// QW4 · QA-B-012 — teacher attendance write overlay: persona/role gate (DB-free).
//
// IMPORTANT routing fact: the spec names routeTeacher, but the teacher attendance
// WRITE path (/teacher/attendance/draft + /submit) is NOT in teacher_router.ts —
// that router only owns GET read surfaces + exam/parent-comm delegations. The
// real draft→submitted writes live in pilot_operations_handlers.ts and are
// dispatched by routePilotOperations (verified: pilot/pilot_operations_router.ts
// lines 18-23). So this overlay test targets the actual write handlers + router.
//
// The existing pilot_rbac_gate_test.ts already proves the markAttendance slug
// gate (403 without / 503 with) for a SCHOOL-scope caller. This file adds the
// PERSONA/ROLE leg the row asks for and the draft path, WITHOUT duplicating it:
//   - A non-teacher PERSONA (parent scope) is rejected at the scope guard (403)
//     for BOTH draft and submit — even when carrying markAttendance.
//   - A school caller WITH markAttendance reaches the persist path for BOTH draft
//     (status "draft") and submit (status "submitted") → 503 (DB-free proxy for
//     "authorized"; the draft vs submitted status divergence is in the repo/cert).
//   - The route dispatcher matches both write paths (reaches auth, not 404/null).
// Live remainder (infra): the real draft→submitted row transition + guardian
// absence notification fan-out + RLS are covered by the live cert.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import {
  handleTeacherAttendanceDraft,
  handleTeacherAttendanceSubmit,
} from "../pilot/pilot_operations_handlers.ts";
import { routePilotOperations } from "../pilot/pilot_operations_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function schoolClaims(permissions: string[]): AccessTokenClaims {
  return {
    sub: "teacher-1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "teacher",
    role_slugs: ["teacher"],
    primary_role: "teacher",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

function parentClaims(permissions: string[]): AccessTokenClaims {
  return {
    ...schoolClaims(permissions),
    sub: "parent-1",
    role: "parent",
    role_slugs: ["parent"],
    primary_role: "parent",
    scope: "parent",
    child_ids: ["stu-1"],
  };
}

function post(path: string, token: string, body: unknown): Request {
  return new Request(`https://x${path}`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

const attBody = { class_id: "class_8a", entries: [{ student_id: "stu-1", mark: "present" }] };

// ── Persona/role gate: a non-teacher persona (parent) is blocked ──────────────

Deno.test("QA-B-012: attendance submit rejects a parent persona even with markAttendance (403)", async () => {
  const token = await signAccessToken(SECRET, parentClaims(["markAttendance"]), 900);
  const res = await handleTeacherAttendanceSubmit(post("/teacher/attendance/submit", token, attBody), config);
  assertEquals(res.status, 403);
  const env = await res.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-012: attendance draft rejects a parent persona even with markAttendance (403)", async () => {
  const token = await signAccessToken(SECRET, parentClaims(["markAttendance"]), 900);
  const res = await handleTeacherAttendanceDraft(post("/teacher/attendance/draft", token, attBody), config);
  assertEquals(res.status, 403);
});

// ── Permission leg: a school caller without markAttendance is blocked ─────────

Deno.test("QA-B-012: attendance submit is denied for a school caller lacking markAttendance (403)", async () => {
  const token = await signAccessToken(SECRET, schoolClaims(["viewAdminHub"]), 900);
  const res = await handleTeacherAttendanceSubmit(post("/teacher/attendance/submit", token, attBody), config);
  assertEquals(res.status, 403);
});

// ── Authorized leg: teacher with markAttendance reaches the persist path ──────

Deno.test("QA-B-012: attendance submit (status submitted) is authorized with markAttendance (503)", async () => {
  const token = await signAccessToken(SECRET, schoolClaims(["markAttendance"]), 900);
  const res = await handleTeacherAttendanceSubmit(post("/teacher/attendance/submit", token, attBody), config);
  assertEquals(res.status, 503);
});

Deno.test("QA-B-012: attendance draft (status draft) is authorized with markAttendance (503)", async () => {
  const token = await signAccessToken(SECRET, schoolClaims(["markAttendance"]), 900);
  const res = await handleTeacherAttendanceDraft(post("/teacher/attendance/draft", token, attBody), config);
  assertEquals(res.status, 503);
});

Deno.test("QA-B-012: attendance submit rejects an invalid JSON body (422) before the DB", async () => {
  const token = await signAccessToken(SECRET, schoolClaims(["markAttendance"]), 900);
  const req = new Request("https://x/teacher/attendance/submit", {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: "not-json",
  });
  const res = await handleTeacherAttendanceSubmit(req, config);
  assertEquals(res.status, 422);
});

Deno.test("QA-B-012: unauthenticated submit is rejected (401)", async () => {
  const req = new Request("https://x/teacher/attendance/submit", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(attBody),
  });
  const res = await handleTeacherAttendanceSubmit(req, config);
  assertEquals(res.status, 401);
});

// ── Route dispatch: both write paths are matched (reach auth, not null/404) ───

Deno.test("QA-B-012: routePilotOperations dispatches POST /teacher/attendance/submit", async () => {
  const token = await signAccessToken(SECRET, schoolClaims(["markAttendance"]), 900);
  const res = await routePilotOperations(
    post("/teacher/attendance/submit", token, attBody),
    config,
    "POST",
    "/teacher/attendance/submit",
  );
  // Matched + authorized → 503; the key assertion is it is NOT null and NOT 404.
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-012: routePilotOperations dispatches POST /teacher/attendance/draft", async () => {
  const token = await signAccessToken(SECRET, schoolClaims(["markAttendance"]), 900);
  const res = await routePilotOperations(
    post("/teacher/attendance/draft", token, attBody),
    config,
    "POST",
    "/teacher/attendance/draft",
  );
  assertEquals(res?.status, 503);
});

Deno.test("QA-B-012: routePilotOperations returns null for an unmatched path", async () => {
  const token = await signAccessToken(SECRET, schoolClaims(["markAttendance"]), 900);
  const res = await routePilotOperations(
    post("/teacher/attendance/nope", token, attBody),
    config,
    "POST",
    "/teacher/attendance/nope",
  );
  assertEquals(res, null);
});
