#!/usr/bin/env bash
# Pre-M15 Patrol certification — red team, onboarding, parent/teacher/student workflows.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export PATH="${PATH}:${HOME}/.pub-cache/bin"
export PATROL_ANALYTICS_ENABLED="${PATROL_ANALYTICS_ENABLED:-false}"

RUN_ID="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="${ROOT}/qa/patrol/reports/pre_m15_cert/${RUN_ID}"
mkdir -p "$REPORT_DIR"

log() { echo "[pre-m15-patrol] $*" | tee -a "${REPORT_DIR}/run.log"; }

DART_DEFINES=(
  "--dart-define=APP_ENV=development"
  "--dart-define=ENABLE_QA_LOGIN=true"
  "--dart-define=ENABLE_DEMO_AUTH=true"
  "--dart-define=ENABLE_API_MODE=false"
)

DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
if [[ -z "$DEVICE_ID" ]]; then
  log "No Android device — starting headless emulator"
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"
  nohup "$ANDROID_HOME/emulator/emulator" \
    -avd "${AKSHARA_EMULATOR_AVD:-Medium_Phone_API_36.0}" \
    -no-snapshot-load -no-boot-anim -gpu swiftshader_indirect -no-window \
    >> /tmp/akshara_emulator_patrol.log 2>&1 &
  deadline=$((SECONDS + 180))
  while (( SECONDS < deadline )); do
    DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
    if [[ -n "$DEVICE_ID" ]]; then
      boot="$(adb -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
      [[ "$boot" == "1" ]] && break
    fi
    sleep 5
  done
fi

if [[ -z "$DEVICE_ID" ]]; then
  log "FATAL: No Android device available for Patrol"
  exit 1
fi

log "Using device: $DEVICE_ID"

TARGETS=(
  "patrol_test/workflows/red_team_parent_operational_e2e_test.dart"
  "patrol_test/workflows/red_team_student_operational_e2e_test.dart"
  "patrol_test/workflows/red_team_route_security_e2e_test.dart"
  "patrol_test/workflows/red_team_admin_security_e2e_test.dart"
  "patrol_test/workflows/startup_onboarding_certification_e2e_test.dart"
  "patrol_test/workflows/parent_workflows_test.dart"
  "patrol_test/workflows/teacher_workflows_test.dart"
  "patrol_test/workflows/student_workflows_test.dart"
)

FAILED=0
PASSED=0
FAILURES=()

for target in "${TARGETS[@]}"; do
  name="$(basename "$target" .dart)"
  log "Patrol ==> $target"
  set +e
  patrol test --target "$target" --device "$DEVICE_ID" "${DART_DEFINES[@]}" \
    >"${REPORT_DIR}/${name}.log" 2>&1
  ec=$?
  set -e
  if [[ "$ec" -ne 0 ]]; then
    FAILED=$((FAILED + 1))
    FAILURES+=("$name")
    log "FAIL $name (exit $ec)"
    tail -30 "${REPORT_DIR}/${name}.log" | tee -a "${REPORT_DIR}/run.log"
  else
    PASSED=$((PASSED + 1))
    log "PASS $name"
  fi
done

log "Summary: ${PASSED} passed, ${FAILED} failed"
log "Reports: ${REPORT_DIR}"
if [[ "$FAILED" -gt 0 ]]; then
  log "Failed: ${FAILURES[*]}"
  exit 1
fi
