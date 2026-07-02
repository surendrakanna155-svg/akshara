// QW4 · QA-B-045 (P1) — Pilot overlay routes enforce their persona/role.
//
// routePilotOperations exposes the mobile-overlay write routes. Each enforces a
// PERSONA (scope) gate first, then (for teacher writes) a granular permission —
// see pilot_operations_handlers.ts. This file proves the cross-persona contract:
// a route's own persona reaches the DB (503) while a foreign persona is denied
// (403), via routePilotOperations (the real router), end to end.
//
//   POST /teacher/attendance/submit  → school scope + markAttendance
//   POST /teacher/homework           → school scope + manageHomework
//   POST /student/homework/submit    → student scope (scope+school_id+student_id)
//   POST /parent/leave               → parent scope + child linkage
//
// Cross-persona denials proven:
//   • a non-teacher (student/parent scope) is denied the teacher attendance
//     submit and homework-create routes (403 "Teacher scope required");
//   • a school-scope teacher WITHOUT the granular permission is denied (403);
//   • a non-student (teacher scope) is denied the student homework submit (403);
//   • a non-parent (teacher scope) is denied the parent leave route (403);
//   • each persona's OWN route passes its gate and reaches the DB (503).
//
// This mirrors the established pilot_rbac_gate_test.ts pattern but drives the
// REAL ROUTER (path → handler) rather than calling handlers directly, closing
// the router-dispatch leg of the contract.
//
// REMAINDER (infra-blocked): the parent child-linkage 403 (child_id ∈ child_ids)
// IS asserted here (it reads the claim), but the live INSERT + RLS that a
// teacher's submit only writes their own class's rows needs a live
// ERP_TENANT_DATABASE_URL (live cert).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routePilotOperations } from "./pilot_operations_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function base(over: Partial<AccessTokenClaims>): AccessTokenClaims {
  return {
    sub: "user-1",
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
    session_id: "s1",
    ...over,
  };
}

const teacher = (perms: string[]) =>
  base({ scope: "school", permissions: perms, primary_role: "teacher", role: "teacher" });
const student = () =>
  base({
    scope: "student",
    student_id: "student-1",
    primary_role: "student",
    role: "student",
    role_slugs: ["student"],
  });
const parent = (childIds: string[]) =>
  base({
    scope: "parent",
    child_ids: childIds,
    primary_role: "parent",
    role: "parent",
    role_slugs: ["parent"],
  });

async function post(
  c: AccessTokenClaims | null,
  path: string,
  body: unknown,
): Promise<Response | null> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (c) headers.authorization = `Bearer ${await signAccessToken(SECRET, c, 900)}`;
  const req = new Request(`https://x${path}`, { method: "POST", headers, body: JSON.stringify(body) });
  return routePilotOperations(req, config, "POST", path);
}

async function get(
  c: AccessTokenClaims | null,
  path: string,
): Promise<Response | null> {
  const headers: Record<string, string> = {};
  if (c) headers.authorization = `Bearer ${await signAccessToken(SECRET, c, 900)}`;
  const req = new Request(`https://x${path}`, { method: "GET", headers });
  // The real dispatcher routes on the pathname only (query stripped); mirror it
  // so a "?from=..." on the URL never breaks the exact-path route match.
  const routePathname = new URL(`https://x${path}`).pathname;
  return routePilotOperations(req, config, "GET", routePathname);
}

// ── Teacher attendance submit: teacher-only ──────────────────────────────────

Deno.test("QA-B-045: teacher attendance submit is denied a non-teacher persona (403)", async () => {
  for (const c of [student(), parent(["student-1"])]) {
    const res = await post(c, "/teacher/attendance/submit", { class_id: "8A", entries: [] });
    assertEquals(res?.status, 403, `scope ${c.scope} must not submit teacher attendance`);
  }
});

Deno.test("QA-B-045: teacher attendance submit is denied a teacher WITHOUT markAttendance (403)", async () => {
  const res = await post(teacher(["viewAdminHub"]), "/teacher/attendance/submit", {
    class_id: "8A",
    entries: [],
  });
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-045: teacher attendance submit passes WITH school scope + markAttendance (503 to DB)", async () => {
  const res = await post(teacher(["markAttendance"]), "/teacher/attendance/submit", {
    class_id: "8A",
    entries: [],
  });
  assertEquals(res?.status, 503);
});

// ── Teacher homework create: teacher-only ────────────────────────────────────

Deno.test("QA-B-045: teacher homework create is denied a non-teacher persona (403)", async () => {
  for (const c of [student(), parent(["student-1"])]) {
    const res = await post(c, "/teacher/homework", {
      class_label: "8-A",
      subject: "Math",
      title: "HW",
    });
    assertEquals(res?.status, 403, `scope ${c.scope} must not create homework`);
  }
});

Deno.test("QA-B-045: teacher homework create is denied a teacher WITHOUT manageHomework (403)", async () => {
  const res = await post(teacher(["viewAdminHub"]), "/teacher/homework", {
    class_label: "8-A",
    subject: "Math",
    title: "HW",
  });
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-045: teacher homework create passes WITH manageHomework + valid body (503 to DB)", async () => {
  const res = await post(teacher(["manageHomework"]), "/teacher/homework", {
    class_label: "8-A",
    subject: "Math",
    title: "HW",
    due_date: "2026-07-10",
  });
  assertEquals(res?.status, 503);
});

