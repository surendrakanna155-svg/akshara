#!/usr/bin/env bash
# One-time / per-session iOS build environment for Akshara ERP.
# Usage: source scripts/setup_ios_env.sh
set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="${ROOT_DIR}/scripts/ios:${PATH}"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "ERROR: Xcode not found at $DEVELOPER_DIR"
  echo "Install Xcode from the App Store, then run:"
  echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
  echo "  sudo xcodebuild -runFirstLaunch"
  return 1 2>/dev/null || exit 1
fi

echo "DEVELOPER_DIR=$DEVELOPER_DIR"
echo "Flutter doctor (Xcode row):"
flutter doctor -v 2>&1 | sed -n '/\[✓\] Xcode/,/^$/p' || true
echo "xcodebuild: $(xcodebuild -version | head -1)"
echo "pod: $(pod --version)"
echo "Signing identities:"
security find-identity -v -p codesigning 2>&1 | head -5 || true
