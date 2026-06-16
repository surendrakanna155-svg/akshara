# Patrol — Red Team Operational Remediation

**Branch:** `release/v1.0-preprod`  
**Scope:** E2E validation for Red Team findings #14–#25 (parent transport/PTM, student progress, admin hub, route guards)

## Suites

| File | Cases | Coverage |
|------|------:|----------|
| `patrol_test/workflows/red_team_parent_operational_e2e_test.dart` | 4 | Transport + PTM quick actions; notice `n1`→PTM, `n3`→transport |
| `patrol_test/workflows/red_team_student_operational_e2e_test.dart` | 2 | Report card + progress / AI guidance |
| `patrol_test/workflows/red_team_route_security_e2e_test.dart` | 4 | Parent/student blocked from `/admin` and Control Center |
| `patrol_test/workflows/red_team_admin_security_e2e_test.dart` | 3 | Admin hub module cards; CC guard allow/deny |

## QA keys

Stable selectors live in `lib/core/testing/qa_test_keys.dart`:

- `parentDashboardScreen`, `parentDashboardQuickAction(id)`, `parentDashboardNotice(id)`
- `parentTransportScreen`, `parentPtmScreen`
- `studentDashboardScreen`, `studentDashboardQuickAction(id)`
- `studentReportCardScreen`, `studentProgressScreen`
- `adminHubScreen`, `adminHubModuleCard(label)`
- `accessDeniedScreen`

## Helpers

`patrol_test/helpers/patrol_helpers.dart`:

- `assertPatrolRoute`, `currentPatrolRoute`
- `tapParentDashboardQuickAction`, `tapStudentDashboardQuickAction`
- `tapParentHome`, `tapStudentHome`
- `assertMobileForbiddenErpRoute`

## Run

```bash
# Full red-team patrol pack (analyze + unit tests + 4 Patrol suites)
bash qa/patrol/run_red_team_remediation.sh

# Single suite
patrol test --target patrol_test/workflows/red_team_parent_operational_e2e_test.dart \
  --dart-define=ENABLE_QA_LOGIN=true \
  --dart-define=ENABLE_DEMO_AUTH=true
```

Requires Android emulator or device (`adb devices`). QA login must be enabled.

## Notice deep links

| Notice ID | Dashboard copy | Destination |
|-----------|----------------|-------------|
| `n1` | PTM scheduled… | `/parent/ptm` |
| `n3` | New transport route… | `/parent/transport` |

## Registry

Added to `qa/patrol/run_erp_coverage.sh` `ALL_TARGETS` for full ERP regression.
