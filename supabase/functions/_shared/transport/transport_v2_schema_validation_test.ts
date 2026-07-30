// BUS-016…BUS-030 — Transport v2 schema contract validation.
//
// SCOPE AND HONESTY NOTE
//
// There is no local Postgres in this environment, so these tests validate the
// migration SQL statically — they do NOT prove the DDL executes. Live DDL
// execution and RLS behaviour under real sessions are proven by BUS-133 (live
// deploy + certification), which is owner-gated. This suite exists to catch the
// class of defect that static analysis genuinely CAN catch: a schema that
// silently contradicts TRANSPORT_DOMAIN_CONTRACT.md.
//
// Mirrors the existing intelligence_migration_validation_test.ts convention.
//
// WHY EACH ASSERTION EXISTS
//
// Every check below corresponds to a specific defect the Bus Tracking audit
// found in the pre-v2 model. A regression here means the new schema has
// reintroduced an old failure.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const MIGRATIONS = new URL("../../../migrations/", import.meta.url);

async function sql(file: string): Promise<string> {
  return await Deno.readTextFile(new URL(file, MIGRATIONS));
}

/**
 * Strips `--` line comments and block comments so a "must NOT contain" check
 * tests the actual DDL rather than the prose explaining why the column is
 * absent. Without this, a comment reading "DELIBERATELY ABSENT:
 * assigned_vehicle_id" would fail the very assertion it documents.
 */
