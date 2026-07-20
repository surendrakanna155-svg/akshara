// MJ-H19 / TRANS-1 + MJ-M9 / TRANS-2/3 — transport write coverage.
//
// The HTTP handlers (handleRecordAttendance / handleAssignStudentTransport /
// handleNotifyRouteDelay) wrap auth + tenant transaction plumbing that is not
// unit-testable in isolation, so — mirroring transport_read_repository_test.ts
// and broadcast_batch_test.ts — these tests pin the three load-bearing pieces
// the handlers compose: (1) the entity-store persistence shape each handler
// writes, (2) the notify-delay route lookup + affected-cohort resolution that
// scopes the delay alert to exactly the on-route students' guardians (PRA-P1-44),
// and (3) the manageTransport RBAC gate + body validation.

import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
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
import {
  assertCapacity,
  CapacityExceededError,
  collectDocumentExpiries,
  isoDateField,
  isStrictIsoDate,
  regKey,
  runDocumentExpiryReminder,
  stopStudentTransport,
  TRANSPORT_DOC_EXPIRY_AUDIENCE,
} from "./transport_write_handlers.ts";
import { buildRoster } from "./transport_handlers.ts";
import { normalizeBroadcastAudience } from "../communication/communication_service.ts";

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

/**
 * PRC-A caps 4/9 — stopping transport must also REVOKE the fee, so this fixture
 * speaks the finance SQL cancelInvoice issues (invoice read, the status-guarded
 * cancel, and the student-account lockstep release) on top of transport_entities.
 */
class MockStopTransportDb extends MockTransportWriteDb {
  invoices: Record<string, unknown>[] = [];
  accounts: Record<string, unknown>[] = [];

  // deno-lint-ignore no-explicit-any
  override queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("SELECT * FROM finance_invoices") && sql.includes("WHERE id = $1")) {
      const found = this.invoices.find((i) =>
        i.id === args[0] && i.organization_id === args[1] && i.school_id === args[2]
      );
      return Promise.resolve((found ? [found] : []) as T[]);
    }
    if (sql.includes("UPDATE finance_invoices") && sql.includes("invoice_status = 'cancelled'")) {
      const row = this.invoices.find((i) => i.id === args[0]);
      if (!row) return Promise.resolve([] as T[]);
      // The status guard: a paid/cancelled invoice matches 0 rows.
      if (row.invoice_status === "paid" || row.invoice_status === "cancelled") {
        return Promise.resolve([] as T[]);
      }
      row.invoice_status = "cancelled";
      return Promise.resolve([row] as T[]);
    }
    if (sql.includes("UPDATE finance_student_accounts")) {
      const released = parseFloat(String(args[0]));
      const account = this.accounts.find((a) =>
        a.student_id === args[1] && a.academic_year === args[2] &&
        a.organization_id === args[3] && a.school_id === args[4]
      );
      if (!account) return Promise.resolve([] as T[]);
      const drop = (v: unknown) => Math.max(0, parseFloat(String(v)) - released).toFixed(2);
      account.total_fee = drop(account.total_fee);
      account.outstanding_amount = drop(account.outstanding_amount);
      return Promise.resolve([account] as T[]);
    }
    return super.queryObject<T>(sql, args);
  }
}

const STUDENT_U = "a4000000-0000-4000-8000-000000000001";

/** Seeds one transport allocation + its raised demand/invoice/account. */
async function seedStoppableTransport(
  db: MockStopTransportDb,
  invoiceStatus = "issued",
): Promise<void> {
  await writeStore.insert(db as unknown as TenantQueryClient, ORG, SCHOOL_A, "allocation", "alloc-1", {
    id: "alloc-1",
    sisStudentId: "ADM-1",
    routeId: "route-1",
    routeName: "Route 1",
    busNumber: "AP01AB1234",
    transportEnrolled: true,
  });
  await writeStore.insert(db as unknown as TenantQueryClient, ORG, SCHOOL_A, "demand", "demand-1", {
    id: "demand-1",
    dedupeKey: "ADM-1::route-1::2026-27::annual",
    allocationId: "alloc-1",
    sisStudentId: "ADM-1",
    studentUuid: STUDENT_U,
    routeId: "route-1",
    academicYear: "2026-27",
    term: "annual",
    invoiceId: "inv-t1",
  });
  db.invoices.push({
    id: "inv-t1",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT_U,
    academic_year: "2026-27",
    total_amount: "12000",
    outstanding_amount: "12000",
    invoice_status: invoiceStatus,
  });
  db.accounts.push({
    id: "acct-t1",
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT_U,
    academic_year: "2026-27",
    total_fee: "12000",
    amount_paid: "0",
    outstanding_amount: "12000",
  });
}

