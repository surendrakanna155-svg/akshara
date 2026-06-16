#!/usr/bin/env bash
# Rerun the 4 remaining failed ERP Patrol suites.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export PATH="${PATH}:${HOME}/.pub-cache/bin"
export PATROL_ANALYTICS_ENABLED="${PATROL_ANALYTICS_ENABLED:-false}"

RUN_ID="${1:-$(date +%Y%m%d_%H%M%S)_final4}"
REPORT_DIR="${ROOT}/qa/patrol/reports/erp_coverage/${RUN_ID}"
mkdir -p "$REPORT_DIR"

log() { echo "[patrol-final4] $*" | tee -a "${REPORT_DIR}/run.log"; }

DART_DEFINES=(
  "--dart-define=APP_ENV=development"
  "--dart-define=ENABLE_QA_LOGIN=true"
  "--dart-define=ENABLE_DEMO_AUTH=true"
  "--dart-define=ENABLE_API_MODE=false"
)

DEVICE_ARGS=()
if command -v adb >/dev/null 2>&1; then
  DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  if [[ -z "$DEVICE_ID" ]]; then
    bash "${ROOT}/scripts/qa/start_emulator.sh" | tee -a "${REPORT_DIR}/run.log"
    DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  fi
  [[ -n "$DEVICE_ID" ]] && DEVICE_ARGS=(--device "$DEVICE_ID")
fi

TARGETS=(
  "patrol_test/workflows/inventory_po_e2e_test.dart"
  "patrol_test/workflows/finance_qr_payment_e2e_test.dart"
  "patrol_test/workflows/substitute_teacher_e2e_test.dart"
  "patrol_test/workflows/director_portal_e2e_test.dart"
)

FAILED=0
PASSED=0
FAILURES=()

for target in "${TARGETS[@]}"; do
  name="$(basename "$target" .dart)"
  log "Patrol ==> $target"
  set +e
  patrol test --target "$target" "${DEVICE_ARGS[@]}" "${DART_DEFINES[@]}" \
    2>&1 | tee "${REPORT_DIR}/${name}.log"
  ec="${PIPESTATUS[0]}"
  set -e
  if [[ "$ec" -ne 0 ]]; then
    log "Retry ==> $target"
    set +e
    patrol test --target "$target" "${DEVICE_ARGS[@]}" "${DART_DEFINES[@]}" \
      2>&1 | tee -a "${REPORT_DIR}/${name}.log"
    ec="${PIPESTATUS[0]}"
    set -e
  fi
  if [[ "$ec" -ne 0 ]]; then
    FAILED=$((FAILED + 1))
    FAILURES+=("$name")
  else
    PASSED=$((PASSED + 1))
  fi
done

log "Result: ${PASSED}/${#TARGETS[@]} passed"
[[ "$FAILED" -eq 0 ]] || { log "FAILED: ${FAILURES[*]}"; exit 1; }
