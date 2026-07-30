// BUS-055…BUS-060 — allocation integrity, and BUS-059's parent read.
//
// BUS-059 IS THE ONE THAT MATTERS MOST. The same legacy call caused all three of
// the audit's original parent P0s:
//   * it 403'd in the live build (parent role held no transport permission and
//     the endpoint demanded school scope);
//   * it would have LEAKED the school roster — other children's names, admission
//     numbers, class, bus and PICKUP STOP LOCATIONS — to any parent's device;
//   * it read page 1 of 20 and scanned client-side, finding the right child for
//     roughly 2.5% of parents in an 800-student school.
//
// These tests pin the properties that make each of those unrepresentable rather
// than merely fixed.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const SRC = await Deno.readTextFile(
  new URL("./transport_v2_allocation_handlers.ts", import.meta.url),
);
const ROUTER = await Deno.readTextFile(
  new URL("./transport_router.ts", import.meta.url),
);

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
const CODE = codeOnly(SRC);

function fn(name: string, until: string): string {
  const start = SRC.indexOf(`export async function ${name}`);
  assert(start >= 0, `handler ${name} not found`);
  const end = SRC.indexOf(until, start);
  return SRC.slice(start, end > start ? end : undefined);
}

// ── BUS-059: the parent read ────────────────────────────────────────────────

Deno.test("BUS-059: the parent endpoint takes ONE childId and has no list form", () => {
  const h = fn("handleParentChildAllocationV2", "");
  assert(h.includes('searchParams.get("childId")'));
  assert(h.includes("LIMIT 1"), "must return at most one allocation");
  assert(h.includes("a.student_id = $1::uuid"), "must key on one student");
  // A list form would reintroduce the leak by construction.
  assert(
    !/export async function handleParent\w*Allocations/.test(SRC),
    "no parent-facing LIST endpoint may exist",
  );
});

Deno.test("BUS-059: a missing childId is refused, never defaulted to a first child", () => {
  const h = fn("handleParentChildAllocationV2", "");
  assert(h.includes("childId is required"));
  // Guessing which child a parent meant is how the legacy path ended up
  // scanning a school-wide list.
  assert(!/child_ids\s*\[\s*0\s*\]/.test(h), "must not default to child_ids[0]");
});

Deno.test("BUS-059: it runs on PARENT scope — the fix for the 403", () => {
  const h = fn("handleParentChildAllocationV2", "");
  assert(h.includes('auth.claims.scope !== "parent"'));
  assert(h.includes('requirePermission(auth.claims, "viewChildTransport")'));
  // It must NOT demand school scope; that requirement is what 403'd every parent.
  assert(!h.includes("requireSchoolOperationalScope"));
  assert(!h.includes('"viewTransport"'));
});

Deno.test("BUS-059: guardianship is checked TWICE — token, then database", () => {
  const h = fn("handleParentChildAllocationV2", "");
  // Cheap token check first, so a foreign id never reaches a query.
  assert(h.includes("child_ids ?? []).includes(childId)"));
  // Then the authoritative check in SQL, so a forged token still cannot read.
  assert(h.includes("FROM student_guardians sg"));
  assert(h.includes("sg.status = 'active'"));
  assert(h.includes("sg.guardian_user_id = $4::uuid"));
});

Deno.test("BUS-059: no allocation is a legitimate answer, not an error", () => {
  const h = fn("handleParentChildAllocationV2", "");
  // The child may walk or be driven. A 404 here would render as a failure screen.
  assert(h.includes("rows[0] ?? {}"));
});

Deno.test("BUS-059: the parent route is NOT mounted under /transport/*", () => {
  // /transport/* is school-scoped. Mounting a parent endpoint inside it is how
  // the legacy path acquired its school-scope requirement.
  assert(ROUTER.includes('path === "/parent/transport/allocation"'));
  const idx = ROUTER.indexOf('path === "/parent/transport/allocation"');
  const guardIdx = ROUTER.indexOf('if (!path.startsWith("/transport")) return null;');
  assert(idx < guardIdx, "the parent route must be matched BEFORE the /transport guard");
});

Deno.test("BUS-059: the projection carries no other child's data", () => {
  const h = fn("handleParentChildAllocationV2", "");
  // Only the child's own route/stops/crew. No roster, no sibling, no class list.
  for (const forbidden of ["students st", "display_name", "admission"]) {
    assert(!h.includes(forbidden), `parent projection must not select ${forbidden}`);
  }
});

// ── BUS-055: stops are FKs and must be on the route ─────────────────────────

