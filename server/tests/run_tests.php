<?php
// End-to-end tests for the Zuzu AI proxy. Run via server/tests/run.sh.
declare(strict_types=1);

$base = 'http://127.0.0.1:8000/api/chat.php';
$pass = 0;
$fail = 0;

function call(string $method, string $url, ?string $token, ?array $body): array
{
    $ch = curl_init($url);
    $headers = ['Content-Type: application/json'];
    if ($token !== null) {
        $headers[] = "Authorization: Bearer $token";
    }
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_POSTFIELDS => $body === null ? null : json_encode($body),
    ]);
    $raw = (string)curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return [$status, json_decode($raw, true) ?? [], $raw];
}

function msg(string $text): array
{
    return ['messages' => [
        ['role' => 'system', 'content' => 'You are Pico.'],
        ['role' => 'user', 'content' => $text],
    ]];
}

function check(string $name, bool $ok, string $detail = ''): void
{
    global $pass, $fail;
    if ($ok) { $pass++; echo "  ok    $name\n"; }
    else { $fail++; echo "  FAIL  $name  $detail\n"; }
}

echo "Zuzu AI proxy\n";

[$s, $j] = call('GET', "$base?health", null, null);
check('health check reports ready', $s === 200 && $j['ok'] === true, json_encode($j));
check('health check leaks no secrets',
    !str_contains(json_encode($j), 'sk-') && !isset($j['model']));

[$s, $j] = call('GET', $base, null, null);
check('GET without ?health is refused', $s === 405);

[$s, $j] = call('POST', $base, null, msg('hi'));
check('no token -> 401 auth_missing', $s === 401 && $j['error'] === 'auth_missing');

[$s, $j] = call('POST', $base, 'garbage', msg('hi'));
check('token Google rejects -> 401', $s === 401 && $j['error'] === 'auth_invalid');

[$s, $j] = call('POST', $base, 'wrong-audience', msg('hi'));
check('token for ANOTHER app -> 401', $s === 401 && $j['error'] === 'auth_invalid');

[$s, $j] = call('POST', $base, 'expired', msg('hi'));
check('expired token -> 401', $s === 401);

[$s, $j] = call('POST', $base, 'unverified', msg('hi'));
check('unverified email -> 401', $s === 401);

[$s, $j, $raw] = call('POST', $base, 'good-alice', msg('hello'));
check('valid user gets a reply', $s === 200 && str_starts_with($j['reply'] ?? '', 'echo: hello'), $raw);
check('server added ITS model (proves app never sends one)',
    str_contains($j['reply'] ?? '', 'model=server-model'));
check('response carries no model or key fields',
    !isset($j['model']) && !str_contains($raw, 'sk-test-secret'));
check('remaining counts down from the cap', ($j['remaining'] ?? null) === 2 && $j['limit'] === 3, $raw);

call('POST', $base, 'good-alice', msg('two'));
[$s, $j] = call('POST', $base, 'good-alice', msg('three'));
check('third message leaves zero', $s === 200 && $j['remaining'] === 0);

[$s, $j] = call('POST', $base, 'good-alice', msg('four'));
check('over the cap -> 429 daily_limit', $s === 429 && $j['error'] === 'daily_limit');
check('429 says when it resets', isset($j['resets_at']) && $j['remaining'] === 0);

[$s, $j] = call('POST', $base, 'good-bob', msg('hi'));
check('a different person has their own allowance', $s === 200 && $j['remaining'] === 2);

[$s, $j, $raw] = call('POST', $base, 'good-bob', msg('FAIL'));
check('OpenAI failure -> 502 upstream', $s === 502 && $j['error'] === 'upstream', $raw);
check('upstream error text (which names the model) is NOT forwarded',
    !str_contains($raw, 'secret-model') && !str_contains($raw, 'overloaded'));
[$s, $j] = call('POST', $base, 'good-bob', msg('after failure'));
check('a failed call is refunded, not charged', $s === 200 && $j['remaining'] === 1, json_encode($j));

