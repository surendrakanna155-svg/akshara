// GAP-P1-8 — POST /parent/communication/:id/read + /acknowledge (DB-free
// route/RBAC-wiring contract, mirrors the qw4_school_completion_route_contract_test.ts
// pattern: with no erpTenantDatabaseUrl configured, a request that clears auth +
// parent-scope reaches the tenant-DB boundary and gets 503 TENANT_DB_NOT_CONFIGURED
// (the DB-free proxy for "authorized, would have persisted/audited on a real DB");
// a request that fails the parent-scope check is rejected with 403 before ever
// reaching the DB. Live persistence + audit-row assertions are VPS-blocked
// (no local Postgres in this harness) — see DR_RPO_ACCEPTANCE / live-lane notes.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeParent } from "./parent_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
// DB-free: no erpTenantDatabaseUrl / supabaseUrl, so authenticateRequest skips
// the live session check and withTenantContext throws TenantDbNotConfiguredError.
const config = { jwtSecret: SECRET } as AppConfig;
const COMM_ID = "comm-123";

function parentClaims(childIds: string[]): AccessTokenClaims {
  return {
    sub: "parent-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "parent",
    role_slugs: ["parent"],
    primary_role: "parent",
    permissions: [],
    permissions_version: 1,
    scope: "parent",
    school_group_id: null,
    student_id: null,
    child_ids: childIds,
    session_id: "s1",
  };
}

function nonParentClaims(): AccessTokenClaims {
  return {
    sub: "teacher-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "teacher",
    role_slugs: ["teacher"],
    primary_role: "teacher",
    permissions: [],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s2",
  };
}

async function call(method: string, path: string, claims: AccessTokenClaims): Promise<Response> {
  const token = await signAccessToken(SECRET, claims, 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}` },
  });
  const res = await routeParent(req, config, method, path);
  if (res === null) throw new Error(`route returned null for ${method} ${path}`);
  return res;
}

Deno.test("GAP-P1-8: parent with a linked child reaches the DB boundary marking a communication read (authorized)", async () => {
  const res = await call(
    "POST",
    `/parent/communication/${COMM_ID}/read`,
    parentClaims(["11111111-1111-4111-8111-111111111111"]),
  );
  assertEquals(res.status, 503);
  const body = await res.json();
  assertEquals(body.error.code, "TENANT_DB_NOT_CONFIGURED");
});

Deno.test("GAP-P1-8: parent with a linked child reaches the DB boundary acknowledging a communication (authorized)", async () => {
  const res = await call(
    "POST",
    `/parent/communication/${COMM_ID}/acknowledge`,
    parentClaims(["11111111-1111-4111-8111-111111111111"]),
  );
  assertEquals(res.status, 503);
  const body = await res.json();
  assertEquals(body.error.code, "TENANT_DB_NOT_CONFIGURED");
});

Deno.test("GAP-P1-8: a non-parent scope is forbidden from read/acknowledge (never reaches the DB)", async () => {
  const readRes = await call(
    "POST",
    `/parent/communication/${COMM_ID}/read`,
    nonParentClaims(),
  );
  assertEquals(readRes.status, 403);

  const ackRes = await call(
    "POST",
    `/parent/communication/${COMM_ID}/acknowledge`,
    nonParentClaims(),
  );
  assertEquals(ackRes.status, 403);
});

Deno.test("GAP-P1-8: a parent account with NO linked children still resolves the route (own-child scope bounds the search, not the route match)", async () => {
  // findOwnCommunicationEntity short-circuits on an empty child_ids list, so
  // this reaches the handler's own 404 branch rather than a router 404 — proof
  // the own-child scoping lives in the query, not an accidental route miss.
  // With no DB configured, withTenantContext still throws first (503) since
  // the short-circuit lives inside the DB callback.
  const res = await call("POST", `/parent/communication/${COMM_ID}/read`, parentClaims([]));
  assertEquals(res.status, 503);
});
