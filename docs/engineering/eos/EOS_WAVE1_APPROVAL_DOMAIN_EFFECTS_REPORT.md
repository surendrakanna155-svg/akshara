# EOS — Completeness Wave 1 · Approval-decision domain persistence

**Date:** 2026-07-01 · **Scope:** backend approval domain effects (staffLeave, studentLeave, inventoryPo).
**Standard:** Constitution Part 7B (Certification / Failure Conditions), Part 4 (data integrity). **Gate:** PASS (locally-verifiable).

## Defect (found by the completeness gap-sweep, verified in code)
In production `config/live_release.json` sets `APPROVAL_API_ENABLED=true`, so
`approval_center_provider._skipApprovalDomainEffects` returns true → the client approval adapters'
`onApproved/onRejected` side-effects are **skipped** (the backend is meant to be authoritative). But
`applyApprovalTypeHandler` (`approval_type_handlers.ts`) persisted real domain effects only for
examResults / attendanceCorrection / refund / hostel-leave — for **staffLeave, studentLeave, inventoryPo**
it recorded an `approval_domain_effects` audit row only and **never flipped the underlying row**. Result
in API mode: an approved/rejected leave stayed `pending` in every read model; an approved PO stayed
`draft`. Severity **P1** (core workflow silently non-functional; the client mock stores masked it in dev).

## Fix
- New `approval/leave_decision_effect.ts` → `flipLeaveDecision`: flips `mobile_leave_requests.status`
  (parent/teacher-submitted) or the HR `snapshot_leave` snapshot (whichever holds the id).
- New `inventory_finance_repository.rejectPurchaseOrder`; reused existing `approvePurchaseOrder`
  (finance-integrated: AP commitment + posting).
- `applyApprovalTypeHandler` now calls these on decision for leave + inventoryPo, keeping the audit
  effect. Non-draft/absent PO and already-decided leaves are handled idempotently (no throw).
- Untouched (correct as-is): examResults/attendanceCorrection/refund/hostel persist server-side already;
  the refund/PO client guards intentionally force approvals through the Approval Center.

## Evidence
- `deno check` clean (4 files). `deno test` **9/9** new (`approval_domain_effect_persistence_test.ts`,
  spy `TenantQueryClient` proving the real `UPDATE mobile_leave_requests` / snapshot flip /
  `UPDATE purchase_orders SET status='approved'|'rejected'` are issued, plus the audit effect).
- Regression: full `approval/` + `inventory_finance/` suites **39/39** green.

## Residual / not in this wave
- **feeStructure** approval never activates the row (not in `F2_APPROVAL_TYPES`) → **Wave 2**.
- **feeConcession** has no backend table at all → **owner-gated** (FIN-D4 concession maker-checker).
- Live persisted-row verification after a real decision = Track-B live leg (needs tenant Postgres / RLS).

**Gate: PASS** (locally-verifiable). No open P0. GA `QA-R-012` unaffected (still blocked on prior items).
