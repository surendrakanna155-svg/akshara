// ICA-F6 — inventory_finance ROUTE + RBAC + entitlement contract (DB-free).
//
// Before ICA-F6 the inventory_finance HTTP surface was split across two parent
// routers — the reconciliation reads were inlined in routeFinance and the
// procurement/stock surface was delegated from routeInventory — with no direct
// entry in api/app.ts. It is now owned by ONE router (routeInventoryFinance),
// registered once, owning two disjoint prefixes:
//   /inventory/{vendors/catalog, procurement/*, stock/*}   (procurement + stock)
//   /finance/inventory-reconciliation/*                    (reconciliation reads)
//
// Proven here (same harness as the finance/inventory route-contract tests —
// signs a real JWT, dispatches through the real router):
//   • every registered route resolves to its handler and enforces its slug:
//       procurement/stock reads → viewInventory, writes → manageInventory,
//       reconciliation reads → viewFinance. Holder → gate-passed (503 DB-free, or
//       422 when a write's body validation fires after the gate); non-holder → 403.
//   • the module.inventory plan entitlement is SELF-ENFORCED for the /inventory/*
//     surface only (org-builder pattern) — identical to the gate those routes
//     inherited from withEntitlement(routeInventory, "/inventory", "module.inventory");
//     /finance/inventory-reconciliation/* carries NO plan entitlement, exactly as
//     it did under routeFinance.
//   • a path the router does not own returns null, so the sibling routers
//     (routeFinance, routeInventory) still own the rest of their prefixes.
//
// Live RLS row isolation + 200 happy-path = live-cert remainder.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeInventoryFinance } from "./inventory_finance_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;
const ID = "11111111-1111-1111-1111-111111111111";

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "inventoryManager", role_slugs: ["inventoryManager"], primary_role: "inventoryManager",
    permissions: perms, permissions_version: 1, scope: "school", school_group_id: null,
    student_id: null, child_ids: [], session_id: "s1",
  };
}

async function call(
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
  return routeInventoryFinance(req, config, method, path);
}

interface RouteCase {
  method: string;
  path: string;
  holder: string[]; // grants access → gate-passed (503/422)
  other: string[]; // lacks the required slug → 403
  body?: unknown; // valid body so a write reaches the DB (503) rather than 400/422
}

// The full registered inventory_finance route map (28 routes), each with its real
// slug (read from the handlers' requirePermission calls, never guessed).
const routes: RouteCase[] = [
  // ── reconciliation reads (gate: viewFinance) ──
  { method: "GET", path: "/finance/inventory-reconciliation/dashboard", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: "/finance/inventory-reconciliation/timeline", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: "/finance/inventory-reconciliation/goods-receipts", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: "/finance/inventory-reconciliation/postings", holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: `/finance/inventory-reconciliation/goods-receipts/${ID}`, holder: ["viewFinance"], other: ["viewInventory"] },
  { method: "GET", path: `/finance/inventory-reconciliation/vendors/${ID}/transactions`, holder: ["viewFinance"], other: ["viewInventory"] },
  // ── procurement + vendor catalog reads (gate: viewInventory) ──
  { method: "GET", path: "/inventory/vendors/catalog", holder: ["viewInventory"], other: ["viewFinance"] },
  { method: "GET", path: "/inventory/procurement/orders", holder: ["viewInventory"], other: ["viewFinance"] },
  { method: "GET", path: "/inventory/procurement/grns", holder: ["viewInventory"], other: ["viewFinance"] },
  { method: "GET", path: `/inventory/procurement/orders/${ID}`, holder: ["viewInventory"], other: ["viewFinance"] },
  // ── procurement + vendor catalog writes (gate: manageInventory) ──
  { method: "POST", path: "/inventory/vendors/catalog", holder: ["manageInventory"], other: ["viewInventory"], body: { vendorCode: "VC1", displayName: "Acme" } },
  { method: "POST", path: "/inventory/procurement/orders", holder: ["manageInventory"], other: ["viewInventory"], body: { vendorId: "v1", poNumber: "PO-1", lines: [{ sku: "x", qty: 1 }] } },
  { method: "POST", path: `/inventory/procurement/orders/${ID}/approve`, holder: ["manageInventory"], other: ["viewInventory"], body: {} },
  { method: "POST", path: `/inventory/procurement/orders/${ID}/receive`, holder: ["manageInventory"], other: ["viewInventory"], body: {} },
  // ── stock reads (gate: viewInventory) ──
  { method: "GET", path: "/inventory/stock/valuation", holder: ["viewInventory"], other: ["viewFinance"] },
  { method: "GET", path: "/inventory/stock/approvals", holder: ["viewInventory"], other: ["viewFinance"] },
  { method: "GET", path: "/inventory/stock", holder: ["viewInventory"], other: ["viewFinance"] },
  { method: "GET", path: "/inventory/stock/adjustments", holder: ["viewInventory"], other: ["viewFinance"] },
  { method: "GET", path: "/inventory/stock/items", holder: ["viewInventory"], other: ["viewFinance"] },
  { method: "GET", path: "/inventory/stock/register", holder: ["viewInventory"], other: ["viewFinance"] },
  { method: "GET", path: "/inventory/stock/low-stock", holder: ["viewInventory"], other: ["viewFinance"] },
  // ── stock writes (gate: manageInventory) ──
  { method: "POST", path: "/inventory/stock/issue", holder: ["manageInventory"], other: ["viewInventory"], body: { issueNumber: "ISS-1", lines: [{ sku: "PEN-1", quantity: 2 }] } },
  { method: "POST", path: "/inventory/stock/adjust", holder: ["manageInventory"], other: ["viewInventory"], body: { sku: "PEN-1", quantity: 3, movementType: "adjust_in", reason: "restock" } },
  { method: "POST", path: `/inventory/stock/adjustments/${ID}/approve`, holder: ["manageInventory"], other: ["viewInventory"], body: {} },
  { method: "POST", path: `/inventory/stock/adjustments/${ID}/reject`, holder: ["manageInventory"], other: ["viewInventory"], body: { comment: "no" } },
  { method: "POST", path: "/inventory/stock/count", holder: ["manageInventory"], other: ["viewInventory"], body: { sessionNumber: "CNT-1", lines: [{ sku: "PEN-1", countedQty: 5 }] } },
  { method: "POST", path: "/inventory/stock/items", holder: ["manageInventory"], other: ["viewInventory"], body: { sku: "PEN-1", reorderLevel: 10 } },
  { method: "PUT", path: "/inventory/stock/items", holder: ["manageInventory"], other: ["viewInventory"], body: { sku: "PEN-1", reorderLevel: 10 } },
];

