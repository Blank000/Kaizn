# iOS build runbook (run on the Mac)

Everything iOS-side that could be prepared from Windows is already done on
`timetable`: Darwin notification init (fixes the launch crash), mic +
speech-recognition permission strings, Google Sign-In client id + URL
scheme in Info.plist, deployment target 13.0, iOS launcher icons
generated. The Mac only compiles and signs.

## One-time setup on the Mac
1. Install Xcode from the App Store, then:
   `sudo xcode-select --switch /Applications/Xcode.app` and open Xcode once
   to accept licenses / install components.
2. Install Flutter (same major version as Windows: check `flutter --version`
   here first) and CocoaPods: `sudo gem install cocoapods` (or
   `brew install cocoapods`).
3. `flutter doctor` until the Xcode row is green.

## Every-build steps
```bash
git clone <repo-url> && cd habit_reward_tracker   # or git pull
git checkout timetable
flutter pub get
cd ios && pod install && cd ..                     # generates Podfile on first run
open ios/Runner.xcworkspace                        # ALWAYS .xcworkspace, never .xcodeproj
```

In Xcode → Runner target → **Signing & Capabilities**:
- Team: your personal Apple ID team (free account works for device installs,
  app expires after 7 days; paid account for TestFlight).
- Bundle identifier: keep `com.alokraj.habitRewardTracker`-style unique id
  (whatever the project has; change only if the team rejects it).

Then either run from Xcode onto a plugged-in iPhone, or:
```bash
flutter run --release            # device attached
flutter build ipa                # paid account: produces the .ipa for TestFlight
```

## Podfile & recovery
`ios/Podfile` is committed and already pins `platform :ios, '13.0'` with
per-pod deployment targets (ported from the old ios-release branch) — no
generation step needed. If a build hits codesign / xattr / stale-Pods
errors, run the canonical reset: `bash tools/ios_reset.sh` (it also warns
if the project path contains a space — the classic silent killer).
`iOS_SETUP.md` in the repo root is the deeper first-Mac guide (Xcode
signing, Developer Mode, Google Sign-In OAuth gotchas) written during the
first real Mac attempt — use it if this runbook's happy path fails.

## Google Sign-In on iOS — verify once
Info.plist already carries `GIDClientID` and the reversed-client-id URL
scheme. Confirm in Google Cloud Console that this client id is an **iOS**
OAuth client for this bundle id; if sign-in bounces back instantly, create
an iOS OAuth client (same project as Android's), and swap both plist
values to the new id + its reversed form.

## Known iOS deltas vs Android (all acceptable for v1)
- **Exact alarms** are an Android concept; iOS schedules normally (may
  drift minutes under low power). No code change needed.
- **Notification action buttons** (Done/Skip/Snooze) are Android-only for
  now — iOS shows plain notifications. Porting needs Darwin categories;
  tracked, not blocking.
- **Speech-to-text** will show Apple's own mic + speech permission dialogs
  on first use of the Pico mic (strings already in Info.plist).
- Widget/live-activity style features: none used.

## Smoke-test list on the iPhone (10 minutes)
1. Launch (no crash = Darwin init works), onboarding, add a task.
2. Complete a task → points, Ignition on first win.
3. Google Sign-In → Drive backup "Back up now".
4. Notification settings → enable a toggle → iOS permission prompt →
   test a task reminder fires.
5. Pico: floating robot drag, chat (needs an OpenAI key), mic dictation,
   plan create → preview → apply.
6. Timeline drag, stack runner with Ren meditating, Sunday review.
7. Dark/light theme flip, share-progress card (share sheet).
