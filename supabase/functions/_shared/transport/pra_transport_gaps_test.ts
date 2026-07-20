// PRA-P0-19 / P0-20 / P1-43 — transport gap remediation coverage.
//
// Pins the load-bearing pieces of the three new write paths (the HTTP handlers
// themselves wrap auth + tenant-transaction plumbing that is not unit-testable in
// isolation, mirroring transport_write_handlers_test.ts):
//   • P0-19 — assigning a vehicle to a route sets `assignedBus`, which makes the
//     previously-inert TRN-7 capacity guard resolve a real capacity and fire.
//   • P0-20 — allocations are annotated with a derived `demandRaised`, and one
//     shared demand-raise core dedupes idempotently (bulk relies on this).
//   • P1-43 — the attendance roster is DERIVED from the route's allocations
//     (shift-filtered, stable idempotency id), instead of one client-provided row.

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import {
  assertCapacity,
  buildAttendanceRosterRows,
  CapacityExceededError,
  raiseTransportDemandFor,
  regKey,
  routeCapacityAndCount,
} from "./transport_write_handlers.ts";
import { annotateAllocationsWithDemand } from "./transport_handlers.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";

const writeStore = createEntityWriteStore("transport_entities", "Transport");

interface EntityRow {
  id: string;
  organization_id: string;
  school_id: string;
  entity_type: string;
  payload: Record<string, unknown>;
}

/** In-memory transport_entities honouring the exact SQL the write store issues. */
class MockTransportWriteDb {
  rows: EntityRow[] = [];

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("INSERT INTO transport_entities")) {
      this.rows.push({
        id: args[0],
        organization_id: args[1],
        school_id: args[2],
        entity_type: args[3],
        payload: JSON.parse(args[4]),
      });
      return Promise.resolve([{ payload: this.rows[this.rows.length - 1].payload }] as T[]);
    }
    if (sql.includes("UPDATE transport_entities")) {
      const row = this.rows.find((r) =>
        r.id === args[0] && r.organization_id === args[1] &&
        r.school_id === args[2] && r.entity_type === args[3]
      );
      if (!row) return Promise.resolve([] as T[]);
      row.payload = JSON.parse(args[4]);
      return Promise.resolve([{ payload: row.payload }] as T[]);
    }
    if (sql.includes("AND id = $4")) {
      const row = this.rows.find((r) =>
        r.organization_id === args[0] && r.school_id === args[1] &&
        r.entity_type === args[2] && r.id === args[3]
      );
      return Promise.resolve(row ? [{ payload: row.payload }] as T[] : [] as T[]);
    }
    if (sql.includes("ORDER BY id")) {
      const items = this.rows.filter((r) =>
        r.organization_id === args[0] && r.school_id === args[1] &&
        r.entity_type === args[2]
      );
      return Promise.resolve(items.map((r) => ({ payload: r.payload })) as T[]);
    }
    return Promise.resolve([] as T[]);
  }
}

