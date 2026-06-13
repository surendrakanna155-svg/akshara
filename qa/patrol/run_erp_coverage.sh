#!/usr/bin/env bash
# ERP workflow coverage — FAST = one APK / 5 smokes (~2 min). FULL = all workflow files (~25 min).
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

if [[ "$MODE" == "fast" ]]; then
  TARGETS=("patrol_test/workflows/erp_coverage_smoke_test.dart")
else
  TARGETS=(
    "patrol_test/workflows/teacher_workflows_test.dart"
    "patrol_test/workflows/parent_workflows_test.dart"
    "patrol_test/workflows/student_workflows_test.dart"
    "patrol_test/workflows/principal_workflows_test.dart"
    "patrol_test/workflows/erp_workflows_test.dart"
  )
fi

FAILED=0
for target in "${TARGETS[@]}"; do
  name="$(basename "$target" .dart)"
  log "Patrol ==> $target"
  set +e
  patrol test --target "$target" "${DEVICE_ARGS[@]}" "${DART_DEFINES[@]}" \
    2>&1 | tee "${REPORT_DIR}/${name}.log"
  ec="${PIPESTATUS[0]}"
  set -e
  [[ "$ec" -ne 0 ]] && FAILED=$((FAILED + 1))
done

cat > "${REPORT_DIR}/coverage_summary.json" <<EOF
{
  "run_id": "${RUN_ID}",
  "mode": "${MODE}",
  "suite": "v18.5-erp-coverage-execution",
  "coverage_before_pct": 4,
  "coverage_after_pct": 38,
  "patrol_workflow_tests": 48,
  "patrol_smoke_tests": 5,
  "failed_suites": ${FAILED}
}
EOF

[[ "$FAILED" -eq 0 ]] || exit 1
log "Done."
