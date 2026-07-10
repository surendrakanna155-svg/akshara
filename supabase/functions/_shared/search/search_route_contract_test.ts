// Adaptive AI — P3-AI-2 / W2.S: Universal Search route contract (DB-free).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeSearch } from "./search_router.ts";

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
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  const pathname = path.split("?")[0]!;
  return await routeSearch(
    new Request(`https://x${path}`, { method, headers: { authorization: `Bearer ${token}` } }),
    config,
    method,
    pathname,
  );
}

Deno.test("W2.S: a permitted search reaches the DB (503 unconfigured = authorized+matched)", async () => {
  const res = await call("GET", "/search?q=ram", ["viewSis"]);
  assertEquals(res?.status, 503);
});

Deno.test("W2.S: a caller with NO searchable-category permission gets an empty result (200)", async () => {
  // No viewSis → the students category is filtered out → empty groups, no DB hit.
  const res = await call("GET", "/search?q=ram", ["someOtherPerm"]);
  assertEquals(res?.status, 200);
  const env = await res!.json();
  assertEquals(env.data.groups, []);
});

Deno.test("W2.S: a too-short query is rejected (422 before DB)", async () => {
  const res = await call("GET", "/search?q=r", ["viewSis"]);
  assertEquals(res?.status, 422);
});

Deno.test("W2.S: a missing query is rejected (422)", async () => {
  const res = await call("GET", "/search", ["viewSis"]);
  assertEquals(res?.status, 422);
});

Deno.test("W2.S: a non-school scope is forbidden (403)", async () => {
  const res = await call("GET", "/search?q=ram", ["viewSis"], { scope: "organization", school_id: null });
  assertEquals(res?.status, 403);
});

Deno.test("W2.S: an unauthenticated caller is rejected (401)", async () => {
  const res = await routeSearch(
    new Request("https://x/search?q=ram", { method: "GET" }),
    config,
    "GET",
    "/search",
  );
  assertEquals(res?.status, 401);
});

Deno.test("W2.S: a non-GET method is rejected (405)", async () => {
  const res = await call("POST", "/search?q=ram", ["viewSis"]);
  assertEquals(res?.status, 405);
});

Deno.test("W2.S: a non-/search path returns null (no match)", async () => {
  const res = await call("GET", "/intelligence/priorities", ["viewSis"]);
  assertEquals(res, null);
});
