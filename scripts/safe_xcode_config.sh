#!/bin/bash
set -euo pipefail

echo "⚙️ Safely configuring Xcode project for CI signing..."

PROJECT_FILE="macos/Runner.xcodeproj/project.pbxproj"
BACKUP_FILE="${PROJECT_FILE}.backup"

if [[ ! -f "$PROJECT_FILE" ]]; then
    echo "❌ Project file not found: $PROJECT_FILE"
    exit 1
fi

if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
    echo "❌ APPLE_TEAM_ID environment variable not set"
    exit 1
fi

echo "📋 Team ID: $APPLE_TEAM_ID"
echo "💾 Creating backup..."
cp "$PROJECT_FILE" "$BACKUP_FILE"

# Use more precise sed with backup files
echo "🔧 Updating project settings..."
sed -i.bak1 "s/DEVELOPMENT_TEAM = 2KQDYWP72S;/DEVELOPMENT_TEAM = $APPLE_TEAM_ID;/g" "$PROJECT_FILE"
sed -i.bak2 "s/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Manual;/g" "$PROJECT_FILE"
sed -i.bak3 's/"CODE_SIGN_IDENTITY\[sdk=macosx\*\]" = "Mac Development"/"CODE_SIGN_IDENTITY[sdk=macosx*]" = ""/g' "$PROJECT_FILE"

# Clean up sed backup files
rm -f "$PROJECT_FILE".bak*

# Verify the file is still valid by checking basic structure
if grep -q "objects = {" "$PROJECT_FILE" && grep -q "rootObject = " "$PROJECT_FILE"; then
    echo "✅ Project file structure verified"
    echo "📝 Updated settings:"
    grep -E "(DEVELOPMENT_TEAM|CODE_SIGN_STYLE|CODE_SIGN_IDENTITY)" "$PROJECT_FILE" | head -3
else
    echo "❌ Project file appears corrupted, restoring backup..."
    cp "$BACKUP_FILE" "$PROJECT_FILE"
    exit 1
fi

echo "✅ Xcode project configured successfully"