// ── HWK-2/5/6/D1 homework management routes: teacher-only + manageHomework ────

Deno.test("HWK-2: non-submitters GET is denied a non-teacher persona (403)", async () => {
  for (const c of [student(), parent(["student-1"])]) {
    const res = await get(c, "/teacher/homework/hw-1/non-submitters");
    assertEquals(res?.status, 403, `scope ${c.scope} must not read non-submitters`);
  }
});

Deno.test("HWK-2: non-submitters GET is denied a teacher WITHOUT manageHomework (403)", async () => {
  const res = await get(teacher(["viewAdminHub"]), "/teacher/homework/hw-1/non-submitters");
  assertEquals(res?.status, 403);
});

Deno.test("HWK-2: non-submitters GET passes WITH manageHomework (503 to DB)", async () => {
  const res = await get(teacher(["manageHomework"]), "/teacher/homework/hw-1/non-submitters");
  assertEquals(res?.status, 503);
});

Deno.test("HWK-5: homework history GET passes WITH manageHomework (503 to DB)", async () => {
  const res = await get(teacher(["manageHomework"]), "/teacher/homework/history?from=2026-07-01");
  assertEquals(res?.status, 503);
});

Deno.test("HWK-5: homework history GET is denied a non-teacher persona (403)", async () => {
  const res = await get(student(), "/teacher/homework/history");
  assertEquals(res?.status, 403);
});

Deno.test("HWK-6: bulk-review POST passes WITH manageHomework (503 to DB)", async () => {
  const res = await post(teacher(["manageHomework"]), "/teacher/homework/bulk-review", {
    homework_id: "hw-1",
    grade: "A",
  });
  assertEquals(res?.status, 503);
});

Deno.test("HWK-6: bulk-review POST is denied a teacher WITHOUT manageHomework (403)", async () => {
  const res = await post(teacher(["viewAdminHub"]), "/teacher/homework/bulk-review", {
    homework_id: "hw-1",
    grade: "A",
  });
  assertEquals(res?.status, 403);
});

Deno.test("HWK-D1: notify-non-submitters POST passes WITH manageHomework (503 to DB)", async () => {
  const res = await post(
    teacher(["manageHomework"]),
    "/teacher/homework/hw-1/notify-non-submitters",
    {},
  );
  assertEquals(res?.status, 503);
});

Deno.test("HWK-D1: notify-non-submitters POST is denied a non-teacher persona (403)", async () => {
  for (const c of [student(), parent(["student-1"])]) {
    const res = await post(c, "/teacher/homework/hw-1/notify-non-submitters", {});
    assertEquals(res?.status, 403);
  }
});

// ── Student homework submit: student-only ────────────────────────────────────

Deno.test("QA-B-045: student homework submit is denied a non-student persona (403)", async () => {
  for (const c of [teacher(["manageHomework"]), parent(["student-1"])]) {
    const res = await post(c, "/student/homework/submit", { homework_id: "hw-1", notes: "done" });
    assertEquals(res?.status, 403, `scope ${c.scope} must not submit student homework`);
  }
});

Deno.test("QA-B-045: student homework submit passes WITH student scope (503 to DB)", async () => {
  const res = await post(student(), "/student/homework/submit", { homework_id: "hw-1", notes: "done" });
  assertEquals(res?.status, 503);
});

// ── Parent leave submit: parent-only + child linkage ─────────────────────────

Deno.test("QA-B-045: parent leave is denied a non-parent persona (403)", async () => {
  for (const c of [teacher(["manageHomework"]), student()]) {
    const res = await post(c, "/parent/leave", { child_id: "student-1", type: "sick" });
    assertEquals(res?.status, 403, `scope ${c.scope} must not submit parent leave`);
  }
});

Deno.test("QA-B-045: parent leave is denied when the child is not linked to the parent (403)", async () => {
  const res = await post(parent(["other-child"]), "/parent/leave", {
    child_id: "student-1",
    type: "sick",
  });
  assertEquals(res?.status, 403);
});

Deno.test("QA-B-045: parent leave passes WITH parent scope + a linked child (503 to DB)", async () => {
  const res = await post(parent(["student-1"]), "/parent/leave", {
    child_id: "student-1",
    type: "sick",
  });
  assertEquals(res?.status, 503);
});

// ── Auth + dispatch contract ─────────────────────────────────────────────────

Deno.test("QA-B-045: pilot overlay routes reject an unauthenticated caller (401)", async () => {
  for (const path of [
    "/teacher/attendance/submit",
    "/teacher/homework",
    "/student/homework/submit",
    "/parent/leave",
  ]) {
    const res = await post(null, path, {});
    assertEquals(res?.status, 401, `expected 401 for ${path}, got ${res?.status}`);
  }
});

Deno.test("QA-B-045: an unmatched pilot path returns null (no match → dispatch 404)", async () => {
  const res = await post(teacher(["markAttendance"]), "/teacher/unknown", {});
  assertEquals(res, null);
});
