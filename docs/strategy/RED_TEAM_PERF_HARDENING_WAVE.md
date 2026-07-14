# P4-RT-1 · Performance-Hardening Wave (routed from round-3 Domain 11)

**Date:** 2026-07-14 · **Owner directive:** execute the routed performance-hardening work in its proper wave.
**Scope:** the 10 Domain-11 findings from [`RED_TEAM_P4_RT1_ROUND3_REPORT.md`](RED_TEAM_P4_RT1_ROUND3_REPORT.md). Post-FREEZE-1 performance work is permitted; each change is behavior-preserving + tested; the large architectural item is designed, not rushed.

## Status

| ID | Sev | Status | Notes |
|---|---|---|---|
| **RT-11-6** | P1 | ✅ FIXED | `comm_broadcasts` search index — migration `20260880` (round 3). |
| **RT-11-7** | P2 | ✅ FIXED | `finance_invoices` `lower(invoice_number)` functional index — migration `20260881`. |
| **RT-11-2** | P1 | ✅ FIXED + TESTED | `accrueLateFees` set-based rewrite (below). |
| **RT-11-1** | P1 | 📐 DESIGNED → dedicated AI-connection-hardening wave | large architectural refactor; design below. RT-1 stays OPEN on this. |
| **RT-11-3** | P2 | ⏳ tracked | `computeAndStoreRiskSnapshots` / `computeAndStoreStudentSuccessSnapshots` per-student INSERT loop (`student_risk_repository.ts:196-232`, `student_success_service.ts:251-291`) → one multi-row `INSERT … SELECT unnest(...)`. Admin-triggered (not per-page). Behaviour-preserving set-based rewrite. |
| **RT-11-4** | P2 | ⏳ tracked | `generateSeating` per-seat INSERT loop (`exam_administration_repository.ts:2266-2286`) → multi-row insert. |
| **RT-11-9** | P2 | ⏳ tracked | parent priority-feed 5×per-child round trips + a duplicate identity lookup (`parent_sources.ts:145-176` vs `pilot_operations_repository.ts:1517`) → batch `WHERE student_id = ANY($childIds)` (the same file already does this for homework). Remove the duplicate lookup first (pure waste). |
| **RT-11-8** | P2 | ⏳ tracked | global search runs ≤6 category queries sequentially on one held connection (`search_handlers.ts:175-184`) → `Promise.all` the permitted-category queries. |
| **RT-11-5** | P1? | ⏳ BLOCKED (ops) | notification drain sends sequentially per batch holding a pool connection; **P1 only if the self-hosted edge runtime lacks `EdgeRuntime.waitUntil`** — needs a VPS ops check (VPS was down at wave time). If `waitUntil` is present the response doesn't block (P2); if absent, parallelize the per-batch sends + confirm. |

## RT-11-2 — accrueLateFees set-based rewrite (FIXED)
`finance_late_fee_repository.ts`. The old loop `SELECT … FOR UPDATE OF fi` locked **every** overdue invoice, then ran 2 sequential UPDATEs per invoice — holding all those locks (and blocking any concurrent collection on them) for the whole batch's round-trip time. Rewrite: non-locking candidate read → compute fees in JS (formula unchanged) → **two** set-based `UPDATE … FROM unnest($ids,$fees)` writes. The transaction now commits in ~2 round trips (locks released far sooner). The writes are **delta-based + guarded on `late_fee_amount = 0`**, which is also *safer* than the prior absolute write — a concurrent collection's outstanding reduction is preserved, and a concurrent accrual run can't double-apply (the guard skips already-accrued rows, RETURNING excludes them from the per-account roll-up). Tests: `finance_late_fee_accrual_test.ts` (correct per-invoice fee + per-account delta · same-account roll-up · already-accrued guard).

## RT-11-1 — AI-gateway holds the tenant DB pool connection across the LLM call (DESIGN)
**Verified:** `model_gateway.ts` `governedModelText(db, …)` uses the caller's tenant `db` for `readUsage` (pre-call) and `safeRecord` (post-call); the reservation is already out-of-band (`reserveOutOfBand`, its own connection). But the **caller** wraps the whole op in `withTenantContext`, so the tenant connection is held **idle-in-transaction across the ~20s `callModel` fetch** (`model_gateway.ts:641`). Replicated at ~10 AI call sites (copilot, director, parent_insights, hr_dashboard, predictions, brief, education gapfill, org-builder, school-builder, publisher). `POOL_SIZE=10` per isolate → ~10 concurrent AI requests saturate the pool and queue *every* other module for up to 20s.

**Why not a contained fix:** the gateway cannot release the caller's transaction (the caller owns it). The fix is at the **handler** level and must preserve the reservation/cost-logging/cache invariants (money-adjacent). Design:
1. Add a pooled gateway entry (`governedTextForPooled(config, claims, …)`) that runs its own DB ops (`readUsage`, `safeRecord`) on **short-lived out-of-band connections** (mirroring `reserveOutOfBand`) and holds **no** connection during `callModel`.
2. Restructure each AI handler: `const ctx = await withTenantContext(cfg, claims, db => readContext(db))` (txn 1, released) → `await governedTextForPooled(cfg, claims, ctx, …)` (LLM, no tenant conn held) → persist any result in a fresh short txn.
3. Preserve: out-of-band reservation atomicity (unchanged), the output guard, the deterministic fallback, cache read/write, and the `ai_call_log` accounting.
**Test plan:** unit-test `governedTextForPooled` (no connection held during a stubbed slow `callModel`); per-handler contract tests unchanged; a concurrency test asserting N>POOL_SIZE concurrent AI calls don't block a non-AI query.
**Routing:** dedicated **AI-connection-hardening wave** (design-first). RT-1 remains OPEN on this P1. Not currently triggered on the pilot (AI tables empty), so no live exposure today — but it gates scale.

## Round-law note
This wave FIXED 2 of the 3 perf P1s (RT-11-2, RT-11-6) + an index (RT-11-7); the 3rd P1 (RT-11-1) is designed and routed; RT-11-5 is ops-blocked; the P2s are tracked with anchors. **The perf wave (and RT-1) remain OPEN** until RT-11-1 lands, RT-11-5's ops check + fix, and the P2 set-based rewrites are done — then a re-audit round confirms no new perf P0/P1.
