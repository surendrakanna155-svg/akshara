// P1-PROD-22 SLICE 1 — attendance-auth ROUTE + RBAC + shape contract (DB-free).
//
// Proven without a live Postgres:
//   1. PATH-MATCH: the 3 routes resolve to handlers; an unregistered path under
//      the prefix 404s, a known path with the wrong method 405s, outside the
//      prefix returns null.
//   2. RBAC: 401 unauthenticated; school scope required (403 for a
//      student/parent-scope session); a targetUserId different from the caller
//      requires `manageHr` (403 without it, reaches the DB with it).
//   3. Self-service (no targetUserId) never requires manageHr — 503 (authorized,
//      DB-free) with just school scope.
//   4. The audit catalog backs every mutation (attendance_auth source module).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeAttendanceAuth } from "./attendance_auth_router.ts";
import { attendanceAuthAudit } from "../audit/mutation_audit_catalog.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[], over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "teacher", role_slugs: ["teacher"], primary_role: "teacher",
    permissions: perms, permissions_version: 1, scope: "school", school_group_id: null,
    student_id: null, child_ids: [], session_id: "s1", ...over,
  };
}

async function call(
  method: string,
  path: string,
  perms: string[],
  opts: { body?: unknown; over?: Partial<AccessTokenClaims> } = {},
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms, opts.over), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
  });
  return routeAttendanceAuth(req, config, method, path);
}

const DIM64 = Array.from({ length: 64 }, () => 0.1);

Deno.test("attendance-auth: the 3 routes path-match handlers (not 404)", async () => {
  for (const [m, p, body] of [
    ["POST", "/attendance-auth/face/enroll", { embedding: DIM64 }],
    ["GET", "/attendance-auth/face/enrollment", undefined],
    ["POST", "/attendance-auth/face/revoke", undefined],
  ] as const) {
    const res = await call(m, p, [], { body });
    assertEquals(res !== null, true, `${m} ${p} should resolve`);
    assertEquals(res!.status !== 404, true, `${m} ${p} should not 404`);
  }
});

Deno.test("attendance-auth: unregistered path under prefix 404s; outside prefix is null", async () => {
  const under = await call("GET", "/attendance-auth/nope", []);
  assertEquals(under?.status, 404);
  const outside = await call("POST", "/staff-attendance/check", []);
  assertEquals(outside, null);
});

Deno.test("attendance-auth: a known path with the wrong method 405s", async () => {
  const res = await call("GET", "/attendance-auth/face/enroll", []);
  assertEquals(res?.status, 405);
  const res2 = await call("POST", "/attendance-auth/face/enrollment", []);
  assertEquals(res2?.status, 405);
  const res3 = await call("GET", "/attendance-auth/face/revoke", []);
  assertEquals(res3?.status, 405);
});

Deno.test("attendance-auth: unauthenticated is 401 on every route", async () => {
  for (const [m, p] of [
    ["POST", "/attendance-auth/face/enroll"],
    ["GET", "/attendance-auth/face/enrollment"],
    ["POST", "/attendance-auth/face/revoke"],
  ] as const) {
    const req = new Request(`https://x${p}`, { method: m });
    const res = await routeAttendanceAuth(req, config, m, p);
    assertEquals(res?.status, 401, `${m} ${p} should be 401`);
  }
});

Deno.test("attendance-auth: a student/parent-scope session is 403 (school scope required)", async () => {
  const student = await call("POST", "/attendance-auth/face/enroll", [], {
    body: { embedding: DIM64 },
    over: { scope: "student", student_id: "st-1" },
  });
  assertEquals(student?.status, 403);
  assertEquals((await student!.json()).error.code, "FORBIDDEN");

  const parent = await call("GET", "/attendance-auth/face/enrollment", [], {
    over: { scope: "parent", child_ids: ["st-1"] },
  });
  assertEquals(parent?.status, 403);
});

Deno.test("attendance-auth: self-service enrol/status/revoke need only school scope — reaches DB (503)", async () => {
  const enroll = await call("POST", "/attendance-auth/face/enroll", [], { body: { embedding: DIM64 } });
  assertEquals(enroll?.status, 503);

  const status = await call("GET", "/attendance-auth/face/enrollment", []);
  assertEquals(status?.status, 503);

  const revoke = await call("POST", "/attendance-auth/face/revoke", [], { body: {} });
  assertEquals(revoke?.status, 503);
});

Deno.test("attendance-auth: enrolling ANOTHER user (targetUserId) without manageHr is 403", async () => {
  const res = await call("POST", "/attendance-auth/face/enroll", [], {
    body: { embedding: DIM64, targetUserId: "u2" },
  });
  assertEquals(res?.status, 403);
  assertEquals((await res!.json()).error.code, "FORBIDDEN");
});

Deno.test("attendance-auth: enrolling ANOTHER user WITH manageHr reaches the DB (503)", async () => {
  const res = await call("POST", "/attendance-auth/face/enroll", ["manageHr"], {
    body: { embedding: DIM64, targetUserId: "u2" },
  });
  assertEquals(res?.status, 503);
});

Deno.test("attendance-auth: revoking ANOTHER user without manageHr is 403; with it, reaches the DB", async () => {
  const denied = await call("POST", "/attendance-auth/face/revoke", [], {
    body: { targetUserId: "u2" },
  });
  assertEquals(denied?.status, 403);

  const allowed = await call("POST", "/attendance-auth/face/revoke", ["manageHr"], {
    body: { targetUserId: "u2" },
  });
  assertEquals(allowed?.status, 503);
});

Deno.test("attendance-auth: a targetUserId equal to the caller's own id is still self-service (no manageHr needed)", async () => {
  const res = await call("POST", "/attendance-auth/face/enroll", [], {
    body: { embedding: DIM64, targetUserId: "u1" },
  });
  assertEquals(res?.status, 503);
});

Deno.test("attendance-auth: audit catalog backs both mutations (attendance_auth module)", () => {
  const enrolled = attendanceAuthAudit.faceEnrolled("face_1", "u1", "u1");
  assertEquals(enrolled.domain.eventType, "attendance_auth.face.enrolled");
  assertEquals(enrolled.domain.sourceModule, "attendance_auth");
  assertEquals(enrolled.domain.payload, { enrollmentId: "face_1", userId: "u1", actorUserId: "u1" });

  const revoked = attendanceAuthAudit.faceRevoked("face_1", "u2", "hr-1");
  assertEquals(revoked.domain.eventType, "attendance_auth.face.revoked");
  assertEquals(revoked.domain.sourceModule, "attendance_auth");
  assertEquals(revoked.domain.payload, { enrollmentId: "face_1", userId: "u2", actorUserId: "hr-1" });
});
