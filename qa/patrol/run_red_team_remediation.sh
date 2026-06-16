#!/usr/bin/env bash
# Patrol — Red Team operational remediation suites (parent/student/admin security).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export PATH="${PATH}:${HOME}/.pub-cache/bin"
export PATROL_ANALYTICS_ENABLED="${PATROL_ANALYTICS_ENABLED:-false}"

RUN_ID="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="${ROOT}/qa/patrol/reports/red_team_remediation/${RUN_ID}"
mkdir -p "$REPORT_DIR"

log() { echo "[red-team-patrol] $*" | tee -a "${REPORT_DIR}/run.log"; }

DART_DEFINES=(
  "--dart-define=APP_ENV=development"
  "--dart-define=ENABLE_QA_LOGIN=true"
  "--dart-define=ENABLE_DEMO_AUTH=true"
  "--dart-define=ENABLE_API_MODE=false"
)

DEVICE_ARGS=()
if command -v adb >/dev/null 2>&1; then
  DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  if [[ -z "$DEVICE_ID" ]] && [[ -x "${ROOT}/scripts/qa/start_emulator.sh" ]]; then
    log "No Android device — starting emulator"
    bash "${ROOT}/scripts/qa/start_emulator.sh" | tee -a "${REPORT_DIR}/run.log"
    DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  fi
  [[ -n "$DEVICE_ID" ]] && DEVICE_ARGS=(--device "$DEVICE_ID")
fi

TARGETS=(
  "patrol_test/workflows/red_team_parent_operational_e2e_test.dart"
  "patrol_test/workflows/red_team_student_operational_e2e_test.dart"
  "patrol_test/workflows/red_team_route_security_e2e_test.dart"
  "patrol_test/workflows/red_team_admin_security_e2e_test.dart"
)

log "Gate: flutter analyze (errors only)"
flutter analyze --no-fatal-infos 2>&1 | tee "${REPORT_DIR}/flutter_analyze.log"

log "Gate: flutter test"
flutter test | tee "${REPORT_DIR}/flutter_test.log"

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

log "Summary: ${PASSED} passed, ${FAILED} failed"
if [[ "$FAILED" -gt 0 ]]; then
  log "Failed: ${FAILURES[*]}"
  exit 1
fi
