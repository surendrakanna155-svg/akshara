#!/usr/bin/env bash
# Visual testing on Android emulator — keeps emulator alive, enables QA login (no OTP).
# Run in macOS Terminal (not Cursor agent shell) for best stability:
#   bash scripts/dev/visual_emulator_run.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="$PATH:$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools"
AVD="${AKSHARA_EMULATOR_AVD:-Medium_Phone_API_36.0}"
LOG="${AKSHARA_EMULATOR_LOG:-/tmp/akshara_visual_run.log}"

log() { echo "[visual-run] $*"; }

cd "$ROOT"

if ! adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {exit 0} END {exit 1}'; then
  if pgrep -f "qemu-system.*${AVD}" >/dev/null 2>&1; then
    log "Emulator process exists — waiting for adb..."
  else
    log "Starting $AVD (do NOT close the emulator window)"
    nohup "$ANDROID_HOME/emulator/emulator" \
      -avd "$AVD" \
      -no-snapshot-load \
      -no-boot-anim \
      -gpu swiftshader_indirect \
      >> "$LOG" 2>&1 &
    disown
  fi
  for _ in $(seq 1 60); do
    if adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {found=1} END {exit !found}'; then
      boot="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
      if [[ "$boot" == "1" ]]; then
        log "Emulator ready: $(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
        break
      fi
    fi
    sleep 3
  done
fi

adb devices

log "Launching app with QA login (tap Parent / Teacher / Student — no OTP)"
exec flutter run -d emulator-5554 \
  --dart-define=ENABLE_QA_LOGIN=true \
  --dart-define=ENABLE_DEMO_AUTH=true
