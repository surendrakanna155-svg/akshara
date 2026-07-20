// PRA-P1-30 (security) — homework attachments are REAL stored objects. The
// teacher-worksheet and student-submission presign endpoints reject wrong-type /
// oversized files and enforce scope/permission BEFORE a signed URL is minted; the
// submit + create paths refuse a foreign-tenant storage_path; the download
// endpoint refuses a path outside the caller's tenant prefix.
//
// All provable DB-free: presign runs validateUpload + the scope/permission gate
// before touching storage/DB, and the submit/create/download tenant-prefix checks
// run before any DB call.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routePilotOperations } from "./pilot_operations_router.ts";
import { HOMEWORK_UPLOAD_CONSTRAINTS } from "../storage/storage_service.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function baseClaims(): AccessTokenClaims {
  return {
    sub: "u1",
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
  };
}

function teacher(perms: string[]): AccessTokenClaims {
  return { ...baseClaims(), permissions: perms };
}

function student(): AccessTokenClaims {
  return {
    ...baseClaims(),
    scope: "student",
    role: "student",
    role_slugs: ["student"],
    primary_role: "student",
    student_id: "stu-1",
  };
}

function parent(): AccessTokenClaims {
  return {
    ...baseClaims(),
    scope: "parent",
    role: "parent",
    role_slugs: ["parent"],
    primary_role: "parent",
    child_ids: ["stu-1"],
  };
}

async function call(
  claims: AccessTokenClaims,
  path: string,
  body: unknown,
): Promise<Response> {
  const token = await signAccessToken(SECRET, claims, 900);
  const req = new Request(`https://x${path}`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const res = await routePilotOperations(req, config, "POST", path);
  return res!;
}

const TEACHER_PRESIGN = "/teacher/homework/attachment/presign";
const STUDENT_PRESIGN = "/student/homework/attachment/presign";
const DOWNLOAD = "/homework/attachment/download";
const CREATE = "/teacher/homework";
const SUBMIT = "/student/homework/submit";

// ── Teacher worksheet presign ────────────────────────────────────────────────

Deno.test("PRA-P1-30: teacher presign rejects an OVERSIZED file (422)", async () => {
  const res = await call(teacher(["manageHomework"]), TEACHER_PRESIGN, {
    file_name: "ws.pdf",
    content_type: "application/pdf",
    size_bytes: HOMEWORK_UPLOAD_CONSTRAINTS.maxBytes + 1,
  });
  assertEquals(res.status, 422);
});

Deno.test("PRA-P1-30: teacher presign rejects a DISALLOWED type (.exe → 422)", async () => {
  const res = await call(teacher(["manageHomework"]), TEACHER_PRESIGN, {
    file_name: "x.exe",
    content_type: "application/octet-stream",
    size_bytes: 1000,
  });
  assertEquals(res.status, 422);
});

Deno.test("PRA-P1-30: teacher presign needs manageHomework (403)", async () => {
  const res = await call(teacher([]), TEACHER_PRESIGN, {
    file_name: "ws.pdf",
    content_type: "application/pdf",
    size_bytes: 1000,
  });
  assertEquals(res.status, 403);
});

Deno.test("PRA-P1-30: teacher presign rejects a non-school (student) caller (403)", async () => {
  const res = await call(student(), TEACHER_PRESIGN, {
    file_name: "ws.pdf",
    content_type: "application/pdf",
    size_bytes: 1000,
  });
  assertEquals(res.status, 403);
});

// ── Student submission presign ───────────────────────────────────────────────

Deno.test("PRA-P1-30: student presign requires homework_id (422)", async () => {
  const res = await call(student(), STUDENT_PRESIGN, {
    file_name: "answer.jpg",
    content_type: "image/jpeg",
    size_bytes: 1000,
  });
  assertEquals(res.status, 422);
});

Deno.test("PRA-P1-30: student presign rejects a DISALLOWED type (422)", async () => {
  const res = await call(student(), STUDENT_PRESIGN, {
    homework_id: "hw_1",
    file_name: "answer.exe",
    content_type: "application/octet-stream",
    size_bytes: 1000,
  });
  assertEquals(res.status, 422);
});

Deno.test("PRA-P1-30: student presign rejects a non-student (teacher) caller (403)", async () => {
  const res = await call(teacher(["manageHomework"]), STUDENT_PRESIGN, {
    homework_id: "hw_1",
    file_name: "answer.jpg",
    content_type: "image/jpeg",
    size_bytes: 1000,
  });
  assertEquals(res.status, 403);
});

// ── Submit / create confirm: foreign-tenant storage_path is refused ──────────

Deno.test("PRA-P1-30: submit refuses a FOREIGN-tenant attachment_storage_path (422)", async () => {
  const res = await call(student(), SUBMIT, {
    homework_id: "hw_1",
    notes: "done",
    attachment_storage_path: "other-org/other-school/stu-1/hw_1/x.jpg",
  });
  assertEquals(res.status, 422);
});

Deno.test("PRA-P1-30: create refuses a FOREIGN-tenant attachment_storage_path (422)", async () => {
  const res = await call(teacher(["manageHomework"]), CREATE, {
    class_label: "8-A",
    subject: "Math",
    title: "Algebra",
    due_date: "2026-07-10",
    attachment_storage_path: "other-org/other-school/teacher/x.pdf",
  });
  assertEquals(res.status, 422);
});

// ── Download ─────────────────────────────────────────────────────────────────

Deno.test("PRA-P1-30: download requires a storage_path (422)", async () => {
  const res = await call(parent(), DOWNLOAD, {});
  assertEquals(res.status, 422);
});

Deno.test("PRA-P1-30: download refuses a FOREIGN-tenant storage_path (422)", async () => {
  const res = await call(parent(), DOWNLOAD, {
    storage_path: "other-org/other-school/teacher/x.pdf",
  });
  assertEquals(res.status, 422);
});
