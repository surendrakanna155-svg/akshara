// QW4 · QA-B-004 — Principal Command Center ROUTE contract (DB-free).
//
// routePrincipalCommand owns /principal-command/{center,query}. Both gate on
// requireAnyPermission(["viewPrincipalCommand","viewAnalytics"]) (OR-fixed,
// principal_command_handlers.ts:19,40) THEN requireSchoolOperationalScope — so the
// caller must hold one of the two slugs AND be in school scope with a school_id.
//
// PROVEN HERE (locally, DB-free):
//   * 503 (authorized) for a principal holding viewPrincipalCommand.
//   * 503 for a holder of viewAnalytics ALONE (the OR-gate).
//   * 403 for a librarian / parent holding neither slug.
//   * 403 for an org-scope (non-school) caller even WITH the slug — the
//     school-operational-scope leg (org vs school scope).
//   * 422 on /query with a blank q (gate passed, validation fired before DB).
//   * 401 unauthenticated; 404 unregistered path within the prefix.
//
// Live remainder: the real command-center payload + per-school data isolation are
// covered by the live cert (needs ERP_TENANT_DATABASE_URL).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routePrincipalCommand } from "./principal_command_router.ts";

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
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
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
  path: string,
  permissions: string[] | null,
  over: Partial<AccessTokenClaims> = {},
): Promise<Response | null> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (permissions !== null) {
    const token = await signAccessToken(SECRET, claims(permissions, over), 900);
    headers.authorization = `Bearer ${token}`;
  }
  const req = new Request(`https://x${path}`, { method, headers });
  // The dispatcher passes the URL pathname (no query string) as `path`; mirror that.
  const pathname = path.split("?")[0]!;
  return routePrincipalCommand(req, config, method, pathname);
}

Deno.test("QA-B-004: GET principal-command center authorizes a principal with viewPrincipalCommand (503)", async () => {
  const res = await call("GET", "/principal-command/center", ["viewPrincipalCommand"]);
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-004: GET principal-command center authorizes viewAnalytics alone (OR-gate, 503)", async () => {
  const res = await call("GET", "/principal-command/center", ["viewAnalytics"]);
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-004: GET principal-command center is denied for a librarian (403)", async () => {
  const res = await call("GET", "/principal-command/center", ["viewLibrary"]);
  assertEquals(res!.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-004: GET principal-command center is denied for a parent-scope caller (403)", async () => {
  const res = await call("GET", "/principal-command/center", ["viewParentAcademicSummary"], {
    scope: "parent",
    role: "parent",
  });
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-004: GET principal-command center denies an org-scope caller WITH the slug (school scope leg, 403)", async () => {
  // Holds viewPrincipalCommand but scope is organization → requireSchoolOperationalScope 403.
  const res = await call("GET", "/principal-command/center", ["viewPrincipalCommand"], {
    scope: "organization",
    school_id: null,
    role: "director",
  });
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-004: GET principal-command query rejects a blank q (422 after gate)", async () => {
  const res = await call("GET", "/principal-command/query?q=%20", ["viewPrincipalCommand"]);
  assertEquals(res!.status, 422);
});

Deno.test("QA-B-004: GET principal-command query authorizes and reaches DB with a query (503)", async () => {
  const res = await call("GET", "/principal-command/query?q=attendance", ["viewAnalytics"]);
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-004: principal-command rejects an unauthenticated caller (401)", async () => {
  const res = await call("GET", "/principal-command/center", null);
  assertEquals(res!.status, 401);
});

Deno.test("QA-B-004: an unregistered principal-command path returns 404", async () => {
  const res = await call("GET", "/principal-command/unknown", ["viewPrincipalCommand"]);
  assertEquals(res!.status, 404);
});

Deno.test("QA-B-004: a non principal-command path is not claimed (null)", async () => {
  const res = await call("GET", "/dashboard", ["viewPrincipalCommand"]);
  assertEquals(res, null);
});
