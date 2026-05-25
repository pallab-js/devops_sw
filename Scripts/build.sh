#!/bin/bash
# Build script for DevForge (SPM-only, no Xcode)
set -euo pipefail

CMD="${1:-build}"

case "$CMD" in
  build)
    swift build
    ;;
  run)
    swift run "$@"
    ;;
  test)
    swift test
    ;;
  clean)
    swift package clean
    ;;
  *)
    echo "Usage: $0 {build|run|test|clean}"
    exit 1
    ;;
esac
