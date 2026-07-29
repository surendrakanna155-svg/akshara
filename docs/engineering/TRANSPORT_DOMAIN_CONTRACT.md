# TRANSPORT DOMAIN CONTRACT

**Status:** FROZEN v1.0 — 2026-07-29
**Tasks:** BUS-010 (contract SSOT) · BUS-011 (location-source abstraction) · BUS-012 (privacy & visibility model) · BUS-015 (flag & rollout plan)
**Authority:** `docs/roadmap/BUS_TRACKING_MASTER_ROADMAP.md` §1 (binding principles P-1…P-10)
**Binding on:** every task from BUS-016 onward. An implementation that contradicts this document is rejected regardless of test status.

---

## 0. WHY THIS DOCUMENT EXISTS

Every integration defect the Bus Tracking audit found traces to the absence of a contract:

| Defect | Root cause |
|---|---|
| `pickupTime` written, `scheduledTime` read (BUS-006) | No canonical field name. Both sides were internally consistent and mutually wrong. |
| Stops carry coordinates in seed data but not in the write path (BUS-037) | No entity definition. Fixture and writer diverged silently. |
| `assignedBus` read by three subsystems, written by none (BUS-043) | No ownership rule for who populates a field. |
| Capacity guard correct but never executed (BUS-044) | Unit tests stubbed the field the handler reads. Nothing tested the join. |

These are not coding mistakes. They are the predictable output of handler-by-handler development against stubs. The codebase's `str(body, "camelCase", "snake_case", "alias")` multi-key tolerance *masked* divergence rather than preventing it.

**Rule:** the names, types, and state machines below are the only permitted ones. Multi-key input tolerance is forbidden for new endpoints. Read-side legacy fallbacks are permitted only where explicitly listed in §9.

---

## 1. ENTITY MODEL

```
                    ┌──────────────────┐
                    │ transport_stop   │  location GEOGRAPHY(POINT,4326)
                    │  (school-owned)  │  geofence_radius_m
                    └────────┬─────────┘
                             │ M:N via route_stop
                    ┌────────┴─────────┐
   ┌────────────────┤ transport_route  ├────────────────┐
   │                │   (TEMPLATE)     │                │
   │                └────────┬─────────┘                │
   │                         │                          │
   │  transport_allocation   │  transport_assignment    │  transport_trip
   │  student ↔ route ↔ stop │  DATED: route ↔ vehicle  │  ONE SERVICE DATE
   │  (per shift)            │         ↔ driver         │  (INSTANCE)
   │                         │         ↔ attendant      │
   └─────────────────────────┴──────────┬───────────────┘
                                        │
              ┌─────────────────────────┼─────────────────────────┐
              │                         │                         │
      transport_position        transport_boarding        transport_incident
      (partitioned by date)     (student ↔ trip ↔ stop)   (SOS/speed/geofence)
```

### 1.1 The two structural rules

**Route is a TEMPLATE. Trip is an INSTANCE.** (P-4)
Nothing about a day's running attaches to the route. A route has no vehicle, no driver, no status-of-today. It has a name, a direction, a shift, and an ordered stop set. Everything operational lives on the trip.

**All operational links are DATED ASSIGNMENT ROWS, never scalar fields.** (P-3)
`route.assignedBus` — the field whose absence of a writer disabled three features — does not exist in this model. Route↔vehicle↔driver↔attendant is `transport_assignment`, a row with `effective_from` / `effective_to` and an `assignment_kind`. This is what makes substitution (owner requirement 1), temporary vehicle replacement, and AM/PM duality ordinary records rather than schema changes.

### 1.2 Entity definitions

Types are Postgres types. `org` = `organization_id UUID NOT NULL`, `school` = `school_id UUID NOT NULL`; both present on every table, both in every RLS policy.

#### `transport_vehicle`
| Field | Type | Notes |
|---|---|---|
| `id` | UUID PK | Stable surrogate. **Never reference a vehicle by registration** — that string is mutable and its mutation silently orphaned links in the old model. |
| `registration` | TEXT | UNIQUE per school, normalised upper+trim. |
| `model`, `capacity` | TEXT, INT | `capacity > 0` when set. |
| `status` | ENUM | `active` \| `maintenance` \| `retired` |
| `insurance_expiry`, `fitness_expiry`, `puc_expiry`, `permit_expiry`, `road_tax_expiry` | DATE | Strict dates. **Preserve** the existing ISO validation — it is correct. |

