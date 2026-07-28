// QW4 · QA-B-001 — Employee module ROUTE contract (DB-free).
//
// Proves the RBAC/error-path envelope for routeEmployee without a live Postgres,
// using the proven pattern: with config = { jwtSecret } (no supabaseUrl/serviceRole),
// assertSessionValid short-circuits to null and a forged JWT flows straight to the
// permission gate. 503 TENANT_DB_NOT_CONFIGURED = gate PASSED, handler reached the
// (unconfigured) tenant DB — the DB-free proxy for "authorized".
//
// Focus of this row: the employee read/write gates were OR-fixed
// (employee_handlers.ts:22 requireEmployeeRead = requireAnyPermission(viewEmployees
// OR viewHr); :27 requireEmployeeWrite = requireAnyPermission(manageEmployees OR
// manageHr)). We assert EITHER slug authorizes and NEITHER → 403.
//
// Live remainder: the end-to-end 200 + real employee rows + tenant isolation are
// covered by the repository tests + the live cert (needs ERP_TENANT_DATABASE_URL).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeEmployee } from "./employee_router.ts";

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
  return routeEmployee(req, config, method, path);
}

Deno.test("QA-B-001: GET employees is denied for a non-holder librarian (403 FORBIDDEN)", async () => {
  const res = await call("GET", "/employees", ["viewLibrary"]);
  assertEquals(res!.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
  assertEquals(env.data, null);
});

Deno.test("QA-B-001: GET employees passes the gate with viewEmployees (503 reaches DB)", async () => {
  const res = await call("GET", "/employees", ["viewEmployees"]);
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-001: GET employees passes the gate with viewHr alone (OR-gate, 503)", async () => {
  // The OR-fix: viewHr alone must authorize even without viewEmployees.
  const res = await call("GET", "/employees", ["viewHr"]);
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-001: GET employees with neither viewEmployees nor viewHr is 403", async () => {
  const res = await call("GET", "/employees", ["viewStudents"]);
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-001: GET employees rejects an unauthenticated caller (401)", async () => {
  const res = await call("GET", "/employees", null);
  assertEquals(res!.status, 401);
  const env = await res!.json();
  assertEquals(env.error.code, "UNAUTHORIZED");
});

Deno.test("QA-B-001: POST employee role assign authorizes with manageHr alone (OR-gate, 503)", async () => {
  // requireEmployeeWrite = manageEmployees OR manageHr. manageHr alone → through.
  const id = "11111111-1111-4111-8111-111111111111";
  const res = await call("POST", `/employees/${id}/roles`, ["manageHr"], {}, {
    roleCode: "teacher",
  });
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-001: POST employee role assign authorizes with manageEmployees alone (OR-gate, 503)", async () => {
  const id = "11111111-1111-4111-8111-111111111111";
  const res = await call("POST", `/employees/${id}/roles`, ["manageEmployees"], {}, {
    roleCode: "teacher",
  });
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-001: POST employee role assign is denied without any manage slug (403)", async () => {
  const id = "11111111-1111-4111-8111-111111111111";
  // viewEmployees can read but must NOT write.
  const res = await call("POST", `/employees/${id}/roles`, ["viewEmployees"], {}, {
    roleCode: "teacher",
  });
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-001: POST employee role assign rejects missing roleCode with 422 (after gate)", async () => {
  const id = "11111111-1111-4111-8111-111111111111";
  const res = await call("POST", `/employees/${id}/roles`, ["manageEmployees"], {}, {});
  assertEquals(res!.status, 422);
});

Deno.test("QA-B-001: an unregistered employees path returns null (central dispatcher 404s)", async () => {
  const res = await call("GET", "/employees/not-a-uuid/unknown", ["viewEmployees"]);
  assertEquals(res, null);
});

Deno.test("QA-B-001: a non-employees path is not claimed by routeEmployee (null)", async () => {
  const res = await call("GET", "/students", ["viewEmployees"]);
  assertEquals(res, null);
});
