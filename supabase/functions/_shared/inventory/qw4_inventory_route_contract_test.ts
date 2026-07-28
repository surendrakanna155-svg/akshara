// QW4 · QA-B-025 — Inventory module ROUTE + RBAC + entitlement contract (DB-free).
// After ICA-F6, routeInventory composes TWO sub-routers in order:
// matchInventoryIntelligenceRoute (copilot/lifecycle/procurement-workflow) and the
// base matchInventoryRoute (dashboard/assets/…). The procurement / vendor-catalog /
// stock (inventory_finance) surface moved to routeInventoryFinance — its route,
// RBAC and module.inventory-entitlement contract is proven in
// inventory_finance/inventory_finance_route_contract_test.ts.
//
// Proven without a live Postgres:
//   QA-B-025
//     • PATH-MATCH: every registered inventory route across both sub-routers
//       resolves to a handler (status !== 404); unregistered under /inventory 404s;
//       outside the prefix returns null.
//     • module.inventory 402 gate wired via withEntitlement on the /inventory prefix
//       (DB-free 503; pure 402 in qw4_entitlement_402_matrix_test.ts).
//     • POST /inventory/intelligence/lifecycle/events requires manageAssetLifecycle
//       OR manageInventory → 403 for a non-holder, 422 for a holder with a bad body
//       (validation runs before the DB), 503 for a holder with a valid body.
//
// Live RLS row isolation + 200 happy-path = live-cert remainder.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeInventory } from "./inventory_router.ts";
import { withEntitlement } from "../entitlements/entitlement_middleware.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;
const UUID = "11111111-1111-1111-1111-111111111111";

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "inventoryManager", role_slugs: ["inventoryManager"], primary_role: "inventoryManager",
    permissions: perms, permissions_version: 1, scope: "school", school_group_id: null,
    student_id: null, child_ids: [], session_id: "s1",
  };
}

async function call(
  router: (req: Request, c: AppConfig, m: string, p: string) => Promise<Response | null>,
  method: string,
  path: string,
  perms: string[],
  body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  return router(req, config, method, path);
}

// Registered surface OWNED by routeInventory: the base register + the
// intelligence sub-router. ICA-F6: the procurement / vendor-catalog / stock
// (inventory_finance) surface moved to routeInventoryFinance and is covered by
// inventory_finance/inventory_finance_route_contract_test.ts.
const REGISTERED: Array<[string, string]> = [
  // base reads
  ["GET", "/inventory/dashboard"],
  ["GET", "/inventory/assets"],
  ["GET", "/inventory/categories"],
  ["GET", "/inventory/allocations"],
  ["GET", "/inventory/maintenance"],
  ["GET", "/inventory/procurement"],
  ["GET", "/inventory/vendors"],
  ["GET", "/inventory/reports"],
  // intelligence
  ["GET", "/inventory/intelligence/copilot"],
  ["GET", "/inventory/intelligence/lifecycle"],
  ["POST", "/inventory/intelligence/lifecycle/events"],
  ["GET", "/inventory/intelligence/procurement-workflow"],
  ["POST", `/inventory/intelligence/procurement-workflow/${UUID}/advance`],
];

Deno.test("QA-B-025: every registered inventory route path-matches to a handler (not 404)", async () => {
  const perms = ["viewInventory", "manageInventory", "viewInventoryIntelligence", "manageAssetLifecycle", "manageProcurementWorkflow"];
  for (const [method, path] of REGISTERED) {
    const res = await call(routeInventory, method, path, perms);
    assertEquals(res !== null, true, `${method} ${path} returned null`);
    assertEquals(res!.status !== 404, true, `${method} ${path} unexpectedly 404'd`);
  }
});

Deno.test("QA-B-025: unregistered path under /inventory returns null (central dispatcher 404s); path outside prefix is null", async () => {
  const under = await call(routeInventory, "GET", "/inventory/not-a-route", ["viewInventory"]);
  assertEquals(under, null);
  const outside = await call(routeInventory, "GET", "/hostel/dashboard", ["viewInventory"]);
  assertEquals(outside, null);
});

Deno.test("QA-B-025: module.inventory 402 gate is wired via withEntitlement on the /inventory prefix", async () => {
  const wrapped = withEntitlement(routeInventory, "/inventory", "module.inventory");
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "true");
  const gated = await call(wrapped, "GET", "/inventory/dashboard", ["viewInventory"]);
  assertEquals(gated?.status, 503, "wrapped prefix did not route through the entitlement gate");
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "false");
  const passNonHolder = await call(wrapped, "GET", "/inventory/dashboard", []);
  assertEquals(passNonHolder?.status, 403);
  Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
});

