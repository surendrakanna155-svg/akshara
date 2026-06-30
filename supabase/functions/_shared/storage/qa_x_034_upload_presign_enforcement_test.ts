// QA-X-034 (security) — upload presign enforces TYPE + SIZE before a signed URL
// is ever minted.
//
// THREAT: a client could ask for a presigned upload URL for an executable, a
// disguised file, or an oversized blob, then PUT arbitrary bytes into tenant
// storage. The defence is validateUpload (storage_service.ts), applied at presign
// in BOTH upload surfaces BEFORE any storage/DB work:
//   • school memories  — handleMemoryUploadPresign → 422 on error
//     (MEMORY_UPLOAD_CONSTRAINTS: 50 MiB, images + video).
//   • admissions docs   — handlePresignDocumentUpload → 422 on error
//     (ADMISSIONS_UPLOAD_CONSTRAINTS: 25 MiB, PDF + images).
//
// validateUpload is a pure function (extension always checked; declared MIME +
// size checked when present) returning an error string or null, so the core
// enforcement is provable directly. We ALSO drive the admissions presign route to
// prove the 422 is wired into the request path (the memories presign 422 is
// already covered by QA-B-007; admissions presign 422 is added here).
//
// Live remainder (needs storage + ERP_TENANT_DATABASE_URL): the actual signed URL
// for an ALLOWED file, and the bucket-side size/MIME backstop, belong to the live
// cert. The presign-time rejection contract is fully provable DB-free.

