// Adaptive AI — P3-AI-2 / W2.0b: Recommendation routes contract + gate (DB-free).
//
// GET /intelligence/recommendations mirrors the priority-feed gate; POST
// /intelligence/recommendations/feedback validates its body BEFORE the DB and is
// school-scope gated. Proven without a live Postgres (QW1/QW4 pattern): a valid,
// authorized request reaches the unconfigured tenant DB → 503.

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
  body?: unknown,
  over: Partial<AccessTokenClaims> = {},
): Promise<Response> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  const pathname = path.split("?")[0]!;
  const init: RequestInit = { method, headers: { authorization: `Bearer ${token}` } };
  if (body !== undefined) init.body = JSON.stringify(body);
  const res = await routeIntelligence(
    new Request(`https://x${path}`, init),
    config,
    method,
    pathname,
  );
  if (res === null) throw new Error(`routeIntelligence returned null for ${method} ${pathname}`);
  return res;
}

// ─── GET /intelligence/recommendations ───────────────────────────────────────

Deno.test("W2.0b: recommendations feed matches the router (reaches DB → 503)", async () => {
  const res = await call("GET", "/intelligence/recommendations?persona=principal", ["viewAnalytics"]);
  assertEquals(res.status, 503);
});

Deno.test("W2.0b: recommendations rejects an unknown persona (422)", async () => {
  const res = await call("GET", "/intelligence/recommendations?persona=wizard", ["viewAnalytics"]);
  assertEquals(res.status, 422);
});

Deno.test("W2 student: recommendations for persona=student (student scope) reach the DB (503)", async () => {
  const res = await call("GET", "/intelligence/recommendations?persona=student", ["viewSis"], undefined, {
    scope: "student", role: "student", role_slugs: ["student"], primary_role: "student",
    student_id: "stu-1",
  });
  assertEquals(res.status, 503);
});

Deno.test("W2 teacher: recommendations for persona=teacher reach the DB (503)", async () => {
  const res = await call("GET", "/intelligence/recommendations?persona=teacher", ["viewAdminHub"], undefined, {
    role: "teacher",
    role_slugs: ["teacher"],
    primary_role: "teacher",
  });
  assertEquals(res.status, 503);
});

Deno.test("W2 parent: recommendations for persona=parent (parent scope) reach the DB (503)", async () => {
  const res = await call("GET", "/intelligence/recommendations?persona=parent", ["viewSis"], undefined, {
    scope: "parent", role: "parent", role_slugs: ["parent"], primary_role: "parent",
    child_ids: ["stu-1"],
  });
  assertEquals(res.status, 503);
});

Deno.test("W2 parent: a parent session may record its own feedback (reaches DB → 503)", async () => {
  const res = await call(
    "POST",
    "/intelligence/recommendations/feedback",
    ["viewSis"],
    { itemKey: "parent:fees:stu-1", itemType: "follow_up", action: "dismiss" },
    { scope: "parent", role: "parent", role_slugs: ["parent"], primary_role: "parent", child_ids: ["stu-1"] },
  );
  assertEquals(res.status, 503);
});

Deno.test("W2.0b: recommendations rejects a non-school scope (403)", async () => {
  const res = await call(
    "GET",
    "/intelligence/recommendations?persona=principal",
    ["viewAnalytics"],
    undefined,
    { scope: "organization", school_id: null },
  );
  assertEquals(res.status, 403);
});

// ─── POST /intelligence/recommendations/feedback ─────────────────────────────

Deno.test("W2.0b: feedback rejects a missing itemKey (422 before DB)", async () => {
  const res = await call("POST", "/intelligence/recommendations/feedback", ["viewAnalytics"], {
    itemType: "exception",
    action: "accept",
  });
  assertEquals(res.status, 422);
});

Deno.test("W2.0b: feedback rejects an unknown itemType (422)", async () => {
  const res = await call("POST", "/intelligence/recommendations/feedback", ["viewAnalytics"], {
    itemKey: "risk:student:x",
    itemType: "not-a-type",
    action: "accept",
  });
  assertEquals(res.status, 422);
});

Deno.test("W2.0b: feedback rejects an unknown action (422)", async () => {
  const res = await call("POST", "/intelligence/recommendations/feedback", ["viewAnalytics"], {
    itemKey: "risk:student:x",
    itemType: "exception",
    action: "delete",
  });
  assertEquals(res.status, 422);
});

Deno.test("W2.0b: a valid feedback body is authorized and reaches the DB (503)", async () => {
  const res = await call("POST", "/intelligence/recommendations/feedback", ["viewAnalytics"], {
    itemKey: "risk:student:x",
    itemType: "exception",
    action: "dismiss",
  });
  assertEquals(res.status, 503);
});

Deno.test("W2.0b: feedback rejects an ineligible scope (403)", async () => {
  // Feed-eligible scopes are school/parent/student; an organization session is not.
  const res = await call(
    "POST",
    "/intelligence/recommendations/feedback",
    ["viewAnalytics"],
    { itemKey: "k", itemType: "exception", action: "accept" },
    { scope: "organization", school_id: null },
  );
  assertEquals(res.status, 403);
});

Deno.test("W2.0b: an unauthenticated caller is rejected (401)", async () => {
  const res = await routeIntelligence(
    new Request("https://x/intelligence/recommendations", { method: "GET" }),
    config,
    "GET",
    "/intelligence/recommendations",
  );
  assertEquals(res?.status, 401);
});
