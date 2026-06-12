#!/usr/bin/env bash
# Akshara ERP — pilot/staging release builds (APK + AAB + optional IPA).
# Usage: ./scripts/build_release.sh [apk|aab|ipa|all]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGET="${1:-all}"

# Staging pilot configuration — see docs/Operations/Deployment-Guide.md
STAGING_API_BASE="https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api"

DART_DEFINES=(
  "--dart-define=APP_ENV=staging"
  "--dart-define=API_BASE_URL=${STAGING_API_BASE}"
  "--dart-define=ENABLE_API_MODE=true"
  "--dart-define=ADMISSIONS_API_ENABLED=true"
  "--dart-define=FINANCE_API_ENABLED=true"
  "--dart-define=SIS_API_ENABLED=true"
  "--dart-define=ACADEMIC_API_ENABLED=true"
  "--dart-define=ACADEMIC_TIMETABLE_API_ENABLED=true"
  "--dart-define=ANALYTICS_INTELLIGENCE_API_ENABLED=true"
  "--dart-define=AI_COPILOT_ENABLED=true"
  "--dart-define=PAYMENT_API_ENABLED=true"
  "--dart-define=COMMUNICATION_API_ENABLED=true"
  "--dart-define=AUDIT_API_ENABLED=true"
  "--dart-define=ONBOARDING_API_ENABLED=true"
  "--dart-define=PARENT_API_ENABLED=true"
  "--dart-define=TEACHER_API_ENABLED=true"
  "--dart-define=STUDENT_API_ENABLED=true"
  "--dart-define=PHASE5_API_ENABLED=true"
  "--dart-define=INVENTORY_FINANCE_API_ENABLED=true"
  "--dart-define=SCHOOL_COMPLETION_API_ENABLED=true"
)

echo "==> Akshara release build (v$(grep '^version:' pubspec.yaml | awk '{print $2}'))"
echo "==> Target: ${TARGET}"
echo "==> API: ${STAGING_API_BASE}"

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
