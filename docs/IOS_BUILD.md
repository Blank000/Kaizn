# Building Zuzu for iOS (run this on the Mac)

*Current as of 2026-09-23, branch `timetable`. Everything that could be
prepared from Windows is already committed. The Mac only has to compile and
sign — no feature work belongs here.*

---

## What is already done

Do not redo any of this:

- **Display name** — `CFBundleDisplayName` is `Zuzu`.
- **Launcher icons** — all 21 sizes generated into
  `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, no alpha (iOS rejects
  transparency in app icons).
- **Notifications** — Darwin init settings are in place with all the
  request flags false, plus an explicit
  `IOSFlutterLocalNotificationsPlugin.requestPermissions` call. This was a
  real launch crash on iOS before it was fixed; leave it alone.
- **Microphone + speech** — `NSMicrophoneUsageDescription` and
  `NSSpeechRecognitionUsageDescription` are written, worded for the Pico
  voice input.
- **Google Sign-In** — `GIDClientID` and the reversed-client-id URL scheme
  are in `Info.plist`.
- **Deployment target** — 13.0, in both the Podfile and the Xcode project.
- **Podfile** — committed, pinning `platform :ios, '13.0'` with per-pod
  deployment targets.

## One-time Mac setup

1. Install Xcode from the App Store. Then:
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app
   ```
   Open Xcode once to accept the licence and let it install components.
2. Install Flutter (match the Windows version — run `flutter --version` on
   Windows first and use the same major) and CocoaPods:
   ```bash
   brew install cocoapods     # or: sudo gem install cocoapods
   ```
3. `flutter doctor` until the Xcode row is green.

**Put the checkout outside iCloud, in a path with no spaces.** Both
`Documents` (iCloud Drive) and a space in the path make codesign fail with
`resource fork, Finder information, or similar detritus not allowed`.
`bash tools/ios_reset.sh` strips that metadata, then iCloud stamps it
back on the next build. Clone into something like `~/Projects/Kaizn`.
If that folder already exists, use another name (`~/Projects/Kaizn-timetable`
worked). Do not use `~/Documents/Github Projects/Kaizn`.

## Every build

```bash
git clone git@github.com:Blank000/Kaizn.git ~/Projects/Kaizn
cd ~/Projects/Kaizn
git checkout timetable
flutter pub get
cd ios && pod install && cd ..
open ios/Runner.xcworkspace        # ALWAYS .xcworkspace, never .xcodeproj
```

In Xcode, select the **Runner** target → **Signing & Capabilities**:

- **Automatically manage signing** — on.
- **Team** — your personal Apple ID (shows as Personal Team on a free
  account). A free account is enough to install on your own iPhone; the
  install expires after 7 days. A paid account is required for TestFlight.
- **Bundle identifier** — keep `com.alokraj.habitRewardTracker`. Google
  Sign-In is registered against it.

### Phone

1. Plug in with a data cable, unlock, tap **Trust**.
2. **Settings → Privacy & Security → Developer Mode → On**, then restart.
3. Find the id (the middle column):

```bash
flutter devices
```

```text
Prachi’s iPhone (wireless) • 00008150-001169583A78401C • ios • iOS 26.6.2
```

Wi-Fi works after one USB pair. Xcode → **Window → Devices and Simulators**
→ select the iPhone → **Connect via network**. Same Wi-Fi, phone unlocked.
On iOS 26 the wireless attach often sits on “waiting to connect” for a
minute after the Mac already has a link. Leave it. A cable is faster when
that stalls.

### Use the app without a terminal

`flutter run` is a debug session. Closing that terminal kills the app.
Install a release build instead, then open Zuzu from the home screen:

```bash
flutter build ios --release && flutter install --release -d <iphone-id>
```

Example:

```bash
flutter build ios --release && flutter install --release -d 00008150-001169583A78401C
```

The first launch may ask you to trust the developer certificate:
**Settings → General → VPN & Device Management**. When the free install
expires (7 days), run the same command again.

SQLite `MIN` / `MAX` lines during the Xcode build are warnings. The
failure that matters is the codesign “detritus” line, and that is the
path problem above.

`flutter build ipa` is the TestFlight / App Store package. It needs the
paid Apple Developer Program.

## If the build fights you

Run the canonical reset — it clears Pods and extended attributes, and
warns if the project path contains a space:

```bash
bash tools/ios_reset.sh
```

If the error is still `resource fork, Finder information, or similar
detritus not allowed`, the checkout is still under iCloud `Documents`.
Move it (see the path rule above) and build again. Resetting in place
does not stick there.

`iOS_SETUP.md` in the repo root is the deeper first-Mac guide (Xcode
signing, Developer Mode on the phone, Google Sign-In OAuth gotchas), written
during the first real Mac attempt. Use it when the happy path above fails.

## Things to verify on device, because they are the untested edges

These all compile, but none has ever run on iOS:

| Area | What to check | Notes |
|---|---|---|
| **Launch** | App opens without crashing | If it crashes instantly, the Darwin notification init regressed |
| **Google Sign-In** | Sign in, then Settings → Back up now | If it bounces straight back, the `GIDClientID` is not registered as an **iOS** OAuth client for this bundle id. Create one in the same Cloud project as Android's and swap both plist values. |
| **Notifications** | Enable a toggle, fire a task reminder | iOS will prompt for permission on first enable |
| **Pico voice** | Tap the mic in the AI chat | Expect Apple's mic *and* speech-recognition prompts, one after the other |
| **Zuzu animations** | Home post, first completion, day complete | Pure Dart Lottie, no native code — should be identical to Android |
| **Stopwatch** | Start, background the app, return | It must **not** auto-pause. That is deliberate. |
| **Home-screen widget** | Nothing — just confirm the app still launches | Android-only. `home_widget` is a dependency but **no iOS widget extension exists**. `WidgetService.init` already wraps `setAppGroupId` in a try/catch and every refresh is best-effort, so the missing extension degrades quietly rather than crashing. |
| **Safe areas** | Floating Pico, timeline, bottom sheets | Notch and home-indicator clamps have never been checked on a real iPhone |

## Known iOS deltas — all acceptable for v1

- **Exact alarms** are an Android concept. iOS schedules normally and may
  drift by minutes under low power. No code change needed.
- **Notification action buttons** (Done / Skip / Snooze) are Android-only
  today. iOS shows plain notifications; wiring them needs Darwin category
  registration. Tracked, not blocking.
- **No home-screen widget on iOS.** Would need a separate widget extension
  target plus an app group.

## Do not do on the Mac

- Do not rebuild features on an old branch. `ios-release` was archived as
  the tag `archive/ios-release` and deleted — everything lives on
  `timetable`.
- Do not change the bundle id, the Dart package name, the Drift database
  name or the Drive backup filename. They are deliberately still spelled
  `habit_reward_tracker`; renaming any of them orphans real user data.
