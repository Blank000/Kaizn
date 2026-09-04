#!/usr/bin/env bash
# Canonical "wipe everything iOS-related and rebuild from scratch" script.
# Run from project root: bash tools/ios_reset.sh
#
# Use this whenever an iOS build fails with codesign / xattr / missing-Pods
# errors. Idempotent.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "→ Project: $PROJECT_ROOT"

if [[ "$PROJECT_ROOT" == *" "* ]]; then
  echo "⚠️  Your project path contains a SPACE: '$PROJECT_ROOT'"
  echo "    This is a known cause of iOS codesign failures."
  echo "    Move the project to a path WITHOUT spaces (e.g. ~/Projects/Kaizn)"
  echo "    before continuing if you keep hitting build errors."
  echo ""
fi

echo "→ Stripping macOS extended attributes from the project…"
xattr -cr . || true

echo "→ flutter clean"
flutter clean

echo "→ flutter pub get"
flutter pub get

echo "→ Wiping ios/Pods and ios/Podfile.lock"
rm -rf ios/Pods ios/Podfile.lock

echo "→ pod install (in ios/)"
cd ios
pod install --repo-update
cd ..

echo ""
echo "✓ Reset complete. Now run:"
echo "    flutter run -d <your-iphone-id>"
echo ""
echo "  (use 'flutter devices' to find the id)"
