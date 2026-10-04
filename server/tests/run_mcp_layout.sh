#!/bin/sh
# Same suite, but in the layout the Hostinger MCP produces: zuzu-private
# uploaded INSIDE public_html. Also proves the usage database is created
# OUTSIDE public_html, and that fetching config.php over HTTP prints nothing.
set -e
ROOT=/tmp/site/domains/example.com
rm -rf /tmp/site && mkdir -p "$ROOT/public_html"
cp -r /srv/public_html/api "$ROOT/public_html/api"
cp -r /srv/zuzu-private "$ROOT/public_html/zuzu-private"
cat > "$ROOT/public_html/zuzu-private/config.php" <<'EOF'
<?php return [
  'openai_api_key' => 'sk-test-secret',
  'model' => 'server-model',
  'daily_limit' => 3,
  'google_client_ids' => ['test-client'],
  'openai_url' => 'http://127.0.0.1:9000/v1/chat/completions',
  'tokeninfo_url' => 'http://127.0.0.1:9000/tokeninfo',
];
EOF
unset ZUZU_CONFIG
php -S 127.0.0.1:9000 /srv/tests/mock_upstream.php >/tmp/mock.log 2>&1 &
php -S 127.0.0.1:8000 -t "$ROOT/public_html" >/tmp/app.log 2>&1 &
sleep 1
php /srv/tests/run_tests.php

echo
echo "MCP layout checks"
if [ -f "$ROOT/zuzu-data/zuzu.sqlite" ]; then
  echo "  ok    usage database created OUTSIDE public_html"
else
  echo "  FAIL  usage database not found outside public_html"; exit 1
fi
if [ -d "$ROOT/public_html/zuzu-private/data" ]; then
  echo "  FAIL  a data folder was created inside public_html"; exit 1
else
  echo "  ok    nothing written inside public_html"
fi
BODY=$(curl -s http://127.0.0.1:8000/zuzu-private/config.php)
if [ -z "$BODY" ]; then
  echo "  ok    requesting config.php over HTTP prints nothing"
else
  echo "  FAIL  config.php printed: $BODY"; exit 1
fi
