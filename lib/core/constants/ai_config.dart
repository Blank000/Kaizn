/// Where Pico gets its answers when the user has not added their own key.
///
/// NEITHER VALUE HERE IS A SECRET, and that is the point of the design: the
/// OpenAI key and the model name live only on the server
/// (`server/zuzu-private/config.php`), because anything compiled into the
/// app can be extracted from the APK. A URL and a public OAuth client id
/// are safe to ship.
///
/// Fill both in after deploying the server (see `server/README.md`). While
/// [kAiProxyUrl] is empty the app behaves exactly as before: Pico asks each
/// user for their own key.
library;

/// The deployed proxy, e.g. `https://yourdomain.com/api/chat.php`.
const String kAiProxyUrl = '';

/// The **Web** OAuth client id from the same Google Cloud project as the
/// app (APIs & Services -> Credentials -> "Web application").
///
/// Android only hands the app a Google ID token - the proof of identity the
/// server checks - when sign-in is configured with a web client id. Getting
/// this wrong makes Android sign-in fail outright, which is why it stays
/// empty (and unused) until you have created the client and copied its id.
const String kGoogleServerClientId = '';

/// Shown to users; must match `daily_limit` in the server config.
const int kAiDailyLimit = 50;
