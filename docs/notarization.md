# Notarization Guide

## Prerequisites
- Apple Developer account with paid membership
- Xcode 15+
- App-specific password or API key for notarization

## Steps

### 1. Archive Build
```
Xcode → Product → Archive
```

### 2. Export Signed DMG
```
xcodebuild -exportArchive \
  -archivePath DevForge.xcarchive \
  -exportPath DevForge.dmg \
  -exportOptionsPlist exportOptions.plist
```

### 3. Submit to Notarization
```
xcrun notarytool submit DevForge.dmg \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "@keychain:AC_PASSWORD" \
  --wait
```

### 4. Staple Ticket
```
xcrun stapler staple DevForge.dmg
```

### 5. Verify
```
spctl --assess --type open --context context:primary-signature DevForge.dmg
```
