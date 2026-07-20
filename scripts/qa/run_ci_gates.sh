#!/usr/bin/env bash
# CI gate script — analyze + full unit/widget/integration suite + Phase 1 completion checks.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

log() { echo "[ci-gates] $*"; }

log "Gate 1: flutter analyze (0-issue bar — warnings AND infos are fatal so lint drift can't recur)"
flutter analyze --fatal-infos

log "Gate 1b: mock/demo-scaffolding import recurrence guard (PRA S0/T2-H)"
bash scripts/qa/check_mock_imports.sh

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

log "Gate 6: coverage minimum-threshold enforcement (QA-X-038)"
bash scripts/qa/check_coverage_threshold.sh

log "All CI gates passed."
