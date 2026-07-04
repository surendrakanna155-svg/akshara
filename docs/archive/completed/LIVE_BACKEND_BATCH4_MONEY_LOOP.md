# Batch 4 — Money Loop (verified end-to-end on live)

Date: 2026-06-23. Live edge: **https://akshara.veloraunisexsalon.com**.

Goal: make the fee cycle **Fee structure → Invoice → Collection → Receipt** actually
persist on the live backend and **reach the parent app**, end-to-end, durably.

## Result: the full money loop works on live
Verified with the real seed tenant (Admin + Parent personas):

1. **Fee structure**: `GET /finance/fee-structures` → "Probe Structure A" (₹50,000, tuition). ✅
2. **Invoice**: `GET /finance/invoices` → `INV-PROBE-A-2026` for STU-001. ✅
3. **Collection (the untested write)**: admin `POST /finance/collections`
   `{invoiceId, amountCollected: 2500, paymentMethod: cash}` → **persisted**, receipt
   `RCPT-2026-8D99D3F5` **auto-generated**, invoice recomputed
   (outstanding 47,000 → 44,500, status `partially_paid`). Durable in Postgres. ✅
4. **Parent fees**: `GET /parent/fees` → real `totalDue: 44,500`, real installment from
   `INV-PROBE-A-2026`, real child identity. ✅
5. **Parent receipts**: `GET /parent/receipts` → both **real** receipts
   (`RCPT-2026-8D99D3F5` ₹2,500 "Paid" + `RCPT-PROBE-A-2026` ₹5,000 "Partially refunded"),
   not the stale seed cache. This feeds the app's client-side receipt-PDF builder. ✅

The receipt PDF itself is generated **client-side** in the app
(`finance_receipt_pdf_service.dart`, `pdf`/`printing` packages) from the collection
result / receipt list — so once real receipt data reaches the parent, the PDF is real.

## What was actually broken (and fixed)
The office-side money loop (structure→invoice→collection→receipt) was already fully
wired and works live. **The break was on the parent side** — two issues, both fixed:

1. **Parent fees showed stale seed data.** `/parent/fees` overlays real data via
   `overlayFeesSnapshotFromFinance()`, which queries `finance_invoices` under **parent
   scope**. But `finance_invoices` RLS was **school-scope only**, so the parent's SELECT
   returned **zero rows** and the overlay silently fell back to the seed snapshot. (Same
   trap Batch 3 hit with exams.) Proven at the DB: as parent scope, `finance_invoices`
   visible rows = 0; the invoice genuinely exists.

2. **Parent receipts came from a stale cache, not real receipts.** `/parent/receipts`
   read the `parent_entities` seed cache (`RCP-001 / "Term 1 Payment"`) via `handleList`,
   so a real collection's receipt **never** reached the parent.

### Fixes
- **RLS** — migration `20260704000000_parent_student_finance_read_rls.sql`. Adds
  parent/student **SELECT** policies on `finance_invoices`, `finance_collections`,
  `finance_receipts`, restricted to the caller's **own children** (parent, via
  `student_guardians`) or **own record** (student). No write access granted. The
  receipts policy gates via the parent's visible `finance_collections` (receipts have no
  `student_id`). Verified live: parent now sees 1 invoice / 2 collections / 2 receipts.
- **Real receipts overlay** — new `overlayReceiptsFromFinance()` in
  `pilot/pilot_operations_repository.ts` queries `finance_receipts → finance_collections
  → finance_invoices` and shapes each item to the exact fields the app expects
  (`receiptNumber, title, dateLabel, amount, paymentMethod, statusLabel, childName,
  childClass, category, lineItems, schoolName`). New handler
  `handleFinanceReceipts` in `entity_read/mobile_read_handlers.ts`; `handleReceipts`
  (parent_handlers.ts) now uses it instead of the `parent_entities` cache.
- **Consistency tightening** — the fees overlay now also corrects child identity from
  real records (was showing the stale seed name "Ravi Kumar / 8-A"); friendly receipt
  status labels (`completed→Paid`, `partially_refunded→Partially refunded`, …).

## Files changed (uncommitted on branch feature/scope-trim-school-build)
- `supabase/migrations/20260704000000_parent_student_finance_read_rls.sql` (new)
- `supabase/functions/_shared/pilot/pilot_operations_repository.ts`
  (`overlayReceiptsFromFinance`, fees-overlay identity fix, status labels)
- `supabase/functions/_shared/entity_read/mobile_read_handlers.ts` (`handleFinanceReceipts`)
- `supabase/functions/_shared/parent/parent_handlers.ts` (wire real receipts)
- `supabase/functions/_shared/pilot/pilot_finance_overlay_test.ts` (new, 3 tests)

## Deploy notes
- Edge bind-mounts `/opt/akshara/functions` (read-only) → `/app`. Deploy = `scp` the
  changed `_shared/**` files to the VPS + `docker compose restart akshara-edge`. (No env
  change, so the Batch-2 `--force-recreate` gotcha does not apply here.)
- Migration applied live as `supabase_admin` and recorded in
  `supabase_migrations.schema_migrations` (version `20260704000000`).

## Tests
- New: 3 Deno tests for the finance overlays (`pilot_finance_overlay_test.ts`).
- Regression: finance handlers 76 green; parent/pilot/entity_read 22 green.
- `flutter analyze`: 0 errors (app code unchanged this batch; pre-existing info/warning
  lint in unrelated files remains).

## Open follow-ups (not blocking the loop)
- **Cosmetic**: `/parent/dashboard` and `/parent/attendance` still show the stale seed
  child name (Batch 3 follow-up); fees/exams/receipts overlays now correct identity.
- **Fees overlay depth**: `/parent/fees` overlays `totalDue` + installments + identity.
  Richer fields the app can show (paidAmount, progress %, category breakdown, payment
  history) still come from the snapshot defaults — enrich later if needed.
- **Discounts**: app `createDiscountRule/updateDiscountRule` still throw
  `UnimplementedError` (pending finance-backend wiring) — out of the core money loop.
- Test data left in staging: collection `RCPT-2026-8D99D3F5` (₹2,500 cash) on
  `INV-PROBE-A-2026` from this verification.
