// Adaptive AI — P3-AI-2 / W2-GATE-2: Quick Actions route contract (DB-free).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
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

async function call(path: string, perms: string[], over: Partial<AccessTokenClaims> = {}): Promise<Response> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  const pathname = path.split("?")[0]!;
  const res = await routeIntelligence(
    new Request(`https://x${path}`, { method: "GET", headers: { authorization: `Bearer ${token}` } }),
    config,
    "GET",
    pathname,
  );
  if (res === null) throw new Error(`routeIntelligence returned null for ${pathname}`);
  return res;
}

Deno.test("W2-GATE-2: quick-actions is a pure catalog read (200, no DB)", async () => {
  const res = await call("/intelligence/quick-actions?persona=principal", ["viewAnalytics"]);
  assertEquals(res.status, 200);
  const env = await res.json();
  assertEquals(env.data.persona, "principal");
  assert(env.data.items.some((i: { id: string }) => i.id === "principal_today_priorities"));
});

Deno.test("W2-GATE-2: results are RBAC-filtered by the caller's permissions", async () => {
  const res = await call("/intelligence/quick-actions?persona=principal", ["viewAnalytics"]);
  const env = await res.json();
  // No viewStudentRisk → the high-risk action is absent.
  assert(!env.data.items.some((i: { id: string }) => i.id === "principal_high_risk_students"));
});

Deno.test("W2-GATE-2: an invalid persona is rejected (422)", async () => {
  const res = await call("/intelligence/quick-actions?persona=wizard", ["viewAnalytics"]);
  assertEquals(res.status, 422);
});

Deno.test("W2-GATE-2: a missing persona is rejected (422)", async () => {
  const res = await call("/intelligence/quick-actions", ["viewAnalytics"]);
  assertEquals(res.status, 422);
});

Deno.test("W2-GATE-2: a non-school scope is forbidden (403)", async () => {
  const res = await call(
    "/intelligence/quick-actions?persona=principal",
    ["viewAnalytics"],
    { scope: "organization", school_id: null },
  );
  assertEquals(res.status, 403);
});

Deno.test("W2-GATE-2: an unauthenticated caller is rejected (401)", async () => {
  const res = await routeIntelligence(
    new Request("https://x/intelligence/quick-actions?persona=principal", { method: "GET" }),
    config,
    "GET",
    "/intelligence/quick-actions",
  );
  assertEquals(res?.status, 401);
});
