#!/usr/bin/env bash
# Akshara autonomous QA — full regression runner (Flutter gates + Maestro journeys).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export PATH="${HOME}/.maestro/bin:${PATH}"
export MAESTRO_CLI_NO_ANALYTICS="${MAESTRO_CLI_NO_ANALYTICS:-1}"
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED="${MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED:-1}"

RUN_ID="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="${ROOT}/qa/reports/${RUN_ID}"
SCREENSHOT_DIR="${ROOT}/qa/screenshots/${RUN_ID}"
JUNIT_FILE="${REPORT_DIR}/maestro.junit.xml"
LOG_FILE="${REPORT_DIR}/maestro.log"

mkdir -p "$REPORT_DIR" "$SCREENSHOT_DIR"

log() { echo "[qa-run] $*" | tee -a "${REPORT_DIR}/run.log"; }

SKIP_FLUTTER="${SKIP_FLUTTER:-0}"
SKIP_MAESTRO="${SKIP_MAESTRO:-0}"
BUILD_APK="${BUILD_APK:-0}"
SMOKE_ONLY="${SMOKE_ONLY:-0}"

log "Run ID: ${RUN_ID}"
log "Reports: ${REPORT_DIR}"

# ── Route inventory ──────────────────────────────────────────────────────────
python3 "${ROOT}/scripts/qa/extract_route_inventory.py"

# ── Flutter quality gates ────────────────────────────────────────────────────
if [[ "$SKIP_FLUTTER" != "1" ]]; then
  log "Running flutter analyze..."
  flutter analyze | tee "${REPORT_DIR}/flutter_analyze.log"

  log "Running flutter test..."
  flutter test | tee "${REPORT_DIR}/flutter_test.log"
fi

# ── Optional QA APK ───────────────────────────────────────────────────────────
if [[ "$BUILD_APK" == "1" ]]; then
  log "Building QA APK..."
  APK="$("${ROOT}/scripts/qa/build_qa_apk.sh" | tail -1)"
  if command -v adb >/dev/null 2>&1; then
    DEVICE="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
    if [[ -n "$DEVICE" ]]; then
      log "Installing QA APK on ${DEVICE}..."
      adb -s "$DEVICE" install -r "$APK" | tee -a "${REPORT_DIR}/run.log"
    else
      log "WARN: No adb device — skip APK install"
    fi
  fi
fi

# ── Maestro ───────────────────────────────────────────────────────────────────
MAESTRO_STATUS="skipped"
if [[ "$SKIP_MAESTRO" != "1" ]]; then
  if ! command -v maestro >/dev/null 2>&1; then
    log "ERROR: Maestro not found. Run scripts/qa/setup_maestro.sh"
    MAESTRO_STATUS="missing_cli"
  else
    log "Maestro: $(maestro --version 2>&1 | head -1)"
    if command -v adb >/dev/null 2>&1; then
      DEVICE_COUNT="$(adb devices | awk 'NR>1 && $2=="device" {c++} END {print c+0}')"
      log "adb devices (ready): ${DEVICE_COUNT}"
      if [[ "$DEVICE_COUNT" -eq 0 ]]; then
        log "WARN: No Android device/emulator. Launch: flutter emulators --launch Medium_Phone_API_36.0"
      fi
    fi

    if [[ "$SMOKE_ONLY" == "1" ]]; then
      FLOWS=( "${ROOT}/qa/journeys/smoke_launch.yaml" "${ROOT}/qa/journeys/smoke_otp_back.yaml" )
    else
      mapfile -t FLOWS < <(find "${ROOT}/qa/journeys" -maxdepth 1 -name '*.yaml' | sort)
    fi

    DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
    MAESTRO_DEVICE_ARGS=()
    if [[ -n "$DEVICE_ID" ]]; then
      MAESTRO_DEVICE_ARGS=(--device "$DEVICE_ID")
      log "Maestro device: ${DEVICE_ID}"
    fi

    log "Running ${#FLOWS[@]} Maestro flow(s)..."
    set +e
    maestro test \
      --config "${ROOT}/qa/maestro/config.yaml" \
      "${MAESTRO_DEVICE_ARGS[@]}" \
      --format junit \
      --output "$JUNIT_FILE" \
      --test-output-dir "$SCREENSHOT_DIR" \
      "${FLOWS[@]}" 2>&1 | tee "$LOG_FILE"
    MAESTRO_EXIT=$?
    set -e

    if [[ $MAESTRO_EXIT -eq 0 ]]; then
      MAESTRO_STATUS="pass"
    else
      MAESTRO_STATUS="fail"
    fi
  fi
fi

# ── Coverage + findings report ───────────────────────────────────────────────
"${ROOT}/qa/generate_report.sh" "$RUN_ID" "$MAESTRO_STATUS"

log "Done. Summary: ${REPORT_DIR}/coverage_summary.json"
if [[ "$MAESTRO_STATUS" == "fail" ]]; then
  exit 1
fi
