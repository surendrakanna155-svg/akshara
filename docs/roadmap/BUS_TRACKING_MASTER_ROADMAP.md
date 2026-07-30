# BUS TRACKING — MASTER ROADMAP

**Status:** DRAFT — awaiting owner approval
**Owner:** Surendra
**Created:** 2026-07-29
**Source of truth:** Bus Tracking Module Technical & Product Audit (2026-07-29). The audit's findings are reproduced in full inside this document (task bodies + Appendix A). This roadmap supersedes the audit as the working artefact — the audit is now historical.
**Scope:** the complete School Bus Tracking / Transport module — backend, database, ERP admin, driver, parent, student.
**Module verdict at roadmap creation:** NOT PRODUCTION READY. Engineering 4.5/10 · Product 2/10 · UX 3/10 · Scalability 3/10 · Composite 4.1/10.

---

## 0. HOW TO USE THIS DOCUMENT

1. This is the **engineering checklist** until the Bus Tracking module reaches production quality. It is not a discussion document.
2. Tasks are ordered by **dependency**, grouped into phases. **A task may not start before every task in its `Deps` list is COMPLETE.**
3. A task is **COMPLETE only when it works end-to-end** across the full chain:

   > **Transport Admin → Driver → Backend → Parent → Student**

   If any link in that chain is missing, stubbed, mocked, or unverified, the task **remains open**. Partial completion is not completion. "Backend done, UI pending" is *Not Started* for the purposes of this roadmap.
4. Each task carries a `Done when` clause. That clause is the acceptance test. No task closes on code review alone.
5. **Status values:** `Not Started` · `In Progress` · `Blocked` · `Verified` (= closed). There is no "Done" — only `Verified`.
6. Every task references the audit section that produced it. Appendix B is a traceability matrix proving no audit finding was dropped.
7. The **EOS gate** (`CLAUDE.md`, `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md`) applies to every phase exit. A phase is not exited on a BLOCKED verdict.

### Priority definitions

| | Meaning |
|---|---|
| **P0** | Ships broken/dishonest today, or blocks all downstream work. Must be fixed before any school sees the module. |
| **P1** | Required for the module to be sellable and competitive. Table stakes in this market. |
| **P2** | Differentiator or polish. Deferred until P0+P1 are Verified. |

### Effort units

Engineer-days (`d`) for one competent full-stack engineer familiar with this codebase. Estimates exclude review, certification, and pilot time, which are budgeted separately in Phase 20.

---

## 1. ARCHITECTURAL PRINCIPLES (BINDING)

These constrain every task below. Violating one is grounds for rejecting an implementation regardless of whether it passes tests.

**P-1 · Never fabricate a fact about a child.**
No invented ETA, no simulated position, no placeholder number rendered as real data. When the system does not know, it says so. Applies with special force to any parent- or student-facing surface. *(Origin: audit §1.6 — hardcoded "8 minutes away".)*

**P-2 · Location source is pluggable.**
The system ingests positions through one interface. A driver phone and a hardware GPS device are interchangeable implementations behind it. No code above the ingest boundary may know which produced a fix. *(Additional requirement 3.)*

**P-3 · Everything operational is dated.**
Route↔vehicle, route↔driver, and route↔student links are **dated assignment rows**, never scalar fields on a route. "Today's bus is different" and "today's driver is different" are normal records, not exceptions. *(Additional requirements 1 & 3; audit §2 "Can routes change daily? — No".)*

**P-4 · The trip is the unit of operation.**
Nothing about a day's running attaches to the route. A trip owns its date, vehicle, driver, positions, boardings, and diversions. Route is the template; trip is the instance. *(Audit §7 "the missing concept".)*

**P-5 · Geography is first-class.**
Stops, geofences, and positions are PostGIS geography values, not floats bolted onto JSON. *(Audit §1.5, §7.)*

**P-6 · Referential integrity is enforced by the database.**
No entity is linked to another by a denormalized display string. Every relationship is a foreign key. *(Audit §7 — routes point at vehicles by registration text.)*

**P-7 · Mapping cost is fixed, not per-transaction.**
No billable map-vendor API may be called inside a per-ping, per-poll, or per-render loop. Geocoding happens once and is cached. ETA is computed in-house. *(Audit §4.)*

**P-8 · Parents see their own child and nothing else.**
Data minimisation is a schema and authorization property, designed in — never a client-side filter over a broader payload. *(Audit §1.9 — roster leakage.)*

**P-9 · Tracking is a consequence of the trip lifecycle, never a toggle.**
The driver never enables or disables GPS. Starting a trip starts tracking; ending it stops tracking. *(Additional requirement 2.)*

**P-10 · Preserve what already works.**
Multi-tenancy + forced RLS, the write-handler/permission middleware pattern, the mutation audit catalogue, row-locked read-modify-write discipline, the Finance boundary (Transport raises demands, Finance collects), and the dedicated `transportManager` role are **assets**. Carry them forward; do not rewrite them.

---

## 2. PHASE MAP & DEPENDENCY ORDER

```
PHASE 0   Stop the Bleeding  (honesty + live defects)          BUS-001 … BUS-009
   ↓
PHASE 1   Foundation  (contracts, permissions, harness)        BUS-010 … BUS-015
   ↓
PHASE 2   Database & Domain Model  (relational + PostGIS)      BUS-016 … BUS-032
   ↓
PHASE 3   Route Management                                     BUS-033 … BUS-042
   ↓
PHASE 4   Bus (Vehicle) Assignment                             BUS-043 … BUS-047
   ↓
PHASE 5   Driver Assignment & Substitution                     BUS-048 … BUS-054
   ↓
PHASE 6   Student Allocation & Roster Integrity                BUS-055 … BUS-061
   ↓
PHASE 7   Driver Identity & Driver App                         BUS-062 … BUS-068
   ↓
PHASE 8   Trip Lifecycle                                       BUS-069 … BUS-075
   ↓
PHASE 9   GPS Tracking (ingest + sources)                      BUS-076 … BUS-085
   ↓
PHASE 10  Live Map                                             BUS-086 … BUS-089
   ↓
PHASE 11  ETA Engine                                           BUS-090 … BUS-094
   ↓
PHASE 12  Parent Tracking                                      BUS-095 … BUS-100
   ↓
PHASE 13  Student Experience                                   BUS-101
   ↓
PHASE 14  Boarding & Transport Attendance                      BUS-102 … BUS-106
   ↓
PHASE 15  Notifications                                        BUS-107 … BUS-112
   ↓
PHASE 16  Safety & SOS                                         BUS-113 … BUS-118
   ↓
PHASE 17  Admin Experience & Onboarding                        BUS-119 … BUS-122
   ↓
PHASE 18  Reporting & Analytics                                BUS-123 … BUS-125
   ↓
PHASE 19  Scale & Performance                                  BUS-126 … BUS-129
   ↓
PHASE 20  Production Validation & Certification                BUS-130 … BUS-135
```

**Hard gates (no exceptions):**

- Nothing in Phase 3+ may be built on `transport_entities`. Phase 2 must land first.
- No GPS work (Phase 9) before the Driver App (Phase 7) and Trip Lifecycle (Phase 8) exist. There is no GPS source without them.
- No Live Map (Phase 10) before positions exist (Phase 9).
- No ETA (Phase 11) before stop coordinates (BUS-037) **and** live positions (Phase 9) exist.
- No Parent Tracking (Phase 12) before ETA (Phase 11) — parents must never be shown a number the system cannot compute (**P-1**).
- No Notifications (Phase 15) before route-cohort targeting (BUS-107) exists.

---

# PHASE 0 — STOP THE BLEEDING

**Goal:** the module tells the truth and stops losing data. No new capability. Ships independently of everything else.
**Exit criteria:** zero fabricated values on any user-facing surface; zero silent data loss; no notification reaches a parent it does not concern.

---

### BUS-001 — Remove the fabricated parent ETA
**P0** · **0.5 d** · **Verified** · **Deps:** none · **Audit:** §1.6, §8 Critical #1

- **Description:** Delete the hardcoded "approximately 8 minutes away" string from the parent transport screen and the non-functional "Refresh ETA" affordance.
- **Why it matters:** This is the single worst defect in the module. Every parent, for every child, every day, is shown the same invented number about their child's school bus. A parent who trusts it and waits is taught that the product lies — and in school transport, parent trust is the product. Violates **P-1**.
- **Current implementation:** `lib/features/parent/transport/parent_transport_screen.dart:74-81` renders a compile-time constant `AksharaInsightCard` reading *"Bus is approximately 8 minutes away (telemetry preview). Live map integration is not enabled in this build."* `actionLabel: 'Refresh ETA'` is passed with `onAction: null`, so the button never renders — the parent is promised freshness with no mechanism.
- **Target implementation:** Card removed entirely. Screen shows only facts the system holds: route name, bus number, pickup stop, drop stop. A single honest line states that live tracking is not yet enabled for this school. No number, no time, no progress indicator.
- **Done when:** Parent app on a live build shows zero time-based claims. Widget test asserts the string "minutes away" appears nowhere in the parent transport tree. Verified by a real parent login against the live backend.

---

### BUS-002 — Fix delay-notification targeting
**P0** · **1 d** · **Verified** · **Deps:** none · **Audit:** §1.12, §8 Critical #6

- **Description:** Route-delay broadcasts must reach only the parents of students allocated to that route, not every parent in the school.
- **Why it matters:** A 10-minute delay on Route 8 currently pushes to every parent in the school — including parents of walkers and car-drop children — while the API response and the audit log both claim it went to the 38 affected families. Alert fatigue sets in within a week; parents mute the app, which also mutes fee reminders and exam notices. The module's one working notification path is actively degrading the whole notification channel, and the audit trail is inaccurate.
- **Current implementation:** `supabase/functions/_shared/transport/transport_write_handlers.ts:389-431` carefully filters allocations to the route, counts them into `recipientCount`, audits that count — then calls `sendBroadcastMessage` with `audience: "parents"`. The filtered cohort is computed and discarded.
- **Target implementation:** Interim (pre-Phase 15): resolve the affected student set, map to guardian recipients, and dispatch a targeted broadcast. `recipientCount` in the response and in the audit event must equal the number of recipients actually enqueued. If targeted dispatch is not yet supported by the communication pipeline, the endpoint must **fail closed** with a clear error rather than silently broadcasting school-wide.
- **Done when:** Integration test proves a delay on Route A enqueues deliveries only for Route A guardians and zero for a Route B-only parent. Audit event count matches enqueued count exactly.

---

### BUS-003 — Gate the parent transport screen behind honest state
**P0** · **0.5 d** · **Verified** · **Deps:** BUS-001 · **Audit:** §1.9, §8 Critical #3

- **Description:** Until Phase 12 delivers a correct parent path, the parent transport screen must not attempt a request it cannot be authorized for, and must not render an error screen to a parent as if the app were broken.
- **Why it matters:** In the live build (`config/live_release.json` sets `TRANSPORT_API_ENABLED: true`) the parent screen calls `GET /transport/allocations`, which requires the `viewTransport` permission and `scope === 'school'`. The `parent` role holds neither; parent tokens carry `scope: "parent"`; the RLS policy on `transport_entities` itself requires school scope. The parent receives a **403** and sees a generic failure. The feature has never worked outside mock mode.
- **Current implementation:** `lib/features/parent/transport/parent_transport_provider.dart` calls `getAllocations()` unconditionally; `lib/core/security/role_permissions.dart:654-661` grants the parent role six permissions, none transport-related.
- **Target implementation:** Client detects that transport is not yet enabled for parents and renders a deliberate, designed empty state ("Bus details will appear here once your school enables transport in the app"), issuing no request. Removed entirely once BUS-095/BUS-096 land.
- **Done when:** A real parent login on the live build produces zero 403s in the transport path and zero error screens. Network trace confirms no `/transport/*` call is made from a parent session.

---

### BUS-004 — Replace seeded dashboard KPIs with computed or explicit not-configured values
**P0** · **2 d** · **Verified** · **Deps:** none · **Audit:** §7, §8 Critical #9

- **Description:** The transport dashboard must compute its KPIs from live data or state plainly that it cannot.
- **Why it matters:** The dashboard currently presents fiction as fact to a principal. Demo/pilot schools see permanently frozen figures ("18 Active Buses", "94% On-Time", "842 Students Picked") regardless of reality; a genuinely onboarded school receives an empty snapshot and sees permanent zeros with no explanation. Both are misinformation on the screen most likely to be shown in a sales demo.
- **Current implementation:** `snapshot_dashboard`, `snapshot_tracking`, `snapshot_occupancy`, `snapshot_reports` are static JSONB documents seeded once by `supabase/migrations/20260614100000_transport_hr_read_apis.sql:75-173`. No code path anywhere recomputes them — grep for `mutateSnapshot` in the transport module returns zero write-side hits. `handleSnapshot` returns `{}` when the row is absent, which the null-tolerant mapper renders as all-zeros.
- **Target implementation:** KPIs derived on read from actual counts (vehicles, active routes, allocated students, unallocated students). Any KPI that has no data source yet renders as "—" with a "not configured" affordance, never as a number. Fuel KPI handled by BUS-005.
- **Done when:** A freshly-onboarded school with 3 buses and 120 allocations sees 3 and 120 on the dashboard. A school with nothing configured sees "—" and a setup prompt, not zeros. No dashboard value originates from a migration seed.

---

### BUS-005 — Remove the placeholder fuel-cost KPI
**P0** · **0.25 d** · **Verified** · **Deps:** none · **Audit:** §7

- **Description:** Delete the "Fuel Cost (MTD) ₹84K" KPI until a real fuel data source exists (BUS-121).
- **Why it matters:** The seed data labels this value `"detail": "Finance integration placeholder"` in the source, and the UI renders it as a live financial figure on a principal's dashboard. A fabricated money number is the fastest way to lose a finance stakeholder's confidence in the entire product.
- **Current implementation:** `supabase/migrations/20260614100000_transport_hr_read_apis.sql:89` — seeded KPI with an explicit placeholder annotation, rendered by `transport_kpi_row.dart` identically to real KPIs.
- **Target implementation:** KPI removed from the dashboard. Reintroduced only by BUS-121 when fuel logs exist.
- **Done when:** No monetary value appears on the transport dashboard that is not traceable to a Finance record.

---

### BUS-006 — Fix the stop-time client/server contract break
**P0** · **1 d** · **Verified** · **Deps:** none · **Audit:** §2, §8 Critical #8

- **Description:** Backend and client disagree on the stop pickup-time field name, so the value silently never displays.
- **Why it matters:** A transport admin types a pickup time, sees a success toast, and the value renders blank on reload. They will re-enter it, conclude the product is broken, and lose confidence in every other save in the module. This is a live user-visible data-loss bug shipping today.
- **Current implementation:** `transport_write_handlers.ts:790` writes `{ id, name, pickupTime, dropTime }`. `lib/core/repositories/api/transport/mapper/transport_mapper.dart:330` reads `item['scheduledTime']`, defaulting to `''`. `TransportStop.scheduledTime` is consequently always empty for any stop created through the product.
- **Target implementation:** One canonical field name defined in the transport contract doc (BUS-010), used identically on both sides, with a contract test that fails if they diverge. Interim fix here; superseded by structured TIME columns in BUS-038.
- **Done when:** A stop created via the UI with pickup time "7:05 AM" displays "7:05 AM" after a full app restart. A contract test asserts the round-trip.

---

### BUS-007 — Fix stop-edit drop-time erasure
**P0** · **0.5 d** · **Verified** · **Deps:** BUS-006 · **Audit:** §2, §8 Critical #8

- **Description:** Editing a stop's name silently wipes its drop time. Also dispose the leaked text controllers.
- **Why it matters:** Silent destruction of previously-entered data on an unrelated edit. The admin has no signal that anything was lost, and no way to recover it. This is the most corrosive class of bug for user trust because it is invisible until someone notices the afternoon schedule is empty.
- **Current implementation:** `lib/features/transport/routes/transport_stop_editor.dart:280` initialises the drop-time controller as `TextEditingController()` — empty — even in edit mode where a value exists, then unconditionally submits it. `TransportStop` carries no `dropTime` field to prefill from, compounding the loss. Controllers at lines 278-280 are never disposed.
- **Target implementation:** Edit dialog prefills every field from the persisted stop, including drop time. Model carries both pickup and drop time. Omitted fields are not overwritten server-side. Controllers disposed via a `StatefulWidget`.
- **Done when:** Editing only a stop's name leaves pickup and drop times byte-identical in the database. Regression test covers it.

---

### BUS-008 — Remove silent mock write-fallback from release builds
**P0** · **1 d** · **Verified** · **Deps:** none · **Audit:** §7

- **Description:** Production writes must never silently execute a mock implementation and report success.
- **Why it matters:** `HybridTransportRepository` wraps every write in `withMockWriteFallback`. On `ApiNotConnectedException` it runs the **mock** and returns a success object; the UI shows "Stops updated" and the admin believes the data persisted. The catch is narrow, so blast radius is limited — but a data layer that can substitute fake writes for real ones is precisely how a module reaches the state this audit found: green tests, confident screens, and paths never exercised end-to-end. It also makes every future verification untrustworthy.
- **Current implementation:** `lib/core/repositories/api/hybrid_write_fallback.dart`; applied to all 19 write methods in `lib/core/repositories/api/transport/hybrid_transport_repository.dart`.
- **Target implementation:** Fallback compiled out of release builds. In release, an unreachable API surfaces a real error to the user. Mock repositories remain available for tests and local development only.
- **Done when:** A release build with the backend unreachable shows a failure on write and persists nothing. No release code path can reach `MockTransportRepository`.

---

### BUS-009 — Remove transport demo fixtures from production seeding
**P0** · **1 d** · **Verified** · **Deps:** BUS-004 · **Audit:** §1.2, §7

- **Description:** Demo routes, vehicles, drivers, allocations, and the tracking snapshot must not be seeded into production tenants.
- **Why it matters:** A migration inserts a fictional fleet ("BUS-07 / Ramesh Kumar / Route 12 — North") including two buses at fixed Hitech City coordinates and a snapshot whose own text reads *"GPS architecture placeholder"*. If a real tenant inherits these rows, the school sees phantom buses and phantom children. Fixtures belong in test and demo tenants only.
- **Current implementation:** `supabase/migrations/20260614100000_transport_hr_read_apis.sql:75-252` seeds School A and a School B probe fixture directly in a schema migration.
- **Target implementation:** Fixture data moved out of schema migrations into an explicitly-invoked demo-seed script targeting demo/test tenants only. Tenant-isolation probe fixtures retained but clearly namespaced and excluded from production.
- **Done when:** A newly provisioned production tenant contains zero transport rows. Isolation probes still pass.

---

**PHASE 0 EXIT GATE:** No user-facing surface in the transport module displays a value the system did not compute. No write silently discards data. No notification reaches an unaffected parent. EOS gate run against Phase 0 scope.

---

# PHASE 1 — FOUNDATION

**Goal:** decide and document the contracts, permission model, privacy model, and verification harness *before* any schema is written. Cheap now, extremely expensive later.
**Exit criteria:** an engineer can implement any Phase 2+ task without inventing a contract.

---

### BUS-010 — Transport domain contract document (SSOT)
**P0** · **3 d** · **Verified** · **Deps:** Phase 0 · **Audit:** §2, §7

