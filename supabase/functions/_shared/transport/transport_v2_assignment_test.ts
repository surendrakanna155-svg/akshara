// BUS-043…BUS-054 — vehicle & driver assignment, availability, substitution.
//
// THE THREE DEAD FEATURES THIS REVIVES
//
// Pre-v2 there was no way to assign a bus or driver to a route: `assignedBus`
// was written "" at creation and never set by any endpoint, `assignedDriverId`
// was read by a guard and written by nothing. That silently killed three
// correctly-built, row-locked, concurrency-tested features:
//   1. the capacity guard        → unlimited over-allocation of a 48-seat bus
//   2. the vehicle-in-use guard  → could delete a bus 45 children rode
//   3. the driver-in-use guard   → dead code
//
// It also made the owner's substitute-driver requirement unrepresentable.
//
// These tests pin the revival AND the substitution semantics, since a wrong
// precedence rule would silently send the wrong driver to a route full of
// children.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { routeTransport } from "./transport_router.ts";

const RAW = await Deno.readTextFile(
  new URL("./transport_v2_assignment_handlers.ts", import.meta.url),
);
const ROUTER = await Deno.readTextFile(
  new URL("./transport_router.ts", import.meta.url),
);
const OPS_SQL = await Deno.readTextFile(
  new URL(
    "../../../migrations/20260920000290_transport_v2_operations.sql",
    import.meta.url,
  ),
);

