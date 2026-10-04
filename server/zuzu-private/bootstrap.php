<?php
/**
 * Zuzu AI proxy — the server side of Pico.
 *
 * WHAT IT IS FOR
 * The app must never carry the OpenAI key or name the model: anything
 * shipped inside an APK can be extracted. So the app sends the chat here,
 * this file adds the key and the model, calls OpenAI, and returns only the
 * reply text.
 *
 * WHY EVERY REQUEST IS AUTHENTICATED
 * An open endpoint is a blank cheque - anyone who finds the URL could run
 * up the owner's OpenAI bill. Each request carries the user's Google
 * sign-in ID token. We check it with Google, then key the daily cap on the
 * Google account's stable id (`sub`), so reinstalling the app or clearing
 * its data does not reset anyone's allowance.
 *
 * WHAT IS NEVER STORED OR LOGGED
 * Message content. The database holds only: a hash of each verified token
 * (so we don't ask Google every time), and a per-account message count per
 * day.
 *
 * Lives OUTSIDE public_html. Only public_html/api/chat.php is reachable from
 * the web, and it does nothing but require this file.
 */

declare(strict_types=1);

const ZUZU_VERSION = '1';

function zuzu_config(): array
{
    static $config = null;
    if ($config !== null) {
        return $config;
    }
    // ZUZU_CONFIG lets the test suite point at a throwaway config; in
    // production it is unset and config.php beside this file is used.
    $path = getenv('ZUZU_CONFIG') ?: __DIR__ . '/config.php';
    if (!is_file($path)) {
        zuzu_fail(500, 'server_not_configured',
            'The AI server is not set up yet.');
    }
    $c = require $path;
    $defaults = [
        'daily_limit' => 50,
        'timezone' => 'Asia/Kolkata',
        'max_output_tokens' => 1500,
        'max_input_chars' => 150000,
        'max_messages' => 80,
        'openai_url' => 'https://api.openai.com/v1/chat/completions',
        'tokeninfo_url' => 'https://oauth2.googleapis.com/tokeninfo',
        'data_dir' => __DIR__ . '/data',
    ];
    $config = array_merge($defaults, $c);
    foreach (['openai_api_key', 'model', 'google_client_ids'] as $k) {
        if (empty($config[$k])) {
            zuzu_fail(500, 'server_not_configured',
                'The AI server is not set up yet.');
        }
    }
    return $config;
}

/** Send JSON and stop. Never echoes anything from config. */
function zuzu_respond(int $status, array $body): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function zuzu_fail(int $status, string $code, string $message,
                   array $extra = []): never
{
    zuzu_respond($status, ['error' => $code, 'message' => $message] + $extra);
}

function zuzu_db(): PDO
{
    static $pdo = null;
    if ($pdo !== null) {
        return $pdo;
    }
    $dir = zuzu_config()['data_dir'];
    if (!is_dir($dir) && !mkdir($dir, 0700, true) && !is_dir($dir)) {
        zuzu_fail(500, 'storage', 'The AI server cannot write its data.');
    }
    $pdo = new PDO('sqlite:' . $dir . '/zuzu.sqlite');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    // Two app users hitting send at the same instant must queue, not fail.
    $pdo->exec('PRAGMA busy_timeout = 5000');
    $pdo->exec('PRAGMA journal_mode = WAL');
    $pdo->exec('CREATE TABLE IF NOT EXISTS usage (
        sub TEXT NOT NULL, day TEXT NOT NULL, count INTEGER NOT NULL,
        PRIMARY KEY (sub, day))');
    $pdo->exec('CREATE TABLE IF NOT EXISTS token_cache (
        hash TEXT PRIMARY KEY, sub TEXT NOT NULL, exp INTEGER NOT NULL)');
    return $pdo;
}

/** Today's date in the configured timezone - when the 50 resets. */
function zuzu_today(): string
{
    $tz = new DateTimeZone(zuzu_config()['timezone']);
    return (new DateTimeImmutable('now', $tz))->format('Y-m-d');
}

function zuzu_resets_at(): string
{
    $tz = new DateTimeZone(zuzu_config()['timezone']);
    return (new DateTimeImmutable('tomorrow', $tz))->format(DATE_ATOM);
}

