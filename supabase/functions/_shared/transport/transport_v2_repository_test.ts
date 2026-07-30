// BUS-029 / BUS-032 — Transport v2 repository access-pattern guards.
//
// THE DEFECT THESE PIN
//
// The pre-v2 write paths called `findAll('allocation')` — loading EVERY
// allocation payload in the school into Deno memory — on every assign, every
// bulk operation, every delay notification and every roster read. Capacity
// checking was O(all students in school) PER SINGLE ASSIGNMENT. The audit rated
// that ❌ at 100 buses and unviable at 1,000.
//
// The same access pattern also produced the parent bug: with no way to query
// "the allocation for student X", the parent path fetched page 1 of 20 and
// scanned client-side, finding the right child for ~2.5% of parents in an
// 800-student school.
//
// These tests are STRUCTURAL guards on the new repository. They read the source
// and assert the rules in its header, because "don't reintroduce a full scan" is
// a property no unit test with a mock DB would ever catch — the mock would
// happily return three rows and pass.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  childAllocation,
  dashboardCounts,
  driverTripsToday,
  effectiveAssignment,
  lockRoute,
  routeCapacity,
  routeReadiness,
  tripManifest,
  unstaffedRoutes,
} from "./transport_v2_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

const RAW_SOURCE = await Deno.readTextFile(
  new URL("./transport_v2_repository.ts", import.meta.url),
);

/**
 * Strips comments so "must NOT contain" checks test real CODE, not the prose
 * documenting why a pattern is banned. Without this, a header comment reading
 * "REPLACES ... findAll('allocation')" would fail the very assertion it explains
 * — and the `SELECT … FOR UPDATE` reference in a doc block would be mistaken for
 * an unbounded query.
 */
function codeOnly(src: string): string {
  return src
    .replace(/\/\*[\s\S]*?\*\//g, " ")
    .split("\n")
    .map((line) => {
      const idx = line.indexOf("//");
      return idx >= 0 ? line.slice(0, idx) : line;
    })
    .join("\n");
}

const SOURCE = codeOnly(RAW_SOURCE);

/** Every SQL string literal in the repository. */
function sqlLiterals(src: string): string[] {
  return [...src.matchAll(/`([\s\S]*?)`/g)]
    .map((m) => m[1])
    .filter((s) => /\bSELECT\b|\bINSERT\b|\bUPDATE\b/i.test(s));
}

const QUERIES = sqlLiterals(SOURCE);

// ── Rule 1: no unbounded collection reads ────────────────────────────────────

Deno.test("BUS-032: every query is keyed, filtered, or bounded", () => {
  assert(QUERIES.length >= 8, `expected the repository's queries, saw ${QUERIES.length}`);

  for (const q of QUERIES) {
    const flat = q.replace(/\s+/g, " ");
    const isBounded = /\bWHERE\b/i.test(flat) || /\bLIMIT\b/i.test(flat);
    assert(
      isBounded,
      `unbounded query found — every read must be keyed, predicate-filtered or ` +
        `paginated (rule 1):\n${flat.slice(0, 200)}`,
    );
  }
});

Deno.test("BUS-032: every tenant-scoped query filters on organization_id AND school_id", () => {
  for (const q of QUERIES) {
    const flat = q.replace(/\s+/g, " ");
    // Queries touching a transport table must be tenant-scoped. RLS is the
    // backstop, not the only guard (defence in depth).
    if (!/\btransport_\w+\b/.test(flat)) continue;
    // The assignment-resolution helper is scoped via its EXISTS guard.
    assert(
      /organization_id/.test(flat) && /school_id/.test(flat),
      `query touches a transport table without tenant scoping:\n${flat.slice(0, 200)}`,
    );
  }
});

// ── Rule 2: counts happen in SQL ─────────────────────────────────────────────

Deno.test("BUS-032/BUS-044: occupancy is counted in SQL, never by fetching rows", () => {
  // `count(*)` in SQL vs `rows.length` in TypeScript is the entire difference
  // between an indexed aggregate and loading a school's allocations into memory.
  assert(
    /count\(\*\) FROM transport_allocation/.test(SOURCE),
    "capacity/occupancy must be a SQL count(*)",
  );
  // The banned shape: pulling allocation rows only to measure the array.
  assert(
    !/allocations\.length/.test(SOURCE),
    "occupancy must not be derived from a fetched array's length — that is the " +
      "O(all students in school) pattern BUS-032 exists to remove",
  );
  assert(
    !/findAll\(/.test(SOURCE),
    "findAll has no place in the v2 repository",
  );
});

// ── Rule 3: row-locking discipline preserved ─────────────────────────────────

Deno.test("BUS-032/P-10: the route row lock is preserved", () => {
  // The pre-v2 TRN-7 implementation used SELECT … FOR UPDATE so a concurrent
  // assign could not over-fill a vehicle. That was correct and understood lost
  // updates; only the storage beneath it changes.
  assert(/FOR UPDATE/.test(SOURCE), "lockRoute must take a real row lock");
  assert(typeof lockRoute === "function");
});

// ── Rule 4: single-source precedence for substitution ────────────────────────

Deno.test("BUS-051: substitute precedence is NOT reimplemented in TypeScript", () => {
  // The precedence rule lives in the SQL function transport_effective_assignment.
  // Duplicating it here is how two sides of a rule drift apart — the shape of
  // nearly every defect the audit found.
  assert(
    /transport_effective_assignment/.test(SOURCE),
    "resolution must delegate to the SQL function",
  );
  assert(
    !/assignment_kind === ['"]substitute['"]/.test(SOURCE),
    "substitute precedence must not be re-derived in TypeScript",
  );
});

// ── Parent read is single-child by construction (BUS-059) ────────────────────

Deno.test("BUS-059: the parent read is a single-child lookup with no list form", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function childAllocation"),
    SOURCE.indexOf("// ─── Driver \"today\" read"),
  );
  assert(/a\.student_id = \$3::uuid/.test(fn), "must key on ONE student id");
  assert(/LIMIT 1/.test(fn), "must return at most one row");
  // There must be no exported function that returns allocations for a parent
  // without a student id — the pre-v2 shape that would have leaked the roster.
  assert(
    !/export async function (allAllocations|schoolAllocations|listAllocations)/
      .test(SOURCE),
    "no school-wide allocation list may be exported from this repository",
  );
});

Deno.test("BUS-067: the manifest is bounded by ONE trip", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function tripManifest"),
    SOURCE.indexOf("// ─── Dashboard counts"),
  );
  assert(/t\.id = \$3::uuid/.test(fn), "manifest must be keyed on one trip");
});

