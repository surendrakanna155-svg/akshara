// MJ-H19 / TRANS-1 + MJ-M9 / TRANS-2/3 — transport write coverage.
//
// The HTTP handlers (handleRecordAttendance / handleAssignStudentTransport /
// handleNotifyRouteDelay) wrap auth + tenant transaction plumbing that is not
// unit-testable in isolation, so — mirroring transport_read_repository_test.ts
// and broadcast_batch_test.ts — these tests pin the three load-bearing pieces
// the handlers compose: (1) the entity-store persistence shape each handler
// writes, (2) the notify-delay route lookup + affected-cohort count that drives
// the broadcast reuse, and (3) the manageTransport RBAC gate + body validation.

import { assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import {
  boolOr,
  requireStr,
  str,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";

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

/**
 * In-memory stand-in for the transport_entities table that honours the exact
 * SQL the entity write store issues (INSERT/UPDATE/SELECT-by-key/SELECT-all by
 * org+school+entity_type). Mirrors MockTransportDb in the read-repo test.
 */
class MockTransportWriteDb {
  rows: EntityRow[] = [];

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("INSERT INTO transport_entities")) {
      const row: EntityRow = {
        id: args[0],
        organization_id: args[1],
        school_id: args[2],
        entity_type: args[3],
        payload: JSON.parse(args[4]),
      };
      this.rows.push(row);
      return Promise.resolve([{ payload: row.payload }] as T[]);
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

function orgClaims(): AccessTokenClaims {
  return {
    ...schoolClaims(),
    school_id: null,
    scope: "organization",
  };
}

// ── TRANS-1: record-attendance persistence ───────────────────────────────────

Deno.test("record-attendance persists an attendance entity the list reads back", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  const body = {
    studentName: "Ravi Kumar",
    stopName: "Lake View Colony",
    routeName: "Route 12 — North",
    status: "picked",
    parentNotified: true,
    shift: "am",
  };
  const id = str(body, "id") ?? "att-1";
  const payload = {
    id,
    studentName: requireStr(body, "studentName", "student_name"),
    stopName: str(body, "stopName", "stop_name") ?? "",
    routeName: str(body, "routeName", "route_name") ?? "",
    scheduledTime: str(body, "scheduledTime", "scheduled_time") ?? "",
    actualTime: str(body, "actualTime", "actual_time") ?? "",
    status: str(body, "status") ?? "waiting",
    parentNotified: boolOr(body, false, "parentNotified", "parent_notified"),
    shift: str(body, "shift") ?? "am",
  };
  await writeStore.insert(db, ORG, SCHOOL_A, "attendance", id, payload);

  // The GET attendance read lists live `attendance` entities — confirm it's there.
  const listed = await writeStore.findAll(db, ORG, SCHOOL_A, "attendance");
  assertEquals(listed.length, 1);
  assertEquals(listed[0].studentName, "Ravi Kumar");
  assertEquals(listed[0].status, "picked");
  assertEquals(listed[0].parentNotified, true);
});

Deno.test("record-attendance re-recording the same id replaces, not duplicates", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "attendance", "att-1", {
    id: "att-1",
    studentName: "Ravi Kumar",
    status: "waiting",
  });
  const existing = await writeStore.find(db, ORG, SCHOOL_A, "attendance", "att-1");
  assertEquals(existing?.status, "waiting");
  await writeStore.replace(db, ORG, SCHOOL_A, "attendance", "att-1", {
    id: "att-1",
    studentName: "Ravi Kumar",
    status: "absent",
  });
  const listed = await writeStore.findAll(db, ORG, SCHOOL_A, "attendance");
  assertEquals(listed.length, 1);
  assertEquals(listed[0].status, "absent");
});

Deno.test("record-attendance requires studentName", () => {
  assertThrows(
    () => requireStr({ status: "picked" }, "studentName", "student_name"),
    WriteValidationError,
  );
});

// ── TRANS-3: assign carries real SIS identity + transport flag ────────────────

Deno.test("assign persists studentName/admissionNumber/sisStudentId + transport flag", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  const body = {
    allocationId: "alloc-1",
    routeId: "route-12",
    pickupStop: "Lake View Colony",
    dropStop: "Akshara Main Gate",
    studentName: "Ravi Kumar",
    admissionNumber: "ADM-2026-0138",
    sisStudentId: "SIS-STU-10430",
    classLabel: "10",
  };
  const sisStudentId = str(body, "sisStudentId", "sis_student_id") ?? "";
  const payload = {
    id: "alloc-1",
    studentName: str(body, "studentName", "student_name") ?? "",
    admissionNumber: str(body, "admissionNumber", "admission_number") ?? "",
    classLabel: str(body, "classLabel", "class_label") ?? "",
    pickupStop: requireStr(body, "pickupStop", "pickup_stop"),
    dropStop: requireStr(body, "dropStop", "drop_stop"),
    routeId: "route-12",
    sisStudentId,
    transportEnrolled: true,
  };
  await writeStore.insert(db, ORG, SCHOOL_A, "allocation", "alloc-1", payload);

  const saved = await writeStore.find(db, ORG, SCHOOL_A, "allocation", "alloc-1");
  // Previously these defaulted to "" because the client never sent them.
  assertEquals(saved?.studentName, "Ravi Kumar");
  assertEquals(saved?.admissionNumber, "ADM-2026-0138");
  assertEquals(saved?.sisStudentId, "SIS-STU-10430");
  // The SIS Student-360 read matches the allocation by sisStudentId — this flag
  // is the cross-module transport handoff.
  assertEquals(saved?.transportEnrolled, true);
});

// ── TRANS-2: notify-delay route lookup + affected cohort ──────────────────────

Deno.test("notify-delay resolves the route and counts the affected cohort", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "route", "route-12", {
    id: "route-12",
    name: "Route 12 — North",
  });
  // Two students on route-12, one on another route — only the two are affected.
  await writeStore.insert(db, ORG, SCHOOL_A, "allocation", "a1", {
    id: "a1",
    routeId: "route-12",
  });
  await writeStore.insert(db, ORG, SCHOOL_A, "allocation", "a2", {
    id: "a2",
    routeId: "route-12",
  });
  await writeStore.insert(db, ORG, SCHOOL_A, "allocation", "a3", {
    id: "a3",
    routeId: "route-08",
  });

  const routes = await writeStore.findAll(db, ORG, SCHOOL_A, "route");
  const route = routes.find((r) => String(r.id ?? "") === "route-12");
  assertEquals((route?.name as string | undefined), "Route 12 — North");

  const allocations = await writeStore.findAll(db, ORG, SCHOOL_A, "allocation");
  const affected = allocations.filter((a) => String(a.routeId ?? "") === "route-12");
  assertEquals(affected.length, 2);
});

Deno.test("notify-delay requires routeId and message", () => {
  assertThrows(() => requireStr({ message: "late" }, "routeId", "route_id"), WriteValidationError);
  assertThrows(() => requireStr({ routeId: "r" }, "message"), WriteValidationError);
});

// ── RBAC: manageTransport gate ────────────────────────────────────────────────

Deno.test("manageTransport required for transport writes", () => {
  const claims = { ...schoolClaims(), permissions: ["viewTransport"] as string[] };
  const denied = requirePermission(claims, "manageTransport") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});

Deno.test("org scope denied for transport writes", () => {
  const denied = requirePermission(orgClaims(), "manageTransport") ??
    requireSchoolOperationalScope(orgClaims());
  assertEquals(denied?.status, 403);
});
