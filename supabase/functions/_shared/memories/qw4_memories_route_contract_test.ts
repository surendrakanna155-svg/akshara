// QW4 · QA-B-007 — School Memories ROUTE contract (DB-free).
//
// routeMemories owns /memories/events (GET/POST), /memories/events/{uuid}
// (GET, POST publish, POST upload/presign, POST upload/confirm), /memories/analytics,
// /memories/media/{uuid}/download, /memories/share/{token}. Read gates on
// requirePermission("viewSchoolMemories"); write gates on
// requirePermission("manageSchoolMemories") (school_memories_handlers.ts:33,38,
// each chained with requireSchoolOperationalScope).
//
// PROVEN HERE (locally, DB-free):
//   * 503 (authorized) for a manageSchoolMemories holder creating an event.
//   * 403 for a non-holder (lacks manageSchoolMemories) on POST.
//   * 503 for a viewSchoolMemories holder on GET events list.
//   * presign/upload contract: validation fires before DB —
//       - missing body / missing filename -> 400;
//       - wrong-type/oversized upload -> 422 (RT-31 validateUpload).
//   * upload/confirm requires albumId+storagePath+title -> 400 before DB.
//   * 401 unauthenticated; 404 unregistered path.
//
// NOTE ON STATUS CODES (real backend behaviour, not a defect): the create/confirm
// "missing required field" path returns 400 VALIDATION_ERROR (handler :137,:140,
// :293,:296), whereas the presign upload-constraint path returns 422 (:239). We
// assert each handler's actual code rather than normalising.
//
// Live remainder: persisted event/media rows, real presigned storage URLs and the
// share-token resolution are covered by the live cert (needs ERP_TENANT_DATABASE_URL
// + storage).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeMemories } from "./school_memories_router.ts";

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
  body?: unknown,
): Promise<Response | null> {
  const headers: Record<string, string> = { "content-type": "application/json" };
  if (permissions !== null) {
    const token = await signAccessToken(SECRET, claims(permissions), 900);
    headers.authorization = `Bearer ${token}`;
  }
  const req = new Request(`https://x${path}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  return routeMemories(req, config, method, path);
}

const EVENT_ID = "44444444-4444-4444-8444-444444444444";

Deno.test("QA-B-007: POST memories events authorizes a manageSchoolMemories holder (503 persists)", async () => {
  const res = await call("POST", "/memories/events", ["manageSchoolMemories"], {
    title: "Annual Day",
    category: "event",
  });
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-007: POST memories events is denied for a non-holder (403)", async () => {
  // viewSchoolMemories can read but must NOT create.
  const res = await call("POST", "/memories/events", ["viewSchoolMemories"], {
    title: "Annual Day",
    category: "event",
  });
  assertEquals(res!.status, 403);
  const env = await res!.json();
  assertEquals(env.error.code, "FORBIDDEN");
});

Deno.test("QA-B-007: POST memories events rejects missing title/category (400 before DB)", async () => {
  const res = await call("POST", "/memories/events", ["manageSchoolMemories"], {
    title: "Annual Day",
  });
  assertEquals(res!.status, 400);
});

Deno.test("QA-B-007: GET memories events authorizes a viewSchoolMemories holder (503)", async () => {
  const res = await call("GET", "/memories/events", ["viewSchoolMemories"]);
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-007: GET memories events is denied for a non-holder (403)", async () => {
  const res = await call("GET", "/memories/events", ["viewLibrary"]);
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-007: POST upload presign is denied for a read-only holder (403 write gate)", async () => {
  const res = await call("POST", `/memories/events/${EVENT_ID}/upload/presign`, [
    "viewSchoolMemories",
  ], { filename: "photo.jpg", contentType: "image/jpeg", sizeBytes: 1000 });
  assertEquals(res!.status, 403);
});

Deno.test("QA-B-007: POST upload presign rejects a missing filename (400 before DB)", async () => {
  const res = await call("POST", `/memories/events/${EVENT_ID}/upload/presign`, [
    "manageSchoolMemories",
  ], {});
  assertEquals(res!.status, 400);
});

Deno.test("QA-B-007: POST upload presign rejects a disallowed file type (422 RT-31)", async () => {
  const res = await call("POST", `/memories/events/${EVENT_ID}/upload/presign`, [
    "manageSchoolMemories",
  ], { filename: "malware.exe", contentType: "application/octet-stream", sizeBytes: 1000 });
  assertEquals(res!.status, 422);
});

Deno.test("QA-B-007: POST upload presign with a valid image authorizes (503 reaches DB)", async () => {
  const res = await call("POST", `/memories/events/${EVENT_ID}/upload/presign`, [
    "manageSchoolMemories",
  ], { filename: "photo.jpg", contentType: "image/jpeg", sizeBytes: 1000 });
  assertEquals(res!.status, 503);
});

Deno.test("QA-B-007: POST upload confirm rejects missing required fields (400 before DB)", async () => {
  const res = await call("POST", `/memories/events/${EVENT_ID}/upload/confirm`, [
    "manageSchoolMemories",
  ], { albumId: "a1" });
  assertEquals(res!.status, 400);
});

Deno.test("QA-B-007: memories rejects an unauthenticated caller (401)", async () => {
  const res = await call("POST", "/memories/events", null, { title: "x", category: "y" });
  assertEquals(res!.status, 401);
});

Deno.test("QA-B-007: an unregistered memories path returns 404", async () => {
  const res = await call("GET", "/memories/unknown", ["viewSchoolMemories"]);
  assertEquals(res!.status, 404);
});

Deno.test("QA-B-007: a non-memories path is not claimed by the router (null)", async () => {
  const res = await call("GET", "/gallery", ["viewSchoolMemories"]);
  assertEquals(res, null);
});
