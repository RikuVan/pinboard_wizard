# Development Setup Guide

## Flutter Version Management

This project uses **FVM (Flutter Version Manager)** to ensure consistent Flutter versions across development environments.

### Required Flutter Version

- **Flutter**: 3.38.5
- **Dart**: 3.10.4

### Installing FVM

If you don't have FVM installed:

```bash
# macOS/Linux
brew tap leoafarias/fvm
brew install fvm

# Or using pub
dart pub global activate fvm
```

### Project Setup

1. **Install the correct Flutter version:**
   ```bash
   fvm install 3.38.5
   ```

2. **Use FVM for this project:**
   ```bash
   cd pinboard_wizard
   fvm use 3.38.5
   ```

3. **Install dependencies:**
   ```bash
   fvm flutter pub get
   ```

4. **Clean build (if needed):**
   ```bash
   fvm flutter clean
   fvm flutter pub get
   ```

### Running the App

Always prefix Flutter commands with `fvm`:

```bash
# Run the app
fvm flutter run

# Run tests
fvm flutter test

# Analyze code
fvm flutter analyze

# Build for macOS
fvm flutter build macos
```

### IDE Configuration

#### VS Code

Add to `.vscode/settings.json`:

```json
{
  "dart.flutterSdkPath": ".fvm/flutter_sdk",
  "search.exclude": {
    "**/.fvm": true
  },
  "files.watcherExclude": {
    "**/.fvm": true
  }
}
```

#### IntelliJ IDEA / Android Studio

1. Open Preferences → Languages & Frameworks → Flutter
2. Set Flutter SDK path to: `<project-path>/.fvm/flutter_sdk`

### Why FVM?

- **Consistency**: Everyone uses the same Flutter version
- **Stability**: Avoid breaking changes from newer Flutter releases
- **Isolation**: Different projects can use different Flutter versions
- **Easy switching**: Switch between Flutter versions per project

### Troubleshooting

#### "Command not found: fvm"

Make sure FVM is in your PATH. If installed via pub:

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

Add to `~/.zshrc` or `~/.bash_profile` to make permanent.

#### Build errors after Flutter upgrade

```bash
fvm flutter clean
fvm flutter pub get
# Delete derived data (macOS)
rm -rf ~/Library/Developer/Xcode/DerivedData
```

#### Wrong Flutter version being used

Check which Flutter is being used:

```bash
which flutter  # Should NOT use this
fvm flutter --version  # Always use fvm prefix
```

### Important Notes

- **Always use `fvm flutter`** instead of just `flutter`
- The `.fvm` directory is git-ignored
- Each developer must run `fvm use 3.38.5` in their local clone
- CI/CD should also use FVM for consistency

### Dependencies

Current dependency versions (as of December 2024):

```yaml
dependencies:
  flutter: sdk: flutter
  macos_ui: ^2.2.2
  drift: ^2.14.0
  flutter_bloc: ^9.1.1
  get_it: ^9.2.0
  timeago: ^3.7.0
  # ... see pubspec.yaml for full list

dev_dependencies:
  build_runner: ^2.7.1
  drift_dev: ^2.14.0
  mockito: ^5.4.4
  bloc_test: ^10.0.0
```

### Building for Release

```bash
# macOS Release Build
fvm flutter build macos --release

# The app will be in:
# build/macos/Build/Products/Release/pinboard_wizard.app
```

---

For more information on FVM, see: https://fvm.app
