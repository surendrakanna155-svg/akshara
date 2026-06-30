// QW4 · QA-B-023 — Library module ROUTE + RBAC + entitlement contract (DB-free).
//
// Proven without a live Postgres:
//   1. PATH-MATCH: every registered library route (8 GET + 6 POST = 14) resolves
//      to a handler (status !== 404); unregistered under /library 404s; outside
//      the prefix returns null.
//   2. module.library 402 gate wired via withEntitlement on the /library prefix
//      (DB-free 503; pure 402 in qw4_entitlement_402_matrix_test.ts).
//   3. POST /library/issues (issue book) and POST /library/returns (return book)
//      are 403 for a non-holder of manageLibrary, 503 for a holder.
//
// Live RLS row isolation + 200 happy-path = live-cert remainder.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeLibrary } from "./library_router.ts";
import { withEntitlement } from "../entitlements/entitlement_middleware.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "librarian", role_slugs: ["librarian"], primary_role: "librarian",
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
  ["GET", "/library/dashboard"],
  ["GET", "/library/catalog"],
  ["GET", "/library/issues"],
  ["GET", "/library/returns"],
  ["GET", "/library/members"],
  ["GET", "/library/fines"],
  ["GET", "/library/digital-resources"],
  ["GET", "/library/reports"],
  ["POST", "/library/catalog"],
  ["POST", "/library/issues"],
  ["POST", "/library/returns"],
  ["POST", "/library/members"],
  ["POST", "/library/digital-resources"],
  ["POST", "/library/fines/fine-1/waive"],
];

Deno.test("QA-B-023: all 14 library routes path-match to a handler (not 404)", async () => {
  const perms = ["viewLibrary", "manageLibrary"];
  for (const [method, path] of REGISTERED) {
    const res = await call(routeLibrary, method, path, perms);
    assertEquals(res !== null, true, `${method} ${path} returned null`);
    assertEquals(res!.status !== 404, true, `${method} ${path} unexpectedly 404'd`);
  }
});

Deno.test("QA-B-023: unregistered path under /library 404s; path outside prefix is null", async () => {
  const under = await call(routeLibrary, "GET", "/library/not-a-route", ["viewLibrary"]);
  assertEquals(under?.status, 404);
  const outside = await call(routeLibrary, "GET", "/hostel/dashboard", ["viewLibrary"]);
  assertEquals(outside, null);
});

Deno.test("QA-B-023: module.library 402 gate is wired via withEntitlement on the /library prefix", async () => {
  const wrapped = withEntitlement(routeLibrary, "/library", "module.library");
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "true");
  const gated = await call(wrapped, "GET", "/library/dashboard", ["viewLibrary"]);
  assertEquals(gated?.status, 503, "wrapped prefix did not route through the entitlement gate");
  Deno.env.set("ENTITLEMENT_ENFORCEMENT", "false");
  const passNonHolder = await call(wrapped, "GET", "/library/dashboard", []);
  assertEquals(passNonHolder?.status, 403);
  Deno.env.delete("ENTITLEMENT_ENFORCEMENT");
});

Deno.test("QA-B-023: POST /library/issues (issue book) is 403 without manageLibrary, 503 with it", async () => {
  const denied = await call(routeLibrary, "POST", "/library/issues", ["viewLibrary"], { bookId: "b1", memberId: "m1" });
  assertEquals(denied?.status, 403);
  assertEquals((await denied!.json()).error.code, "FORBIDDEN");
  const allowed = await call(routeLibrary, "POST", "/library/issues", ["manageLibrary"], { bookId: "b1", memberId: "m1" });
  assertEquals(allowed?.status, 503);
});

Deno.test("QA-B-023: POST /library/returns (return book) is 403 without manageLibrary", async () => {
  const denied = await call(routeLibrary, "POST", "/library/returns", ["viewLibrary"], { issueId: "i1" });
  assertEquals(denied?.status, 403);
});

Deno.test("QA-B-023: GET /library/dashboard is 403 without viewLibrary", async () => {
  const denied = await call(routeLibrary, "GET", "/library/dashboard", ["viewFinance"]);
  assertEquals(denied?.status, 403);
});

Deno.test("QA-B-023: unauthenticated library read is 401", async () => {
  const req = new Request("https://x/library/dashboard", { method: "GET" });
  const res = await routeLibrary(req, config, "GET", "/library/dashboard");
  assertEquals(res?.status, 401);
});
