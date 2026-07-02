// Journey Wave 5 — MJ-M10 / MJ-M11 RBAC gate tests.
//
// Proves the teacher pilot write handlers now require a granular permission
// (not just school scope) and that the parent correction handler requires
// parent scope. A 403 means the gate blocked; a 503 (TENANT_DB_NOT_CONFIGURED)
// means the gate PASSED and the handler proceeded to the DB layer (which is not
// configured in a unit test) — i.e. the permission/scope check let it through.
// The end-to-end positive path (real 200 + RLS) is covered by the live cert.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import {
  handleTeacherAttendanceDraft,
  handleTeacherAttendanceSubmit,
  handleTeacherExamMarkUpdate,
  handleTeacherHomeworkCreate,
  handleTeacherHomeworkReview,
} from "./pilot_operations_handlers.ts";
import { handleParentCreateAttendanceCorrection } from "../attendance/attendance_handlers.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function schoolClaims(permissions: string[]): AccessTokenClaims {
  return {
    sub: "user-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "officeStaff",
    role_slugs: ["officeStaff"],
    primary_role: "officeStaff",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

function parentClaims(): AccessTokenClaims {
  return {
    ...schoolClaims(["submitAttendanceCorrection"]),
    sub: "parent-1",
    role: "parent",
    role_slugs: ["parent"],
    primary_role: "parent",
    scope: "parent",
    child_ids: ["student-1"],
  };
}

function post(path: string, token: string, body: unknown): Request {
  return new Request(`https://x${path}`, {
    method: "POST",
    headers: {
      authorization: `Bearer ${token}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

async function tokenWith(permissions: string[]): Promise<string> {
  return await signAccessToken(SECRET, schoolClaims(permissions), 900);
}

// ── Attendance marking gates on markAttendance (ATTEN-3 / MJ-M10) ─────────────

Deno.test("attendance draft is denied without markAttendance", async () => {
  const token = await tokenWith(["viewAdminHub"]);
  const res = await handleTeacherAttendanceDraft(
    post("/teacher/attendance/draft", token, { class_id: "class_8a", entries: [] }),
    config,
  );
  assertEquals(res.status, 403);
});

Deno.test("attendance submit is denied without markAttendance", async () => {
  const token = await tokenWith(["viewAdminHub"]);
  const res = await handleTeacherAttendanceSubmit(
    post("/teacher/attendance/submit", token, { class_id: "class_8a", entries: [] }),
    config,
  );
  assertEquals(res.status, 403);
});

Deno.test("attendance submit passes the gate WITH markAttendance", async () => {
  const token = await tokenWith(["markAttendance"]);
  const res = await handleTeacherAttendanceSubmit(
    post("/teacher/attendance/submit", token, { class_id: "class_8a", entries: [] }),
    config,
  );
  // Gate passed → reached the (unconfigured) DB layer.
  assertEquals(res.status, 503);
});

// ── Homework create/grade gates on manageHomework (TEACH-4 / MJ-M10) ──────────

Deno.test("homework create is denied without manageHomework", async () => {
  const token = await tokenWith(["viewAdminHub"]);
  const res = await handleTeacherHomeworkCreate(
    post("/teacher/homework", token, { class_label: "8-A", subject: "Math", title: "HW" }),
    config,
  );
  assertEquals(res.status, 403);
});

Deno.test("homework review is denied without manageHomework", async () => {
  const token = await tokenWith(["viewAdminHub"]);
  const res = await handleTeacherHomeworkReview(
    post("/teacher/homework/submissions/sub-1/review", token, { grade: "A" }),
    config,
    "sub-1",
  );
  assertEquals(res.status, 403);
});

Deno.test("homework create passes the gate WITH manageHomework", async () => {
  const token = await tokenWith(["manageHomework"]);
  const res = await handleTeacherHomeworkCreate(
    post("/teacher/homework", token, {
      class_label: "8-A",
      subject: "Math",
      title: "HW",
      due_date: "2026-07-10",
    }),
    config,
  );
  assertEquals(res.status, 503);
});

// ── Exam mark update gates on manageExamMarks (TEACH-4 / MJ-M10) ──────────────

Deno.test("exam mark update is denied without manageExamMarks", async () => {
  const token = await tokenWith(["viewAdminHub"]);
  const res = await handleTeacherExamMarkUpdate(
    new Request("https://x/teacher/exams/marks/m-1", {
      method: "PUT",
      headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
      body: JSON.stringify({ marks_obtained: 10 }),
    }),
    config,
    "m-1",
  );
  assertEquals(res.status, 403);
});

// ── Parent correction route requires parent scope (ATTEN-2 / MJ-M11) ──────────

Deno.test("parent correction rejects a school-scope caller", async () => {
  const token = await signAccessToken(SECRET, schoolClaims(["manageSis"]), 900);
  const res = await handleParentCreateAttendanceCorrection(
    post("/parent/attendance/corrections", token, { sisStudentId: "S1" }),
    config,
  );
  assertEquals(res.status, 403);
});

Deno.test("parent correction passes scope WITH parent claims", async () => {
  const token = await signAccessToken(SECRET, parentClaims(), 900);
  const res = await handleParentCreateAttendanceCorrection(
    post("/parent/attendance/corrections", token, { sisStudentId: "S1" }),
    config,
  );
  // Parent scope accepted → reached the (unconfigured) DB layer (where RLS would
  // enforce the student_guardians linkage in production).
  assertEquals(res.status, 503);
});
