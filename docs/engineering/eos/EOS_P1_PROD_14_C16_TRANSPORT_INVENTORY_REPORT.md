# EOS Report — P1-PROD-14 · C16 Transport & Inventory productivity

- **Date:** 2026-07-06
- **Commit:** `5eba37d`
- **Scope:** FEATURE (Transport/Inventory) — C16 (TRN-5, TRN-6, TRN-7, TRN-8, INV-3, INV-4, INV-5, INV-6, INV-7)
- **Verdict:** **PASS** — fixes a latent runtime defect on the TRN-8 path and a broadcast-audience CHECK regression; no automatic-failure condition.
- **Standard:** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` (Part 7B / Part 8). Not restated here.

---

## 1. Method — multi-agent, discovery-first

Two disjoint modules (Transport, Inventory) → parallel read-only discovery (one
agent each), then parallel implementation under **disjoint file ownership**:
TRN-8 by a transport agent (only `_shared/transport/**`), INV-7 + INV-5 by an
inventory agent (`_shared/inventory_finance/**`, `_shared/communication/**`,
one migration, inventory client files). The one-line EXM-6 fix (exams module,
owned by neither agent) was applied by the main loop. No shared-file contention.

## 2. Per-item outcome

| Item | Verdict | Evidence |
|---|---|---|
| **TRN-5** bulk student→route allocation | **Verified built** | `handleBulkAllocateTransport` (`transport_write_handlers.ts:915`) — roster/id targets, same `buildAllocationPayload` shape as single-assign, capacity guard under route `FOR UPDATE`, per-student audit `bulk:true`; client `transport_bulk_allocation_sheet.dart`. |
| **TRN-6** transport list/vehicle exports | **Verified built** | `TransportReportExporters` (roster / student list / vehicle incl. TRN-2 expiry columns) on XCT-1 `shareGridCsv/Pdf`; wired at `transport_reports_screen.dart:89-107`. |
| **TRN-7** capacity/over-allocation warning | **Verified built** | `assertCapacity` → 409 `CAPACITY_EXCEEDED` under route lock (single + bulk); `allowOverCapacity` override audited `transport.capacity.overridden`; occupancy card + client confirm dialog. |
| **TRN-8** doc-expiry reminders | **Was PARTIAL + latently broken → closed** | §3. |
| **INV-3** manual stock-adjust | **Verified built** | `adjustStock` (reason mandatory): `adjust_in`/`opening` immediate; `adjust_out` → pending maker-checker approval (SoD; see §5). |
| **INV-4** low-stock/reorder + raise-PO | **Verified built** | `listLowStock` (qty < reorder_level, recommended qty, default vendor) + client `_LowStockSection` raise-PO reusing `createPurchaseOrder` (approval-center `inventoryPo`, self-approve-guarded). |
| **INV-5** stock/consumption/GRN exports | **Verified (stock/consumption) + GRN gap closed** | Register + low-stock exports existed on XCT-1; added GRN register: `GET /inventory/procurement/grns` (`handleListGrns`, viewInventory) + client list/provider + CSV/PDF export buttons. |
| **INV-6** physical stock-take/count session | **Verified built** | `stock_count_sessions`/`stock_count_lines` + `recordStockCount`: positive variance applies as `count_variance`; **negative variance routes through the governed maker-checker path** — never bypasses the ledger. |
| **INV-7** low-stock alert to storekeeper | **Was divergent → closed** | §4. |

## 3. TRN-8 — onto the XCT-2 rail + audience defect fixed

The handler existed but (a) sent an **immediate** broadcast instead of riding the
rail, and (b) passed `audience: "staff"` — not aliased by
`normalizeBroadcastAudience` and **not in the `comm_broadcasts.audience` CHECK**,
so any run with ≥1 expiring document violated the constraint at insert time
(the empty path masked it in tests). Rewired per the EXM-6 pattern:

- Pure exported scan `collectDocumentExpiries` (5 vehicle fields + driver
  licence, legacy free-text skipped) + core `runDocumentExpiryReminder`:
  check-at-trigger (nothing due → nothing scheduled), else ONE
  `scheduleReminder({audience: 'all_staff', remindAt: now})` on the shared rail;
  audit `transport.document.reminded` now carries `{count, withinDays, reminderId}`.
- Response backward-compatible (`{reminded, withinDays, expiries}` + new
  `reminderId`); client mapper reads only `reminded` (verified, untouched).
- New tests include a **regression guard** asserting the audience is in the exact
  CHECK token set and that `"staff"` is provably not.

**Bonus fix (main loop):** EXM-6 `handleRemindPendingMarks` read `scheduled.id`,
which the rail never returns (`broadcastId` is the key), so its `reminderId`
always fell back to a timestamp — one-line fix, exam suite 124/0.

## 4. INV-7 — storekeeper-targeted, on the XCT-2 rail

Was an on-issue immediate `all_staff` broadcast. Now:

- **Migration `20260851000000_communication_storekeepers_audience.sql`:**
  widens the audience CHECK with `storekeepers` — and **restores `all_staff`**,
  which `20260838000000`'s re-add had accidentally dropped (i.e. the pre-wave
  all_staff low-stock broadcast violated the CHECK on a fresh DB; TRN-8's fix
  also depends on this restoration). Also seeds the `storekeeper`
  role_definition + grants (viewAdminHub/viewInventory/manageInventory) — the
  client ERP role existed but was never seeded server-side, so no school could
  hold it.
- **Resolver:** `storekeepers` → active `school_memberships` with
  `role='storekeeper'`; **falls back to the exact all-staff set** when a school
  has no storekeeper, so the alert is never silently dropped (fallback query
  verified identical to the `all_staff` branch; `school_memberships` holds staff
  only — parents/students resolve via other tables).
- **Handler:** `scheduleLowStockReminderIfNeeded` — pending-dedupe (skips if a
  scheduled low-stock reminder already exists for the org/school), then
  `scheduleReminder({audience:'storekeepers', remindAt: now})`; wrapped in a
  **SAVEPOINT** so alert failure can never fail or poison the posted stock
  issue (the old code had no such guard — a broadcast failure rolled back the
  whole issue). Audit `inventory.low_stock.alerted` preserved.

## 5. Governance tripwire (money-adjacent)

- `inventory_stock_repository.ts` — **zero edits** (git-clean); its 12 governance
  tests pass untouched: FOR UPDATE lock, negative-block 422 + DB CHECK,
  maker-checker SoD 409 + DB `checker_not_maker` CHECK, immutable
  `stock_movements` (SELECT/INSERT only), stock-take negative variance via the
  governed path. Note: the as-built maker-checker is a bespoke `stock_adjustments`
  flow, not the C10 approval center — SoD intent of
  [[inventory-stock-governance-decision]] is fully enforced (409 + DB backstop);
  deliberately **not** refactored onto `decideApproval` (working governed path;
  rebuild = risk without benefit).
- Transport = demand only: TRN-9 "ZERO payment/collection code" test still green;
  bulk allocation deliberately does **not** auto-raise demands (explicit
  `POST /transport/demands` stays the only demand path).
- Reminders ride the ONE XCT-2 rail — no new scheduler, no new channel
  (in-app only; external channels stay owner-gated).

## 6. Regression evidence

- `flutter analyze` → **0 issues**.
- Full `flutter test` → **3643 passed, 2 failed — exactly the 2 known UX-7**
  TeacherDashboardScreen overflow tests (no NEW failures).
- `deno test`: transport **40/0** (+4 new) · inventory_finance **29/0** (+10 new:
  8 low-stock-reminder + 2 GRN) · communication **104/0** · exam_administration
  **124/0** · reminders **5/0**. `deno check` green on all touched files.
- **ISO-COUNT partial repair:** `communication_probe_validation_test.ts` stale
  tripwire (220) updated to the actual 233 probes — one of the 5 tracked
  ISO-COUNT tests; the remaining stale counts (payment/pilot/sis) stay tracked.
- New tests: **+17** (TRN-8 ×4 incl. audience regression guard; INV-7 ×8;
  GRN backend ×2; GRN export widget ×3).

## 7. Next

C17 — Library & Communication productivity (LIB-3/4/5, COM-3/4/5). Deps C9 + C0
(XCT-2) met. Library ∥ Communication are adjacent (LIB-5/COM-4 both ride XCT-2
and COM items live in the communication module) — assess ownership split at
discovery; COM-4 activates the dormant `scheduled_at` send path.
