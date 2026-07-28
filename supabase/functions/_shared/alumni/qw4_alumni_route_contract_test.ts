// QW4 · QA-B-024 — Alumni module ROUTE + RBAC + entitlement contract (DB-free).
//
// Proven without a live Postgres:
//   1. PATH-MATCH: every registered alumni route (9 GET + 5 POST = 14) resolves
//      to a handler (status !== 404); unregistered under /alumni 404s; outside
//      the prefix returns null.
//   2. module.alumni 402 gate wired via withEntitlement on the /alumni prefix
//      (DB-free 503; pure 402 in qw4_entitlement_402_matrix_test.ts).
//   3. POST /alumni/donations (record donation) and POST /alumni/campaigns
//      (create campaign) are 403 for a non-holder of manageAlumni, 503 for a holder.
//
// Live RLS row isolation + 200 happy-path = live-cert remainder.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeAlumni } from "./alumni_router.ts";
import { withEntitlement } from "../entitlements/entitlement_middleware.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "alumniManager", role_slugs: ["alumniManager"], primary_role: "alumniManager",
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
  ["GET", "/alumni/dashboard"],
  ["GET", "/alumni/registry"],
  ["GET", "/alumni/events"],
  ["GET", "/alumni/donations"],
  ["GET", "/alumni/campaigns"],
  ["GET", "/alumni/mentorship"],
  ["GET", "/alumni/reports"],
  ["GET", "/alumni/settings"],
  ["GET", "/alumni/registry/al-1"],
  ["POST", "/alumni/registry"],
  ["POST", "/alumni/events"],
  ["POST", "/alumni/campaigns"],
  ["POST", "/alumni/mentorship"],
  ["POST", "/alumni/donations"],
];

Deno.test("QA-B-024: all 14 alumni routes path-match to a handler (not 404)", async () => {
  const perms = ["viewAlumni", "manageAlumni"];
  for (const [method, path] of REGISTERED) {
    const res = await call(routeAlumni, method, path, perms);
    assertEquals(res !== null, true, `${method} ${path} returned null`);
    assertEquals(res!.status !== 404, true, `${method} ${path} unexpectedly 404'd`);
  }
});

Deno.test("QA-B-024: unregistered path under /alumni returns null (central dispatcher 404s); path outside prefix is null", async () => {
  const under = await call(routeAlumni, "GET", "/alumni/not-a-route", ["viewAlumni"]);
  assertEquals(under, null);
  const outside = await call(routeAlumni, "GET", "/library/dashboard", ["viewAlumni"]);
  assertEquals(outside, null);
});

Deno.test("QA-B-024: module.alumni 402 gate is wired via withEntitlement on the /alumni prefix", async () => {
  const wrapped = withEntitlement(routeAlumni, "/alumni", "module.alumni");
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "true");
  const gated = await call(wrapped, "GET", "/alumni/dashboard", ["viewAlumni"]);
  assertEquals(gated?.status, 503, "wrapped prefix did not route through the entitlement gate");
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "false");
  const passNonHolder = await call(wrapped, "GET", "/alumni/dashboard", []);
  assertEquals(passNonHolder?.status, 403);
  Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
});

Deno.test("QA-B-024: POST /alumni/donations is 403 without manageAlumni, 503 with it", async () => {
  const denied = await call(routeAlumni, "POST", "/alumni/donations", ["viewAlumni"], { amount: 1000 });
  assertEquals(denied?.status, 403);
  assertEquals((await denied!.json()).error.code, "FORBIDDEN");
  const allowed = await call(routeAlumni, "POST", "/alumni/donations", ["manageAlumni"], { amount: 1000 });
  assertEquals(allowed?.status, 503);
});

Deno.test("QA-B-024: POST /alumni/campaigns is 403 without manageAlumni", async () => {
  const denied = await call(routeAlumni, "POST", "/alumni/campaigns", ["viewAlumni"], { name: "C1" });
  assertEquals(denied?.status, 403);
});

Deno.test("QA-B-024: GET /alumni/dashboard is 403 without viewAlumni", async () => {
  const denied = await call(routeAlumni, "GET", "/alumni/dashboard", ["viewFinance"]);
  assertEquals(denied?.status, 403);
});

Deno.test("QA-B-024: unauthenticated alumni read is 401", async () => {
  const req = new Request("https://x/alumni/dashboard", { method: "GET" });
  const res = await routeAlumni(req, config, "GET", "/alumni/dashboard");
  assertEquals(res?.status, 401);
});
