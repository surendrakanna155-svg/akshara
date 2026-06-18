#!/usr/bin/env bash
# ERP workflow coverage — FAST = smoke (~2 min). FULL = every workflow suite (~60+ min).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

export PATH="${PATH}:${HOME}/.pub-cache/bin"
export PATROL_ANALYTICS_ENABLED="${PATROL_ANALYTICS_ENABLED:-false}"

MODE="${ERP_COVERAGE_MODE:-fast}"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="${ROOT}/qa/patrol/reports/erp_coverage/${RUN_ID}"
mkdir -p "$REPORT_DIR"

log() { echo "[erp-coverage] $*" | tee -a "${REPORT_DIR}/run.log"; }

DART_DEFINES=(
  "--dart-define=APP_ENV=development"
  "--dart-define=ENABLE_QA_LOGIN=true"
  "--dart-define=ENABLE_DEMO_AUTH=true"
  "--dart-define=ENABLE_API_MODE=false"
)

DEVICE_ARGS=()
if command -v adb >/dev/null 2>&1; then
  DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  if [[ -z "$DEVICE_ID" ]]; then
    log "No Android device — starting emulator (cold boot)"
    if [[ -x "${ROOT}/scripts/qa/start_emulator.sh" ]]; then
      bash "${ROOT}/scripts/qa/start_emulator.sh" | tee -a "${REPORT_DIR}/run.log"
      DEVICE_ID="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
    fi
  fi
  [[ -n "$DEVICE_ID" ]] && DEVICE_ARGS=(--device "$DEVICE_ID")
fi

log "Mode: ${MODE} | Reports: ${REPORT_DIR}"

log "Gate: flutter analyze"
flutter analyze | tee "${REPORT_DIR}/flutter_analyze.log"

log "Gate: flutter test"
flutter test | tee "${REPORT_DIR}/flutter_test.log"

log "Generate module coverage report"
python3 scripts/qa/generate_module_coverage_report.py | tee "${REPORT_DIR}/coverage_report.log"

