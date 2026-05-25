#!/bin/bash
set -e

echo "→ SwiftLint..."
swiftlint lint --strict --quiet

echo "→ Build check..."
xcodebuild -scheme DevForge -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO > /dev/null 2>&1

echo "✓ Pre-commit passed"