import {
  assert,
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import {
  ADMISSIONS_UPLOAD_CONSTRAINTS,
  MEMORY_UPLOAD_CONSTRAINTS,
  validateUpload,
} from "./storage_service.ts";
import { routeAdmissions } from "../admissions/admissions_router.ts";
import { routeMemories } from "../memories/school_memories_router.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

// ── (A) validateUpload — the enforcement primitive, both constraint sets ──────

Deno.test("QA-X-034: an OVERSIZED file is rejected (memories, > 50 MiB)", () => {
  const err = validateUpload(
    "video.mp4",
    { contentType: "video/mp4", sizeBytes: MEMORY_UPLOAD_CONSTRAINTS.maxBytes + 1 },
    MEMORY_UPLOAD_CONSTRAINTS,
  );
  assert(err !== null, "oversized upload must be rejected");
  assertStringIncludes(err!, "maximum size");
});

Deno.test("QA-X-034: an OVERSIZED file is rejected (admissions, > 25 MiB)", () => {
  const err = validateUpload(
    "scan.pdf",
    { contentType: "application/pdf", sizeBytes: ADMISSIONS_UPLOAD_CONSTRAINTS.maxBytes + 1 },
    ADMISSIONS_UPLOAD_CONSTRAINTS,
  );
  assert(err !== null);
  assertStringIncludes(err!, "maximum size");
});

Deno.test("QA-X-034: a zero/negative declared size is rejected (no empty/garbage upload)", () => {
  assert(
    validateUpload("a.jpg", { sizeBytes: 0 }, MEMORY_UPLOAD_CONSTRAINTS) !== null,
  );
});

Deno.test("QA-X-034: a DISALLOWED EXTENSION (.exe) is rejected by both surfaces", () => {
  const mem = validateUpload(
    "malware.exe",
    { contentType: "application/octet-stream", sizeBytes: 1000 },
    MEMORY_UPLOAD_CONSTRAINTS,
  );
  assert(mem !== null);
  assertStringIncludes(mem!, "not allowed");

  const adm = validateUpload(
    "malware.exe",
    { contentType: "application/octet-stream", sizeBytes: 1000 },
    ADMISSIONS_UPLOAD_CONSTRAINTS,
  );
  assert(adm !== null);
  assertStringIncludes(adm!, "not allowed");
});

Deno.test("QA-X-034: a DISALLOWED MIME on an allowed extension is rejected (declared type honoured)", () => {
  // The extension (.pdf) is allowed for admissions, but the declared content-type
  // is an executable → reject. (Defends against an allowed extension carrying a
  // wrong/forged declared MIME.)
  const err = validateUpload(
    "doc.pdf",
    { contentType: "application/x-msdownload", sizeBytes: 1000 },
    ADMISSIONS_UPLOAD_CONSTRAINTS,
  );
  assert(err !== null);
  assertStringIncludes(err!, "not allowed");
});

Deno.test("QA-X-034: an extension-less filename is rejected", () => {
  assert(
    validateUpload("noextension", { sizeBytes: 1000 }, MEMORY_UPLOAD_CONSTRAINTS) !==
      null,
  );
});

Deno.test("QA-X-034: a PDF is NOT a valid memory upload (constraint sets are distinct)", () => {
  // PDFs are admissions-only; uploading one as a memory must be rejected.
  assert(
    validateUpload("report.pdf", { contentType: "application/pdf", sizeBytes: 1000 },
      MEMORY_UPLOAD_CONSTRAINTS) !== null,
  );
  // …and it IS allowed for admissions.
  assertEquals(
    validateUpload("report.pdf", { contentType: "application/pdf", sizeBytes: 1000 },
      ADMISSIONS_UPLOAD_CONSTRAINTS),
    null,
  );
});

Deno.test("QA-X-034: an ALLOWED type + within-size upload passes (returns null)", () => {
  // Memories: a JPEG image under 50 MiB.
  assertEquals(
    validateUpload(
      "photo.jpg",
      { contentType: "image/jpeg", sizeBytes: 2_000_000 },
      MEMORY_UPLOAD_CONSTRAINTS,
    ),
    null,
  );
  // Admissions: a PDF exactly at the 25 MiB boundary (boundary is inclusive).
  assertEquals(
    validateUpload(
      "Birth Certificate.pdf",
      { contentType: "application/pdf", sizeBytes: ADMISSIONS_UPLOAD_CONSTRAINTS.maxBytes },
      ADMISSIONS_UPLOAD_CONSTRAINTS,
    ),
    null,
  );
});

// ── (B) Route-level: presign returns 422 BEFORE storage; allowed passes the gate ──

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

async function callAdmissions(perms: string[], body: unknown): Promise<Response> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request("https://x/admissions/documents/upload/presign", {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const res = await routeAdmissions(req, config, "POST", "/admissions/documents/upload/presign");
  return res!;
}

const LEAD = "33333333-3333-3333-3333-333333333333";

Deno.test("QA-X-034 (route): admissions presign rejects an OVERSIZED file (422 before storage)", async () => {
  const res = await callAdmissions(["manageAdmissions"], {
    lead_id: LEAD,
    file_name: "scan.pdf",
    content_type: "application/pdf",
    size_bytes: ADMISSIONS_UPLOAD_CONSTRAINTS.maxBytes + 1,
  });
  assertEquals(res.status, 422);
  const env = await res.json();
  assertEquals(env.error.code, "VALIDATION_ERROR");
});

Deno.test("QA-X-034 (route): admissions presign rejects a DISALLOWED type (.exe → 422)", async () => {
  const res = await callAdmissions(["manageAdmissions"], {
    lead_id: LEAD,
    file_name: "malware.exe",
    content_type: "application/octet-stream",
    size_bytes: 1000,
  });
  assertEquals(res.status, 422);
});

Deno.test("QA-X-034 (route): admissions presign needs manageAdmissions (a non-holder is 403, never reaches presign)", async () => {
  // Anti-tamper completeness: the presign is also gated, so an unprivileged
  // caller can't even attempt an upload.
  const res = await callAdmissions(["viewAdmissions"], {
    lead_id: LEAD,
    file_name: "ok.pdf",
    content_type: "application/pdf",
    size_bytes: 1000,
  });
  assertEquals(res.status, 403);
});

async function callMemories(perms: string[], body: unknown): Promise<Response> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const eventId = "44444444-4444-4444-8444-444444444444";
  const path = `/memories/events/${eventId}/upload/presign`;
  const req = new Request(`https://x${path}`, {
    method: "POST",
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const res = await routeMemories(req, config, "POST", path);
  return res!;
}

Deno.test("QA-X-034 (route): memories presign rejects an OVERSIZED image (422 before DB)", async () => {
  const res = await callMemories(["manageSchoolMemories"], {
    filename: "huge.jpg",
    contentType: "image/jpeg",
    sizeBytes: MEMORY_UPLOAD_CONSTRAINTS.maxBytes + 1,
  });
  assertEquals(res.status, 422);
});

Deno.test("QA-X-034 (route): memories presign with an ALLOWED image passes validation → reaches DB (503, not 422)", async () => {
  // An allowed type + size clears validateUpload and proceeds to the tenant DB,
  // which is unconfigured here (503) — proving the gate let it through (would be
  // a 201 with a signed URL against a live DB/storage).
  const res = await callMemories(["manageSchoolMemories"], {
    filename: "photo.jpg",
    contentType: "image/jpeg",
    sizeBytes: 1_000_000,
  });
  assertEquals(res.status, 503);
});
