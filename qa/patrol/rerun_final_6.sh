#!/usr/bin/env bash
# Rerun the 6 remaining failed ERP Patrol suites (post final11).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export PATH="${PATH}:${HOME}/.pub-cache/bin"
export PATROL_ANALYTICS_ENABLED="${PATROL_ANALYTICS_ENABLED:-false}"

RUN_ID="${1:-$(date +%Y%m%d_%H%M%S)_final6}"
REPORT_DIR="${ROOT}/qa/patrol/reports/erp_coverage/${RUN_ID}"
mkdir -p "$REPORT_DIR"

log() { echo "[patrol-final6] $*" | tee -a "${REPORT_DIR}/run.log"; }

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
    log "No Android device — starting emulator"
    bash "${ROOT}/scripts/qa/start_emulator.sh" | tee -a "${REPORT_DIR}/run.log"
    DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  fi
  [[ -n "$DEVICE_ID" ]] && DEVICE_ARGS=(--device "$DEVICE_ID")
fi

FAILED_TARGETS=(
  "patrol_test/workflows/inventory_po_e2e_test.dart"
  "patrol_test/workflows/finance_qr_payment_e2e_test.dart"
  "patrol_test/workflows/parent_receipt_pdf_e2e_test.dart"
  "patrol_test/workflows/substitute_teacher_e2e_test.dart"
  "patrol_test/workflows/director_portal_e2e_test.dart"
  "patrol_test/workflows/trust_intelligence_e2e_test.dart"
)

log "Gate: flutter analyze"
flutter analyze | tee "${REPORT_DIR}/flutter_analyze.log"

log "Pub get (no flutter clean — avoids Gradle 0-test flake)"
flutter pub get | tee -a "${REPORT_DIR}/run.log"

FAILED=0
PASSED=0
FAILURES=()

log "Reports: ${REPORT_DIR} | suites: ${#FAILED_TARGETS[@]}"

run_patrol_suite() {
  local target="$1"
  local name
  name="$(basename "$target" .dart)"

  if [[ "$name" == "inventory_po_e2e_test" ]]; then
    log "Pre-build Android test bundle for inventory PO"
    set +e
    patrol build android "${DART_DEFINES[@]}" \
      --target "$target" 2>&1 | tee -a "${REPORT_DIR}/${name}_build.log"
    set -e
  fi

  log "Patrol ==> $target"
  set +e
  patrol test --target "$target" "${DEVICE_ARGS[@]}" "${DART_DEFINES[@]}" \
    2>&1 | tee "${REPORT_DIR}/${name}.log"
  local ec="${PIPESTATUS[0]}"
  set -e

  if [[ "$ec" -ne 0 ]]; then
    log "Retry ==> $target"
    set +e
    patrol test --target "$target" "${DEVICE_ARGS[@]}" "${DART_DEFINES[@]}" \
      2>&1 | tee -a "${REPORT_DIR}/${name}.log"
    ec="${PIPESTATUS[0]}"
    set -e
  fi

  if [[ "$ec" -ne 0 && "$name" == "inventory_po_e2e_test" ]]; then
    log "Inventory third attempt after clean build"
    flutter clean | tee -a "${REPORT_DIR}/run.log"
    flutter pub get | tee -a "${REPORT_DIR}/run.log"
    set +e
    patrol test --target "$target" "${DEVICE_ARGS[@]}" "${DART_DEFINES[@]}" \
      2>&1 | tee -a "${REPORT_DIR}/${name}.log"
    ec="${PIPESTATUS[0]}"
    set -e
  fi

  if [[ "$ec" -ne 0 ]]; then
    FAILED=$((FAILED + 1))
    FAILURES+=("$name")
    return 1
  fi
  PASSED=$((PASSED + 1))
  return 0
}

for target in "${FAILED_TARGETS[@]}"; do
  run_patrol_suite "$target" || true
done

cat > "${REPORT_DIR}/coverage_summary.json" <<EOF
{
  "run_id": "${RUN_ID}",
  "mode": "final6",
  "patrol_suites_passed": ${PASSED},
  "failed_suites": ${FAILED},
  "total_rerun": ${#FAILED_TARGETS[@]}
}
EOF

if [[ "$FAILED" -gt 0 ]]; then
  log "FAILED suites: ${FAILURES[*]}"
  exit 1
fi
log "Done. ${PASSED}/${#FAILED_TARGETS[@]} suites passed."
