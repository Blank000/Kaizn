# Building & Running on Android

Quick reference for building and running this Flutter app on a physical Android
device from Windows (PowerShell). Bookmark this — paste commands directly, no
prefixes needed.

Project path: `C:\Users\AlokRaj\Documents\personal\projects\habit_reward_tracker`

---

## 1. One-time phone setup

1. **Settings → About phone → tap "Build number" 7 times** → unlocks Developer options.
2. **Settings → System → Developer options → enable "USB debugging"**
   (and "Wireless debugging" if you want to go cable-free).

### Option A — USB (simplest)
Plug in via USB. When the phone prompts, tap **Allow USB debugging** and check
"Always allow from this computer".

### Option B — Wireless (Android 11+)
Phone and PC must be on the **same Wi-Fi**. Wireless debugging needs a **pair**
step first, on a *different* port than the connect port.

1. On phone: **Developer options → Wireless debugging → Pair device with pairing code.**
   Note the `IP:PORT` and the 6-digit code shown there.
2. Pair (use the **pairing** port):
   ```powershell
   adb pair 192.168.1.6:PAIRING_PORT
   ```
   Enter the code when prompted.
3. Connect (use the port on the **main** Wireless debugging screen — different number):
   ```powershell
   adb connect 192.168.1.6:CONNECT_PORT
   ```

---

## 2. Verify the device is visible

```powershell
flutter devices
```

Your phone should be listed. If not, check raw adb state:
```powershell
adb devices
```
- `device` → ready.
- `offline` → stale; `adb disconnect IP:PORT` and reconnect.
- `unauthorized` → accept the debugging prompt on the phone.

---

## 3. Run the app (development — hot reload)

> **⚠ iQOO/Vivo: `r`/`R` DON'T work with plain `flutter run`.** Funtouch OS
> suppresses/masks the "Dart VM service is listening on http://…" logcat
> line that Flutter parses to attach — the tool hangs at "Waiting for VM
> Service port", never prints the key-commands banner, and hot reload never
> enables (app logs still stream, which makes it LOOK attached). Verified
> 2026-07-22: the URL line is absent from logcat entirely.
>
> **Use the helper script instead** (fixed, tokenless VM-service port +
> explicit `flutter attach` — bypasses logcat discovery):
> ```powershell
> .\dev.ps1
> ```
> Prefer a **USB cable** for dev sessions: wireless adb on this phone drops
> whenever the screen sleeps (ports change per reconnect, sessions die).

On non-Vivo devices, plain run works:
```powershell
flutter run
```
Or pin to a device if multiple are attached:
```powershell
flutter run -d <DEVICE_ID>
```
- First build takes a few minutes; then `r` = hot reload, `R` = hot restart, `q` = quit.
- `r` for UI/logic edits; `R` when initState/services/constants changed;
  full re-run only for schema (codegen), manifest, or pubspec changes.
- **Accept the notification + exact-alarm prompts** on first launch, or reminders won't fire.

---

## 4. Build a standalone APK (sideload — no cable after)

Debug APK:
```powershell
flutter build apk --debug
```
Release APK (smaller, faster):
```powershell
flutter build apk --release
```
Split per architecture (smallest per-device APK):
```powershell
flutter build apk --release --split-per-abi
```
Output lands in `build\app\outputs\flutter-apk\`. Copy to phone and tap to
install (allow "install from unknown sources" if prompted).

Install straight to a connected device instead of copying:
```powershell
flutter install
```

---

## 5. After changing a database table (Drift codegen)

Any edit under `lib/core/database/tables/` (or the schema itself) needs the
generated `database.g.dart` rebuilt:
```powershell
dart run build_runner build --delete-conflicting-outputs
```

**MUST run before `flutter run` after any schema change** — otherwise the
build fails with errors like `The getter 'X' isn't defined for the class 'Task'`
or `No named parameter with the name 'X'` in `TasksCompanion.insert`. Those
all mean `database.g.dart` is stale.

## Quick sanity check (compile only, ~fast)
```powershell
flutter analyze --no-fatal-infos
```

---

## Testing notifications quickly

Reminders fire at real clock times, so to see one fast:
1. Create/edit a task, turn on **Remind me**, set the time **~2 minutes out**.
2. Press home to background the app; wait for the reminder with **Done · Skip · Snooze 1h**.
3. Tap **Done** → a "✓ Logged…" confirmation with **Undo** appears; the completion
   shows in-app on reopen.

Use a **physical device**, not an emulator — emulators are unreliable about
delivering scheduled/background notifications under Doze.

---

## Troubleshooting

- **`flutter devices` doesn't list the phone:** phone side — accept the USB-debug
  prompt; PC side — `adb kill-server; adb start-server` and reconnect.
- **`adb connect` fails on wireless:** you skipped the **pair** step, or used the
  pairing port for connect (they differ). Re-pair (§1 Option B).
- **Reminders arrive late (tens of minutes off) or not at all:** exact-alarm
  permission wasn't granted. The app requests it on launch; grant it manually at
  **Settings → Apps → Habit Reward Tracker → Alarms & reminders → Allow**.
- **No notifications at all:** the POST_NOTIFICATIONS runtime permission (Android
  13+) was denied — re-enable under the app's notification settings.

### iQOO / Vivo / Oppo / Xiaomi — "notification only shows when I open the app"

BBK-group phones (iQOO, Vivo, OnePlus, Oppo, Realme) and Xiaomi kill the app
process whenever it's not in the foreground, so scheduled alarms can't wake the
app to post notifications. Alarms & reminders permission alone is NOT enough.
Unlock all four:

1. **Autostart** — Settings → Apps → Habit Reward Tracker → **Autostart** → ON
   (or: Settings → Battery → Background power consumption → Autostart).
2. **Background power / battery** — Settings → Battery → Background power
   consumption management → Habit Reward Tracker → **Allow background high
   power consumption**. Also: Settings → Apps → Habit Reward Tracker → Battery
   → set to **Unrestricted** / **Allow background activity**.
3. **Lock in Recents** — open the app, swipe to Recents, swipe **down** on the
   app card (or long-press) → tap the padlock icon that appears. This
   prevents Vivo's "clean up" from killing it. The lock badge stays across
   reboots.
4. **Alarms & reminders** — Settings → Apps → Habit Reward Tracker → Alarms &
   reminders → **Allow**.

After all four, test: add a task, set the reminder ~2 min out, **lock the
phone**, wait. If it still doesn't fire, the phone likely also needs the app
category set to "high priority" under Settings → Notifications → Habit Reward
Tracker → **Task Reminders** → Importance = Urgent.

### Notification action buttons (Done / Skip / Snooze) don't work

The buttons open the app briefly so the action runs in the reliable foreground
isolate — a silent background isolate is killed by OEM battery managers before
the DB write lands. If the app doesn't open on tap, verify Autostart (see
above); without it the OS blocks the tap-to-open intent too.
- **Google Sign-In fails with `DEVELOPER_ERROR`:** your machine's SHA-1 isn't
  registered on the OAuth client for `com.alokraj.habit_reward_tracker`. Grab
  the debug SHA-1 with `cd android; ./gradlew signingReport` and add it in
  Google Cloud Console. Release builds need the release-keystore SHA-1 too.
- **Gradle/build oddities:** `flutter clean` then rebuild.
