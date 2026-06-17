# Phase D M-D2 — Final Certification

**Milestone:** M-D2 — Principal Approval Center UI  
**Branch:** `feature/m15-theme`  
**Certification date:** 2026-06-17  
**Verdict:** ✅ **PASS** — certified via automated tests; no human QA required  
**Reference:** [`PHASE_D_M2_COMPLETION_REPORT.md`](./PHASE_D_M2_COMPLETION_REPORT.md) · [`PHASE_D_M1_FINAL_CERTIFICATION.md`](./PHASE_D_M1_FINAL_CERTIFICATION.md)

---

## 1. Validation checklist

| # | Requirement | Result | Evidence |
|---|-------------|--------|----------|
| 1 | Approval queue loads | ✅ Pass | `approval_center_provider_test.dart` — seeded demo ≥10 items; widget test loads queue |
| 2 | Status filters work | ✅ Pass | Provider tests: pending / approved / rejected / all |
| 3 | Category filters work | ✅ Pass | Provider + widget: All, Finance, HR, Marketing, Admissions |
| 4 | Academic filter works | ✅ Pass | Provider + widget: `ApprovalCategory.academic` → exam results, leave, attendance |
| 5 | Approve action works | ✅ Pass | Provider + integration: status → `approved`, audit `approved` entry |
| 6 | Reject requires comment | ✅ Pass | Provider + integration: empty comment → `ApiFailure`; valid comment → `rejected` |
| 7 | Audit history after approve/reject | ✅ Pass | Provider + integration: `listAuditEntries` includes decision events |
| 8 | Mobile layout renders | ✅ Pass | Widget test (cards, no DataTable); golden `390x844`, `428x926` |
| 9 | Desktop layout renders | ✅ Pass | Widget test (DataTable); golden `834x1194` |
| 10 | RBAC enforcement | ✅ Pass | Provider permission matrix; widget hides actions for teacher; table/detail `AksharaApproveAction` |
| 11 | Deep links from dashboards | ✅ Pass | `approval_center_navigation_test.dart`; KPI drill → `managementApprovals` |
| 12 | No navigation regressions | ✅ Pass | `router_smoke_test.dart` staff routes include tasks + approvals; `management_screens_test.dart` |
| 13 | `flutter analyze` — zero errors | ✅ Pass | 0 errors; 66 pre-existing info hints |
| 14 | Full `flutter test` | ✅ Pass | **1870 passed**, 1 skipped |

---

## 2. Test inventory (M-D2 scope)

| Suite | File | Tests | Status |
|-------|------|-------|--------|
| Provider | `test/features/management/approval/approval_center_provider_test.dart` | 18 | ✅ |
| Widget | `test/features/management/approval/approval_center_screen_test.dart` | 9 | ✅ |
| Navigation | `test/features/management/approval/approval_center_navigation_test.dart` | 4 | ✅ |
| Integration | `test/integration/approval/approval_center_integration_test.dart` | 3 | ✅ |
| Golden | `test/golden/approval_center_golden_test.dart` | 3 | ✅ |
| M-D1 contracts | `test/contracts/approval/` | 11 | ✅ |
| M-D1 service | `test/core/approvals/approval_center_service_test.dart` | 7 | ✅ |
| Router smoke (regression) | `test/router_smoke_test.dart` — tasks + approvals routes | included in 12 | ✅ |
| **M-D2 gate total** | | **52** | **✅** |

### Gate command

```bash
flutter test test/features/management/approval/ test/integration/approval/ \
  test/contracts/approval/ test/core/approvals/ test/golden/approval_center_golden_test.dart
# 00:03 +52: All tests passed!
```

### Full suite command

```bash
flutter analyze   # 66 info, 0 errors
flutter test      # 1870 passed, 1 skipped
```

---

## 3. Coverage achieved