Deno.test("PRC-A caps 4/9: stopping transport SOFT-stops the allocation (row + history preserved, never deleted)", async () => {
  const db = new MockStopTransportDb();
  await seedStoppableTransport(db);

  await stopStudentTransport(db as unknown as TenantQueryClient, ORG, SCHOOL_A, "alloc-1", {
    effectiveDate: "2026-08-01",
    actorId: "staff",
  });

  // The row still exists — the old code hard-deleted it, destroying the history.
  const alloc = await writeStore.find(
    db as unknown as TenantQueryClient, ORG, SCHOOL_A, "allocation", "alloc-1",
  );
  assertEquals(alloc?.transportEnrolled, false);
  assertEquals(alloc?.stoppedAt, "2026-08-01");
  assertEquals(alloc?.stoppedBy, "staff");
  assertEquals(alloc?.sisStudentId, "ADM-1");
});

Deno.test("PRC-A caps 4/9: stopping transport REVOKES the fee — invoice cancelled and the account released", async () => {
  const db = new MockStopTransportDb();
  await seedStoppableTransport(db);

  const result = await stopStudentTransport(
    db as unknown as TenantQueryClient, ORG, SCHOOL_A, "alloc-1",
    { effectiveDate: "2026-08-01", actorId: "staff" },
  );

  assertEquals(result.cancelledInvoices, ["inv-t1"]);
  assertEquals(db.invoices[0]!.invoice_status, "cancelled");
  // The over-billing is actually gone at ACCOUNT level, not just on the invoice.
  assertEquals(db.accounts[0]!.outstanding_amount, "0.00");
  assertEquals(db.accounts[0]!.total_fee, "0.00");
});

Deno.test("PRC-A caps 4/9: stopping releases the demand dedupe key so a later re-enrolment raises a NEW fee", async () => {
  const db = new MockStopTransportDb();
  await seedStoppableTransport(db);

  await stopStudentTransport(db as unknown as TenantQueryClient, ORG, SCHOOL_A, "alloc-1", {
    effectiveDate: "2026-08-01",
    actorId: "staff",
  });

  const demand = await writeStore.find(
    db as unknown as TenantQueryClient, ORG, SCHOOL_A, "demand", "demand-1",
  );
  // dedupeKey must be GONE: the raise path dedupes on it and the partial unique
  // index covers `payload ? 'dedupeKey'`, so leaving it would make a re-enrolment
  // return this old demand as "idempotent" and raise no fee — a free ride.
  assertEquals(demand?.dedupeKey, undefined);
  assertEquals(demand?.revokedDedupeKey, "ADM-1::route-1::2026-27::annual");
  // ...while the history itself is preserved.
  assertEquals(demand?.invoiceId, "inv-t1");
  assertEquals(demand?.cancelledEffectiveDate, "2026-08-01");
});

Deno.test("PRC-A caps 4/9: a PAID transport invoice is NOT cancelled — it is reported as skipped (refund is Finance's call)", async () => {
  const db = new MockStopTransportDb();
  await seedStoppableTransport(db, "paid");

  const result = await stopStudentTransport(
    db as unknown as TenantQueryClient, ORG, SCHOOL_A, "alloc-1",
    { effectiveDate: "2026-08-01", actorId: "staff" },
  );

  assertEquals(result.cancelledInvoices, []);
  assertEquals(result.skippedInvoices.length, 1);
  assertEquals(result.skippedInvoices[0]!.invoiceId, "inv-t1");
  assertEquals(db.invoices[0]!.invoice_status, "paid");
  // Real money already collected is untouched — no silent account rewrite.
  assertEquals(db.accounts[0]!.outstanding_amount, "12000");
  // The allocation still stops, and the demand key is still released.
  const alloc = await writeStore.find(
    db as unknown as TenantQueryClient, ORG, SCHOOL_A, "allocation", "alloc-1",
  );
  assertEquals(alloc?.transportEnrolled, false);
});

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

