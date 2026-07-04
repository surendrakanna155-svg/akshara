# EOS Report — P1-PROD-6 · C8 · Transport Fleet, Roster & Fee (TRN-1/2/3/4/9) — VERIFICATION

**Scope:** FEATURE (Transport) — fleet CRUD, document-expiry, stop roster/editor, and the Transport→Finance fee demand.
**Date:** 2026-07-04 · **Gate:** **PASS (covered by existing implementation + tests; money boundary verified intact — no gap safe to close)** · **Ledger:** appended.
**Anchors:** Constitution Part 7B (*Certification Categories*, *Evidence Requirements*, *Automatic-Failure Conditions* — esp. *duplicate financial transaction*), Part 8 (*Release Decision*); EOS rule #4. Cites the law; does not restate it.

---

## 1. Outcome — C8 already implemented; money boundary CONFIRMED intact

Discovery-first found all five items built with real, RLS-scoped, audited persistence. Completion criterion (`FINAL_QA_ROADMAP.md:558`: "fleet CRUD persists; stop rosters export; transport demand appears in Finance — no duplicate payment logic") is met. **No code change** — the only candidate gap is a subtle money-adjacent concurrency item that is NOT safe to hot-patch (§3).

| Item | Verdict | Evidence |
|---|---|---|
| **TRN-1** vehicle & driver CRUD | ✅ EXISTS | `handleCreate/Update/DeleteVehicle`/`…Driver` (`transport_write_handlers.ts`), dup-registration/licence 409 guards, in-use delete guards, audited; real Dio client + dialogs. Tests: `trn_transport_actions_widget_test.dart`, `transport_write_handlers_test.ts`. |
| **TRN-2** document-expiry tracker | ✅ EXISTS | Strict ISO `isStrictIsoDate` (422 on bad), 5 vehicle expiry fields + driver licence; client `_ExpiryDateField` → `showDatePicker` (not free-text) + expiring-soon scanner/view. |
| **TRN-3** stop-wise roster + export | ✅ EXISTS | `buildRoster` (`GET /transport/routes/{id}/roster`, grouped by stop sequence); client exports via `AksharaReportExportService.shareGridPdf/shareGridCsv`. |
| **TRN-4** stop editor / ordering | ✅ EXISTS | row-locked `mutateRouteStops` add/update/remove/reorder with auto 1-based resequence + permutation validation. |
| **TRN-9** fee → Finance demand | ✅ EXISTS (money boundary intact) | `handleRaiseTransportDemand` → `assignFeeStructure` (creates assignment+invoice+installments); Transport selects a Finance `transport`-category fee structure. |

## 2. Money boundary — VERIFIED (Part 7B: no duplicate financial transaction)

Per the owner decision ([[trn9-transport-fee-account-decision]]): Transport defines fee/demand; **Finance is the sole payment engine**.
- **Zero payment/collection code in Transport** — grep of the transport backend + client for `createCollection` / `finance_collections` / `collectPayment` finds only doc-comments + UI copy ("Finance collects payment — no payment is taken here"). This is **enforced by a passing unit test**: `transport_write_handlers_test.ts:540` "TRN-9: transport contains ZERO payment/collection code" (strips comments, asserts none of the transport handlers/router/repo call `createCollection(` or reference `finance_collections`). **Ran this wave → green.**
- **Get-or-create per-year account** confirmed in `finance_assignments_repository.ts:113` `createAssignmentAndAccount` — reuses the existing `finance_student_accounts` row (one per student+year, many invoices) instead of throwing `DuplicateStudentAccountError`; tuition + transport coexist. Test `finance_assignments_repository_test.ts:261` (ONE account, aggregated) — green.
- **Double-invoice prevented** — re-assigning the SAME (student, structure, year) throws `DuplicateAssignmentError` at the Finance layer.

## 3. The one candidate gap — NOT safe to hot-patch (recorded as a tracked hardening item)

The TRN-9 demand dedupe on `(sisStudentId, routeId, academicYear, term)` is enforced in **application code** (`transport_write_handlers.ts:1196`, a scan + in-memory match) — there is **no DB UNIQUE index** on that tuple. Under concurrent identical raises the read-then-insert is racy.

- **Money risk is already contained:** a double raise still cannot create a second invoice — the Finance-side `finance_fee_assignments` per-(student, structure, year) uniqueness rejects it (`DuplicateAssignmentError`). So there is **no duplicate-financial-transaction exposure** (no automatic-failure).
- **Why not hot-patch it here:** the obvious "catch `DuplicateAssignmentError` → return idempotent" is **incorrect** — the demand dedupe is **route-scoped** while the assignment uniqueness is **structure-scoped**. A legitimately *different-route* transport demand for a student who already has that transport structure assigned that year would be wrongly swallowed as "idempotent." Reconciling route-vs-structure semantics + a proper partial-unique index on the JSONB `dedupeKey` is a money-adjacent **design** change, not a safe drive-by fix.
- **Tracked → `TRN9-DEDUPE`:** future hardening pass (DB partial-unique index on `transport_entities (payload->>'dedupeKey') WHERE entity_type='demand'`, scoped org+school, designed with the route/structure semantics) — a live-lane migration + design item, surfaced not silently fixed.

## 4. Regression evidence (gates run this wave)

- `deno test --allow-env --allow-read supabase/functions/_shared/transport/` → **36 passed / 0 failed** (incl. the money-boundary enforcing test).
- `deno test … finance_assignments_repository_test.ts` → **12 passed / 0 failed** (get-or-create).
- `flutter test test/features/transport/` → **42 passed / 0 failed**.
- No files modified → `flutter analyze` unaffected (0 at last run); full suite unaffected (3616 pass / 2 known UX-7 → P2-UX).

## 5. Verdict

**EOS gate: PASS — C8 covered by existing implementation + tests; money boundary verified intact and test-enforced.** 0 P0 / 0 P1. No code change (no safe gap to close — the dedupe-race is money-contained and requires design, tracked as `TRN9-DEDUPE`). **Advance → C9 (Operational Modules — Inventory, Library & Communication).**

**Commit:** docs(eos)-only (verification close — no code change).
