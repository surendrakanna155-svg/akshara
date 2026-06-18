# F2 Approval API — Migration & Rollback

**Phase:** F2 (Production Backend Program)  
**Scope:** Unified `/approvals/*` API, seven approval types, server-side orchestration  
**Stack:** Supabase PostgreSQL + Edge Functions + Flutter `ApiApprovalRepository`

---

## Cutover checklist

| Step | Action |
|------|--------|
| 1 | Apply migration `20260617100000_approval_requests.sql` on staging tenant DB |
| 2 | Deploy Edge `api` function with `routeApproval` |
| 3 | Build Flutter with `--dart-define=ENABLE_API_MODE=true` |
| 4 | Enable `--dart-define=APPROVAL_API_ENABLED=true` |
| 5 | Verify `GET /approvals/pending` returns envelope for principal JWT |
| 6 | Submit + approve test for each F2 type on staging |
| 7 | Confirm PO self-approve returns `403 FORBIDDEN` server-side |
| 8 | Run CI: `flutter test test/contracts/approval/ test/integration/approval/f2_approval_api_integration_test.dart` |

## Feature flags

| Flag | Default (API mode on) | Effect |
|------|----------------------|--------|
| `ENABLE_API_MODE` | `false` in QA builds | Master API switch |
| `APPROVAL_API_ENABLED` | `false` | Selects `ApiApprovalRepository` |

## Client behavior

| Mode | Repository | Audit trail | Domain side effects |
|------|------------|-------------|---------------------|
| Mock (`APPROVAL_API_ENABLED=false`) | `MockApprovalRepository` | Client `ApprovalCenterService` writes audit | `ApprovalAdapterRegistry` → governance stores |
| API (`APPROVAL_API_ENABLED=true`) | `ApiApprovalRepository` | Server `approval_audit_entries` | Server `approval_domain_effects` + type handlers |

## Rollback (per execution plan)

1. Set `APPROVAL_API_ENABLED=false` (mock fallback — no UI change)  
2. Optional: remove Edge `/approvals` routes from deployment (client ignores when flag off)  
3. PostgreSQL tables remain — no data deletion required  
4. Device-local governance stores resume writes on approve/reject in mock mode  
5. Exam / attendance device stores unchanged on rollback  

## Supported approval types (F2)

| Type | Server permission | Domain handler |
|------|-------------------|----------------|
| `examResults` | `approveExamResults` | `approval_domain_effects` (publish flag) |
| `studentLeave` | `approveStudentLeave` | leave status effect |
| `staffLeave` | `approveStaffLeave` | leave status effect |
| `attendanceCorrection` | `approveAttendanceCorrection` | correction applied/denied |
| `feeConcession` | `approveFeeConcession` | concession active/rejected |
| `refund` | `approveRefunds` | finance `approveRefund` when row exists |
| `inventoryPo` | `approvePurchaseOrder` | PO status + **self-approve denied** |

## Data migration

No client approval data migration. Existing mock/demo seeds are bypassed in API mode; server inbox starts empty until modules submit via API.

---

*See `docs/PHASE_F2_FINAL_CERTIFICATION.md` for gate results.*
