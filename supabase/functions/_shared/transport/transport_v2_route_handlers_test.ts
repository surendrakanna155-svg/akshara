// BUS-033…BUS-042 — Transport v2 route & stop management.
//
// WHAT EACH GROUP PINS
//
// These handlers close the gaps that made the pre-v2 module unusable for a real
// school: routes could be created and activated but never edited, retired or
// deleted; creation hid four hardcoded values behind a one-field dialog;
// activation ran with zero validation; and stops had no coordinates at all.
//
// The `parseStopTime` and coordinate-validation tests carry the most weight —
// they are the two places where the pre-v2 module accepted anything and
// therefore could never compute anything.

import {
  assert,
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { parseStopTime } from "./transport_v2_route_handlers.ts";
import { routeTransport } from "./transport_router.ts";

const RAW_SOURCE = await Deno.readTextFile(
  new URL("./transport_v2_route_handlers.ts", import.meta.url),
);

/**
 * Strips comments so "must NOT contain" checks test real CODE, not the prose
 * explaining why a pattern is banned — e.g. the header comment stating that this
 * file does not touch `transport_entities` must not fail that very assertion.
 */
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

const SOURCE = RAW_SOURCE;
const CODE = codeOnly(RAW_SOURCE);
const ROUTER_SOURCE = await Deno.readTextFile(
  new URL("./transport_router.ts", import.meta.url),
);

// ── BUS-038: structured stop times ───────────────────────────────────────────

Deno.test("BUS-038: 24-hour times parse and normalise", () => {
  assertEquals(parseStopTime("07:05"), "07:05");
  assertEquals(parseStopTime("7:05"), "07:05");
  assertEquals(parseStopTime("15:40"), "15:40");
  assertEquals(parseStopTime("00:00"), "00:00");
  assertEquals(parseStopTime("23:59"), "23:59");
});

Deno.test("BUS-038: 12-hour times parse, including the midnight/noon edges", () => {
  assertEquals(parseStopTime("7:05 AM"), "07:05");
  assertEquals(parseStopTime("7:05am"), "07:05");
  assertEquals(parseStopTime("3:40 PM"), "15:40");
  // The two cases naive converters get wrong.
  assertEquals(parseStopTime("12:00 AM"), "00:00", "12 AM is midnight");
  assertEquals(parseStopTime("12:30 PM"), "12:30", "12 PM is noon");
});

Deno.test("BUS-038: the exact junk the pre-v2 field accepted is now REJECTED", () => {
  // Every one of these persisted unvalidated before BUS-038, which is why
  // schedule adherence and any ETA baseline were arithmetically impossible.
  for (const junk of ["7.05", "0705", "morning", "7", "25:00", "12:60", "abc", "7:5"]) {
    assertEquals(parseStopTime(junk), null, `"${junk}" must be rejected`);
  }
});

Deno.test("BUS-038: blank means 'not set', not an error", () => {
  assertEquals(parseStopTime(""), null);
  assertEquals(parseStopTime("   "), null);
});

// ── BUS-037: coordinates are mandatory ───────────────────────────────────────

Deno.test("BUS-037: stop creation demands a coordinate", () => {
  // The gating requirement for the whole tracking feature. The pre-v2 write path
  // accepted only {name, pickupTime, dropTime}.
  assert(SOURCE.includes("STOP_LOCATION_REQUIRED"));
  assert(
    /latitude and longitude are required/.test(SOURCE),
    "the error must explain WHY a location is required",
  );
});

Deno.test("BUS-037: (0,0) is rejected explicitly, not merely as out-of-range", () => {
  // (0,0) is the exact signature of a dropped coordinate — the value EVERY
  // pre-v2 stop received. A generic range check would accept it.
  assert(
    /Math\.abs\(lat\) < 0\.0001 && Math\.abs\(lng\) < 0\.0001/.test(SOURCE),
    "must reject NULL Island specifically",
  );
  assert(SOURCE.includes("STOP_LOCATION_INVALID"));
});

Deno.test("BUS-037/P-7: addresses are geocoded ONCE and stored, never per read", () => {
  assert(
    /geocoded ONCE/i.test(SOURCE),
    "the geocode-once rule must be documented at the write site",
  );
  assert(SOURCE.includes("address_text"));
  // No geocoding call may appear in this layer at all.
  assert(!/geocod(e|ing)\(/i.test(SOURCE));
});

Deno.test("BUS-037: a stop with no location cannot be attached to a route", () => {
  // Otherwise an admin builds a route that can never be published (BUS-042)
  // with no visible cause.
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function handleAttachStopV2"),
    SOURCE.indexOf("export async function handleUpdateRouteStopV2"),
  );
  assert(fn.includes("needs_location"));
  assert(fn.includes("STOP_LOCATION_REQUIRED"));
});

Deno.test("BUS-030/BUS-037: placing a pin resolves a migrated needs_location stop", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function handleUpdateStopV2"),
    SOURCE.indexOf("export async function handleDeleteStopV2"),
  );
  assert(
    fn.includes("status = 'active'"),
    "supplying a coordinate must clear needs_location so the route becomes " +
      "publishable — this is how BUS-030's migration debt gets worked off",
  );
});