// PRA-P1-44: the delay alert must reach ONLY the on-route students' guardians —
// not every parent in the school. The handler extracts the affected allocations'
// sisStudentIds and hands them to guardianUserIdsForStudents; this pins that
// route-scoped extraction (off-route students are excluded, blanks dropped).
Deno.test("P1-44 notify-delay extracts only the on-route students' sisStudentIds", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "route", "route-12", {
    id: "route-12",
    name: "Route 12 — North",
  });
  await writeStore.insert(db, ORG, SCHOOL_A, "allocation", "a1", {
    id: "a1",
    routeId: "route-12",
    sisStudentId: "SIS-STU-1",
  });
  await writeStore.insert(db, ORG, SCHOOL_A, "allocation", "a2", {
    id: "a2",
    routeId: "route-12",
    sisStudentId: "SIS-STU-2",
  });
  // Off-route student — must NOT be notified.
  await writeStore.insert(db, ORG, SCHOOL_A, "allocation", "a3", {
    id: "a3",
    routeId: "route-08",
    sisStudentId: "SIS-STU-3",
  });
  // On-route allocation with no SIS id yet — dropped from the recipient set.
  await writeStore.insert(db, ORG, SCHOOL_A, "allocation", "a4", {
    id: "a4",
    routeId: "route-12",
  });

  const allocations = await writeStore.findAll(db, ORG, SCHOOL_A, "allocation");
  const affected = allocations.filter((a) => String(a.routeId ?? "") === "route-12");
  const sisStudentIds = affected
    .map((a) => String(a.sisStudentId ?? ""))
    .filter((s) => s.length > 0);

  // Exactly the two on-route students with a SIS id — never SIS-STU-3 (route-08).
  assertEquals(sisStudentIds.sort(), ["SIS-STU-1", "SIS-STU-2"]);
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

// ── TRN-2: strict ISO-date validation ─────────────────────────────────────────

Deno.test("TRN-2: isStrictIsoDate accepts real YYYY-MM-DD, rejects malformed/impossible", () => {
  assertEquals(isStrictIsoDate("2026-12-31"), true);
  assertEquals(isStrictIsoDate("2028-02-29"), true); // leap day
  assertEquals(isStrictIsoDate("2026-02-30"), false); // impossible calendar date
  assertEquals(isStrictIsoDate("2026-13-01"), false); // bad month
  assertEquals(isStrictIsoDate("2026-1-1"), false); // not zero-padded
  assertEquals(isStrictIsoDate("31-12-2026"), false); // wrong order
  assertEquals(isStrictIsoDate("Dec 2026"), false); // free text
});

Deno.test("TRN-2: isoDateField throws 422 on malformed date, passes a real one, omits absent", () => {
  const err = assertThrows(
    () => isoDateField({ insuranceExpiry: "not-a-date" }, "insuranceExpiry", "insurance_expiry"),
    WriteValidationError,
  );
  assertEquals(err.status, 422);
  assertEquals(isoDateField({ insuranceExpiry: "2026-06-30" }, "insuranceExpiry"), "2026-06-30");
  assertEquals(isoDateField({}, "insuranceExpiry"), undefined);
});

// ── TRN-1: vehicle registration uniqueness (per school) ───────────────────────

Deno.test("TRN-1: duplicate vehicle registration is rejected (case/space-insensitive)", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "vehicle", "v1", {
    id: "v1",
    registration: "KA-01-AB-1234",
    capacity: 40,
  });
  // The create handler's guard: scan existing vehicles, reject a normalized dupe.
  const existing = await writeStore.findAll(db, ORG, SCHOOL_A, "vehicle");
  const isDuplicate = existing.some(
    (v) => regKey(String(v.registration ?? "")) === regKey("ka-01-ab-1234"),
  );
  assertEquals(isDuplicate, true);
});

// ── TRN-1: delete-block when a route references the vehicle ────────────────────

