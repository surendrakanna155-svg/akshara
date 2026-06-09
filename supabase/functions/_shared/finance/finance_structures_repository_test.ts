import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import {
  decodeFeeHead,
  encodeFeeHead,
  feeStructureToApi,
  parseItemInputsFromBody,
} from "./finance_mapper.ts";
import {
  archiveFeeStructure,
  createFeeStructure,
  getFeeStructure,
  listFeeStructures,
  updateFeeStructure,
} from "./finance_structures_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const STAFF = "a3000000-0000-4000-8000-000000000001";

function schoolClaims(permissions: string[]): AccessTokenClaims {
  return {
    sub: STAFF,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions,
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
    ...schoolClaims(["viewFinance", "manageFinance"]),
    school_id: null,
    scope: "organization",
    role: "organizationAdmin",
    role_slugs: ["organizationAdmin"],
    primary_role: "organizationAdmin",
  };
}

type Row = Record<string, unknown>;

class MockTenantDb {
  structures: Row[] = [];
  items: Row[] = [];
  queries: string[] = [];

  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    this.queries.push(sql);
    if (sql.includes("finance_fee_structures")) {
      return this.structures.filter((row) =>
        row.organization_id === args[0] && row.school_id === args[1]
      ).length;
    }
    return 0;
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    this.queries.push(sql);
    if (sql.startsWith("DELETE FROM finance_fee_structure_items")) {
      this.items = this.items.filter((row) => row.fee_structure_id !== args[0]);
      return [] as T[];
    }
    if (sql.includes("INSERT INTO finance_fee_structures")) {
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        school_id: args[1],
        name: args[2],
        academic_year: args[3],
        description: args[4],
        status: args[5],
        created_by: args[6],
        created_at: "2026-06-12T00:00:00.000Z",
        updated_at: "2026-06-12T00:00:00.000Z",
      };
      this.structures.push(row);
      return [row as T];
    }
    if (sql.includes("INSERT INTO finance_fee_structure_items")) {
      const row = {
        id: crypto.randomUUID(),
        fee_structure_id: args[0],
        organization_id: args[1],
        school_id: args[2],
        fee_head: args[3],
        amount: String(args[4]),
        sort_order: args[5],
        created_at: "2026-06-12T00:00:00.000Z",
      };
      this.items.push(row);
      return [] as T[];
    }
    if (sql.includes("SELECT * FROM finance_fee_structures") && sql.includes("WHERE id =")) {
      const found = this.structures.find((row) =>
        row.id === args[0] &&
        row.organization_id === args[1] &&
        row.school_id === args[2]
      );
      return (found ? [found] : []) as T[];
    }
    if (sql.includes("SELECT * FROM finance_fee_structure_items")) {
      const rows = this.items.filter((row) =>
        row.fee_structure_id === args[0] &&
        row.organization_id === args[1] &&
        row.school_id === args[2]
      );
      return rows as T[];
    }
    if (sql.includes("UPDATE finance_fee_structures")) {
      const idx = this.structures.findIndex((row) => row.id === args[0]);
      if (idx < 0) return [] as T[];
      this.structures[idx] = {
        ...this.structures[idx],
        name: args[3],
        academic_year: args[4],
        description: args[5],
        status: args[6],
        updated_at: "2026-06-12T01:00:00.000Z",
      };
      return [this.structures[idx] as T];
    }
    if (sql.includes("ORDER BY created_at DESC")) {
      return this.structures.filter((row) =>
        row.organization_id === args[0] && row.school_id === args[1]
      ) as T[];
    }
    return [] as T[];
  }

}