#### `transport_driver`
| Field | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `user_id` | UUID FK → auth | Nullable until provisioned. **This link is what makes a driver able to log in** — its absence is the root cause of the entire tracking gap. |
| `name`, `phone` | TEXT | |
| `licence_number` | TEXT | UNIQUE per school. |
| `licence_expiry`, `licence_class` | DATE, TEXT | Gates assignment (BUS-054). |
| `photo_ref`, `address` | TEXT | |
| `police_verification_status`, `police_verification_expiry` | ENUM, DATE | Indian school-transport norm. |
| `medical_check_date`, `eyesight_check_date`, `blood_group` | DATE, DATE, TEXT | |
| `emergency_contact` | TEXT | |
| `status` | ENUM | `active` \| `on_leave` \| `inactive` |

#### `transport_stop`
| Field | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `name` | TEXT | |
| `location` | `GEOGRAPHY(POINT,4326)` **NOT NULL** | **The single most consequential field in the schema.** Without it there is no geofence, no distance-to-stop, no arrival detection, no ETA, no map. Creation MUST reject a missing or out-of-bounds coordinate. |
| `geofence_radius_m` | INT | Default 100. Per-stop tunable (BUS-104). |
| `address_text`, `landmark` | TEXT | Geocoded ONCE at creation and stored (P-7). Never re-geocoded on read. |
| `status` | ENUM | `active` \| `needs_location` \| `retired`. `needs_location` exists only for BUS-030 migration rows and blocks route publication. |

Stops belong to the **school**, not to a route. One physical "Green Park Gate" is shared by the AM and PM routes (BUS-040).

#### `transport_route` (template)
`id` UUID PK · `name` · `code` · `direction` ENUM(`pickup`,`drop`) · `shift` ENUM(`am`,`pm`) · `status` ENUM(`draft`,`active`,`inactive`) · `default_departure_time` TIME · `default_return_time` TIME · `distance_m` INT.

**Holds no vehicle, no driver, no derived counts.** `stopCount` / `studentCount` are computed on read.

#### `transport_route_stop`
`route_id` FK · `stop_id` FK · `sequence` INT · `scheduled_pickup_time` **TIME** · `scheduled_drop_time` **TIME** · `dwell_seconds` INT.
PK `(route_id, stop_id)`; UNIQUE `(route_id, sequence)` DEFERRABLE.

Times are **TIME, not TEXT**. Free-text times made schedule adherence, delay detection, and any ETA baseline arithmetically impossible — which is why the old module could display a hardcoded "94% On-Time" but never compute one.

#### `transport_assignment` (dated)
`id` · `route_id` FK · `vehicle_id` FK · `driver_id` FK · `attendant_id` FK NULL · `effective_from` DATE · `effective_to` DATE NULL · `assignment_kind` ENUM(`permanent`,`substitute`) · `reason` TEXT · `created_by`.

**Precedence:** for a given `(route, date)`, a `substitute` row whose range covers the date wins over any `permanent` row. Exactly one permanent assignment may be open per route (exclusion constraint on overlapping ranges where `kind = 'permanent'`). Substitutes may overlap a permanent row — that is the entire point.

#### `transport_allocation`
`id` · `student_id` FK · `route_id` FK · `pickup_stop_id` FK · `drop_stop_id` FK · `shift` ENUM(`am`,`pm`,`both`) · `effective_from` · `effective_to` NULL · `status`.

**Stops are FKs, never strings.** The old model let an admin type a stop name and grouped rosters by exact string match, so `"Green Park Gate"` / `"Green park gate"` / `"Green Park gate "` became three stops and referential integrity depended on typing accuracy.

**Constraint:** at most one active allocation per `(student_id, shift)`, with `both` conflicting against `am` and `pm`. A student may hold a distinct AM and PM route; a student may not ride two buses at once.

**No denormalized display copies.** No `routeName`, no `busNumber`.

#### `transport_trip` (instance)
`id` · `route_id` FK · `service_date` DATE · `shift` · `vehicle_id` FK · `driver_id` FK · `attendant_id` FK NULL · `assignment_id` FK · `status` · `started_at` · `ended_at` · `start_location` · `end_location` · `distance_m` · `diversion_id` NULL.
UNIQUE `(route_id, service_date, shift)`.

#### `transport_position` (time-series)
`trip_id` FK · `recorded_at` TIMESTAMPTZ · `location` GEOGRAPHY · `accuracy_m` · `speed_mps` · `heading_deg` · `source_type` · `source_id` · `integrity_flags` JSONB · `received_at`.
**Range-partitioned by `recorded_at`.** At 1,000 buses this receives ~2.16M rows/day.