Deno.test("BUS-065: the driver read is scoped to one driver AND one date", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function driverTripsToday"),
    SOURCE.indexOf("export async function tripManifest"),
  );
  assert(/t\.service_date = \$3::date/.test(fn), "today only");
  assert(
    /t\.driver_id = \$4::uuid OR t\.attendant_id = \$4::uuid/.test(fn),
    "theirs only — a driver must never see another crew's trip",
  );
  assert(
    /is_substitute/.test(fn),
    "the UI must be able to tell a covering driver they are substituting",
  );
});

// ── Behavioural checks against a recording fake ──────────────────────────────

class RecordingDb {
  queries: Array<{ sql: string; args: unknown[] }> = [];
  rows: Record<string, unknown>[] = [];

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    this.queries.push({ sql, args });
    return Promise.resolve(this.rows as T[]);
  }
}

const SCOPE = { organizationId: "org-1", schoolId: "school-1" };

Deno.test("BUS-044: capacity null when no vehicle is assigned (guard skipped, not crashed)", async () => {
  const db = new RecordingDb();
  db.rows = [{ route_name: "Route 12", capacity: null, current: "40" }];
  const cap = await routeCapacity(
    db as unknown as TenantQueryClient,
    SCOPE,
    "route-1",
    "2026-07-30",
  );
  assertEquals(cap?.capacity, null);
  assertEquals(cap?.current, 40);
});

Deno.test("BUS-044: a zero-capacity vehicle is treated as unset, not as a 0-seat bus", async () => {
  const db = new RecordingDb();
  db.rows = [{ route_name: "Route 12", capacity: 0, current: "5" }];
  const cap = await routeCapacity(
    db as unknown as TenantQueryClient,
    SCOPE,
    "route-1",
    "2026-07-30",
  );
  // A 0 would otherwise reject every allocation on a route whose vehicle simply
  // has no capacity recorded yet.
  assertEquals(cap?.capacity, null);
});

