// W4 — Transport assignment history (Owner decision #5, FINAL/approved): full
// history preservation via Valid-From / Valid-To effective dating. A student's
// transport assignment is NEVER overwritten-in-place; the allocation open on ANY
// past date is reconstructable.
//
// Proven DB-free against a faithful in-memory transport_allocation_history —
// same fake-TenantQueryClient seam as transport_read_repository_test.ts and
// trn9_demand_race_test.ts. The mock honours the exact SQL the repository issues
// (open-period SELECT … FOR UPDATE, the close UPDATE, the open-period INSERT, the
// as-of range SELECT, the timeline SELECT) AND enforces the open-period PARTIAL
// UNIQUE INDEX (transport_allocation_history_open_uniq) exactly like Postgres.
//
// Coverage:
//   • a re-assignment CLOSEs the prior period and OPENs a new one — the OLD
//     period is preserved (route/stop/valid_from immutable), never overwritten;
//   • as-of-date reconstruction returns the correct historical allocation across
//     ≥2 changes (and null before the first period / for a stopped student);
//   • the full per-student timeline lists every period in order;
//   • a re-assign to the SAME route/stop is a timeline no-op (no churn);
//   • stopping transport CLOSEs the open period (no new period);
//   • the concurrency guard: a racing double-open is rejected (409 conflict) and
//     NEVER persisted — no two open periods can ever coexist.

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  AllocationHistoryConflictError,
  closeOpenAllocation,
  getAllocationAsOf,
  getStudentAllocationAsOf,
  listAllocationTimeline,
  listStudentAllocationTimeline,
  recordAllocationChange,
} from "./transport_allocation_history_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";

const T0 = "2026-01-01T00:00:00.000Z";
const T1 = "2026-03-01T00:00:00.000Z";
const T2 = "2026-06-01T00:00:00.000Z";

interface HistoryRow {
  _seq: number;
  id: string;
  organization_id: string;
  school_id: string;
  allocation_id: string;
  sis_student_id: string | null;
  route_id: string | null;
  pickup_stop: string | null;
  drop_stop: string | null;
  shift: string | null;
  payload: Record<string, unknown>;
  valid_from: string;
  valid_to: string | null;
  changed_by: string | null;
}

/** True when a period is open on `asOf` (valid_from <= asOf < valid_to|∞). */
function openOn(row: HistoryRow, asOf: string): boolean {
  const at = Date.parse(asOf);
  return Date.parse(row.valid_from) <= at &&
    (row.valid_to === null || Date.parse(row.valid_to) > at);
}

/**
 * In-memory transport_allocation_history that speaks the repository's exact SQL
 * and enforces the open-period partial unique index. `failNextInsert` injects a
 * racing concurrent double-open (the index firing 23505), mirroring
 * MockDemandRaceDb in trn9_demand_race_test.ts.
 */
class MockHistoryDb {
  rows: HistoryRow[] = [];
  insertAttempts = 0;
  failNextInsert = false;
  private seq = 0;

  private uniqueViolation(): Error {
    const err = new Error(
      'duplicate key value violates unique constraint "transport_allocation_history_open_uniq"',
    ) as Error & { code: string; fields: { code: string } };
    err.code = "23505";
    err.fields = { code: "23505" };
    return err;
  }

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (
      sql.startsWith("SAVEPOINT") ||
      sql.startsWith("RELEASE SAVEPOINT") ||
      sql.startsWith("ROLLBACK TO SAVEPOINT")
    ) {
      return Promise.resolve([] as T[]);
    }

