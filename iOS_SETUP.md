# iOS setup — first-time on a fresh Mac

Follow this once when bringing the project onto a Mac for the first time. Each
step assumes the previous one succeeded.

## 0. Path warning

**Do not put the project at a path that contains a space.** Apple's codesign
tool and several Flutter build phases choke on spaces. Use something like:

```
~/Projects/Kaizn
```

Not:

```
~/Documents/Github Projects/Kaizn       ← will cause "codesign failed" loops
```

If you already cloned it under a spaced path, move it:

```bash
mv "/Users/USER/Documents/Github Projects/Kaizn" ~/Projects/Kaizn
cd ~/Projects/Kaizn
```

## 1. Install Flutter + Xcode + CocoaPods

```bash
brew install --cask flutter
brew install cocoapods
```

Install Xcode from the Mac App Store. After it installs:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```

Check everything's green:

```bash
flutter doctor
```

## 2. Open Xcode once and sign in

- Launch Xcode
- Xcode → Settings → Accounts → `+` → Apple ID → sign in
- Xcode will provision your developer certificate

## 3. Get the project building

From the project root:

```bash
flutter pub get
cd ios && pod install && cd ..
```

## 4. Open the workspace in Xcode and set the Team

```bash
open ios/Runner.xcworkspace
```

In Xcode:
1. Left sidebar → click the blue **Runner** at the top
2. Center pane → TARGETS → **Runner**
3. Top tab row → **Signing & Capabilities**
4. Tick **Automatically manage signing**
5. **Team** dropdown → pick your Apple ID (will show as "Personal Team" for free accounts)

If you see a red "bundle identifier not available" error, change the Bundle
Identifier to something unique (e.g. `com.yourname.kaizn`). NOTE: if you
change the bundle ID, you also need to create a new iOS OAuth Client in
Google Cloud Console matching the new ID, and update `ios/Runner/Info.plist`'s
`GIDClientID` and the reversed URL scheme.

## 5. Enable Developer Mode on the iPhone (iOS 16+)

Plug iPhone in. On the iPhone:

- Settings → Privacy & Security → **Developer Mode** → ON → restart
- After restart, confirm with passcode

## 6. Run

```bash
flutter devices                              # find your iPhone's ID
flutter run -d <iphone-id>
```

On first launch on the phone:
- Settings → General → VPN & Device Management → tap your Apple Development
  cert → **Trust**
- Tap the app icon to launch

## Troubleshooting

### Build fails with codesign / xattr / Pods errors

Run:

```bash
bash tools/ios_reset.sh
flutter run -d <iphone-id>
```

That script strips macOS extended attributes, wipes Pods, reinstalls
everything, and warns if your project path has a space.

### "Unable to find a destination matching … iOS X.Y is not installed"

Your iPhone's iOS version is newer than the SDK on your Mac.
Open Xcode → Settings → **Components** (or **Platforms**) → download the
matching iOS SDK. ~5 GB download.

### "Wireless debugging on iOS 26 may be slower than expected"

Yes, wireless deploys on iOS 26 are flaky. Use a USB cable when possible.
The phone must stay unlocked the entire install + launch cycle.

### Google Sign-In: "Access blocked"

The OAuth consent screen needs your Gmail in the Test Users list:
Google Cloud Console → APIs & Services → OAuth consent screen → Test users
→ `+ Add Users` → paste your Gmail.

### Google Sign-In: nothing happens / DEVELOPER_ERROR

The iOS OAuth Client's Bundle ID doesn't match the Xcode project's bundle ID.
Open Xcode → Runner target → General → check Bundle Identifier matches what's
in Google Cloud Console → Credentials → iOS Client.