Deno.test("TRN-1: a vehicle assigned to an ACTIVE route is delete-blocked", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "vehicle", "v1", {
    id: "v1",
    registration: "KA-01-AB-1234",
    capacity: 40,
  });
  await writeStore.insert(db, ORG, SCHOOL_A, "route", "r1", {
    id: "r1",
    name: "Route 12",
    assignedBus: "KA-01-AB-1234",
    status: "active",
  });
  const routes = await writeStore.findAll(db, ORG, SCHOOL_A, "route");
  const referencing = routes.find(
    (r) => regKey(String(r.assignedBus ?? "")) === regKey("KA-01-AB-1234") &&
      String(r.status ?? "") === "active",
  );
  assertEquals(referencing?.id, "r1"); // delete would 409 VEHICLE_IN_USE

  // Deactivating the route unblocks the delete.
  await writeStore.replace(db, ORG, SCHOOL_A, "route", "r1", {
    id: "r1",
    name: "Route 12",
    assignedBus: "KA-01-AB-1234",
    status: "inactive",
  });
  const routes2 = await writeStore.findAll(db, ORG, SCHOOL_A, "route");
  const stillReferencing = routes2.find(
    (r) => regKey(String(r.assignedBus ?? "")) === regKey("KA-01-AB-1234") &&
      String(r.status ?? "") === "active",
  );
  assertEquals(stillReferencing, undefined);
});

// ── TRN-7: race-safe capacity guard (409 + explicit override) ─────────────────

async function seedRouteWithVehicle(db: TenantQueryClient, capacity: number, occupants: number) {
  await writeStore.insert(db, ORG, SCHOOL_A, "vehicle", "v1", {
    id: "v1",
    registration: "KA-01-AB-1234",
    capacity,
  });
  await writeStore.insert(db, ORG, SCHOOL_A, "route", "r1", {
    id: "r1",
    name: "Route 12",
    assignedBus: "KA-01-AB-1234",
    status: "active",
  });
  for (let i = 0; i < occupants; i++) {
    await writeStore.insert(db, ORG, SCHOOL_A, "allocation", `a${i}`, {
      id: `a${i}`,
      routeId: "r1",
      sisStudentId: `S${i}`,
    });
  }
}

Deno.test("TRN-7: assigning past capacity rejects with 409 CAPACITY_EXCEEDED", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await seedRouteWithVehicle(db, 2, 2); // full
  const route = await writeStore.find(db, ORG, SCHOOL_A, "route", "r1");
  const err = await assertRejects(
    () => assertCapacity(db, ORG, SCHOOL_A, route!, 1, false),
    CapacityExceededError,
  );
  assertEquals((err as CapacityExceededError).status, 409);
  assertEquals((err as CapacityExceededError).code, "CAPACITY_EXCEEDED");
});

Deno.test("TRN-7: allowOverCapacity override succeeds and flags overridden", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await seedRouteWithVehicle(db, 2, 2); // full
  const route = await writeStore.find(db, ORG, SCHOOL_A, "route", "r1");
  const result = await assertCapacity(db, ORG, SCHOOL_A, route!, 1, true);
  assertEquals(result.overridden, true);
  assertEquals(result.capacity, 2);
  assertEquals(result.current, 2);
});

Deno.test("TRN-7: under capacity passes without override; no vehicle = unbounded (skip)", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await seedRouteWithVehicle(db, 40, 5);
  const route = await writeStore.find(db, ORG, SCHOOL_A, "route", "r1");
  const ok = await assertCapacity(db, ORG, SCHOOL_A, route!, 1, false);
  assertEquals(ok.overridden, false);

  // A route with no assigned vehicle has null capacity → guard is skipped.
  await writeStore.insert(db, ORG, SCHOOL_A, "route", "r2", {
    id: "r2",
    name: "Unbused",
    assignedBus: "",
    status: "active",
  });
  const r2 = await writeStore.find(db, ORG, SCHOOL_A, "route", "r2");
  const unbounded = await assertCapacity(db, ORG, SCHOOL_A, r2!, 999, false);
  assertEquals(unbounded.capacity, null);
  assertEquals(unbounded.overridden, false);
});

// ── TRN-3: roster grouping by stop, ordered by route stop sequence ────────────