    if (sql.includes("INSERT INTO transport_allocation_history")) {
      this.insertAttempts += 1;
      if (this.failNextInsert) {
        this.failNextInsert = false;
        throw this.uniqueViolation();
      }
      const [
        id,
        org,
        school,
        allocationId,
        sis,
        route,
        pickup,
        drop,
        shift,
        payloadJson,
        validFrom,
        changedBy,
      ] = args;
      // The INSERT always opens a period (valid_to = NULL literal). Enforce the
      // partial unique index: at most one open period per (org, school, allocation).
      const dup = this.rows.find((r) =>
        r.organization_id === org && r.school_id === school &&
        r.allocation_id === allocationId && r.valid_to === null
      );
      if (dup) throw this.uniqueViolation();
      const row: HistoryRow = {
        _seq: this.seq++,
        id,
        organization_id: org,
        school_id: school,
        allocation_id: allocationId,
        sis_student_id: sis ?? null,
        route_id: route ?? null,
        pickup_stop: pickup ?? null,
        drop_stop: drop ?? null,
        shift: shift ?? null,
        payload: JSON.parse(payloadJson),
        valid_from: validFrom,
        valid_to: null,
        changed_by: changedBy ?? null,
      };
      this.rows.push(row);
      return Promise.resolve([row] as T[]);
    }

    if (sql.includes("UPDATE transport_allocation_history")) {
      // Close the currently-open period (both the record-change close and
      // closeOpenAllocation). args: [$1 org, $2 school, $3 allocation_id, $4 valid_to].
      const [org, school, allocationId, validTo] = args;
      const closed = this.rows.filter((r) =>
        r.organization_id === org && r.school_id === school &&
        r.allocation_id === allocationId && r.valid_to === null
      );
      for (const r of closed) r.valid_to = validTo;
      return Promise.resolve(closed as T[]);
    }

    if (sql.includes("FROM transport_allocation_history")) {
      const org = args[0];
      const school = args[1];
      const scoped = this.rows.filter((r) =>
        r.organization_id === org && r.school_id === school
      );

      // Open-period lookup (SELECT … FOR UPDATE).
      if (sql.includes("FOR UPDATE")) {
        const allocationId = args[2];
        const open = scoped.filter((r) =>
          r.allocation_id === allocationId && r.valid_to === null
        );
        return Promise.resolve(open as T[]);
      }

      // As-of range read (allocation OR student).
      if (sql.includes("valid_from <= $4")) {
        const key = args[2];
        const asOf = args[3];
        const byKey = sql.includes("sis_student_id = $3")
          ? scoped.filter((r) => r.sis_student_id === key)
          : scoped.filter((r) => r.allocation_id === key);
        const match = byKey
          .filter((r) => openOn(r, asOf))
          .sort((a, b) => Date.parse(b.valid_from) - Date.parse(a.valid_from));
        return Promise.resolve((match[0] ? [match[0]] : []) as T[]);
      }

      // Full timeline (allocation OR student), oldest first.
      const key = args[2];
      const byKey = sql.includes("sis_student_id = $3")
        ? scoped.filter((r) => r.sis_student_id === key)
        : scoped.filter((r) => r.allocation_id === key);
      const ordered = byKey.sort((a, b) =>
        Date.parse(a.valid_from) - Date.parse(b.valid_from) || a._seq - b._seq
      );
      return Promise.resolve(ordered as T[]);
    }

    throw new Error(`Unhandled SQL in MockHistoryDb: ${sql.slice(0, 90)}`);
  }
}

