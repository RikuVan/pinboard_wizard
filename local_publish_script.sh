#!/bin/bash

# ====================================================================
# --- Configuration & Environment Check ---
# ====================================================================

# ⚠️ This script relies on environment variables being set (e.g., via 'source ./.env'):
#    APPLE_ID, TEAM_ID, APP_SPECIFIC_PASSWORD, DEVELOPER_ID_NAME

# Check if required environment variables are set
if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$APP_SPECIFIC_PASSWORD" ] || [ -z "$DEVELOPER_ID_NAME" ]; then
    echo "❌ ERROR: One or more required environment variables are not set." >&2
    echo "Please set: APPLE_ID, TEAM_ID, APP_SPECIFIC_PASSWORD, and DEVELOPER_ID_NAME." >&2
    exit 1
fi

# The full DEVELOPER_ID string is constructed from the ENV vars
DEVELOPER_ID="$DEVELOPER_ID_NAME ($TEAM_ID)"

# App-specific details
APP_NAME="pinboard_wizard"
BUILD_DIR="build/macos/Build/Products/Release"

# File Paths
APP_PATH="$BUILD_DIR/$APP_NAME.app"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"
ENTITLEMENTS_PATH="macos/Runner/Release.entitlements" # NOTE: Ensure this file has the hardcoded Team ID
ZIP_DIR="release"
ZIP_NAME_FINAL="${APP_NAME}.zip"
ZIP_PATH="$ZIP_DIR/$ZIP_NAME_FINAL"

# --- Script Functions ---

# Function to check for errors
check_error() {
    if [ $? -ne 0 ]; then
        echo "❌ ERROR: $1" >&2
        exit 1
    fi
}

# Function to verify code signature
verify_signature() {
    echo "🔎 Verifying code signature for: $1"
    codesign -vvv --deep --strict "$1"
    check_error "Code signature verification failed for $1."
}

# ====================================================================
# --- Execution Starts Here ---
# ====================================================================

echo "====================================================="
echo "🚀 Starting Notarization Process for '$APP_NAME.app'"
echo "   Using Developer ID: $DEVELOPER_ID"
echo "====================================================="

# 1. Check existence of built app
if [ ! -d "$APP_PATH" ]; then
    echo "❌ ERROR: App bundle not found at '$APP_PATH'."
    echo "Please run 'flutter build macos --release' first."
    exit 1
fi
echo "✅ Found app bundle: $APP_PATH"

## Code Signing Steps (Steps 2-5 remain the same and are critical for success)

# 2. Sign frameworks and nested components (Inner to Outer)
echo
echo "➡️ Signing embedded frameworks and components..."
find "$APP_PATH/Contents/Frameworks" -name "*.framework" -type d | while read -r framework; do
    echo "→ Signing framework bundle deeply: $framework"
    codesign --force --verify --verbose --timestamp --options runtime --deep \
        --entitlements "$ENTITLEMENTS_PATH" \
        -s "$DEVELOPER_ID" "$framework"
    check_error "Framework signing failed for $framework."
done

# 3. Sign the main executable
echo
echo "➡️ Signing the main executable: $EXECUTABLE_PATH"
codesign --force --verify --verbose --timestamp --options runtime \
    --entitlements "$ENTITLEMENTS_PATH" \
    -s "$DEVELOPER_ID" "$EXECUTABLE_PATH"
check_error "Main executable signing failed."

# 4. Sign the entire application bundle
echo
echo "➡️ Signing the entire application bundle: $APP_PATH"
codesign --force --verify --verbose --timestamp --options runtime \
    --entitlements "$ENTITLEMENTS_PATH" \
    -s "$DEVELOPER_ID" "$APP_PATH"
check_error "App bundle signing failed."

# 5. Final Code Signature Verification
echo
verify_signature "$APP_PATH"

# 6. Create zip for notarization
echo
echo "➡️ Creating zip archive for notarization: $ZIP_PATH"
mkdir -p "$ZIP_DIR"
ditto -c -k --rsrc --keepParent "$APP_PATH" "$ZIP_PATH"
check_error "Failed to create zip file."
echo "✅ Zip created: $(ls -lh "$ZIP_PATH" | awk '{print $5}') - $ZIP_PATH"

# 7. Submit for notarization
echo
echo "➡️ Submitting '$ZIP_PATH' for notarization (This may take several minutes)..."
SUBMISSION_OUTPUT=$(
    xcrun notarytool submit "$ZIP_PATH" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_SPECIFIC_PASSWORD" \
        --wait
)
# Note: No check_error here. We rely on the output status (Accepted/Invalid).

echo "$SUBMISSION_OUTPUT"

# 💥 FIX: Use a robust method to reliably extract the final status (Accepted or Invalid).
# We search for the "status: " line and extract the second word.
SUBMISSION_STATUS=$(echo "$SUBMISSION_OUTPUT" | grep 'status: ' | tail -n 1 | awk '{print $2}')


if [ "$SUBMISSION_STATUS" == "Accepted" ]; then
    echo "✅ Notarization **ACCEPTED** by Apple."

    # 8. Staple the ticket to the app bundle
    echo
    echo "➡️ Stapling the notarization ticket to the app bundle..."
    xcrun stapler staple "$APP_PATH"
    check_error "Stapling failed."
    echo "✅ Stapling complete. The application is ready for distribution."
else
    # 9. Get detailed log on failure

    echo
    echo "❌ Notarization **INVALID**."

    # 💥 FIX: Use a robust grep to extract the UUID, avoiding line breaks.
    SUBMISSION_ID=$(echo "$SUBMISSION_OUTPUT" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | tail -n 1)

    echo "Attempting to retrieve detailed log for Submission ID: $SUBMISSION_ID"

    # Save the log to a file for review
    LOG_FILE="notarization_log_$SUBMISSION_ID.json"
    xcrun notarytool log "$SUBMISSION_ID" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_SPECIFIC_PASSWORD" > "$LOG_FILE"

    echo "⚠️ Detailed log saved to: $LOG_FILE"
    echo "Please review the log for specific errors (e.g., Hardened Runtime, Framework signing) and re-run."
    exit 1
fi

echo
echo "====================================================="
echo "🎉 Notarization and Stapling COMPLETE"
echo "====================================================="
