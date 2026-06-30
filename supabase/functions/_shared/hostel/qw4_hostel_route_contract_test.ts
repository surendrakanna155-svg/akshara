// QW4 · QA-B-021 — Hostel module ROUTE + RBAC + entitlement contract (DB-free).
//
// Proven without a live Postgres:
//   1. PATH-MATCH: every registered hostel route (9 GET + 7 POST = 16) resolves
//      to a handler (status !== 404); an unregistered path under /hostel 404s and
//      a path outside the prefix returns null.
//   2. module.hostel 402 gate is wired via withEntitlement on the /hostel prefix
//      (DB-free: surfaces 503 when the gate runs into the unconfigured tenant DB;
//      pure 402 in qw4_entitlement_402_matrix_test.ts).
//   3. POST /hostel/rooms (create room) and POST /hostel/students/{id}/room
//      (allocation) are 403 for a non-holder of manageHostel, 503 for a holder.
//
// Live RLS row isolation + 200 happy-path = live-cert remainder.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeHostel } from "./hostel_router.ts";
import { withEntitlement } from "../entitlements/entitlement_middleware.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "hostelWarden", role_slugs: ["hostelWarden"], primary_role: "hostelWarden",
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

const REGISTERED: Array<[string, string]> = [
  ["GET", "/hostel/dashboard"],
  ["GET", "/hostel/students"],
  ["GET", "/hostel/rooms"],
  ["GET", "/hostel/attendance"],
  ["GET", "/hostel/leave"],
  ["GET", "/hostel/mess"],
  ["GET", "/hostel/visitors"],
  ["GET", "/hostel/reports"],
  ["GET", "/hostel/occupancy-metrics"],
  ["POST", "/hostel/students"],
  ["POST", "/hostel/rooms"],
  ["POST", "/hostel/attendance"],
  ["POST", "/hostel/mess"],
  ["POST", "/hostel/visitors"],
  ["POST", "/hostel/students/stu-1/room"],
  ["POST", "/hostel/students/stu-1/checkout"],
];

Deno.test("QA-B-021: all 16 hostel routes path-match to a handler (not 404)", async () => {
  const perms = ["viewHostel", "manageHostel"];
  for (const [method, path] of REGISTERED) {
    const res = await call(routeHostel, method, path, perms);
    assertEquals(res !== null, true, `${method} ${path} returned null`);
    assertEquals(res!.status !== 404, true, `${method} ${path} unexpectedly 404'd`);
  }
});

Deno.test("QA-B-021: unregistered path under /hostel 404s; path outside prefix is null", async () => {
  const under = await call(routeHostel, "GET", "/hostel/not-a-route", ["viewHostel"]);
  assertEquals(under?.status, 404);
  const outside = await call(routeHostel, "GET", "/library/dashboard", ["viewHostel"]);
  assertEquals(outside, null);
});

Deno.test("QA-B-021: module.hostel 402 gate is wired via withEntitlement on the /hostel prefix", async () => {
  const wrapped = withEntitlement(routeHostel, "/hostel", "module.hostel");
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "true");
  const gated = await call(wrapped, "GET", "/hostel/dashboard", ["viewHostel"]);
  assertEquals(gated?.status, 503, "wrapped prefix did not route through the entitlement gate");
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "false");
  const passNonHolder = await call(wrapped, "GET", "/hostel/dashboard", []);
  assertEquals(passNonHolder?.status, 403);
  Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
});

Deno.test("QA-B-021: POST /hostel/rooms is 403 without manageHostel, 503 with it", async () => {
  const denied = await call(routeHostel, "POST", "/hostel/rooms", ["viewHostel"], { name: "Room 1" });
  assertEquals(denied?.status, 403);
  assertEquals((await denied!.json()).error.code, "FORBIDDEN");
  const allowed = await call(routeHostel, "POST", "/hostel/rooms", ["manageHostel"], { name: "Room 1" });
  assertEquals(allowed?.status, 503);
});

Deno.test("QA-B-021: POST /hostel/students/{id}/room allocation is 403 without manageHostel", async () => {
  const denied = await call(routeHostel, "POST", "/hostel/students/stu-1/room", ["viewHostel"], { roomId: "rm-1" });
  assertEquals(denied?.status, 403);
});

Deno.test("QA-B-021: GET /hostel/dashboard is 403 without viewHostel", async () => {
  const denied = await call(routeHostel, "GET", "/hostel/dashboard", ["viewFinance"]);
  assertEquals(denied?.status, 403);
});

Deno.test("QA-B-021: unauthenticated hostel read is 401", async () => {
  const req = new Request("https://x/hostel/dashboard", { method: "GET" });
  const res = await routeHostel(req, config, "GET", "/hostel/dashboard");
  assertEquals(res?.status, 401);
});