/**
 * Verify a Google ID token and return the account's stable id.
 *
 * Accepted only when Google confirms it AND it was issued to one of OUR
 * OAuth clients (`aud`). Without the audience check, a token minted for any
 * other app on earth would be accepted.
 */
function zuzu_verify_google(string $token): string
{
    $cfg = zuzu_config();
    $hash = hash('sha256', $token);
    $now = time();

    $db = zuzu_db();
    $hit = $db->prepare('SELECT sub, exp FROM token_cache WHERE hash = ?');
    $hit->execute([$hash]);
    $row = $hit->fetch(PDO::FETCH_ASSOC);
    if ($row && (int)$row['exp'] > $now) {
        return (string)$row['sub'];
    }

    $ch = curl_init($cfg['tokeninfo_url'] . '?id_token=' . rawurlencode($token));
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 10,
        CURLOPT_CONNECTTIMEOUT => 5,
    ]);
    $raw = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($raw === false) {
        zuzu_fail(503, 'auth_unreachable',
            'Could not verify your sign-in right now. Try again.');
    }
    $info = json_decode((string)$raw, true);
    if ($status !== 200 || !is_array($info)) {
        zuzu_fail(401, 'auth_invalid',
            'Your sign-in has expired. Please sign in again.');
    }

    $aud = (string)($info['aud'] ?? '');
    $iss = (string)($info['iss'] ?? '');
    $exp = (int)($info['exp'] ?? 0);
    $sub = (string)($info['sub'] ?? '');
    $verified = ($info['email_verified'] ?? '') === 'true'
        || ($info['email_verified'] ?? false) === true;

    $issOk = in_array($iss, ['accounts.google.com',
        'https://accounts.google.com'], true);
    $audOk = in_array($aud, (array)$cfg['google_client_ids'], true);

    if (!$issOk || !$audOk || $sub === '' || $exp <= $now || !$verified) {
        zuzu_fail(401, 'auth_invalid',
            'Your sign-in could not be verified. Please sign in again.');
    }

    $db->prepare('INSERT OR REPLACE INTO token_cache (hash, sub, exp)
        VALUES (?, ?, ?)')->execute([$hash, $sub, $exp]);
    // Opportunistic cleanup; keeps the table tiny without a cron job.
    if (random_int(1, 50) === 1) {
        $db->prepare('DELETE FROM token_cache WHERE exp < ?')->execute([$now]);
    }
    return $sub;
}

/**
 * Take one message from today's allowance, atomically. Returns how many
 * are left AFTER this one. Refuses once the cap is reached.
 */