| Area | Automated coverage |
|------|-------------------|
| Queue load + demo seed | Provider, widget, integration |
| Status chips (All / Pending / Approved / Rejected) | Provider + widget |
| Category chips (7 buckets) | Provider + widget + unit `ApprovalCategory.matchesType` |
| Academic sub-filter (`examResults`) | Provider + widget |
| Detail panel + audit timeline | Widget |
| Approve mutation + snackbar path | Provider + integration |
| Reject validation + mutation | Provider + integration |
| RBAC per `ApprovalRequestType` | Provider permission tests + widget (teacher deny) |
| Mobile card list vs desktop DataTable | Widget + golden |
| Route aliases `/management/tasks` + `/management/approvals` | Navigation + router smoke |
| KPI drill from management dashboard | Navigation unit + smoke |
| `ManagementTasksScreen` delegation | Widget |

**Visual baselines:** `test/golden/goldens/approval_center_{390x844,428x926,834x1194}.png`

---

## 4. Test evidence (representative)

### Provider — approve + audit

```bash
flutter test test/features/management/approval/approval_center_provider_test.dart \
  --name "approve updates status and audit"
```

### Integration — reject comment required

```bash
flutter test test/integration/approval/approval_center_integration_test.dart \
  --name "reject without comment fails"
```

### Navigation — KPI drill

```bash
flutter test test/features/management/approval/approval_center_navigation_test.dart
```

---

## 5. Production fixes during certification

| File | Change | Reason |
|------|--------|--------|
| `mock_approval_demo_seed.dart` | Submit via `ApprovalCenterService` | Audit entries include `submitted` |
| `approval_queue_table.dart` | Wrap actions in `AksharaApproveAction` | RBAC parity with detail panel |
| `management_kpi_row.dart` | Default card height 140 → 172 | Fix executive KPI overflow on management dashboard |
| `test/test_helpers.dart` | `enableQaLogin: true` + `initProviderTestPrefs` in router pump | `ApprovePermissionGuard` needs prefs + QA login |
| `copilot_persona_shell_screen.dart` | Material wrapper on `SwitchListTile` | Router smoke AI route ListTile assertion |

---

## 6. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Principal role lacks `manageFinance` — cannot approve budget/expense types in live UI | Medium | Documented; finance-type items visible but approve hidden unless finance permission added (M-D5) |
| Approve/reject in DataTable not widget-tapped (horizontal scroll) | Low | Covered by provider + integration tests |
| Demo seed only — no module adapters (M-D3) | Expected | Real exam/leave/finance submit flows deferred |
| Patrol journey stub only (`biz_erp_approval_center.yaml`) | Low | Flutter tests provide certification gate; Patrol optional |
| Golden baselines updated for M15.5 theme drift | Low | Re-run goldens on intentional visual changes |

---

## 7. Remaining gaps (not M-D2 scope)

- M-D3 module adapters (exam publish, attendance correction, leave feeds)
- M-D4+ notification on outcome, escalation rules
- Patrol E2E execution on emulator (stub exists; not required for this certification)
- API repository when `APPROVAL_API_ENABLED=true` (contract stub only)
- Finance-type approval RBAC for principal persona (needs permission policy decision)

---

## 8. Scope isolation

- No M-D3 adapter code added
- No Phase A work started
- Changes outside `lib/features/management/approval/` limited to: demo seed, KPI row height, router/deep-link wiring (pre-M-D2), shared test helpers, copilot ListTile Material wrapper (router smoke blocker)

---

## 9. Commit record

Commit created after full suite pass:

**Message:** `Phase D M2 - Principal Approval Center UI`

---

## 10. Certification sign-off

| Role | Status |
|------|--------|
| M-D2 functional requirements | ✅ Certified (automated) |
| M-D2 gate tests | ✅ 52/52 |
| Full suite | ✅ 1870/1870 (+1 skipped) |
| Analyze | ✅ 0 errors |
| Human QA | ⛔ Not required |
| M-D3 | ⛔ **Not authorized** — STOP |
| Phase A | ⛔ **Not authorized** — STOP |

---

## Change log

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-06-17 | Final automated certification + commit |
