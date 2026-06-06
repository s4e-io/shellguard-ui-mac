#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

PRODUCT_NAME="ShellGuard"
APP_NAME="${PRODUCT_NAME}.app"
PKG_NAME="${PRODUCT_NAME}.pkg"
STAGING_DIR="/tmp/${PRODUCT_NAME}-appstore-staging"
OUT_DIR="$ROOT_DIR/dist"

# ── Identity & provisioning ───────────────────────────────────────────────────
# Set these to match your Apple Developer account.
# APP_IDENTITY: "Apple Distribution: Your Name (TEAMID)"
# PKG_IDENTITY: "3rd Party Mac Developer Installer: Your Name (TEAMID)"
# PROVISION_PROFILE: path to your .provisionprofile downloaded from developer.apple.com
APP_IDENTITY="${APP_IDENTITY:-Apple Distribution: Your Name (TEAMID)}"
PKG_IDENTITY="${PKG_IDENTITY:-3rd Party Mac Developer Installer: Your Name (TEAMID)}"
ENTITLEMENTS="$ROOT_DIR/ShellGuardUIApp.entitlements"
PROVISION_PROFILE="${PROVISION_PROFILE:-$HOME/Desktop/ShellGuard_Mac_App_Store.provisionprofile}"

echo "→ Building Go CLI..."
cd "$CLI_DIR"
go build -o shellguard ./cmd/shellguard/
echo "  CLI built ✓"

echo "→ Building Swift UI..."
cd "$UI_DIR"
swift build -c release 2>&1 | grep -v "^warning:" | grep -v "^$"
echo "  UI built ✓"

echo "→ Assembling app bundle..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/$APP_NAME/Contents/MacOS"
mkdir -p "$STAGING_DIR/$APP_NAME/Contents/Resources"

cp "$UI_DIR/.build/release/ShellGuardUIApp" "$STAGING_DIR/$APP_NAME/Contents/MacOS/ShellGuardUIApp"
cp "$CLI_DIR/shellguard"                    "$STAGING_DIR/$APP_NAME/Contents/MacOS/shellguard"
chmod +x "$STAGING_DIR/$APP_NAME/Contents/MacOS/ShellGuardUIApp"
chmod +x "$STAGING_DIR/$APP_NAME/Contents/MacOS/shellguard"
cp "$UI_DIR/Info.plist" "$STAGING_DIR/$APP_NAME/Contents/Info.plist"

# App icon
if [ -f "$UI_DIR/Resources/AppIcon.icns" ]; then
    cp "$UI_DIR/Resources/AppIcon.icns" "$STAGING_DIR/$APP_NAME/Contents/Resources/AppIcon.icns"
    echo "  Icon copied ✓"
fi

# Embed provisioning profile
cp "$PROVISION_PROFILE" "$STAGING_DIR/$APP_NAME/Contents/embedded.provisionprofile"

echo "→ Signing for App Store..."
# Sign CLI binary first (no entitlements)
codesign --force --options runtime \
    --sign "$APP_IDENTITY" \
    "$STAGING_DIR/$APP_NAME/Contents/MacOS/shellguard"
echo "  CLI signed ✓"

# Sign full app bundle with entitlements
codesign --deep --force \
    --sign "$APP_IDENTITY" \
    --entitlements "$ENTITLEMENTS" \
    --options runtime \
    "$STAGING_DIR/$APP_NAME"
echo "  App bundle signed ✓"

# Verify
codesign --verify --deep --strict "$STAGING_DIR/$APP_NAME" && echo "  Verification passed ✓"

echo "→ Creating .pkg..."
mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/$PKG_NAME"

productbuild \
    --component "$STAGING_DIR/$APP_NAME" /Applications \
    --sign "$PKG_IDENTITY" \
    "$OUT_DIR/$PKG_NAME"

rm -rf "$STAGING_DIR"

echo ""
echo "✓ Done: $OUT_DIR/$PKG_NAME"
echo ""
echo "Upload with:"
echo "  xcrun altool --upload-app -f $OUT_DIR/$PKG_NAME -t macos --apiKey <KEY> --apiIssuer <ISSUER>"
echo "  or drag into Transporter.app"
