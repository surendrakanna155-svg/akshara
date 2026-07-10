// Adaptive AI — P3-AI-2 / W2.0a: Priority Feed ROUTE contract + gate (DB-free).
//
// Proven without a live Postgres (QW1/QW4 pattern): the route matches
// routeIntelligence, unauthenticated callers are rejected (401), an unsupported
// persona is rejected (422) BEFORE the DB, and a supported persona with school
// scope passes the gate and reaches the unconfigured tenant DB (503 = matched +
// authorized). Cross-tenant / RLS isolation of the loaded data is a live-DB
// concern (withTenantContext + org/school RLS) — recorded as the infra remainder.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../../config.ts";
import type { AccessTokenClaims } from "../../jwt.ts";
import { signAccessToken } from "../../jwt.ts";
import { routeIntelligence } from "../intelligence_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "principal", role_slugs: ["principal"], primary_role: "principal",
    permissions: perms, permissions_version: 1, scope: "school",
    school_group_id: null, student_id: null, child_ids: [], session_id: "s1", ...over,
  };
}

async function call(
  method: string,
  path: string,
  perms: string[],
  over: Partial<AccessTokenClaims> = {},
): Promise<Response> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  // The router matches on the pathname only; query params reach the handler via
  // req.url (mirrors app.ts, which passes routePath(req) sans query string).
  const pathname = path.split("?")[0]!;
  const res = await routeIntelligence(
    new Request(`https://x${path}`, {
      method,
      headers: { authorization: `Bearer ${token}` },
    }),
    config,
    method,
    pathname,
  );
  if (res === null) throw new Error(`routeIntelligence returned null for ${method} ${pathname}`);
  return res;
}

Deno.test("W2.0a: GET /intelligence/priorities matches the router (reaches DB → 503)", async () => {
  const res = await call("GET", "/intelligence/priorities?persona=principal", ["viewAnalytics"]);
  assertEquals(res.status, 503); // matched + authorized → unconfigured tenant DB
});

Deno.test("W2.0a: default persona (none supplied) is principal and matches", async () => {
  const res = await call("GET", "/intelligence/priorities", ["viewAnalytics"]);
  assertEquals(res.status, 503);
});

Deno.test("W2.0a: an unsupported persona is rejected 422 BEFORE the DB", async () => {
  // teacher/parent/student are per-user-scoped personas — not served by W2.0a.
  const res = await call("GET", "/intelligence/priorities?persona=teacher", ["viewAnalytics"]);
  assertEquals(res.status, 422);
  const env = await res.json();
  assertEquals(env.error.code, "VALIDATION_ERROR");
});

Deno.test("W2.0a: an unknown persona string is rejected 422", async () => {
  const res = await call("GET", "/intelligence/priorities?persona=wizard", ["viewAnalytics"]);
  assertEquals(res.status, 422);
});

Deno.test("W2.0a: a non-school scope is forbidden (403)", async () => {
  const res = await call(
    "GET",
    "/intelligence/priorities?persona=principal",
    ["viewAnalytics"],
    { scope: "organization", school_id: null },
  );
  assertEquals(res.status, 403);
});

Deno.test("W2.0a: an unauthenticated caller is rejected (401)", async () => {
  const res = await routeIntelligence(
    new Request("https://x/intelligence/priorities?persona=principal", { method: "GET" }),
    config,
    "GET",
    "/intelligence/priorities",
  );
  assertEquals(res?.status, 401);
});

Deno.test("W2.0a: a permission-light caller still matches the route (RBAC is per-source)", async () => {
  // No analytics/risk perms → the feed would be empty+degraded, but the route is
  // still authorized (school scope) and reaches the DB layer → 503 here.
  const res = await call("GET", "/intelligence/priorities?persona=principal", ["someOtherPerm"]);
  assertEquals(res.status, 503);
});
