#!/usr/bin/env bash
# Akshara ERP — pilot/staging release builds (APK + AAB + optional IPA).
# Usage: ./scripts/build_release.sh [apk|aab|ipa|all]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Native assets (objective_c) and xcrun require full Xcode when xcode-select
# points at Command Line Tools. ios/Flutter/xcode.env.local mirrors this.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export PATH="${ROOT}/scripts/ios:${PATH}"

TARGET="${1:-all}"

# A1: live-as-default. All API mode / module flags / live URL live in ONE
# reviewable source of truth, consumed by --dart-define-from-file. Edit flags
# there, not here. Override with RELEASE_CONFIG=path/to.json if ever needed.
RELEASE_CONFIG="${RELEASE_CONFIG:-config/live_release.json}"
if [[ ! -f "${RELEASE_CONFIG}" ]]; then
  echo "ERROR: release config not found: ${RELEASE_CONFIG}" >&2
  exit 1
fi
API_BASE="$(grep -o '"API_BASE_URL"[^,]*' "${RELEASE_CONFIG}" | sed 's/.*: *"\(.*\)"/\1/')"

DART_DEFINES=(
  "--dart-define-from-file=${RELEASE_CONFIG}"
)

echo "==> Akshara release build (v$(grep '^version:' pubspec.yaml | awk '{print $2}'))"
echo "==> Target: ${TARGET}"
echo "==> Config: ${RELEASE_CONFIG} (APP_ENV=production, live API mode)"
echo "==> API: ${API_BASE}"

build_apk() {
  echo "==> Building release APK..."
  flutter build apk --release "${DART_DEFINES[@]}"
  echo "APK: build/app/outputs/flutter-apk/app-release.apk"
  ls -lh build/app/outputs/flutter-apk/app-release.apk
}

build_aab() {
  echo "==> Building release AAB..."
  flutter build appbundle --release "${DART_DEFINES[@]}"
  echo "AAB: build/app/outputs/bundle/release/app-release.aab"
  ls -lh build/app/outputs/bundle/release/app-release.aab
}

build_ipa() {
  echo "==> Building release IPA (requires Xcode + signing)..."
  flutter build ipa --release "${DART_DEFINES[@]}"
  echo "IPA: build/ios/ipa/"
  ls -lh build/ios/ipa/ 2>/dev/null || true
}

flutter clean
flutter pub get

case "$TARGET" in
  apk) build_apk ;;
  aab) build_aab ;;
  ipa) build_ipa ;;
  all)
    build_apk
    build_aab
    if command -v xcodebuild >/dev/null 2>&1; then
      build_ipa || echo "WARN: IPA build skipped — see docs/Testing/Device-Testing-Guide.md § iOS signing"
    else
      echo "WARN: Xcode not installed — IPA not built"
    fi
    ;;
  *)
    echo "Usage: $0 [apk|aab|ipa|all]"
    exit 1
    ;;
esac

echo "==> Release build complete."
