# P4-RT-1 — Global Red Team · Round 1 Report (static / local-runnable surface)

**Date:** 2026-07-14 · **Phase:** P4-RT-1 (round 1) · **Framework:** [`GLOBAL_RED_TEAM_FRAMEWORK.md`](GLOBAL_RED_TEAM_FRAMEWORK.md) · **Seeds:** [`RED_TEAM_P4_RT0_READINESS.md`](RED_TEAM_P4_RT0_READINESS.md)
**Scope this round:** the **static / local-runnable** surface (code-level authz, isolation, money integrity, AI abuse, data corruption + concurrency) that needs no live VPS. The **live legs** (concurrent cross-tenant probes on `akshara_tenant_test`, DR restore, ops/alerts) are deferred to round 2 pending the owner re-establishing the SSH control-master.
**Operators:** 5 perspective-diverse, model-tiered (opus on security/isolation/money/AI-abuse; sonnet on corruption/concurrency). Every finding was independently adversarially verified by the orchestrator against the source before triage.

---

## Verdict: **round 1 CONVERGED with fixes.** 3 confirmed P0/P1 (all FIXED + regression-locked) · 3 tracked P2/P3 · 2 informational.

Post-freeze note: every fix below is a **correctness / data-integrity** change — the class explicitly permitted after FREEZE-1. No new feature, no schema migration (all edge/Deno code), so the live migration head parity (CFC-1 item 8) is unaffected; the fixes ship in the next edge deploy window.

## Confirmed & FIXED (P0/P1)

### RT-3-1 (F1) · P0 · Duplicate financial transaction — concurrent refund approval
- **Domain 3 (money).** `finance_refunds_repository.ts` — `getRefund` read is unlocked, the account update is a **delta** (`amount_paid - $1`) while the invoice update is an absolute set (masking the double), and the terminal `UPDATE finance_refunds SET refund_status='processed'` lacked the `AND refund_status='pending'` guard that the *certified sibling* `finance_fee_reductions_repository.ts:421` has.
- **Repro:** two concurrent `POST .../refunds/:id/approve` (double-click or two approvers, SoD passing) on one pending refund → both pass the unlocked pre-check → the student `finance_student_accounts` moves by **2×** the refund (ledger diverges from the invoice by the refund amount), one refund row, no error.
- **Verified:** `withTenantContext` gives each approval its own BEGIN/COMMIT (`tenant_db.ts:108-130`); the certified fee-reduction path proves the correct pattern; the only double-approve test was sequential (caught by the pre-check).
- **Fix:** added `AND refund_status='pending'` to the terminal write (approve **and** reject) + throw `InvalidRefundTransitionError` on 0 rows → the enclosing txn rolls back the money mutations. **Test:** `finance_refunds_repository_test.ts` — "a concurrent winner (terminal 0-rows) fails closed".

### RT-10-1 · P1 · Duplicate Transfer Certificate — concurrent no-dues issuance
- **Domain 10→9 (concurrency → duplicate legal document).** `sis_certificates_repository.ts` `issueTransferCertificate` — the **waiver** branch is race-proofed by `consumeWaiver`'s atomic guard, but the common **zero-dues / no-waiver** path skips it (`if (decision.waiver)` false), and the terminal `UPDATE students SET status='transferred'` had no status guard; `sis_certificate_issues` has no unique on `(student_id, certificate_type)` and each caller draws a distinct serial.
- **Repro:** two concurrent `POST .../transfer-certificate` for a clean-dues student → both allocate a distinct serial, both insert a TC issue row → **two serially-numbered legal TC documents**, no error.
- **Fix:** guarded the terminal students write with `AND status = <prior status we read+validated>` + throw `InvalidStudentStatusTransitionError` on 0 rows → the loser's issue row + serial roll back. Mirrors the codebase's `WHERE status='...'` atomic-transition idiom. **Test:** `sis_certificates_repository_test.ts` — "a concurrent TC on the ZERO-dues path fails closed (RT-10-1)".

### RT-3-2 (F2) · P1 · Double reversal — concurrent collection cancel without `expectedVersion`
- **Domain 3/10 (money/concurrency).** `finance_collections_repository.ts` `cancelCollection` — the optimistic-lock guard `AND ($6::int IS NULL OR row_version = $6)` is **disabled when `expectedVersion` is omitted** (the API makes it optional), with no status fallback, so a raw double-cancel double-applies the account reversal.
- **Fix:** added the unconditional `AND collection_status <> 'cancelled'` to the terminal write; the existing 0-rows→`CollectionConflictError`→rollback path now fires even with a null version. **Test:** `finance_collections_repository_test.ts` — "a concurrent cancel WITHOUT expectedVersion fails closed".

