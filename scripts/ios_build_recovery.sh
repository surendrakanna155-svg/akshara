#!/usr/bin/env bash
# Safe iOS/Xcode cache recovery for Akshara ERP local device builds.
# Usage: ./scripts/ios_build_recovery.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export PATH="${ROOT}/scripts/ios:${PATH}"

echo "==> iOS build recovery (v$(grep '^version:' pubspec.yaml | awk '{print $2}'))"

echo "==> 1/5 Removing Xcode DerivedData for Runner..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-* 2>/dev/null || true
rm -rf ~/Library/Developer/Xcode/DerivedData/Pods-* 2>/dev/null || true

echo "==> 2/5 flutter clean..."
flutter clean

echo "==> 3/5 flutter pub get..."
flutter pub get

echo "==> 4/5 pod install..."
cd ios
pod deintegrate 2>/dev/null || true
pod install
cd ..

echo "==> 5/5 Environment check..."
source scripts/setup_ios_env.sh 2>/dev/null || true

echo "==> Recovery complete. Next: flutter run -d <device-id>"
