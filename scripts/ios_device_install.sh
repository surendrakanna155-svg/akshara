#!/usr/bin/env bash
# Build and install Akshara ERP on a connected iPhone (development signing).
# Usage: ./scripts/ios_device_install.sh [device-id]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export PATH="${ROOT}/scripts/ios:${PATH}"

DEVICE_ID="${1:-}"
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID="$(flutter devices 2>/dev/null | grep -E 'ios.*•' | grep -v 'simulator' | head -1 | awk -F'•' '{print $2}' | xargs || true)"
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "ERROR: No connected iPhone found. Connect device via USB and unlock it."
  exit 1
fi

STAGING_API="https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api"

DART_DEFINES=(
  "--dart-define=APP_ENV=staging"
  "--dart-define=API_BASE_URL=${STAGING_API}"
  "--dart-define=ENABLE_API_MODE=true"
  "--dart-define=ADMISSIONS_API_ENABLED=true"
  "--dart-define=FINANCE_API_ENABLED=true"
  "--dart-define=SIS_API_ENABLED=true"
  "--dart-define=ACADEMIC_API_ENABLED=true"
  "--dart-define=PARENT_API_ENABLED=true"
  "--dart-define=TEACHER_API_ENABLED=true"
  "--dart-define=STUDENT_API_ENABLED=true"
)

echo "==> Building for device ${DEVICE_ID}..."
flutter build ios --release "${DART_DEFINES[@]}"

APP_PATH="${ROOT}/build/ios/iphoneos/Runner.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: Build output not found at ${APP_PATH}"
  exit 1
fi

echo "==> Installing ${APP_PATH}..."
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo ""
echo "==> Installed. On iPhone (first time only):"
echo "    Settings → General → VPN & Device Management"
echo "    → Trust 'Apple Development: surendra303@gmail.com'"
echo ""
echo "==> Launch:"
echo "    xcrun devicectl device process launch --device ${DEVICE_ID} com.akshara.erp.aksharaErp"
echo "    Or tap Akshara ERP on the home screen."