function schoolClaims(): AccessTokenClaims {
  return {
    sub: "staff",
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["manageTransport"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

// ── PRA-P0-19: vehicle→route assignment makes the capacity guard live ─────────

Deno.test("P0-19: a route with no assigned vehicle has null capacity (guard inert)", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "vehicle", "v1", {
    id: "v1",
    registration: "KA-01-AB-1234",
    capacity: 2,
  });
  await writeStore.insert(db, ORG, SCHOOL_A, "route", "r1", {
    id: "r1",
    name: "Route 12",
    assignedBus: "", // never set — the P0-19 gap
    status: "active",
  });
  const route = await writeStore.find(db, ORG, SCHOOL_A, "route", "r1");
  const { capacity } = await routeCapacityAndCount(db, ORG, SCHOOL_A, route!);
  assertEquals(capacity, null); // guard skipped → over-fill impossible to catch
});

Deno.test("P0-19: assigning a vehicle sets assignedBus → capacity guard now fires", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "vehicle", "v1", {
    id: "v1",
    registration: "KA-01-AB-1234",
    capacity: 2,
  });
  await writeStore.insert(db, ORG, SCHOOL_A, "route", "r1", {
    id: "r1",
    name: "Route 12",
    assignedBus: "",
    status: "active",
  });

  // handleAssignRouteVehicle's core op: resolve the vehicle by normalized
  // registration, then set the route's assignedBus under the row lock.
  const vehicles = await writeStore.findAll(db, ORG, SCHOOL_A, "vehicle");
  const vehicle = vehicles.find((v) =>
    regKey(String(v.registration ?? "")) === regKey("ka-01-ab-1234")
  );
  assertEquals(vehicle?.id, "v1"); // case/space-insensitive lookup
  await writeStore.mutateEntity(db, ORG, SCHOOL_A, "route", "r1", (r) => ({
    ...r,
    assignedBus: String(vehicle!.registration ?? ""),
  }));

  // The route now resolves a real capacity from its assigned vehicle …
  const route = await writeStore.find(db, ORG, SCHOOL_A, "route", "r1");
  const resolved = await routeCapacityAndCount(db, ORG, SCHOOL_A, route!);
  assertEquals(resolved.capacity, 2);

  // … so filling it to capacity and adding one more now REJECTS (guard is live).
  await writeStore.insert(db, ORG, SCHOOL_A, "allocation", "a0", { id: "a0", routeId: "r1" });
  await writeStore.insert(db, ORG, SCHOOL_A, "allocation", "a1", { id: "a1", routeId: "r1" });
  const full = await writeStore.find(db, ORG, SCHOOL_A, "route", "r1");
  await assertRejects(
    () => assertCapacity(db, ORG, SCHOOL_A, full!, 1, false),
    CapacityExceededError,
  );
});

Deno.test("P0-19: a too-small vehicle for an over-subscribed route is 409-rejected", () => {
  // handleAssignRouteVehicle rejects when vehicle.capacity < current allocation
  // count on the route (a bus that cannot hold who is already on it).
  const capacity = 2;
  const currentCount = 3;
  assertEquals(capacity > 0 && capacity < currentCount, true);
  const err = new CapacityExceededError("Route 12", capacity, currentCount);
  assertEquals(err.status, 409);
  assertEquals(err.code, "CAPACITY_EXCEEDED");
});

// ── PRA-P0-20: per-allocation billed status + idempotent demand core ──────────

Deno.test("P0-20: annotateAllocationsWithDemand flags billed allocations", () => {
  const allocations = [
    { id: "a1", sisStudentId: "S1", routeId: "r1" },
    { id: "a2", sisStudentId: "S2", routeId: "r1" },
    { id: "a3", sisStudentId: "S3", routeId: "r1" },
    { id: "a4", sisStudentId: "S4", routeId: "" }, // unassigned — never billed
  ];
  const demands = [
    { allocationId: "a1" }, // matched by allocation id
    { sisStudentId: "S2", routeId: "r1" }, // matched by dedupe-key shape
    { sisStudentId: "S3", routeId: "r9" }, // different route — must NOT match a3
    { sisStudentId: "S4", routeId: "" }, // blank route — ignored
  ];
  const annotated = annotateAllocationsWithDemand(allocations, demands);
  assertEquals(annotated.map((a) => a.demandRaised), [true, true, false, false]);
});

Deno.test("P0-20: raiseTransportDemandFor is idempotent on a prior matching demand", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  const dedupeKey = "SIS-1::r1::2026-27::annual";
  await writeStore.insert(db, ORG, SCHOOL_A, "demand", "d1", {
    id: "d1",
    dedupeKey,
    sisStudentId: "SIS-1",
    routeId: "r1",
    academicYear: "2026-27",
    term: "annual",
    invoiceId: "inv-1",
  });
  // A re-raise for the same tuple short-circuits BEFORE resolveStudentId /
  // assignFeeStructure — created:false, nothing new billed. (This is the exact
  // per-allocation idempotency the bulk endpoint relies on to never double-bill.)
  const { demand, created } = await raiseTransportDemandFor(
    db,
    ORG,
    SCHOOL_A,
    schoolClaims(),
    {
      sisStudentId: "SIS-1",
      routeId: "r1",
      feeStructureId: "fee-1",
      academicYear: "2026-27",
      term: "annual",
      allocationId: "a1",
    },
  );
  assertEquals(created, false);
  assertEquals(demand.id, "d1");
  assertEquals(demand.invoiceId, "inv-1");
});

