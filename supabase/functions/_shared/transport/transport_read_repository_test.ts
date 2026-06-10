import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  getSnapshot,
  listEntities,
  TRANSPORT_ROUTE_SCHOOL_A,
  TransportSnapshotNotFoundError,
} from "./transport_read_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";

function schoolClaims(): AccessTokenClaims {
  return {
    sub: "staff",
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["viewTransport"],
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
    permissions: ["viewTransport"],
  };
}

class MockTransportDb {
  rows = [
    {
      entity_type: "snapshot_dashboard",
      id: "default",
      payload: {
        aiInsight: "Test insight",
        kpis: [{ id: "active_buses", value: "18", label: "Active Buses", accentName: "primary" }],
        vehicleAssignments: [],
        activeDelays: [],
        routePerformance: [],
        occupancy: {
          totalCapacity: 860,
          allocatedSeats: 842,
          unassignedStudents: 2,
          utilizationPercent: 88,
        },
      },
    },
    {
      entity_type: "route",
      id: TRANSPORT_ROUTE_SCHOOL_A,
      payload: {
        id: TRANSPORT_ROUTE_SCHOOL_A,
        name: "Route 12 — North",
        stopCount: 8,
        distanceKm: "14.2 km",
        amDeparture: "6:45 AM",
        pmDeparture: "3:30 PM",
        assignedBus: "BUS-07",
        studentCount: 42,
        status: "active",
        shift: "both",
        stops: [],
      },
    },
    {
      entity_type: "vehicle",
      id: "veh_7",
      payload: {
        id: "veh_7",
        busNumber: "BUS-07",
        registration: "TS 09 AB 4521",
        capacity: 48,
        routeName: "Route 12 — North",
        gpsDeviceId: "GPS-TR-007",
        insuranceExpiry: "Dec 2026",
        fitnessExpiry: "Aug 2026",
        status: "active",
        occupancyPercent: 88,
      },
    },
  ];

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("count(*)::text AS total")) {
      const entityType = args[2] as string;
      const total = this.rows.filter((row) => row.entity_type === entityType).length;
      return [{ total: String(total) }] as T[];
    }

    if (sql.includes("entity_type = $3") && sql.includes("AND id = $4")) {
      const entityType = args[2] as string;
      const id = args[3] as string;
      const row = this.rows.find((entry) => entry.entity_type === entityType && entry.id === id);
      return row ? [{ payload: row.payload }] as T[] : [] as T[];
    }

    if (sql.includes("ORDER BY id")) {
      const entityType = args[2] as string;
      const limit = args[3] as number;
      const offset = args[4] as number;
      const items = this.rows
        .filter((row) => row.entity_type === entityType)
        .slice(offset, offset + limit);
      return items.map((row) => ({ payload: row.payload })) as T[];
    }

    return [] as T[];
  }
}

Deno.test("getSnapshot returns dashboard payload", async () => {
  const db = new MockTransportDb() as unknown as TenantQueryClient;
  const snapshot = await getSnapshot(db, ORG, SCHOOL_A, "snapshot_dashboard");
  assertEquals(typeof snapshot.aiInsight, "string");
  assertEquals(Array.isArray(snapshot.kpis), true);
  assertEquals(typeof snapshot.occupancy, "object");
});

Deno.test("getSnapshot throws when snapshot missing", async () => {
  const db = new MockTransportDb() as unknown as TenantQueryClient;
  await assertRejects(
    () => getSnapshot(db, ORG, SCHOOL_A, "snapshot_tracking"),
    TransportSnapshotNotFoundError,
  );
});

Deno.test("listEntities paginates routes", async () => {
  const db = new MockTransportDb() as unknown as TenantQueryClient;
  const result = await listEntities(db, ORG, SCHOOL_A, "route", { page: 1, pageSize: 20 });
  assertEquals(result.total, 1);
  assertEquals(result.items[0]?.id, TRANSPORT_ROUTE_SCHOOL_A);
  assertEquals(result.items[0]?.status, "active");
});

Deno.test("listEntities paginates vehicles", async () => {
  const db = new MockTransportDb() as unknown as TenantQueryClient;
  const result = await listEntities(db, ORG, SCHOOL_A, "vehicle", { page: 1, pageSize: 20 });
  assertEquals(result.total, 1);
  assertEquals(result.items[0]?.busNumber, "BUS-07");
});

Deno.test("org scope denied for transport read", () => {
  const denied = requirePermission(orgClaims(), "viewTransport") ??
    requireSchoolOperationalScope(orgClaims());
  assertEquals(denied?.status, 403);
});

Deno.test("viewTransport required for transport read", () => {
  const claims = { ...schoolClaims(), permissions: [] as string[] };
  const denied = requirePermission(claims, "viewTransport") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});
