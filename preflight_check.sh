#!/bin/bash
set -euo pipefail

# ----------------------------
# CONFIGURATION
# ----------------------------
APP_NAME="Pinboard Wizard"
APP_PATH="release/$APP_NAME.app"
TEAM_ID="Y4BC88SNUY"
IDENTIFIER="com.yourname.pinboardwizard" # <-- update to your actual bundle ID
ENTITLEMENTS="entitlements.plist"

# ----------------------------
# CHECK 1: Developer ID Certificate
# ----------------------------
echo "🔍 Checking for Developer ID Application certificate..."
if security find-identity -p codesigning -v | grep -q "Developer ID Application"; then
    echo "✅ Developer ID Application certificate found."
else
    echo "❌ ERROR: No 'Developer ID Application' certificate found in keychain."
    echo "   Please install it from Apple Developer account."
    exit 1
fi

# ----------------------------
# CHECK 2: Flutter build exists
# ----------------------------
echo "🔍 Checking Flutter macOS build..."
if [ ! -d "$APP_PATH" ]; then
    echo "❌ ERROR: $APP_PATH does not exist."
    echo "   Run: flutter build macos --release"
    exit 1
fi
echo "✅ Flutter build found."

# ----------------------------
# CHECK 3: Info.plist metadata
# ----------------------------
echo "🔍 Checking Info.plist..."
PLIST="$APP_PATH/Contents/Info.plist"

if ! plutil -p "$PLIST" >/dev/null 2>&1; then
    echo "❌ ERROR: Info.plist is missing or invalid."
    exit 1
fi

BUNDLE_ID=$(defaults read "$APP_PATH/Contents/Info" CFBundleIdentifier 2>/dev/null || echo "MISSING")
VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "MISSING")
BUILD=$(defaults read "$APP_PATH/Contents/Info" CFBundleVersion 2>/dev/null || echo "MISSING")

if [ "$BUNDLE_ID" != "$IDENTIFIER" ]; then
    echo "⚠️ WARNING: Bundle identifier mismatch."
    echo "   Expected: $IDENTIFIER"
    echo "   Found:    $BUNDLE_ID"
fi

echo "✅ Info.plist OK: ID=$BUNDLE_ID, Version=$VERSION, Build=$BUILD"

# ----------------------------
# CHECK 4: Entitlements file
# ----------------------------
echo "🔍 Checking entitlements..."
if [ ! -f "$ENTITLEMENTS" ]; then
    echo "⚠️ WARNING: No $ENTITLEMENTS file found."
    echo "   Notarization usually requires one if you use runtime options."
else
    echo "✅ Entitlements file found."
fi

# ----------------------------
# CHECK 5: Keychain access
# ----------------------------
echo "🔍 Checking keychain unlock status..."
if security show-keychain-info ~/Library/Keychains/login.keychain-db >/dev/null 2>&1; then
    echo "✅ Keychain is accessible."
else
    echo "⚠️ WARNING: Keychain may be locked. Unlock with:"
    echo "   security unlock-keychain -p <password> ~/Library/Keychains/login.keychain-db"
fi

# ----------------------------
# CHECK 6: Local Gatekeeper assessment (unsigned app)
# ----------------------------
echo "🔍 Checking Gatekeeper assessment..."
if spctl --assess --type execute "$APP_PATH" >/dev/null 2>&1; then
    echo "✅ App is acceptable by Gatekeeper (pre-signing)."
else
    echo "⚠️ App may fail Gatekeeper assessment before signing — this is normal for unsigned apps."
fi

echo ""
echo "✨ Pre-flight check complete! You can now run your signing + notarization script."
