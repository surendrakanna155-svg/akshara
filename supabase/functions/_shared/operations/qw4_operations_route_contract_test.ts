// QW4 · QA-B-033 (P1) — Operations Hub route-contract (DB-free).
//
// routeOperations owns two GET routes: /operations/hub and /operations/actions.
// Both gate through requireOpsRead = requirePermission("viewOperationsHub") then
// requireSchoolOperationalScope — see operations/operations_hub_handlers.ts:14.
//
// This proves:
//   • a non-holder (lacks viewOperationsHub) is denied both routes (403);
//   • a holder (viewOperationsHub + school scope) passes the gate and reaches
//     the unconfigured tenant DB (503 = the DB-free proxy for "authorized");
//   • a holder whose scope is NOT school is still denied (403) — the scope leg;
//   • unauthenticated → 401; unregistered /operations path → 404; foreign → null.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeOperations } from "./operations_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

const OPS_ROUTES = ["/operations/hub", "/operations/actions"];

function claims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "ops-user-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["viewOperationsHub"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

function get(token: string | null, path: string): Request {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (token) headers.authorization = `Bearer ${token}`;
  return new Request(`https://x${path}`, { method: "GET", headers });
}

Deno.test("QA-B-033: a non-holder is denied both operations routes (403)", async () => {
  const token = await signAccessToken(SECRET, claims({ permissions: ["viewInventory"] }), 900);
  for (const path of OPS_ROUTES) {
    const res = await routeOperations(get(token, path), config, "GET", path);
    assertEquals(res?.status, 403, `expected 403 for ${path}, got ${res?.status}`);
    const env = await res!.json();
    assertEquals(env.error.code, "FORBIDDEN");
  }
});

Deno.test("QA-B-033: a viewOperationsHub holder passes the gate on both routes (503 to DB)", async () => {
  const token = await signAccessToken(SECRET, claims(), 900);
  for (const path of OPS_ROUTES) {
    const res = await routeOperations(get(token, path), config, "GET", path);
    assertEquals(res?.status, 503, `expected 503 for ${path}, got ${res?.status}`);
  }
});

Deno.test("QA-B-033: a holder without school scope is still denied (scope leg, 403)", async () => {
  const token = await signAccessToken(
    SECRET,
    claims({ scope: "platform", school_id: null }),
    900,
  );
  const res = await routeOperations(get(token, "/operations/hub"), config, "GET", "/operations/hub");
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-033: an unauthenticated caller is rejected on operations routes (401)", async () => {
  for (const path of OPS_ROUTES) {
    const res = await routeOperations(get(null, path), config, "GET", path);
    assertEquals(res?.status, 401, `expected 401 for ${path}, got ${res?.status}`);
  }
});

Deno.test("QA-B-033: an unregistered /operations path returns 404", async () => {
  const token = await signAccessToken(SECRET, claims(), 900);
  const res = await routeOperations(
    get(token, "/operations/nope"),
    config,
    "GET",
    "/operations/nope",
  );
  assertEquals(res?.status, 404);
});

Deno.test("QA-B-033: a non-/operations path returns null (no match)", async () => {
  const res = await routeOperations(get(null, "/student/exams"), config, "GET", "/student/exams");
  assertEquals(res, null);
});
