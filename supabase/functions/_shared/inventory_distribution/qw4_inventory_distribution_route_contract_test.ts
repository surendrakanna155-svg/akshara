// QW4 · QA-B-002 — inventory_distribution ROUTE/RBAC contract (DB-free).
//
// Proves the `routeInventoryDistribution` write/read gates WITHOUT a live
// Postgres. As in finance_collections_route_contract_test.ts, a 503
// (TENANT_DB_NOT_CONFIGURED) means the permission gate PASSED and the handler
// reached the (unconfigured) tenant DB — the DB-free proxy for "authorized".
//
// What's proven here:
//   - POST /inventory/distribution/items persists for a holder (gate→503) and is
//     denied for a non-holder (403 FORBIDDEN).
//   - The QW4-INV-OR fix: BOTH the specific slug (view/manageInventoryDistribution)
//     and the broader inventory slug (view/manageInventory) independently
//     authorize — i.e. it is a real OR, not a collapsed AND.
//   - Validation fires before the DB (422); unauthenticated callers get 401;
//     unregistered paths return 404.
// Live remainder (infra): the real 201 + persisted distribution row + per-school
// RLS isolation is covered by the repository test + the live cert.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeInventoryDistribution } from "./inventory_distribution_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(permissions: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "inventoryManager",
    role_slugs: ["inventoryManager"],
    primary_role: "inventoryManager",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

async function call(
  method: string,
  path: string,
  perms: string[],
  body?: unknown,
  over?: Partial<AccessTokenClaims>,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  return routeInventoryDistribution(req, config, method, path);
}

const validCreate = { studentId: "stu-1", catalogItemId: "cat-1", quantity: 2 };

Deno.test("QA-B-002: create distribution is denied for a non-holder (403 FORBIDDEN)", async () => {
  // viewSis: neither manageInventoryDistribution nor manageInventory.
  const res = await call("POST", "/inventory/distribution/items", ["viewSis"], validCreate);
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-002: create distribution passes the gate with manageInventoryDistribution (503)", async () => {
  const res = await call("POST", "/inventory/distribution/items", ["manageInventoryDistribution"], validCreate);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-002: OR-fix — broader manageInventory also authorizes the write (503)", async () => {
  // If the gate had collapsed into an AND, manageInventory alone would 403.
  const res = await call("POST", "/inventory/distribution/items", ["manageInventory"], validCreate);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-002: create distribution rejects a missing catalogItemId (422) before the DB", async () => {
  const res = await call("POST", "/inventory/distribution/items", ["manageInventoryDistribution"], {
    studentId: "stu-1",
  });
  assertEquals(res?.status, 422);
});

Deno.test("QA-B-002: read list is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("GET", "/inventory/distribution/items", ["viewSis"]);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-002: read list passes the gate with viewInventoryDistribution (503)", async () => {
  const res = await call("GET", "/inventory/distribution/items", ["viewInventoryDistribution"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-002: OR-fix — broader viewInventory also authorizes the read (503)", async () => {
  const res = await call("GET", "/inventory/distribution/items", ["viewInventory"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-002: write gate denies a holder of only the READ slug (403)", async () => {
  // viewInventoryDistribution must NOT authorize a write.
  const res = await call("POST", "/inventory/distribution/items", ["viewInventoryDistribution"], validCreate);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-002: unauthenticated create is rejected (401)", async () => {
  const req = new Request("https://x/inventory/distribution/items", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(validCreate),
  });
  const res = await routeInventoryDistribution(req, config, "POST", "/inventory/distribution/items");
  assertEquals(res?.status, 401);
});

Deno.test("QA-B-002: router returns null for a path outside its prefix", async () => {
  const res = await call("GET", "/finance/refunds", ["viewInventory"]);
  assertEquals(res, null);
});

Deno.test("QA-B-002: unregistered path under the prefix returns 404", async () => {
  const res = await call("GET", "/inventory/distribution/nope", ["viewInventory"]);
  assertEquals(res?.status, 404);
});