Deno.test("BUS-055: allocation takes stop IDs, never stop names", () => {
  const h = fn("handleAllocateStudentV2", "/**");
  assert(h.includes('requireStr(body, "pickupStopId"'));
  assert(h.includes('requireStr(body, "dropStopId"'));
  // The legacy free-text field is what made a child's pickup point depend on
  // an admin's typing.
  assert(!/requireStr\(body, "pickupStop"[^I]/.test(h));
});

Deno.test("BUS-055: a stop not on the route is rejected", () => {
  assert(CODE.includes("STOP_NOT_ON_ROUTE"));
  assert(CODE.includes("assertStopOnRoute"));
  // Both ends are checked — a child could otherwise be dropped somewhere the
  // bus never visits.
  const h = fn("handleAllocateStudentV2", "/**");
  assert(h.includes('assertStopOnRoute(db, routeId, pickupStopId, "pickup")'));
  assert(h.includes('assertStopOnRoute(db, routeId, dropStopId, "drop")'));
});

// ── BUS-056: one bus per child per shift ───────────────────────────────────

Deno.test("BUS-056: a duplicate allocation returns an actionable 409, not a 500", () => {
  const h = fn("handleAllocateStudentV2", "/**");
  assert(h.includes("ALLOCATION_CONFLICT"));
  assert(h.includes("isUniqueViolation"));
  // The message must name the correct action.
  assert(
    h.includes("Transfer them") ||
      h.replace(/"\s*\+\s*\n?\s*"/g, "").includes("Transfer them"),
  );
  assert(
    h.replace(/"\s*\+\s*\n?\s*"/g, "").includes("cannot ride two buses"),
    "the message must explain WHY, or it reads as an arbitrary rule",
  );
});

// ── BUS-044: the capacity guard actually runs ──────────────────────────────

Deno.test("BUS-044: capacity is checked under the route lock", () => {
  const h = fn("handleAllocateStudentV2", "/**");
  const lockIdx = h.indexOf("lockRoute");
  const capIdx = h.indexOf("routeCapacity");
  assert(lockIdx >= 0 && capIdx > lockIdx, "the lock must precede the count");
  assert(h.includes("CAPACITY_EXCEEDED"));
});

Deno.test("BUS-044: a capacity override is audited SEPARATELY", () => {
  assert(CODE.includes("transport.capacity.overridden"));
  // "Who authorised the 49th child on a 48-seat bus" must stay answerable.
  const h = fn("handleAllocateStudentV2", "/**");
  assert(h.includes("capacityOverridden"));
});

// ── BUS-057: transfer is the only correct move ─────────────────────────────

Deno.test("BUS-057: transfer locks BOTH routes in a stable order", () => {
  const h = fn("handleTransferAllocationV2", "/**");
  // Two concurrent transfers in opposite directions would otherwise deadlock.
  assert(h.includes(".sort()"));
  assert(h.includes("lockRoute"));
  assert(h.includes("second !== first"), "must not lock the same route twice");
});

Deno.test("BUS-057: transfer re-validates stops against the TARGET route", () => {
  const h = fn("handleTransferAllocationV2", "/**");
  assert(h.includes("assertStopOnRoute(db, targetRouteId, pickupStopId"));
  assert(h.includes("assertStopOnRoute(db, targetRouteId, dropStopId"));
});

// ── BUS-060: bulk allocation keeps its partial-success semantics ───────────

Deno.test("BUS-060: one bad row does not lose the rest of the class", () => {
  const h = fn("handleBulkAllocateV2", "/**");
  // A savepoint per row: without it a single conflict aborts the transaction
  // and thirty-nine successful allocations are rolled back.
  assert(h.includes("SAVEPOINT alloc_row"));
  assert(h.includes("ROLLBACK TO SAVEPOINT alloc_row"));
  assert(h.includes("skipped.push"));
  assert(h.includes("already_allocated_for_this_shift"));
});

Deno.test("BUS-060: capacity is checked ONCE for the whole batch", () => {
  const h = fn("handleBulkAllocateV2", "/**");
  assertEquals((h.match(/routeCapacity\(/g) ?? []).length, 1);
  assert(h.includes("cap.current + targets.length"));
});

// ── BUS-058: roster is an indexed join ────────────────────────────────────

Deno.test("BUS-058: the roster is one query ordered by stop sequence", () => {
  const h = fn("handleRouteRosterV2", "/**");
  assert(h.includes("ORDER BY rs.sequence"));
  // The legacy version loaded every allocation in the school and grouped in JS
  // by exact stop-NAME match.
  assert(!h.includes("findAll"));
  assert(h.includes("rs.route_id = $1::uuid"), "must be bounded to one route");
});

Deno.test("BUS-058: a stop with no students is RETAINED in the roster", () => {
  const h = fn("handleRouteRosterV2", "/**");
  assert(h.includes("LEFT JOIN transport_allocation"));
  // An empty stop is information — nobody boards there — not absent data.
  assert(h.includes("if (r.studentId)"));
});

// ── Cross-cutting ─────────────────────────────────────────────────────────

Deno.test("Phase 6: no handler touches transport_entities", () => {
  assert(!CODE.includes("transport_entities"));
});

Deno.test("Phase 6: every query binds parameters", () => {
  const queries = [...CODE.matchAll(/`([\s\S]*?)`/g)]
    .map((m) => m[1])
    .filter((q) =>
      /\bSELECT\b[\s\S]*\bFROM\b/i.test(q) ||
      /\bINSERT\s+INTO\b/i.test(q) ||
      /\bUPDATE\b[\s\S]*\bSET\b/i.test(q)
    );
  assert(queries.length >= 6, `expected the queries, saw ${queries.length}`);
  for (const q of queries) {
    assert(!/\$\{/.test(q), `query interpolates:\n${q.slice(0, 140)}`);
  }
});

Deno.test("Phase 6: allocations are ENDED, never hard-deleted", () => {
  const h = fn("handleEndAllocationV2", "/**");
  assert(h.includes("status = 'ended'"));
  assert(h.includes("effective_to = CURRENT_DATE"));
  // A boarding record from last term must still resolve the stop the child used
  // at the time.
  assert(!/DELETE FROM transport_allocation/i.test(CODE));
});

Deno.test("Phase 6: bulk and single allocation routes do not collide", () => {
  const block = ROUTER.slice(
    ROUTER.indexOf("function matchTransportV2Route"),
    ROUTER.indexOf("function matchTransportRoute"),
  );
  assert(
    block.indexOf('"/transport/v2/allocations/bulk"') <
      block.indexOf('"/transport/v2/allocations"'),
    "'bulk' must be matched before the bare collection path",
  );
});