[$s, $j] = call('POST', $base, 'good-carol', ['messages' => [['role' => 'hacker', 'content' => 'x']]]);
check('unknown role rejected', $s === 400);
[$s, $j] = call('POST', $base, 'good-carol', ['messages' => []]);
check('empty conversation rejected', $s === 400);
[$s, $j] = call('POST', $base, 'good-carol', msg(str_repeat('x', 200001)));
check('oversized conversation rejected before spending', $s === 413);
[$s, $j] = call('POST', $base, 'good-carol', msg('still fine'));
check('rejected requests did not use up allowance', $s === 200 && $j['remaining'] === 2);

// Attachments - a fresh person, since carol has used part of her allowance.
function parts(array $parts): array
{
    return ['messages' => [
        ['role' => 'system', 'content' => 'You are Pico.'],
        ['role' => 'user', 'content' => $parts],
    ]];
}
$png = 'data:image/png;base64,' . base64_encode('fake-png-bytes');
$pdf = 'data:application/pdf;base64,' . base64_encode(str_repeat('%PDF', 1000));

[$s, $j, $raw] = call('POST', $base, 'good-dave', parts([
    ['type' => 'text', 'text' => 'what is this'],
    ['type' => 'image_url', 'image_url' => ['url' => $png], 'evil' => 'x'],
    ['type' => 'file', 'file' => ['filename' => 'plan.pdf', 'file_data' => $pdf]],
]));
check('photo + PDF reach the model',
    $s === 200 && str_contains($j['reply'] ?? '', 'what is this [image_url] [file]'), $raw);

[$s] = call('POST', $base, 'good-dave', parts([
    ['type' => 'image_url', 'image_url' => ['url' => 'https://example.com/a.png']],
]));
check('remote image URL refused (no fetching on our bill)', $s === 400);

[$s] = call('POST', $base, 'good-dave', parts([
    ['type' => 'file', 'file' => ['filename' => 'x.exe',
        'file_data' => 'data:application/x-msdownload;base64,TVqQ']],
]));
check('non-PDF file refused', $s === 400);

[$s] = call('POST', $base, 'good-dave', parts([
    ['type' => 'image_url', 'image_url' => ['url' => 'data:image/png;base64,not base64!']],
]));
check('corrupt image data refused', $s === 400);

[$s] = call('POST', $base, 'good-dave', ['messages' => [
    ['role' => 'assistant', 'content' => [['type' => 'text', 'text' => 'x']]],
]]);
check('only user messages may carry parts', $s === 400);

[$s] = call('POST', $base, 'good-dave',
    parts(array_fill(0, 13, ['type' => 'image_url', 'image_url' => ['url' => $png]])));
check('more than 12 attachments refused', $s === 413);

$big = 'data:application/pdf;base64,' . str_repeat('A', 13 * 1024 * 1024);
[$s, $j, $raw] = call('POST', $base, 'good-dave', parts([
    ['type' => 'file', 'file' => ['filename' => 'big.pdf', 'file_data' => $big]],
]));
check('a 10 MB PDF is accepted (no regex backtrack limit)',
    $s === 200 && str_contains($j['reply'] ?? '', '[file]'), substr($raw, 0, 300));

[$s, $j] = call('POST', $base, 'good-dave', msg('allowance check'));
check('refused attachments did not use up allowance', $s === 200 && $j['remaining'] === 0,
    json_encode($j));

// Reporting a reply (Play's AI-content policy) and deleting your data.
[$s, $j] = call('POST', "$base?report", null,
    ['reason' => 'Offensive', 'reply' => 'a bad reply']);
check('report works without signing in', $s === 200 && $j['ok'] === true);
[$s] = call('POST', "$base?report", 'good-erin',
    ['reason' => 'Wrong', 'reply' => 'another reply']);
check('report works signed in', $s === 200);
[$s] = call('POST', "$base?report", null, ['reason' => 'x', 'reply' => '']);
check('empty report refused', $s === 400);
[$s] = call('POST', "$base?report", 'garbage', ['reason' => 'x', 'reply' => 'y']);
check('report with a forged sign-in refused', $s === 401);

[$s] = call('POST', "$base?delete", null, []);
check('delete needs sign-in', $s === 401);
call('POST', $base, 'good-erin', msg('use one'));
[$s, $j] = call('POST', "$base?delete", 'good-erin', []);
check('delete succeeds', $s === 200 && $j['ok'] === true);
[$s, $j] = call('POST', $base, 'good-erin', msg('after delete'));
check('deleting resets that person\'s usage', $s === 200 && $j['remaining'] === 2,
    json_encode($j));

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
