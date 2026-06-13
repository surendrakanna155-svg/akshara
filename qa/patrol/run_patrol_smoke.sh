#!/usr/bin/env bash
# Patrol smoke — launch, auth personas, one dashboard per role.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export PATH="${PATH}:${HOME}/.pub-cache/bin"
export PATROL_ANALYTICS_ENABLED="${PATROL_ANALYTICS_ENABLED:-false}"

DART_DEFINES=(
  "--dart-define=APP_ENV=development"
  "--dart-define=ENABLE_QA_LOGIN=true"
  "--dart-define=ENABLE_DEMO_AUTH=true"
  "--dart-define=ENABLE_API_MODE=false"
)

DEVICE_ARGS=()
if command -v adb >/dev/null 2>&1; then
  DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  if [[ -n "$DEVICE_ID" ]]; then
    DEVICE_ARGS=(--device "$DEVICE_ID")
  fi
fi

TARGETS=(
  "patrol_test/smoke/smoke_launch_test.dart"
  "patrol_test/auth/qa_login_personas_test.dart"
  "patrol_test/dashboards/dashboards_test.dart"
)

echo "[patrol-smoke] NOTE: first run builds APK (~2-5 min). Re-runs ~30s."
echo "[patrol-smoke] Building & testing on ${DEVICE_ARGS[*]:-(default device)}..."
for target in "${TARGETS[@]}"; do
  echo "==> $target"
  patrol test --target "$target" "${DEVICE_ARGS[@]}" "${DART_DEFINES[@]}"
done

echo "[patrol-smoke] PASS"
