// QW4 · QA-B-006 + QA-B-047 — school_config ROUTE/RBAC contract (DB-free).
//
// `routeSchoolConfig` owns exactly one path (/school-config) with GET + PUT.
// Proven WITHOUT a live Postgres (a 503/TENANT_DB_NOT_CONFIGURED means the gate
// PASSED and the handler reached the unconfigured tenant DB = "authorized"):
//   - GET requires viewSchoolSetup + school scope; a non-holder gets 403.
//   - PUT requires manageSchoolSetup + school scope; a manage-holder reaches the
//     persist path (503); a non-holder gets 403; the read-only viewSchoolSetup
//     holder is denied the write (403).
//   - A PUT with no capabilities object is rejected (422 INVALID_BODY) before DB.
//   - Method not registered on the path → router returns null (404 at dispatch).
// Live remainder (infra): the real 200 + persisted school_configuration row and
// the per-school RLS isolation are covered by the live cert.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeSchoolConfig } from "./school_config_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(permissions: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

async function call(
  method: string,
  perms: string[],
  body?: unknown,
  over?: Partial<AccessTokenClaims>,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms, over), 900);
  const req = new Request("https://x/school-config", {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  return routeSchoolConfig(req, config, method, "/school-config");
}

const validPut = {
  schoolType: "day_school",
  curriculum: "cbse",
  operationsModel: "single_school",
  branchCount: 1,
  capabilities: { transport: true },
};

Deno.test("QA-B-047: GET school-config is denied without viewSchoolSetup (403)", async () => {
  const res = await call("GET", ["viewSis"]);
  assertEquals(res?.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-047: GET school-config passes the gate with viewSchoolSetup (503)", async () => {
  const res = await call("GET", ["viewSchoolSetup"]);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-006: PUT school-config is denied without manageSchoolSetup (403)", async () => {
  const res = await call("PUT", ["viewSchoolSetup"], validPut);
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-006: PUT school-config passes the gate with manageSchoolSetup (503)", async () => {
  const res = await call("PUT", ["manageSchoolSetup"], validPut);
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-006: PUT with no capabilities object is rejected (422 INVALID_BODY) before DB", async () => {
  const res = await call("PUT", ["manageSchoolSetup"], { schoolType: "day_school" });
  assertEquals(res?.status, 422);
  const env = await res!.json();
  assertEquals(env.error.code, "INVALID_BODY");
});

Deno.test("QA-B-006: a school-setup gate requires school scope (org-scope token → 403)", async () => {
  const res = await call("GET", ["viewSchoolSetup"], undefined, {
    scope: "organization",
    school_id: null,
  });
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-006: unauthenticated PUT is rejected (401)", async () => {
  const req = new Request("https://x/school-config", {
    method: "PUT",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(validPut),
  });
  const res = await routeSchoolConfig(req, config, "PUT", "/school-config");
  assertEquals(res?.status, 401);
});

Deno.test("QA-B-006: an unregistered method on the path → router returns null", async () => {
  const res = await call("DELETE", ["manageSchoolSetup"]);
  assertEquals(res, null);
});

Deno.test("QA-B-006: a path outside /school-config → router returns null", async () => {
  const token = await signAccessToken(SECRET, claims(["viewSchoolSetup"]), 900);
  const req = new Request("https://x/school-setup", {
    method: "GET",
    headers: { authorization: `Bearer ${token}` },
  });
  const res = await routeSchoolConfig(req, config, "GET", "/school-setup");
  assertEquals(res, null);
});
