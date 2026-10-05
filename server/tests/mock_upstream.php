<?php
// Stand-in for Google's tokeninfo and OpenAI, so the proxy can be tested
// without real credentials or real money. Run: php -S 127.0.0.1:9000 this.
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
header('Content-Type: application/json');

if ($path === '/tokeninfo') {
    $t = $_GET['id_token'] ?? '';
    $now = time();
    $base = ['iss' => 'accounts.google.com', 'aud' => 'test-client',
             'exp' => (string)($now + 3600), 'email_verified' => 'true'];
    if (str_starts_with($t, 'good-')) {
        echo json_encode($base + ['sub' => substr($t, 5)]);
    } elseif ($t === 'wrong-audience') {
        echo json_encode(['aud' => 'some-other-app', 'sub' => 'x'] + $base);
    } elseif ($t === 'expired') {
        echo json_encode(['exp' => (string)($now - 10), 'sub' => 'x'] + $base);
    } elseif ($t === 'unverified') {
        echo json_encode(['email_verified' => 'false', 'sub' => 'x'] + $base);
    } else {
        http_response_code(400);
        echo json_encode(['error' => 'invalid_token']);
    }
    exit;
}

if ($path === '/v1/chat/completions') {
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if ($auth !== 'Bearer sk-test-secret') {
        http_response_code(401);
        echo json_encode(['error' => ['message' => 'bad key']]);
        exit;
    }
    $body = json_decode(file_get_contents('php://input'), true);
    $last = end($body['messages'])['content'];
    if (is_array($last)) {
        // Attachments: echo the text parts and which part types arrived.
        $last = implode(' ', array_map(
            fn($p) => $p['type'] === 'text' ? $p['text'] : "[{$p['type']}]",
            $last));
    }
    if ($last === 'FAIL') {
        http_response_code(500);
        echo json_encode(['error' => ['message' => 'model secret-model-x overloaded']]);
        exit;
    }
    // Echo what the proxy sent, so the test can prove model + key were
    // added server-side and nothing leaks back.
    echo json_encode(['model' => $body['model'], 'choices' => [[
        'message' => ['content' => "echo: $last | model=" . $body['model']],
    ]]]);
    exit;
}

http_response_code(404);
