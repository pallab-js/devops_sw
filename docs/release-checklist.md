# Release Checklist

## Pre-Release
- [ ] All tests pass: `xcodebuild test -scheme DevForge -destination 'platform=macOS'`
- [ ] SwiftLint clean: `swiftlint lint --strict`
- [ ] README.md updated with latest features
- [ ] CHANGELOG.md updated with all changes
- [ ] Version bumped in Xcode project (marketing version)
- [ ] Build number incremented

## Build
- [ ] Archive succeeds
- [ ] DMG exports successfully
- [ ] DMG is code-signed
- [ ] Notarization submitted and approved
- [ ] Stapler ticket applied
- [ ] Gatekeeper assessment passes

## GitHub
- [ ] Tag created (`git tag v1.0.0`)
- [ ] Tag pushed (`git push --tags`)
- [ ] Release created on GitHub
- [ ] DMG attached to release
- [ ] Release notes generated from CHANGELOG.md