Deno.test("BUS-042: readiness blocks on each missing prerequisite, itemised", async () => {
  const db = new RecordingDb();
  db.rows = [{
    stop_count: "1",
    stops_without_location: "1",
    student_count: "0",
    has_vehicle: false,
    has_driver: false,
    driver_licence_expired: false,
  }];
  const r = await routeReadiness(
    db as unknown as TenantQueryClient,
    SCOPE,
    "route-1",
    "2026-07-30",
  );
  assertEquals(r.ready, false);
  // The pre-v2 activate endpoint had NO validation at all — an admin could
  // activate a route that could never be tracked, with no on-screen signal.
  for (
    const blocker of [
      "needs_at_least_two_stops",
      "stops_missing_location",
      "no_students_allocated",
      "no_vehicle_assigned",
      "no_driver_assigned",
    ]
  ) {
    assert(r.blockers.includes(blocker), `missing blocker: ${blocker}`);
  }
});

Deno.test("BUS-042: a fully-configured route is ready", async () => {
  const db = new RecordingDb();
  db.rows = [{
    stop_count: "8",
    stops_without_location: "0",
    student_count: "42",
    has_vehicle: true,
    has_driver: true,
    driver_licence_expired: false,
  }];
  const r = await routeReadiness(
    db as unknown as TenantQueryClient,
    SCOPE,
    "route-1",
    "2026-07-30",
  );
  assertEquals(r.ready, true);
  assertEquals(r.blockers, []);
});

Deno.test("BUS-054: an expired driver licence blocks publication", async () => {
  const db = new RecordingDb();
  db.rows = [{
    stop_count: "8",
    stops_without_location: "0",
    student_count: "42",
    has_vehicle: true,
    has_driver: true,
    driver_licence_expired: true,
  }];
  const r = await routeReadiness(
    db as unknown as TenantQueryClient,
    SCOPE,
    "route-1",
    "2026-07-30",
  );
  assertEquals(r.ready, false);
  assert(r.blockers.includes("driver_licence_expired"));
});

Deno.test("BUS-059: a child with no allocation returns null, never another child's row", async () => {
  const db = new RecordingDb();
  db.rows = [];
  const alloc = await childAllocation(
    db as unknown as TenantQueryClient,
    SCOPE,
    "student-1",
    "2026-07-30",
  );
  assertEquals(alloc, null);
  // The student id must be bound as a parameter, not interpolated.
  assert(db.queries[0].args.includes("student-1"));
});

Deno.test("BUS-022: effectiveAssignment returns null for an unresolvable route", async () => {
  const db = new RecordingDb();
  db.rows = [];
  const asg = await effectiveAssignment(
    db as unknown as TenantQueryClient,
    SCOPE,
    "route-1",
    "2026-07-30",
  );
  assertEquals(asg, null);
});

Deno.test("BUS-032: all queries bind parameters — no string interpolation of ids", () => {
  // An interpolated id is both an injection vector and a plan-cache killer.
  for (const q of QUERIES) {
    assert(
      !/\$\{/.test(q),
      `query interpolates a value instead of binding it:\n${q.slice(0, 160)}`,
    );
  }
});

Deno.test("BUS-120: dashboard counts are all SQL aggregates", async () => {
  const db = new RecordingDb();
  db.rows = [{
    active_vehicles: "3",
    active_routes: "2",
    allocated_students: "120",
    trips_running: "1",
    open_incidents: "0",
    stops_needing_location: "4",
  }];
  const counts = await dashboardCounts(
    db as unknown as TenantQueryClient,
    SCOPE,
    "2026-07-30",
  );
  assertEquals(counts.activeVehicles, 3);
  assertEquals(counts.allocatedStudents, 120);
  // BUS-030 surfaces migration debt on the dashboard so it cannot be ignored.
  assertEquals(counts.stopsNeedingLocation, 4);
});

Deno.test("BUS-050: unstaffed-route detection names WHY each route is unstaffed", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function unstaffedRoutes"),
    SOURCE.indexOf("// ─── Capacity"),
  );
  for (
    const reason of ["no_assignment", "no_driver", "no_vehicle", "driver_unavailable"]
  ) {
    assert(fn.includes(`'${reason}'`), `must distinguish '${reason}'`);
  }
  assert(typeof unstaffedRoutes === "function");
  assert(typeof driverTripsToday === "function");
  assert(typeof tripManifest === "function");
});