#### `transport_boarding`
`id` · `trip_id` FK · `student_id` FK · `stop_id` FK · `event` ENUM(`boarded`,`alighted`,`absent`,`no_show`) · `recorded_at` · `recorded_by` · `source` ENUM(`driver`,`attendant`,`geofence`,`admin`) · `location` · `notes`.
UNIQUE `(trip_id, student_id, event)`.

**Carries a real `student_id` and is scoped to a dated trip.** The old attendance row had neither — it keyed on a display name and overwrote in place, so it could not be attributed to a child, joined to SIS, or asked about yesterday.

#### `transport_incident`
`id` · `trip_id` FK NULL · `vehicle_id` · `driver_id` · `kind` ENUM(`sos`,`breakdown`,`speed_violation`,`geofence_anomaly`,`diversion`,`no_show`) · `severity` · `location` · `occurred_at` · `reported_by` · `acknowledged_by` · `acknowledged_at` · `resolution`.

---

## 2. CANONICAL FIELD NAMES

API payloads use **lowerCamelCase**. Database columns use **snake_case**. The mapping is mechanical; no aliases.

| Concept | API | Column | Never |
|---|---|---|---|
| Stop pickup time | `pickupTime` | `scheduled_pickup_time` | ~~`scheduledTime`~~ |
| Stop drop time | `dropTime` | `scheduled_drop_time` | — |
| Vehicle identity | `vehicleId` | `vehicle_id` | ~~`assignedBus`~~, ~~registration as a link~~ |
| Driver identity | `driverId` | `driver_id` | ~~`assignedDriverId` (never written)~~ |
| Student identity | `studentId` | `student_id` | ~~`sisStudentId` as a link~~, ~~`studentName`~~ |
| Stop reference | `pickupStopId` / `dropStopId` | `pickup_stop_id` / `drop_stop_id` | ~~`pickupStop` (free text)~~ |
| Service date | `serviceDate` | `service_date` | — |
| Position timestamp | `recordedAt` | `recorded_at` | — |

**Enforcement:** BUS-014's harness asserts round-trip equality for every field. A client key the server does not write, or vice versa, fails the build.

---

## 3. STATE MACHINES

### 3.1 Trip (BUS-072)

```
   scheduled ──startTrip──▶ started ──endTrip──▶ completed  (terminal, immutable)
       │                       │
       └──cancel──▶ cancelled  └──abort──▶ aborted  (raises an incident)
```

**Invariants**
- `startTrip` requires: trip is for **today**, caller is the trip's assigned driver, status is `scheduled`.
- Position ingest is accepted **only** for `started` trips. A fix for any other status is rejected and counted.
- Boarding events are accepted only for `started` trips.
- `completed` and `aborted` are immutable. Corrections are separate audited adjustment rows referencing the original (BUS-073).
- Auto-end safeguard: a `started` trip inside the school geofence past a threshold is ended automatically and flagged `auto_ended` — never silently.

### 3.2 Tracking lifecycle (P-9, owner requirement 2)

```
driver login → today's trip appears → tap Start Trip
                                          ↓
                          GPS capture starts AUTOMATICALLY
                                          ↓
                    parent live visibility opens AUTOMATICALLY
                                          ↓
                                   tap End Trip
                                          ↓
                          GPS capture stops AUTOMATICALLY
                                          ↓
                    parent visibility closes · history written
```

**There is no tracking on/off control anywhere in the product.** Not in the driver app, not in admin settings, not behind a debug menu. BUS-070's acceptance includes a grep proving this. A separate toggle is the most common failure mode in competitor driver apps — drivers forget it and parents watch a stationary bus.

### 3.3 Assignment resolution

To answer *"who drives route R on date D?"*:
1. `substitute` assignment covering D → that driver.
2. else `permanent` assignment covering D → that driver.
3. else → **unstaffed**; surfaced on the dashboard as needing a substitute (BUS-050).

Identical logic for vehicle and attendant. A substitute driver therefore needs **no special case** in the driver app: BUS-065 resolves "today's trip" by effective assignment, so a substitute logging in at 06:45 sees the covered route exactly as the permanent driver would.

---

## 4. LOCATION-SOURCE CONTRACT (BUS-011)

**P-2: one ingest boundary; sources are interchangeable adapters.** Nothing above this boundary may branch on source type — except integrity scoring (§4.3) and the admin device registry.

### 4.1 The `LocationFix` envelope