// ── BUS-033: the update endpoint that did not exist ──────────────────────────

Deno.test("BUS-033: every previously write-once route field is updatable", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function handleUpdateRouteV2"),
    SOURCE.indexOf("// ─── BUS-034"),
  );
  // The four values the pre-v2 create hardcoded and no endpoint could fix.
  for (const field of ["name", "code", "shift", "direction",
                       "default_departure_time", "default_return_time", "distance_m"]) {
    assert(fn.includes(field), `route field '${field}' must be updatable`);
  }
});

Deno.test("BUS-033/BUS-007: an omitted field is left untouched, never defaulted", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function handleUpdateRouteV2"),
    SOURCE.indexOf("// ─── BUS-034"),
  );
  // BUS-007's lesson: the pre-v2 stop editor overwrote a field it had never
  // loaded, silently erasing drop times. Partial update is structural here.
  assert(fn.includes("if (sets.length === 0)"));
  assert(fn.includes("NO_CHANGES"));
  assert(
    fn.includes("!== undefined"),
    "presence must be tested with !== undefined, not truthiness — an empty " +
      "string is a legitimate 'clear this field'",
  );
});

Deno.test("BUS-033: a blank name is rejected rather than silently accepted", () => {
  assert(SOURCE.includes("name cannot be blank"));
});

// ── BUS-034: deactivate and delete ───────────────────────────────────────────

Deno.test("BUS-034: deactivate reports how many children still reference the route", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function handleDeactivateRouteV2"),
    SOURCE.indexOf("export async function handleDeleteRouteV2"),
  );
  assert(fn.includes("studentsStillAllocated"));
  assert(
    fn.includes("active_allocations"),
    "deactivation must not silently strip allocations — the admin needs to know " +
      "who to re-home",
  );
});

Deno.test("BUS-034: delete is blocked by allocations, trips or assignments", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function handleDeleteRouteV2"),
    SOURCE.indexOf("// ─── BUS-042"),
  );
  for (const blocker of ["has_allocations", "has_trip_history", "has_assignments"]) {
    assert(fn.includes(blocker), `delete must be blocked by '${blocker}'`);
  }
  assert(fn.includes("ROUTE_IN_USE"));
  assert(
    /Deactivate it instead/.test(fn),
    "the rejection must offer the correct alternative",
  );
});

// ── BUS-042: the publish gate ────────────────────────────────────────────────

Deno.test("BUS-042: activation is gated on readiness, not unconditional", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function handleActivateRouteV2"),
    SOURCE.indexOf("/** GET-shaped readiness probe"),
  );
  assert(fn.includes("routeReadiness"));
  assert(fn.includes("ROUTE_INCOMPLETE"));
  assert(
    fn.includes("readiness.blockers.join"),
    "the rejection must itemise WHAT is missing, not just refuse",
  );
});

Deno.test("BUS-042/BUS-119: the gate and the UI checklist share one source", () => {
  // Two implementations of "is this route ready" would drift — the shape of
  // nearly every defect the audit found.
  assert(
    SOURCE.includes("handleRouteReadinessV2"),
    "the UI must be able to probe the SAME readiness function the gate uses",
  );
  const probeCount = (SOURCE.match(/routeReadiness\(/g) ?? []).length;
  assert(probeCount >= 2, "both the gate and the probe must call routeReadiness");
});

Deno.test("BUS-035: a new route starts as DRAFT, never active", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function handleCreateRouteV2"),
    SOURCE.indexOf("// ─── BUS-033"),
  );
  assert(fn.includes("'draft'"));
  assert(
    !fn.includes("'active'"),
    "creation must not activate — BUS-042 requires a complete configuration " +
      "before a route can carry children",
  );
});

