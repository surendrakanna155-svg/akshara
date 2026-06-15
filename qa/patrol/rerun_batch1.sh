#!/usr/bin/env bash
# Run Post-M13 QA expansion batch-1 Patrol suites.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

bash scripts/qa/start_emulator.sh

DEVICE="${PATROL_DEVICE:-emulator-5554}"
DEVICE_ARGS=(--device "$DEVICE")
DART_DEFINES=(--dart-define=AKSHARA_QA_MODE=true)

TARGETS=(
  patrol_test/workflows/finance_filters_e2e_test.dart
  patrol_test/workflows/finance_exports_e2e_test.dart
  patrol_test/workflows/admissions_exports_e2e_test.dart
  patrol_test/workflows/management_actions_e2e_test.dart
  patrol_test/workflows/sis_filters_e2e_test.dart
  patrol_test/workflows/director_portal_navigation_e2e_test.dart
  patrol_test/workflows/industry_pack_navigation_e2e_test.dart
  patrol_test/workflows/healthcare_navigation_e2e_test.dart
  patrol_test/workflows/hostel_visitors_e2e_test.dart
  patrol_test/workflows/library_digital_resources_e2e_test.dart
)

FAILED=0
for target in "${TARGETS[@]}"; do
  echo "==> $target"
  if ! patrol test --target "$target" "${DEVICE_ARGS[@]}" "${DART_DEFINES[@]}"; then
    FAILED=$((FAILED + 1))
  fi
done

if [[ "$FAILED" -gt 0 ]]; then
  echo "Batch 1 Patrol: $FAILED suite(s) failed."
  exit 1
fi
echo "Batch 1 Patrol: all suites passed."
