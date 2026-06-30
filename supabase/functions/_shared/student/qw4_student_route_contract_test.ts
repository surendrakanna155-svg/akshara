// QW4 · QA-B-032 (P1) — Student persona route-contract (DB-free).
//
// routeStudent registers exactly 7 GET routes (dashboard, attendance, homework,
// exams, timetable, notices, profile). This proves the PERSONA-SCOPE contract:
//   • a student-scope token reaches each of the 7 routes (gate passes → 503,
//     the DB-free proxy for "authorized + reached the unconfigured tenant DB");
//   • a non-student (school-scope) token and an unauthenticated caller are
//     DENIED before any data is read (403 / 401);
//   • an unregistered /student path / non-GET method returns null (→ 404).
//
// Each student handler is built by createStudentScopedReadHandlers, whose
// requireRead = requireStudentScope (scope==="student" && school_id &&
// student_id) — see entity_read/mobile_read_handlers.ts:40,486.
//
// REMAINDER (infra-blocked, NOT asserted here): "returns ONLY the student's own
// rows" is row-level scoping enforced by Postgres RLS keyed on student_id. That
// needs a live ERP_TENANT_DATABASE_URL; it is the live-cert / RLS leg. The
// route + persona contract below is fully provable DB-free.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeStudent } from "./student_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

const STUDENT_ROUTES = [
  "/student/dashboard",
  "/student/attendance",
  "/student/homework",
  "/student/exams",
  "/student/timetable",
  "/student/notices",
  "/student/profile",
];

function studentClaims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "stu-user-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "student",
    role_slugs: ["student"],
    primary_role: "student",
    permissions: [],
    permissions_version: 1,
    scope: "student",
    school_group_id: null,
    student_id: "student-1",
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

Deno.test("QA-B-032: a student token reaches all 7 student read routes (authorized to DB)", async () => {
  const token = await signAccessToken(SECRET, studentClaims(), 900);
  for (const path of STUDENT_ROUTES) {
    const res = await routeStudent(get(token, path), config, "GET", path);
    // 503 TENANT_DB_NOT_CONFIGURED = the student-scope gate passed and the
    // handler reached the (unconfigured) tenant DB — the DB-free proxy for
    // "authorized for this route".
    assertEquals(res?.status, 503, `expected 503 for ${path}, got ${res?.status}`);
  }
});

Deno.test("QA-B-032: a non-student (school-scope) token is denied every student route (403)", async () => {
  const token = await signAccessToken(
    SECRET,
    studentClaims({
      role: "teacher",
      role_slugs: ["teacher"],
      primary_role: "teacher",
      scope: "school",
      student_id: null,
      permissions: ["viewAdminHub"],
    }),
    900,
  );
  for (const path of STUDENT_ROUTES) {
    const res = await routeStudent(get(token, path), config, "GET", path);
    assertEquals(res?.status, 403, `expected 403 for ${path}, got ${res?.status}`);
    const env = await res!.json();
    assertEquals(env.error.code, "FORBIDDEN");
  }
});

Deno.test("QA-B-032: a student token missing student_id is denied (403, cannot self-scope)", async () => {
  // A token with scope=student but no student_id cannot resolve "its own data",
  // so requireStudentScope rejects it before any read.
  const token = await signAccessToken(SECRET, studentClaims({ student_id: null }), 900);
  const res = await routeStudent(get(token, "/student/dashboard"), config, "GET", "/student/dashboard");
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-032: an unauthenticated caller is rejected on student routes (401)", async () => {
  for (const path of STUDENT_ROUTES) {
    const res = await routeStudent(get(null, path), config, "GET", path);
    assertEquals(res?.status, 401, `expected 401 for ${path}, got ${res?.status}`);
  }
});

Deno.test("QA-B-032: an unregistered student path returns 404 (router owns /student prefix)", async () => {
  const token = await signAccessToken(SECRET, studentClaims(), 900);
  const res = await routeStudent(
    get(token, "/student/does-not-exist"),
    config,
    "GET",
    "/student/does-not-exist",
  );
  assertEquals(res?.status, 404);
});

Deno.test("QA-B-032: a non-GET method on a student route returns 404 (reads are GET-only)", async () => {
  const token = await signAccessToken(SECRET, studentClaims(), 900);
  const req = new Request("https://x/student/dashboard", {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
  });
  const res = await routeStudent(req, config, "POST", "/student/dashboard");
  assertEquals(res?.status, 404);
});

Deno.test("QA-B-032: a non-/student path returns null (no match → dispatch 404)", async () => {
  const res = await routeStudent(
    get(null, "/finance/collections"),
    config,
    "GET",
    "/finance/collections",
  );
  assertEquals(res, null);
});