- **Description:** Author the single canonical specification for the transport domain: entity definitions, field names, types, enumerations, state machines, API surface, and error taxonomy. All subsequent tasks implement against this document.
- **Why it matters:** Every integration defect found in the audit traces to the absence of one — `pickupTime` vs `scheduledTime` (BUS-006), stops carrying coordinates in seed data but not in the write path (BUS-037), `assignedBus` read by three subsystems and written by none (BUS-043). These are not coding mistakes; they are the predictable result of handler-by-handler development with no contract.
- **Current implementation:** None. Field names are established ad hoc per handler, with `str(body, "camelCase", "snake_case", "alias")` multi-key tolerance masking divergence rather than preventing it.
- **Target implementation:** `docs/engineering/TRANSPORT_DOMAIN_CONTRACT.md` covering: entity model and ERD; canonical field names and types; trip and assignment state machines; the full REST surface with request/response schemas; error codes; the location-ingest contract (BUS-011); and the visibility matrix (BUS-012). Generated contract tests enforce client/server agreement.
- **Done when:** Document reviewed and frozen. A contract test suite derived from it fails on any client/server field divergence.

---

### BUS-011 — Location-source abstraction specification
**P0** · **2 d** · **Verified** · **Deps:** BUS-010 · **Audit:** §3, §4; Additional requirement 3

- **Description:** Define the single ingest contract through which all position fixes enter the system, such that a driver phone and a third-party hardware GPS device are interchangeable implementations.
- **Why it matters:** **P-2.** Schools split into two camps: those who will run a driver app for free, and those who want tamper-proof hardware and will pay for it. Committing to one now forces a rewrite later. Defining the boundary first means adding a hardware vendor becomes an adapter, not a redesign. This is explicitly listed in the additional requirements as something that must not require re-architecture.
- **Current implementation:** None — no ingest path of any kind exists.
- **Target implementation:** A specified `LocationFix` envelope (trip reference, timestamp, coordinate, accuracy, speed, heading, source type, source id, integrity signals) and a batched ingest contract. Two documented implementations: `driver_app` and `hardware_device`. Nothing above the ingest boundary may branch on source type except integrity scoring and the admin device registry.
- **Done when:** Specification approved. A written walkthrough demonstrates adding a hypothetical hardware vendor touching only adapter + registry code.

---

### BUS-012 — Transport privacy & visibility model
**P0** · **2 d** · **Verified** · **Deps:** BUS-010 · **Audit:** §1.9, §3, §8 Critical #3

- **Description:** Define exactly which actor may see which transport datum, under which conditions, and for how long — before any parent-facing endpoint is built.
- **Why it matters:** **P-8.** The audit found the parent path would have exposed other children's names, admission numbers, class, bus number, and **pickup stop location** to any parent who opened the screen. Publishing where other people's children stand each morning is a child-safety failure, not merely a privacy one. It happened because visibility was treated as a client-side filter over a broad payload rather than a designed property. This must be settled on paper first.
- **Current implementation:** Transport reads require school scope, so parents are simply locked out; the client compensates by fetching the school-wide list and filtering locally. The design has no parent model at all.
- **Target implementation:** A written visibility matrix: actor × datum × condition × retention. Minimum rules — a parent sees only their own child's allocation, only their own child's trip, only during that trip's active window, and never another child's identity or stop; a driver sees only today's assigned trip and its manifest; a student sees a subset of their own; position history retention is bounded and stated. Enforced at the database/authorization layer, never in the client.
- **Done when:** Matrix approved and referenced by every endpoint spec in BUS-010. Adopted as the acceptance basis for BUS-100 and BUS-131.

---

### BUS-013 — Transport permission & role model rework
**P0** · **2 d** · **Verified** · **Deps:** BUS-012 · **Audit:** §1.8, §1.9, §2, §13

- **Description:** Extend the role/permission model to cover the driver, the attendant, the parent transport view, and the student transport view.
- **Why it matters:** There is no driver role, so drivers cannot log in, so there is no GPS source — this single gap is the root cause of the entire tracking absence. Parents lack any transport permission. The `student` role currently holds an **empty permission set** (`role_permissions.dart:662`), so no student-facing transport surface is even reachable. Every downstream phase depends on this.
- **Current implementation:** `UserRole` = `{parent, teacher, student, staff}` (`lib/features/auth/auth_models.dart:7-11`). `manageTransport` held by `superAdmin`, `schoolAdmin`, `transportManager`; `viewTransport` additionally by `principal` (read-only). `AuthScope` includes `parent` and `student` but transport handlers demand `school`.
- **Target implementation:** New `driver` role and scope with a minimal permission set (own trips only). New `attendant` role (BUS-053). Parent gains a narrow transport-view permission scoped to their own children. Student gains a read-only self view. `transportManager` and the principal read-only split are **preserved** — they are correct.
- **Done when:** RBAC route inventory updated; every transport endpoint has an explicit allow-list; negative tests prove a driver cannot read another driver's trip, a parent cannot read another child's allocation, and a student cannot read any manifest.

---

### BUS-014 — End-to-end verification harness
**P0** · **4 d** · **Verified** · **Deps:** BUS-013 · **Audit:** §2 (root cause), §7

- **Description:** Build a test harness that exercises the full chain — Transport Admin → Driver → Backend → Parent → Student — as a single scenario against a real database.
- **Why it matters:** This is the roadmap's completion rule made executable. The audit's defining finding is that individually well-engineered handlers were never connected: the race-safe capacity guard is correct code that has never once executed, because no endpoint writes the field it reads. Unit tests stubbed the field. Only a chain test catches this class of defect, and without a harness the rule in §0.3 is unenforceable.
- **Current implementation:** Good unit and contract coverage (~2,450 lines of transport tests) with no cross-actor scenario test.
- **Target implementation:** A scenario harness that provisions a tenant, drives admin setup, driver login and trip, backend ingest, and parent/student reads in one run, asserting state at each hop. Every subsequent task's `Done when` is expressed as a scenario in this harness.
- **Done when:** Harness runs green in CI against a real Postgres, and a deliberately-introduced break at any hop fails it.

---

### BUS-015 — Transport v2 feature-flag & rollout plan
**P1** · **1 d** · **Verified** · **Deps:** BUS-010 · **Audit:** §7

- **Description:** Define the flag topology and migration path allowing v2 transport to be developed and piloted alongside the existing module without destabilising live pilot schools.
- **Why it matters:** Phase 2 replaces the storage substrate. Doing that in place on a live pilot without a flag and a rollback is reckless. Also prevents a repeat of `TRANSPORT_API_ENABLED` being flipped on in `config/live_release.json` while the parent path underneath it was never verified.
- **Current implementation:** Single coarse `TRANSPORT_API_ENABLED` dart-define, default false, true in live release.
- **Target implementation:** Per-capability flags (relational store, driver app, live tracking, parent tracking) with a documented enablement order, per-school rollout, and rollback procedure. Flag state visible in admin diagnostics.
- **Done when:** Plan approved; flags implemented; a school can be moved forward and back one capability at a time without data loss.

---

**PHASE 1 EXIT GATE:** Contract, ingest boundary, visibility matrix, permission model, harness, and rollout plan all approved and frozen. No Phase 2 work begins before this gate.

---

# PHASE 2 — DATABASE & DOMAIN MODEL

**Goal:** replace the JSONB entity store with a relational, geospatial, time-aware schema. This is the largest single body of work and everything downstream depends on it.
**Exit criteria:** transport reads and writes run entirely on typed tables with foreign keys; `transport_entities` no longer serves any transport type.

> **Root finding driving this phase (audit §7):** transport was modelled as documents when it is fundamentally relational, geospatial, and time-series. Every scalability, integrity, and correctness defect in the audit descends from that one decision.

---

### BUS-016 — Enable PostGIS
**P0** · **1 d** · **Verified** · **Deps:** Phase 1 · **Audit:** §1.5, §7

- **Description:** Enable the PostGIS extension and establish conventions for geography types, SRID, and spatial indexing.
- **Why it matters:** **P-5.** Nearest-stop resolution, geofence entry/exit, distance-to-stop, and route corridor checks are all impossible without it. Adding PostGIS after live geographic data exists means migrating it — do it before the first coordinate is stored.
- **Current implementation:** No PostGIS. Zero geography or geometry columns across all migrations. Coordinates exist only as JSON floats in seed fixtures, defaulted to `0` by the client mapper.
- **Target implementation:** `postgis` enabled; convention fixed at `GEOGRAPHY(POINT, 4326)`; GiST index standard defined; helper functions for distance and containment agreed.
- **Done when:** Extension live in all environments; a spatial query returns correct results in an integration test; deployment runbook updated.

---

### BUS-017 — `transport_vehicle` table
**P0** · **1.5 d** · **Verified** · **Deps:** BUS-016 · **Audit:** §2, §7

- **Description:** Relational vehicle entity with a stable surrogate key and typed compliance-document dates.
- **Why it matters:** Vehicles are currently referenced by **registration string**, so `PUT /transport/vehicles/{id}` changing a registration silently breaks the route↔vehicle link with no error and no cascade (audit §7). A stable id makes the link unbreakable (**P-6**).
- **Current implementation:** JSONB rows with `entity_type = 'vehicle'`; uniqueness enforced by loading all vehicles into application memory and comparing normalised strings (`transport_write_handlers.ts:445-452`).
- **Target implementation:** `transport_vehicle(id PK, org, school, registration UNIQUE per school, model, capacity, status, insurance_expiry DATE, fitness_expiry DATE, puc_expiry DATE, permit_expiry DATE, road_tax_expiry DATE, timestamps)`. **Preserve** the strict ISO date validation and the per-school uniqueness rule — both are correct today.
- **Done when:** Table live with constraints; uniqueness enforced by the database, not by application scan; existing pilot vehicles migrated (BUS-030).

---

### BUS-018 — `transport_driver` table + identity link + safety records
**P0** · **2 d** · **Verified** · **Deps:** BUS-016, BUS-013 · **Audit:** §1.8, §6, §8 nice-to-haves

- **Description:** Relational driver entity linked to an auth identity, extended with the safety and compliance fields an Indian school transport operation requires.
- **Why it matters:** The driver is currently an inert data record — name, licence, phone, status — with no login, no photo, no address, no police verification, and no medical/eyesight record. Schools are accountable for who is driving their children; competitors capture this. The auth link is the prerequisite for the entire driver app.
- **Current implementation:** JSONB `entity_type = 'driver'`; licence uniqueness by in-memory scan; no identity linkage; no safety fields.
- **Target implementation:** `transport_driver(id PK, org, school, user_id FK → auth, name, phone, licence_number UNIQUE per school, licence_expiry DATE, licence_class, photo_ref, address, police_verification_status, police_verification_expiry, medical_check_date, eyesight_check_date, blood_group, emergency_contact, status, timestamps)`. **Preserve** strict ISO expiry validation.
- **Done when:** Table live; a driver record can be linked to a login; compliance fields feed BUS-054 and BUS-125.

---

### BUS-019 — `transport_stop` table with geography
**P0** · **2 d** · **Verified** · **Deps:** BUS-016 · **Audit:** §1.5, §2, §8 Critical #4

- **Description:** Promote the stop to a first-class entity carrying a real location and a geofence radius.
- **Why it matters:** **The single most consequential task in the roadmap.** Stops today are objects inside a route's JSON array with no coordinates — the write path accepts only `{id, name, pickupTime, dropTime}`, and every stop a real school creates sits at 0°N 0°E, in the Atlantic Ocean off Ghana. Without stop coordinates, live tracking, geofencing, ETA, route rendering, and arrival detection are all permanently unreachable regardless of what else is built.
- **Current implementation:** `transport_write_handlers.ts:778-793` writes name and two free-text time strings. The stop editor UI collects three text fields. The Dart model has `latitude`/`longitude`, but the mapper defaults them to `0` and nothing writes them.
- **Target implementation:** `transport_stop(id PK, org, school, name, location GEOGRAPHY(POINT,4326) NOT NULL, geofence_radius_m, address_text, landmark, status, timestamps)` with a GiST index. Stops belong to the school, not to a route, so one physical stop is shared across morning and afternoon routes (**P-3**, BUS-040).
- **Done when:** A stop cannot be created without a valid coordinate inside a plausible bounding box for the school. Spatial index verified in query plans.

---

### BUS-020 — `transport_route` table
**P0** · **1 d** · **Verified** · **Deps:** BUS-016 · **Audit:** §2, §7

- **Description:** Route as a template entity — identity, direction, shift, status, schedule metadata. It holds no vehicle, no driver, and no operational state.
- **Why it matters:** **P-3/P-4.** Today a route carries `assignedBus` as a scalar string, which is precisely what makes daily substitution unrepresentable. Assignments move to dated rows (BUS-022); the route becomes a stable template.
- **Current implementation:** JSONB `entity_type = 'route'` with embedded `assignedBus`, `stops[]`, `stopCount`, `studentCount`, and free-text departure times.
- **Target implementation:** `transport_route(id PK, org, school, name, code, direction, shift, status, default_departure_time TIME, default_return_time TIME, distance_m, timestamps)`. Derived counts computed on read, never stored.
- **Done when:** Table live; route carries no operational or denormalized fields.

---

### BUS-021 — `transport_route_stop` table
**P0** · **1.5 d** · **Verified** · **Deps:** BUS-019, BUS-020 · **Audit:** §2, §8 Critical #8

- **Description:** The ordered, timed junction between a route and its stops, with times as real `TIME` values.
- **Why it matters:** Stop times are free-text strings today (`"7:05 AM"`, hint `"e.g. 7:05 AM"`, zero validation). `"7.05"`, `"0705"`, and `"morning"` all persist. You cannot sort, diff, or subtract them — which makes schedule adherence, delay detection, and any ETA baseline permanently impossible without a migration. Fixing the type here removes that ceiling.
- **Current implementation:** Stops embedded in the route's JSON array with string times; sequence maintained by a row-locked resequence (which is well-implemented and should be carried forward).
- **Target implementation:** `transport_route_stop(route_id FK, stop_id FK, sequence, scheduled_pickup_time TIME, scheduled_drop_time TIME, dwell_seconds, PK(route_id, stop_id), UNIQUE(route_id, sequence) DEFERRABLE)`. **Preserve** the contiguous 1..N resequencing and permutation validation from the current implementation.
- **Done when:** Times are queryable and arithmetic-capable; sequence integrity enforced by constraint; reorder remains race-safe under concurrent edits.

---

### BUS-022 — `transport_assignment` table (dated route ↔ vehicle ↔ driver)
**P0** · **2.5 d** · **Verified** · **Deps:** BUS-017, BUS-018, BUS-020 · **Audit:** §2, §7; Additional requirements 1 & 3

- **Description:** Dated assignment rows binding a route to a vehicle and a driver over an effective period, supporting permanent assignments and single-day overrides simultaneously.
- **Why it matters:** **P-3, and the structural enabler for the owner's substitute-driver requirement.** Today `assignedBus` is a scalar that is never written and `assignedDriverId` is read but never written — so there is neither a permanent nor a temporary assignment. Modelling assignment as a dated row makes "Bus 7 is in the workshop today, Bus 12 covers" and "Ramesh is on leave, Suresh drives today" ordinary records rather than unrepresentable states — with no schema change when those needs arrive.
- **Current implementation:** Nothing. Two dead fields.
- **Target implementation:** `transport_assignment(id PK, org, school, route_id FK, vehicle_id FK, driver_id FK, attendant_id FK NULL, effective_from DATE, effective_to DATE NULL, assignment_kind ENUM('permanent','substitute'), reason, created_by, timestamps)` with an exclusion constraint preventing overlapping permanent assignments per route and a documented precedence rule (substitute wins for its date range). Powers BUS-043, BUS-046, BUS-048, BUS-051.
- **Done when:** A permanent assignment and a one-day substitute can coexist; resolving "who drives Route 12 today" returns the substitute and tomorrow returns the permanent driver.

---

### BUS-023 — `transport_allocation` table
**P0** · **2 d** · **Verified** · **Deps:** BUS-019, BUS-020 · **Audit:** §2, §7, §8 Critical #3

- **Description:** Student↔route↔stop allocation on real foreign keys, with shift semantics.
- **Why it matters:** Allocations today are JSON rows keyed by strings, carrying **frozen copies** of `routeName` and `busNumber` captured at assignment time, with pickup and drop stops entered as **free text** that the roster then groups by exact string match. `"Green Park Gate"`, `"Green park gate"`, and `"Green Park gate "` become three different stops. Referential integrity between a child and their stop is currently maintained by the admin's typing accuracy.
- **Current implementation:** JSONB `entity_type = 'allocation'`; id `routeId:sisStudentId` in bulk mode; denormalized name copies; string stop references.
- **Target implementation:** `transport_allocation(id PK, org, school, student_id FK, route_id FK, pickup_stop_id FK, drop_stop_id FK, shift ENUM('am','pm','both'), effective_from, effective_to NULL, status, timestamps)` with a partial unique constraint enforcing at most one active allocation per student per shift (BUS-056). No denormalized display strings. **Preserve** the SIS transport-enrolled linkage behaviour, keyed on `student_id`.
- **Done when:** Allocation carries zero display-string copies; stop references are FKs; a student cannot hold two conflicting active allocations for the same shift.

---

### BUS-024 — `transport_trip` table
**P0** · **2.5 d** · **Verified** · **Deps:** BUS-022 · **Audit:** §2, §7; Additional requirement 2

- **Description:** The daily instance of a route — the missing concept that makes history, substitution, and per-day attendance representable.
- **Why it matters:** **P-4.** The audit's core structural finding: there is no trip. Consequently the system cannot express "today", cannot store yesterday, and cannot attach positions, boardings, or a substitute driver to a specific day's running. Transport attendance has no date because there is no trip to hang it on. Every additional requirement from the owner — substitute driver, trip lifecycle, temporary vehicle replacement, emergency diversion — is a property of a trip.
- **Current implementation:** Does not exist in any form.
- **Target implementation:** `transport_trip(id PK, org, school, route_id FK, service_date DATE, shift, vehicle_id FK, driver_id FK, attendant_id FK NULL, assignment_id FK, status ENUM('scheduled','started','completed','cancelled','aborted'), started_at, ended_at, start_location, end_location, distance_m, diversion_id NULL, timestamps)` with `UNIQUE(route_id, service_date, shift)`. Immutable once completed (BUS-073).
- **Done when:** A trip exists for every scheduled route-day; positions, boardings and incidents reference it; completed trips are immutable.

---

### BUS-025 — `transport_position` table (partitioned)
**P0** · **2.5 d** · **Verified** · **Deps:** BUS-024 · **Audit:** §1.2, §3, §7

- **Description:** Time-series storage of position fixes, partitioned by date, with a bounded hot retention.
- **Why it matters:** At 1,000 buses this table receives roughly **2.16 million rows per day** (6 fixes/min × 6 h). A JSONB entity table with no partitioning, no time dimension, and no attribute index is the wrong substrate by an order of magnitude. Getting partitioning and retention right at creation avoids a painful migration under load.
- **Current implementation:** No position storage of any kind.
- **Target implementation:** `transport_position(trip_id FK, recorded_at TIMESTAMPTZ, location GEOGRAPHY(POINT,4326), accuracy_m, speed_mps, heading_deg, source_type, source_id, integrity_flags, received_at)` — range-partitioned by `recorded_at`, GiST + btree indexed, with automated partition creation and a defined retention/archival policy (BUS-084). Out-of-order backfill accepted (BUS-080).
- **Done when:** Partition automation verified; a synthetic 1,000-bus day ingests and queries within budget (BUS-126).

