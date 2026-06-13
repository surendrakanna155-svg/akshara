#!/usr/bin/env bash
# Build Android APK optimized for Maestro QA (demo auth, offline mocks).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

DART_DEFINES=(
  "--dart-define=APP_ENV=development"
  "--dart-define=ENABLE_DEMO_AUTH=true"
  "--dart-define=ENABLE_API_MODE=false"
  "--dart-define=AUTH_API_ENABLED=false"
)

echo "==> QA APK build (demo auth, mock repositories)"
flutter pub get
flutter build apk --profile "${DART_DEFINES[@]}"

APK="build/app/outputs/flutter-apk/app-profile.apk"
if [[ ! -f "$APK" ]]; then
  APK="build/app/outputs/flutter-apk/app-release.apk"
fi

echo "==> QA APK: $APK"
ls -lh "$APK"
echo "$APK"
