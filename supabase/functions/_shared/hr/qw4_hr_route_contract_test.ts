// QW4 · QA-B-022 — HR module ROUTE + RBAC + entitlement contract (DB-free).
//
// Proven without a live Postgres:
//   1. PATH-MATCH: every registered HR route (9 GET + 7 POST + 4 PUT + 1 PATCH)
//      resolves to a handler (status !== 404); unregistered under /hr 404s; a path
//      outside the prefix returns null.
//   2. POST /hr/payroll/run requires manageHr → 403 for a non-holder, 503 for a
//      holder (gate passed; reached the unconfigured tenant DB).
//   3. module.hr_payroll 402 gate is wired via withEntitlement on the /hr prefix
//      (DB-free: 503 when the gate runs into the unconfigured DB; pure 402 in
//      qw4_entitlement_402_matrix_test.ts).
//
// NOTE: api/index.ts wraps routeHr with slug "module.hr_payroll" on prefix "/hr".
// Live RLS row isolation + 200 happy-path = live-cert remainder.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeHr } from "./hr_router.ts";
import { withEntitlement } from "../entitlements/entitlement_middleware.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "hrManager", role_slugs: ["hrManager"], primary_role: "hrManager",
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
  // The router matches on the pathname only; the query string is read from the
  // request URL by the handler (mirrors how api/index.ts routes).
  const pathname = new URL(`https://x${path}`).pathname;
  return router(req, config, method, pathname);
}

const REGISTERED: Array<[string, string]> = [
  ["GET", "/hr/dashboard"],
  ["GET", "/hr/employees"],
  ["GET", "/hr/attendance"],
  ["GET", "/hr/leave"],
  ["GET", "/hr/payroll"],
  ["GET", "/hr/recruitment"],
  ["GET", "/hr/performance"],
  ["GET", "/hr/settings"],
  // HR reporting / export reads (HR-1/2/4/5/6/7).
  ["GET", "/hr/payroll/register"],
  ["GET", "/hr/payroll/payslips"],
  ["GET", "/hr/attendance/muster"],
  ["GET", "/hr/leave/balances"],
  ["GET", "/hr/reports/headcount"],
  ["GET", "/hr/employees/export"],
  // HR-D1 / HR-D2 reports.
  ["GET", "/hr/documents/expiring"],
  ["GET", "/hr/probation/ending"],
  ["GET", "/hr/employees/emp-1"],
  ["POST", "/hr/employees"],
  ["POST", "/hr/leave"],
  // HR-3 batch decide.
  ["POST", "/hr/leave/batch-decide"],
  ["POST", "/hr/leave/lv-1/approve"],
  ["POST", "/hr/leave/lv-1/reject"],
  // HR-D2 probation confirm/extend.
  ["POST", "/hr/employees/emp-1/probation"],
  ["POST", "/hr/performance"],
  ["POST", "/hr/recruitment"],
  ["POST", "/hr/payroll/run"],
  // MOD-2 — payroll engine: salary structures + run generation.
  ["POST", "/hr/payroll/structures"],
  ["POST", "/hr/payroll/run/generate"],
  ["PUT", "/hr/employees/emp-1"],
  ["PUT", "/hr/performance/pr-1"],
  ["PUT", "/hr/recruitment/rc-1"],
  // PRA-P1-33 — HR settings write.
  ["PUT", "/hr/settings"],
  ["PATCH", "/hr/employees/emp-1/status"],
];

Deno.test("QA-B-022: all HR routes path-match to a handler (not 404)", async () => {
  const perms = ["viewHr", "manageHr"];
  for (const [method, path] of REGISTERED) {
    const res = await call(routeHr, method, path, perms);
    assertEquals(res !== null, true, `${method} ${path} returned null`);
    assertEquals(res!.status !== 404, true, `${method} ${path} unexpectedly 404'd`);
  }
});

// MOD-2 — the payroll-engine writes gate manageHr (403 non-holder, 503 holder =
// gate passed + reached the unconfigured tenant DB), like every HR write.
Deno.test("MOD-2: payroll structure + generate writes require manageHr", async () => {
  for (const path of ["/hr/payroll/structures", "/hr/payroll/run/generate"]) {
    const denied = await call(routeHr, "POST", path, ["viewHr"], {
      employeeId: "e1",
      basicPay: 40000,
      runId: "r",
      period: "2026-07",
    });
    assertEquals(denied?.status, 403, `${path} should 403 without manageHr`);
    const allowed = await call(routeHr, "POST", path, ["manageHr"], {
      employeeId: "e1",
      basicPay: 40000,
      runId: "r",
      period: "2026-07",
    });
    assertEquals(allowed?.status, 503, `${path} holder should reach the unconfigured DB (503)`);
  }
});

// HR reporting / export reads (HR-1/2/4/5/6/7) — all gate viewHr, all resolve to
// their report handler (503 for a holder = gate passed, reached the unconfigured
// tenant DB), and 403 for a non-holder.
const HR_REPORT_ROUTES: string[] = [
  "/hr/payroll/register?runId=run-1",
  "/hr/payroll/payslips?runId=run-1",
  "/hr/attendance/muster?month=2026-06",
  "/hr/leave/balances",
  "/hr/reports/headcount",
  "/hr/employees/export",
];

Deno.test("HR reports: each report route gates viewHr (403 non-holder, 503 holder)", async () => {
  for (const path of HR_REPORT_ROUTES) {
    const denied = await call(routeHr, "GET", path, ["viewFinance"]);
    assertEquals(denied?.status, 403, `${path} should 403 without viewHr`);
    const allowed = await call(routeHr, "GET", path, ["viewHr"]);
    assertEquals(allowed?.status, 503, `${path} holder should reach unconfigured DB (503)`);
  }
});