## Tracked (P2/P3 — routed to P5 / next windows; not fixed this round)

### RT-4-1 · P2 · Parent-facing AI insight bypasses the determinism number guard
- **Domain 4.** `parent_insights/parent_insights_ai.ts:141` calls `governedTextFor("parent_insights", …)` with **no `guard`**, so a model that disobeys its "never change numbers" instruction could serve a fabricated attendance/marks **%** to a parent — every comparable narrative surface (copilot/brief/director) sets a guard.
- **⚠ Corrected analysis (orchestrator):** the operator's proposed one-liner `guard: { allowDerivedPercents: true }` is the **wrong direction** — `output_guard.ts:119` treats `allowDerivedPercents:true` as *skip the percent check* (`[CURRENCY_RE]` only). To actually block a fabricated percent the guard must run the **percent** check (`allowDerivedPercents:false`/omit), which is safe **only if** the injected model context carries the real percents verbatim (else faithful restatements get falsely discarded and enrichment silently disables). **Correct fix = verify the context carries the percents, then enable the percent-checking guard, with a dedicated test.** Parent-facing → fix before GA; too subtle to rush into the frozen tree without the test. **Routed to P5.**

### RT-9-2 · P2 · `student_clearance_waivers` missing FK/CHECK (latent)
- **Domain 9.** `20260878…:18,28-29` — `student_id` has no `REFERENCES students(id)`, `maker_id`/`checker_id` have no FK to `users` and no DB-level `CHECK (checker_id <> maker_id)`, unlike the codebase precedent `inventory_stock_movements` (`20260839…:174-182`). Currently **latent**: students are never hard-deleted (only status-lifecycled), SoD is enforced in app code, and `clearance_waiver_repository.ts` is the sole writer.
- **Decision:** a corrective migration is freeze-compatible but would put repo head ahead of the deployed head (breaking the just-closed CFC-1 item 8 parity) until redeployed. **Batched to the next migration/deploy window** (with the SSH re-establishment), not applied mid-round.

### RT-4-2 · P3 · Per-role daily copilot quota is TOCTOU-racy
- **Domain 4.** `ai_copilot_quota.ts` reads committed `ai_call_log` before the turn's own row commits, so a concurrent burst can exceed the per-role/day soft limit. **Cost stays hard-bounded** by the atomic reservation (per-user/hour + per-school/day + monthly spend cap) — governance-weakening only. **Tracked to pilot quota-tuning.**

## Informational (no action; recorded to prevent a future regression)
- **ISO-C1:** `ai_call_reservations` RLS is **org-only** (no `school_id` clause), by documented design; non-exploitable because reads are app-pinned to the caller's school and consume/release key on a **server-generated** reservation id. *If a future school-scoped API is added on this table, add the `school_id` RLS clause.*
- **SoD empty-actor short-circuit:** `decideWaiver`/`approveRefund`/`approveFeeReduction` skip the maker≠checker check when the actor id is `""`. Not reachable (the server always sets `sub` from the verified JWT). Defense-in-depth: hard-fail on an empty actor id.

## Domains that converged clean (no surviving finding)
- **Domain 1 (Security):** all 19 W2 handlers auth+gate verified; persona-escalation, director aggregate-only law, search/copilot gating, clearance maker-checker (route + DB self-approve block), Face-ID SoD, cron fail-closed — all hold.
- **Domain 2 (Isolation):** the 8 new tables all FORCE-RLS + WITH CHECK on a non-bypass `erp_tenant` role; search/AI-log/reservation/persona-source queries all claims-pinned; no `service_role` on any tenant path.

## Round law
Round 1 (static surface) converged: after adversarial verification, the surviving set is the 3 fixed + 3 tracked + 2 informational above. **Round 2 is required** (the exit is *consecutive* clean rounds): it re-audits the fixed money/TC paths and runs the **live legs** (concurrent cross-tenant probes on `akshara_tenant_test`, DR restore, ops/alerts) once the owner re-establishes the SSH control-master. RT-4-1 must also be closed (with its test) before GA.

**EOS gate (P4/P5 round 1): PASS** — 3 confirmed P0/P1 fixed + regression-locked (deno **2867/0**, +3 race tests), no open P0/P1 on the static surface; P2/P3 tracked with owners.
