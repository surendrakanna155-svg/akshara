# EOS — Completeness Wave 2 · Fee-structure approval activation

**Date:** 2026-07-01 · **Scope:** feeStructure approval type (end-to-end) · **Gate:** PASS (locally-verifiable).

## Defect
`feeStructure` is a client approval type (`approval_request_type.dart`) with a permission
(`approveFeeStructure`) and RBAC grants — but the server never (a) registered the permission,
(b) recognised `feeStructure` as an approval type, or (c) activated the structure on approval.
Consequences in production (approval-required finance): the fee-structure approval **422'd on submit**
(`approval_handlers.ts:241` rejects non-`F2_APPROVAL_TYPES`), and even if created it stayed `inactive`
forever. Severity **P1** (fee structures could not be activated through the documented approval flow).

## Fix (backend catch-up to the existing client design)
- Migration `20260821000000` — seed `approveFeeStructure` + grant to the 6 roles the client matrix
  grants it to (parity with `approveFeeConcession`).
- `F2_APPROVAL_TYPES += "feeStructure"`; `APPROVAL_PERMISSION_BY_TYPE.feeStructure = "approveFeeStructure"`.
- `finance_structures_repository.setFeeStructureStatus` (active/inactive, idempotent).
- `applyApprovalTypeHandler` case `feeStructure`: approve → `active`, reject → `inactive`, + audit effect.
- No client change — the client already models feeStructure end-to-end; this closes the server gap.

## Evidence
- `deno check` clean. `deno test` `approval/` + `finance/` **141/141** green (12 domain-persistence tests,
  incl. `feeStructure` recognised as an F2 type, approve→`UPDATE finance_fee_structures status='active'`,
  reject→`inactive`).

## Residual
- Live persisted-row verification + the seeded permission taking effect = deferred (migration apply on
  the next deploy; Track-B live leg). **feeConcession** still owner-gated (FIN-D4, no backend table).
- Other client approval types not yet server-recognised (admission/budget/expense/payroll/vendor/marketing)
  — reachability to be verified before treating as gaps (next).

**Gate: PASS** (locally-verifiable). No open P0.