---

### BUS-026 — `transport_boarding` table
**P0** · **1.5 d** · **Verified** · **Deps:** BUS-024, BUS-023 · **Audit:** §1.7, §1.10, §8 Critical #5

- **Description:** Per-trip, per-student boarding and alighting events with a real student foreign key.
- **Why it matters:** Transport attendance today stores `studentName` as a **display string with no student id and no date**, and re-recording replaces the row in place. It therefore cannot be attributed to a child, cannot be joined to SIS, breaks entirely for two children with the same name, and physically cannot store history. "Was my son on the bus last Tuesday?" — the exact question a school faces when something goes wrong — is unanswerable.
- **Current implementation:** JSONB `entity_type = 'attendance'` with `{studentName, stopName, routeName, scheduledTime, actualTime, status, parentNotified, shift}`. No id, no date.
- **Target implementation:** `transport_boarding(id PK, trip_id FK, student_id FK, stop_id FK, event ENUM('boarded','alighted','absent','no_show'), recorded_at, recorded_by, source ENUM('driver','attendant','geofence','admin'), location, notes)` with `UNIQUE(trip_id, student_id, event)`. Full history preserved.
- **Done when:** A boarding event is attributable to a specific child on a specific date and trip; historical queries return correct results across dates.

---

### BUS-027 — `transport_incident` table
**P1** · **1.5 d** · **Verified** · **Deps:** BUS-024 · **Audit:** §1.12, §8 nice-to-haves

- **Description:** Unified record for SOS activations, geofence anomalies, speed violations, breakdowns, and diversions.
- **Why it matters:** Safety events must be first-class, timestamped, and auditable — not log lines. Required by Phase 16 and by any serious safety conversation with a school.
- **Current implementation:** None. Grep for `sos|panic|emergency` across the transport module returns zero.
- **Target implementation:** `transport_incident(id PK, org, school, trip_id FK NULL, vehicle_id FK NULL, driver_id FK NULL, kind, severity, location, occurred_at, reported_by, acknowledged_by, acknowledged_at, resolution, timestamps)`.
- **Done when:** Table live; consumed by BUS-113 through BUS-118.

---

### BUS-028 — RLS, tenant policies & grants for all transport tables
**P0** · **2 d** · **Verified** · **Deps:** BUS-017 … BUS-027 · **Audit:** §7 (strength to preserve), §1.9

- **Description:** Apply the project's forced-RLS tenant pattern to every new table, extended to cover the driver and parent scopes.
- **Why it matters:** Multi-tenancy is the one part of the current module the audit rated genuinely solid — composite keys, `FORCE ROW LEVEL SECURITY`, matching `USING`/`WITH CHECK`, per-connection tenant context, dedicated isolation probes. That standard must carry to every new table without regression. The extension to driver and parent scopes is where the new risk lies: the existing school-only policy is exactly what makes the parent path 403 today.
- **Current implementation:** `transport_entities` policy requires `app_current_scope() = 'school'` — correct for staff, fatal for parents and drivers.
- **Target implementation:** Per-table policies implementing the BUS-012 visibility matrix: staff by school; driver limited to trips assigned to them; parent limited to their own children's allocations and active trips. Isolation probes extended to every new table.
- **Done when:** Negative tests prove cross-tenant, cross-school, cross-driver and cross-child reads are all rejected **at the database layer**, not the application layer.

---

### BUS-029 — Indexes, constraints & query-plan validation
**P0** · **2 d** · **Verified** · **Deps:** BUS-028 · **Audit:** §7

- **Description:** Systematic index and constraint design across the new schema, validated against real query plans.
- **Why it matters:** The current store cannot be queried by attribute at all — "which allocation belongs to student X?" requires loading every allocation into memory. That single limitation is the direct cause of the parent page-1-of-20 bug. Indexing must be designed, not discovered under load.
- **Current implementation:** One index on `(organization_id, school_id, entity_type)`. No index on any payload field.
- **Target implementation:** Documented index set covering every access path in BUS-010, with `EXPLAIN` evidence for each. Check constraints on enums, ranges, and coordinate bounds.
- **Done when:** Every documented access path has a plan without a sequential scan on a large table, evidenced in the task record.

---

### BUS-030 — Data migration from `transport_entities`
**P0** · **3 d** · **Verified** · **Deps:** BUS-029 · **Audit:** §7

- **Description:** Migrate existing pilot transport data into the relational schema, with explicit handling for data the old model could not represent.
- **Why it matters:** Pilot schools have real vehicles, drivers, routes and allocations. Some fields cannot migrate cleanly: stops have no coordinates, times are unparseable free text, and allocations reference stops by string. These must be surfaced as a remediation worklist for the school, not silently defaulted — defaulting a stop to 0°N 0°E would embed the audit's worst defect into the new schema.
- **Current implementation:** No migration path.
- **Target implementation:** Idempotent, reversible migration. Unparseable times → NULL + flagged. Stop strings → fuzzy-matched to created stops with an admin confirmation queue. Stops without coordinates → created in a `needs_location` state that blocks route publication (BUS-042). A per-school migration report enumerating everything requiring human input.
- **Done when:** Pilot data migrated with a reconciliation report; no fabricated coordinate or time exists post-migration; rollback rehearsed.

---

### BUS-031 — Decommission transport types from `transport_entities`
**P1** · **1 d** · **Not Started** · **Deps:** BUS-030, Phase 3–6 complete · **Audit:** §7

- **Description:** Remove transport entity types from the JSONB store once all readers and writers are relational.
- **Why it matters:** Two sources of truth is worse than either alone. Leaving the old store readable invites a regression that writes to it.
- **Current implementation:** All transport data in `transport_entities`.
- **Target implementation:** Transport entity types dropped; the table retained only if other modules use it. Snapshot documents removed (superseded by BUS-004/BUS-120).
- **Done when:** No transport code path references `transport_entities`; a guard test fails if one is reintroduced.

---

### BUS-032 — Transport repository layer rewrite
**P0** · **4 d** · **Verified** · **Deps:** BUS-029 · **Audit:** §7

- **Description:** Replace the entity-store access layer with typed repositories issuing targeted SQL. Eliminate all full-collection scans.
- **Why it matters:** Current handlers call `findAll('allocation')` — loading **every allocation payload in the school into Deno memory** — on every assign, every bulk operation, every delay notification, and every roster read. Capacity checking is O(all students in school) per single assignment. At 100 buses this degrades badly; at 1,000 it is not viable.
- **Current implementation:** `createEntityWriteStore` + `findAll` at `transport_write_handlers.ts:405`, `:701`, `:1005`, and elsewhere.
- **Target implementation:** Typed repositories per aggregate with predicate-pushdown queries, keyset pagination, and no unbounded fetches. **Preserve** the row-locked read-modify-write discipline (`SELECT … FOR UPDATE`), savepoint-based unique-violation recovery, and the mutation audit catalogue — all three are well-engineered and correct.
- **Done when:** No transport code path loads an unbounded collection. Capacity check is a single indexed count. Concurrency tests still pass.

---

**PHASE 2 EXIT GATE:** All transport reads/writes relational; PostGIS live; pilot data migrated with a reconciliation report; no unbounded scans; RLS negative tests green; EOS gate run.

---

# PHASE 3 — ROUTE MANAGEMENT

**Goal:** an admin can fully create, edit, correct, retire, and publish a route — including real stop locations and real times.
**Exit criteria:** every route attribute is editable; no route can be published in an incomplete state.

---

### BUS-033 — Route update endpoint & full edit UI
**P0** · **2 d** · **Not Started** · **Deps:** BUS-032 · **Audit:** §2, §8 Critical #7

- **Description:** Implement `PUT /transport/routes/{id}` and a complete edit form.
- **Why it matters:** **There is no route update endpoint of any kind.** A route created with a typo in its name is permanent. Departure times can never be corrected. This is a hard functional gap that makes the module unusable for a real school, and it is one of the first things an evaluator will try.
- **Current implementation:** Router (`transport_router.ts`) exposes only `POST /transport/routes` and `POST /transport/routes/{id}/activate`. No PUT.
- **Target implementation:** Full update of name, code, direction, shift, default times, and distance, with optimistic concurrency, validation, and audit events.
- **Done when:** Admin renames a route and corrects its departure time; changes persist and propagate everywhere the route is displayed — with no stale copies (guaranteed by BUS-023 removing denormalized names).

---

### BUS-034 — Route deactivate & delete with guards
**P0** · **1.5 d** · **Not Started** · **Deps:** BUS-033 · **Audit:** §2, §8 Critical #7

- **Description:** Implement route deactivation and deletion with referential guards.
- **Why it matters:** A route can currently only be **activated** — never deactivated, never deleted. A discontinued route stays live forever, keeps counting toward KPIs, and remains selectable for allocation.
- **Current implementation:** `handleActivateRoute` sets status to `active`. No inverse operation exists.
- **Target implementation:** Deactivate (reversible, blocks new allocations, preserves history) and delete (hard-blocked when allocations, assignments, or trips exist — deactivate instead). Clear, actionable rejection messages.
- **Done when:** A route with students cannot be deleted but can be deactivated; a deactivated route disappears from allocation pickers and today's trip generation while its history remains queryable.

---

### BUS-035 — Complete route creation form
**P1** · **1.5 d** · **Not Started** · **Deps:** BUS-033 · **Audit:** §2, §6

- **Description:** Replace the single-field creation dialog with a full form.
- **Why it matters:** Route creation is currently **one text field: "Route name"**. Distance, AM departure, PM departure and shift are silently hardcoded (`"0 km"`, `"7:00 AM"`, `"3:30 PM"`, `"am"`) and — because there is no update endpoint — permanently uncorrectable. The admin is not told any of this.
- **Current implementation:** `transport_workflow_actions.dart:26-51`; defaults applied server-side at `transport_write_handlers.ts:104-116`.
- **Target implementation:** Form covering name, code, direction, shift, default pickup/return times (time pickers), and optional description. No hidden defaults; anything defaulted is visible and editable.
- **Done when:** Every persisted route attribute was either entered or visibly confirmed by the admin at creation.

---

### BUS-036 — Stop CRUD as a first-class entity
**P0** · **2 d** · **Not Started** · **Deps:** BUS-032 · **Audit:** §2, §7

- **Description:** School-level stop management independent of any route.
- **Why it matters:** Stops embedded in a route's JSON array cannot be queried, indexed, referenced by foreign key, or shared. The same physical "Green Park Gate" exists as two independently-editable objects on the morning and afternoon routes — so correcting its location fixes only one of them.
- **Current implementation:** Stops mutated only through `mutateRouteStops`, entirely inside the route document.
- **Target implementation:** Full stop CRUD with search, map view of all school stops, merge-duplicates, and usage display ("used by 3 routes, 47 students"). Deletion blocked while referenced.
- **Done when:** A stop is created once and attached to multiple routes; editing its location updates every route that uses it.

---

### BUS-037 — Stop location capture (map picker + address search)
**P0** · **3 d** · **Not Started** · **Deps:** BUS-036, BUS-086 (SDK wiring) · **Audit:** §1.5, §8 Critical #4

- **Description:** Admin sets a stop's real coordinate via a draggable map pin and address search, with geocoding performed once and cached.
- **Why it matters:** **This is the gating task for the entire tracking feature.** No coordinates means no geofence, no distance-to-stop, no arrival detection, no ETA, no map. Until this ships, everything from Phase 9 onward is unbuildable. Enforces **P-5** and **P-7** (geocode once, store forever — never per view).
- **Current implementation:** Stop editor collects a name and two free-text time strings (`transport_stop_editor.dart:274-338`). No map, no address search, no geocoding, no coordinate field anywhere in the write path.
- **Target implementation:** Map picker with draggable pin, address/landmark search with cached geocoding results, GPS-assisted "use my current location" for field staff, geofence radius slider with a visible circle, and validation that the coordinate falls inside a plausible bounding box for the school. Coordinate is **mandatory**.
- **Done when:** An admin places 8 stops on a real map for a real route; every stop persists an accurate coordinate; zero geocoding calls occur on any subsequent view of those stops.

---

### BUS-038 — Structured stop times
**P0** · **1.5 d** · **Not Started** · **Deps:** BUS-021, BUS-036 · **Audit:** §2, §8 Critical #8

- **Description:** Replace free-text stop times with typed `TIME` values and time pickers. Supersedes BUS-006.
- **Why it matters:** Free-text times make schedule adherence, delay detection, and ETA baselines arithmetically impossible. Fixing the type removes that ceiling permanently and closes the `pickupTime`/`scheduledTime` divergence at the source.
- **Current implementation:** String fields with hint text and zero validation.
- **Target implementation:** `TIME` columns; platform time pickers; server-side validation that stop times increase monotonically along the sequence, with a warning (not a hard block) on violation.
- **Done when:** Times round-trip exactly; a non-monotonic sequence is flagged to the admin; arithmetic on stop times is possible in SQL.

---

### BUS-039 — Route-stop sequence management
**P1** · **1.5 d** · **Not Started** · **Deps:** BUS-021, BUS-037 · **Audit:** §2 (strength to preserve)

- **Description:** Attach, detach, and reorder stops on a route with drag-and-drop, preserving today's race-safe resequencing.
- **Why it matters:** The existing `mutateRouteStops` implementation — row-locked read-modify-write, contiguous 1..N resequencing, permutation validation on reorder — is genuinely well-engineered and understands lost updates. That correctness must survive the schema change; only the storage beneath it changes.
- **Current implementation:** `transport_write_handlers.ts:747-874`, operating on the embedded array.
- **Target implementation:** Same guarantees over `transport_route_stop`, with drag-and-drop reorder and a live map preview of the resulting stop order.
- **Done when:** Concurrent reorder tests pass; sequence is always contiguous; the map preview matches persisted order.

---

### BUS-040 — Shared stops across AM/PM and multiple routes
**P1** · **1 d** · **Not Started** · **Deps:** BUS-039 · **Audit:** §2; Additional requirement 3

- **Description:** One physical stop referenced by many route-stop rows with independent times per route.
- **Why it matters:** Morning and afternoon routes serve the same physical locations at different times. Duplicating the stop duplicates the location, the geofence, and every future correction — and the additional requirements explicitly call for AM/PM route support without redesign.
- **Current implementation:** Impossible — stops live inside a single route document.
- **Target implementation:** Many-to-many via `transport_route_stop`; the stop detail view lists every route using it and each route's times.
- **Done when:** One stop serves an AM and a PM route with different scheduled times; editing its location updates both.

---

### BUS-041 — Route geometry generation & caching
**P1** · **2.5 d** · **Not Started** · **Deps:** BUS-039, BUS-090 · **Audit:** §1.4, §4

- **Description:** Compute and cache the road-following polyline for each route from its ordered stops.
- **Why it matters:** Routes have no geometry today, so nothing can be drawn on a map. Enforces **P-7**: geometry is computed once on route change and cached — never fetched per map render, which is how map bills explode.
- **Current implementation:** None.
- **Target implementation:** Polyline generated by the in-house routing engine (BUS-090) on stop-set change, stored as a geometry column with a version stamp, and served from cache. Manual override supported for roads the graph gets wrong.
- **Done when:** A route renders as a road-following line; changing a stop regenerates it exactly once; zero routing calls occur on map render.

---

### BUS-042 — Route completeness validation & publish gate
**P0** · **1.5 d** · **Not Started** · **Deps:** BUS-033 … BUS-041 · **Audit:** §6

- **Description:** A route cannot be activated until it is genuinely operable, and its gaps are always visible.
- **Why it matters:** The audit's setup finding was that an admin can spend two hours configuring transport and end with a seating chart that can never be tracked — with nothing on screen indicating incompleteness. Make the incomplete state loud instead of letting an admin believe they are finished.
- **Current implementation:** `POST /transport/routes/{id}/activate` sets status to `active` with **no validation whatsoever**.
- **Target implementation:** Publish gate requiring ≥2 stops, every stop with a coordinate, monotonic times, an assigned vehicle, an assigned driver with a valid licence, and ≥1 allocated student. Blocked routes display a per-item checklist of what is missing.
- **Done when:** An incomplete route cannot be activated and the admin sees precisely which items are outstanding.

---

**PHASE 3 EXIT GATE:** Routes fully editable and retirable; every stop has a real coordinate and typed times; incomplete routes cannot be published.

---

# PHASE 4 — BUS (VEHICLE) ASSIGNMENT

**Goal:** a bus can be assigned to a route — permanently and temporarily. This resurrects three correctly-built but unreachable features.
**Exit criteria:** every active route has a resolvable vehicle for any given date.

---

### BUS-043 — Vehicle↔route assignment endpoint
**P0** · **2 d** · **Not Started** · **Deps:** BUS-022 · **Audit:** §2, §8 Critical #2