Deno.test("TRN-3: roster groups students by pickup stop, ordered by route sequence", () => {
  const route = {
    id: "r1",
    name: "Route 12",
    stops: [
      { id: "s1", name: "Lake View", sequence: 1 },
      { id: "s2", name: "Market Square", sequence: 2 },
      { id: "s3", name: "Hilltop", sequence: 3 },
    ],
  };
  const allocations = [
    { sisStudentId: "S2", studentName: "Bhavya", classLabel: "5", pickupStop: "Market Square" },
    { sisStudentId: "S1", studentName: "Anaya", classLabel: "6", pickupStop: "Lake View" },
    { sisStudentId: "S3", studentName: "Chetan", classLabel: "5", pickupStop: "Lake View" },
    { sisStudentId: "S4", studentName: "Divya", classLabel: "4", pickupStop: "Hilltop" },
  ];
  const roster = buildRoster(route, allocations) as {
    stopCount: number;
    studentCount: number;
    stops: Array<{ stop: string; sequence: number; students: Array<{ studentName: string }> }>;
  };
  assertEquals(roster.stopCount, 3);
  assertEquals(roster.studentCount, 4);
  // Ordered by the route's stop sequence.
  assertEquals(roster.stops.map((g) => g.stop), ["Lake View", "Market Square", "Hilltop"]);
  // Lake View has two students, sorted by name.
  assertEquals(roster.stops[0].students.map((s) => s.studentName), ["Anaya", "Chetan"]);
});

Deno.test("TRN-3: a student on an unknown stop sorts last under (unassigned stop)", () => {
  const route = { id: "r1", name: "R1", stops: [{ id: "s1", name: "Known", sequence: 1 }] };
  const roster = buildRoster(route, [
    { sisStudentId: "S1", studentName: "A", pickupStop: "Known" },
    { sisStudentId: "S2", studentName: "B", pickupStop: "" },
  ]) as { stops: Array<{ stop: string }> };
  assertEquals(roster.stops[0].stop, "Known");
  assertEquals(roster.stops[1].stop, "(unassigned stop)");
});

// ── TRN-4: stop editor resequencing (contiguous 1-based ordering) ─────────────

Deno.test("TRN-4: removing a middle stop keeps sequence contiguous 1..n", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "route", "r1", {
    id: "r1",
    name: "R1",
    stopCount: 3,
    stops: [
      { id: "s1", name: "A", sequence: 1 },
      { id: "s2", name: "B", sequence: 2 },
      { id: "s3", name: "C", sequence: 3 },
    ],
  });
  // Mirror handleRemoveStop: drop s2, resequence.
  const saved = await writeStore.mutateEntity(db, ORG, SCHOOL_A, "route", "r1", (route) => {
    const stops = (route.stops as Array<Record<string, unknown>>).filter((s) => s.id !== "s2");
    const reseq = stops.map((s, i) => ({ ...s, sequence: i + 1 }));
    return { ...route, stops: reseq, stopCount: reseq.length };
  });
  const stops = (saved!.stops as Array<{ id: string; sequence: number }>);
  assertEquals(stops.map((s) => `${s.id}:${s.sequence}`), ["s1:1", "s3:2"]);
  assertEquals(saved!.stopCount, 2);
});

// ── TRN-5: bulk allocation partial result (assigned + skipped) ────────────────

Deno.test("TRN-5: bulk assign yields per-student partial result with skips", async () => {
  const db = new MockTransportWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "route", "r1", {
    id: "r1",
    name: "R1",
    assignedBus: "",
    status: "active",
  });
  const targets = ["S1", "S2", ""]; // "" is skipped (empty id)
  const assigned: string[] = [];
  const skipped: Array<{ studentId: string; reason: string }> = [];
  for (const sisStudentId of targets) {
    if (!sisStudentId) {
      skipped.push({ studentId: sisStudentId, reason: "empty student id" });
      continue;
    }
    const allocId = `r1:${sisStudentId}`;
    await writeStore.insert(db, ORG, SCHOOL_A, "allocation", allocId, {
      id: allocId,
      routeId: "r1",
      sisStudentId,
      pickupStop: "Gate",
      dropStop: "Gate",
      transportEnrolled: true,
    });
    assigned.push(sisStudentId);
  }
  assertEquals(assigned, ["S1", "S2"]);
  assertEquals(skipped.length, 1);
  const listed = await writeStore.findAll(db, ORG, SCHOOL_A, "allocation");
  assertEquals(listed.length, 2);
});

// ── TRN-8: document-expiry reminder rides the XCT-2 rail as all_staff ─────────

/**
 * MockTransportWriteDb + call capture + a comm_broadcasts responder, so the
 * FULL TRN-8 core (entity scan → scheduleReminder → audit) runs against one
 * fake db and every INSERT the rail issues is assertable — same capturing
 * fake-db pattern as reminders/reminders_service_test.ts.
 */
