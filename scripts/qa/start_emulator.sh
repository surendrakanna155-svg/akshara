#!/usr/bin/env bash
# Start Android emulator for Patrol — cold boot avoids stale snapshot offline crashes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"

AVD="${AKSHARA_EMULATOR_AVD:-Medium_Phone_API_36.0}"
BOOT_TIMEOUT_SEC="${AKSHARA_EMULATOR_BOOT_TIMEOUT:-180}"
LOG="${AKSHARA_EMULATOR_LOG:-/tmp/akshara_emulator.log}"

log() { echo "[start-emulator] $*"; }

if adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {found=1} END {exit !found}'; then
  log "Device already connected: $(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  exit 0
fi

# Emulator may be booting — wait instead of killing (fixes flash-close on re-run).
if pgrep -f "qemu-system.*${AVD}" >/dev/null 2>&1 || pgrep -f "emulator.*${AVD}" >/dev/null 2>&1; then
  log "Emulator process already running for $AVD — waiting for adb"
  deadline=$((SECONDS + BOOT_TIMEOUT_SEC))
  while (( SECONDS < deadline )); do
    if adb devices 2>/dev/null | grep -q "emulator.*device"; then
      boot="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
      if [[ "$boot" == "1" ]]; then
        log "Ready: $(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
        exit 0
      fi
    fi
    sleep 5
  done
  log "Emulator running but adb not ready after ${BOOT_TIMEOUT_SEC}s — recycling"
fi

log "Stopping stale emulator processes for $AVD"
pkill -f "qemu-system.*${AVD}" 2>/dev/null || true
pkill -f "emulator.*${AVD}" 2>/dev/null || true
sleep 2

log "Cold boot $AVD (no snapshot — fixes flash-close / adb offline)"
GPU_MODE="${AKSHARA_EMULATOR_GPU:-swiftshader_indirect}"
if [[ "${AKSHARA_EMULATOR_HEADLESS:-0}" == "1" ]]; then
  nohup "$ANDROID_HOME/emulator/emulator" \
    -avd "$AVD" \
    -no-snapshot-load \
    -no-snapshot-save \
    -no-boot-anim \
    -gpu "$GPU_MODE" \
    -no-window \
    >> "$LOG" 2>&1 &
else
  nohup "$ANDROID_HOME/emulator/emulator" \
    -avd "$AVD" \
    -no-snapshot-load \
    -no-snapshot-save \
    -no-boot-anim \
    -gpu "$GPU_MODE" \
    >> "$LOG" 2>&1 &
fi
EMU_PID=$!

# Allow cold boot to spawn qemu before liveness checks.
sleep 15

deadline=$((SECONDS + BOOT_TIMEOUT_SEC))
while (( SECONDS < deadline )); do
  if adb devices 2>/dev/null | grep -q "emulator.*device"; then
    boot="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    if [[ "$boot" == "1" ]]; then
      log "Ready: $(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
      exit 0
    fi
  fi
  if ! kill -0 "$EMU_PID" 2>/dev/null; then
    log "Emulator process exited early. Last log lines:"
    tail -20 "$LOG" >&2 || true
    exit 1
  fi
  sleep 5
done

log "Timed out after ${BOOT_TIMEOUT_SEC}s. See $LOG"
exit 1
