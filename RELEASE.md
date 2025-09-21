# Release Instructions

This document outlines the process for creating and publishing releases of Pinboard Wizard.

## Prerequisites

- [ ] All tests are passing locally (`flutter test`)
- [ ] Code analysis is clean (`flutter analyze`)
- [ ] App builds successfully in release mode (`flutter build macos --release`)
- [ ] Manual testing completed on macOS
- [ ] Version number updated in `pubspec.yaml`
- [ ] CHANGELOG.md updated with new features/fixes

## Release Process

### 1. Prepare the Release

1. **Update version number** in `pubspec.yaml`:

   ```yaml
   version: 1.2.0+1 # Update both version and build number
   ```

2. **Update CHANGELOG.md** with release notes:

   ```markdown
   ## [1.2.0] - 2024-01-15

   ### Added

   - New categorized pin system
   - Dynamic category suggestions

   ### Fixed

   - Dialog overflow issues
   ```

3. **Commit and push changes**:
   ```bash
   git add .
   git commit -m "chore: bump version to 1.2.0"
   git push origin main
   ```

### 2. Create GitHub Release

1. **Go to GitHub Releases page**: https://github.com/richardvancamp/pinboard_wizard/releases

2. **Click "Create a new release"**

3. **Fill in release details**:
   - **Tag version**: `v1.2.0` (must start with 'v')
   - **Release title**: `Pinboard Wizard v1.2.0`
   - **Description**: Copy from CHANGELOG.md and enhance with:

     ```markdown
     ## What's New

     - 🎯 **Categorized Pinning**: Pin bookmarks with categories like `pin:work`, `pin:reading`
     - 🤖 **AI-Enhanced Metadata**: Cost-controlled AI analysis using your OpenAI key
     - ☁️ **AWS S3 Backup**: Direct backup to your own S3 bucket

     ## Installation

     Download the `.tar.gz` file below and extract to Applications folder.

     ## Full Changelog

     [Copy relevant sections from CHANGELOG.md]
     ```

4. **Publish release** (don't check "pre-release" for stable releases)

### 3. Automated Build Process

Once you publish the release, GitHub Actions will automatically:

1. **Build the macOS app** in release mode
2. **Create tarball** with proper naming: `pinboard-wizard-v1.2.0-macos.tar.gz`
3. **Calculate SHA256** hash for verification
4. **Upload tarball** as release asset
5. **Update release notes** with download and installation instructions

### 4. Manual Installation Testing

Download and test the release tarball:

```bash
# Download the tarball
curl -L https://github.com/richardvancamp/pinboard_wizard/releases/download/v1.2.0/pinboard-wizard-v1.2.0-macos.tar.gz -o pinboard-wizard.tar.gz

# Extract and test
tar -xzf pinboard-wizard.tar.gz
open "Pinboard Wizard.app"
```

## Post-Release Tasks

- [ ] Test manual installation from tarball
- [ ] Verify app launches correctly from Applications
- [ ] Test that app displays as "Pinboard Wizard" in system UI
- [ ] Update documentation if needed
- [ ] Announce release on relevant channels

## Troubleshooting

### Build Fails in GitHub Actions

1. Check the Actions tab for error details
2. Common issues:
   - **Code signing**: Verify automatic signing is enabled
   - **Dependencies**: Check if any new dependencies need setup
   - **Tests failing**: Fix tests before releasing

### SHA256 Verification Issues

1. **Wrong SHA256**: Download the tarball and recalculate:

   ```bash
   shasum -a 256 pinboard-wizard-v1.2.0-macos.tar.gz
   ```

2. **Installation verification**: Test locally:
   ```bash
   tar -xzf pinboard-wizard-v1.2.0-macos.tar.gz
   mv "Pinboard Wizard.app" /Applications/
   open -a "Pinboard Wizard"
   ```

### App Won't Launch After Install

1. Check codesigning: `codesign -dv "Pinboard Wizard.app"`
2. Verify entitlements match build configuration
3. Test with Gatekeeper: System Preferences → Security & Privacy

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **Major** (1.0.0 → 2.0.0): Breaking changes, major new features
- **Minor** (1.0.0 → 1.1.0): New features, backward compatible
- **Patch** (1.0.0 → 1.0.1): Bug fixes, backward compatible

Flutter build numbers should increment with each release:

- `1.0.0+1` → `1.0.1+2` → `1.1.0+3` → etc.

## Release Checklist Template

Copy this for each release:

```markdown
## Release v1.x.x Checklist

### Pre-Release

- [ ] Version updated in pubspec.yaml
- [ ] CHANGELOG.md updated
- [ ] All tests passing
- [ ] Flutter analyze clean
- [ ] Manual testing completed
- [ ] Changes committed and pushed

### Release

- [ ] GitHub release created
- [ ] Tag follows vX.Y.Z format
- [ ] Release notes written
- [ ] Release published

### Post-Release

- [ ] Automated build completed successfully
- [ ] Tarball available in release assets
- [ ] Homebrew formula updated (if applicable)
- [ ] Installation tested via Homebrew
- [ ] Manual download tested
- [ ] Documentation updated
```

## Rollback Process

If a release has critical issues:

1. **Create hotfix release** with patch version bump
2. **Don't delete the problematic release** (breaks existing installations)
3. **Mark as pre-release** to hide from main download
4. **Update Homebrew formula** to point to previous stable version temporarily