class MockReminderRailDb extends MockTransportWriteDb {
  calls: Array<{ sql: string; args: unknown[] }> = [];

  // deno-lint-ignore no-explicit-any
  override queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    this.calls.push({ sql, args });
    if (sql.includes("INSERT INTO comm_broadcasts")) {
      // Echo the scheduled row back the way createScheduledBroadcast RETURNINGs it.
      return Promise.resolve([{
        id: "rem-trn8",
        organization_id: args[0],
        school_id: args[1],
        audience: args[2],
        audience_class: args[3],
        audience_section: args[4],
        requires_ack: args[5],
        title: args[6],
        body: args[7],
        status: "scheduled",
        scheduled_at: args[8],
        created_by: args[9],
        sent_at: null,
        created_at: new Date().toISOString(),
      }] as T[]);
    }
    return super.queryObject<T>(sql, args);
  }
}

/** The exact comm_broadcasts.audience CHECK-constraint tokens (migration truth). */
const VALID_BROADCAST_AUDIENCES = new Set([
  "all_parents",
  "all_teachers",
  "all_students",
  "all_staff",
  "school_wide",
  "class_parents",
  "class_students",
]);

/** Strict ISO date n whole days from now (UTC), for rot-proof expiry fixtures. */
function isoInDays(n: number): string {
  return new Date(Date.now() + n * 86_400_000).toISOString().slice(0, 10);
}

Deno.test("TRN-8: expiring docs schedule ONE all_staff reminder on the XCT-2 rail + audit", async () => {
  const db = new MockReminderRailDb();
  const client = db as unknown as TenantQueryClient;
  await writeStore.insert(client, ORG, SCHOOL_A, "vehicle", "v1", {
    id: "v1",
    registration: "KA-01-AB-1234",
    insuranceExpiry: isoInDays(5), // within 30 days → due
    roadTaxExpiry: isoInDays(400), // far future → not due
    permitExpiry: "Dec 2027", // legacy free-text → skipped, never crashes the scan
  });
  await writeStore.insert(client, ORG, SCHOOL_A, "driver", "d1", {
    id: "d1",
    name: "Ramesh",
    licenseExpiry: isoInDays(-2), // already expired → still reminded
  });

  const result = await runDocumentExpiryReminder(client, schoolClaims(), ORG, SCHOOL_A, 30);

  assertEquals(result.reminded, 2);
  assertEquals(result.withinDays, 30);
  assertEquals(result.reminderId, "rem-trn8");
  assertEquals((result.expiries as unknown[]).length, 2);

  // ONE scheduled reminder row rides the rail — persisted 'scheduled', not sent now.
  const inserts = db.calls.filter((c) => c.sql.includes("INSERT INTO comm_broadcasts"));
  assertEquals(inserts.length, 1);
  assertEquals(inserts[0].sql.includes("'scheduled'"), true);
  // Audience is the VALID role-scoped staff token (the "staff" CHECK-violation bug).
  assertEquals(inserts[0].args[2], "all_staff");
  assertEquals(inserts[0].args[2], TRANSPORT_DOC_EXPIRY_AUDIENCE);
  assertEquals(String(inserts[0].args[6]), "Transport document expiries — 2 upcoming");
  assertEquals(String(inserts[0].args[7]).includes("Vehicle KA-01-AB-1234"), true);
  assertEquals(String(inserts[0].args[7]).includes("Driver Ramesh"), true);

  // The run is audited (transport.document.reminded carries count + reminderId).
  const audits = db.calls.filter((c) => c.sql.includes("INSERT INTO audit_events"));
  assertEquals(audits.length >= 1, true);
  assertEquals(
    audits.some((c) => c.args.some((a) => String(a).includes("transport.document.reminded"))),
    true,
  );
});