function db(mock: MockHistoryDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

/** Convenience: record an assignment period for one allocation. */
function assign(
  mock: MockHistoryDb,
  allocationId: string,
  routeId: string,
  changeDate: string,
  extra: { sisStudentId?: string; pickupStop?: string; dropStop?: string } = {},
) {
  return recordAllocationChange(
    db(mock),
    ORG,
    SCHOOL,
    allocationId,
    {
      sisStudentId: extra.sisStudentId ?? "SIS-1",
      routeId,
      pickupStop: extra.pickupStop ?? "Pickup",
      dropStop: extra.dropStop ?? "School Gate",
      shift: "both",
      payload: { id: allocationId, routeId, routeName: `Route ${routeId}` },
    },
    { changeDate, changedBy: "user-1" },
  );
}

Deno.test("W4: a re-assignment CLOSEs the prior period and OPENs a new one — the OLD period is never overwritten", async () => {
  const mock = new MockHistoryDb();

  const first = await assign(mock, "alloc-1", "route-A", T0);
  assertEquals(first.changed, true);
  assertEquals(first.record.routeId, "route-A");
  assertEquals(first.record.validFrom, T0);
  assertEquals(first.record.validTo, null); // open

  const second = await assign(mock, "alloc-1", "route-B", T1);
  assertEquals(second.changed, true);
  assertEquals(second.record.routeId, "route-B");
  assertEquals(second.record.validFrom, T1);
  assertEquals(second.record.validTo, null); // new open period

  // Two distinct rows now exist — the re-assign INSERTed, it did not UPDATE in place.
  assertEquals(mock.rows.length, 2);

  // The OLD period is PRESERVED: same route, same start, only CLOSEd at the change
  // date. Its historical route/stop snapshot was never mutated.
  const timeline = await listAllocationTimeline(db(mock), ORG, SCHOOL, "alloc-1");
  assertEquals(timeline.length, 2);
  assertEquals(timeline[0].routeId, "route-A");
  assertEquals(timeline[0].validFrom, T0);
  assertEquals(timeline[0].validTo, T1); // closed exactly at the change date
  assertEquals(timeline[0].payload.routeName, "Route route-A");
  assertEquals(timeline[1].routeId, "route-B");
  assertEquals(timeline[1].validTo, null);

  // Exactly ONE open period at any time.
  assertEquals(timeline.filter((r) => r.validTo === null).length, 1);
});

Deno.test("W4: as-of-date read reconstructs the correct historical allocation across ≥2 changes", async () => {
  const mock = new MockHistoryDb();
  await assign(mock, "alloc-1", "route-A", T0); // [T0, T1)
  await assign(mock, "alloc-1", "route-B", T1); // [T1, T2)
  await assign(mock, "alloc-1", "route-C", T2); // [T2, ∞)

  // Before any assignment → nothing was in effect.
  assertEquals(
    await getAllocationAsOf(db(mock), ORG, SCHOOL, "alloc-1", "2025-12-01T00:00:00.000Z"),
    null,
  );
  // Inside period A.
  assertEquals(
    (await getAllocationAsOf(db(mock), ORG, SCHOOL, "alloc-1", "2026-02-01T00:00:00.000Z"))?.routeId,
    "route-A",
  );
  // Exactly on the boundary T1 → the NEW period (valid_from <= d, prior closed at d).
  assertEquals(
    (await getAllocationAsOf(db(mock), ORG, SCHOOL, "alloc-1", T1))?.routeId,
    "route-B",
  );
  // Inside period B.
  assertEquals(
    (await getAllocationAsOf(db(mock), ORG, SCHOOL, "alloc-1", "2026-04-01T00:00:00.000Z"))?.routeId,
    "route-B",
  );
  // Inside the currently-open period C.
  const now = await getAllocationAsOf(db(mock), ORG, SCHOOL, "alloc-1", "2026-09-01T00:00:00.000Z");
  assertEquals(now?.routeId, "route-C");
  assertEquals(now?.validTo, null);
});

Deno.test("W4: per-student full timeline lists every assignment period in order", async () => {
  const mock = new MockHistoryDb();
  await assign(mock, "alloc-1", "route-A", T0, { sisStudentId: "SIS-42" });
  await assign(mock, "alloc-1", "route-B", T1, { sisStudentId: "SIS-42" });
  await assign(mock, "alloc-1", "route-C", T2, { sisStudentId: "SIS-42" });
  // A different student is not mixed in.
  await assign(mock, "alloc-9", "route-Z", T1, { sisStudentId: "SIS-99" });

  const timeline = await listStudentAllocationTimeline(db(mock), ORG, SCHOOL, "SIS-42");
  assertEquals(timeline.map((r) => r.routeId), ["route-A", "route-B", "route-C"]);
  assertEquals(timeline.map((r) => r.validTo), [T1, T2, null]);

  // Per-student as-of works the same way.
  assertEquals(
    (await getStudentAllocationAsOf(db(mock), ORG, SCHOOL, "SIS-42", "2026-04-01T00:00:00.000Z"))?.routeId,
    "route-B",
  );
});

Deno.test("W4: re-assigning to the SAME route/stop is a timeline no-op (no churn, no new period)", async () => {
  const mock = new MockHistoryDb();
  await assign(mock, "alloc-1", "route-A", T0);
  const repeat = await assign(mock, "alloc-1", "route-A", T1); // identical assignment
  assertEquals(repeat.changed, false);
  // No second period was opened; the original open period is untouched.
  assertEquals(mock.rows.length, 1);
  assertEquals(mock.rows[0].valid_to, null);
  assertEquals(mock.rows[0].valid_from, T0);
});

Deno.test("W4: stopping transport CLOSEs the open period (no new period); as-of after the stop is null", async () => {
  const mock = new MockHistoryDb();
  await assign(mock, "alloc-1", "route-A", T0);

  const closed = await closeOpenAllocation(db(mock), ORG, SCHOOL, "alloc-1", T1);
  assertEquals(closed?.routeId, "route-A");
  assertEquals(closed?.validTo, T1);

  // No open period remains; still exactly one (now-closed) row.
  assertEquals(mock.rows.length, 1);
  assertEquals(mock.rows.filter((r) => r.valid_to === null).length, 0);

  // In effect before the stop, gone after it.
  assertEquals(
    (await getAllocationAsOf(db(mock), ORG, SCHOOL, "alloc-1", "2026-02-01T00:00:00.000Z"))?.routeId,
    "route-A",
  );
  assertEquals(
    await getAllocationAsOf(db(mock), ORG, SCHOOL, "alloc-1", "2026-04-01T00:00:00.000Z"),
    null,
  );

  // Closing again is idempotent (nothing open → null), never a throw.
  assertEquals(await closeOpenAllocation(db(mock), ORG, SCHOOL, "alloc-1", T2), null);
});

Deno.test("W4 concurrency guard: a racing double-open is rejected (409 conflict) and NEVER persisted", async () => {
  const mock = new MockHistoryDb();
  // Model the LOSER of a concurrent re-assignment: by the time it inserts, a
  // concurrent winner has already opened a new period, so the open-period partial
  // unique index fires 23505 on THIS insert. (The loser's own snapshot showed no
  // open period, exactly as READ COMMITTED yields after the winner committed.)
  mock.failNextInsert = true;

  const err = await assertRejects(
    () =>
      recordAllocationChange(
        db(mock),
        ORG,
        SCHOOL,
        "alloc-1",
        { sisStudentId: "SIS-1", routeId: "route-C", pickupStop: "p", dropStop: "d", shift: "both", payload: {} },
        { changeDate: T2, changedBy: "user-1" },
      ),
    AllocationHistoryConflictError,
  );
  // Rejected as a clean 409 CONFLICT (extends WriteValidationError).
  assertEquals(err.status, 409);
  assertEquals(err.code, "TRANSPORT_REASSIGN_CONFLICT");

  // The loser persisted NOTHING — no orphaned or duplicate open period.
  assertEquals(mock.insertAttempts, 1);
  assertEquals(mock.rows.length, 0);
});

Deno.test("W4 concurrency guard: the open-period unique index forbids two open periods for one allocation", async () => {
  const mock = new MockHistoryDb();
  await assign(mock, "alloc-1", "route-A", T0); // one open period

  // recordAllocationChange always CLOSEs the open period before opening the next,
  // so the normal re-assign never conflicts — but if the close is bypassed (a
  // buggy/racing writer), the partial unique index MUST reject the second open.
  // Prove the invariant holds by attempting an insert while an open period exists.
  mock.failNextInsert = false;
  await assertRejects(
    // Direct insert of a SECOND open period for the same allocation (no close
    // first) — the partial unique index must reject it, exactly like Postgres.
    async () => {
      await mock.queryObject(
        "INSERT INTO transport_allocation_history (...) VALUES (...)",
        ["dup-id", ORG, SCHOOL, "alloc-1", "SIS-1", "route-X", "p", "d", "both", "{}", T1, "user-1"],
      );
    },
  );

  // Still exactly one open period, still route-A.
  const open = mock.rows.filter((r) => r.allocation_id === "alloc-1" && r.valid_to === null);
  assertEquals(open.length, 1);
  assertEquals(open[0].route_id, "route-A");
});
