# EOS Report — P1-PROD-2 · C2 · Finance Counter, Statements & Reports (FIN-1/2/6/7/8)

**Scope:** FEATURE (Finance) — daily/counter reports, student ledger, and the installment-driven due schedule.
**Date:** 2026-07-04 · **Gate:** **PASS** (0 P0 / 0 P1) · **Ledger:** appended.
**Anchors:** Constitution Part 7B (*Certification Categories*, *Evidence Requirements*, *Automatic-Failure Conditions*), Part 8 (*Release Decision*). Cites the law; does not restate it.

---

## 1. Discovery-first (verify before build) — most of C2 already existed

| Item | Verdict | Evidence |
|---|---|---|
| **FIN-1** daily collection summary export | EXISTS (real, shared pipeline) | `GET /finance/collections/daily-summary` (`finance_collections_repository.ts:getDailySummary`, real query over collections+invoices); client `_exportSummary` via `AksharaReportExportService.shareTabularCsv`. |
| **FIN-2** printable student fee statement / ledger | EXISTS (real, shared PDF) | `GET /finance/student-accounts/{id}/ledger` (`finance_ledger_repository.ts`, real running-balance; cancelled collections excluded — `finance_d_features_test.ts:302,373`); client `_exportStatement` via `buildGridReportPdf`. |
| **FIN-7** transaction-level day collection report | EXISTS (real, shared CSV grid) | `GET /finance/collections` list; client `_exportCollections` via `shareGridCsv` (one row per transaction). |
| **FIN-8** class-wise dues report | EXISTS (real, shared CSV grid) | `exportClassWiseDues` (`finance_recovery_actions.dart`) groups the real defaulter feed by class via `shareGridCsv`. |

All four export **real transactions** through the XCT-1 shared pipeline — the C2 "each report exports real transactions" criterion is met by verified existing code (no rebuild, no hand-rolled CSV/PDF).

## 2. Real gap closed — FIN-6 (the C2 completion criterion: *installment due dates drive aging*)

The term-wise schedule (`finance_invoice_installments`, generation, endpoint, client display) already existed but was **informational only**: aging still keyed off the single `finance_invoices.due_date`, and a **hardcoded `+30`** survived in the draft→issued transition.

- **Removed the last hardcoded due date:** [finance_invoices_repository.ts issueInvoice](../../../supabase/functions/_shared/finance/finance_invoices_repository.ts#L206) now honours the school's `payments.due_days` setting (default 30) and generates the installment schedule on issue — same as the create path.
- **Aging now driven by the installment schedule:** new shared SQL helper `overdueDaysSql` ([finance_aging.ts](../../../supabase/functions/_shared/finance/finance_aging.ts)) — a student's days-overdue is computed from the **earliest installment term due date** (`COALESCE(MIN(installment.due_date), invoice.due_date)`). Applied to **every** finance aging read so they can never diverge: defaulters (`finance_defaulters_handlers.ts`), recovery call queue (`finance_recovery_repository.ts listCallQueue`), finance-intelligence defaulter predictions (`finance_intelligence_service.ts`), and — to keep its stated parity true — student-risk (`intelligence/student_risk_repository.ts`).
- **Behaviour-preserving by default:** the default `installment_terms = "1"` yields one term whose due date equals the invoice `due_date`, and legacy/un-scheduled invoices fall back via COALESCE — so single-term invoices age **exactly as before**; only genuine multi-term schedules change (they now correctly age from term 1).
- Evidence: `finance_aging_test.ts` (4/4 — helper ages off `MIN(installment)` with `due_date` fallback + old single-column aging gone; call-queue query ages via installments; `issueInvoice` drops `CURRENT_DATE + 30` for a param-driven date and generates the schedule; behaviour-preserving COALESCE documented).

## 3. Automatic-failure check (Part 7B) — none

FIN-6 aging is **informational only** — no money movement (the invoice's single outstanding stays authoritative; installments never hold money). The money-affecting late-fee accrual (`finance_late_fee_repository.ts`, `due_date + grace_days`) was deliberately **left untouched** — out of aging scope. No duplicate financial transaction, no data loss, no auth break. RBAC/RLS on all touched reads unchanged.

## 4. Regression evidence

- **No `lib/**` changes this wave** (backend-only) → the Flutter suite is unaffected (last full run 3613 pass / 2 known UX-7 → P2-UX).
- `flutter analyze` → **0**.
- `deno test --allow-env --allow-read supabase/functions/_shared/finance/` → **147 passed / 0 failed** (+4 FIN-6 tests).
- `deno test ... _shared/intelligence/` → **51 passed / 0 failed** (student-risk aging change verified).
- `deno check supabase/functions/api/index.ts` → clean.

> **Evidence-grade note:** the aging SQL is verified at the query-shape + pure-logic level (this lane has no live DB); live numeric re-verification of multi-term aging rides the deferred live lane. The change is behaviour-preserving for the default single-term config, bounding the risk.

## 5. Verdict

**EOS gate: PASS.** 0 P0 / 0 P1. FIN-1/2/7/8 verified existing (real exports on the shared pipeline — no rebuild); FIN-6 closed (hardcoded +30 removed; installment due dates now drive aging across all finance aging reads, behaviour-preserving by default); no automatic-failure; regression green (2 known UX-7 carried). **Advance → C4 (Exams — Fast Marks & Tabulation, O2 top-priority).** Note: C3 (Staff Attendance Dashboard & Muster) **defers** — it depends on Phase B B4 / GA-1 live (staff-attendance / live-lane, owner-gated).

**Commit:** `fa30e00` (feat) · docs(eos) close companion follows.
