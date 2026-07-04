# Batch 5 — Module Writes + Server RBAC (live)

Date: 2026-06-23. Branch `feature/scope-trim-school-build`. Backend: live VPS
(`https://akshara.veloraunisexsalon.com`, edge at `127.0.0.1:3000`).

Batch 5 turned the remaining secondary-module **writes** from
`ApiNotConnectedException` / `UnimplementedError` stubs into real, persisted,
RBAC-enforced backend operations, and closed a known attendance privacy leak.

## What shipped

### Reusable module-entity write framework (server)
Reads already used a JSONB `{module}_entities` store via `createEntityReadStore` +
`createModuleReadHandlers`. Batch 5 adds the write counterparts:

- `_shared/entity_write/entity_write_store.ts` — `createEntityWriteStore`:
  `insert` / `replace` / `find` / `findAll` / `remove` + `mutateSnapshot`
  (read-modify-write for snapshot docs). RLS (`FOR ALL`, school scope) +
  `erp_tenant` INSERT/UPDATE/DELETE grants already existed on these tables.
- `_shared/entity_write/module_write_handlers.ts` — `createModuleWriteHandlers(managePermission)`:
  enforces `requirePermission(manage*)` + `requireSchoolOperationalScope`, runs
  the write **and its audit row in one tenant transaction** (commit/rollback
  together), maps `WriteValidationError`/`WriteNotFoundError`. Plus body helpers
  (`str`/`requireStr`/`intOr`/`boolOr`).
- `moduleEntityAudit(eventType, entityType, id, meta)` in
  `audit/mutation_audit_catalog.ts` — generic audit + domain-event spec so each
  module write emits an audit row without a bespoke catalog entry.

Server RBAC was **already a solid DB-backed system** (role/permission tables,
`requirePermission`, RLS). Batch 5 mostly *applied* it: every new write enforces
the module's already-defined `manage*` permission.

### Modules wired (each: server handler + manage* RBAC + app repo/datasource + live verify)

| Module | Writes | Permission | Storage |
|---|---|---|---|
| Library | add book, issue, return, add digital resource | `manageLibrary` | `library_entities` (+ snapshot append) |
| Transport | create/activate route, assign/transfer/remove allocation | `manageTransport` | `transport_entities` |
| Hostel | admit student, assign room, checkout, create room, log visitor | `manageHostel` | `hostel_entities` |
| HR | employee create/update/set-status, leave request, payroll run | `manageHr` | `hr_entities` (employee rows + snapshot arrays) |
| Alumni | add alumnus, create event, create campaign, add mentorship | `manageAlumni` | `alumni_entities` |
| Inventory | create PO, approve PO, receive goods | `manageInventory` | existing relational PO tables (`inventory_finance`) |
| Control Center | create school, create CRM lead | `manageControlCenter` (org scope) | `control_center_entities` (org-scoped) |
| Finance | create/update discount rule | `manageFinance` | **new** `finance_discount_rules` table |

Director (12 multi-school analytics endpoints, no server module) was **deferred to
Batch 6** (multi-school) by owner decision — it is greenfield analytics, not a
write-wiring task.

### Migrations applied to live DB
- `20260705000000_finance_discount_rules.sql` — new school-scope table (RLS +
  grants + `set_updated_at` trigger).
- `20260706000000_attendance_records_parent_privacy_rls.sql` — privacy fix below.

## Live verification (admin pilot phone `+919876543210`, schoolAdmin)
All writes returned `err:null` and persisted (re-read confirmed counts/state):
- Transport: create route (inactive) → activate (active) → assign → transfer →
  remove(DELETE).
- Hostel: create room → admit (awaitingAllocation) → assign room (resident) →
  checkout (checkedOut) → log visitor.
- HR: createEmployee → update → setStatus(PATCH inactive) → createLeave →
  processPayroll (run `pay_1` → processed).
- Alumni: add alumnus / event / campaign / mentorship.
- Library: add book (catalog +1, availableCopies bookkeeping) → issue (→2) →
  return (→3, fine computed) → add digital resource.
- Inventory: create PO (draft, real vendor) → approve (AP commitment) → receive
  (GRN generated).
- Finance: create discount (pending) → update PUT (approved).

### RBAC proven
- Parent token → **HTTP 403** on `POST /library/catalog`, `/transport/routes`,
  `/hr/employees`, `/finance/discounts` (manage* enforced).
- schoolAdmin (school scope) → **HTTP 403** on `POST /control-center/schools`
  (platform/org-scope write correctly rejects school scope).

### Attendance privacy fix verified (RLS, `erp_tenant` connection)
Before: `attendance_records_school` was `FOR ALL` with
`scope IN ('school','parent','student')` and no per-student filter → any
parent/student could read every student's attendance. After: school scope keeps
full read+write; parent/student get SELECT only, scoped to own children
(`student_guardians`) / own record. Verified: parent context sees **1** row
(own child) not 2; school scope still sees **2** (no staff regression).

## Known limitations / follow-ups
- **Inventory create-PO needs a vendor picker.** `vendor_id` is an FK to
  `inventory_vendors`; the app's `CreateInventoryProcurementOrderRequest` only
  carries a free-text `vendorName` (mapped to `vendorId`), which fails the FK.
  Approve/receive (which take `orderId`) work. The procurement form should let
  the user select a vendor and pass its id.
- **Control Center happy-path not live-tested.** `manageControlCenter` is
  org/platform scope; no org/platform-scope persona is seeded in staging, so
  only the RBAC *deny* was verified live. Seed a platform admin to exercise
  create-school / create-lead.
- **Deploy mechanics**: edge code is `scp`'d to `/opt/akshara/functions/_shared`
  + `docker compose restart akshara-edge` (no env change). Migrations applied
  manually as `supabase_admin`. OTP login has a 60s per-phone cooldown (Batch 2)
  — reuse one token across tests.
- Staging now contains Batch 5 QA test rows (a QA route/allocation already
  removed; QA room/student/visitor/employee/leave/alumni/PO/discount records).

See `LIVE_BACKEND_BATCH4_MONEY_LOOP.md` for the prior batch.
