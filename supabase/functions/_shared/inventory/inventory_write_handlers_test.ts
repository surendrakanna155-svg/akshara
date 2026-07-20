// PRA-P1-39 — inventory register write coverage.
//
// The register was 100% read-only: inventory_router hard-rejected every non-GET
// method (404) and there was NO inventory_write_handlers.ts. These tests pin the
// three load-bearing pieces the new write path composes, exactly as
// transport_write_handlers_test.ts does for transport: (1) the entity-store
// persistence shape each handler writes (so the matching GET reads it back),
// (2) the router wiring — POST/PUT under /inventory now resolve to a handler and
// are gated on manageInventory instead of 404-ing, and (3) the manageInventory
// RBAC gate + duplicate-asset-tag guard.

import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import {
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { requireStr } from "../entity_write/module_write_handlers.ts";
import { WriteValidationError } from "../entity_write/module_write_handlers.ts";
import { assetTagKey } from "./inventory_write_handlers.ts";
import { routeInventory } from "./inventory_router.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";

const writeStore = createEntityWriteStore("inventory_entities", "Inventory");

interface EntityRow {
  id: string;
  organization_id: string;
  school_id: string;
  entity_type: string;
  payload: Record<string, unknown>;
}

/** In-memory stand-in for inventory_entities honouring the exact SQL the entity
 * write store issues (mirrors MockTransportWriteDb). */
class MockInventoryWriteDb {
  rows: EntityRow[] = [];

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("INSERT INTO inventory_entities")) {
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
    if (sql.includes("UPDATE inventory_entities")) {
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

function schoolClaims(perms: string[]): AccessTokenClaims {
  return {
    sub: "staff",
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "inventoryManager",
    role_slugs: ["inventoryManager"],
    primary_role: "inventoryManager",
    permissions: perms,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "test",
  };
}

// ── Persistence shape: an asset write reads back on the asset list ────────────

Deno.test("P1-39: create-asset persists an asset entity the list reads back", async () => {
  const db = new MockInventoryWriteDb() as unknown as TenantQueryClient;
  const payload = {
    id: "asset-1",
    assetTag: "AKS-LAP-001",
    name: "Dell Latitude 5440",
    category: "IT Equipment",
    location: "Staff Room",
    status: "available",
  };
  await writeStore.insert(db, ORG, SCHOOL_A, "asset", "asset-1", payload);

  const listed = await writeStore.findAll(db, ORG, SCHOOL_A, "asset");
  assertEquals(listed.length, 1);
  assertEquals(listed[0].assetTag, "AKS-LAP-001");
  assertEquals(listed[0].name, "Dell Latitude 5440");
  assertEquals(listed[0].status, "available");
});

Deno.test("P1-39: update-asset replaces in place, not duplicates", async () => {
  const db = new MockInventoryWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "asset", "asset-1", {
    id: "asset-1",
    assetTag: "AKS-LAP-001",
    status: "available",
  });
  await writeStore.replace(db, ORG, SCHOOL_A, "asset", "asset-1", {
    id: "asset-1",
    assetTag: "AKS-LAP-001",
    status: "maintenance",
  });
  const listed = await writeStore.findAll(db, ORG, SCHOOL_A, "asset");
  assertEquals(listed.length, 1);
  assertEquals(listed[0].status, "maintenance");
});

Deno.test("P1-39: allocation + maintenance writes read back on their own lists", async () => {
  const db = new MockInventoryWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "allocation", "alloc-1", {
    id: "alloc-1",
    assetTag: "AKS-LAP-001",
    assignedTo: "R. Sharma",
    status: "active",
  });
  await writeStore.insert(db, ORG, SCHOOL_A, "maintenance", "mnt-1", {
    id: "mnt-1",
    assetTag: "AKS-PRN-002",
    maintenanceType: "Servicing",
    status: "scheduled",
  });
  assertEquals((await writeStore.findAll(db, ORG, SCHOOL_A, "allocation")).length, 1);
  assertEquals((await writeStore.findAll(db, ORG, SCHOOL_A, "maintenance"))[0].status, "scheduled");
});

// ── Duplicate asset-tag guard (case/space-insensitive) ────────────────────────

Deno.test("P1-39: a duplicate asset tag is detected (case/space-insensitive)", async () => {
  const db = new MockInventoryWriteDb() as unknown as TenantQueryClient;
  await writeStore.insert(db, ORG, SCHOOL_A, "asset", "asset-1", {
    id: "asset-1",
    assetTag: "AKS-LAP-001",
  });
  const existing = await writeStore.findAll(db, ORG, SCHOOL_A, "asset");
  const isDuplicate = existing.some(
    (a) => assetTagKey(String(a.assetTag ?? "")) === assetTagKey("  aks-lap-001 "),
  );
  assertEquals(isDuplicate, true);
});

Deno.test("P1-39: create-asset requires assetTag and name", () => {
  assertThrows(() => requireStr({ name: "x" }, "assetTag", "asset_tag", "tag"), WriteValidationError);
  assertThrows(() => requireStr({ assetTag: "T1" }, "name"), WriteValidationError);
});

// ── RBAC: manageInventory required for register writes ────────────────────────

Deno.test("P1-39: manageInventory required for inventory writes", () => {
  const denied = requirePermission(schoolClaims(["viewInventory"]), "manageInventory") ??
    requireSchoolOperationalScope(schoolClaims(["viewInventory"]));
  assertEquals(denied?.status, 403);
});

// ── Router wiring: POST/PUT under /inventory no longer 404 — they gate + route ─
// Before P1-39 every non-GET returned 404 NOT_FOUND. Now a non-holder sees the
// manageInventory 403, and a holder reaches the (unconfigured) tenant DB → 503:
// the standard proxy for "authorized; would have hit the DB".

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

async function call(
  method: string,
  path: string,
  perms: string[],
  body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, schoolClaims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  return await routeInventory(req, config, method, path);
}

Deno.test("P1-39: POST /inventory/assets is 403 without manageInventory, 503 with it (wired, not 404)", async () => {
  const denied = await call("POST", "/inventory/assets", ["viewInventory"], {
    assetTag: "AKS-LAP-001",
    name: "Dell Latitude",
  });
  assertEquals(denied?.status, 403);
  assertEquals((await denied!.json()).error.code, "FORBIDDEN");

  const allowed = await call("POST", "/inventory/assets", ["manageInventory"], {
    assetTag: "AKS-LAP-001",
    name: "Dell Latitude",
  });
  assertEquals(allowed?.status, 503); // gate passed → unconfigured tenant DB
});

Deno.test("P1-39: PUT /inventory/assets/{id} + POST categories/allocations/maintenance are wired (403/503, not 404)", async () => {
  for (
    const [method, path, body] of [
      ["PUT", "/inventory/assets/asset-1", { name: "Renamed" }],
      ["POST", "/inventory/categories", { name: "IT Equipment" }],
      ["POST", "/inventory/allocations", { assignedTo: "R. Sharma" }],
      ["POST", "/inventory/maintenance", { assetTag: "AKS-PRN-002" }],
    ] as const
  ) {
    const denied = await call(method, path, ["viewInventory"], body);
    assertEquals(denied?.status, 403, `${method} ${path} should 403 a non-holder (was it 404?)`);
    const allowed = await call(method, path, ["manageInventory"], body);
    assertEquals(allowed?.status, 503, `${method} ${path} should reach the DB for a holder`);
  }
});
