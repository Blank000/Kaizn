# Zuzu AI server — deploying on Hostinger

Pico can answer through **your** OpenAI key and model without anyone ever
seeing either. The app sends the chat here, this server adds the key and
model, calls OpenAI, and returns only the reply.

- **Anyone who signs in with Google** can use it, **50 messages a day** each.
- **People who add their own OpenAI key** in Settings skip this server
  entirely and have no limit.
- Every request is checked with Google first. A request without a valid
  sign-in for *this* app is refused before a cent is spent.
- Message content is **never stored or logged**. The server keeps only a
  per-person count per day.

Total time: about 20 minutes.

---

## Step 1 — Create a "Web" sign-in client in Google Cloud (2 min)

Android only gives the app a sign-in token the server can check when the
app is set up with a *Web* client id.

1. Open <https://console.cloud.google.com/apis/credentials> and select the
   **same project** the app already uses.
2. **+ Create credentials → OAuth client ID**.
3. Application type: **Web application**. Name: `Zuzu server`. Leave
   everything else empty. **Create**.
4. Copy the **Client ID** (ends in `.apps.googleusercontent.com`). You need
   it in step 4 and step 6.

## Step 2 — Set PHP up in hPanel (2 min)

1. hPanel → **Websites → your domain → Advanced → PHP Configuration**.
2. **PHP version: 8.2** (8.1 also works; older will not).
3. Under **PHP extensions**, make sure **curl** and **pdo_sqlite** are
   ticked. They usually are by default.
4. hPanel → **Security → SSL**: make sure your domain has an active SSL
   certificate (Hostinger's free one is fine). The app only talks HTTPS.

## Step 3 — Upload the files (5 min)

Open hPanel → **File Manager**. You will see a folder like:

```
domains/
  yourdomain.com/
    public_html/        <- your website, served to the world
```

Upload so it looks like this:

```
domains/
  yourdomain.com/
    zuzu-private/       <- NEW, beside public_html, NOT inside it
      bootstrap.php
      config.sample.php
      .htaccess
    public_html/
      api/              <- NEW
        chat.php
        .htaccess
```

- `zuzu-private` comes from this repo's `server/zuzu-private/`.
- `api` comes from this repo's `server/public_html/api/`.
- Files starting with a dot (`.htaccess`) are hidden by default in File
  Manager. Use the "show hidden files" setting so you can see them upload.

**`zuzu-private` must sit beside `public_html`, never inside it.** That
is what keeps your OpenAI key off the web. (Its `.htaccess` refuses all
requests anyway, as a backstop.)

## Step 4 — Put your key in (3 min)

1. In `zuzu-private/`, copy `config.sample.php` and name the copy
   `config.php`.
2. Edit `config.php`:
   - `openai_api_key` → your key from <https://platform.openai.com/api-keys>
   - `model` → the model everyone uses, e.g. `gpt-4o-mini`
   - in `google_client_ids`, replace `REPLACE_WITH_WEB_CLIENT_ID...` with
     the Web Client ID from step 1. Leave the second line (the iPhone
     client id) as it is.
3. Save.

## Step 5 — Check it (1 min)

Open in a browser:

```
https://yourdomain.com/api/chat.php?health
```

You should see:

```json
{"ok":true,"version":"1","config_present":true,"pdo_sqlite":true,"curl":true,"php":"8.2.x"}
```

| If you see | Fix |
|---|---|
| `"config_present":false` | `config.php` is missing or misnamed (step 4), or `zuzu-private` is in the wrong place (step 3) |
| `"pdo_sqlite":false` or `"curl":false` | tick the extension (step 2) |
| A 500 error page | PHP version is older than 8.1 (step 2) |
| 404 | `api/chat.php` is not inside `public_html` |

Then make sure your key is **not** reachable — this should **fail** (404
or 403):

```
https://yourdomain.com/zuzu-private/config.php
```

## Step 6 — Point the app at it

In `lib/core/constants/ai_config.dart`:

```dart
const String kAiProxyUrl = 'https://yourdomain.com/api/chat.php';
const String kGoogleServerClientId = '<Web Client ID from step 1>';
```

Rebuild the APK. From then on Pico works for everyone with no setup, and
shows "N of 50 messages left today" under the chat box.

**Check the Web Client ID twice before you build.** A wrong one does not
just break Pico — it makes Google sign-in fail on Android.

## Step 7 — Put a spending ceiling on OpenAI (strongly recommended)

<https://platform.openai.com/settings/organization/limits> → set a
**monthly budget**. The daily cap protects you per person; this is the
last line of defence if many people sign up at once.

---

## Changing things later

- **Different model** → edit `model` in `config.php`. No app update needed.
- **Different daily cap** → edit `daily_limit` in `config.php`, and
  `kAiDailyLimit` in the app so the counter shows the right number.
- **Rotate the key** → edit `openai_api_key`. No app update needed.

## Testing it locally

The server ships with an end-to-end test suite that runs against mock
Google and OpenAI endpoints — no real key, no cost:

```bash
docker run --rm -v "$PWD/server:/srv" -w /srv php:8.2-cli sh tests/run.sh
```

It checks sign-in verification (including tokens issued to other apps),
the daily cap, that failed calls are refunded, that oversized requests are
rejected before spending anything, and that neither the key nor the model
name ever appears in a response.
