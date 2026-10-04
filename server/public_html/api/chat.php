<?php
// The only web-reachable file. Everything with secrets lives one level ABOVE
// public_html, in zuzu-private/, where the web server will not serve it.
declare(strict_types=1);
require dirname(__DIR__, 2) . '/zuzu-private/bootstrap.php';
zuzu_handle_chat();