// ── BUS-039: sequence integrity ──────────────────────────────────────────────

Deno.test("BUS-039/P-10: the route row lock is preserved for stop mutations", () => {
  // The pre-v2 implementation used SELECT … FOR UPDATE and understood lost
  // updates. That discipline survives the storage change.
  assert(SOURCE.includes("FOR UPDATE"));
  const fn = SOURCE.slice(
    SOURCE.indexOf("async function resequenceRouteStops"),
    SOURCE.indexOf("/** POST /transport/v2/routes/{id}/stops"),
  );
  assert(fn.includes("FOR UPDATE"), "resequencing must hold the route lock");
});

Deno.test("BUS-039: reorder requires an exact permutation", () => {
  const fn = SOURCE.slice(SOURCE.indexOf("export async function handleReorderStopsV2"));
  assert(fn.includes("permutation"));
  // A partial list would silently drop stops from the route.
  assert(fn.includes("order.length !== currentIds.size"));
  assert(
    fn.includes("new Set(order).size !== order.length"),
    "a duplicated id must be rejected too",
  );
});

Deno.test("BUS-039: reorder avoids the UNIQUE(route_id, sequence) collision", () => {
  const fn = SOURCE.slice(SOURCE.indexOf("export async function handleReorderStopsV2"));
  assert(
    fn.includes("sequence = -sequence"),
    "sequences must be parked out of range before rewriting, or a mid-shuffle " +
      "collision aborts the transaction",
  );
});

Deno.test("BUS-039: detaching a stop children are allocated to is blocked", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function handleDetachStopV2"),
    SOURCE.indexOf("export async function handleReorderStopsV2"),
  );
  assert(fn.includes("STOP_HAS_ALLOCATIONS"));
  assert(
    /Move them to another stop first/.test(fn),
    "the rejection must tell the admin what to do",
  );
});

// ── BUS-040: shared stops ────────────────────────────────────────────────────

Deno.test("BUS-040: deleting a shared stop names every route that uses it", () => {
  const fn = SOURCE.slice(
    SOURCE.indexOf("export async function handleDeleteStopV2"),
    SOURCE.indexOf("// ─── BUS-039"),
  );
  assert(fn.includes("STOP_IN_USE"));
  assert(
    fn.includes("transport_route_stop"),
    "usage across ALL routes must be counted — stops are school-owned and " +
      "shared between the AM and PM route",
  );
});

// ── Routing ──────────────────────────────────────────────────────────────────

Deno.test("BUS-033…042: v2 paths are matched BEFORE the legacy handlers", () => {
  const v2Idx = ROUTER_SOURCE.indexOf("function matchTransportV2Route");
  const legacyIdx = ROUTER_SOURCE.indexOf("function matchTransportRoute");
  assert(v2Idx >= 0 && v2Idx < legacyIdx);
  assert(
    /const v2 = matchTransportV2Route\(method, path\);\s*\n\s*if \(v2\) return v2;/
      .test(ROUTER_SOURCE),
    "a /transport/v2/* path must never fall through to a handler that writes " +
      "to the JSONB store (roadmap hard gate)",
  );
});

Deno.test("BUS-039: /stops/reorder is matched before /stops/{stopId}", () => {
  const block = ROUTER_SOURCE.slice(
    ROUTER_SOURCE.indexOf("function matchTransportV2Route"),
    ROUTER_SOURCE.indexOf("function matchTransportRoute"),
  );
  assert(
    block.indexOf("stops\\\\/reorder") < block.indexOf("stops$"),
    "'reorder' would otherwise be captured as a stop id",
  );
});