Deno.test("TRN-8: no expiring docs → nothing scheduled, reminded 0", async () => {
  const db = new MockReminderRailDb();
  const client = db as unknown as TenantQueryClient;
  await writeStore.insert(client, ORG, SCHOOL_A, "vehicle", "v1", {
    id: "v1",
    registration: "KA-01-AB-1234",
    insuranceExpiry: isoInDays(200), // all comfortably outside the 30-day window
    fitnessExpiry: isoInDays(365),
  });
  await writeStore.insert(client, ORG, SCHOOL_A, "driver", "d1", {
    id: "d1",
    name: "Ramesh",
    licenseExpiry: isoInDays(180),
  });

  const result = await runDocumentExpiryReminder(client, schoolClaims(), ORG, SCHOOL_A, 30);

  assertEquals(result.reminded, 0);
  assertEquals(result.expiries, []);
  assertEquals(result.reminderId, undefined);
  // Check-at-trigger-time: nothing due → NOTHING rides the rail and nothing audits.
  assertEquals(db.calls.some((c) => c.sql.includes("INSERT INTO comm_broadcasts")), false);
  assertEquals(db.calls.some((c) => c.sql.includes("INSERT INTO audit_events")), false);
});

Deno.test("TRN-8: regression guard — the reminder audience is a valid CHECK token (never 'staff')", () => {
  // The constant itself must be a CHECK-approved token…
  assertEquals(VALID_BROADCAST_AUDIENCES.has(TRANSPORT_DOC_EXPIRY_AUDIENCE), true);
  // …and must SURVIVE audience normalization still CHECK-approved (what hits SQL).
  assertEquals(
    VALID_BROADCAST_AUDIENCES.has(normalizeBroadcastAudience(TRANSPORT_DOC_EXPIRY_AUDIENCE)),
    true,
  );
  // The old bug, pinned: "staff" is neither a CHECK token nor aliased to one, so
  // any regression back to it would violate comm_broadcasts' CHECK at insert time.
  assertEquals(VALID_BROADCAST_AUDIENCES.has("staff"), false);
  assertEquals(VALID_BROADCAST_AUDIENCES.has(normalizeBroadcastAudience("staff")), false);
});

Deno.test("TRN-8: collectDocumentExpiries scans all five vehicle fields + driver licence", () => {
  const now = new Date();
  const expiries = collectDocumentExpiries(
    [{
      id: "v1",
      registration: "KA-01-AB-1234",
      insuranceExpiry: isoInDays(1),
      fitnessExpiry: isoInDays(2),
      pucExpiry: isoInDays(3),
      permitExpiry: isoInDays(4),
      roadTaxExpiry: isoInDays(5),
    }],
    [{ id: "d1", name: "Ramesh", licenseExpiry: isoInDays(6) }],
    30,
    now,
  );
  assertEquals(expiries.length, 6);
  assertEquals(
    expiries.map((e) => e.document),
    ["insurance", "fitness", "puc", "permit", "roadTax", "licence"],
  );
});

// ── TRN-9: demand idempotency + payment-free proof ────────────────────────────

Deno.test("TRN-9: a demand re-raise for the same (student,route,year,term) is idempotent", async () => {
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
  // The handler dedupe: a matching demand short-circuits and raises nothing new.
  const existing = await writeStore.findAll(db, ORG, SCHOOL_A, "demand");
  const prior = existing.find((d) => String(d.dedupeKey ?? "") === dedupeKey);
  assertEquals(prior?.id, "d1");
  assertEquals(prior?.invoiceId, "inv-1");
  // No second demand row created for the same key.
  assertEquals(existing.length, 1);
});

Deno.test("TRN-9: transport contains ZERO payment/collection code (payment-free)", async () => {
  // Prove Transport DEFINES + RAISES a demand but never collects: the transport
  // source must not import or call createCollection / finance_collections.
  const files = [
    "./transport_write_handlers.ts",
    "./transport_handlers.ts",
    "./transport_router.ts",
    "./transport_read_repository.ts",
  ];
  for (const rel of files) {
    const src = await Deno.readTextFile(new URL(rel, import.meta.url));
    // Strip line/block comments so a descriptive doc-comment ("never calls
    // createCollection") doesn't trip the check — we forbid actual CODE usage.
    const code = src
      .replace(/\/\*[\s\S]*?\*\//g, "")
      .split("\n")
      .map((line) => line.replace(/\/\/.*$/, ""))
      .join("\n");
    // No call to createCollection(...) and no import from a finance_collections module.
    assertEquals(
      /createCollection\s*\(/.test(code),
      false,
      `${rel} must not call createCollection`,
    );
    assertEquals(
      /from\s+["'][^"']*finance_collections[^"']*["']/.test(code),
      false,
      `${rel} must not import a finance_collections module`,
    );
    assertEquals(
      /finance_collections/.test(code),
      false,
      `${rel} must not reference the finance_collections table in code`,
    );
  }
});