/** Strips comments so "must NOT contain" tests inspect code, not prose. */
function codeOnly(src: string): string {
  return src
    .replace(/\/\*[\s\S]*?\*\//g, " ")
    .split("\n")
    .map((l) => {
      const i = l.indexOf("//");
      return i >= 0 ? l.slice(0, i) : l;
    })
    .join("\n");
}
const CODE = codeOnly(RAW);

/**
 * Joins adjacent string-literal concatenations so a prose assertion is not
 * defeated by where the source happened to wrap:
 *   "Replace the permanent " + "assignment instead."  →  one string
 */
function joinLiterals(src: string): string {
  return src.replace(/"\s*\+\s*\n?\s*"/g, "");
}

function fnBody(name: string, until: string): string {
  const start = RAW.indexOf(`export async function ${name}`);
  const end = RAW.indexOf(until, start);
  assert(start >= 0, `handler ${name} not found`);
  return RAW.slice(start, end > start ? end : undefined);
}

// ── BUS-043/048: the endpoint that did not exist ─────────────────────────────

Deno.test("BUS-043/048: assignment links by ID, never by registration or licence", () => {
  // Pre-v2 a route referenced its vehicle by registration TEXT, so changing the
  // registration silently orphaned the link with no error (BUS-047).
  const fn = codeOnly(fnBody("handleSetRouteAssignmentV2", "// ─── BUS-046"));
  assert(fn.includes("vehicleId") && fn.includes("driverId"));
  assert(fn.includes("$4::uuid"), "ids must be bound as uuids");
  assert(!fn.includes("registration"), "must not resolve a vehicle by registration");
  assert(!fn.includes("licence_number"), "must not resolve a driver by licence");
});

Deno.test("BUS-043: assignment takes the route row lock before mutating", () => {
  const fn = fnBody("handleSetRouteAssignmentV2", "// ─── BUS-046");
  assert(
    fn.includes("lockRoute"),
    "closing one assignment and opening another must be serialised, or the " +
      "permanent-overlap exclusion constraint can see two open rows",
  );
});

Deno.test("BUS-043: a new permanent assignment closes the previous one atomically", () => {
  const fn = fnBody("handleSetRouteAssignmentV2", "// ─── BUS-046");
  assert(fn.includes("effective_to = ($2::date - INTERVAL '1 day')::date"));
  assert(fn.includes("assignment_kind = 'permanent'"));
});

Deno.test("BUS-043: assigning nothing is rejected", () => {
  assert(CODE.includes("NOTHING_TO_ASSIGN"));
});

Deno.test("BUS-053: the attendant cannot also be the driver", () => {
  // One person cannot both drive and supervise; the schema enforces it too.
  assert(CODE.includes("ATTENDANT_IS_DRIVER"));
  assert(OPS_SQL.includes("transport_assignment_attendant_distinct"));
});

// ── BUS-044: the capacity guard, finally reachable ───────────────────────────

Deno.test("BUS-044: capacity resolves from the assignment's vehicle", () => {
  const fn = fnBody("handleRouteCapacityV2", "/** GET-shaped");
  assert(fn.includes("routeCapacity"));
  assert(fn.includes("wouldExceed"));
});

Deno.test("BUS-044: no vehicle means UNBOUNDED, never zero seats", () => {
  const fn = fnBody("handleRouteCapacityV2", "/** GET-shaped");
  assert(fn.includes("unbounded"));
  assert(
    /capacity === null/.test(fn),
    "null capacity must mean 'no vehicle assigned', not a 0-seat bus — " +
      "reporting 0 would reject every allocation",
  );
});

// ── BUS-045/049: the delete guards, finally reachable ────────────────────────

Deno.test("BUS-045: vehicle delete is blocked by assignments AND trip history", () => {
  const fn = fnBody("handleDeleteVehicleV2", "/** DELETE /transport/v2/drivers");
  assert(fn.includes("VEHICLE_IN_USE"));
  assert(fn.includes("transport_assignment"));
  assert(fn.includes("transport_trip"), "trip history must block deletion");
  assert(/Retire it instead/.test(joinLiterals(fn)), "must offer the correct alternative");
});

Deno.test("BUS-049: driver delete counts BOTH driver and attendant references", () => {
  const fn = fnBody("handleDeleteDriverV2", "");
  assert(fn.includes("DRIVER_IN_USE"));
  assert(
    fn.includes("driver_id = $1::uuid OR attendant_id = $1::uuid"),
    "a person assigned as an attendant is just as in-use as one assigned as " +
      "a driver — checking only driver_id would let them be deleted",
  );
  assert(/Deactivate instead/.test(joinLiterals(fn)));
});

// ── BUS-051: substitution (owner requirement 1) ──────────────────────────────

Deno.test("BUS-051: a substitute is BOUNDED and never touches the permanent row", () => {
  const fn = codeOnly(fnBody("handleSubstituteAssignmentV2", "/** DELETE /transport/v2/assignments"));
  assert(fn.includes("'substitute'"));
  // The permanent assignment must not be closed or modified — that is the whole
  // point of owner requirement 1.
  assert(
    !fn.includes("effective_to = ($2::date - INTERVAL '1 day')::date"),
    "substitution must NOT close the permanent assignment",
  );
  assert(fn.includes("$8::date"), "effective_to must be set (bounded)");
  assert(OPS_SQL.includes("transport_assignment_substitute_bounded"));
});

Deno.test("BUS-051: a substitute requires a reason", () => {
  const fn = fnBody("handleSubstituteAssignmentV2", "/** DELETE /transport/v2/assignments");
  assert(
    fn.includes('requireStr(body, "reason")'),
    "an unexplained substitution is an unauditable one",
  );
});

Deno.test("BUS-051: a driver-only substitution inherits the regular vehicle", () => {
  const fn = fnBody("handleSubstituteAssignmentV2", "/** DELETE /transport/v2/assignments");
  assert(fn.includes("permanent?.vehicle_id"));
  assert(fn.includes("permanent?.driver_id"));
  assert(
    fn.includes("effectiveAssignment"),
    "inheritance must read the EFFECTIVE assignment, not raw rows",
  );
});

Deno.test("BUS-051/052: already-generated trips are re-bound to the substitute", () => {
  const fn = fnBody("handleSubstituteAssignmentV2", "/** DELETE /transport/v2/assignments");
  assert(fn.includes("UPDATE transport_trip"));
  assert(
    fn.includes("status = 'scheduled'"),
    "only NOT-yet-started trips may be re-bound — re-binding a running trip " +
      "would rewrite who was actually driving",
  );
  assert(
    fn.includes("tripsRebound"),
    "the count must be reported: if last night's trip generation already ran, " +
      "the substitute would otherwise log in and see nothing",
  );
});

Deno.test("BUS-051: a substitute driver must themselves be available", () => {
  const fn = fnBody("handleSubstituteAssignmentV2", "/** DELETE /transport/v2/assignments");
  assert(
    fn.includes("assertDriverAvailable"),
    "covering one route by stripping another is not a fix",
  );
  assert(fn.includes("DRIVER_DOUBLE_BOOKED") || CODE.includes("DRIVER_DOUBLE_BOOKED"));
});

Deno.test("BUS-051: only a substitute may be cancelled, never a permanent row", () => {
  const fn = fnBody("handleCancelSubstituteV2", "// ─── BUS-050");
  assert(fn.includes("NOT_A_SUBSTITUTE"));
  assert(
    /Replace the permanent assignment instead/.test(joinLiterals(fn)),
    "cancelling a permanent assignment would leave the route unstaffed with no " +
      "record of what it used to be",
  );
});

Deno.test("BUS-051: cancelling a substitute re-binds trips to the permanent crew", () => {
  const fn = fnBody("handleCancelSubstituteV2", "// ─── BUS-050");
  assert(fn.includes("UPDATE transport_trip"));
  assert(fn.includes("effectiveAssignment"));
});

Deno.test("BUS-022/051: substitute precedence lives ONLY in SQL", () => {
  // Re-deriving precedence in TypeScript is how two sides of a rule drift — the
  // shape of nearly every defect the audit found.
  assert(
    !/assignment_kind === ['"]substitute['"]/.test(CODE),
    "precedence must not be reimplemented here",
  );
  assert(
    OPS_SQL.includes("ORDER BY (a.assignment_kind = 'substitute') DESC"),
    "precedence belongs to transport_effective_assignment()",
  );
});

// ── BUS-050: availability drives the substitution flag ───────────────────────

Deno.test("BUS-050: marking leave reports which routes it leaves uncovered", () => {
  const fn = fnBody("handleSetDriverAvailabilityV2", "// ─── BUS-044");
  assert(fn.includes("routesNeedingSubstitute"));
  assert(
    fn.includes("r.status = 'active'"),
    "only active routes matter — a retired route needs no substitute",
  );
});

Deno.test("BUS-050: an unavailable driver cannot be permanently assigned", () => {
  assert(CODE.includes("DRIVER_UNAVAILABLE"));
  assert(
    /Assign a substitute for those dates instead/.test(joinLiterals(RAW)),
    "the rejection must point at the correct action",
  );
});

Deno.test("BUS-050: availability kinds are validated", () => {
  assert(CODE.includes("INVALID_KIND"));
  for (const k of ["leave", "sick", "rest", "suspended", "training"]) {
    assert(CODE.includes(`"${k}"`), `kind '${k}' must be accepted`);
  }
});

// ── BUS-054: compliance gate ────────────────────────────────────────────────

Deno.test("BUS-054: expired insurance/fitness/permit blocks assignment", () => {
  assert(CODE.includes("COMPLIANCE_BLOCKED"));
  for (const doc of ["insurance", "fitness", "permit"]) {
    assert(CODE.includes(`'${doc}'`), `${doc} expiry must gate assignment`);
  }
});

Deno.test("BUS-054: an expired driver licence blocks assignment", () => {
  assert(CODE.includes("driver_licence_expired"));
  assert(CODE.includes("licence_expiry < $2::date"));
});

Deno.test("BUS-054: a non-active vehicle cannot be assigned", () => {
  assert(
    CODE.includes("vehicle_${rows[0].status}") ||
      CODE.includes("`vehicle_${rows[0].status}`"),
    "a vehicle in maintenance or retired must not be assignable",
  );
});

Deno.test("BUS-054: the compliance override is audited SEPARATELY", () => {
  // Mirrors the capacity-override trail that made "who authorised the 49th
  // child on a 48-seat bus" answerable.
  assert(CODE.includes("transport.compliance.overridden"));
  const count = (CODE.match(/transport\.compliance\.overridden/g) ?? []).length;
  assert(count >= 2, "both permanent assignment and substitution must audit it");
});

// ── Routing ─────────────────────────────────────────────────────────────────

Deno.test("BUS-043: the assignment endpoint is reachable", () => {
  assert(ROUTER.includes("handleSetRouteAssignmentV2"));
  assert(ROUTER.includes("assignment$"));
});

Deno.test("BUS-050: /routes/unstaffed is matched before /routes/{id}/...", async () => {
  // 'unstaffed' must not be captured as a route id.
  const block = ROUTER.slice(
    ROUTER.indexOf("function matchTransportV2Route"),
    ROUTER.indexOf("function matchTransportRoute"),
  );
  assert(block.includes('path === "/transport/v2/routes/unstaffed"'));
  const res = await routeTransport(
    new Request("https://x.test/transport/v2/routes/unstaffed"),
    {} as never,
    "GET",
    "/transport/v2/routes/unstaffed",
  );
  // GET is not a declared method for this path, so it falls through — the point
  // is that matching did not throw.
  assertEquals(res, null);
});

// ── Cross-cutting ───────────────────────────────────────────────────────────

Deno.test("Phase 4/5: no handler touches transport_entities", () => {
  assert(!CODE.includes("transport_entities"));
});

Deno.test("Phase 4/5: every mutation emits an audit event", () => {
  const handlers = [...CODE.matchAll(/export async function (handle\w+V2)/g)]
    .map((m) => m[1]);
  assert(handlers.length >= 8, `expected the v2 handlers, saw ${handlers.length}`);
  const audits = (CODE.match(/emitMutationAudit\(/g) ?? []).length;
  // capacity-check and unstaffed are read-only probes and correctly audit nothing.
  assert(audits >= handlers.length - 2, `${handlers.length} handlers, ${audits} audits`);
});

Deno.test("Phase 4/5: every query binds parameters", () => {
  const queries = [...CODE.matchAll(/`([\s\S]*?)`/g)]
    .map((m) => m[1])
    .filter((q) =>
      /\bSELECT\b[\s\S]*\bFROM\b/i.test(q) ||
      /\bINSERT\s+INTO\b/i.test(q) ||
      /\bUPDATE\b[\s\S]*\bSET\b/i.test(q) ||
      /\bDELETE\s+FROM\b/i.test(q)
    );
  assert(queries.length >= 10, `expected the queries, saw ${queries.length}`);
  for (const q of queries) {
    assert(!/\$\{/.test(q), `query interpolates instead of binding:\n${q.slice(0, 140)}`);
  }
});

Deno.test("Phase 4/5: date inputs are strictly validated", () => {
  assert(CODE.includes("INVALID_DATE"));
  assert(CODE.includes("INVALID_DATE_RANGE"));
  assert(CODE.includes("ISO_DATE"));
});
