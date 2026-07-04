# EOS Report — P1-PROD-1 · C1 · Finance Fee Recovery / Collections CRM (FIN-R1..R5)

**Scope:** FEATURE (Finance) — the fee-recovery / collections CRM wave.
**Date:** 2026-07-04 · **Gate:** **PASS** (0 P0 / 0 P1) · **Ledger:** appended.
**Anchors:** Constitution Part 7B (*Certification Categories*, *Evidence Requirements*, *Automatic-Failure Conditions*), Part 8 (*Release Decision*). Cites the law; does not restate it.

---

## 1. Discovery-first (verify before build)

The recovery CRM was already substantially built. Verified EXISTING and **not** rebuilt:
- **FIN-R1 recovery dashboard** — backend `handleRecoveryDashboard` + `recoveryAggregates` ([finance_recovery_repository.ts:341](../../../supabase/functions/_shared/finance/finance_recovery_repository.ts#L341)); client `_RecoverySection` ([finance_defaulters_screen.dart](../../../lib/features/finance/defaulters/finance_defaulters_screen.dart)). ✅
- **FIN-R3 promise-to-pay** — full lifecycle (create/list/resolve, one-way `pending`→kept/broken/cancelled guard); backend + client dialogs + notifiers. ✅
- **FIN-R5 collector performance** — backend `collectorPerformanceForMonth` derives contacts/PTPs/₹-recovered per collector from **real rows** (`finance_recovery_contacts` ⋈ `finance_promises_to_pay` ⋈ completed `finance_collections`). ✅ (The mock repo uses clearly-labelled demo collectors — a mock parity choice, not a production path; a contract test pins it.)

## 2. Real gaps closed

**FIN-R2 — telecaller call queue (was entirely missing).** Built server-authoritative, riding the SAME candidate source as the defaulters list (no duplicate source):
- Backend: `listCallQueue` ([finance_recovery_repository.ts:121](../../../supabase/functions/_shared/finance/finance_recovery_repository.ts#L121)) selects the open/overdue accounts enriched with last-contact / nearest pending promise / broken-promise signals; **pure** ranking `callQueuePriority`/`callQueueReason` + `handleFinanceCallQueue` sort ([finance_recovery_handlers.ts](../../../supabase/functions/_shared/finance/finance_recovery_handlers.ts)); route `GET /finance/recovery/call-queue` (viewFinance).
- Client: `CallQueueEntry` model + full repo lane (interface/api/remote/hybrid/mock) + DTO/mapper + `financeCallQueue*` providers + `_CallQueueSection`/`_CallQueueTile` on the defaulters screen — reuses the existing log-contact / PTP dialogs (no duplicate dialogs).
- Evidence: `finance_recovery_test.ts` (7/7 — ranking tiers incl. broken-promise=0, due-promise=1, future-promise de-prioritised=5, never-contacted=2, stale=3, recent=4; row mapping; query shape); route-contract adds the call-queue route (viewFinance/403); `fin_r2_call_queue_widget_test.dart` (2/2 — renders ranked entries + the **round-trip**: pick from queue → log outcome → queue re-ranks live).

**FIN-R4 — contact-history sheet read stale embedded data.** Fixed: `showContactHistorySheet` now reads the live `financeStudentContactsFutureProvider` (falls back to embedded history while loading/on error), so a contact just logged this session appears immediately. Same live path is exercised by the FIN-R2 round-trip (mutation → `_invalidateRecoveryReads` incl. the call queue).

## 3. Completion criteria (roadmap `FINAL_QA_ROADMAP.md:551`) — met

"Call queue → log outcome → PTP → contact-history persist round-trip; collector metrics compute from real data."
- Call queue → log outcome → re-rank: proven by `fin_r2_call_queue_widget_test.dart`.
- PTP: create/resolve lifecycle exists (FIN-R3) and is reachable from the queue tile.
- Contact-history persists + surfaces live: FIN-R4 fix + mock contract round-trip.
- Collector metrics from real data: FIN-R5 backend aggregate (§1).

## 4. Automatic-failure check (Part 7B) — none

The recovery CRM is **additive** and never touches the collection/invoice money path (repo header + code). No duplicate financial transaction, no data loss, no auth break. RBAC: reads `viewFinance`, writes `manageFinance` (route-contract asserts holder-passes / other-403); RLS scopes every recovery table to tenant + `app_current_scope()='school'`.

## 5. Regression evidence

- `flutter analyze` → **0**.
- `flutter test` (full) → **3613 passed / 2 failed / 0 new** (the 2 are pre-existing **UX-7** TeacherDashboard 360×640 overflow → P2-UX).
- `deno test --allow-env --allow-read supabase/functions/_shared/finance/` → **143 passed / 0 failed** (incl. new FIN-R2 unit tests + call-queue route-contract).
- `deno check supabase/functions/api/index.ts` → clean.

## 6. Verdict

**EOS gate: PASS.** 0 P0 / 0 P1. FIN-R2 built (the one real gap) + FIN-R4 fixed; FIN-R1/R3/R5 verified existing (no rebuild, no duplication); completion round-trip proven; no automatic-failure; regression green (2 known UX-7 carried). **Advance → P1-PROD-2 (C2).**

**Commit:** `c1b9feb` (feat) · docs(eos) close companion follows.
