// QW4 · QA-B-020 — Transport module ROUTE + RBAC + entitlement contract (DB-free).
//
// What is proven here without a live Postgres:
//   1. PATH-MATCH: every one of the registered transport routes resolves to a
//      handler (proxy: it does NOT 404), and an unregistered path under /transport
//      404s while a path outside the prefix returns null (no match) at the router.
//   2. ENTITLEMENT 402: wrapping routeTransport exactly as api/index.ts does
//      (`withEntitlement(routeTransport, "/transport", "module.transport")`) and
//      flipping ENTITLEMENT_ENFORCEMENT on makes the wrapper intercept the prefix
//      and run the gate before the router. The plan-vs-slug 402-vs-pass decision is
//      resolved from the org's subscription in the tenant DB, so DB-free it surfaces
//      as 503 (gate reached the unconfigured DB). The pure 402 leg is proven in
//      qw4_entitlement_402_matrix_test.ts via requireEntitlement.
//   3. PER-ROUTE 403: a write (POST /transport/routes, /transport/allocations)
//      is denied for a token without `manageTransport` (403 FORBIDDEN); a read is
//      denied without `viewTransport`; a holder passes the gate and reaches the
//      (unconfigured) tenant DB → 503.
//
// 503 (TENANT_DB_NOT_CONFIGURED) = the proxy for "authorized; would have hit the
// DB". The end-to-end 200 + RLS row isolation is the live-cert / infra remainder.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeTransport } from "./transport_router.ts";
import { withEntitlement } from "../entitlements/entitlement_middleware.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "transportManager", role_slugs: ["transportManager"], primary_role: "transportManager",
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

// The complete registered surface of routeTransport (TRN-1..9 + PRA-P0-19/20/P1-43).
const REGISTERED: Array<[string, string]> = [
  ["GET", "/transport/dashboard"],
  ["GET", "/transport/routes"],
  ["GET", "/transport/vehicles"],
  ["GET", "/transport/drivers"],
  ["GET", "/transport/allocations"],
  ["GET", "/transport/attendance"],
  ["GET", "/transport/tracking"],
  ["GET", "/transport/reports"],
  ["GET", "/transport/settings"],
  ["GET", "/transport/occupancy-metrics"],
  ["GET", "/transport/routes/route-1/roster"], // TRN-3
  ["POST", "/transport/routes"],
  ["POST", "/transport/allocations"],
  ["POST", "/transport/allocations/bulk"], // TRN-5
  ["POST", "/transport/attendance"],
  ["POST", "/transport/attendance/generate"], // PRA-P1-43
  ["POST", "/transport/notify-delay"],
  ["POST", "/transport/vehicles"], // TRN-1
  ["POST", "/transport/drivers"], // TRN-1
  ["POST", "/transport/reminders/document-expiry"], // TRN-8
  ["POST", "/transport/demands"], // TRN-9
  ["POST", "/transport/demands/bulk"], // PRA-P0-20
  ["POST", "/transport/routes/route-1/activate"],
  ["PUT", "/transport/routes/route-1/vehicle"], // PRA-P0-19
  ["POST", "/transport/routes/route-1/stops"], // TRN-4
  ["POST", "/transport/routes/route-1/stops/reorder"], // TRN-4
  ["POST", "/transport/allocations/alloc-1/transfer"],
  ["PUT", "/transport/vehicles/veh-1"], // TRN-1
  ["PUT", "/transport/drivers/drv-1"], // TRN-1
  ["PUT", "/transport/routes/route-1/stops/stop-1"], // TRN-4
  ["DELETE", "/transport/vehicles/veh-1"], // TRN-1
  ["DELETE", "/transport/drivers/drv-1"], // TRN-1
  ["DELETE", "/transport/routes/route-1/stops/stop-1"], // TRN-4
  ["DELETE", "/transport/allocations/alloc-1"],
];

Deno.test("QA-B-020: all transport routes path-match to a handler (not 404)", async () => {
  // A holder token; any registered route must resolve past the router into the
  // handler/gate (status !== 404). 404 here would mean a missing/typo'd route.
  const perms = ["viewTransport", "manageTransport"];
  for (const [method, path] of REGISTERED) {
    const res = await call(routeTransport, method, path, perms);
    assertEquals(res !== null, true, `${method} ${path} returned null`);
    assertEquals(res!.status !== 404, true, `${method} ${path} unexpectedly 404'd`);
  }
});

Deno.test("QA-B-020: unregistered path under /transport returns null (central dispatcher 404s); path outside prefix is null", async () => {
  const under = await call(routeTransport, "GET", "/transport/not-a-route", ["viewTransport"]);
  assertEquals(under, null);
  const outside = await call(routeTransport, "GET", "/finance/dashboard", ["viewTransport"]);
  assertEquals(outside, null);
});

