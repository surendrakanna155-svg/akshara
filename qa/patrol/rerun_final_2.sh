#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export PATH="${PATH}:${HOME}/.pub-cache/bin"
DART_DEFINES=(
  "--dart-define=APP_ENV=development"
  "--dart-define=ENABLE_QA_LOGIN=true"
  "--dart-define=ENABLE_DEMO_AUTH=true"
  "--dart-define=ENABLE_API_MODE=false"
)
DEVICE=(--device emulator-5554)
for target in inventory_po_e2e_test director_portal_e2e_test; do
  echo "[patrol] ==> $target"
  if ! patrol test --target "patrol_test/workflows/${target}.dart" "${DEVICE[@]}" "${DART_DEFINES[@]}"; then
    echo "[patrol] FAILED $target"
  fi
done