function asDb(mock: MockTenantDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("encodeFeeHead and decodeFeeHead round-trip category labels", () => {
  const encoded = encodeFeeHead("transport", "Bus Fee");
  assertEquals(encoded, "transport:Bus Fee");
  assertEquals(decodeFeeHead(encoded), { category: "transport", label: "Bus Fee" });
});

Deno.test("parseItemInputsFromBody accepts client categories payload", () => {
  const items = parseItemInputsFromBody({
    categories: [
      { category: "tuition", label: "Annual Tuition", amount: "50000" },
      { category: "activity", label: "Lab Fee", amount: "5000" },
    ],
  });
  assertEquals(items.length, 2);
  assertEquals(items[0]!.feeHead, "tuition:Annual Tuition");
  assertEquals(items[0]!.amount, 50000);
});

Deno.test("feeStructureToApi maps structure and items to client contract", () => {
  const api = feeStructureToApi(
    {
      id: "struct-1",
      organization_id: ORG,
      school_id: SCHOOL_A,
      name: "Standard 5",
      academic_year: "2026-27",
      description: "Classes 1-5",
      status: "active",
      created_by: STAFF,
      created_at: "2026-06-12T00:00:00.000Z",
      updated_at: "2026-06-12T00:00:00.000Z",
    },
    [{
      id: "item-1",
      fee_structure_id: "struct-1",
      organization_id: ORG,
      school_id: SCHOOL_A,
      fee_head: "tuition:Annual Tuition",
      amount: "50000",
      sort_order: 0,
      created_at: "2026-06-12T00:00:00.000Z",
    }],
  );
  assertEquals(api.name, "Standard 5");
  assertEquals(api.totalAnnual, "50000");
  assertEquals(api.classRange, "Classes 1-5");
  assertEquals((api.categories as Array<Record<string, string>>)[0]?.category, "tuition");
});

Deno.test("createFeeStructure inserts header and line items", async () => {
  const db = new MockTenantDb();
  const result = await createFeeStructure(asDb(db), ORG, SCHOOL_A, {
    name: "Grade 5 Plan",
    academicYear: "2026-27",
    description: "Classes 4-5",
    status: "active",
    createdBy: STAFF,
    items: [{ feeHead: "tuition:Tuition", amount: 45000, sortOrder: 0 }],
  });
  assertEquals(result.structure.name, "Grade 5 Plan");
  assertEquals(result.items.length, 1);
  assertEquals(db.structures.length, 1);
});

Deno.test("listFeeStructures returns paginated structures with items", async () => {
  const db = new MockTenantDb();
  await createFeeStructure(asDb(db), ORG, SCHOOL_A, {
    name: "A",
    academicYear: "2026-27",
    description: null,
    status: "active",
    createdBy: STAFF,
    items: [],
  });
  const page = await listFeeStructures(asDb(db), ORG, SCHOOL_A, { page: 1, pageSize: 20 });
  assertEquals(page.total, 1);
  assertEquals(page.items.length, 1);
});

Deno.test("getFeeStructure returns null for missing id", async () => {
  const db = new MockTenantDb();
  const result = await getFeeStructure(asDb(db), ORG, SCHOOL_A, "missing");
  assertEquals(result, null);
});

Deno.test("updateFeeStructure replaces items when provided", async () => {
  const db = new MockTenantDb();
  const created = await createFeeStructure(asDb(db), ORG, SCHOOL_A, {
    name: "Original",
    academicYear: "2026-27",
    description: null,
    status: "active",
    createdBy: STAFF,
    items: [{ feeHead: "tuition:Old", amount: 1000, sortOrder: 0 }],
  });
  const updated = await updateFeeStructure(asDb(db), ORG, SCHOOL_A, created.structure.id as string, {
    name: "Updated",
    items: [{ feeHead: "tuition:New", amount: 2000, sortOrder: 0 }],
  });
  assertEquals(updated?.structure.name, "Updated");
  assertEquals(updated?.items[0]?.fee_head, "tuition:New");
});

Deno.test("archiveFeeStructure sets status inactive", async () => {
  const db = new MockTenantDb();
  const created = await createFeeStructure(asDb(db), ORG, SCHOOL_A, {
    name: "To Archive",
    academicYear: "2026-27",
    description: null,
    status: "active",
    createdBy: STAFF,
    items: [],
  });
  const archived = await archiveFeeStructure(
    asDb(db),
    ORG,
    SCHOOL_A,
    created.structure.id as string,
  );
  assertEquals(archived?.structure.status, "inactive");
});

Deno.test("viewFinance required for finance read scope", () => {
  const withoutPerm = requirePermission(schoolClaims([]), "viewFinance");
  assertEquals(withoutPerm?.status, 403);

  const withPerm = requirePermission(schoolClaims(["viewFinance"]), "viewFinance");
  assertEquals(withPerm, null);
});

Deno.test("manageFinance required for finance writes", () => {
  const denied = requirePermission(schoolClaims(["viewFinance"]), "manageFinance");
  assertEquals(denied?.status, 403);

  const allowed = requirePermission(
    schoolClaims(["viewFinance", "manageFinance"]),
    "manageFinance",
  );
  assertEquals(allowed, null);
});

Deno.test("organization scope denied at middleware for finance operations", () => {
  const denied = requireSchoolOperationalScope(orgClaims());
  assertEquals(denied?.status, 403);
});
