// QW4 · QA-B-028, QA-B-039 — Analytics ROUTE contract + RBAC (DB-free).
//
// Proven without a live Postgres (QW1 pattern, see
// finance_collections_route_contract_test.ts): all 7 analytics GET routes match
// routeAnalytics (an unregistered /analytics path 404s), every route is gated on
// `viewAnalytics` (403 without it, reaches the unconfigured DB → 503 with it).
// The end-to-end aggregate values + per-school RLS isolation are the live-cert
// remainder (analytics_handlers compute through withTenantContext → org RLS).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeAnalytics } from "./analytics_router.ts";

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

async function get(path: string, perms: string[]): Promise<Response> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method: "GET", headers: { authorization: `Bearer ${token}` },
  });
  const res = await routeAnalytics(req, config, "GET", path);
  if (res === null) throw new Error(`routeAnalytics returned null for GET ${path}`);
  return res;
}

const ROUTES = [
  "/analytics/dashboard", "/analytics/trends", "/analytics/risks", "/analytics/health",
  "/analytics/recommendations", "/analytics/principal-summary", "/analytics/weekly-briefing",
];

Deno.test("QA-B-028: all 7 analytics routes match the router and authorize (503 DB-free)", async () => {
  for (const path of ROUTES) {
    const res = await get(path, ["viewAnalytics"]);
    assertEquals(res.status, 503, `${path} should match + authorize, got ${res.status}`);
  }
});

Deno.test("QA-B-028: an unregistered analytics path returns 404 NOT_FOUND", async () => {
  const res = await get("/analytics/nope", ["viewAnalytics"]);
  assertEquals(res.status, 404);
  const env = await res.json();
  assertEquals(env.error.code, "NOT_FOUND");
});

Deno.test("QA-B-028: a non-/analytics path returns null (no match)", async () => {
  const token = await signAccessToken(SECRET, claims(["viewAnalytics"]), 900);
  const req = new Request("https://x/director/dashboard", {
    method: "GET", headers: { authorization: `Bearer ${token}` },
  });
  assertEquals(await routeAnalytics(req, config, "GET", "/director/dashboard"), null);
});

Deno.test("QA-B-039: every analytics route is denied without viewAnalytics (403 FORBIDDEN)", async () => {
  // A token with an unrelated permission (and not viewSchoolHealth) is denied
  // all 7 routes. health/principal-summary accept viewSchoolHealth OR viewAnalytics,
  // so withholding both proves the gate fires on every route.
  for (const path of ROUTES) {
    const res = await get(path, ["viewInventory"]);
    assertEquals(res.status, 403, `${path} should 403 without viewAnalytics, got ${res.status}`);
    const env = await res.json();
    assertEquals(env.error.code, "FORBIDDEN");
  }
});

Deno.test("QA-B-039: viewAnalytics alone authorizes every analytics route (reaches DB → 503)", async () => {
  for (const path of ROUTES) {
    const res = await get(path, ["viewAnalytics"]);
    assertEquals(res.status, 503, `${path} should pass with viewAnalytics, got ${res.status}`);
  }
});

Deno.test("QA-B-039: school-health routes accept EITHER viewSchoolHealth or viewAnalytics (OR, not AND)", async () => {
  // Regression for the analytics RBAC fix: requireSchoolHealthView must allow a
  // principal holding only viewAnalytics (or only viewSchoolHealth). Previously
  // the `??` chain ANDed the two, denying viewAnalytics-only principals (403).
  for (const path of ["/analytics/health", "/analytics/principal-summary"]) {
    assertEquals((await get(path, ["viewAnalytics"])).status, 503, `${path} viewAnalytics-only`);
    assertEquals((await get(path, ["viewSchoolHealth"])).status, 503, `${path} viewSchoolHealth-only`);
    // Neither permission → still denied.
    assertEquals((await get(path, ["viewInventory"])).status, 403, `${path} neither perm`);
  }
});

Deno.test("QA-B-039: an unauthenticated caller is rejected (401) on an analytics route", async () => {
  const req = new Request("https://x/analytics/dashboard", { method: "GET" });
  const res = await routeAnalytics(req, config, "GET", "/analytics/dashboard");
  assertEquals(res?.status, 401);
});
