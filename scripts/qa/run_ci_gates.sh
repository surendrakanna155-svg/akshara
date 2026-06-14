#!/usr/bin/env bash
# CI gate script — analyze + full unit/widget/integration suite + Phase 1 completion checks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

log() { echo "[ci-gates] $*"; }

log "Gate 1: flutter analyze"
flutter analyze

log "Gate 2: module coverage report generation"
python3 scripts/qa/generate_module_coverage_report.py

log "Gate 3: QA keys + route protection"
flutter test test/core/testing/ test/router/route_protection_inventory_test.dart

log "Gate 4: Phase 1 completion (workflows + screens + integration)"
flutter test \
  test/features/final_completion/ \
  test/integration/final_completion/ \
  test/features/hr/hr_write_tests.dart \
  test/features/inventory/inventory_write_tests.dart \
  test/features/transport/transport_write_tests.dart \
  test/features/education/education_write_tests.dart \
  test/features/education/education_screens_test.dart

log "Gate 4b: Phase 2 report exports + PO receive handoff"
flutter test \
  test/features/final_completion/phase2_report_export_widget_test.dart \
  test/features/final_completion/phase2_po_receive_handoff_widget_test.dart

log "Gate 5: full flutter test suite with coverage"
flutter test --coverage

log "All CI gates passed."