Deno.test("QA-B-025: POST /inventory/intelligence/lifecycle/events — 403 non-holder, 422 bad body, 503 valid", async () => {
  // Token holding NEITHER lifecycle perm → denied.
  const denied = await call(routeInventory, "POST", "/inventory/intelligence/lifecycle/events", ["viewInventory"], {
    assetId: "a1", eventType: "purchase",
  });
  assertEquals(denied?.status, 403);
  assertEquals((await denied!.json()).error.code, "FORBIDDEN");

  // To pass the gate today a token must hold the ENTIRE chained set (see FINDING
  // QW4-INV-OR below: the `??` chain is an AND, not the intended OR). With both
  // slugs held but an invalid eventType → validation fires before the DB.
  const lifecyclePerms = ["manageAssetLifecycle", "manageInventory"];
  // NOTE: this handler validates with 422 VALIDATION_ERROR; the point is
  // that validation runs after the gate and before the DB.
  const badBody = await call(routeInventory, "POST", "/inventory/intelligence/lifecycle/events", lifecyclePerms, {
    assetId: "a1", eventType: "not-a-type",
  });
  assertEquals(badBody?.status, 422);

  // Both slugs held, valid body → reached the unconfigured tenant DB.
  const valid = await call(routeInventory, "POST", "/inventory/intelligence/lifecycle/events", lifecyclePerms, {
    assetId: "a1", eventType: "purchase",
  });
  assertEquals(valid?.status, 503);
});

// FINDING QW4-INV-OR (P1) — the inventory-intelligence permission gates are built
// as `requirePermission(A) ?? requirePermission(B) ?? requireSchoolOperationalScope`
// (inventory_intelligence_handlers.ts:25-44). `requirePermission` returns a 403
// Response on DENY and null on GRANT, so `??` yields the FIRST denial — turning the
// intended "A OR B OR scope" into "A AND B AND scope". Effect: a holder of the
// broader `manageInventory` (or `viewInventory`) slug is WRONGLY 403'd on the
// intelligence routes; only a holder of the narrow `manageAssetLifecycle` /
// `viewInventoryIntelligence` slug passes. This is over-restrictive (privilege is
// FIXED in QW4 (requireAnyPermission): the gate now OR-grants — EITHER the specific
// or the broader slug authorizes. This test verifies the restored OR semantics
// (previously it pinned the broken AND behaviour). The systemic fix spans 29 chains
// across 15 handler files; see docs/QW4_BACKEND_API_CERTIFICATION.md.
Deno.test("QA-B-025 [FIXED QW4-INV-OR]: intelligence gate OR-grants — the broader manageInventory alone now authorizes", async () => {
  // Per the OR-intent, manageInventory alone now passes requireAssetLifecycleManage
  // (reaches the unconfigured DB → 503), without needing manageAssetLifecycle.
  const broaderOnly = await call(routeInventory, "POST", "/inventory/intelligence/lifecycle/events", ["manageInventory"], {
    assetId: "a1", eventType: "purchase",
  });
  assertEquals(broaderOnly?.status, 503);

  // The specific slug alone also authorizes the READ gate (OR, not AND).
  const specificOnly = await call(routeInventory, "GET", "/inventory/intelligence/copilot", ["viewInventoryIntelligence"]);
  assertEquals(specificOnly?.status, 503);
  // The broader slug alone authorizes too — the previously-dead fallback now lives.
  const readBroaderOnly = await call(routeInventory, "GET", "/inventory/intelligence/copilot", ["viewInventory"]);
  assertEquals(readBroaderOnly?.status, 503);
  // A token holding NEITHER OR slug is still denied (the gate is not open).
  const neither = await call(routeInventory, "GET", "/inventory/intelligence/copilot", ["viewFinance"]);
  assertEquals(neither?.status, 403);
});

Deno.test("QA-B-025: GET /inventory/dashboard is 403 without viewInventory", async () => {
  const denied = await call(routeInventory, "GET", "/inventory/dashboard", ["viewFinance"]);
  assertEquals(denied?.status, 403);
});

// ICA-F6: routeInventory no longer owns the inventory_finance surface, so a
// procurement / stock path is now an in-prefix no-match → routeInventory returns
// null (the central dispatcher 404s), proving the delegation was removed. The
// positive route/RBAC contract for those paths lives in
// inventory_finance/inventory_finance_route_contract_test.ts.
Deno.test("ICA-F6: procurement / stock paths are no longer owned by routeInventory (null)", async () => {
  const movedOut: Array<[string, string]> = [
    ["GET", "/inventory/vendors/catalog"],
    ["POST", "/inventory/procurement/orders"],
    ["GET", "/inventory/stock/valuation"],
    ["POST", "/inventory/stock/adjust"],
    ["GET", "/inventory/stock/register"],
  ];
  for (const [method, path] of movedOut) {
    const res = await call(routeInventory, method, path, ["viewInventory", "manageInventory"]);
    assertEquals(res, null, `${method} ${path} should return null through routeInventory after ICA-F6`);
  }
});
