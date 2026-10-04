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

echo "\n$pass passed, $fail failed\n";
exit($fail === 0 ? 0 : 1);