ALL_TARGETS=(
  "patrol_test/workflows/erp_coverage_smoke_test.dart"
  "patrol_test/workflows/teacher_workflows_test.dart"
  "patrol_test/workflows/parent_workflows_test.dart"
  "patrol_test/workflows/student_workflows_test.dart"
  "patrol_test/workflows/principal_workflows_test.dart"
  "patrol_test/workflows/erp_workflows_test.dart"
  "patrol_test/workflows/finance_workflows_test.dart"
  "patrol_test/workflows/inventory_workflows_test.dart"
  "patrol_test/workflows/sis_workflows_test.dart"
  "patrol_test/workflows/sis_academic_operations_e2e_test.dart"
  "patrol_test/workflows/continuity_e2e_test.dart"
  "patrol_test/workflows/workflow_automation_e2e_test.dart"
  "patrol_test/workflows/platform_intelligence_e2e_test.dart"
  "patrol_test/workflows/admissions_workflows_test.dart"
  "patrol_test/workflows/admissions_e2e_journey_test.dart"
  "patrol_test/workflows/finance_fee_assignment_e2e_test.dart"
  "patrol_test/workflows/finance_fee_collection_e2e_test.dart"
  "patrol_test/workflows/finance_full_journey_e2e_test.dart"
  "patrol_test/workflows/finance_invoice_e2e_test.dart"
  "patrol_test/workflows/teacher_attendance_e2e_test.dart"
  "patrol_test/workflows/hr_workflows_test.dart"
  "patrol_test/workflows/hr_leave_e2e_test.dart"
  "patrol_test/workflows/hr_payroll_e2e_test.dart"
  "patrol_test/workflows/hr_employee_crud_e2e_test.dart"
  "patrol_test/workflows/management_approval_e2e_test.dart"
  "patrol_test/workflows/management_dashboard_export_e2e_test.dart"
  "patrol_test/workflows/management_insight_routes_e2e_test.dart"
  "patrol_test/workflows/management_kpi_drill_e2e_test.dart"
  "patrol_test/workflows/copilot_context_e2e_test.dart"
  "patrol_test/workflows/copilot_dock_e2e_test.dart"
  "patrol_test/workflows/ai_access_settings_e2e_test.dart"
  "patrol_test/workflows/library_issue_return_e2e_test.dart"
  "patrol_test/workflows/hostel_allocation_e2e_test.dart"
  "patrol_test/workflows/inventory_po_e2e_test.dart"
  "patrol_test/workflows/inventory_lifecycle_e2e_test.dart"
  "patrol_test/workflows/transport_route_e2e_test.dart"
  "patrol_test/workflows/transport_activate_e2e_test.dart"
  "patrol_test/workflows/transport_allocation_e2e_test.dart"
  "patrol_test/workflows/education_remark_e2e_test.dart"
  "patrol_test/workflows/transport_workflows_test.dart"
  "patrol_test/workflows/library_workflows_test.dart"
  "patrol_test/workflows/hostel_workflows_test.dart"
  "patrol_test/workflows/alumni_workflows_test.dart"
  "patrol_test/workflows/control_center_workflows_test.dart"
  "patrol_test/workflows/management_workflows_test.dart"
  # M6–M8 intelligence & AI
  "patrol_test/workflows/operations_hub_e2e_test.dart"
  "patrol_test/workflows/resource_optimization_e2e_test.dart"
  "patrol_test/workflows/ai_content_generation_e2e_test.dart"
  "patrol_test/workflows/universal_ai_assistant_e2e_test.dart"
  "patrol_test/workflows/parent_meeting_summary_e2e_test.dart"
  # M6+ extended journeys
  "patrol_test/workflows/admissions_settings_persistence_e2e_test.dart"
  "patrol_test/workflows/book_distribution_e2e_test.dart"
  "patrol_test/workflows/communication_broadcast_e2e_test.dart"
  "patrol_test/workflows/finance_offline_payment_e2e_test.dart"
  "patrol_test/workflows/finance_qr_payment_e2e_test.dart"
  "patrol_test/workflows/growth_campaign_e2e_test.dart"
  "patrol_test/workflows/hr_leave_approval_e2e_test.dart"
  "patrol_test/workflows/inventory_replacement_e2e_test.dart"
  "patrol_test/workflows/parent_receipt_pdf_e2e_test.dart"
  "patrol_test/workflows/school_memories_admin_e2e_test.dart"
  "patrol_test/workflows/sis_profile_edit_e2e_test.dart"
  "patrol_test/workflows/substitute_teacher_e2e_test.dart"
  "patrol_test/workflows/teacher_reassignment_e2e_test.dart"
  "patrol_test/workflows/timetable_optimization_apply_e2e_test.dart"
  # M9 multi-school SaaS
  "patrol_test/workflows/multi_school_operations_e2e_test.dart"
  "patrol_test/workflows/director_portal_e2e_test.dart"
  "patrol_test/workflows/trust_intelligence_e2e_test.dart"
  "patrol_test/workflows/branch_operations_e2e_test.dart"
  "patrol_test/workflows/franchise_portfolio_e2e_test.dart"
  # M10–M11 platform evolution
  "patrol_test/workflows/organization_builder_e2e_test.dart"
  "patrol_test/workflows/dynamic_widget_platform_e2e_test.dart"
  # M12 infrastructure
  "patrol_test/workflows/platform_operations_e2e_test.dart"
  # M13 multi-industry
  "patrol_test/workflows/industry_framework_e2e_test.dart"
  "patrol_test/workflows/healthcare_vertical_e2e_test.dart"
  "patrol_test/workflows/salon_vertical_e2e_test.dart"
  "patrol_test/workflows/restaurant_vertical_e2e_test.dart"
  "patrol_test/workflows/accommodation_vertical_e2e_test.dart"
  "patrol_test/workflows/white_label_platform_e2e_test.dart"
  # Post-M13 QA expansion — batch 1
  "patrol_test/workflows/finance_filters_e2e_test.dart"
  "patrol_test/workflows/finance_exports_e2e_test.dart"
  "patrol_test/workflows/pilot_closure_workflows_e2e_test.dart"
  "patrol_test/workflows/patrol_batch1_p0_expansion_e2e_test.dart"
  "patrol_test/workflows/admissions_exports_e2e_test.dart"
  "patrol_test/workflows/management_actions_e2e_test.dart"
  "patrol_test/workflows/sis_filters_e2e_test.dart"
  "patrol_test/workflows/director_portal_navigation_e2e_test.dart"
  "patrol_test/workflows/industry_pack_navigation_e2e_test.dart"
  "patrol_test/workflows/healthcare_navigation_e2e_test.dart"
  "patrol_test/workflows/hostel_visitors_e2e_test.dart"
  "patrol_test/workflows/library_digital_resources_e2e_test.dart"
  "patrol_test/workflows/screenshot_validation_test.dart"
  # Red Team operational remediation (post #14–#25)
  "patrol_test/workflows/red_team_parent_operational_e2e_test.dart"
  "patrol_test/workflows/red_team_student_operational_e2e_test.dart"
  "patrol_test/workflows/red_team_route_security_e2e_test.dart"
  "patrol_test/workflows/red_team_admin_security_e2e_test.dart"
)

if [[ "$MODE" == "fast" ]]; then
  TARGETS=("patrol_test/workflows/erp_coverage_smoke_test.dart")
else
  TARGETS=("${ALL_TARGETS[@]:1}") # skip smoke duplicate in full mode
fi

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

COVERAGE_AFTER="$(python3 -c "import json; print(json.load(open('qa/reports/module_coverage_v18_6.json'))['coverage_after_pct'])")"
WORKFLOW_COUNT="$(python3 -c "import json; print(json.load(open('qa/reports/module_coverage_v18_6.json'))['patrol_workflow_tests'])")"

cat > "${REPORT_DIR}/coverage_summary.json" <<EOF
{
  "run_id": "${RUN_ID}",
  "mode": "${MODE}",
  "suite": "v18.6-erp-full-coverage",
  "coverage_before_pct": 38,
  "coverage_after_pct": ${COVERAGE_AFTER},
  "patrol_workflow_tests": ${WORKFLOW_COUNT},
  "patrol_suites_passed": ${PASSED},
  "failed_suites": ${FAILED},
  "readiness_score": $([[ "$FAILED" -eq 0 ]] && echo 90 || echo 82)
}
EOF

if [[ "$FAILED" -gt 0 ]]; then
  log "FAILED suites: ${FAILURES[*]}"
  exit 1
fi
log "Done. ${PASSED} suites passed."
