#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Override SIGN_IDENTITY with a Developer ID Application identity for distribution.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
swift build --build-system native -c release
BIN_DIR="$(swift build --build-system native -c release --show-bin-path)"
mkdir -p "$PWD/dist"
STAGING="$(mktemp -d "$PWD/dist/.stix-build.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/STIX System.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/HelperTools" "$APP/Contents/Library/LaunchDaemons"
cp "$BIN_DIR/STIXSystem" "$APP/Contents/MacOS/"
cp "$BIN_DIR/STIXFanService" "$APP/Contents/Library/HelperTools/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/ru.stix.system.fans.plist "$APP/Contents/Library/LaunchDaemons/"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --sign - --identifier ru.stix.system.fans "$APP/Contents/Library/HelperTools/STIXFanService"
    codesign --force --sign - --identifier ru.stix.system "$APP"
else
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp --identifier ru.stix.system.fans "$APP/Contents/Library/HelperTools/STIXFanService"
    codesign --force --sign "$SIGN_IDENTITY" --options runtime --timestamp --identifier ru.stix.system "$APP"
fi
codesign --verify --deep --strict "$APP"
DEST="$PWD/dist/STIX System.app"
if [ -d "$DEST" ]; then mv "$DEST" "$STAGING/Previous.app"; fi
mv "$APP" "$DEST"
printf '\nBuilt: %s\n' "$DEST"