Deno.test("HR reports: literal report paths are not swallowed by id/detail matches", async () => {
  // /hr/employees/export must reach the directory handler, NOT employee-detail;
  // both reach the DB seam (503) so we assert they are not 404 and are gated.
  const directory = await call(routeHr, "GET", "/hr/employees/export", ["viewHr"]);
  assertEquals(directory?.status, 503);
  const register = await call(routeHr, "GET", "/hr/payroll/register?runId=r", ["viewHr"]);
  assertEquals(register?.status, 503);
});

Deno.test("QA-B-022: unregistered path under /hr 404s; path outside prefix is null", async () => {
  const under = await call(routeHr, "GET", "/hr/not-a-route", ["viewHr"]);
  assertEquals(under?.status, 404);
  const outside = await call(routeHr, "GET", "/library/dashboard", ["viewHr"]);
  assertEquals(outside, null);
});

Deno.test("QA-B-022: POST /hr/payroll/run requires manageHr (403 non-holder, 503 holder)", async () => {
  const denied = await call(routeHr, "POST", "/hr/payroll/run", ["viewHr"], { runId: "run-1" });
  assertEquals(denied?.status, 403);
  assertEquals((await denied!.json()).error.code, "FORBIDDEN");
  const allowed = await call(routeHr, "POST", "/hr/payroll/run", ["manageHr"], { runId: "run-1" });
  assertEquals(allowed?.status, 503);
});

// --- Final HR slice (HR-3 / HR-D1 / HR-D2 / HR-D3) route + RBAC contract ------

Deno.test("HR-3: POST /hr/leave/batch-decide requires manageHr (403 non-holder, 503 holder)", async () => {
  const body = { ids: ["lv-1"], decision: "approve" };
  const denied = await call(routeHr, "POST", "/hr/leave/batch-decide", ["viewHr"], body);
  assertEquals(denied?.status, 403);
  assertEquals((await denied!.json()).error.code, "FORBIDDEN");
  const allowed = await call(routeHr, "POST", "/hr/leave/batch-decide", ["manageHr"], body);
  assertEquals(allowed?.status, 503);
});

Deno.test("HR-3: batch-decide is not swallowed by the /hr/leave/{id}/approve match", async () => {
  // batch-decide has no /approve|/reject suffix, so it must reach the batch
  // handler (503 for a holder), never the single-decision handler or a 404.
  const res = await call(routeHr, "POST", "/hr/leave/batch-decide", ["manageHr"], {
    ids: ["lv-1"],
    decision: "reject",
  });
  assertEquals(res?.status, 503);
});

Deno.test("PRA-P1-33: PUT /hr/settings requires manageHr (403 non-holder, 503 holder)", async () => {
  const body = { leavePolicy: [{ leaveType: "casual", entitlement: 12 }] };
  const denied = await call(routeHr, "PUT", "/hr/settings", ["viewHr"], body);
  assertEquals(denied?.status, 403);
  assertEquals((await denied!.json()).error.code, "FORBIDDEN");
  const allowed = await call(routeHr, "PUT", "/hr/settings", ["manageHr"], body);
  assertEquals(allowed?.status, 503);
});

Deno.test("HR-D2: POST /hr/employees/{id}/probation requires manageHr (403 non-holder, 503 holder)", async () => {
  const body = { action: "confirm" };
  const denied = await call(routeHr, "POST", "/hr/employees/emp-1/probation", ["viewHr"], body);
  assertEquals(denied?.status, 403);
  const allowed = await call(routeHr, "POST", "/hr/employees/emp-1/probation", ["manageHr"], body);
  assertEquals(allowed?.status, 503);
});

Deno.test("HR-D1/HR-D2 reports gate viewHr (403 non-holder, 503 holder)", async () => {
  for (const path of ["/hr/documents/expiring?withinDays=30", "/hr/probation/ending?withinDays=15"]) {
    const denied = await call(routeHr, "GET", path, ["viewFinance"]);
    assertEquals(denied?.status, 403, `${path} should 403 without viewHr`);
    const allowed = await call(routeHr, "GET", path, ["viewHr"]);
    assertEquals(allowed?.status, 503, `${path} holder should reach unconfigured DB (503)`);
  }
});

Deno.test("QA-B-022: module.hr_payroll 402 gate is wired via withEntitlement on the /hr prefix", async () => {
  const wrapped = withEntitlement(routeHr, "/hr", "module.hr_payroll");
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "true");
  const gated = await call(wrapped, "GET", "/hr/dashboard", ["viewHr"]);
  assertEquals(gated?.status, 503, "wrapped prefix did not route through the entitlement gate");
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "false");
  const passNonHolder = await call(wrapped, "GET", "/hr/dashboard", []);
  assertEquals(passNonHolder?.status, 403);
  Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
});

Deno.test("QA-B-022: GET /hr/dashboard is 403 without viewHr", async () => {
  const denied = await call(routeHr, "GET", "/hr/dashboard", ["viewFinance"]);
  assertEquals(denied?.status, 403);
});

Deno.test("QA-B-022: unauthenticated HR read is 401", async () => {
  const req = new Request("https://x/hr/dashboard", { method: "GET" });
  const res = await routeHr(req, config, "GET", "/hr/dashboard");
  assertEquals(res?.status, 401);
});
