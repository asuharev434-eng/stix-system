#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/dist/STIX System.app"
[ -d "$APP" ] || ./scripts/build.sh
codesign --verify --deep --strict "$APP"
DEST="$HOME/Applications/STIX System.app"
if pgrep -x STIXSystem >/dev/null; then
    echo 'Quit STIX System before updating so its fan session can return to Auto.' >&2
    exit 1
fi
mkdir -p "$HOME/Applications"
if [ -x "$DEST/Contents/MacOS/STIXSystem" ] && [ "$(/usr/libexec/PlistBuddy -c 'Print STIXSupportsServiceCLI' "$DEST/Contents/Info.plist" 2>/dev/null || true)" = "true" ]; then
    SERVICE_STATUS="$("$DEST/Contents/MacOS/STIXSystem" --service-status)"
    if [ "$SERVICE_STATUS" = "1" ] || [ "$SERVICE_STATUS" = "2" ]; then
        "$DEST/Contents/MacOS/STIXSystem" --unregister-fan-service
    fi
fi
if [ -d "$DEST" ]; then
    BACKUP_DIR="$HOME/Library/Application Support/STIX System/Backups"
    mkdir -p "$BACKUP_DIR"
    BACKUP="$BACKUP_DIR/STIX-System-$(date +%Y%m%d-%H%M%S).bundlebackup"
    mv "$DEST" "$BACKUP"
fi
ditto "$APP" "$DEST"
codesign --verify --deep --strict "$DEST"
open "$DEST"
printf '\nInstalled: %s\n' "$DEST"
