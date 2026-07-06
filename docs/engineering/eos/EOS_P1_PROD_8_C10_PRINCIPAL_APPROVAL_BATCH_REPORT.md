# EOS Report — P1-PROD-8 · C10 · Principal Approval Center batch actions (PRI-1)

**Scope:** FEATURE (Principal / Approvals) — batch multi-select approve/reject.
**Date:** 2026-07-04 · **Gate:** **PASS** (0 P0 / 0 P1) · **Ledger:** appended.
**Anchors:** Constitution Part 7B (*Certification Categories*, *Evidence Requirements*, *Automatic-Failure Conditions* — esp. **permission escalation** / self-approval of money), Part 8 (*Release Decision*); EOS rule #4. Cites the law; does not restate it.

---

## 1. Discovery-first — PRI-1 batch is already built; a money-SoD gap was found

The batch multi-select approve/reject capability exists end-to-end. Completion criterion (`FINAL_QA_ROADMAP.md:560`: "multi-select approve/reject persists + audits each decision") is met. Discovery surfaced a genuine, money-adjacent governance gap that PRI-1's tripwire ("must NOT bypass maker-checker where a decision gates money/value") targets — **fixed this wave**.

| Capability | Verdict |
|---|---|
| Approval Center screen + multi-select UI (checkboxes + batch action bar) | ✅ EXISTS (`principal_approval_center_screen.dart`, `approval_batch_action_bar.dart`, `approval_queue_table.dart`) |
| Backend `POST /approvals/batch-decide` → `handleBatchDecideApprovals` (one tx, de-dupe, per-item `decideOne`, partial-success `{decided, skipped}`, MAX_BULK cap) | ✅ EXISTS |
| Reuses single-item `decideApproval` — audit-each, idempotent, not-pending skip | ✅ EXISTS |
| Client repo/api/mock/service/provider wired to the real route | ✅ EXISTS |
| Backend batch tests (audit-each, partial-success, idempotency, SoD) | ✅ EXISTS (`approval_batch_decide_test.ts`) |

## 2. Real gap closed — self-approval of money/value approvals (SoD / maker-checker)

`decideApproval` enforced the self-approve (requester ≠ approver) guard **only for `inventoryPo`** — despite comments in `approval_type_handlers.ts` / `finance_fee_concessions_repository.ts` claiming maker≠checker "is already guaranteed by decideApproval." It was **not**: a requester holding the approve permission could approve their **own** `feeConcession` (a money waiver, FIN-D4-mandated two-person maker-checker), `refund` (pays money out), or `feeStructure` (sets fee amounts) — on both the single and batch paths. That is a permission-escalation / self-approval-of-money hole.

- **Fix:** [approval_repository.ts](../../../supabase/functions/_shared/approval/approval_repository.ts) — new `SELF_APPROVE_DENIED_TYPES = {inventoryPo, feeConcession, refund, feeStructure}`; the approve-time guard now denies self-approval for any of them (`ApprovalSelfApproveDeniedError`). Applies identically to single- and batch-decide (both route through `decideApproval`); **rejection by the same person stays allowed** (only approvals are guarded). Code now matches the documented intent + the FIN-D4 owner decision ([[fin-d4-fee-concession-decision]]).
- **Verified non-breaking:** the `studentLeave` "SoD is exam-only" test (self-actor) still passes (not a guarded type); the fee-concession domain-effect tests exercise `applyApprovalTypeHandler` (post-decision effect), not `decideApproval`; the audit test uses distinct requester/approver. No test relied on self-approving a money/value request.
- **Tests (+4):** `approval_separation_of_duties_test.ts` — fee-concession requester self-approve → denied; a *different* checker → allowed; refund requester self-approve → denied; requester **can reject** their own (only approvals guarded). `approval_batch_decide_test.ts` — a fee-concession maker self-approving in a **batch** is skipped (FIN-D4 not bypassed), no audit, no UPDATE.

## 3. Automatic-failure check (Part 7B) — none open; one closed

This wave **closes** a permission-escalation exposure (self-approval of a money waiver), not opens one. No data loss, no duplicate financial transaction, no broken auth. Backend-only; the batch tx, audit-each, and partial-success behavior are unchanged.

## 4. Regression evidence

- `deno test … _shared/approval/` → **59 passed / 0 failed** (+4 SoD/batch tests).
- `deno test` (finance fee-concession + finance decide-adjacent) → **2 passed / 0 failed**.
- `deno check supabase/functions/api/index.ts` → clean.
- No `lib/**` changes → the Flutter suite is unaffected (3616 pass / 2 known UX-7 → P2-UX); `flutter analyze` 0 at last run.

## 5. Noted (tracked, not this-wave gaps)

- **`PRI1-CLIENT-TEST`** — the client batch multi-select UI/provider (`ApprovalBatchActionBar`, `batchDecideApprovalsProvider`) has no widget test (the backend batch is comprehensively tested; the client is thin repo delegation). Tracked test-debt.
- **Mock parity** — `mock_approval_repository.dart` enforces no self-approve guard at all (pre-existing divergence, incl. `inventoryPo`); a demo/offline stand-in, not the enforcement path. Minor consistency item.

## 6. Verdict

**EOS gate: PASS.** 0 P0 / 0 P1. PRI-1 batch verified existing (persist + audit-each — no rebuild); closed the genuine money-SoD gap (self-approval of feeConcession/refund/feeStructure now denied on single + batch, aligning with FIN-D4); no automatic-failure (one closed); regression green. **Advance → C11 (Admissions / Front-office productivity) or the next unblocked C-wave.**

**Commit:** `7c9294b` (fix+test) · docs(eos) close companion follows.