- **Description:** Assign a vehicle to a route by **id**, creating a dated permanent assignment.
- **Why it matters:** **There is no way to assign a bus to a route.** `assignedBus` is set to `""` at creation and no endpoint anywhere writes it. This is one of the two most fundamental operations in a transport module, and it silently disables three other features (BUS-044, BUS-045, and the parent's bus number). The audit identified this as the **highest value-per-line-of-code fix in the module**.
- **Current implementation:** `transport_write_handlers.ts:111` writes `assignedBus: ""`. Grep across `supabase/functions` confirms no other writer exists. Three subsystems read it.
- **Target implementation:** Assignment via `transport_assignment` referencing `vehicle_id` — never a registration string (**P-6**). Validates vehicle availability (not assigned to an overlapping route in the same shift), active status, and valid compliance documents.
- **Done when:** Admin assigns a bus to a route; the bus number appears on the route, on every allocation view, and on the parent screen; a double-booked vehicle is rejected with a clear reason.

---

### BUS-044 — Reactivate the capacity guard
**P0** · **1 d** · **Not Started** · **Deps:** BUS-043 · **Audit:** §2, §8 Critical #2

- **Description:** Wire the existing race-safe capacity guard to the real vehicle assignment.
- **Why it matters:** TRN-7 is **correct, well-engineered, and has never once executed.** It resolves capacity from the route's assigned vehicle; `assignedBus` is always `""`, so capacity resolves to `null` and the guard returns early. The result is **unlimited over-allocation of a 48-seat bus.** The row locking, the concurrency handling, and the separate override audit trail are all already right — only the input is missing.
- **Current implementation:** `transport_write_handlers.ts:685-738`. Capacity always `null`; guard always skipped.
- **Target implementation:** Capacity resolved from the assignment effective on the allocation date. Guard active for single and bulk allocation. **Preserve** the `allowOverCapacity` override and its distinct audit event — knowing who authorised a 49th child on a 48-seat bus is genuinely valuable.
- **Done when:** Assigning a 49th student to a 48-seat bus is rejected; the override succeeds and emits a separate audit event; the concurrency test proving two simultaneous assignments cannot both slip past now exercises a live code path.

---

### BUS-045 — Vehicle-in-use deletion guard on foreign keys
**P0** · **0.5 d** · **Not Started** · **Deps:** BUS-043 · **Audit:** §2, §8 Critical #2

- **Description:** Block deletion of a vehicle that is assigned, on the FK relationship.
- **Why it matters:** The current guard matches `route.assignedBus` against the registration string. Since `assignedBus` is always empty, it never matches — **you can delete a bus that 45 children ride to school**, with no warning.
- **Current implementation:** `transport_write_handlers.ts:526-540`; dead code.
- **Target implementation:** FK-based restriction plus an application-level check producing a clear message naming the affected routes and student count. Retirement (soft) offered as the correct alternative.
- **Done when:** Deleting an assigned vehicle is rejected with an actionable message; retirement succeeds and preserves history.

---

### BUS-046 — Temporary vehicle replacement
**P1** · **1.5 d** · **Not Started** · **Deps:** BUS-043, BUS-024 · **Audit:** §2; Additional requirement 3

- **Description:** Assign a different vehicle for a single day or date range without disturbing the permanent assignment.
- **Why it matters:** Breakdowns and servicing are routine. The additional requirements explicitly demand temporary vehicle replacement without re-architecture. **P-3** makes this a normal dated row rather than a special case.
- **Current implementation:** Impossible — no assignment concept at all.
- **Target implementation:** Substitute assignment for a date range with a reason; today's trip resolves to the substitute; the permanent assignment returns automatically afterwards. Capacity guard uses the substitute's capacity, and flags if it is smaller than the allocated count.
- **Done when:** A one-day vehicle swap is visible on today's trip, on the driver's app, and on the parent view; tomorrow reverts automatically; a smaller substitute triggers a capacity warning.

---

### BUS-047 — Vehicle identity change safety
**P1** · **0.5 d** · **Not Started** · **Deps:** BUS-017, BUS-043 · **Audit:** §7

- **Description:** Ensure changing a vehicle's registration cannot break any relationship.
- **Why it matters:** Today `PUT /transport/vehicles/{id}` may change a registration while routes reference vehicles **by that string** — silently orphaning the link with no error and no cascade. Moving to FKs removes the failure mode; this task verifies it and adds an audit trail for a legally-significant identifier change.
- **Current implementation:** Registration update allowed; string-based links break silently.
- **Target implementation:** All references by `vehicle_id`. Registration changes audited with before/after values.
- **Done when:** Changing a registration leaves every assignment, trip, and allocation intact, and emits an audit event.

---

**PHASE 4 EXIT GATE:** Every active route resolves a vehicle for any date; capacity guard and delete guard both demonstrably execute; temporary replacement works end-to-end.

---

# PHASE 5 — DRIVER ASSIGNMENT & SUBSTITUTION

**Goal:** a driver can be assigned to a route permanently, and substituted for a single day — the owner's first additional requirement, in full.
**Exit criteria:** "who drives Route 12 today?" is always answerable and always correct.

---

### BUS-048 — Driver↔route assignment endpoint
**P0** · **1.5 d** · **Not Started** · **Deps:** BUS-022, BUS-018 · **Audit:** §2, §8 Critical #2

- **Description:** Assign a driver to a route as a dated permanent assignment.
- **Why it matters:** The second of the two missing fundamental operations. `assignedDriverId` is **read** by the driver-delete guard and **written by nothing**. Without driver assignment there is no trip owner, no GPS source, and no driver app content.
- **Current implementation:** Field read at `transport_write_handlers.ts:646`; never written anywhere.
- **Target implementation:** Assignment through `transport_assignment` with `driver_id`. Validates licence validity, driver availability across overlapping shifts, and active status.
- **Done when:** Admin assigns a driver; the driver appears on the route and on today's trip; an unavailable or expired-licence driver is rejected with a clear reason.

---

### BUS-049 — Driver-in-use deletion guard on foreign keys
**P0** · **0.5 d** · **Not Started** · **Deps:** BUS-048 · **Audit:** §2, §8 Critical #2

- **Description:** Block deletion of an assigned driver, on the FK relationship.
- **Why it matters:** The existing guard matches `assignedDriverId`, which nothing writes — dead code, third of three.
- **Current implementation:** `transport_write_handlers.ts:643-654`.
- **Target implementation:** FK restriction plus a clear message naming affected routes; deactivation offered as the alternative; historical trips retain the driver reference.
- **Done when:** Deleting an assigned driver is rejected with an actionable message; deactivation succeeds and preserves trip history.

---

### BUS-050 — Driver availability & leave model
**P0** · **2 d** · **Not Started** · **Deps:** BUS-018 · **Audit:** §2; Additional requirement 1

- **Description:** Record driver availability — leave, sick days, rest days — as dated records that drive substitution.
- **Why it matters:** The substitute-driver requirement begins with the system knowing the regular driver is unavailable. Without an availability model, substitution is a manual override with no audit trail and no ability to warn about an unstaffed route.
- **Current implementation:** A driver has a coarse `status` field only. No dates, no leave, no calendar.
- **Target implementation:** `transport_driver_availability(driver_id, from_date, to_date, kind, reason, recorded_by)`. Marking a driver unavailable **flags every route they are assigned to for that period as needing a substitute**, surfaced prominently on the transport dashboard.
- **Done when:** Marking a driver on leave for three days raises a substitution-needed flag on all their routes for exactly those dates.

---

### BUS-051 — Substitute driver for today's trip
**P0** · **2.5 d** · **Not Started** · **Deps:** BUS-050, BUS-024 · **Audit:** Additional requirement 1

- **Description:** Assign a different driver for a specific date's trip **without altering the permanent route assignment**.
- **Why it matters:** Directly implements the owner's first additional requirement. **P-3** makes it a dated substitute assignment row rather than a mutation of the route, so the permanent arrangement is never lost and tomorrow reverts automatically with no cleanup step an admin could forget.
- **Current implementation:** No driver assignment exists at all, permanent or temporary.
- **Target implementation:** Admin selects a route/date needing cover, picks from eligible available drivers (valid licence, not otherwise assigned that shift), and confirms with a reason. A substitute assignment is created for that date only; today's trip binds to the substitute; the permanent driver is untouched. Fully audited.
- **Done when:** A substitute is assigned for today; today's trip shows the substitute; tomorrow's trip shows the permanent driver with zero admin action; the audit trail records who authorised the substitution and why.

---

### BUS-052 — Substitute driver handover packet
**P0** · **2 d** · **Not Started** · **Deps:** BUS-051, BUS-065 · **Audit:** Additional requirement 1

- **Description:** On login, a substitute driver immediately receives everything needed to run today's trip — and nothing else.
- **Why it matters:** The owner's requirement is explicit: after login the substitute must **immediately see only today's assigned trip**, with today's route, today's stop list, today's assigned students, and the trip information. A substitute who must be briefed verbally is an operational failure and a safety risk — they do not know the stops or the children.
- **Current implementation:** No driver app, no driver login, no trip.
- **Target implementation:** Driver "Today" screen resolves trips by *effective assignment for the current date*, so a substitute sees the covered route with no special-casing. Packet includes: route name and direction, ordered stop list with times and map, per-stop student manifest, vehicle details, attendant if any, school contacts, and any diversion in force. Cached offline (BUS-068).
- **Done when:** A substitute assigned at 06:30 logs in at 06:45 and sees the complete trip with zero manual briefing; they see no other route and no other day.

---

### BUS-053 — Attendant / conductor role
**P1** · **2 d** · **Not Started** · **Deps:** BUS-013, BUS-022 · **Audit:** §8 nice-to-haves, PRA-P2-19

- **Description:** Introduce the bus attendant (conductor/ayah) as a first-class role assignable to routes and trips.
- **Why it matters:** Grep confirms **zero occurrences** of attendant/conductor anywhere in the codebase. Indian school-transport safety norms commonly expect an attendant on buses carrying young children, and in practice the attendant — not the driver — marks boarding. Competitors model this.
- **Current implementation:** Concept absent.
- **Target implementation:** Attendant role, records, availability, and assignment through `transport_assignment`. Attendant app access limited to today's trip and boarding capture (no driving controls). Substitution supported identically to drivers.
- **Done when:** An attendant is assigned, logs in, sees today's trip, and marks boarding; the driver retains trip control.

---

### BUS-054 — Compliance gate on assignment
**P1** · **1 d** · **Not Started** · **Deps:** BUS-048, BUS-043 · **Audit:** §5 (strength to extend)

- **Description:** Block assignment of a driver with an expired licence or a vehicle with expired statutory documents.
- **Why it matters:** The existing document-expiry tracking with strict ISO validation and the staff digest is one of the module's genuine strengths — but today it only *reports*. Turning it into a gate converts a report into a control, which is what a school actually needs when an inspector asks.
- **Current implementation:** `runDocumentExpiryReminder` scans and digests; nothing blocks any operation.
- **Target implementation:** Hard block on assigning a driver with an expired licence or a vehicle with expired insurance/fitness/permit. Warning at 30 days. Override requires an explicit, separately-audited authorisation.
- **Done when:** Assignment with expired documents is blocked; the override path is audited distinctly; the existing digest continues to work.

---

**PHASE 5 EXIT GATE:** Every route has a resolvable driver for any date; substitution works end-to-end and reverts automatically; compliance gating active.

---

# PHASE 6 — STUDENT ALLOCATION & ROSTER INTEGRITY

**Goal:** student↔stop↔route relationships are referentially sound and cannot be corrupted by typing.
**Exit criteria:** no allocation references a stop by string; no student holds conflicting allocations.

---

### BUS-055 — Stop selection by picker, not free text
**P0** · **1.5 d** · **Not Started** · **Deps:** BUS-023, BUS-036 · **Audit:** §2, §8 Critical

- **Description:** Replace free-text pickup/drop stop entry with pickers constrained to the route's actual stops.
- **Why it matters:** Pickup and drop stops are typed as free text and the roster then groups students by **exact string match**. `"Green Park Gate"`, `"Green park gate"`, and `"Green Park gate "` become three different stops; mismatches silently fall into an `"(unassigned stop)"` bucket. Referential integrity between a child and their stop currently depends on the admin's typing accuracy. This is a safety issue — a driver reading a corrupted roster does not know where to collect a child.
- **Current implementation:** `transport_workflow_actions.dart:339-343` and `:496-500` use plain `TextField`s; roster grouping by string at `transport_handlers.ts:238-250`.
- **Target implementation:** Dropdown/searchable picker of the selected route's stops, persisting `stop_id`. Free text impossible.
- **Done when:** No allocation can reference a non-existent stop; the `"(unassigned stop)"` bucket is structurally unreachable.

---

### BUS-056 — One active allocation per student per shift
**P0** · **1 d** · **Not Started** · **Deps:** BUS-023 · **Audit:** §2

- **Description:** Enforce at most one active allocation per student per shift, while allowing a different AM and PM route.
- **Why it matters:** A student can currently be allocated to two routes simultaneously — nothing checks. They count against both capacities, appear on both rosters, and **both drivers expect them**. Meanwhile the legitimate case (different morning and afternoon routes, very common with after-school activities) is hinted at by the `shift` field but never enforced or supported properly.
- **Current implementation:** Bulk allocation ids are `routeId:sisStudentId`, so a second route creates an independent row. No cross-route check exists.
- **Target implementation:** Partial unique constraint on `(student_id, shift)` for active allocations, with `both` treated as covering AM and PM. Attempting a conflicting allocation offers a transfer instead.
- **Done when:** Double allocation is rejected at the database layer; a distinct AM and PM route for one student is accepted.

---

### BUS-057 — Allocation transfer & removal on the relational model
**P1** · **1.5 d** · **Not Started** · **Deps:** BUS-055, BUS-056 · **Audit:** §2

- **Description:** Port transfer and removal to FK semantics with correct capacity accounting on both sides.
- **Why it matters:** Transfer exists today and does the right thing, but nothing forces its use and nothing detects the duplicate that results from bypassing it. Under the new constraints, transfer becomes the only correct path — so it must be complete.
- **Current implementation:** `handleTransferStudentTransport` rewrites denormalized route/bus name copies; `handleRemoveStudentTransport` returns a cleared object and drops the SIS flag.
- **Target implementation:** Transfer as an atomic operation releasing source capacity and acquiring target capacity under lock, validating the target's capacity and stops. Removal ends the allocation with an effective date, preserving history. **Preserve** the SIS transport-enrolled linkage, now keyed on `student_id`.
- **Done when:** Transfer moves a student atomically with correct counts on both routes; removal preserves history and clears the SIS flag.

---

### BUS-058 — Roster read on the relational model
**P1** · **1 d** · **Not Started** · **Deps:** BUS-055 · **Audit:** §1.9, §7

- **Description:** Rebuild the stop-wise roster as an indexed query.
- **Why it matters:** The roster currently loads **every allocation in the school** and groups in JavaScript by string. On the new model it is a join ordered by sequence — correct and fast — and it is the data the driver's manifest depends on.
- **Current implementation:** `handleRouteRoster` + `buildRoster` at `transport_handlers.ts:169-269`.
- **Target implementation:** Single indexed query joining allocation → route_stop → student, ordered by sequence. **Preserve** the CSV/PDF export, which works well today.
- **Done when:** Roster matches expected grouping exactly; no unbounded fetch; exports unchanged in output.

---

### BUS-059 — Parent-scoped single-child allocation endpoint
**P0** · **1.5 d** · **Not Started** · **Deps:** BUS-028, BUS-013 · **Audit:** §1.9, §8 Critical #3

- **Description:** A dedicated endpoint returning exactly one child's allocation to an authorised parent.
- **Why it matters:** Fixes all three simultaneous failures in the current parent path: the **403** (parent role lacks `viewTransport`; endpoint demands school scope), the **data leak** (school-wide roster returned to a parent device, exposing other children's names, admission numbers and pickup locations), and the **page-1-of-20 truncation** (a parent finds their child only if they land in the first 20 rows by id — in an 800-student school that is ~2.5% of parents). Implements **P-8**.
- **Current implementation:** `parent_transport_provider.dart` fetches `/transport/allocations` and scans client-side.
- **Target implementation:** `GET /parent/transport/allocation?childId=…` returning only that child's allocation, authorised against the parent-child link and enforced by RLS. No list endpoint reachable by a parent.
- **Done when:** Parent receives exactly one allocation regardless of school size; a request for an unlinked child returns 403; no other child's data appears in any parent response payload.

---

### BUS-060 — Bulk allocation rework
**P1** · **2 d** · **Not Started** · **Deps:** BUS-055, BUS-056 · **Audit:** §2 (strength to preserve)

- **Description:** Port bulk allocation to the relational model, preserving its existing partial-success semantics.
- **Why it matters:** Bulk allocation is the **best-engineered handler in the current module** — SIS class/section resolution, deterministic allocation ids, a single capacity check under the route lock, bulk-size caps, and a proper `{assigned, skipped}` partial result. Do not regress it; only change its substrate.
- **Current implementation:** `transport_write_handlers.ts:918-1085`.
- **Target implementation:** Same semantics with FK stop selection, per-shift conflict detection, and skip reasons extended to cover conflicts. **Preserve** the bulk cap and the capacity-override audit.
- **Done when:** A full class is allocated in one operation; conflicts and capacity issues appear as itemised skip reasons; the override audit still fires.

---

### BUS-061 — CSV import for transport master data
**P1** · **3 d** · **Not Started** · **Deps:** BUS-017, BUS-018, BUS-036, BUS-055 · **Audit:** §6

- **Description:** Validated CSV import for vehicles, drivers, stops, and allocations.
- **Why it matters:** Onboarding today is ~2 minutes of typing per bus, per driver, per stop, and per student. Twenty buses is 40 minutes before a single route exists. Every competitor has import; it is the difference between a 40-minute and a 4-minute onboarding, and it is what a school will judge in the first hour.
- **Current implementation:** None — all entry is one-at-a-time through dialogs.
- **Target implementation:** Templated CSV per entity with dry-run validation, row-level error reporting, address geocoding for stops during import (cached), and idempotent re-import. Nothing partially applied without an explicit confirmation.
- **Done when:** A school onboards 20 buses, 20 drivers, 60 stops and 600 allocations by import; every rejected row carries an actionable reason.

---

**PHASE 6 EXIT GATE:** No string-based stop references remain; no student double-allocated; parent reads exactly one child; bulk and CSV paths verified.

---

# PHASE 7 — DRIVER IDENTITY & DRIVER APP

**Goal:** drivers can log in and see today's work. Without this there is no GPS source and no tracking — this phase is the true unlock.
**Exit criteria:** a real driver logs in on a real phone and sees today's trip, stops, and students.

---

### BUS-062 — Driver role, scope & authorization
**P0** · **2 d** · **Not Started** · **Deps:** BUS-013, BUS-018 · **Audit:** §1.8, §8 Critical

- **Description:** Implement the driver role, auth scope, token claims, and authorization rules.
- **Why it matters:** **The root cause of the entire tracking absence.** `UserRole` contains no driver; drivers cannot log in; therefore there is no GPS source; therefore no tracking is theoretically reachable from the current architecture. Everything from here to Phase 16 depends on this task.
- **Current implementation:** `UserRole = {parent, teacher, student, staff}`. Drivers exist only as data records.
- **Target implementation:** `driver` role and scope; tokens carrying driver identity and school; authorization limited to their own trips for the current service date. Enforced in RLS (BUS-028), not only in handlers.
- **Done when:** A driver authenticates and can read only their own current trip; every attempt to read another driver's trip, another date, or any admin surface is rejected.

---

### BUS-063 — Driver login
**P0** · **2 d** · **Not Started** · **Deps:** BUS-062 · **Audit:** §1.8, §6

- **Description:** Phone + OTP login for drivers, with session handling suited to shared and low-end devices.
- **Why it matters:** Drivers are not email users. Login must work on a low-end Android phone, in poor connectivity, at 6 a.m., without IT support. A substitute assigned at 06:30 must be able to log in at 06:45 (BUS-052) — so account provisioning must be immediate on driver creation, not a separate step someone forgets.
- **Current implementation:** No driver authentication of any kind.
- **Target implementation:** Phone+OTP with the project's existing OTP infrastructure; long-lived refresh suited to daily use; explicit device binding; admin-initiated session revocation. Account provisioned automatically when a driver record is created.
- **Done when:** A newly-created driver logs in on first attempt with no admin intervention; revocation takes effect immediately.

---

### BUS-064 — Driver app shell
**P0** · **3 d** · **Not Started** · **Deps:** BUS-063 · **Audit:** §1.8, §5

- **Description:** Driver-specific app shell — navigation, theming, and large-touch-target layout for in-vehicle use.
- **Why it matters:** The driver is not an ERP user. The interface must be operable in seconds, in daylight, possibly with gloves, by someone whose primary task is driving. Every competitor ships a driver app; we ship none.
- **Current implementation:** No driver surface exists.
- **Target implementation:** Minimal shell — Today, Trip, Manifest, Profile — built on the Akshara design system with driver-appropriate scale (large targets, high contrast, minimal chrome, no nested navigation). Honours the existing 48dp minimum touch-target rule.
- **Done when:** A driver reaches any primary action in at most two taps from launch; usable outdoors in sunlight.

---

### BUS-065 — Driver "Today" screen
**P0** · **2.5 d** · **Not Started** · **Deps:** BUS-064, BUS-069 · **Audit:** Additional requirements 1 & 2

- **Description:** On login the driver sees exactly today's assigned trip (or trips, for AM+PM) — nothing else.
- **Why it matters:** Directly implements the owner's requirement: *"After login, the substitute driver should immediately see only today's assigned trip."* Resolving trips by *effective assignment for the current date* means a substitute needs no special case (BUS-052). Showing a driver anything other than today's work is noise that costs seconds at 6 a.m.
- **Current implementation:** None.
- **Target implementation:** Screen resolving trips from `transport_assignment` effective today, showing route, direction, shift, vehicle, scheduled departure, stop count, student count, and the primary action (Start Trip). No route browser, no history, no other dates.
- **Done when:** Permanent and substitute drivers both see the correct trip with zero configuration; a driver with no trip today sees a clear, calm empty state.

---

### BUS-066 — Driver route & stop list
**P0** · **2 d** · **Not Started** · **Deps:** BUS-065, BUS-037 · **Audit:** Additional requirement 1

- **Description:** Ordered stop list with times, addresses, landmarks, and map, plus turn-by-turn hand-off.
- **Why it matters:** A substitute driver does not know the route. This screen replaces the verbal briefing that today's design implicitly assumes and that safety cannot depend on.
- **Current implementation:** None.
- **Target implementation:** Ordered stops with scheduled times, address and landmark text, per-stop student count, map with the route polyline, and a "navigate to next stop" hand-off to the device navigation app (no billable routing calls from us — **P-7**).
- **Done when:** A driver who has never run the route completes it using only the app.

---

### BUS-067 — Driver student manifest
**P0** · **2 d** · **Not Started** · **Deps:** BUS-066, BUS-058 · **Audit:** Additional requirement 1; §1.7

- **Description:** Per-stop student manifest with the identifying detail a driver legitimately needs.
- **Why it matters:** The driver must know who to expect at each stop and who is still to board. This is the operational core of child safety on a bus — and it is the data BUS-102 boarding capture writes against. Scope is bounded by the BUS-012 visibility matrix: enough to identify a child at a stop, no more.
- **Current implementation:** None. (Roster exists for admin export only.)
- **Target implementation:** Grouped-by-stop manifest with name, class, photo where policy permits, and guardian contact for exception handling only. Running boarded/expected counts. Offline-available (BUS-068).
- **Done when:** A driver sees exactly the children expected at each stop and a live count of who has boarded.

---

### BUS-068 — Driver offline cache
**P0** · **2.5 d** · **Not Started** · **Deps:** BUS-067 · **Audit:** §3, §5

- **Description:** Today's trip, stops, and manifest cached locally and fully usable without connectivity.
- **Why it matters:** Buses drive through dead zones daily. A manifest that blanks out mid-route is worse than useless. Offline capability is also where we currently score **0/10** against every competitor — and the platform already has `sqflite`/`sqflite_sqlcipher` and `connectivity_plus` as dependencies, unused by transport.
- **Current implementation:** None.
- **Target implementation:** Encrypted local cache of today's trip, refreshed on login and on change; explicit staleness indicator; all read operations functional offline; boarding marks queued for sync (BUS-080).
- **Done when:** A driver in airplane mode for the full route retains the manifest and can mark boarding throughout; everything syncs on reconnection.

---

**PHASE 7 EXIT GATE:** A real driver on a real phone logs in and runs a full route from the app, offline-capable, seeing only today's work.

---

# PHASE 8 — TRIP LIFECYCLE

**Goal:** implement the owner's trip lifecycle exactly — login → today's trip → Start → tracking auto-on → parent visibility auto-on → End → tracking auto-off → history stored.
**Exit criteria:** no manual tracking toggle exists anywhere in the product.

---

### BUS-069 — Daily trip generation
**P0** · **2.5 d** · **Not Started** · **Deps:** BUS-024, BUS-022 · **Audit:** §2, §7; Additional requirement 2

- **Description:** Materialise trips for each service date from routes, assignments, and the school calendar.
- **Why it matters:** **P-4.** The trip is what the driver app, tracking, boarding, and parent visibility all attach to. Generating it ahead of time (rather than on Start) lets an admin see today's plan, spot an unstaffed route, and arrange a substitute *before* 6 a.m. rather than discovering the gap when a bus does not arrive.
- **Current implementation:** No trip concept.
- **Target implementation:** Scheduled generation for the next N days, resolving the effective vehicle/driver/attendant per route per date; idempotent regeneration on assignment change; trips suppressed on holidays (BUS-074); unstaffed trips flagged to the admin.
- **Done when:** Tomorrow's trips exist tonight with correct assignments; changing an assignment regenerates cleanly without duplicating.

---

### BUS-070 — Start Trip
**P0** · **2 d** · **Not Started** · **Deps:** BUS-069, BUS-065 · **Audit:** Additional requirement 2

- **Description:** Driver taps Start Trip; the trip enters `started`, GPS capture begins automatically, and parent visibility opens automatically.
- **Why it matters:** **P-9 and the owner's explicit instruction: the driver must not manually enable tracking.** A separate tracking toggle is the single most common failure mode in competitor driver apps — drivers forget it, and parents see a stationary bus. Binding capture to trip state removes the failure entirely.
- **Current implementation:** None.
- **Target implementation:** One primary action. On start: validate the driver is assigned and the trip is for today; capture the start location and timestamp; start the foreground location service (BUS-077); open the parent visibility window (BUS-096); notify subscribed parents (BUS-110). No independent tracking control exists anywhere in the UI.
- **Done when:** Tapping Start begins position flow within seconds and makes the trip visible to the right parents, with no other driver action. Grep proves no tracking on/off control exists in any build.

---

### BUS-071 — End Trip
**P0** · **1.5 d** · **Not Started** · **Deps:** BUS-070 · **Audit:** Additional requirement 2

- **Description:** Driver taps End Trip; capture stops, parent visibility closes, and the trip is finalised into history.
- **Why it matters:** Completes the lifecycle. Without a clean stop, GPS drains battery all day, parents keep watching a parked bus at the depot, and the trip record never closes — all three are privacy or trust problems.
- **Current implementation:** None.
- **Target implementation:** Confirmation guard when students remain unmarked; stop the location service; close the visibility window; compute distance, duration, and adherence; write the immutable trip record. Automatic end safeguard (geofence at school + time threshold) for a driver who forgets, clearly marked as auto-ended.
- **Done when:** Ending a trip stops position flow within seconds, closes parent access, and persists a complete history record. The auto-end safeguard fires correctly in test.

---

### BUS-072 — Trip state machine & guards
**P0** · **1.5 d** · **Not Started** · **Deps:** BUS-071 · **Audit:** §7; Additional requirement 2

- **Description:** Formal state machine with enforced legal transitions.
- **Why it matters:** Prevents double-started trips, positions arriving for a completed trip, boarding marks on a cancelled trip, and other integrity violations that would silently corrupt history and safety records.
- **Current implementation:** None.
- **Target implementation:** `scheduled → started → completed`, plus `cancelled` from scheduled and `aborted` from started (with an incident record). Transitions enforced server-side with row locks. Ingest rejects positions for non-started trips.
- **Done when:** Every illegal transition is rejected and covered by a test; late-arriving positions for a completed trip are handled explicitly and documented.

---

### BUS-073 — Trip history & immutability
**P0** · **1.5 d** · **Not Started** · **Deps:** BUS-072 · **Audit:** §1.7, §7

- **Description:** Completed trips are immutable and permanently queryable.
- **Why it matters:** The system today **cannot store yesterday** — transport attendance has no date and re-recording overwrites in place. Immutable trip history is what makes "was my son on the bus last Tuesday?" answerable, and it is the evidentiary record when an incident is investigated.
- **Current implementation:** No history of any kind.
- **Target implementation:** Completed trips write-protected; corrections recorded as separate audited adjustments referencing the original; retention policy defined; history queryable by route, driver, vehicle, student and date.
- **Done when:** A completed trip cannot be mutated; a correction is visible as an adjustment; a specific child's boarding on a specific past date is retrievable.

---

### BUS-074 — School calendar awareness
**P1** · **1 d** · **Not Started** · **Deps:** BUS-069 · **Audit:** §2

- **Description:** Trip generation respects holidays, exam schedules, and early-closure days.
- **Why it matters:** Generating trips on a holiday produces phantom trips, spurious "bus not started" alerts, and noise that trains admins to ignore alerts.
- **Current implementation:** No calendar integration.
- **Target implementation:** Integration with the school academic calendar; holidays suppress generation; early closure shifts PM trip times; per-route exceptions supported.
- **Done when:** No trips generate on a school holiday; an early-closure day generates PM trips at the adjusted time.

---

### BUS-075 — Emergency route diversion
**P1** · **2.5 d** · **Not Started** · **Deps:** BUS-072, BUS-041 · **Audit:** Additional requirement 3

- **Description:** Mid-trip diversion — skip a stop, add a temporary stop, or take an alternate path — recorded against the trip without altering the route template.
- **Why it matters:** Explicitly required by the owner. Waterlogging, a closed road, or a local incident happen mid-route and must be handled without corrupting the permanent route definition. **P-3/P-4**: the diversion belongs to the trip.
- **Current implementation:** Impossible.
- **Target implementation:** Driver or admin records a diversion with a reason; affected stops marked skipped or relocated; affected parents notified automatically (BUS-110); ETA recomputed (BUS-091); the route template is untouched and tomorrow runs normally.
- **Done when:** A stop is skipped mid-trip with automatic notification to exactly the affected parents; tomorrow's trip is unaffected; the diversion appears in trip history.

---

**PHASE 8 EXIT GATE:** Full lifecycle demonstrated end-to-end; no manual tracking control exists in any build; history immutable.

---

# PHASE 9 — GPS TRACKING

**Goal:** reliable, trustworthy, battery-sane position capture and ingest from pluggable sources.
**Exit criteria:** a real bus running a real route produces a complete, gap-free position trace on a mid-range Android phone.

---

### BUS-076 — Location source abstraction (implementation)
**P0** · **2 d** · **Not Started** · **Deps:** BUS-011, BUS-072 · **Audit:** §4; Additional requirement 3

- **Description:** Implement the BUS-011 ingest boundary with the driver-phone source as the first adapter.
- **Why it matters:** **P-2.** Building phone capture directly into the trip logic would force a redesign when the first school buys hardware trackers. The boundary must exist before the first source is written, not after.
- **Current implementation:** None.
- **Target implementation:** The specified `LocationFix` envelope, source registry, and adapter interface; the driver phone as adapter #1; hardware as adapter #2 (BUS-085) requiring no changes above the boundary.
- **Done when:** A synthetic second source can be added touching only adapter and registry code, demonstrated in test.

---

### BUS-077 — Foreground-service GPS capture
**P0** · **4 d** · **Not Started** · **Deps:** BUS-076, BUS-070 · **Audit:** §3

- **Description:** Android foreground service and iOS background location capture, started and stopped by trip state.
- **Why it matters:** **This is where most school-ERP tracking implementations actually fail in the field.** Since Android 8 a backgrounded app is aggressively throttled, and OEM skins (Xiaomi, Oppo, Vivo, Realme — i.e. most Indian driver phones) kill background work far harder than stock Android. The feature works in the demo and dies on the driver's Redmi. Getting this right is the difference between a real product and a demo.
- **Current implementation:** None. No location plugin, no foreground service, no iOS background entitlement.
- **Target implementation:** Android foreground service with a persistent notification and correct manifest declarations; iOS background location with the appropriate entitlement; service lifecycle bound strictly to trip state (**P-9**); wake-lock strategy; auto-restart on process death mid-trip.
- **Done when:** Position capture survives 6 hours backgrounded, screen off, on Xiaomi, Oppo, Vivo, Realme and Samsung devices, with a documented per-OEM test result table.

---

### BUS-078 — OEM battery-optimisation onboarding
**P0** · **2 d** · **Not Started** · **Deps:** BUS-077 · **Audit:** §3

- **Description:** Guided, per-OEM setup ensuring the driver's phone will not kill the tracking service.
- **Why it matters:** Even a correct foreground service is killed by aggressive OEM battery managers unless the user grants an exemption — through settings screens that differ per manufacturer and are effectively undiscoverable. Without this flow, tracking silently stops for a subset of drivers and nobody knows why.
- **Current implementation:** None.
- **Target implementation:** Device-model detection with per-OEM step-by-step guidance and deep links to the correct settings page, a verification check confirming the exemption, and a persistent warning in the driver app while unresolved. Admin visibility of which drivers are unprotected.
- **Done when:** A driver completes setup on each major OEM and tracking survives a full route; the admin can see any driver whose device is not correctly configured.

---

### BUS-079 — Adaptive sampling & battery strategy
**P1** · **2 d** · **Not Started** · **Deps:** BUS-077 · **Audit:** §3

- **Description:** Vary sampling rate and accuracy by context to balance fidelity against battery.
- **Why it matters:** A fixed 10-second high-accuracy interval for 6 hours consumes roughly 30–50% of a mid-range phone battery — a driver whose phone dies at 8 a.m. is untracked for the rest of the day, which is worse than a slightly coarser trace.
- **Current implementation:** None.
- **Target implementation:** Coarse sampling when stationary, tighter near stops and while moving, distance-filtered updates, batched upload (one request per minute carrying multiple fixes rather than one request per fix), and battery-level-aware degradation with an explicit admin-visible signal when degraded.
- **Done when:** A 6-hour route consumes under 15% battery on a mid-range device while retaining fidelity sufficient for accurate arrival detection.

---

### BUS-080 — Store-and-forward offline buffer
**P0** · **2.5 d** · **Not Started** · **Deps:** BUS-077, BUS-068 · **Audit:** §3

- **Description:** Buffer fixes locally through connectivity gaps and flush in order on reconnect; server accepts out-of-order backfill.
- **Why it matters:** Buses drive through dead zones. Without buffering, the trace has holes exactly where the bus was hardest to find, and boarding marks made offline are lost. Offline capability is a current 0/10 against every competitor.
- **Current implementation:** None.
- **Target implementation:** Local durable queue with monotonic timestamps; ordered batched flush on reconnect; server-side idempotent, out-of-order-tolerant ingest; bounded buffer with a documented drop policy that is surfaced, never silent.
- **Done when:** A 20-minute connectivity gap produces a complete backfilled trace with no duplicates and no silent loss; queued boarding marks arrive intact.

---

### BUS-081 — Batched position ingest endpoint
**P0** · **2.5 d** · **Not Started** · **Deps:** BUS-076, BUS-025 · **Audit:** §1.2, §4, §7

- **Description:** A dedicated, lightweight, high-throughput ingest endpoint accepting batched fixes.
- **Why it matters:** **There is no GPS ingest endpoint at all today** — the entire 30-route transport API accepts no coordinate. At 1,000 buses the ingest path handles ~2.16M fixes/day; routing that through a general-purpose edge function with full tenant-context setup per call is both slow and expensive. Batching to one request per bus per minute reduces this to ~360k requests/day.
- **Current implementation:** None.
- **Target implementation:** Minimal-overhead endpoint validating that the caller owns the referenced started trip, accepting a batch, writing to hot store (BUS-083) and durable store (BUS-025), then evaluating geofences asynchronously. Rate-limited per trip. Ingest never blocks on downstream processing.
- **Done when:** Ingest sustains the 1,000-bus load profile within the latency budget defined in BUS-127, with authorization enforced per batch.

---

### BUS-082 — Location integrity & anti-spoof
**P0** · **2 d** · **Not Started** · **Deps:** BUS-081 · **Audit:** §3, §1.11

- **Description:** Detect and flag mock locations, implausible jumps, and off-corridor positions.
- **Why it matters:** A driver can install a mock-location app to appear on time. If the system trusts spoofed positions, every downstream safety claim — arrival, boarding, adherence — is worthless. **The staff-attendance module already implements geofence validation and anti-mock detection**; that hard, security-sensitive work is already solved once in this codebase and should be reused, not rewritten.
- **Current implementation:** Anti-mock exists only in `staff_attendance`; transport has nothing.
- **Target implementation:** Mock-provider detection at capture; server-side plausibility checks (speed, acceleration, teleportation); route-corridor deviation scoring; integrity flags stored per fix; suspicious trips surfaced to the admin. Flagged positions are never silently discarded — they are recorded and marked.
- **Done when:** A mock-location app is detected and flagged; an implausible jump is flagged; the admin sees an integrity warning on the affected trip.

---

### BUS-083 — Hot last-known-position store
**P0** · **2 d** · **Not Started** · **Deps:** BUS-081 · **Audit:** §7

- **Description:** Serve current positions from a hot in-memory store, not from the write-heavy time-series table.
- **Why it matters:** Parent and admin live views poll frequently. Reading the partitioned position table on every poll puts read load directly on the hottest write path — the classic way live-tracking systems fall over at exactly the moment they matter most.
- **Current implementation:** None.
- **Target implementation:** Redis (or equivalent) holding last-known position per active trip with a TTL, written on ingest, read by all live views. Durable table used only for history and analytics. Documented fallback when the hot store is unavailable.
- **Done when:** Live views never query the position table; a hot-store outage degrades gracefully with a clear staleness indicator rather than showing stale data as current.

---

### BUS-084 — Position retention, partitioning & archival
**P1** · **2 d** · **Not Started** · **Deps:** BUS-025, BUS-081 · **Audit:** §7, §3

- **Description:** Automated partition management, retention enforcement, and archival of aged position data.
- **Why it matters:** Unbounded growth of a 2.16M-row/day table is an operational time bomb, and indefinite retention of children's location-adjacent data is a privacy liability under the BUS-012 model.
- **Current implementation:** None.
- **Target implementation:** Automated partition creation and drop; hot retention of 7–30 days at full fidelity; downsampled trip summaries retained longer; archival export; retention documented in the privacy model and surfaced to schools.
- **Done when:** Partitions are managed without manual intervention; retention runs on schedule; storage growth is bounded and forecastable.

---

### BUS-085 — Hardware GPS device adapter & registry
**P2** · **4 d** · **Not Started** · **Deps:** BUS-076, BUS-081 · **Audit:** §4; Additional requirement 3

- **Description:** Second location-source adapter for third-party hardware trackers, plus a device registry.
- **Why it matters:** Schools that want tamper-proof tracking will buy hardware (₹3,000–6,000/bus + ₹100–200/month). Supporting both models widens the market: schools that will not run a driver app still get tracking, and hardware survives phone changes and driver behaviour. Explicitly named in the additional requirements as a must-not-require-redesign capability. Deliberately P2 — the driver-phone path must be proven first.
- **Current implementation:** None. `gpsDeviceId` exists as an unused string on the vehicle record.
- **Target implementation:** Adapter conforming to the BUS-011 contract; device registry binding a device to a vehicle with dated validity; ingest attribution by source; admin view of device health and last contact; source priority when both are present.
- **Done when:** A hardware device feeds positions through the same ingest and renders identically on every map, with no change above the ingest boundary.

---

**PHASE 9 EXIT GATE:** A real bus produces a complete trace on a mid-range Android phone across every major OEM; spoofing is detected; ingest meets the load profile; retention is automated.

---

# PHASE 10 — LIVE MAP

**Goal:** render positions, routes, and stops on a real map without recurring per-view cost.
**Exit criteria:** admin sees the live fleet; zero billable map API calls occur in any render loop.

---

### BUS-086 — Map SDK integration
**P0** · **3 d** · **Not Started** · **Deps:** BUS-083 · **Audit:** §1.3, §4

- **Description:** Integrate the chosen map SDK across Flutter mobile and web, with keys, platform configuration, and a design-system-aligned style.
- **Why it matters:** **We have no map dependency at all today** — no `google_maps_flutter`, no `maplibre_gl`, no `flutter_map`, nothing, on any platform. The audit's recommendation is Google Maps SDK for Android/iOS in v1: **native mobile map loads carry no charge**, India road data is the best available, and it is the fastest path to shipping. MapLibre + a tile provider remains the v2 option if vendor independence becomes a priority. Raw OSM tile servers are excluded — their usage policy prohibits production app traffic.
- **Current implementation:** Grey placeholder cards on both Flutter (`transport_tracking_screen.dart:82-113`) and web (`TrackingPage.tsx`).
- **Target implementation:** SDK integrated on Android, iOS and web; API keys managed per environment with correct platform and referrer restrictions; a documented decision record justifying the provider choice and the migration path to MapLibre.
- **Done when:** A map renders on all three platforms with correct keys and restrictions; the decision record is approved.

---

### BUS-087 — Admin live fleet map
**P0** · **3 d** · **Not Started** · **Deps:** BUS-086, BUS-041 · **Audit:** §1.2, §1.3

- **Description:** Real-time fleet view showing every active trip, its route line, stops, and progress.
- **Why it matters:** This is the screen a principal opens when a parent calls asking where the bus is. It replaces the grey box that currently defines the module in every demo.
- **Current implementation:** Placeholder card plus a static telemetry table fed by seeded fixture data.
- **Target implementation:** Live markers from the hot store with smooth interpolation, route polylines, stop markers with completion state, per-bus status and last-fix age, filtering by route/status, and click-through to trip detail. **Preserve** the existing telemetry table as a complementary list view — it is genuinely useful and works well on small screens.
- **Done when:** An admin watches buses move in real time; a stale or offline bus is visually unmistakable; the view is correct on mobile and desktop.

---

### BUS-088 — Map cost guardrails
**P0** · **1 d** · **Not Started** · **Deps:** BUS-086 · **Audit:** §4

- **Description:** Enforce that no billable map-vendor API is called from any per-ping, per-poll, or per-render path.
- **Why it matters:** **P-7.** The audit's central commercial finding: calling a routing API per ping for 100 buses would cost on the order of **$70,000/year**, while the same feature costs effectively nothing when architected correctly. This is the difference between a viable and an unviable product, and it must be enforced structurally rather than by discipline.
- **Current implementation:** N/A — no map integration exists.
- **Target implementation:** Architectural rule with automated enforcement: geocoding only at stop creation/import and cached permanently; route geometry computed on route change and cached; ETA computed in-house (Phase 11); no Directions, Distance Matrix, Roads, or Places call in any loop. A lint or test fails the build on violation. Billing alerts configured with a hard cap.
- **Done when:** A month of pilot operation shows map-vendor spend within the projected band (₹0–2,000/month for 100 schools × 10 buses); the guardrail test rejects a deliberately-introduced violation.

---

### BUS-089 — Map theming & design-system alignment
**P2** · **1.5 d** · **Not Started** · **Deps:** BUS-087 · **Audit:** §5 (UX strength to preserve)

- **Description:** Style map surfaces to the Akshara design system in light and dark themes.
- **Why it matters:** The module's design-system consistency, accessibility semantics, and responsive card/table switching are rated genuine strengths. A default-styled map would visibly break that. Additive-only per the frozen design-system decision.
- **Current implementation:** N/A.
- **Target implementation:** Custom map style matching brand tokens; marker and polyline styling from design tokens; light/dark support; accessible non-map fallbacks for every map-conveyed fact.
- **Done when:** Map surfaces pass design review in both themes; every map-only fact is also available in text.

---

**PHASE 10 EXIT GATE:** Live fleet visible to admin on all platforms; cost guardrails enforced by an automated test; design review passed.

---

# PHASE 11 — ETA ENGINE

**Goal:** compute honest, improving ETAs in-house at zero marginal cost.
**Exit criteria:** every ETA shown is computed from real data and carries a stated confidence.

---

### BUS-090 — Routing engine selection & hosting
**P1** · **4 d** · **Not Started** · **Deps:** BUS-037 · **Audit:** §4

- **Description:** Select, host, and operate an open-source routing engine over an OpenStreetMap road graph.
- **Why it matters:** **P-7.** This is how Uber, Swiggy, Zomato, Blinkit and Porter avoid per-request routing costs — they run their own engine (OSRM, Valhalla, GraphHopper class) over OSM data rather than calling a vendor API per event. It converts routing from a variable per-transaction cost into a fixed engineering cost, and it is the prerequisite for both route geometry (BUS-041) and ETA.
- **Current implementation:** None.
- **Target implementation:** Engine selected with a written rationale; India OSM extract hosted with a documented update cadence; internal routing service exposing distance/duration/geometry; capacity and failover planned; fallback behaviour defined when unavailable.
- **Done when:** The service returns correct road-following routes for pilot-city stop pairs; sustained load meets the budget; a documented update procedure exists.

---

### BUS-091 — Baseline ETA computation
**P1** · **3 d** · **Not Started** · **Deps:** BUS-090, BUS-083 · **Audit:** §1.6, §4

- **Description:** Compute ETA to each remaining stop from current position, remaining route geometry, and scheduled dwell times.
- **Why it matters:** Replaces the fabricated "8 minutes" (BUS-001) with a real number. **P-1** applies absolutely: if the inputs are insufficient, the system states that rather than guessing.
- **Current implementation:** None. A hardcoded string.
- **Target implementation:** ETA per remaining stop from live position, cached route geometry, historical segment times (BUS-092), and dwell allowances. Recomputed on a sane cadence — never by calling an external routing API per ping. Explicitly unavailable when position is stale or integrity-flagged.
- **Done when:** ETA for the next stop is within an acceptable error band on real pilot routes; a stale-position trip shows "unavailable", not a number.

---

### BUS-092 — Historical segment-time learning
**P2** · **4 d** · **Not Started** · **Deps:** BUS-091 · **Audit:** §4

- **Description:** Accumulate observed segment travel times by day-of-week and time-of-day to improve ETA accuracy over time.
- **Why it matters:** The audit's key insight from the logistics companies: an in-house model trained on your own historical data is **more accurate** than a generic API, because a generic API does not know that this driver takes that shortcut, or that this stretch is impassable at 07:40 on a school day. Accuracy compounds every term, at zero marginal cost.
- **Current implementation:** None.
- **Target implementation:** Per-segment travel-time aggregation bucketed by day and time band; outlier rejection; blended with the routing baseline; per-route accuracy tracked and reported.
- **Done when:** ETA error measurably decreases over one term of pilot data, with the improvement evidenced in the accuracy report.

---

### BUS-093 — Delay detection & schedule adherence
**P1** · **2 d** · **Not Started** · **Deps:** BUS-091, BUS-038 · **Audit:** §1.12, §2

- **Description:** Compare actual progress against the scheduled timetable and classify delays.
- **Why it matters:** Feeds automatic delay notification (BUS-110), on-time reporting (BUS-123), and the dashboard KPIs that BUS-004 made honest. **Impossible before BUS-038** — free-text times cannot be subtracted, which is why the current module can display a hardcoded "94% On-Time" but never compute one.
- **Current implementation:** Only the seeded fake on-time figures.
- **Target implementation:** Per-stop schedule variance; delay thresholds configurable per school; delay classification (minor/major/severe); adherence recorded on the trip record.
- **Done when:** A deliberately delayed test trip is correctly classified and drives both notification and reporting.

---

### BUS-094 — ETA honesty & confidence presentation
**P0** · **1 d** · **Not Started** · **Deps:** BUS-091 · **Audit:** §1.6; **P-1**

- **Description:** Every displayed ETA carries an accuracy characterisation and degrades explicitly when inputs are weak.
- **Why it matters:** The failure this roadmap exists to prevent. A precise-looking number derived from a stale or spoofed fix is worse than no number, because the parent acts on it. Presentation must make uncertainty legible.
- **Current implementation:** A fabricated constant with a disclaimer most readers will not reach.
- **Target implementation:** ETA shown as a range or with an explicit confidence indicator; position age always visible; "unavailable" states for stale, missing, or integrity-flagged data; no ETA rendered for a trip that has not started.
- **Done when:** No ETA is displayed anywhere without a freshness indicator; a stale-fix scenario shows an explicit unavailable state on parent, driver, and admin surfaces.

---

**PHASE 11 EXIT GATE:** ETAs computed in-house, measurably accurate, honestly presented, at zero per-request vendor cost.

---

# PHASE 12 — PARENT TRACKING

**Goal:** a parent sees their own child's bus, live, during the relevant window, and nothing else.
**Exit criteria:** the three simultaneous parent-path failures from the audit are all closed and proven closed.

---

### BUS-095 — Parent transport authorization
**P0** · **2 d** · **Not Started** · **Deps:** BUS-028, BUS-059 · **Audit:** §1.9, §8 Critical #3

- **Description:** Grant parents correctly-scoped transport access enforced at the database layer.
- **Why it matters:** Closes the 403 that makes the current parent screen non-functional in the live build, without opening the leak. Both must be solved together — granting access without data minimisation would convert a broken feature into a child-safety incident.
- **Current implementation:** Parent role holds no transport permission; endpoints require school scope; RLS requires school scope.
- **Target implementation:** Narrow parent transport permission; RLS policies restricting parents to their own children's allocations and active trips; every parent endpoint independently verified against the BUS-012 matrix.
- **Done when:** A parent reads their own child's transport data successfully and every attempt to read another child's returns 403 — proven at the database layer, not only the API layer.

---

### BUS-096 — Parent live trip view
**P0** · **3 d** · **Not Started** · **Deps:** BUS-095, BUS-087, BUS-091 · **Audit:** §1.6, §1.9; Additional requirement 2

- **Description:** Live map showing the bus carrying this parent's child, available automatically while the trip is active.
- **Why it matters:** The feature parents judge the entire ERP on, and the owner's requirement that *"parent live tracking automatically becomes available"* when the trip starts — no parent action, no toggle, no waiting for an admin to enable anything.
- **Current implementation:** A hardcoded ETA string and no map.
- **Target implementation:** Live position, route line, remaining stops, child's stop highlighted, ETA with confidence (BUS-094), and driver/vehicle identification. Visible only during the active trip window per BUS-012; a clear pre-trip and post-trip state outside it. Opens automatically on Start Trip and closes on End Trip.
- **Done when:** A parent opens the app during an active trip and sees their child's bus moving; before and after the window they see an appropriate state; no other child's data is present in any payload.

---

### BUS-097 — Parent transport detail card
**P1** · **1.5 d** · **Not Started** · **Deps:** BUS-095 · **Audit:** §1.9

- **Description:** Rebuild the parent transport screen on real data — route, stop, times, bus, driver, today's status.
- **Why it matters:** The current screen shows a route name, a **blank bus number** (because no assignment path exists — BUS-043), pickup/drop stops, and a fabricated ETA. Every field becomes real once Phases 3–5 land.
- **Current implementation:** `parent_transport_screen.dart` with a static insight card.
- **Target implementation:** Route, assigned bus (including today's substitute if any), driver name and contact (BUS-098), pickup and drop stops with scheduled times, today's trip status, and recent boarding history for their child only.
- **Done when:** Every field is populated from live data and reflects today's actual vehicle and driver, including substitutions.

---

### BUS-098 — Driver identity & contact for parents
**P1** · **1 d** · **Not Started** · **Deps:** BUS-097, BUS-012 · **Audit:** §8 nice-to-haves, PRA-P2-19

- **Description:** Surface the driver's name, photo, and a contact channel to parents of children on that trip.
- **Why it matters:** Recorded as a gap in the existing product-reality audit (PRA-P2-19): the parent app never surfaces driver name or contact. Parents want to know who is driving their child; it is a baseline safety expectation and competitors provide it. Contact must be masked or proxied per BUS-012 — a driver's personal number should not be broadcast to hundreds of parents.
- **Current implementation:** Not surfaced at all.
- **Target implementation:** Driver name, photo, and vehicle shown to parents of children on that trip only; contact via a masked or proxied channel, or routed to the transport office, per the school's configured policy.
- **Done when:** A parent sees today's actual driver (including a substitute) and can make contact through the approved channel without personal numbers being exposed.

---

### BUS-099 — Parent "not travelling today"
**P2** · **2 d** · **Not Started** · **Deps:** BUS-097, BUS-069 · **Audit:** §8 nice-to-haves

- **Description:** Parent marks their child as not travelling for a given trip.
- **Why it matters:** The driver otherwise waits at a stop for a child who is not coming, delaying every subsequent stop and every other family on the route. Small feature, disproportionate operational value, and it visibly gives parents agency.
- **Current implementation:** None.
- **Target implementation:** Parent marks non-travel per date and shift with a cut-off time; the driver's manifest reflects it live; the boarding record is pre-marked; the child is excluded from no-show escalation (BUS-118).
- **Done when:** A parent marks non-travel and the driver's manifest updates before departure; no false no-show alert is raised.

---

### BUS-100 — Parent data-minimisation verification
**P0** · **1.5 d** · **Not Started** · **Deps:** BUS-096, BUS-097 · **Audit:** §1.9, §8 Critical #3

- **Description:** Adversarial verification that no parent-facing response contains data about any child other than their own.
- **Why it matters:** The audit found the original parent path would have shipped other children's names, admission numbers, class, bus number and **pickup stop locations** to every parent. That must be proven impossible, not assumed fixed — and proven by inspecting payloads, not by reading UI.
- **Current implementation:** Client-side filtering over a school-wide payload.
- **Target implementation:** Automated payload inspection across every parent transport endpoint asserting single-child scope; a manual adversarial review; findings recorded in the certification evidence.
- **Done when:** Every parent transport response is proven single-child by automated assertion, and the adversarial review is signed off.

---

**PHASE 12 EXIT GATE:** Parents see their own child's bus live with an honest ETA; zero cross-child data in any payload; verified by real parent logins against the live backend.

---

# PHASE 13 — STUDENT EXPERIENCE

---

### BUS-101 — Student transport view
**P2** · **2 d** · **Not Started** · **Deps:** BUS-095, BUS-013 · **Audit:** §13 (verification chain), role model

- **Description:** Age-appropriate read-only transport view for the student.
- **Why it matters:** The completion rule requires every feature to be verified through to the **Student**. Today `ErpRole.student` holds an **empty permission set** (`role_permissions.dart:662`), so no student-facing transport surface is reachable at all. Older students in particular benefit from knowing their bus, stop and time.
- **Current implementation:** No student transport surface; no student permissions.
- **Target implementation:** Read-only view of the student's own route, stop, scheduled times, bus and driver. Live position only where school policy permits — configurable, defaulting to off. Never shows other students.
- **Done when:** A student logs in and sees their own transport details; the live-position policy toggle is respected; no other student's data is reachable.

---

# PHASE 14 — BOARDING & TRANSPORT ATTENDANCE

**Goal:** know which child boarded which bus, where, when, and on what date — permanently.
**Exit criteria:** "was my child on the bus last Tuesday?" is answerable.

---

### BUS-102 — Boarding event capture model
**P0** · **2 d** · **Not Started** · **Deps:** BUS-026, BUS-072 · **Audit:** §1.7, §8 Critical #5

- **Description:** Replace string-keyed, dateless transport attendance with trip-scoped, student-linked boarding events.
- **Why it matters:** Current records carry `studentName` as a **display string with no student id and no date**, and re-recording overwrites in place. They cannot be attributed to a child, cannot be joined to SIS, break for duplicate names, and cannot store history. This is a child-safety record that currently cannot answer the one question that matters.
- **Current implementation:** `handleRecordAttendance` at `transport_write_handlers.ts:136-165`.
- **Target implementation:** Events written against `transport_boarding` with `trip_id`, `student_id`, `stop_id`, event type, timestamp, recorder, and source. Full history; corrections as separate audited adjustments.
- **Done when:** A boarding event is attributable to a specific child on a specific trip and date; historical queries across dates return correct results.

---

### BUS-103 — Driver boarding capture UI
**P0** · **2.5 d** · **Not Started** · **Deps:** BUS-102, BUS-067 · **Audit:** §1.7

- **Description:** Fast, one-tap boarding marking on the driver/attendant app, at each stop.
- **Why it matters:** Marking is currently done by a transport admin sitting in an office, tapping through a dialog — nobody is on the bus. The person who can actually observe boarding must be the person recording it, in seconds, while managing children.
- **Current implementation:** Admin-side dialog at `transport_workflow_actions.dart:120-185`.
- **Target implementation:** Stop-scoped list with one-tap boarded/absent, bulk "all boarded", running counts, offline queueing (BUS-080), and a clear unmarked-children warning before departing a stop.
- **Done when:** A driver marks a full stop in under 15 seconds, offline, with the marks syncing correctly on reconnect.

---

### BUS-104 — Geofence-based automatic stop events
**P1** · **3 d** · **Not Started** · **Deps:** BUS-081, BUS-019 · **Audit:** §1.11

- **Description:** Automatic arrival and departure events when a bus enters or leaves a stop geofence.
- **Why it matters:** Removes driver workload, makes arrival times objective rather than self-reported, and drives approaching-alerts (BUS-109) and adherence (BUS-093). Requires stop coordinates (BUS-037) and a geofence radius — impossible until those exist.
- **Current implementation:** Geofencing exists only in `staff_attendance`; transport has none.
- **Target implementation:** Server-side geofence evaluation on ingest with hysteresis and dwell thresholds to prevent flapping; arrival/departure events on the trip; per-stop radius tuning; reuse of the staff-attendance geofence primitives.
- **Done when:** A bus passing through a stop generates exactly one arrival and one departure event; a bus idling near a stop does not flap.

---

### BUS-105 — Transport ↔ SIS attendance reconciliation
**P1** · **2.5 d** · **Not Started** · **Deps:** BUS-102 · **Audit:** §1.10

- **Description:** Connect boarding facts to school attendance with an explicit, reviewable reconciliation.
- **Why it matters:** "Child boarded the bus" and "child was present in class" are currently unconnected facts with no join key. Reconciling them catches the highest-severity scenario in school transport: a child who boarded the bus but never reached class. This must be a **reviewable signal, not an automatic attendance write** — transport evidence should inform, never silently overwrite, the academic record.
- **Current implementation:** No linkage of any kind.
- **Target implementation:** Reconciliation report flagging boarded-but-absent and absent-but-boarded cases for the school office each morning, with a one-click escalation. Configurable per school. Never auto-marks class attendance.
- **Done when:** A boarded-but-absent case is flagged within the school's configured window and can be escalated; academic attendance is never mutated by transport.

---

### BUS-106 — Transport attendance history & reports
**P1** · **2 d** · **Not Started** · **Deps:** BUS-102 · **Audit:** §1.7

- **Description:** Historical boarding queries and reports by student, stop, route, trip, and date range.
- **Why it matters:** History is what makes the record evidentiary. It is also what parents and schools ask for after any incident, and what regulators or insurers may request.
- **Current implementation:** Impossible — no date dimension exists.
- **Target implementation:** Per-student boarding history; per-route daily summaries; exception reports (frequent no-shows, chronically unmarked stops); CSV/PDF export reusing the existing export service.
- **Done when:** A specific child's boarding record for an arbitrary past date is retrievable and exportable in under 5 seconds.

---

**PHASE 14 EXIT GATE:** Boarding attributable to a child, a stop, a trip and a date; geofence events reliable; reconciliation live; history queryable.

---

# PHASE 15 — NOTIFICATIONS

**Goal:** the right parent hears the right thing at the right time, and nobody else hears anything.
**Exit criteria:** zero mis-targeted transport notifications; every send reconciled against its audit record.

---

### BUS-107 — Route-cohort targeting infrastructure
**P0** · **2 d** · **Not Started** · **Deps:** BUS-023, BUS-024 · **Audit:** §1.12, §8 Critical #6

- **Description:** A reusable capability to resolve and address the exact guardian cohort for a route, trip, or stop.
- **Why it matters:** The permanent fix behind BUS-002's interim patch. Every transport notification depends on precise cohort resolution; without it, the safe default is broadcasting to everyone, which is exactly the current failure.
- **Current implementation:** `sendBroadcastMessage` with `audience: "parents"` — school-wide — while the affected cohort is computed and discarded.
- **Target implementation:** Cohort resolution by route, trip, stop, or individual student; guardian channel resolution; delivery enqueued only to resolved recipients; audit count always equal to enqueued count.
- **Done when:** A stop-level notification reaches only guardians of children at that stop, proven by delivery-record inspection.

---

### BUS-108 — Boarding & alighting notifications
**P1** · **2 d** · **Not Started** · **Deps:** BUS-107, BUS-102 · **Audit:** §1.12

- **Description:** Notify a parent when their child boards and when they alight.
- **Why it matters:** The single most-valued transport notification in this market and a competitor standard. The `parentNotified` flag exists in the data model today, is displayed in the admin table, and **nothing ever sends anything** — a UI that reports a notification state the system never produces.
- **Current implementation:** Flag stored and displayed; no sender.
- **Target implementation:** Push on boarding and alighting to that child's guardians only, with the stop and time; per-family opt-out; quiet-hours respected; delivery recorded so the `parentNotified` flag reflects reality.
- **Done when:** A boarding mark produces a notification to exactly that child's guardians within seconds, and the admin-visible flag is truthful.

---

### BUS-109 — Bus-approaching alerts
**P1** · **2.5 d** · **Not Started** · **Deps:** BUS-107, BUS-091, BUS-104 · **Audit:** §8 nice-to-haves

- **Description:** Notify a parent when the bus is a configurable number of minutes from their child's stop.
- **Why it matters:** The audit names this **the feature parents value most** once ETA is real — it is what removes the daily wait at the stop, and it is the most visible proof the tracking works. Requires a trustworthy ETA (Phase 11), which is why it sits here and not earlier.
- **Current implementation:** None.
- **Target implementation:** ETA-threshold trigger per stop, configurable per school and per family; single fire per trip per stop; suppressed when ETA confidence is low (**P-1** — never promise an arrival the system cannot predict).
- **Done when:** A parent receives one accurate approaching alert per trip; low-confidence trips send nothing rather than something wrong.

---

### BUS-110 — Delay, diversion & breakdown alerts
**P1** · **2 d** · **Not Started** · **Deps:** BUS-107, BUS-093, BUS-075 · **Audit:** §1.12

- **Description:** Automatic notification on significant delay, diversion, or breakdown — plus the corrected manual delay notice.
- **Why it matters:** Replaces BUS-002's interim fix with automatic, correctly-targeted alerts driven by detected conditions rather than an admin noticing and typing.
- **Current implementation:** Manual only, mis-targeted school-wide.
- **Target implementation:** Threshold-triggered delay alerts to the route cohort; diversion alerts to affected stops only; breakdown alerts with the school's action; manual override retained for the transport office.
- **Done when:** A delayed trip notifies only its own cohort automatically; a diversion notifies only the affected stops.

---

### BUS-111 — Notification preferences & fatigue controls
**P1** · **2 d** · **Not Started** · **Deps:** BUS-108, BUS-109, BUS-110 · **Audit:** §1.12

- **Description:** Per-family control over which transport notifications they receive, with system-level rate limiting.
- **Why it matters:** The audit's warning is that alert fatigue makes parents mute the app entirely — which also mutes fee reminders and exam notices. Transport is the highest-volume notification source in the product, so it is where fatigue controls must be strongest. Protecting the channel protects every other module.
- **Current implementation:** None; every parent receives everything.
- **Target implementation:** Per-category opt-in/out; quiet hours; per-trip caps; deduplication of related events; school-level defaults with family override.
- **Done when:** A family receives only their chosen categories; no trip can generate more than the configured maximum notifications.

---

### BUS-112 — Notification delivery audit & reconciliation
**P1** · **1.5 d** · **Not Started** · **Deps:** BUS-107 · **Audit:** §1.12

- **Description:** Every transport notification records intended recipients, actual deliveries, and failures — reconciled.
- **Why it matters:** The current endpoint audits a recipient count that **does not match what it sent**. When a parent says "I was never told the bus broke down", the school needs an authoritative answer. An audit trail that can be wrong is worse than none.
- **Current implementation:** `recipientCount` audited from the filtered cohort while a school-wide broadcast is dispatched.
- **Target implementation:** Per-notification delivery records with status; reconciliation report; admin-visible delivery detail per event; alerting when intended and actual diverge.
- **Done when:** For any transport notification an admin can see exactly who was intended, who received it, and who failed — and the counts reconcile.

---

**PHASE 15 EXIT GATE:** All transport notifications precisely targeted, preference-controlled, rate-limited, and fully reconciled.

---

# PHASE 16 — SAFETY & SOS

**Goal:** the module behaves correctly when something goes wrong. This is where a school transport product earns its licence to operate.
**Exit criteria:** an emergency raised on a bus reaches the right people with the right context, immediately.

---

### BUS-113 — Driver SOS
**P0** · **2.5 d** · **Not Started** · **Deps:** BUS-064, BUS-027 · **Audit:** §8 nice-to-haves

- **Description:** One-touch emergency alert from the driver/attendant app with location and trip context.
- **Why it matters:** Grep for `sos|panic|emergency` across the transport module returns **zero**. A product that tracks children on public roads and has no emergency path is incomplete in the dimension that matters most. Competitors ship this.
- **Current implementation:** Absent.
- **Target implementation:** Prominent, accidental-press-guarded SOS raising an incident with live location, trip, vehicle, driver, and onboard student list; immediate alert to configured school responders; escalation if unacknowledged; audible confirmation to the driver that the alert was sent.
- **Done when:** SOS reaches school responders within seconds with full context and is acknowledged in the system; the driver receives confirmation.

---

### BUS-114 — Admin emergency console
**P0** · **2.5 d** · **Not Started** · **Deps:** BUS-113, BUS-087 · **Audit:** §8 nice-to-haves

- **Description:** A focused console for handling an active incident.
- **Why it matters:** A raised alarm nobody can act on is not a safety feature. In an emergency the responder needs one screen with everything and no navigation.
- **Current implementation:** None.
- **Target implementation:** Active-incident view with live position, onboard manifest with guardian contacts, driver and vehicle details, acknowledgement and assignment, one-click notification to affected guardians, and a full action log.
- **Done when:** A responder handles a simulated incident end-to-end from one screen, with every action logged.

---

### BUS-115 — Speed-limit violation detection
**P1** · **2 d** · **Not Started** · **Deps:** BUS-081, BUS-027 · **Audit:** §8 nice-to-haves

- **Description:** Detect and record over-speed events during a trip.
- **Why it matters:** Speed is the risk factor parents and schools care most about, and it is measurable from data we will already have. A recorded, reviewable history changes driver behaviour.
- **Current implementation:** None. (Seed data displays a `speedKph` field with no source.)
- **Target implementation:** Configurable school speed threshold with sustained-duration qualification to avoid GPS-noise false positives; incidents recorded; per-driver reporting; optional immediate admin alert.
- **Done when:** A sustained over-speed on a test route is recorded once with correct location and duration; transient GPS noise does not trigger it.

---

### BUS-116 — Harsh-driving & idle detection
**P2** · **2.5 d** · **Not Started** · **Deps:** BUS-115 · **Audit:** §8 nice-to-haves

- **Description:** Detect harsh acceleration, harsh braking, and excessive idling.
- **Why it matters:** Rounds out driver-behaviour scoring, which is a competitive differentiator and a genuine safety input. Deliberately P2 — detection quality from phone GPS alone is limited and must not produce false accusations against a driver.
- **Current implementation:** None.
- **Target implementation:** Derived from position and, where available, device motion sensors; conservative thresholds tuned to minimise false positives; aggregated into a driver behaviour report; never surfaced as a punitive score without review.
- **Done when:** Detection runs with a documented false-positive rate below an agreed threshold on pilot data.

---

### BUS-117 — Trip replay
**P2** · **2.5 d** · **Not Started** · **Deps:** BUS-025, BUS-087 · **Audit:** §8 nice-to-haves

- **Description:** Replay a completed trip's path with events on a timeline.
- **Why it matters:** The investigative tool. When a parent disputes what happened, replay is the evidence — and it is the fastest way to resolve a complaint fairly.
- **Current implementation:** Impossible — no positions stored.
- **Target implementation:** Timeline scrubber over the trip path with stop arrivals, boarding events, incidents and speed overlaid; exportable for an investigation.
- **Done when:** A completed trip replays accurately with all events correctly positioned in time and space.

---

### BUS-118 — Child no-show & safety escalation
**P1** · **2 d** · **Not Started** · **Deps:** BUS-103, BUS-107, BUS-099 · **Audit:** §1.7, §1.10

- **Description:** Structured escalation when an expected child does not board, or a boarded child does not alight.
- **Why it matters:** The highest-severity operational scenario in school transport. Today it is invisible — there is no student-linked boarding record to detect it from. Must be tuned carefully to avoid alarming parents whose child simply travelled by car (mitigated by BUS-099).
- **Current implementation:** None.
- **Target implementation:** Configurable rules — expected but not boarded, boarded but not alighted at the expected stop — with graduated escalation from driver prompt to office notification to guardian contact, each step logged. Suppressed for pre-marked non-travel.
- **Done when:** A simulated no-show escalates correctly through every step; a pre-marked non-travelling child triggers nothing.

---

**PHASE 16 EXIT GATE:** SOS verified end-to-end; emergency console usable under pressure; escalation rules tuned against pilot data with an acceptable false-positive rate.

---

# PHASE 17 — ADMIN EXPERIENCE & ONBOARDING

**Goal:** a school can set the module up correctly, unaided, in one sitting.
**Exit criteria:** time-to-first-tracked-bus is measured in hours, not never.

---

### BUS-119 — Transport setup wizard & completeness meter
**P1** · **3 d** · **Not Started** · **Deps:** Phases 3–6 · **Audit:** §6

- **Description:** Guided onboarding with a persistent, itemised completeness indicator.
- **Why it matters:** The audit's central setup finding: an admin can spend two hours entering data and end with a configuration that can never be tracked, with **nothing on screen indicating incompleteness**. Making the gap visible is as important as closing it.
- **Current implementation:** No wizard, no progress indication, no validation.
- **Target implementation:** Step-by-step wizard (vehicles → drivers → stops → routes → assignments → allocations → go live) with import at each step, and a persistent meter such as *"Route 12: ✅ 8 stops · ⚠️ no bus assigned · ❌ no driver · ⚠️ 3 stops missing location"*. Resumable; never blocks an experienced admin from working directly.
- **Done when:** A new school reaches a tracked first trip in a single sitting; the meter accurately reflects every outstanding item.

---

### BUS-120 — Live transport dashboard
**P1** · **2.5 d** · **Not Started** · **Deps:** BUS-004, BUS-087, BUS-093 · **Audit:** §7, §1.2

- **Description:** Operational dashboard computed entirely from live data.
- **Why it matters:** Completes BUS-004 by giving the dashboard real content instead of honest emptiness. This is the principal's daily view and the module's showcase surface.
- **Current implementation:** Frozen seeded snapshot; empty for real schools.
- **Target implementation:** Live active-trip count, on-time performance, delayed trips, students boarded, unstaffed routes, integrity warnings, expiring documents, and open incidents — each traceable to its source record and clicking through to it.
- **Done when:** Every dashboard number is traceable to a live query and matches independent verification; no value derives from a seed.

---

### BUS-121 — Fuel & maintenance logs
**P2** · **3 d** · **Not Started** · **Deps:** BUS-017 · **Audit:** §7, §8 nice-to-haves

- **Description:** Per-vehicle fuel and maintenance records with cost tracking.
- **Why it matters:** Restores the fuel KPI removed in BUS-005 with a real data source, and gives transport managers the operating-cost view they actually run the fleet on. Must integrate through the Finance boundary — Transport records the expense; Finance owns the money.
- **Current implementation:** A fabricated dashboard KPI labelled "placeholder" in its own seed data.
- **Target implementation:** Fuel entries (date, vehicle, quantity, cost, odometer), maintenance records with schedules and reminders, per-vehicle and per-route cost reporting, and Finance integration respecting the existing module boundary.
- **Done when:** Fuel cost on the dashboard is computed from actual logged entries and reconciles with Finance.

---

### BUS-122 — Route optimisation suggestions
**P2** · **4 d** · **Not Started** · **Deps:** BUS-090, BUS-092 · **Audit:** §8 nice-to-haves

- **Description:** Suggest stop reordering, route splits, and merges based on observed data.
- **Why it matters:** A genuine differentiator once historical data exists, and the honest version of the fabricated "consider stop reorder" insight currently seeded into the dashboard. Advisory only — the school always decides.
- **Current implementation:** A hardcoded fake AI insight string in the seed data.
- **Target implementation:** Analysis of actual travel times, occupancy and detours producing ranked, explained suggestions with projected impact. Never auto-applied.
- **Done when:** Suggestions are generated from real pilot data with a stated rationale and projected saving, and applying one is an explicit admin action.

---

# PHASE 18 — REPORTING & ANALYTICS

---

### BUS-123 — On-time performance reporting
**P1** · **2 d** · **Not Started** · **Deps:** BUS-093 · **Audit:** §7

- **Description:** Real punctuality reporting by route, driver, stop, and period.
- **Why it matters:** Replaces the seeded "94% On-Time" fiction with a computed figure. This is the number a school quotes to parents, so it must be defensible.
- **Current implementation:** Static seeded trend arrays in the reports snapshot.
- **Target implementation:** Adherence computed from trip and stop-arrival data; trends over time; per-driver and per-route breakdowns; export via the existing service.
- **Done when:** Reported on-time percentage is independently reproducible from raw trip data.

---

### BUS-124 — Utilisation & occupancy reporting
**P1** · **1.5 d** · **Not Started** · **Deps:** BUS-044, BUS-102 · **Audit:** §7

- **Description:** Seat utilisation from real capacity and real boarding data.
- **Why it matters:** Drives fleet-sizing and route-consolidation decisions — the highest-value commercial insight transport data offers a school. Currently seeded fiction.
- **Current implementation:** Static `snapshot_occupancy` document.
- **Target implementation:** Allocated vs capacity vs actually-boarded, per route and trip, with trends and under/over-utilisation flags.
- **Done when:** Utilisation matches manual verification on a pilot route across a week.

---

### BUS-125 — Compliance reporting
**P1** · **1.5 d** · **Not Started** · **Deps:** BUS-054 · **Audit:** §5 (strength to extend)

- **Description:** Fleet-wide compliance status for vehicle and driver documents.
- **Why it matters:** Extends an existing strength into an inspection-ready artefact. When a transport authority asks, the school produces one report.
- **Current implementation:** Expiry scan and staff digest exist; no report.
- **Target implementation:** Current status across all vehicles and drivers, expiring-soon and expired views, historical compliance record, and export.
- **Done when:** A school produces a complete fleet compliance report in one action.

---

# PHASE 19 — SCALE & PERFORMANCE

---

### BUS-126 — Load testing at 10 / 100 / 1000 buses
**P0** · **3 d** · **Not Started** · **Deps:** Phase 9, Phase 12 · **Audit:** §7

- **Description:** Validate the system at each scale tier the audit assessed.
- **Why it matters:** The audit rated the current architecture ❌ at 100 buses and ❌ at 1,000. The redesign must be **proven** at those tiers, not assumed. 1,000 buses implies ~2.16M position writes/day plus concurrent parent reads.
- **Current implementation:** Never load-tested.
- **Target implementation:** Reproducible harness simulating 10, 100 and 1,000 concurrent buses with realistic ping and parent-poll patterns; documented latency, throughput and resource results per tier; identified bottlenecks resolved and re-tested.
- **Done when:** All three tiers meet documented targets, with results recorded in the certification evidence.

---

### BUS-127 — Ingest throughput & cost model
**P0** · **1.5 d** · **Not Started** · **Deps:** BUS-126 · **Audit:** §4, §7

- **Description:** Document actual infrastructure cost per bus per month and validate the map-cost projection.
- **Why it matters:** The commercial case rests on the audit's claim that live tracking is near-free in map fees and modest in infrastructure. That must be measured before it is quoted to a customer, and it is the number that determines module pricing.
- **Current implementation:** No cost model.
- **Target implementation:** Measured per-bus infrastructure cost (ingest, storage, hot store, egress), measured map-vendor spend, and a forecast at 10/100/1000 buses and 1/10/100 schools, with a stated break-even.
- **Done when:** The cost model is validated against a month of real pilot billing and approved as the pricing input.

---

### BUS-128 — Multi-school scale validation
**P1** · **2 d** · **Not Started** · **Deps:** BUS-126, BUS-028 · **Audit:** §7 (strength to preserve)

- **Description:** Verify tenant isolation and performance with many schools operating concurrently.
- **Why it matters:** Multi-tenancy is the one part of the current module the audit rated solid — composite keys, forced RLS, matching policies, per-connection tenant context, isolation probes. The new schema must preserve that standard exactly, under concurrent multi-school load.
- **Current implementation:** Isolation verified on the old schema only.
- **Target implementation:** Concurrent multi-school load test with isolation probes on every new table; no cross-tenant leakage; no per-school performance degradation from neighbours.
- **Done when:** Isolation probes pass under load and no cross-tenant data is observable in any response.

---

### BUS-129 — Query plan & N+1 elimination audit
**P1** · **2 d** · **Not Started** · **Deps:** BUS-032, BUS-126 · **Audit:** §7

- **Description:** Systematic review of every transport query path for unbounded fetches and N+1 patterns.
- **Why it matters:** The old module's defining performance flaw was loading entire collections into application memory per request. A structured sweep prevents the same pattern reappearing in the new code, where it would be harder to spot.
- **Current implementation:** `findAll` scans throughout.
- **Target implementation:** Every path reviewed with a captured plan; no sequential scan on a large table; no N+1; results recorded, with a regression test guarding the highest-traffic paths.
- **Done when:** The audit is documented with plan evidence per path and guard tests are in CI.

---

# PHASE 20 — PRODUCTION VALIDATION & CERTIFICATION

**Goal:** prove the module works, in the field, with real people — then certify it.
**Exit criteria:** live certification passed; module declared production-grade.

---

### BUS-130 — Full-chain end-to-end certification
**P0** · **3 d** · **Not Started** · **Deps:** all prior · **Audit:** §0.3 completion rule

- **Description:** Execute the complete chain — Transport Admin → Driver → Backend → Parent → Student — as a certified scenario against the live environment.
- **Why it matters:** This roadmap's core rule made final. The audit's defining failure was a module whose parts were individually tested and never connected. Certification must exercise the connections, with real accounts and real data.
- **Current implementation:** No chain test exists.
- **Target implementation:** Certified scenario covering setup, assignment, substitution, trip start, live tracking, boarding, notification, parent view, student view, trip end, and history — run against the live backend with real credentials and recorded evidence.
- **Done when:** The full chain passes on the live environment with evidence captured per hop, per the project's certification standard.

---

### BUS-131 — Security & privacy review
**P0** · **2.5 d** · **Not Started** · **Deps:** BUS-100, BUS-028 · **Audit:** §1.9, §8 Critical #3

- **Description:** Independent adversarial security and privacy review of the whole module.
- **Why it matters:** The module handles children's location data. The original design would have leaked other children's names and pickup locations to any parent. That class of defect must be actively hunted before a real school's data is at stake, not assumed absent.
- **Current implementation:** Never reviewed as a whole.
- **Target implementation:** Adversarial review covering authorization on every endpoint, RLS bypass attempts, cross-tenant and cross-child access, driver scope escalation, position-data exposure, retention compliance, and PII in logs. Findings triaged and closed.
- **Done when:** Review complete, every P0/P1 finding closed and re-verified.

---

### BUS-132 — Field pilot
**P0** · **10 d (elapsed)** · **Not Started** · **Deps:** BUS-130 · **Audit:** §3, §5

- **Description:** Run the module on a real bus, with a real driver, real children, and real parents, for a minimum of two full school weeks.
- **Why it matters:** Everything about this module fails or succeeds in the field, not the lab: OEM battery managers, dead zones, drivers who forget to start the trip, parents who misread an ETA, stops in the wrong place. The audit is explicit that this is where competitor implementations die. No amount of testing substitutes for two weeks on a real route.
- **Current implementation:** Never piloted.
- **Target implementation:** Two weeks minimum on ≥2 routes with ≥2 drivers (including one substitution event), monitored daily. Structured feedback from driver, transport admin, and parents. Every gap logged and triaged.
- **Done when:** Two weeks complete with tracking uptime above target, no P0 field defects open, and documented feedback from all three actor groups.

---

### BUS-133 — EOS gate & live certification
**P0** · **2 d** · **Not Started** · **Deps:** BUS-131, BUS-132 · **Audit:** project standard

- **Description:** Run the mandatory EOS gate against the full module scope and produce the live certification document.
- **Why it matters:** Project law (`CLAUDE.md`, Engineering Constitution). The module cannot be declared complete on any other basis, and the audit's opening verdict was **EOS gate: BLOCKED**. This task is where that verdict is formally overturned with evidence.
- **Current implementation:** Gate BLOCKED at audit time.
- **Target implementation:** Full EOS evaluation against the Constitution; live certification per the `certify` standard, run against the deployed bundle with real auth, real DB, real RBAC; `docs/TRANSPORT_BUS_TRACKING_CERTIFICATION.md` produced.
- **Done when:** EOS returns PASS or CONDITIONAL PASS with tracked P1s; the certification document is written and accepted.

---

### BUS-134 — Documentation & operational runbooks
**P1** · **2.5 d** · **Not Started** · **Deps:** BUS-133 · **Audit:** §6

- **Description:** Complete documentation for schools, drivers, support, and engineers.
- **Why it matters:** A module a school cannot operate without calling support is not shipped. Driver documentation in particular must be usable by someone who is not a software user.
- **Current implementation:** None.
- **Target implementation:** School setup guide; driver quick-start (including per-OEM battery setup); transport admin manual; support runbook for common failures (driver not tracking, parent sees nothing, stale position); engineering operations runbook (partitions, hot store, routing service, map keys); troubleshooting decision tree.
- **Done when:** A school completes setup using documentation alone; support resolves each catalogued failure mode from the runbook.

---

### BUS-135 — Competitive parity verification
**P1** · **1.5 d** · **Not Started** · **Deps:** BUS-132 · **Audit:** §5

- **Description:** Re-score the module against the audit's competitive matrix and confirm parity or advantage on every dimension.
- **Why it matters:** Closes the loop on the audit's competitive finding. The starting scores were Live tracking 0/10, Driver experience 0/10, Offline 0/10, Parent experience 1/10, Safety 1/10, Notifications 2/10, Route creation 2/10 — every one below every competitor. Parity must be verified, not assumed, and the strengths (fee integration, compliance, audit trail, RBAC, honesty) must be confirmed intact.
- **Current implementation:** Composite 4.1/10.
- **Target implementation:** Re-scored matrix across all 11 dimensions with evidence per score; a written statement of where we lead, match, and still trail; residual gaps entered as new tasks.
- **Done when:** Re-scored with evidence; no dimension below competitor baseline; the module's differentiators are documented for sales.

---

**PHASE 20 EXIT GATE — MODULE COMPLETE:** Full chain certified · security review closed · two-week field pilot passed · EOS PASS · documentation delivered · competitive parity verified.

---

# APPENDIX A — COMPLETE AUDIT FINDINGS REGISTER

Every finding from the 2026-07-29 audit, preserved verbatim in substance, with its owning task. **No finding exists only in the audit.**

## A.1 — Critical issues (audit §8)

| # | Finding | Task |
|---|---|---|
| 1 | Fabricated ETA ("8 minutes away") shown to parents as a compile-time constant | BUS-001 |
| 2 | No way to assign a vehicle or driver to a route; kills capacity guard and both delete guards | BUS-043, BUS-044, BUS-045, BUS-048, BUS-049 |
| 3 | Parent transport read broken three ways: 403 in live build; would leak other children's data; page-1-of-20 truncation | BUS-003, BUS-059, BUS-095, BUS-100 |
| 4 | Stops have no coordinates — structurally blocks tracking, geofencing, ETA, route rendering | BUS-019, BUS-037 |
| 5 | Transport attendance has no student ID and no date | BUS-026, BUS-102 |
| 6 | Delay notifications go to every parent in the school while reporting a filtered count | BUS-002, BUS-107, BUS-112 |
| 7 | Routes cannot be edited or deleted | BUS-033, BUS-034 |
| 8 | Stop times silently don't save (`pickupTime` vs `scheduledTime`); editing a stop erases its drop time | BUS-006, BUS-007, BUS-038 |
| 9 | Dashboard KPIs are frozen seed data; fuel KPI is a labelled placeholder rendered as real | BUS-004, BUS-005, BUS-120, BUS-121 |

## A.2 — Part 1: current implementation

| Finding | Task |
|---|---|
| All transport in one JSONB `transport_entities` table; no relational schema | BUS-016 … BUS-032 |
| No GPS ingest endpoint anywhere in the 30-route API | BUS-081 |
| `GET /transport/tracking` returns a static seeded fixture | BUS-009, BUS-087 |
| Zero map/location dependencies on any platform | BUS-086 |
| No route geometry; nothing to render | BUS-041 |
| Stop write path accepts only `{id, name, pickupTime, dropTime}` | BUS-019, BUS-037 |
| Stops default to 0°N 0°E (Atlantic Ocean) | BUS-019, BUS-030, BUS-037 |
| No ETA engine of any kind | BUS-090, BUS-091 |
| "Refresh ETA" label with null `onAction` — never renders | BUS-001 |
| Transport attendance keyed by `studentName` display string | BUS-102 |
| Attendance re-record overwrites in place; no history | BUS-026, BUS-073, BUS-106 |
| Attendance marked manually by an office admin, not on the bus | BUS-103 |
| No driver role; `UserRole` = {parent, teacher, student, staff} | BUS-013, BUS-062 |
| Drivers cannot log in; no driver app | BUS-063, BUS-064 |
| No route→driver assignment | BUS-048 |
| Parent path requires `viewTransport` + school scope; parent has neither | BUS-095 |
| Parent fetch would return school-wide roster (names, admission numbers, class, stops) | BUS-059, BUS-100 |
| Parent fetch reads page 1, size 20 only | BUS-059 |
| No transport↔SIS attendance linkage | BUS-105 |
| Geofencing exists only in `staff_attendance` | BUS-104 |
| Staff-attendance anti-mock logic is a reusable asset | BUS-082 |
| `notify-delay` computes cohort then broadcasts school-wide | BUS-002, BUS-107 |
| `parentNotified` flag stored and displayed; nothing ever sends | BUS-108 |
| No pickup/drop, approaching, arrived, breakdown or SOS notifications | BUS-108, BUS-109, BUS-110, BUS-113 |
| Document-expiry reminder is well-built (strength) | BUS-054, BUS-125 |
| Admin/web tracking screens are honestly disclosed (strength to preserve) | BUS-003, BUS-094 |

## A.3 — Part 2: route creation

| Finding | Task |
|---|---|
| `transportManager` role is a good design decision (strength) | BUS-013 |
| Principal read-only on transport (correct SoD, preserve) | BUS-013 |
| Route creation is a single "Route name" field | BUS-035 |
| distanceKm / amDeparture / pmDeparture / shift silently hardcoded | BUS-035 |
| No `PUT /transport/routes/{id}`; no `DELETE` | BUS-033, BUS-034 |
| `assignedBus` set to `""` and never written by any endpoint | BUS-043 |
| `assignedDriverId` read but never written | BUS-048 |
| Capacity guard unreachable → unlimited over-allocation | BUS-044 |
| Vehicle-in-use delete guard unreachable | BUS-045 |
| Driver-in-use delete guard unreachable | BUS-049 |
| Stops stored as an embedded JSON array | BUS-019, BUS-021, BUS-036 |
| Stops cannot be shared, queried, indexed, or FK-referenced | BUS-036, BUS-040 |
| Every stop mutation rewrites the whole route document | BUS-021, BUS-032 |
| Stop times are unvalidated free text | BUS-038 |
| `pickupTime` written / `scheduledTime` read | BUS-006, BUS-038 |
| Stop edit dialog discards existing `dropTime` | BUS-007 |
| Text controllers never disposed | BUS-007 |
| Allocation pickup/drop stops are free-text fields | BUS-055 |
| Roster groups by exact string match; `"(unassigned stop)"` bucket | BUS-055, BUS-058 |
| Bulk allocation is the best-engineered handler (preserve) | BUS-060 |
| Student can be double-allocated to two routes | BUS-056 |
| AM/PM dual-route case not properly supported | BUS-040, BUS-056 |
| No trip, substitute bus, substitute driver, diversion or holiday concept | BUS-024, BUS-046, BUS-051, BUS-074, BUS-075 |
| Row-locked resequencing is well-implemented (preserve) | BUS-039 |

## A.4 — Part 3: live tracking

| Finding | Task |
|---|---|
| No GPS source, refresh, offline, accuracy or background handling | BUS-076 … BUS-085 |
| Android background execution / OEM kill is the real-world failure mode | BUS-077, BUS-078 |
| Store-and-forward required for dead zones | BUS-080 |
| Mock-location spoofing must be detected | BUS-082 |
| Battery strategy required (30–50% drain at naive settings) | BUS-079 |
| Privacy boundary must be designed in, not retrofitted | BUS-012, BUS-100 |
| No background-execution plugin, foreground service, or iOS entitlement | BUS-077 |
| Platform has unused sqflite/connectivity_plus offline infrastructure | BUS-068, BUS-080 |

## A.5 — Part 4: map provider & cost

| Finding | Task |
|---|---|
| No map provider integrated on any platform | BUS-086 |
| Mobile SDK map loads are free; routing APIs are what cost money | BUS-088 |
| Per-ping Directions calls would cost ~$70k/yr at 100 buses | BUS-088 |
| Logistics companies run in-house routing over OSM | BUS-090 |
| In-house ETA from own history is more accurate than a generic API | BUS-092 |
| Geocode once and cache; never per view | BUS-037, BUS-088 |
| Position pings never touch the map vendor | BUS-081 |
| Recommend Google Maps SDK v1, MapLibre as v2 option | BUS-086 |
| Raw OSM tile servers prohibited for production traffic | BUS-086 |
| Support both hardware-device and driver-phone models | BUS-076, BUS-085 |
| Ingest wants a dedicated lightweight path, not a general edge function | BUS-081 |

## A.6 — Part 5: industry comparison

| Finding | Task |
|---|---|
| Live tracking 0/10 vs 5–8 for every competitor | Phases 9–12 |
| Driver experience 0/10 | Phase 7 |
| Offline 0/10 | BUS-068, BUS-080 |
| Parent experience 1/10 | Phase 12 |
| Safety 1/10 | Phase 16 |
| Notifications 2/10 | Phase 15 |
| Route creation 2/10 | Phase 3 |
| Strength — Finance/fee integration with idempotency (preserve) | BUS-121, BUS-010 |
| Strength — compliance tracking with strict ISO validation (extend) | BUS-054, BUS-125 |
| Strength — audit trail incl. separate capacity-override audit (preserve) | BUS-044, BUS-112 |
| Strength — RBAC + forced RLS tenant isolation (preserve) | BUS-028, BUS-128 |
| Strength — honest disclosure on admin/web surfaces (preserve) | BUS-094 |

## A.7 — Part 6: setup experience

| Finding | Task |
|---|---|
| No CSV import; ~2 min of typing per record | BUS-061 |
| Driver records lack photo, address, police verification, medical | BUS-018 |
| Cannot assign bus or driver — setup literally cannot be completed | BUS-043, BUS-048 |
| Route timings not editable after creation | BUS-033, BUS-035 |
| Activation has zero validation | BUS-042 |
| Time-to-first-tracked-bus is infinite | BUS-119, BUS-132 |
| No setup wizard or completeness indication | BUS-119 |

## A.8 — Part 7: architecture

| Finding | Task |
|---|---|
| Transport modelled as documents; is relational + geospatial + time-series | BUS-016 … BUS-032 |
| `findAll` loads every allocation into memory per write | BUS-032 |
| Capacity check is O(all students in school) | BUS-032, BUS-044 |
| No index on any payload field | BUS-029 |
| Zero foreign keys in the module | BUS-017 … BUS-023 |
| Vehicle referenced by registration string; rename breaks link silently | BUS-047 |
| Allocations carry frozen `routeName`/`busNumber` copies | BUS-023 |
| Cannot query "allocation for student X" without full scan | BUS-029, BUS-059 |
| No time dimension anywhere | BUS-024, BUS-025, BUS-073 |
| Snapshot documents never recomputed by any code path | BUS-004, BUS-120 |
| Fails at 100 buses; not viable at 1,000 | BUS-126 |
| Multi-tenancy + forced RLS is solid (preserve) | BUS-028, BUS-128 |
| Needs PostGIS, trip entity, partitioned positions, dated assignments | BUS-016, BUS-022, BUS-024, BUS-025 |
| Needs hot last-known-position store | BUS-083 |
| `withMockWriteFallback` can silently substitute mock writes | BUS-008 |

## A.9 — Nice-to-have improvements (audit §8)

| Finding | Task |
|---|---|
| Attendant/conductor role (grep: zero) | BUS-053 |
| Driver photo, address, police verification, medical records | BUS-018 |
| Driver name + contact surfaced to parents | BUS-098 |
| SOS / panic button (grep: zero) | BUS-113, BUS-114 |
| Speed-limit violation alerts | BUS-115 |
| Harsh-driving / idle detection | BUS-116 |
| Trip replay / route history playback | BUS-117 |
| CSV import | BUS-061 |
| Fuel and maintenance logs | BUS-121 |
| Route optimisation suggestions | BUS-122 |
| Parent "not travelling today" | BUS-099 |
| Bus-approaching push (T-5 min) | BUS-109 |

## A.10 — Owner's additional production requirements

| Requirement | Tasks |
|---|---|
| **1. Driver replacement** — substitute for today without changing the permanent assignment; substitute automatically receives today's route, stops, students, and trip; on login sees only today's trip | BUS-022, BUS-050, BUS-051, BUS-052, BUS-065 |
| **2. Trip lifecycle** — login → today's trip → Start Trip → GPS auto-starts → parent tracking auto-available → End Trip → GPS auto-stops → history stored; driver never manually enables tracking | BUS-065, BUS-069, BUS-070, BUS-071, BUS-072, BUS-073, BUS-096 |
| **3. Future-proof architecture** — hardware GPS, driver phone GPS, multiple schools, temporary route changes, temporary vehicle replacement, temporary driver replacement, AM/PM routes, emergency diversion — all without redesign | BUS-011, BUS-022, BUS-028, BUS-040, BUS-046, BUS-051, BUS-075, BUS-076, BUS-085, BUS-128 |

---

# APPENDIX B — TRACEABILITY SUMMARY

| Audit source | Findings | Tasks |
|---|---|---|
| §8 Critical issues | 9 | 22 |
| Part 1 — Current implementation | 27 | 34 |
| Part 2 — Route creation | 23 | 27 |
| Part 3 — Live tracking | 8 | 12 |
| Part 4 — Map provider | 11 | 9 |
| Part 5 — Industry comparison | 12 | 18 |
| Part 6 — Setup experience | 7 | 8 |
| Part 7 — Architecture | 15 | 22 |
| §8 Nice-to-haves | 12 | 12 |
| Owner additional requirements | 3 | 21 |
| **Total** | **127 findings** | **135 tasks** |

**Coverage: 127 / 127 findings mapped. Zero findings unmapped.**

---

# APPENDIX C — EFFORT SUMMARY

| Phase | Tasks | Effort (d) |
|---|---|---|
| 0 · Stop the Bleeding | 9 | 6.75 |
| 1 · Foundation | 6 | 14 |
| 2 · Database & Domain Model | 17 | 33 |
| 3 · Route Management | 10 | 18 |
| 4 · Bus Assignment | 5 | 5.5 |
| 5 · Driver Assignment & Substitution | 7 | 11.5 |
| 6 · Student Allocation & Roster | 7 | 11.5 |
| 7 · Driver Identity & Driver App | 7 | 16 |
| 8 · Trip Lifecycle | 7 | 12.5 |
| 9 · GPS Tracking | 10 | 25.5 |
| 10 · Live Map | 4 | 8.5 |
| 11 · ETA Engine | 5 | 14 |
| 12 · Parent Tracking | 6 | 11 |
| 13 · Student Experience | 1 | 2 |
| 14 · Boarding & Attendance | 5 | 12 |
| 15 · Notifications | 6 | 11.5 |
| 16 · Safety & SOS | 6 | 14 |
| 17 · Admin Experience | 4 | 12.5 |
| 18 · Reporting | 3 | 5 |
| 19 · Scale & Performance | 4 | 8.5 |
| 20 · Production Validation | 6 | 21 |
| **Total** | **135** | **≈ 274 engineer-days** |

**Calendar estimate:** ~14–19 weeks with 3–4 engineers working the phase order, including the two-week field pilot (BUS-132), which is elapsed time and cannot be compressed by adding people.

**Minimum viable sellable milestone:** Phases 0–6 (≈ 100 d). At that point transport administration is genuinely complete and correct — routes editable, buses and drivers assignable, capacity enforced, rosters sound, parents reading their own child — with **no tracking claim made**. That is a defensible product, and it is the highest-ROI segment of this roadmap.

---

# APPENDIX D — PRIORITY SUMMARY

| Priority | Tasks | Effort (d) |
|---|---|---|
| **P0** | 71 | ≈ 158 |
| **P1** | 45 | ≈ 84 |
| **P2** | 19 | ≈ 32 |

No P1 task begins before every P0 in its phase and all prior phases is `Verified`. No P2 task begins before every P0 and P1 is `Verified`.

---

**Roadmap ends. Awaiting owner review and approval before implementation begins.**
