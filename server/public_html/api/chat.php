<?php
// The only web-reachable entry point. Everything with secrets lives in
// zuzu-private/, in one of two places:
//
//   1. BESIDE public_html - preferred, the web server cannot see it at all.
//      This is the layout when deploying over SSH.
//   2. INSIDE public_html - needed when deploying through Hostinger's MCP,
//      whose file upload can only write inside public_html. There the
//      folder's deny-all .htaccess keeps it unreachable, and config.php only
//      `return`s an array, so even a misconfigured server prints nothing.
declare(strict_types=1);

$candidates = [
    dirname(__DIR__, 2) . '/zuzu-private/bootstrap.php',
    dirname(__DIR__) . '/zuzu-private/bootstrap.php',
];
foreach ($candidates as $path) {
    if (is_file($path)) {
        require $path;
        zuzu_handle_chat();
    }
}
http_response_code(500);
header('Content-Type: application/json');
echo '{"error":"server_not_installed","message":"The AI server files are missing."}';
