#!/bin/bash

# ====================================================================
# Clean Build Script for Pinboard Wizard macOS App (Target: macOS 15.0)
# ====================================================================

set -e  # Exit on any error

# Configuration
APP_NAME="pinboard_wizard"
BUILD_DIR="build/macos/Build/Products/Release"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}➡️ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

# Function to check for errors
check_error() {
    if [ $? -ne 0 ]; then
        print_error "$1"
    fi
}

echo "====================================================="
echo "🏗️  Clean Build Script for Pinboard Wizard (macOS 15.0)"
echo "====================================================="

# 1. Clean previous builds
print_status "Cleaning previous builds..."
flutter clean
check_error "Flutter clean failed"

# 2. Get dependencies
print_status "Getting Flutter dependencies..."
flutter pub get
check_error "Flutter pub get failed"

# 3. Generate code if needed
print_status "Generating code..."
dart run build_runner build --delete-conflicting-outputs
check_error "Code generation failed"

# 4. Clean macOS build specifically
print_status "Cleaning macOS build artifacts..."
rm -rf build/macos
rm -rf macos/Flutter/ephemeral
rm -rf macos/.symlinks

# 5. Update CocoaPods
print_status "Updating CocoaPods..."
cd macos
pod repo update
pod install --repo-update
cd ..
check_error "CocoaPods update failed"

# 6. Build the release app
print_status "Building macOS release app..."
flutter build macos --release --verbose
check_error "Flutter build failed"

# 7. Verify the build
if [ ! -d "$APP_PATH" ]; then
    print_error "App bundle not found at '$APP_PATH'. Build may have failed."
fi

print_success "App bundle created successfully at: $APP_PATH"

# 8. Check app structure
print_status "Verifying app bundle structure..."
if [ ! -d "$APP_PATH/Contents/Frameworks" ]; then
    print_warning "Frameworks directory not found. This may cause runtime issues."
else
    print_success "Frameworks directory exists"
    echo "Available frameworks:"
    ls -la "$APP_PATH/Contents/Frameworks/" | grep -E "\\.framework|\\.dylib"
fi

# 9. Check for required frameworks
print_status "Checking for critical frameworks..."
CRITICAL_FRAMEWORKS=("FlutterMacOS.framework" "appkit_ui_element_colors.framework")
for framework in "${CRITICAL_FRAMEWORKS[@]}"; do
    if [ -d "$APP_PATH/Contents/Frameworks/$framework" ]; then
        print_success "Found: $framework"
    else
        print_warning "Missing: $framework"
    fi
done

# 10. Test the app can start (basic check)
print_status "Testing app launch (will quit immediately)..."
timeout 5s "$APP_PATH/Contents/MacOS/$APP_NAME" --help > /dev/null 2>&1 || true
if [ $? -eq 124 ]; then
    print_success "App appears to launch correctly"
else
    print_warning "App may have launch issues - recommend testing manually"
fi

echo
echo "====================================================="
print_success "🎉 Clean build completed successfully!"
echo "App location: $APP_PATH"
echo "Next step: Run './local_publish_script.sh' to sign and notarize"
echo "====================================================="