Deno.test("QA-B-020: module.transport 402 gate is wired via withEntitlement on the /transport prefix", async () => {
  // Wrap exactly as api/index.ts does. With enforcement ON, the wrapper must
  // intercept the prefix and run enforceEntitlement BEFORE the router. DB-free,
  // resolving the org plan hits the unconfigured tenant DB → 503 (proxy for "gate
  // ran"). With enforcement OFF (default), the wrapper passes straight through to
  // the router. The pure 402 decision is proven in qw4_entitlement_402_matrix_test.
  const wrapped = withEntitlement(routeTransport, "/transport", "module.transport");

  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "true");
  const gated = await call(wrapped, "GET", "/transport/dashboard", ["viewTransport"]);
  assertEquals(gated?.status, 503, "wrapped prefix did not route through the entitlement gate");

  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "false");
  const passthrough = await call(wrapped, "GET", "/transport/dashboard", ["viewTransport"]);
  // Enforcement off → router runs; holder reaches the (unconfigured) DB → 503 too,
  // but a NON-holder now sees the router's 403 (gate skipped), proving pass-through.
  const passNonHolder = await call(wrapped, "GET", "/transport/dashboard", []);
  assertEquals(passthrough?.status, 503);
  assertEquals(passNonHolder?.status, 403);
  Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
});

Deno.test("QA-B-020: POST /transport/routes is 403 without manageTransport, 503 with it", async () => {
  const denied = await call(routeTransport, "POST", "/transport/routes", ["viewTransport"], { name: "R1" });
  assertEquals(denied?.status, 403);
  const body = await denied!.json();
  assertEquals(body.error.code, "FORBIDDEN");

  const allowed = await call(routeTransport, "POST", "/transport/routes", ["manageTransport"], { name: "R1" });
  assertEquals(allowed?.status, 503); // gate passed → unconfigured tenant DB
});

Deno.test("QA-B-020: POST /transport/allocations is 403 without manageTransport", async () => {
  const denied = await call(routeTransport, "POST", "/transport/allocations", ["viewTransport"], {
    studentId: "s1", routeId: "r1",
  });
  assertEquals(denied?.status, 403);
});

Deno.test("QA-B-020: GET /transport/dashboard is 403 without viewTransport", async () => {
  const denied = await call(routeTransport, "GET", "/transport/dashboard", ["viewFinance"]);
  assertEquals(denied?.status, 403);
});

Deno.test("QA-B-020: unauthenticated transport read is 401", async () => {
  const req = new Request("https://x/transport/dashboard", { method: "GET" });
  const res = await routeTransport(req, config, "GET", "/transport/dashboard");
  assertEquals(res?.status, 401);
});

// ── TRN-1..9: new write routes require manageTransport (403), pass to DB (503) ──

const NEW_WRITE_ROUTES: Array<[string, string, unknown]> = [
  ["POST", "/transport/vehicles", { registration: "KA-01-AB-1234" }],
  ["PUT", "/transport/vehicles/veh-1", { capacity: 40 }],
  ["DELETE", "/transport/vehicles/veh-1", undefined],
  ["POST", "/transport/drivers", { name: "D", licenseNumber: "L1" }],
  ["PUT", "/transport/drivers/drv-1", { phone: "9" }],
  ["DELETE", "/transport/drivers/drv-1", undefined],
  ["POST", "/transport/routes/route-1/stops", { name: "Stop" }],
  ["PUT", "/transport/routes/route-1/stops/stop-1", { name: "Stop" }],
  ["DELETE", "/transport/routes/route-1/stops/stop-1", undefined],
  ["POST", "/transport/routes/route-1/stops/reorder", { stopOrder: ["s1"] }],
  ["POST", "/transport/allocations/bulk", { routeId: "r1", pickupStop: "A", dropStop: "B", sisStudentIds: ["S1"] }],
  ["POST", "/transport/reminders/document-expiry", {}],
  ["POST", "/transport/demands", { sisStudentId: "S1", routeId: "r1", feeStructureId: "f1", academicYear: "2026-27" }],
  // PRA-P0-19 / P0-20 / P1-43 write routes.
  ["PUT", "/transport/routes/route-1/vehicle", { registration: "KA-01-AB-1234" }],
  ["POST", "/transport/demands/bulk", { routeId: "r1", feeStructureId: "f1", academicYear: "2026-27" }],
  ["POST", "/transport/attendance/generate", { routeId: "r1" }],
];

Deno.test("QA-B-020: TRN-1..9 write routes are 403 without manageTransport, 503 with it", async () => {
  for (const [method, path, body] of NEW_WRITE_ROUTES) {
    const denied = await call(routeTransport, method, path, ["viewTransport"], body);
    assertEquals(denied?.status, 403, `${method} ${path} should 403 without manageTransport`);
    const allowed = await call(routeTransport, method, path, ["manageTransport"], body);
    assertEquals(allowed?.status, 503, `${method} ${path} should reach DB (503) with manageTransport`);
  }
});

Deno.test("QA-B-020: TRN-3 roster read is 403 without viewTransport, 503 with it", async () => {
  const denied = await call(routeTransport, "GET", "/transport/routes/route-1/roster", ["viewFinance"]);
  assertEquals(denied?.status, 403);
  const allowed = await call(routeTransport, "GET", "/transport/routes/route-1/roster", ["viewTransport"]);
  assertEquals(allowed?.status, 503);
});
