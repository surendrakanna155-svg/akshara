# EOS Report — P1-PROD-7 · C9 · Operational Modules: Inventory, Library & Communication

**Scope:** FEATURE (Operations) — INV-1/2, LIB-1/2, COM-1/2.
**Date:** 2026-07-04 · **Gate:** **PASS** (0 P0 / 0 P1) · **Ledger:** appended.
**Anchors:** Constitution Part 7B (*Certification Categories*, *Evidence Requirements*, *Automatic-Failure Conditions* — esp. *permission escalation* / data integrity via SoD), Part 8 (*Release Decision*); EOS rule #4. Cites the law; does not restate it.

---

## 1. Discovery-first — all six items already built (memory was stale)

The 2-day-old inventory memory ("no stock-out/adjust/count/ledger yet") is **stale** — INV-1/3/6 are fully built. All six C9 items EXIST end-to-end with real, RLS-scoped persistence. Completion criterion (`FINAL_QA_ROADMAP.md:559`) met.

| Item | Verdict | Evidence |
|---|---|---|
| **INV-1** stock issue + issue slip | ✅ EXISTS (governance intact) | `inventory_stock_repository.ts issueStock` (`SELECT … FOR UPDATE` lock, decrements `quantity_on_hand`, idempotent re-post guard); **negative stock hard-blocked** (`InsufficientStockError`→422 + migration `20260839000000` DB `CHECK (quantity_on_hand >= 0)`); **immutable `stock_movements` ledger** (GRANT SELECT/INSERT only, qty_before→qty_after); **maker-checker** on value-reducing moves (`stock_adjustments` `CHECK (checker_id <> maker_id)`, `adjust_out` records pending, self-approve→409). |
| **INV-2** consumable registry + reorder CRUD | ✅ EXISTS | `item_type`/`reorder_level` columns; `upsertStockItem`/`listStockItems`/`listLowStock (qty < reorder_level)`; client upsert dialog + low-stock section. |
| **LIB-1** overdue list + export | ✅ EXISTS | `overdueList` (`daysOverdue>0`+fine) → `GET /library/overdue`; client overdue screen exports via `AksharaReportExportService`. |
| **LIB-2** catalog edit/delete + CSV bulk import | ✅ EXISTS (+ new import test) | `handleBulkImportBooks` (per-row SAVEPOINT rollback + dup-ISBN dedupe + partial-success), `handleUpdate/DeleteBook`; client CSV parser + edit/delete UI. |
| **COM-1** delivery/read report + CSV export | ✅ EXISTS | `getBroadcastDeliveryReport` (counts from `notification_deliveries WHERE broadcast_id`, unread roster) → `GET /communications/broadcasts/{id}/report`; client `BroadcastReportScreen` CSV export; tests `broadcast_report_test.ts`. |
| **COM-2** audience picker + saved segments | ✅ EXISTS | `comm_audience_segments` + `resolveBroadcastRecipients` (class_parents/class_students/…); segment CRUD; client audience UI; tests `communication_audience_ack_test.ts`. |

## 2. Governance boundary — VERIFIED (inventory)

Per [[inventory-stock-governance-decision]]: value-reducing movements = maker-checker; negative stock hard-blocked; immutable ledger. **All confirmed in code + tests** (`inventory_stock_repository_test.ts`: INV-1 decrement + before→after movement, over-on-hand 422, maker-checker pending + self-approve-blocked). No change needed — verified intact.

## 3. Gap closed — LIB-2 bulk-import handler coverage

`handleBulkImportBooks` (a data-write path with dedupe + per-row partial-success) had **no unit test** — the only C9 gap. Rather than build a full `runWrite` auth+db harness (not the codebase's pattern — it tests pure logic + repo functions), I extracted the pure per-row decision into `planImportRow(raw, id, seenIsbns)` ([library_write_handlers.ts](../../../supabase/functions/_shared/library/library_write_handlers.ts)) — **behavior-preserving** (the handler still owns SAVEPOINT/INSERT; dedupe now decided before the savepoint, removing a wasted savepoint on dedupe-rejected rows — same observable `{imported, failed}`). Tested it: `library_write_handlers_test.ts` — valid row accepted with payload; non-object rejected; missing-required-field collected as a per-row failure (not thrown); duplicate ISBN rejected.

## 4. Automatic-failure check (Part 7B) — none

Backend-only, minimal behavior-preserving extraction. The inventory SoD (maker≠checker, self-approve 409) and negative-stock guards are unchanged and test-green. No money, no auth, no data-loss surface changed.

## 5. Regression evidence

- `deno test … _shared/inventory_finance/ _shared/library/` → **76 passed / 0 failed** (+4 `planImportRow` tests).
- `deno test … communication/broadcast_report_test.ts communication_audience_ack_test.ts` → **27 passed / 0 failed**.
- `deno check supabase/functions/api/index.ts` → clean.
- No `lib/**` changes → the Flutter suite is unaffected (3616 pass / 2 known UX-7 → P2-UX); `flutter analyze` 0 at last run.
- Pre-existing **ISO-COUNT** (`communication`/`sis` probe-count) unchanged — untouched, tracked defect.

## 6. Verdict

**EOS gate: PASS.** 0 P0 / 0 P1. All six C9 items verified existing (governance intact — no rebuild); the one genuine gap (LIB-2 bulk-import test) closed via a behavior-preserving pure-function extraction + tests; no automatic-failure; regression green. **Advance → C10 (Principal — Approval Center batch actions).**

**Commit:** `2ecee77` (refactor+test) · docs(eos) close companion follows.