function zuzu_reserve(string $sub): int
{
    $limit = (int)zuzu_config()['daily_limit'];
    $day = zuzu_today();
    $db = zuzu_db();
    // IMMEDIATE takes the write lock up front, so two simultaneous sends
    // can never both read "49" and both proceed.
    $db->exec('BEGIN IMMEDIATE');
    try {
        $q = $db->prepare('SELECT count FROM usage WHERE sub = ? AND day = ?');
        $q->execute([$sub, $day]);
        $used = (int)($q->fetchColumn() ?: 0);
        if ($used >= $limit) {
            $db->exec('ROLLBACK');
            zuzu_fail(429, 'daily_limit',
                "You've used today's {$limit} messages.",
                ['limit' => $limit, 'remaining' => 0,
                 'resets_at' => zuzu_resets_at()]);
        }
        $db->prepare('INSERT INTO usage (sub, day, count) VALUES (?, ?, 1)
            ON CONFLICT(sub, day) DO UPDATE SET count = count + 1')
            ->execute([$sub, $day]);
        $db->exec('COMMIT');
        return $limit - ($used + 1);
    } catch (PDOException $e) {
        try { $db->exec('ROLLBACK'); } catch (PDOException) {}
        error_log('zuzu reserve failed: ' . $e->getCode());
        zuzu_fail(500, 'storage', 'The AI server had a storage problem.');
    }
}

/** Give the message back - the user should not pay for our failure. */
function zuzu_refund(string $sub): void
{
    try {
        zuzu_db()->prepare('UPDATE usage SET count = MAX(count - 1, 0)
            WHERE sub = ? AND day = ?')->execute([$sub, zuzu_today()]);
    } catch (PDOException $e) {
        error_log('zuzu refund failed: ' . $e->getCode());
    }
}

/** Validate the request body. Caps size so nobody can send a novel. */
function zuzu_read_messages(): array
{
    $cfg = zuzu_config();
    $raw = file_get_contents('php://input', false, null, 0, 600001);
    if ($raw === false || strlen($raw) > 600000) {
        zuzu_fail(413, 'too_large', 'That conversation is too long.');
    }
    $body = json_decode($raw, true);
    $messages = is_array($body) ? ($body['messages'] ?? null) : null;
    if (!is_array($messages) || $messages === []) {
        zuzu_fail(400, 'bad_request', 'No messages were sent.');
    }
    if (count($messages) > (int)$cfg['max_messages']) {
        zuzu_fail(413, 'too_large', 'That conversation is too long.');
    }
    $clean = [];
    $chars = 0;
    foreach ($messages as $m) {
        $role = is_array($m) ? ($m['role'] ?? null) : null;
        $content = is_array($m) ? ($m['content'] ?? null) : null;
        if (!in_array($role, ['system', 'user', 'assistant'], true)
            || !is_string($content)) {
            zuzu_fail(400, 'bad_request', 'A message was malformed.');
        }
        $chars += mb_strlen($content);
        $clean[] = ['role' => $role, 'content' => $content];
    }
    if ($chars > (int)$cfg['max_input_chars']) {
        zuzu_fail(413, 'too_large', 'That conversation is too long.');
    }
    return $clean;
}

/** Call OpenAI with OUR key and OUR model. Returns the reply text. */
function zuzu_openai(array $messages): ?string
{
    $cfg = zuzu_config();
    $ch = curl_init($cfg['openai_url']);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_TIMEOUT => 90,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_HTTPHEADER => [
            'Authorization: Bearer ' . $cfg['openai_api_key'],
            'Content-Type: application/json',
        ],
        CURLOPT_POSTFIELDS => json_encode([
            'model' => $cfg['model'],
            'messages' => $messages,
            'max_tokens' => (int)$cfg['max_output_tokens'],
        ], JSON_UNESCAPED_UNICODE),
    ]);
    $raw = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($raw === false || $status !== 200) {
        // The status only - OpenAI's error text can echo the model name.
        error_log('zuzu openai status ' . $status);
        return null;
    }
    $data = json_decode((string)$raw, true);
    $text = $data['choices'][0]['message']['content'] ?? null;
    return is_string($text) && $text !== '' ? $text : null;
}

function zuzu_handle_chat(): never
{
    // A no-secrets self-check for setup: open /api/chat.php?health in a
    // browser and every line should say true.
    if (($_SERVER['REQUEST_METHOD'] ?? '') === 'GET' && isset($_GET['health'])) {
        $configured = is_file(getenv('ZUZU_CONFIG') ?: __DIR__ . '/config.php');
        zuzu_respond(200, [
            'ok' => $configured && extension_loaded('pdo_sqlite')
                && extension_loaded('curl'),
            'version' => ZUZU_VERSION,
            'config_present' => $configured,
            'pdo_sqlite' => extension_loaded('pdo_sqlite'),
            'curl' => extension_loaded('curl'),
            'php' => PHP_VERSION,
        ]);
    }
    if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
        zuzu_fail(405, 'method', 'Use POST.');
    }

    $auth = $_SERVER['HTTP_AUTHORIZATION']
        ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if (!preg_match('/^Bearer\s+(\S+)$/', $auth, $m)) {
        zuzu_fail(401, 'auth_missing', 'Please sign in to use Pico.');
    }

    $sub = zuzu_verify_google($m[1]);
    $messages = zuzu_read_messages();
    $remaining = zuzu_reserve($sub);

    $reply = zuzu_openai($messages);
    if ($reply === null) {
        zuzu_refund($sub);
        zuzu_fail(502, 'upstream',
            'Pico could not get an answer just now. Try again in a moment.');
    }

    zuzu_respond(200, [
        'reply' => $reply,
        'remaining' => $remaining,
        'limit' => (int)zuzu_config()['daily_limit'],
    ]);
}
