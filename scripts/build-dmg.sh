#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UI_DIR="$ROOT_DIR/ui"
CLI_DIR="$ROOT_DIR/cli"

PRODUCT_NAME="ShellGuard"
APP_NAME="${PRODUCT_NAME}.app"
DMG_NAME="${PRODUCT_NAME}.dmg"
STAGING_DIR="/tmp/${PRODUCT_NAME}-staging"
OUT_DIR="$ROOT_DIR/dist"

echo "→ Building Go CLI..."
cd "$CLI_DIR"
go build -o shellguard ./cmd/shellguard/
echo "  CLI built: $CLI_DIR/shellguard"

echo "→ Building Swift UI..."
cd "$UI_DIR"
swift build -c release 2>&1 | grep -v "^warning:"
echo "  UI built: $UI_DIR/.build/release/ShellGuardUIApp"

echo "→ Assembling app bundle..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/$APP_NAME/Contents/MacOS"
mkdir -p "$STAGING_DIR/$APP_NAME/Contents/Resources"

# Binaries
cp "$UI_DIR/.build/release/ShellGuardUIApp"  "$STAGING_DIR/$APP_NAME/Contents/MacOS/ShellGuardUIApp"
cp "$CLI_DIR/shellguard"                     "$STAGING_DIR/$APP_NAME/Contents/MacOS/shellguard"
chmod +x "$STAGING_DIR/$APP_NAME/Contents/MacOS/ShellGuardUIApp"
chmod +x "$STAGING_DIR/$APP_NAME/Contents/MacOS/shellguard"

# Info.plist
cp "$UI_DIR/Info.plist" "$STAGING_DIR/$APP_NAME/Contents/Info.plist"

# App icon (AppIcon.icns → Contents/Resources/)
ICON_SRC="$UI_DIR/Resources/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$STAGING_DIR/$APP_NAME/Contents/Resources/AppIcon.icns"
    echo "  Icon copied ✓"
else
    echo "  WARNING: AppIcon.icns not found at $ICON_SRC"
fi

# /Applications symlink for DMG drag-install
ln -sf /Applications "$STAGING_DIR/Applications"

echo "→ Signing app bundle..."
ENTITLEMENTS="$ROOT_DIR/ui/ShellGuardUIApp-dmg.entitlements"

# Use Developer ID if available, otherwise fall back to ad-hoc
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')

if [ -n "$IDENTITY" ]; then
    echo "  Using Developer ID: $IDENTITY"
    # Sign the Go CLI binary first (no entitlements needed)
    codesign --force --options runtime \
        --sign "$IDENTITY" \
        "$STAGING_DIR/$APP_NAME/Contents/MacOS/shellguard"
    echo "  CLI binary signed ✓"
    # Sign the full app bundle with entitlements
    codesign --deep --force \
        --sign "$IDENTITY" \
        --entitlements "$ENTITLEMENTS" \
        --options runtime \
        "$STAGING_DIR/$APP_NAME"
    echo "  App bundle signed ✓"
else
    echo "  No Developer ID found — using ad-hoc signing"
    codesign --deep --force --sign - "$STAGING_DIR/$APP_NAME"
    echo "  Signed (ad-hoc)"
fi

echo "→ Creating DMG..."
mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/$DMG_NAME"

hdiutil create \
    -volname "$PRODUCT_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    -o "$OUT_DIR/$DMG_NAME"

rm -rf "$STAGING_DIR"

# Sign the DMG itself (required for notarization)
if [ -n "$IDENTITY" ]; then
    echo "→ Signing DMG..."
    codesign --sign "$IDENTITY" "$OUT_DIR/$DMG_NAME"
    echo "  DMG signed ✓"

    # Notarize the DMG if credentials are set
    if [ -n "$APPLE_ID" ] && [ -n "$APPLE_TEAM_ID" ] && [ -n "$APPLE_APP_PASSWORD" ]; then
        echo "→ Notarizing DMG (this takes 2-5 minutes)..."
        xcrun notarytool submit "$OUT_DIR/$DMG_NAME" \
            --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" \
            --password "$APPLE_APP_PASSWORD" \
            --wait
        xcrun stapler staple "$OUT_DIR/$DMG_NAME"
        echo "  Notarized & stapled ✓"
    else
        echo "  Skipping notarization (set APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD to enable)"
    fi
fi

echo ""
echo "✓ Done: $OUT_DIR/$DMG_NAME"
