#!/bin/sh
# Same suite, in the layout of a Hostinger subdomain: the subdomain's folder
# sits INSIDE the main site's public_html (public_html/zuzu/), and both api/
# and zuzu-private/ go inside that. The usage database must still land
# OUTSIDE public_html, beside it.
set -e
ROOT=/tmp/sub/domains/example.com
SITE="$ROOT/public_html/zuzu"
rm -rf /tmp/sub && mkdir -p "$SITE"
cp -r /srv/public_html/api "$SITE/api"
cp -r /srv/zuzu-private "$SITE/zuzu-private"
cp /srv/subdomain-root/.htaccess /srv/subdomain-root/robots.txt "$SITE/"
cat > "$SITE/zuzu-private/config.php" <<'EOF'
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
php -d post_max_size=64M -d memory_limit=512M -S 127.0.0.1:9000 /srv/tests/mock_upstream.php >/tmp/mock.log 2>&1 &
php -d post_max_size=64M -d memory_limit=512M -S 127.0.0.1:8000 -t "$SITE" >/tmp/app.log 2>&1 &
sleep 1
php /srv/tests/run_tests.php

echo
echo "Subdomain layout checks"
if [ -f "$ROOT/zuzu-data/zuzu.sqlite" ]; then
  echo "  ok    usage database created OUTSIDE public_html"
else
  echo "  FAIL  usage database not found outside public_html"; exit 1
fi
if find "$ROOT/public_html" -name '*.sqlite' | grep -q .; then
  echo "  FAIL  a database was created inside public_html"; exit 1
else
  echo "  ok    nothing written inside public_html"
fi