```
{
  tripId:      uuid,          // REQUIRED. A fix not bound to a started trip is rejected.
  recordedAt:  iso8601,       // device clock, monotonic per source
  lat, lng:    number,
  accuracyM:   number,
  speedMps:    number | null,
  headingDeg:  number | null,
  sourceType:  "driver_app" | "hardware_device",
  sourceId:    string,        // device install id, or registered tracker id
  integrity:   { mockLocationDetected: bool, ... }
}
```

### 4.2 Ingest

`POST /transport/trips/{tripId}/positions` accepts a **batch** (`fixes: LocationFix[]`).

- **Batched by contract, not by preference.** One request per bus per minute carrying ~6 fixes turns a 1,000-bus fleet from ~2.16M requests/day into ~360k.
- **Idempotent and out-of-order tolerant.** Store-and-forward (BUS-080) replays buffered fixes after a dead zone; duplicates and late arrivals are normal, not errors.
- **Never blocks on downstream work.** Geofence evaluation, ETA recompute, and notification dispatch happen after the write, not inside the request.
- Authorization: the caller must own the referenced started trip.

### 4.3 Adding a source

Adding a hardware vendor touches exactly: (a) an adapter normalising the vendor payload into `LocationFix`, (b) a device-registry row binding device → vehicle with dated validity, (c) integrity scoring rules for that source class. **Nothing else.** BUS-085's acceptance is a demonstration of this.

Where both a phone and a device report for one trip, the device wins; the phone stream is retained and flagged as secondary.

---

## 5. VISIBILITY MATRIX (BUS-012)

**P-8: data minimisation is a schema and authorization property, designed in.** The audit found the original parent path would have shipped other children's names, admission numbers, class, bus number, and **pickup stop locations** to every parent — because visibility was a client-side filter over a school-wide payload. That is a child-safety failure, not merely a privacy one.

| Actor | May see | May NOT see | Window |
|---|---|---|---|
| **Transport admin / school admin** | Everything for their school | Other schools, other tenants | Always |
| **Principal** | Everything for their school, **read-only** | Write operations | Always |
| **Driver** | Today's assigned trip: route, stops, manifest (name, class, photo-if-policy, guardian contact **for exception handling only**), vehicle, attendant | Any other driver's trip · any other date · any admin surface · guardian contact outside an active trip | Trip window + preparation lead time |
| **Attendant** | Same as driver, minus trip control | Driving controls | Same |
| **Parent** | **Their own child only:** allocation, assigned stop, scheduled times, today's vehicle + driver identity, live position | **Any other child, in any form** · the route roster · other stops' students · position outside their child's active trip | Active trip window only |
| **Student** | Own route, stop, times, bus, driver | Any manifest · any other student · live position unless school policy enables it (default **off**) | Per policy |

### 5.1 Non-negotiable enforcement rules

1. **A parent-reachable endpoint never returns a list of students.** Not paginated, not filtered, not "just the route's". BUS-059 is a single-child endpoint by construction.
2. **Enforced in RLS**, not only in handlers. BUS-028's acceptance is a negative test at the *database* layer.
3. **Position history retention is bounded** and stated to schools (BUS-084).
4. **Driver contact exposure is masked or proxied** (BUS-098). A driver's personal number is not broadcast to hundreds of parents.
5. **Guardian contact on the driver manifest is exception-path only** — reachable on an explicit action, logged, not rendered in the list.

---

## 6. REST SURFACE

Existing paths keep their shape where correct. New and changed:

| Method | Path | Task | Notes |
|---|---|---|---|
| PUT | `/transport/routes/{id}` | BUS-033 | **Did not exist.** Routes were uneditable. |
| DELETE | `/transport/routes/{id}` | BUS-034 | **Did not exist.** Guarded; deactivate preferred. |
| POST/PUT/DELETE | `/transport/stops` `…/{id}` | BUS-036 | Stops become first-class. |
| PUT | `/transport/routes/{id}/assignment` | BUS-043/048 | **The missing operation.** Sets vehicle + driver by id, dated. |
| POST | `/transport/routes/{id}/substitute` | BUS-051 | Single-date override; permanent row untouched. |
| GET | `/transport/trips/today` | BUS-065 | Driver-scoped. Returns only the caller's trips for today. |
| POST | `/transport/trips/{id}/start` · `/end` | BUS-070/071 | Sole tracking control. |
| POST | `/transport/trips/{id}/positions` | BUS-081 | Batched ingest (§4.2). |
| POST | `/transport/trips/{id}/boardings` | BUS-103 | Student-linked, trip-scoped. |
| GET | `/parent/transport/allocation` | BUS-059 | **Single child.** No list form exists. |
| GET | `/parent/transport/trip` | BUS-096 | Single child, active window only. |
| POST | `/transport/trips/{id}/sos` | BUS-113 | |