function ddlOnly(text: string): string {
  return text
    .replace(/\/\*[\s\S]*?\*\//g, " ")
    .split("\n")
    .map((line) => {
      const idx = line.indexOf("--");
      return idx >= 0 ? line.slice(0, idx) : line;
    })
    .join("\n");
}

const POSTGIS = "20260920000270_transport_v2_postgis.sql";
const CORE = "20260920000280_transport_v2_core_entities.sql";
const OPS = "20260920000290_transport_v2_operations.sql";
const RLS = "20260920000300_transport_v2_rls.sql";
const MIGRATE = "20260920000310_transport_v2_data_migration.sql";

// ── BUS-016: geography foundation ────────────────────────────────────────────

Deno.test("BUS-016: PostGIS is enabled before any geography column is declared", async () => {
  const postgis = await sql(POSTGIS);
  assert(
    postgis.includes("CREATE EXTENSION IF NOT EXISTS postgis"),
    "PostGIS must be enabled; without it geofencing, distance-to-stop and " +
      "arrival detection are all impossible",
  );
  // Migration order matters: 883 < 884 < 885, so geography columns land after.
  assert(POSTGIS < CORE && CORE < OPS);
});

Deno.test("BUS-016: the plausibility guard rejects NULL Island", async () => {
  const postgis = await sql(POSTGIS);
  assert(
    postgis.includes("transport_is_plausible_point"),
    "a coordinate guard must exist",
  );
  // (0,0) is the EXACT signature of the pre-v2 defect: the write path dropped
  // coordinates and the client mapper defaulted them to 0, so every stop a real
  // school created sat in the Atlantic off Ghana.
  assert(
    postgis.includes("ABS(ST_X(pt::geometry)) < 0.0001") &&
      postgis.includes("ABS(ST_Y(pt::geometry)) < 0.0001"),
    "the guard MUST reject (0,0) specifically",
  );
});

// ── BUS-019: the gating column ───────────────────────────────────────────────

Deno.test("BUS-019: an active stop cannot exist without a plausible location", async () => {
  const core = await sql(CORE);
  assert(core.includes("location GEOGRAPHY(POINT, 4326)"));
  assert(
    core.includes("transport_stop_location_required"),
    "the location constraint is the single thing that makes the audit's worst " +
      "structural defect unrepresentable",
  );
  // The ONLY permitted NULL location is the explicit migration state.
  assert(core.includes("status = 'needs_location' AND location IS NULL"));
  assert(
    core.includes("transport_is_plausible_point(location)"),
    "an active stop's coordinate must pass the plausibility guard",
  );
});

Deno.test("BUS-019/BUS-040: stops are school-owned so AM and PM can share one", async () => {
  const core = await sql(CORE);
  // A stop table with a route_id column would recreate the pre-v2 duplication,
  // where the same physical gate existed twice and fixing its location fixed
  // only one of them.
  const stopBlock = ddlOnly(core.slice(
    core.indexOf("CREATE TABLE transport_stop"),
    core.indexOf("CREATE INDEX transport_stop_location_gix"),
  ));
  assert(
    !stopBlock.includes("route_id"),
    "transport_stop must NOT carry a route_id — stops belong to the school",
  );
  assert(core.includes("PRIMARY KEY (route_id, stop_id)"));
});

// ── BUS-020: route is a template ─────────────────────────────────────────────

Deno.test("BUS-020: the route table carries NO operational or derived columns", async () => {
  const core = await sql(CORE);
  const routeBlock = ddlOnly(core.slice(
    core.indexOf("CREATE TABLE transport_route ("),
    core.indexOf("CREATE UNIQUE INDEX transport_route_name_uniq"),
  ));
  // `assignedBus` was a scalar NO endpoint ever wrote, which silently disabled
  // the capacity guard and both delete guards — three correct features that
  // never once executed.
  for (
    const forbidden of [
      "assigned_bus",
      "assigned_vehicle_id",
      "assigned_driver_id",
      "stop_count",
      "student_count",
    ]
  ) {
    assert(
      !routeBlock.includes(forbidden),
      `transport_route must not carry '${forbidden}' — operational links are ` +
        `dated assignment rows (P-3) and counts are computed on read`,
    );
  }
});

// ── BUS-021: typed times ─────────────────────────────────────────────────────

Deno.test("BUS-021: stop times are TIME, never text", async () => {
  const core = await sql(CORE);
  assert(core.includes("scheduled_pickup_time TIME"));
  assert(core.includes("scheduled_drop_time TIME"));
  // Free-text times made schedule adherence and any ETA baseline arithmetically
  // impossible — the ceiling that let the old dashboard DISPLAY "94% On-Time"
  // while being unable to COMPUTE it.
  assert(!core.includes("scheduled_pickup_time TEXT"));
});

// ── BUS-022: dated assignment — the substitution enabler ─────────────────────

Deno.test("BUS-022: assignment links by ID, never by registration or licence string", async () => {
  const ops = await sql(OPS);
  assert(ops.includes("vehicle_id UUID REFERENCES transport_vehicle (id)"));
  assert(ops.includes("driver_id UUID REFERENCES transport_driver (id)"));
  // Pre-v2 a route referenced its vehicle by registration TEXT, so changing a
  // registration silently orphaned the link with no error and no cascade.
  const assignBlock = ddlOnly(ops.slice(
    ops.indexOf("CREATE TABLE transport_assignment"),
    ops.indexOf("CREATE EXTENSION IF NOT EXISTS btree_gist"),
  ));
  assert(!assignBlock.includes("registration"));
  assert(!assignBlock.includes("licence_number"));
});

Deno.test("BUS-022: permanent assignments cannot overlap, substitutes deliberately can", async () => {
  const ops = await sql(OPS);
  assert(ops.includes("EXCLUDE USING GIST"));
  assert(
    ops.includes("WHERE (assignment_kind = 'permanent')"),
    "the exclusion constraint MUST be scoped to permanent rows — a substitute " +
      "overlapping a permanent assignment is the entire point of owner " +
      "requirement 1 (cover today without disturbing the permanent arrangement)",
  );
  assert(ops.includes("transport_assignment_substitute_bounded"));
});

Deno.test("BUS-022/BUS-051: substitute wins over permanent for a covered date", async () => {
  const ops = await sql(OPS);
  assert(ops.includes("transport_effective_assignment"));
  assert(
    ops.includes("ORDER BY (a.assignment_kind = 'substitute') DESC"),
    "resolution MUST prefer a substitute — this single ordering is why a " +
      "substitute driver needs no special case in the driver app",
  );
});

// ── BUS-023: allocation integrity ────────────────────────────────────────────

Deno.test("BUS-023: allocations reference stops by FK and carry no display copies", async () => {
  const ops = await sql(OPS);
  assert(ops.includes("pickup_stop_id UUID NOT NULL REFERENCES transport_stop (id)"));
  assert(ops.includes("drop_stop_id UUID NOT NULL REFERENCES transport_stop (id)"));
  const allocBlock = ddlOnly(ops.slice(
    ops.indexOf("CREATE TABLE transport_allocation"),
    ops.indexOf("CREATE UNIQUE INDEX transport_allocation_one_per_shift"),
  ));
  // Pre-v2 these were free text typed by an admin, grouped by exact string
  // match — so a child's pickup point depended on typing accuracy.
  assert(!allocBlock.includes("pickup_stop TEXT"));
  // And these froze at assignment time, going stale on any change.
  assert(!allocBlock.includes("route_name"));
  assert(!allocBlock.includes("bus_number"));
});

Deno.test("BUS-056: a student cannot ride two buses in the same shift", async () => {
  const ops = await sql(OPS);
  assert(ops.includes("transport_allocation_one_per_shift"));
  assert(ops.includes("WHERE status = 'active'"));
  // Pre-v2 nothing checked: a double-allocated student counted against both
  // capacities, appeared on both rosters, and BOTH drivers expected them.
});

// ── BUS-024/072/073: trip ────────────────────────────────────────────────────

Deno.test("BUS-024: one trip per route/date/shift", async () => {
  const ops = await sql(OPS);
  assert(ops.includes("transport_trip_route_date_shift_uniq"));
  assert(ops.includes("ON transport_trip (route_id, service_date, shift)"));
});

Deno.test("BUS-072/073: terminal trips are immutable, enforced by trigger", async () => {
  const ops = await sql(OPS);
  assert(ops.includes("transport_trip_guard"));
  assert(ops.includes("TRIP_STATE_INVALID"));
  assert(
    ops.includes("TRIP_IMMUTABLE"),
    "completed trips must be uneditable — the pre-v2 attendance row destroyed " +
      "its own history because re-recording replaced it in place",
  );
  assert(ops.includes("BEFORE UPDATE ON transport_trip"));
});

// ── BUS-025/026: time-series + boarding ──────────────────────────────────────

Deno.test("BUS-025: positions are partitioned by time", async () => {
  const ops = await sql(OPS);
  assert(ops.includes("PARTITION BY RANGE (recorded_at)"));
  // ~2.16M rows/day at 1,000 buses. Retrofitting partitioning under that load
  // is painful, so it is designed in at creation.
});

Deno.test("BUS-011/076: positions are source-agnostic", async () => {
  const ops = await sql(OPS);
  assert(ops.includes("source_type TEXT NOT NULL DEFAULT 'driver_app'"));
  assert(
    ops.includes("'driver_app', 'hardware_device'"),
    "a driver phone and a hardware tracker must be interchangeable adapters " +
      "(owner requirement 3: no redesign to add hardware GPS)",
  );
});

Deno.test("BUS-026: boarding carries a real student FK and a dated trip", async () => {
  const ops = await sql(OPS);
  assert(ops.includes("student_id UUID NOT NULL REFERENCES students (id)"));
  assert(ops.includes("trip_id UUID NOT NULL REFERENCES transport_trip (id)"));
  const boardBlock = ddlOnly(ops.slice(
    ops.indexOf("CREATE TABLE transport_boarding"),
    ops.indexOf("CREATE UNIQUE INDEX transport_boarding_trip_student_event_uniq"),
  ));
  // The pre-v2 row keyed on a display NAME with no date — unattributable,
  // unjoinable to SIS, broken for duplicate names, and unable to store history.
  assert(!boardBlock.includes("student_name"));
});

// ── BUS-028: RLS ─────────────────────────────────────────────────────────────

Deno.test("BUS-028: every v2 table has forced RLS", async () => {
  const rls = await sql(RLS);
  const core = await sql(CORE);
  const ops = await sql(OPS);
  const created = [...`${core}\n${ops}`.matchAll(/CREATE TABLE (transport_\w+)/g)]
    .map((m) => m[1]);
  assert(created.length >= 10, `expected the full v2 table set, saw ${created.length}`);

  for (const table of created) {
    // Partitions inherit their parent's RLS.
    if (table.endsWith("_default")) continue;
    assert(
      rls.includes(`'${table}'`) || rls.includes(`ON ${table} `) ||
        rls.includes(`ALTER TABLE ${table} ENABLE`),
      `${table} has no RLS policy — the pre-v2 module's forced-RLS tenant ` +
        `isolation is the one part the audit rated solid and must not regress`,
    );
  }
});

Deno.test("BUS-028: parent visibility is scoped to their own children only", async () => {
  const rls = await sql(RLS);
  assert(rls.includes("transport_is_guardian_of"));
  assert(rls.includes("transport_allocation_parent_read"));
  // The audit's finding: the original design would have shipped other
  // children's names, admission numbers and PICKUP STOP LOCATIONS to every
  // parent, because visibility was a client-side filter over a school-wide
  // payload. It must be a database predicate.
  assert(rls.includes("student_guardians"));
  assert(rls.includes("sg.status = 'active'"));
});

Deno.test("BUS-028: a driver reads only TODAY'S trip they crew", async () => {
  const rls = await sql(RLS);
  assert(rls.includes("transport_is_trip_crew"));
  assert(
    rls.includes("p_trip.service_date = CURRENT_DATE"),
    "a driver has no business reading last month's manifest of children",
  );
  assert(rls.includes("transport_current_driver_id"));
});

Deno.test("BUS-028/081: position writes require a STARTED trip the caller crews", async () => {
  const rls = await sql(RLS);
  assert(rls.includes("transport_position_crew_write"));
  assert(rls.includes("t.status = 'started'"));
});

Deno.test("BUS-028: parents see live position only during their child's active trip", async () => {
  const rls = await sql(RLS);
  const policy = rls.slice(
    rls.indexOf("CREATE POLICY transport_position_parent_read"),
    rls.indexOf("GRANT SELECT, INSERT, UPDATE, DELETE ON transport_position"),
  );
  assert(policy.includes("t.status = 'started'"));
  assert(policy.includes("t.service_date = CURRENT_DATE"));
  assert(policy.includes("transport_is_guardian_of"));
});

// ── BUS-030: migration honesty ───────────────────────────────────────────────

Deno.test("BUS-030: the migration NEVER fabricates a coordinate", async () => {
  const migrate = await sql(MIGRATE);
  assert(migrate.includes("'needs_location'"));
  assert(
    migrate.includes("transport_is_plausible_point"),
    "only plausible legacy coordinates may be carried over",
  );
  // Defaulting a missing coordinate to (0,0) would embed the audit's worst
  // defect into the new schema permanently and silently.
  assert(
    !/ST_MakePoint\(0\s*,\s*0\)/.test(migrate),
    "the migration must not insert a (0,0) placeholder",
  );
});

Deno.test("BUS-030: unmigratable data becomes a human worklist, not a silent default", async () => {
  const migrate = await sql(MIGRATE);
  assert(migrate.includes("transport_migration_reconciliation"));
  for (
    const issue of [
      "stop_missing_location",
      "stop_time_unparseable",
      "allocation_unresolved",
      "driver_has_no_login",
      "route_needs_vehicle_and_driver_assignment",
      "document_expiry_unparseable",
      "both_shift_route_split_required",
    ]
  ) {
    assert(
      migrate.includes(`'${issue}'`),
      `migration must itemise '${issue}' for a human rather than guessing`,
    );
  }
});

Deno.test("BUS-030: allocations are exact-matched, never fuzzy-matched", async () => {
  const migrate = await sql(MIGRATE);
  // A child placed at the wrong pickup point by a fuzzy match is a safety
  // incident, not a data-quality issue.
  assert(!migrate.includes("similarity("));
  assert(!migrate.includes("levenshtein"));
  assert(migrate.includes("lower(btrim(ps.name)) = lower(btrim(e.payload ->> 'pickupStop'))"));
});

Deno.test("BUS-030: legacy transport_entities is READ-ONLY (rollback is retention)", async () => {
  const migrate = await sql(MIGRATE);
  assert(!/DROP TABLE\s+transport_entities/i.test(migrate));
  assert(!/DELETE FROM transport_entities/i.test(migrate));
  assert(!/UPDATE transport_entities/i.test(migrate));
});

Deno.test("BUS-030: vehicle→route assignment is deliberately NOT migrated", async () => {
  const migrate = await sql(MIGRATE);
  // There is nothing to migrate: `assignedBus` was written "" at creation and
  // no endpoint ever set it. Every legacy route is unassigned by definition.
  assert(migrate.includes("route_needs_vehicle_and_driver_assignment"));
  assert(
    !/INSERT INTO transport_assignment/i.test(migrate),
    "no assignment can be synthesised from a field that was never written",
  );
});

// ── Cross-cutting ────────────────────────────────────────────────────────────

Deno.test("Phase 2: every v2 table is tenant-scoped", async () => {
  const core = await sql(CORE);
  const ops = await sql(OPS);
  const combined = `${core}\n${ops}`;
  const tables = [...combined.matchAll(/CREATE TABLE (transport_\w+) \(([\s\S]*?)\n\)/g)];
  assert(tables.length >= 10);
  for (const [, name, body] of tables) {
    if (name.endsWith("_default")) continue;
    assertEquals(
      body.includes("organization_id") && body.includes("school_id"),
      true,
      `${name} must carry organization_id + school_id for tenant isolation`,
    );
  }
});

Deno.test("Phase 2: migrations are ordered so dependencies exist when referenced", async () => {
  // FKs reference tables created in earlier files; a wrong order fails at deploy
  // time, which for a live pilot means a failed migration mid-flight.
  assert(POSTGIS < CORE);
  assert(CORE < OPS);
  assert(OPS < RLS);
  assert(RLS < MIGRATE);
});
