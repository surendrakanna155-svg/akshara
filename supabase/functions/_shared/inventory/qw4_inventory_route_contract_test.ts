// QW4 · QA-B-025 / QA-B-026 / QA-B-042 — Inventory module ROUTE + RBAC +
// entitlement contract (DB-free). routeInventory composes three sub-routers in
// order: routeInventoryFinanceWrite (procurement/vendors-catalog/valuation),
// matchInventoryIntelligenceRoute (copilot/lifecycle/procurement-workflow), and
// the base matchInventoryRoute (dashboard/assets/…).
//
// Proven without a live Postgres:
//   QA-B-025
//     • PATH-MATCH: every registered inventory route across all three sub-routers
//       resolves to a handler (status !== 404); unregistered under /inventory 404s;
//       outside the prefix returns null.
//     • module.inventory 402 gate wired via withEntitlement on the /inventory prefix
//       (DB-free 503; pure 402 in qw4_entitlement_402_matrix_test.ts).
//     • POST /inventory/intelligence/lifecycle/events requires manageAssetLifecycle
//       OR manageInventory → 403 for a non-holder, 422 for a holder with a bad body
//       (validation runs before the DB), 503 for a holder with a valid body.
//   QA-B-026 / QA-B-042
//     • POST /inventory/procurement/orders, POST /inventory/vendors/catalog and
//       POST /inventory/vendors require manageInventory → 403 for a non-holder.
//     • GET /inventory/stock/valuation and GET /inventory/vendors/catalog require
//       viewInventory → 403 for a token lacking it.
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

// Full registered surface across the three composed sub-routers.
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
  // finance writes / procurement / valuation
  ["GET", "/inventory/vendors/catalog"],
  ["POST", "/inventory/vendors/catalog"],
  ["GET", "/inventory/procurement/orders"],
  ["POST", "/inventory/procurement/orders"],
  ["GET", `/inventory/procurement/orders/${UUID}`],
  ["POST", `/inventory/procurement/orders/${UUID}/approve`],
  ["POST", `/inventory/procurement/orders/${UUID}/receive`],
  ["GET", "/inventory/stock/valuation"],
  // INV-1..7: store stock module
  ["POST", "/inventory/stock/issue"],
  ["POST", "/inventory/stock/adjust"],
  ["POST", `/inventory/stock/adjustments/${UUID}/approve`],
  ["POST", `/inventory/stock/adjustments/${UUID}/reject`],
  ["GET", "/inventory/stock/adjustments"],
  ["POST", "/inventory/stock/count"],
  ["GET", "/inventory/stock/items"],
  ["POST", "/inventory/stock/items"],
  ["PUT", "/inventory/stock/items"],
  ["GET", "/inventory/stock/register"],
  ["GET", "/inventory/stock/low-stock"],
];

Deno.test("QA-B-025: every registered inventory route path-matches to a handler (not 404)", async () => {
  const perms = ["viewInventory", "manageInventory", "viewInventoryIntelligence", "manageAssetLifecycle", "manageProcurementWorkflow"];
  for (const [method, path] of REGISTERED) {
    const res = await call(routeInventory, method, path, perms);
    assertEquals(res !== null, true, `${method} ${path} returned null`);
    assertEquals(res!.status !== 404, true, `${method} ${path} unexpectedly 404'd`);
  }
});

