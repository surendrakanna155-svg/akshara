import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { requirePermission } from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { controlCenterStore } from "../control_center/control_center_read_repository.ts";
import { managementStore } from "../management/management_read_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";

class MockSchoolDb {
  constructor(private readonly rows: Array<{ entity_type: string; id: string; payload: Record<string, unknown> }>) {}
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("entity_type = $3") && sql.includes("AND id = $4")) {
      const row = this.rows.find((r) => r.entity_type === args[2] && r.id === args[3]);
      return row ? [{ payload: row.payload }] as T[] : [] as T[];
    }
    if (sql.includes("entity_type = $2") && sql.includes("AND id = $3")) {
      const row = this.rows.find((r) => r.entity_type === args[1] && r.id === args[2]);
      return row ? [{ payload: row.payload }] as T[] : [] as T[];
    }
    return [] as T[];
  }
}

Deno.test("management getSnapshot returns dashboard", async () => {
  const db = new MockSchoolDb([
    { entity_type: "snapshot_dashboard", id: "default", payload: { aiInsight: "ok", kpis: [] } },
  ]) as unknown as TenantQueryClient;
  const snapshot = await managementStore.getSnapshot(db, ORG, SCHOOL_A, "snapshot_dashboard");
  assertEquals(snapshot.aiInsight, "ok");
});

Deno.test("control center getSnapshot returns dashboard", async () => {
  const db = new MockSchoolDb([
    { entity_type: "snapshot_dashboard", id: "default", payload: { aiInsight: "ok", kpis: [] } },
  ]) as unknown as TenantQueryClient;
  const snapshot = await controlCenterStore.getSnapshot(db, ORG, "snapshot_dashboard");
  assertEquals(snapshot.aiInsight, "ok");
});

Deno.test("viewManagement permission enforced", () => {
  const claims: AccessTokenClaims = {
    sub: "staff", tenant_id: ORG, organization_id: ORG, school_id: SCHOOL_A,
    role: "schoolAdmin", role_slugs: ["schoolAdmin"], primary_role: "schoolAdmin",
    permissions: [], permissions_version: 1, scope: "school",
    school_group_id: null, student_id: null, child_ids: [], session_id: "test",
  };
  assertEquals(requirePermission(claims, "viewManagement")?.status, 403);
});

Deno.test("viewControlCenter permission enforced", () => {
  const claims: AccessTokenClaims = {
    sub: "staff", tenant_id: ORG, organization_id: ORG, school_id: null,
    role: "superAdmin", role_slugs: ["superAdmin"], primary_role: "superAdmin",
    permissions: [], permissions_version: 1, scope: "organization",
    school_group_id: null, student_id: null, child_ids: [], session_id: "test",
  };
  assertEquals(requirePermission(claims, "viewControlCenter")?.status, 403);
});
