// QW4 · QA-B-003 + QA-B-044 — Parent Experience ROUTE contract (DB-free).
//
// routeParentExperience owns /parent/experience/{summary,summary/refresh,
// report/printable,activation}. The GET/POST summary handlers gate on
// requirePermission("viewParentAcademicSummary") and then enforce a defense-in-
// depth per-child check (parent_experience_router.ts:26 assertParentChildAccess):
// a scope==="parent" caller may only request a studentId in their own child_ids.
//
// PROVEN HERE (locally, DB-free):
//   * 401 unauthenticated; 403 non-holder (lacks viewParentAcademicSummary).
//   * 422 missing studentId before DB.
//   * 403 for a parent-scope caller probing a studentId NOT in their child_ids
//     (the CONTRACT half of per-child isolation — QA-B-044).
//   * 503 (authorized) for a holder requesting their own linked child.
//   * POST /parent/experience/summary/refresh = the write/regenerate contract.
//   * 503 for a school-scope staff holder (parent OR school scope is valid).
//
// INFRA REMAINDER (Blocked — needs ERP_TENANT_DATABASE_URL / live RLS):
//   The DATA leg of per-child RLS — parent A, even passing only their own child_id,
//   must receive ONLY rows for that child and CANNOT read parent B's child's rows
//   from the same school. That row-scoped read is enforced in Postgres RLS, not in
//   this handler, and can only be proven against a live tenant DB.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeParentExperience } from "./parent_experience_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(
  permissions: string[],
  over: Partial<AccessTokenClaims> = {},
): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "parent",
    role_slugs: ["parent"],
    primary_role: "parent",
    permissions,
    permissions_version: 1,
    scope: "parent",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

async function call(
  method: string,
  path: string,
  permissions: string[] | null,
  over: Partial<AccessTokenClaims> = {},
  body?: unknown,
): Promise<Response | null> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (permissions !== null) {
    const token = await signAccessToken(SECRET, claims(permissions, over), 900);
    headers.authorization = `Bearer ${token}`;
  }
  const req = new Request(`https://x${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  // The dispatcher passes the URL pathname (no query string) as `path`; mirror that.
  const pathname = path.split("?")[0]!;
  return routeParentExperience(req, config, method, pathname);
}

const CHILD_A = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const CHILD_B = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";

Deno.test("QA-B-003: GET parent summary rejects an unauthenticated caller (401)", async () => {
  const res = await call(
    "GET",
    `/parent/experience/summary?studentId=${CHILD_A}`,
    null,
  );
  assertEquals(res!.status, 401);
});

Deno.test("QA-B-003: GET parent summary is denied without viewParentAcademicSummary (403)", async () => {
  const res = await call(
    "GET",
    `/parent/experience/summary?studentId=${CHILD_A}`,
    ["viewStudents"],
    { child_ids: [CHILD_A] },
  );
  assertEquals(res!.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-003: GET parent summary requires studentId (422 before DB)", async () => {
  const res = await call(
    "GET",
    `/parent/experience/summary`,
    ["viewParentAcademicSummary"],
    { child_ids: [CHILD_A] },
  );
  assertEquals(res!.status, 422);
});

Deno.test("QA-B-044: a parent probing a studentId NOT in their child_ids is denied (403)", async () => {
  // Holds the permission, but the requested child belongs to another parent.
  const res = await call(
    "GET",
    `/parent/experience/summary?studentId=${CHILD_B}`,
    ["viewParentAcademicSummary"],
    { child_ids: [CHILD_A] },
  );
  assertEquals(res!.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-003: GET parent summary authorizes a parent for their OWN child (503 reaches DB)", async () => {
  const res = await call(
    "GET",
    `/parent/experience/summary?studentId=${CHILD_A}`,
    ["viewParentAcademicSummary"],
    { child_ids: [CHILD_A] },
  );
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-003: GET parent summary authorizes school-scope staff (parent OR school scope, 503)", async () => {
  // assertParentChildAccess is a no-op for non-parent scope; the permission gate
  // is what authorizes a school-staff holder.
  const res = await call(
    "GET",
    `/parent/experience/summary?studentId=${CHILD_B}`,
    ["viewParentAcademicSummary"],
    { scope: "school", role: "teacher", child_ids: [] },
  );
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-003: POST summary refresh authorizes the parent for their own child (503 write contract)", async () => {
  const res = await call(
    "POST",
    `/parent/experience/summary/refresh?studentId=${CHILD_A}`,
    ["viewParentAcademicSummary"],
    { child_ids: [CHILD_A] },
  );
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-044: POST summary refresh blocks a parent probing another child (403)", async () => {
  const res = await call(
    "POST",
    `/parent/experience/summary/refresh?studentId=${CHILD_B}`,
    ["viewParentAcademicSummary"],
    { child_ids: [CHILD_A] },
  );
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-003: a non parent-experience path is not claimed by this router (null)", async () => {
  const res = await call("GET", "/parent/hub", ["viewParentAcademicSummary"]);
  assertEquals(res, null);
});
