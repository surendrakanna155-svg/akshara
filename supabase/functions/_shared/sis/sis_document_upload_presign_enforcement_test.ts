// PRA-P1-19 (security) — the SIS student-document upload enforces a REAL stored
// object. The presign endpoint rejects wrong-type / oversized files and requires
// manageSis BEFORE any storage/DB work; the confirm endpoint refuses to persist a
// row without a tenant-scoped storage_path (killing the old fabricated
// `storage://documents/<name>` string that stored no bytes).
//
// All assertions here are provable DB-free: presign runs validateUpload + the
// permission gate before touching the tenant DB, and confirm validates the
// storage_path shape before any DB call.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeSis } from "./sis_router.ts";
import { STUDENT_DOCUMENT_UPLOAD_CONSTRAINTS } from "../storage/storage_service.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;
const STUDENT = "55555555-5555-4555-8555-555555555555";

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: perms,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

async function call(
  perms: string[],
  method: string,
  path: string,
  body: unknown,
): Promise<Response> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const res = await routeSis(req, config, method, path);
  return res!;
}

const PRESIGN = `/sis/students/${STUDENT}/documents/presign`;
const CONFIRM = `/sis/students/${STUDENT}/documents`;

Deno.test("PRA-P1-19: presign rejects an OVERSIZED file (422 before storage)", async () => {
  const res = await call(["manageSis"], "POST", PRESIGN, {
    file_name: "scan.pdf",
    content_type: "application/pdf",
    size_bytes: STUDENT_DOCUMENT_UPLOAD_CONSTRAINTS.maxBytes + 1,
  });
  assertEquals(res.status, 422);
  const env = await res.json();
  assertEquals(env.error.code, "VALIDATION_ERROR");
});

Deno.test("PRA-P1-19: presign rejects a DISALLOWED type (.exe → 422)", async () => {
  const res = await call(["manageSis"], "POST", PRESIGN, {
    file_name: "malware.exe",
    content_type: "application/octet-stream",
    size_bytes: 1000,
  });
  assertEquals(res.status, 422);
});

Deno.test("PRA-P1-19: presign needs manageSis (a non-holder is 403, never reaches presign)", async () => {
  const res = await call(["viewSis"], "POST", PRESIGN, {
    file_name: "ok.pdf",
    content_type: "application/pdf",
    size_bytes: 1000,
  });
  assertEquals(res.status, 403);
});

Deno.test("PRA-P1-19: confirm WITHOUT storage_path is rejected (no fabricated string)", async () => {
  const res = await call(["manageSis"], "POST", CONFIRM, {
    type: "Transfer Certificate",
    file_name: "tc.pdf",
  });
  assertEquals(res.status, 422);
  const env = await res.json();
  assertEquals(env.error.code, "VALIDATION_ERROR");
});

Deno.test("PRA-P1-19: confirm with a FOREIGN-tenant storage_path is rejected", async () => {
  const res = await call(["manageSis"], "POST", CONFIRM, {
    type: "Transfer Certificate",
    file_name: "tc.pdf",
    storage_path: "other-org/other-school/x/y_tc.pdf",
  });
  assertEquals(res.status, 422);
});