Deno.test("QA-B-025: unregistered path under /inventory 404s; path outside prefix is null", async () => {
  const under = await call(routeInventory, "GET", "/inventory/not-a-route", ["viewInventory"]);
  assertEquals(under?.status, 404);
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

// ─── QA-B-026 / QA-B-042 — procurement / vendor-catalog / valuation RBAC ──────

Deno.test("QA-B-026: POST /inventory/procurement/orders is 403 without manageInventory", async () => {
  const denied = await call(routeInventory, "POST", "/inventory/procurement/orders", ["viewInventory"], {
    vendorId: "v1", poNumber: "PO-1", lines: [{ sku: "x", qty: 1 }],
  });
  assertEquals(denied?.status, 403);
  assertEquals((await denied!.json()).error.code, "FORBIDDEN");
  // Holder reaches the unconfigured tenant DB (gate + body validation passed).
  const allowed = await call(routeInventory, "POST", "/inventory/procurement/orders", ["manageInventory"], {
    vendorId: "v1", poNumber: "PO-1", lines: [{ sku: "x", qty: 1 }],
  });
  assertEquals(allowed?.status, 503);
});

Deno.test("QA-B-026: POST /inventory/vendors/catalog is 403 without manageInventory", async () => {
  const denied = await call(routeInventory, "POST", "/inventory/vendors/catalog", ["viewInventory"], {
    vendorCode: "VC1", displayName: "Acme",
  });
  assertEquals(denied?.status, 403);
  const allowed = await call(routeInventory, "POST", "/inventory/vendors/catalog", ["manageInventory"], {
    vendorCode: "VC1", displayName: "Acme",
  });
  assertEquals(allowed?.status, 503);
});

Deno.test("QA-B-042: GET /inventory/vendors/catalog requires viewInventory (403 otherwise)", async () => {
  const denied = await call(routeInventory, "GET", "/inventory/vendors/catalog", ["viewFinance"]);
  assertEquals(denied?.status, 403);
  const allowed = await call(routeInventory, "GET", "/inventory/vendors/catalog", ["viewInventory"]);
  assertEquals(allowed?.status, 503);
});

Deno.test("QA-B-042: GET /inventory/stock/valuation requires viewInventory (403 otherwise)", async () => {
  const denied = await call(routeInventory, "GET", "/inventory/stock/valuation", ["viewFinance"]);
  assertEquals(denied?.status, 403);
  const allowed = await call(routeInventory, "GET", "/inventory/stock/valuation", ["viewInventory"]);
  assertEquals(allowed?.status, 503);
});

Deno.test("QA-B-042: GET /inventory/procurement/orders requires viewInventory (403 otherwise)", async () => {
  const denied = await call(routeInventory, "GET", "/inventory/procurement/orders", ["viewFinance"]);
  assertEquals(denied?.status, 403);
});

Deno.test("QA-B-026: unauthenticated procurement write is 401", async () => {
  const req = new Request("https://x/inventory/procurement/orders", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ vendorId: "v1", poNumber: "PO-1", lines: [{}] }),
  });
  const res = await routeInventory(req, config, "POST", "/inventory/procurement/orders");
  assertEquals(res?.status, 401);
});

// ─── INV-1..7 — store stock module RBAC + contract (DB-free) ──────────────────

Deno.test("INV: stock writes require manageInventory (403 without, 503 with valid body)", async () => {
  const writes: Array<[string, string, unknown]> = [
    ["POST", "/inventory/stock/issue", { issueNumber: "ISS-1", lines: [{ sku: "PEN-1", quantity: 2 }] }],
    ["POST", "/inventory/stock/adjust", { sku: "PEN-1", quantity: 3, movementType: "adjust_in", reason: "restock" }],
    ["POST", `/inventory/stock/adjustments/${UUID}/approve`, {}],
    ["POST", `/inventory/stock/adjustments/${UUID}/reject`, { comment: "no" }],
    ["POST", "/inventory/stock/count", { sessionNumber: "CNT-1", lines: [{ sku: "PEN-1", countedQty: 5 }] }],
    ["POST", "/inventory/stock/items", { sku: "PEN-1", reorderLevel: 10 }],
    ["PUT", "/inventory/stock/items", { sku: "PEN-1", reorderLevel: 10 }],
  ];
  for (const [method, path, body] of writes) {
    const denied = await call(routeInventory, method, path, ["viewInventory"], body);
    assertEquals(denied?.status, 403, `${method} ${path} should 403 without manageInventory`);
    assertEquals((await denied!.json()).error.code, "FORBIDDEN");
    // Holder with a valid body passes gate + validation → reaches unconfigured DB (503).
    const allowed = await call(routeInventory, method, path, ["manageInventory"], body);
    assertEquals(allowed?.status, 503, `${method} ${path} should reach DB (503) for a holder`);
  }
});

Deno.test("INV: stock writes 422 on an invalid body before touching the DB", async () => {
  // Holder, but missing required fields → 422 validation (not 503/500).
  const badIssue = await call(routeInventory, "POST", "/inventory/stock/issue", ["manageInventory"], { issueNumber: "ISS-1" });
  assertEquals(badIssue?.status, 422);
  const badAdjust = await call(routeInventory, "POST", "/inventory/stock/adjust", ["manageInventory"], { sku: "PEN-1", movementType: "bogus", reason: "x" });
  assertEquals(badAdjust?.status, 422);
});

Deno.test("INV: stock reads require viewInventory (403 without, 503 with)", async () => {
  const reads = [
    "/inventory/stock/adjustments",
    "/inventory/stock/items",
    "/inventory/stock/register",
    "/inventory/stock/low-stock",
  ];
  for (const path of reads) {
    const denied = await call(routeInventory, "GET", path, ["viewFinance"]);
    assertEquals(denied?.status, 403, `${path} should 403 without viewInventory`);
    const allowed = await call(routeInventory, "GET", path, ["viewInventory"]);
    assertEquals(allowed?.status, 503, `${path} should reach DB (503) for a holder`);
  }
});

Deno.test("INV: unauthenticated stock issue is 401", async () => {
  const req = new Request("https://x/inventory/stock/issue", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ issueNumber: "ISS-1", lines: [{ sku: "PEN-1", quantity: 1 }] }),
  });
  const res = await routeInventory(req, config, "POST", "/inventory/stock/issue");
  assertEquals(res?.status, 401);
});
