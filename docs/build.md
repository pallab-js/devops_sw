# Build Instructions

## Prerequisites
- macOS 14.0+ (Sonoma)
- Xcode 15.4+
- Swift 5.10+

## Quick Start

```bash
# Clone
git clone https://github.com/yourname/DevForge.git
cd DevForge

# Open in Xcode
open DevForge.xcodeproj

# Build (Cmd+B) and Run (Cmd+R)
```

## Command Line Build

```bash
# Build
xcodebuild -scheme DevForge \
  -destination 'platform=macOS,arch=arm64' \
  -configuration Debug \
  build

# Run tests
xcodebuild test -scheme DevForge \
  -destination 'platform=macOS,arch=arm64'

# Archive for release
xcodebuild archive \
  -scheme DevForge \
  -destination 'platform=macOS,arch=arm64' \
  -archivePath DevForge.xcarchive

# Export DMG
xcodebuild -exportArchive \
  -archivePath DevForge.xcarchive \
  -exportPath DevForge.dmg \
  -exportOptionsPlist exportOptions.plist
```

## Swift Package Manager

```bash
# Resolve dependencies
swift package resolve

# Build
swift build

# Test
swift test
```

## Dependencies
- GRDB.swift v6 — SQLite persistence
- KeychainSwift — Keychain wrapper
- Nimble (test only) — expressive assertions

All dependencies are resolved automatically via Swift Package Manager in Xcode.
