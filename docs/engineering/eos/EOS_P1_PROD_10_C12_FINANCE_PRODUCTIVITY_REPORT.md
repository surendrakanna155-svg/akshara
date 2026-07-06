# EOS Report — P1-PROD-10 · C12 Finance Productivity & Receipting

- **Date:** 2026-07-06
- **Commit:** `2bd7ecd`
- **Scope:** FEATURE (Finance) — C12 (FIN-3, FIN-4, FIN-5, FIN-9, FIN-R6, FIN-R7)
- **Verdict:** **PASS** — money-safety tripwire intact; no automatic-failure condition triggered.
- **Standard:** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` (Part 7B / Part 8). This report does not restate the Constitution.

---

## 1. Method — discovery-first

Per the standing C-wave pattern (verify-not-rebuild), a read-only discovery pass mapped the
existing Finance receipt/analytics/instrument surface before any code was written. Result:
**FIN-4/5/9 already built**; **FIN-3** had a concrete formatting gap; **FIN-R7/FIN-R6** were
partial. Only genuine, safe gaps were closed.

## 2. Per-item outcome

| Item | Status | Evidence |
|---|---|---|
| **FIN-3** Indian-format receipt | **Gap closed** | Amount-in-words + ORIGINAL/DUPLICATE already present. The receipt `_formatInr` (and two sibling formatters) grouped digits Western-style (`1,234,567`), contradicting the correct Indian amount-in-words on the same page. Added shared `indianDigitGroups` (Lakh/Crore) in `lib/core/reports/amount_in_words.dart`; wired `finance_receipt_pdf_service.dart`. (+5 tests). Real logo/letterhead image remains a branding-asset dependency (placeholder retained — not fabricated). |
| **FIN-4** Duplicate reprint | **Verified built** | `ReprintReceiptNotifier` stamps `copyLabel:'DUPLICATE'` + audits `reprintReceipt`, `manageFinance`-gated (`finance_mutations_provider.dart:962`). |
| **FIN-5** Batch printing | **Verified built** | `buildBatchReceiptsPdf` + `BatchPrintReceiptsNotifier` + UI (`finance_collections_screen.dart:353`). |
| **FIN-9** Outstanding analytics | **Verified built** | Shared `overdueDaysSql` aging → defaulters/reports/intelligence on real `finance_collections`/`finance_invoices`. |
| **FIN-R7** Cheque/DD/PDC + bounce | **Built (money-safe)** | See §3. |
| **FIN-R6** Collection targets | **Built** | FIN-D6 resolved by owner (principal sets, collectors see own). See §4. |

## 3. FIN-R7 — money-safety analysis

`finance_offline_payments` is a **tracking-only ledger**: neither `createOfflinePayment` nor
`reconcileOfflinePayment` writes to `finance_collections` or sets `collection_id`, and nothing
sums the table into dues/collected totals (grep-verified — referenced solely by its own
repo/handlers/tests). Therefore:

- Added `pdc` method + `instrument_date`/`bank_name` metadata + a terminal `bounced` status
  with a bounce audit trail (migration `20260850000000`).
- `bounceOfflinePayment`: only reachable from `pending_reconciliation`; a **reconciled (cleared)
  instrument cannot be bounced** and a **bounced instrument cannot be reconciled** (both → 409),
  idempotent on repeat.
- **A bounce posts and reverses NO money.** Any refund of money already collected against a
  dishonoured instrument remains a separate manual Finance action. **Finance stays the sole
  payment engine.**
- Full client stack (enum/codec/model/mapper/request/repo×3/notifier/api-path/screen: PDC
  option, instrument fields, Bounced tab, mark-bounced dialog).
- Coverage: `fin_r7_instrument_bounce_test.ts` (6) — PDC metadata, bounce flips pending→bounced
  with `collection_id` null (money-safe), terminal + idempotent, mutual exclusion, unknown-id
  reject; route-contract row; `qa_x_022` reconcile-integrity preserved.

## 4. FIN-R6 — FIN-D6 resolution

Owner decision **FIN-D6 = "principal sets, collectors see own"** (2026-07-06). The targets
backend (table, upsert/list, endpoints, audit) already existed but was client-unwired and
attainment was uncomputed. Enriched the recovery dashboard `collectorPerformance` with `target`
+ `attainmentPct` by joining the existing FIN-R5 `collectorPerformanceForMonth` (read-only) with
`listRecoveryTargets` — no new money math. Added a `manageFinance`-gated set-target action →
`setCollectionTarget` (backend audits `finance.recovery.target_set`). (+2 contract tests.)

## 5. Regression evidence

- `flutter analyze` → **0 issues**.
- Full `flutter test` → **no NEW failures**; the 2 failing tests are the known UX-7
  `TeacherDashboardScreen` 360×640 overflow pair (unrelated to Finance).
- `deno test` finance + audit → **172 / 0**.
- `deno check` on all touched `supabase/functions/**` → green.
- New tests this wave: **13** (FIN-3 ×5, FIN-R7 backend ×6, FIN-R7 + FIN-R6 contract ×2).

## 6. Tripwire check

No automatic-failure condition: no data loss, **no duplicate/added financial transaction**
(FIN-R7 bounce and FIN-R6 targets touch no money ledger), no security/RBAC/tenant-isolation
regression (new routes RBAC-gated + route-contract updated), SoD unaffected, no critical
regression. **PASS.**

## 7. Next

C13 (Academic-work productivity) — Exams half **EXM-4/5/6/7** proceeds; Homework half
(HWK-3..8) defers with C6 pending the HWK-1 owner migration.
