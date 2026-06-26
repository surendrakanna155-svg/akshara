import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { recomputeVisitors } from "./hostel_read_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";

function schoolClaims(): AccessTokenClaims {
  return {
    sub: "warden",
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["viewHostel"],
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
    permissions: ["viewHostel"],
  };
}

interface MockRow {
  entity_type: string;
  id: string;
  payload: Record<string, unknown>;
}

class MockHostelDb {
  constructor(public rows: MockRow[]) {}

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // recomputeVisitors list query (newest-first sort happens in JS).
    if (sql.includes("ORDER BY id") && !sql.includes("LIMIT")) {
      const entityType = args[2] as string;
      const items = this.rows.filter((row) => row.entity_type === entityType);
      return items.map((row) => ({ payload: row.payload })) as T[];
    }

    // getSnapshot query (entity_type = $3 AND id = $4).
    if (sql.includes("AND id = $4")) {
      const entityType = args[2] as string;
      const id = args[3] as string;
      const row = this.rows.find((r) => r.entity_type === entityType && r.id === id);
      return row ? [{ payload: row.payload }] as T[] : [] as T[];
    }

    return [] as T[];
  }
}

function visitorEntity(
  id: string,
  overrides: Partial<Record<string, unknown>> = {},
): MockRow {
  return {
    entity_type: "visitor",
    id,
    payload: {
      id,
      visitorName: "Visitor",
      relation: "Father",
      studentName: "Student",
      sisStudentId: "SIS-STU-1",
      checkIn: "2026-06-26T10:00:00.000Z",
      checkOut: null,
      passId: `VP-${id}`,
      status: "active",
      ...overrides,
    },
  };
}

Deno.test("recomputeVisitors surfaces a just-logged visitor in activeVisitors", async () => {
  const loggedId = "f0000000-0000-4000-8000-000000000999";
  const db = new MockHostelDb([
    visitorEntity(loggedId, {
      visitorName: "Vikram Patel",
      passId: "VP-1750932000000",
      checkIn: "2026-06-26T11:30:00.000Z",
    }),
  ]) as unknown as TenantQueryClient;

  const payload = await recomputeVisitors(db, ORG, SCHOOL_A);

  const active = payload.activeVisitors as Array<Record<string, unknown>>;
  assertEquals(active.length, 1);
  assertEquals(active[0]?.id, loggedId);
  assertEquals(active[0]?.passId, "VP-1750932000000");
  assertEquals(active[0]?.visitorName, "Vikram Patel");

  // Static fields fall back to defaults when no seed snapshot is present.
  assertEquals(payload.qrPlaceholderLabel, "QR visitor pass preview (120×120)");
  assertEquals(payload.parentAppRoute, "/parent/dashboard");
});

Deno.test("recomputeVisitors splits active vs checked-out and sorts newest-first", async () => {
  const db = new MockHostelDb([
    visitorEntity("a", {
      checkIn: "2026-06-26T09:00:00.000Z",
      checkOut: "2026-06-26T11:00:00.000Z",
      status: "checkedOut",
    }),
    visitorEntity("b", { checkIn: "2026-06-26T10:00:00.000Z" }),
    visitorEntity("c", {
      checkIn: "2026-06-26T08:00:00.000Z",
      checkOut: "2026-06-26T08:30:00.000Z",
      status: "expired",
    }),
    visitorEntity("d", { checkIn: "2026-06-26T12:00:00.000Z" }),
  ]) as unknown as TenantQueryClient;

  const payload = await recomputeVisitors(db, ORG, SCHOOL_A);
  const active = payload.activeVisitors as Array<Record<string, unknown>>;
  const log = payload.visitorLog as Array<Record<string, unknown>>;

  // Active = status active / checkOut null, newest-first (d before b).
  assertEquals(active.map((v) => v.id), ["d", "b"]);
  // Log = checked-out + expired, newest-first (a before c).
  assertEquals(log.map((v) => v.id), ["a", "c"]);
});

Deno.test("recomputeVisitors prefers seed snapshot static fields when present", async () => {
  const db = new MockHostelDb([
    visitorEntity("x"),
    {
      entity_type: "snapshot_visitors",
      id: "default",
      payload: {
        qrPlaceholderLabel: "Seeded QR label",
        parentAppRoute: "/parent/visitors",
      },
    },
  ]) as unknown as TenantQueryClient;

  const payload = await recomputeVisitors(db, ORG, SCHOOL_A);
  assertEquals(payload.qrPlaceholderLabel, "Seeded QR label");
  assertEquals(payload.parentAppRoute, "/parent/visitors");
});

Deno.test("recomputeVisitors returns empty lists when no visitors logged", async () => {
  const db = new MockHostelDb([]) as unknown as TenantQueryClient;
  const payload = await recomputeVisitors(db, ORG, SCHOOL_A);
  assertEquals((payload.activeVisitors as unknown[]).length, 0);
  assertEquals((payload.visitorLog as unknown[]).length, 0);
});

Deno.test("hostel visitors read denies organization scope", () => {
  const denied = requirePermission(orgClaims(), "viewHostel") ??
    requireSchoolOperationalScope(orgClaims());
  assertEquals(denied?.status, 403);
});

Deno.test("hostel visitors read requires viewHostel permission", () => {
  // Matches the shared `requireRead` (requirePermission ?? requireSchoolOperationalScope):
  // the viewHostel permission is required, then school operational scope.
  const missingPerm = { ...schoolClaims(), permissions: [] as string[] };
  const deniedNoPerm = requirePermission(missingPerm, "viewHostel") ??
    requireSchoolOperationalScope(missingPerm);
  assertEquals(deniedNoPerm?.status, 403);

  // A school-scoped role with viewHostel is allowed.
  const allowed = schoolClaims();
  const grant = requirePermission(allowed, "viewHostel") ??
    requireSchoolOperationalScope(allowed);
  assertEquals(grant, null);
});