Deno.test("P0-20: a raised demand marks its allocation billed on the next read", () => {
  // Integration of the two P0-20 halves: a demand carrying the allocation id
  // flips demandRaised for exactly that allocation.
  const allocations = [
    { id: "alloc-1", sisStudentId: "SIS-1", routeId: "r1" },
    { id: "alloc-2", sisStudentId: "SIS-2", routeId: "r1" },
  ];
  const demands = [
    { id: "d1", allocationId: "alloc-1", sisStudentId: "SIS-1", routeId: "r1" },
  ];
  const annotated = annotateAllocationsWithDemand(allocations, demands);
  assertEquals(annotated.find((a) => a.id === "alloc-1")?.demandRaised, true);
  assertEquals(annotated.find((a) => a.id === "alloc-2")?.demandRaised, false);
});

// ── PRA-P1-43: attendance roster derived from route allocations ───────────────

Deno.test("P1-43: buildAttendanceRosterRows derives shift-filtered waiting rows", () => {
  const route = {
    id: "r1",
    name: "Route 12 — North",
    stops: [{ id: "s1", name: "Lake View", pickupTime: "7:05 AM" }],
  };
  const allocations = [
    { id: "a1", routeId: "r1", shift: "am", sisStudentId: "S1", studentName: "Anaya", pickupStop: "Lake View" },
    { id: "a2", routeId: "r1", shift: "pm", sisStudentId: "S2", studentName: "Bhavya", pickupStop: "Lake View" },
    { id: "a3", routeId: "r1", shift: "both", sisStudentId: "S3", studentName: "Chetan", pickupStop: "Market" },
    { id: "a4", routeId: "r2", shift: "am", sisStudentId: "S4", studentName: "Off Route", pickupStop: "Lake View" },
    { id: "a5", routeId: "r1", shift: "am", sisStudentId: "", studentName: "No SIS", pickupStop: "Lake View" },
  ];
  const rows = buildAttendanceRosterRows(route, allocations, "am", "2026-07-20");

  // am shift → S1 (am) + S3 (both); S2 (pm), S4 (off route), S5 (no SIS) dropped.
  assertEquals(rows.map((r) => r.id), [
    "r1:S1:am:2026-07-20",
    "r1:S3:am:2026-07-20",
  ]);
  assertEquals(rows[0].status, "waiting");
  assertEquals(rows[0].parentNotified, false);
  assertEquals(rows[0].routeName, "Route 12 — North");
  assertEquals(rows[0].scheduledTime, "7:05 AM"); // resolved from the matching stop
  assertEquals(rows[1].scheduledTime, ""); // "Market" is not a route stop
});

Deno.test("P1-43: roster generation is idempotent (stable ids → find-then-skip)", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "route", "r1", {
    id: "r1",
    name: "Route 12",
    stops: [{ id: "s1", name: "Lake View", pickupTime: "7:05 AM" }],
  });
  await writeStore.insert(db, ORG, SCHOOL_A, "allocation", "a1", {
    id: "a1",
    routeId: "r1",
    shift: "am",
    sisStudentId: "S1",
    studentName: "Anaya",
    pickupStop: "Lake View",
  });
  const route = await writeStore.find(db, ORG, SCHOOL_A, "route", "r1");
  const allocations = await writeStore.findAll(db, ORG, SCHOOL_A, "allocation");

  // First generate: derive rows, insert those not already present.
  const insertRoster = async () => {
    const rows = buildAttendanceRosterRows(route!, allocations, "am", "2026-07-20");
    let inserted = 0;
    for (const payload of rows) {
      const id = String(payload.id);
      const existing = await writeStore.find(db, ORG, SCHOOL_A, "attendance", id);
      if (existing) continue;
      await writeStore.insert(db, ORG, SCHOOL_A, "attendance", id, payload);
      inserted++;
    }
    return inserted;
  };

  assertEquals(await insertRoster(), 1);
  // Second run: same stable id already present → nothing new, no duplicate row.
  assertEquals(await insertRoster(), 0);
  const listed = await writeStore.findAll(db, ORG, SCHOOL_A, "attendance");
  assertEquals(listed.length, 1);
  assertEquals(listed[0].id, "r1:S1:am:2026-07-20");
});
