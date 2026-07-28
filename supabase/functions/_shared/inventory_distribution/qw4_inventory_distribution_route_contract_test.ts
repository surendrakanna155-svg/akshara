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

Deno.test("QA-B-002: unregistered path under the prefix returns null (central dispatcher 404s)", async () => {
  const res = await call("GET", "/inventory/distribution/nope", ["viewInventory"]);
  assertEquals(res, null);
});

// ─── Gap-sweep 2 · Step 4 (#2) — replacements workflow (list/approve/fulfill/reject) ───

const rplId = "11111111-1111-1111-1111-111111111111";

Deno.test("gap-sweep-2/step-4: list replacements is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("GET", "/inventory/distribution/replacements", ["viewSis"]);
  assertEquals(res?.status, 403);
});

Deno.test("gap-sweep-2/step-4: list replacements passes the gate with viewInventoryDistribution (503)", async () => {
  const res = await call("GET", "/inventory/distribution/replacements", ["viewInventoryDistribution"]);
  assertEquals(res?.status, 503);
});

Deno.test("gap-sweep-2/step-4: OR-fix — broader viewInventory also authorizes the replacements read (503)", async () => {
  const res = await call("GET", "/inventory/distribution/replacements", ["viewInventory"]);
  assertEquals(res?.status, 503);
});

Deno.test("gap-sweep-2/step-4: approve is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("POST", `/inventory/distribution/replacements/${rplId}/approve`, ["viewSis"]);
  assertEquals(res?.status, 403);
});

Deno.test("gap-sweep-2/step-4: approve passes the gate with manageInventoryDistribution (503)", async () => {
  const res = await call("POST", `/inventory/distribution/replacements/${rplId}/approve`, [
    "manageInventoryDistribution",
  ]);
  assertEquals(res?.status, 503);
});

Deno.test("gap-sweep-2/step-4: OR-fix — broader manageInventory also authorizes approve (503)", async () => {
  const res = await call("POST", `/inventory/distribution/replacements/${rplId}/approve`, ["manageInventory"]);
  assertEquals(res?.status, 503);
});

Deno.test("gap-sweep-2/step-4: approve denies a holder of only the READ slug (403)", async () => {
  const res = await call("POST", `/inventory/distribution/replacements/${rplId}/approve`, [
    "viewInventoryDistribution",
  ]);
  assertEquals(res?.status, 403);
});

Deno.test("gap-sweep-2/step-4: fulfill is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("POST", `/inventory/distribution/replacements/${rplId}/fulfill`, ["viewSis"]);
  assertEquals(res?.status, 403);
});

Deno.test("gap-sweep-2/step-4: fulfill passes the gate with manageInventoryDistribution (503)", async () => {
  const res = await call("POST", `/inventory/distribution/replacements/${rplId}/fulfill`, [
    "manageInventoryDistribution",
  ]);
  assertEquals(res?.status, 503);
});

Deno.test("gap-sweep-2/step-4: reject is denied for a non-holder (403 FORBIDDEN)", async () => {
  const res = await call("POST", `/inventory/distribution/replacements/${rplId}/reject`, ["viewSis"], {
    reason: "damaged beyond repair",
  });
  assertEquals(res?.status, 403);
});

Deno.test("gap-sweep-2/step-4: reject passes the gate with manageInventoryDistribution (503)", async () => {
  const res = await call(
    "POST",
    `/inventory/distribution/replacements/${rplId}/reject`,
    ["manageInventoryDistribution"],
    { reason: "damaged beyond repair" },
  );
  assertEquals(res?.status, 503);
});

Deno.test("gap-sweep-2/step-4: unauthenticated approve is rejected (401)", async () => {
  const req = new Request(`https://x/inventory/distribution/replacements/${rplId}/approve`, {
    method: "POST",
    headers: { "content-type": "application/json" },
  });
  const res = await routeInventoryDistribution(
    req,
    config,
    "POST",
    `/inventory/distribution/replacements/${rplId}/approve`,
  );
  assertEquals(res?.status, 401);
});

Deno.test("gap-sweep-2/step-4: non-UUID replacement id under /approve is unregistered (null)", async () => {
  const res = await call("POST", "/inventory/distribution/replacements/not-a-uuid/approve", [
    "manageInventoryDistribution",
  ]);
  assertEquals(res, null);
});

// ─── Gap-remediation P0-3 — POST /items/:id/replacement (request-replacement) ──
//
// This route was previously untested at the contract level even though its
// handler (`handleRequestReplacement`) carries a deliberate
// `scope !== "parent"` bypass of the staff write-permission gate — i.e. a
// parent-scope caller with ZERO staff RBAC permissions is meant to reach the
// DB here, while a school-scope caller still needs manageInventoryDistribution/
// manageInventory. These prove that contract explicitly.

const itemId = "33333333-3333-3333-3333-333333333333";

Deno.test("gap-remediation/P0-3: parent-scope replacement request reaches the DB with NO staff inventory permission (503)", async () => {
  const res = await call(
    "POST",
    `/inventory/distribution/items/${itemId}/replacement`,
    [], // parents carry no staff RBAC permissions — scope alone is the gate
    { notes: "torn cover" },
    { scope: "parent" },
  );
  assertEquals(res?.status, 503);
});

Deno.test("gap-remediation/P0-3: school-scope replacement request without manage permission is denied (403)", async () => {
  const res = await call(
    "POST",
    `/inventory/distribution/items/${itemId}/replacement`,
    ["viewSis"],
    { notes: "torn cover" },
  );
  assertEquals(res?.status, 403);
});

Deno.test("gap-remediation/P0-3: school-scope replacement request WITH manageInventoryDistribution passes the gate (503)", async () => {
  const res = await call(
    "POST",
    `/inventory/distribution/items/${itemId}/replacement`,
    ["manageInventoryDistribution"],
    { notes: "torn cover" },
  );
  assertEquals(res?.status, 503);
});

Deno.test("gap-remediation/P0-3: unauthenticated replacement request is rejected (401)", async () => {
  const req = new Request(`https://x/inventory/distribution/items/${itemId}/replacement`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ notes: "torn cover" }),
  });
  const res = await routeInventoryDistribution(
    req,
    config,
    "POST",
    `/inventory/distribution/items/${itemId}/replacement`,
  );
  assertEquals(res?.status, 401);
});
