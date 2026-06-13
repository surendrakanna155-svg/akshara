#!/usr/bin/env bash
# ERP workflow coverage — FAST = smoke (~2 min). FULL = every workflow suite (~60+ min).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export PATH="${PATH}:${HOME}/.pub-cache/bin"
export PATROL_ANALYTICS_ENABLED="${PATROL_ANALYTICS_ENABLED:-false}"

MODE="${ERP_COVERAGE_MODE:-fast}"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="${ROOT}/qa/patrol/reports/erp_coverage/${RUN_ID}"
mkdir -p "$REPORT_DIR"

DART_DEFINES=(
  "--dart-define=APP_ENV=development"
  "--dart-define=ENABLE_QA_LOGIN=true"
  "--dart-define=ENABLE_DEMO_AUTH=true"
  "--dart-define=ENABLE_API_MODE=false"
)

DEVICE_ARGS=()
if command -v adb >/dev/null 2>&1; then
  DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  [[ -n "$DEVICE_ID" ]] && DEVICE_ARGS=(--device "$DEVICE_ID")
fi

log() { echo "[erp-coverage] $*" | tee -a "${REPORT_DIR}/run.log"; }

log "Mode: ${MODE} | Reports: ${REPORT_DIR}"

log "Gate: flutter analyze"
flutter analyze | tee "${REPORT_DIR}/flutter_analyze.log"

log "Gate: flutter test"
flutter test | tee "${REPORT_DIR}/flutter_test.log"

log "Generate module coverage report"
python3 scripts/qa/generate_module_coverage_report.py | tee "${REPORT_DIR}/coverage_report.log"

ALL_TARGETS=(
  "patrol_test/workflows/erp_coverage_smoke_test.dart"
  "patrol_test/workflows/teacher_workflows_test.dart"
  "patrol_test/workflows/parent_workflows_test.dart"
  "patrol_test/workflows/student_workflows_test.dart"
  "patrol_test/workflows/principal_workflows_test.dart"
  "patrol_test/workflows/erp_workflows_test.dart"
  "patrol_test/workflows/finance_workflows_test.dart"
  "patrol_test/workflows/inventory_workflows_test.dart"
  "patrol_test/workflows/sis_workflows_test.dart"
  "patrol_test/workflows/admissions_workflows_test.dart"
  "patrol_test/workflows/hr_workflows_test.dart"
  "patrol_test/workflows/transport_workflows_test.dart"
  "patrol_test/workflows/library_workflows_test.dart"
  "patrol_test/workflows/hostel_workflows_test.dart"
  "patrol_test/workflows/alumni_workflows_test.dart"
  "patrol_test/workflows/control_center_workflows_test.dart"
  "patrol_test/workflows/management_workflows_test.dart"
  "patrol_test/workflows/screenshot_validation_test.dart"
)

if [[ "$MODE" == "fast" ]]; then
  TARGETS=("patrol_test/workflows/erp_coverage_smoke_test.dart")
else
  TARGETS=("${ALL_TARGETS[@]:1}") # skip smoke duplicate in full mode
fi

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
    FAILED=$((FAILED + 1))
    FAILURES+=("$name")
  else
    PASSED=$((PASSED + 1))
  fi
done

COVERAGE_AFTER="$(python3 -c "import json; print(json.load(open('qa/reports/module_coverage_v18_6.json'))['coverage_after_pct'])")"
WORKFLOW_COUNT="$(python3 -c "import json; print(json.load(open('qa/reports/module_coverage_v18_6.json'))['patrol_workflow_tests'])")"

cat > "${REPORT_DIR}/coverage_summary.json" <<EOF
{
  "run_id": "${RUN_ID}",
  "mode": "${MODE}",
  "suite": "v18.6-erp-full-coverage",
  "coverage_before_pct": 38,
  "coverage_after_pct": ${COVERAGE_AFTER},
  "patrol_workflow_tests": ${WORKFLOW_COUNT},
  "patrol_suites_passed": ${PASSED},
  "failed_suites": ${FAILED},
  "readiness_score": $([[ "$FAILED" -eq 0 ]] && echo 90 || echo 82)
}
EOF

if [[ "$FAILED" -gt 0 ]]; then
  log "FAILED suites: ${FAILURES[*]}"
  exit 1
fi
log "Done. ${PASSED} suites passed."
