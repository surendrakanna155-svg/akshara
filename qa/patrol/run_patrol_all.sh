#!/usr/bin/env bash
# Run full Patrol regression (requires Android emulator or device).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export PATH="${PATH}:${HOME}/.pub-cache/bin"
export PATROL_ANALYTICS_ENABLED="${PATROL_ANALYTICS_ENABLED:-false}"

RUN_ID="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="${ROOT}/qa/patrol/reports/${RUN_ID}"
mkdir -p "$REPORT_DIR" "${ROOT}/qa/patrol/screenshots"

DART_DEFINES=(
  "--dart-define=APP_ENV=development"
  "--dart-define=ENABLE_QA_LOGIN=true"
  "--dart-define=ENABLE_DEMO_AUTH=true"
  "--dart-define=ENABLE_API_MODE=false"
)

log() { echo "[patrol-all] $*" | tee -a "${REPORT_DIR}/run.log"; }

log "Patrol CLI: $(patrol --version 2>&1 | head -1)"
log "Reports: ${REPORT_DIR}"

if command -v adb >/dev/null 2>&1; then
  DEVICE_COUNT="$(adb devices | awk 'NR>1 && $2=="device" {c++} END {print c+0}')"
  log "adb devices (ready): ${DEVICE_COUNT}"
  if [[ "$DEVICE_COUNT" -eq 0 ]]; then
    log "WARN: No Android device. Launch: flutter emulators --launch <id>"
  fi
fi

log "Running flutter analyze..."
flutter analyze | tee "${REPORT_DIR}/flutter_analyze.log"

log "Running flutter test..."
flutter test | tee "${REPORT_DIR}/flutter_test.log"

log "Generating Patrol journey tests..."
python3 "${ROOT}/scripts/qa/generate_patrol_journeys.py" | tee -a "${REPORT_DIR}/run.log"

DEVICE_ARGS=()
if command -v adb >/dev/null 2>&1; then
  DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  if [[ -n "$DEVICE_ID" ]]; then
    DEVICE_ARGS=(--device "$DEVICE_ID")
    log "Patrol device: ${DEVICE_ID}"
  else
    log "WARN: No Android device — patrol may default to macOS/chrome"
  fi
fi

log "Running patrol test (all)..."
set +e
patrol test \
  "${DEVICE_ARGS[@]}" \
  "${DART_DEFINES[@]}" \
  --verbose \
  2>&1 | tee "${REPORT_DIR}/patrol.log"
PATROL_EXIT=$?
set -e

"${ROOT}/qa/patrol/generate_patrol_report.sh" "$RUN_ID" "$PATROL_EXIT"

if [[ $PATROL_EXIT -ne 0 ]]; then
  exit 1
fi

log "Done."
