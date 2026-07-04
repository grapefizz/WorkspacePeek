#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_NAME="WorkspacePeek"
APP_NAME="WorkspacePeek.app"
APP_PATH="/Applications/$APP_NAME"
BUNDLE_ID="com.example.workspacepeek"
SIGN_IDENTITY="-"

echo "==> Building $BINARY_NAME..."
cd "$SCRIPT_DIR"
swift build -c release 2>&1

BUILT_BINARY="$SCRIPT_DIR/.build/release/$BINARY_NAME"
if [ ! -f "$BUILT_BINARY" ]; then
    echo "ERROR: Build failed"
    exit 1
fi

echo "==> Assembling .app bundle..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BUILT_BINARY" "$APP_PATH/Contents/MacOS/$BINARY_NAME"
chmod +x "$APP_PATH/Contents/MacOS/$BINARY_NAME"
cp "$SCRIPT_DIR/Info.plist" "$APP_PATH/Contents/Info.plist"

echo "==> Signing .app bundle..."
codesign --force --deep \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$SCRIPT_DIR/WorkspacePeek.entitlements" \
    --options runtime \
    "$APP_PATH"

echo "==> Seeding tunable badge config..."
BADGE_DIR="$HOME/.config/workspacepeek"
mkdir -p "$BADGE_DIR"
if [ ! -f "$BADGE_DIR/badge.json" ]; then
cat > "$BADGE_DIR/badge.json" << 'JSON'
{
  "bubbleSize": 26,
  "cornerRadius": 5,
  "spacing": 5,
  "fontSize": 15,
  "glyphYOffset": 0,
  "glyphXOffset": 0,
  "insetX": 10,
  "insetY": 10,
  "selBorderWidth": 3,
  "selGlowRadius": 12,
  "selGlowOpacity": 0.9,
  "titleText": "˚ ₊‧꒰ა  ✦ ˚  · ˚  workspaces  ˚ ·  ˚ ✦  ໒꒱ ‧₊˚",
  "titleFontSize": 18,
  "showTitle": true
}
JSON
else
  echo "    (badge.json exists - leaving your tuned values untouched)"
fi

echo "==> Removing old launchd plist if present..."
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.user.workspacepeek.plist 2>/dev/null || true
rm -f ~/Library/LaunchAgents/com.user.workspacepeek.plist

echo "==> Launching app (will register as Login Item automatically)..."
# Kill any existing instance
pkill -x WorkspacePeek 2>/dev/null || true
sleep 0.5
open "$APP_PATH"

echo ""
echo "✓ WorkspacePeek.app installed to /Applications!"
echo ""
echo "  Trigger:  Option + W"
echo "  Dismiss:  ESC, click outside, or Option + W again"
echo "  Switch:   number keys (1-9) or arrow keys + Enter or click"
echo ""
echo "  On first launch, grant Accessibility + Screen Recording in"
echo "  System Settings → Privacy & Security."
echo ""
echo "  The app registers itself as a Login Item automatically."
echo "  To remove it: System Settings → General → Login Items"