### 6.1 Error codes

`VALIDATION_ERROR` 422 · `NOT_FOUND` 404 · `FORBIDDEN` 403 · `CAPACITY_EXCEEDED` 409 · `VEHICLE_IN_USE` / `DRIVER_IN_USE` 409 · `DUPLICATE_REGISTRATION` / `DUPLICATE_LICENSE` 409 · `ROUTE_INCOMPLETE` 409 (BUS-042) · `ASSIGNMENT_CONFLICT` 409 · `TRIP_STATE_INVALID` 409 · `NO_ROUTE_RECIPIENTS` 422 (BUS-002) · `STOP_LOCATION_REQUIRED` 422 (BUS-037) · `ALLOCATION_CONFLICT` 409 (BUS-056).

**Fail closed.** Where a targeted operation cannot resolve its target, it errors. It never widens scope to compensate — that is precisely the BUS-002 defect.

---

## 7. WHAT IS PRESERVED

These are assets. Carry them forward unchanged; do not rewrite (P-10):

- **Forced-RLS multi-tenancy** — composite keys, `FORCE ROW LEVEL SECURITY`, matching `USING`/`WITH CHECK`, per-connection tenant context, isolation probes. The one part of the old module the audit rated genuinely solid.
- **Row-locked read-modify-write** (`mutateEntity`, `SELECT … FOR UPDATE`) — whoever wrote this understood lost updates.
- **Savepoint-based unique-violation recovery** (`insertDemandIdempotent`) — a racing double-submit returns the winner idempotently instead of a 500.
- **Mutation audit catalogue**, including the **separate** capacity-override audit. "Who authorised a 49th child on a 48-seat bus" must stay answerable.
- **Finance boundary** — Transport raises demands; Finance alone collects.
- **`transportManager` role** and the principal read-only split.
- **Strict ISO document-expiry validation** and the staff digest.
- **Bulk allocation semantics** — SIS class/section resolution, deterministic ids, one capacity check under lock, bulk caps, partial-success `{assigned, skipped}`.
- **Contiguous 1..n stop resequencing** with permutation validation.

---

## 8. FLAG & ROLLOUT PLAN (BUS-015)

Phase 2 replaces the storage substrate beneath a live pilot. That needs per-capability flags and a rehearsed rollback.

| Flag | Gates | Default | Enable after |
|---|---|---|---|
| `TRANSPORT_API_ENABLED` | ERP transport module (existing) | false / true in live release | — |
| `TRANSPORT_RELATIONAL_STORE` | reads+writes hit the new schema | false | BUS-030 migration verified per school |
| `PARENT_TRANSPORT_ENABLED` | parent transport surface (BUS-003, shipped) | false | BUS-095 + BUS-100 |
| `DRIVER_APP_ENABLED` | driver role, login, app | false | BUS-068 |
| `LIVE_TRACKING_ENABLED` | ingest, live map, ETA | false | BUS-094 |

**Order is strict** and each is per-school. Rollback for `TRANSPORT_RELATIONAL_STORE` is documented and rehearsed in BUS-030 — the old rows are retained read-only until BUS-031 decommissions them.

**Lesson encoded:** `TRANSPORT_API_ENABLED` was set true in `config/live_release.json` while the parent path underneath it had never been verified against the live backend, producing a silent 403 for every parent. **A flag may not be enabled until the task whose acceptance covers that path is Verified.**

---

## 9. PERMITTED LEGACY TOLERANCES

Exhaustive. Anything not listed is forbidden.

| Tolerance | Scope | Removed by |
|---|---|---|
| Read `scheduledTime` as `pickupTime` | Read only. Nothing writes it. | BUS-030 migrates the rows; drop after. |
| `sisStudentId` accepting UUID / student code / admission number | Resolution helpers only, never as a stored link | BUS-023 stores `student_id` FK |
| Free-text vehicle document dates | Existing rows read untouched | BUS-017 typed DATE columns |

---

## 10. CHANGE CONTROL

This document is frozen at v1.0. Changing it requires: a stated reason, the roadmap task that motivates it, and a re-check of every already-Verified task the change touches. Amendments append to §11 with a date and task id — the body above is not edited in place.

## 11. AMENDMENTS

*(none)*
