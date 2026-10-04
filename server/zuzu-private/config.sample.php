<?php
/**
 * Copy this file to config.php (same folder) and fill it in.
 * config.php is gitignored - it holds your OpenAI key and must never be
 * committed or placed inside public_html.
 */
return [
    // Your OpenAI secret key, from platform.openai.com/api-keys.
    'openai_api_key' => 'sk-REPLACE_ME',

    // The model everyone on your server uses. Users never see this.
    'model' => 'gpt-4o-mini',

    // Messages per person per day. Resets at midnight in 'timezone'.
    'daily_limit' => 50,
    'timezone' => 'Asia/Kolkata',

    // The OAuth client ids your app's Google sign-in tokens are issued to.
    // A token for any other app is refused. Add:
    //   - the WEB client id   (Android tokens carry this one)
    //   - the iOS client id   (iPhone tokens carry this one; it is the
    //                          GIDClientID value in ios/Runner/Info.plist)
    'google_client_ids' => [
        'REPLACE_WITH_WEB_CLIENT_ID.apps.googleusercontent.com',
        '1056390719903-0uitubentgq7k6l15cf7ebodtjm6qeea.apps.googleusercontent.com',
    ],

    // Optional cost guards.
    'max_output_tokens' => 1500,
];
