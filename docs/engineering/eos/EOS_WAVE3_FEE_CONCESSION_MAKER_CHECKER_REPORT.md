# EOS — Completeness Wave 3 · Fee-concession maker-checker (FIN-D4)

**Date:** 2026-07-01 · **Scope:** feeConcession approval persistence (owner decision FIN-D4 = two-person
maker-checker). **Gate:** PASS (locally-verifiable).

## Owner decision
FIN-D4 (2026-07-01): a fee concession uses **maker-checker** — a maker raises it, a *different* checker
approves it via the Approval Center, then it is recorded and (goal) reduces the student's payable.
Saved to memory `fin-d4-fee-concession-decision`.

## Defect
`feeConcession` decisions were **audit-only** — no per-student concession was ever persisted
(`finance_scholarships` is a program CATALOG, no student/amount; no `fee_concessions` table existed).
In production an approved concession vanished. Severity **P2** (financial record loss).

## Fix
- **Separation of duties is already enforced** — `approval_repository.decideApproval` throws
  `ApprovalSelfApproveDenied` when `requester_id === actorId`, so maker ≠ checker is guaranteed by the
  framework (no new SoD code needed).
- New `finance_fee_concessions` table (migration `20260822000000`): durable ledger with student ref,
  amount, reason, status, `source_approval_id`, **maker_id + checker_id**, RLS school-scoped (FORCE).
- New `finance_fee_concessions_repository` (`recordFeeConcessionDecision`, `listFeeConcessions`,
  best-effort amount parse, UUID guard).
- `applyApprovalTypeHandler` case `feeConcession` now persists the concession on the checker's decision
  (approve → active, reject → rejected), maker = approval requester, checker = decider.

## Evidence
- `deno check` clean. `deno test` **145/145** (approval + finance): feeConcession approve → active with
  `maker != checker`, reject → rejected, + amount/uuid helper units.

## Residual (flagged, not guessed — financial-correctness)
- **Apply-to-fee (reduce the student's live payable)** is NOT auto-applied: the client submits a free-text
  student *name* (no `student_id`) and no payable-netting model exists (scholarships aren't netted either).
  Reliably reducing the correct student's payable needs (a) a resolved `student_id`/`fee_assignment_id`
  on the concession and (b) netting rules. The row carries `payableApplied=false` + a nullable
  `student_id` for that follow-up. Guessing would be a financial-correctness risk.
- Live migration apply / persisted-row verification = deferred deploy (Track-B leg).

**Gate: PASS** (locally-verifiable). No open P0. **Approval domain-effects gap class fully closed** for
all reachable types (staff/student leave, PO, fee-structure, fee-concession).