Deno.test("v2 router falls through on an unknown path without throwing", async () => {
  // CONTRACT NOTE: routeTransport returns null (not a 404) when nothing matches,
  // so the caller can try other module routers. A router that THREW here would
  // turn an unmatched path into a 500, which is the failure mode worth pinning.
  const res = await routeTransport(
    new Request("https://x.test/transport/v2/nonsense"),
    {} as never,
    "PATCH",
    "/transport/v2/nonsense",
  );
  assertEquals(res, null, "unmatched transport paths fall through to the caller");
});

Deno.test("v2 router does not hijack a legacy transport path", async () => {
  // The v2 matcher must only claim /transport/v2/*. If it captured bare
  // /transport/* the legacy handlers would become unreachable mid-rollout.
  const res = await routeTransport(
    new Request("https://x.test/transport/v2-not-really"),
    {} as never,
    "PATCH",
    "/transport/v2-not-really",
  );
  assertEquals(res, null);
});

// ── Cross-cutting ────────────────────────────────────────────────────────────

Deno.test("Phase 3: no handler touches transport_entities", () => {
  assert(
    !CODE.includes("transport_entities"),
    "Phase 3+ must build exclusively on the relational tables",
  );
});

Deno.test("Phase 3: every query binds parameters", () => {
  // A real query has a SQL verb AND a table clause. Filtering on the verb alone
  // also matched error-message templates containing the word "delete".
  const queries = [...CODE.matchAll(/`([\s\S]*?)`/g)]
    .map((m) => m[1])
    .filter((q) =>
      /\bSELECT\b[\s\S]*\bFROM\b/i.test(q) ||
      /\bINSERT\s+INTO\b/i.test(q) ||
      /\bUPDATE\b[\s\S]*\bSET\b/i.test(q) ||
      /\bDELETE\s+FROM\b/i.test(q)
    );
  assert(queries.length >= 10, `expected the handler queries, saw ${queries.length}`);
  for (const q of queries) {
    // Dynamic SET fragments are assembled from a fixed whitelist and always
    // bind their values; a template placeholder in a SQL literal would mean an
    // interpolated value.
    assert(
      !/\$\{(?!args\.length|args\.push|sets\.join|frag)/.test(q),
      `query interpolates a value instead of binding it:\n${q.slice(0, 160)}`,
    );
  }
});

Deno.test("Phase 3: every mutation emits an audit event", () => {
  const handlers = [...SOURCE.matchAll(/export async function (handle\w+V2)/g)]
    .map((m) => m[1]);
  assert(handlers.length >= 10, `expected the v2 handlers, saw ${handlers.length}`);
  const auditCount = (SOURCE.match(/emitMutationAudit\(/g) ?? []).length;
  // Readiness is a read-only probe and correctly emits nothing.
  assert(
    auditCount >= handlers.length - 1,
    `${handlers.length} handlers but only ${auditCount} audit emissions`,
  );
});

Deno.test("Phase 3: shift and direction vocabularies are validated, not trusted", () => {
  assertThrows; // referenced so the import is meaningful in this file
  assert(SOURCE.includes("INVALID_SHIFT"));
  assert(SOURCE.includes("INVALID_DIRECTION"));
  assert(SOURCE.includes('SHIFTS = new Set(["am", "pm"])'));
  assert(SOURCE.includes('DIRECTIONS = new Set(["pickup", "drop"])'));
});

// ── v2 READ surface (gap-fix) ────────────────────────────────────────────────
//
// The v2 write surface shipped before its reads, and the router had NO GET
// branch at all — so the Flutter client's fetchRoutes/fetchStops had nothing to
// route to. That is the same class of defect the audit found in the legacy
// module (a field read by three subsystems and written by none), reintroduced by
// building a client against endpoints that did not yet exist. These tests pin
// the reads so it cannot recur.

Deno.test("v2 reads: every collection GET is routed", () => {
  const block = ROUTER_SOURCE.slice(
    ROUTER_SOURCE.indexOf("function matchTransportV2Route"),
    ROUTER_SOURCE.indexOf("function matchTransportRoute"),
  );
  assert(block.includes('method === "GET"'), "the v2 matcher MUST have a GET branch");
  for (
    const [path, handler] of [
      ["/transport/v2/routes", "handleListRoutesV2"],
      ["/transport/v2/stops", "handleListStopsV2"],
      ["/transport/v2/vehicles", "handleListVehiclesV2"],
      ["/transport/v2/drivers", "handleListDriversV2"],
    ]
  ) {
    assert(block.includes(`path === "${path}"`), `${path} is not routed`);
    assert(block.includes(handler), `${handler} is not wired`);
  }
});

Deno.test("v2 reads: route detail is matched AFTER the fixed collection paths", () => {
  const block = ROUTER_SOURCE.slice(
    ROUTER_SOURCE.indexOf('if (method === "GET")'),
    ROUTER_SOURCE.indexOf('if (method === "POST")'),
  );
  // Otherwise /routes/unstaffed-style fixed segments would be captured as ids.
  assert(
    block.indexOf('path === "/transport/v2/vehicles"') <
      block.indexOf("handleGetRouteV2"),
    "the {id} pattern must come last",
  );
});

Deno.test("v2 reads: the route projection resolves the DATED assignment", async () => {
  const src = await Deno.readTextFile(
    new URL("./transport_v2_read_handlers.ts", import.meta.url),
  );
  assert(
    src.includes("transport_effective_assignment(r.id, $3::date)"),
    "a route read must resolve WHO drives it on the requested date, or today " +
      "and tomorrow would wrongly return the same crew",
  );
  // An unassigned route must come back as NULL, not an empty object — the
  // client distinguishes 'unstaffed' from 'not loaded' on exactly this.
  assert(src.includes("CASE WHEN asg.id IS NULL THEN NULL"));
});

Deno.test("v2 reads: derived counts are SQL aggregates, not fetched rows", async () => {
  const src = await Deno.readTextFile(
    new URL("./transport_v2_read_handlers.ts", import.meta.url),
  );
  assert(src.includes("count(*) FROM transport_allocation"));
  assert(src.includes("count(*) FROM transport_route_stop"));
  // The banned shape is measuring a FETCHED result set. `s.length` inside a
  // path-segment filter is unrelated, so match the actual anti-pattern.
  assert(!/rows\.length|items\.length/.test(src),
      "no count may be derived from a fetched row array");
});

Deno.test("v2 reads: pickers carry compliance state so they can warn early", async () => {
  const src = await Deno.readTextFile(
    new URL("./transport_v2_read_handlers.ts", import.meta.url),
  );
  // A picker that offers an uninsured bus and only fails on submit wastes the
  // admin's time and teaches them to ignore the error (BUS-054).
  assert(src.includes('AS "expiredDocument"'));
  assert(src.includes('AS "licenceExpired"'));
  // Offering a driver who is on leave is how a school "arranges cover" and
  // still has no driver (BUS-050).
  assert(src.includes('AS "unavailableKind"'));
  assert(src.includes('AS "assignedRouteName"'));
});

Deno.test("v2 reads: coordinates are projected as lat/lng, null when absent", async () => {
  const src = await Deno.readTextFile(
    new URL("./transport_v2_read_handlers.ts", import.meta.url),
  );
  assert(src.includes("ST_Y(s.location::geometry)"));
  assert(src.includes("ST_X(s.location::geometry)"));
  // NEVER 0 for a missing location — that is the legacy default the client
  // GeoPoint validator exists to reject.
  assert(src.includes("WHEN s.location IS NULL THEN NULL"));
});

Deno.test("v2 reads: unlocated stops are returned FIRST", async () => {
  const src = await Deno.readTextFile(
    new URL("./transport_v2_read_handlers.ts", import.meta.url),
  );
  assert(src.includes("(s.status = 'needs_location') DESC"));
});

Deno.test("v2 reads: serviceDate is validated, never interpolated", async () => {
  const src = await Deno.readTextFile(
    new URL("./transport_v2_read_handlers.ts", import.meta.url),
  );
  assert(src.includes("test(raw)"), "serviceDate must be format-validated");
  assert(src.includes("d{4}"), "the validator must pin a YYYY-MM-DD shape");
  assert(src.includes("$3::date"), "the date must be a bound parameter");
});

Deno.test("v2 reads: transport read permission is required", async () => {
  const src = await Deno.readTextFile(
    new URL("./transport_v2_read_handlers.ts", import.meta.url),
  );
  assert(src.includes('requirePermission(claims, "viewTransport")'));
  assert(src.includes("requireSchoolOperationalScope"));
});