Deno.test("ICA-F6: every inventory_finance route resolves through routeInventoryFinance and enforces its slug", async () => {
  // Entitlement enforcement OFF (default) so the RBAC gate — not the plan gate —
  // is what we observe here; the self-enforcement is proven separately below.
  Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
  for (const r of routes) {
    // Holder of the route's slug → gate + school scope pass. The request then
    // reaches the unconfigured tenant DB (503) or trips post-gate body validation
    // (422). Both prove the permission gate let the caller through; 401/403/404
    // would mean the route/gate rejected it.
    const holderRes = await call(r.method, r.path, r.holder, r.body);
    const gatePassed = holderRes?.status === 503 || holderRes?.status === 422;
    assertEquals(
      gatePassed,
      true,
      `${r.method} ${r.path} with [${r.holder}] expected gate-passed (503 or 422) but got ${holderRes?.status}`,
    );
    // Caller lacking the slug → 403 FORBIDDEN.
    const otherRes = await call(r.method, r.path, r.other, r.body);
    assertEquals(
      otherRes?.status,
      403,
      `${r.method} ${r.path} with [${r.other}] expected 403 (missing slug) but got ${otherRes?.status}`,
    );
  }
});

Deno.test("ICA-F6: module.inventory self-enforces on /inventory/* only (reconciliation reads are un-gated)", async () => {
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "true");
  try {
    // /inventory/* — the plan gate runs BEFORE the handler RBAC, so even a token
    // that lacks viewInventory is routed through the (unconfigured) subscription DB
    // → 503, NOT the handler's 403. That 503 IS the module.inventory gate firing.
    const gated = await call("GET", "/inventory/stock/register", []);
    assertEquals(gated?.status, 503, "module.inventory gate did not fire for the /inventory/* surface");

    // /finance/inventory-reconciliation/* carries NO plan entitlement — the gate
    // must not fire, so a token lacking viewFinance is denied by the handler (403),
    // never routed through the subscription DB (which would be 503).
    const ungated = await call("GET", "/finance/inventory-reconciliation/dashboard", []);
    assertEquals(ungated?.status, 403, "reconciliation read was wrongly plan-gated by module.inventory");
  } finally {
    Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
  }
});

Deno.test("ICA-F6: a path the router does not own returns null (siblings still own their prefixes)", async () => {
  Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
  // A non-reconciliation finance path and an inventory base path belong to
  // routeFinance / routeInventory — routeInventoryFinance must pass (null).
  assertEquals(await call("GET", "/finance/dashboard", ["viewFinance"]), null);
  assertEquals(await call("GET", "/inventory/dashboard", ["viewInventory"]), null);
  // An owned prefix but unregistered sub-path also yields null (the sibling 404s it).
  assertEquals(await call("GET", "/inventory/stock/not-a-route", ["viewInventory"]), null);
  assertEquals(await call("POST", "/inventory/stock", ["manageInventory"], {}), null);
});

Deno.test("ICA-F6: an unauthenticated inventory_finance write is 401", async () => {
  Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
  const req = new Request("https://x/inventory/stock/issue", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ issueNumber: "ISS-1", lines: [{ sku: "PEN-1", quantity: 1 }] }),
  });
  const res = await routeInventoryFinance(req, config, "POST", "/inventory/stock/issue");
  assertEquals(res?.status, 401);
});
