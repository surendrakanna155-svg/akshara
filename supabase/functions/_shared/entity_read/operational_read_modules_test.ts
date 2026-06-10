import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  ALUMNI_RECORD_SCHOOL_A,
  alumniStore,
} from "../alumni/alumni_read_repository.ts";
import {
  HOSTEL_STUDENT_SCHOOL_A,
  hostelStore,
} from "../hostel/hostel_read_repository.ts";
import {
  INVENTORY_ASSET_SCHOOL_A,
  inventoryStore,
} from "../inventory/inventory_read_repository.ts";
import {
  LIBRARY_BOOK_SCHOOL_A,
  libraryStore,
} from "../library/library_read_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";

class MockEntityDb {
  constructor(
    private readonly rows: Array<{
      entity_type: string;
      id: string;
      payload: Record<string, unknown>;
    }>,
  ) {}

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

function schoolClaims(permission: string): AccessTokenClaims {
  return {
    sub: "staff",
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: [permission],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

Deno.test("hostel getSnapshot returns dashboard", async () => {
  const db = new MockEntityDb([
    {
      entity_type: "snapshot_dashboard",
      id: "default",
      payload: { aiInsight: "ok", kpis: [], occupancy: { totalBeds: 320 } },
    },
  ]) as unknown as TenantQueryClient;
  const snapshot = await hostelStore.getSnapshot(db, ORG, SCHOOL_A, "snapshot_dashboard");
  assertEquals(snapshot.aiInsight, "ok");
});

Deno.test("hostel listEntities returns students", async () => {
  const db = new MockEntityDb([
    {
      entity_type: "student",
      id: HOSTEL_STUDENT_SCHOOL_A,
      payload: { id: HOSTEL_STUDENT_SCHOOL_A, studentName: "Arjun Patel", status: "active" },
    },
  ]) as unknown as TenantQueryClient;
  const result = await hostelStore.listEntities(db, ORG, SCHOOL_A, "student", { page: 1, pageSize: 20 });
  assertEquals(result.total, 1);
});

Deno.test("library listEntities returns catalog", async () => {
  const db = new MockEntityDb([
    {
      entity_type: "catalog",
      id: LIBRARY_BOOK_SCHOOL_A,
      payload: { id: LIBRARY_BOOK_SCHOOL_A, title: "The Guide", status: "available" },
    },
  ]) as unknown as TenantQueryClient;
  const result = await libraryStore.listEntities(db, ORG, SCHOOL_A, "catalog", { page: 1, pageSize: 20 });
  assertEquals(result.items[0]?.title, "The Guide");
});

Deno.test("inventory getEntity returns asset", async () => {
  const db = new MockEntityDb([
    {
      entity_type: "asset",
      id: INVENTORY_ASSET_SCHOOL_A,
      payload: { id: INVENTORY_ASSET_SCHOOL_A, assetTag: "AST-2024-001", status: "active" },
    },
  ]) as unknown as TenantQueryClient;
  const asset = await inventoryStore.getEntity(db, ORG, SCHOOL_A, "asset", INVENTORY_ASSET_SCHOOL_A);
  assertEquals(asset.assetTag, "AST-2024-001");
});

Deno.test("alumni getSnapshot throws when missing", async () => {
  const db = new MockEntityDb([]) as unknown as TenantQueryClient;
  await assertRejects(
    () => alumniStore.getSnapshot(db, ORG, SCHOOL_A, "snapshot_dashboard"),
    alumniStore.SnapshotNotFoundError,
  );
});

Deno.test("viewHostel permission enforced", () => {
  const claims = { ...schoolClaims("viewHostel"), permissions: [] as string[] };
  const denied = requirePermission(claims, "viewHostel") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});

Deno.test("viewLibrary permission enforced", () => {
  const claims = { ...schoolClaims("viewLibrary"), permissions: [] as string[] };
  const denied = requirePermission(claims, "viewLibrary") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});

Deno.test("viewInventory permission enforced", () => {
  const claims = { ...schoolClaims("viewInventory"), permissions: [] as string[] };
  const denied = requirePermission(claims, "viewInventory") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});

Deno.test("viewAlumni permission enforced", () => {
  const claims = { ...schoolClaims("viewAlumni"), permissions: [] as string[] };
  const denied = requirePermission(claims, "viewAlumni") ??
    requireSchoolOperationalScope(claims);
  assertEquals(denied?.status, 403);
});
