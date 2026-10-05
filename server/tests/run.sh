#!/bin/sh
# Runs the proxy end to end inside a stock PHP container:
#   docker run --rm -v "$PWD/server:/srv" -w /srv php:8.2-cli sh tests/run.sh
set -e
cat > /tmp/zuzu-test-config.php <<'EOF'
<?php return [
  'openai_api_key' => 'sk-test-secret',
  'model' => 'server-model',
  'daily_limit' => 3,
  'google_client_ids' => ['test-client'],
  'openai_url' => 'http://127.0.0.1:9000/v1/chat/completions',
  'tokeninfo_url' => 'http://127.0.0.1:9000/tokeninfo',
  'data_dir' => '/tmp/zuzu-data',
];
EOF
rm -rf /tmp/zuzu-data
export ZUZU_CONFIG=/tmp/zuzu-test-config.php
php -d post_max_size=64M -d memory_limit=512M -S 127.0.0.1:9000 tests/mock_upstream.php >/tmp/mock.log 2>&1 &
php -d post_max_size=64M -d memory_limit=512M -S 127.0.0.1:8000 -t public_html >/tmp/app.log 2>&1 &
sleep 1
php tests/run_tests.php
