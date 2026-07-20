// B4 — staff attendance (RE-IMPLEMENTED) ROUTE + RBAC + shape contract (DB-free).
//
// Proven without a live Postgres:
//   1. PATH-MATCH: the 8 routes resolve to handlers; an unregistered path under
//      the prefix 404s; outside the prefix returns null.
//   2. RBAC: 401 unauthenticated; 403 without the right permission; 503 (authorized,
//      DB-free) with it + a valid body. Approve/geofence-set need the SUPERVISORY
//      permission (not markStaffAttendance).
//   3. SHAPE hard-blocks server-side BEFORE any DB work (422): missing location,
//      missing face embedding, bad event_type. There is NO device-biometric field
//      anywhere — attendance proof is geofence + live camera face only.
//   4. The audit catalog backs every event (staff_attendance source module).
//
// Live geofence/anti-mock/face-match + the 200 happy path = the Track-B remainder
// (needs a live tenant DB + an on-device camera/GPS run).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import { routeStaffAttendance } from "./staff_attendance_router.ts";
import { staffAttendanceAudit } from "../audit/mutation_audit_catalog.ts";

const SECRET = "test-jwt-secret-minimum-32-characters-long";
const config = { jwtSecret: SECRET } as AppConfig;

function claims(perms: string[]): AccessTokenClaims {
  return {
    sub: "u1", tenant_id: "org-1", organization_id: "org-1", school_id: "school-1",
    role: "teacher", role_slugs: ["teacher"], primary_role: "teacher",
    permissions: perms, permissions_version: 1, scope: "school", school_group_id: null,
    student_id: null, child_ids: [], session_id: "s1",
  };
}

async function call(
  method: string,
  path: string,
  perms: string[],
  body?: unknown,
): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method,
    headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  // Production (app.ts) routes on url.pathname — the query string stays on the
  // Request for the handler to read, never in the matched path.
  const [pathname] = path.split("?");
  return routeStaffAttendance(req, config, method, pathname);
}

const validCheck = {
  eventType: "check_in",
  location: { latitude: 17.45, longitude: 78.39, accuracyM: 8, isMock: false, capturedAt: "2026-07-01T10:00:00Z" },
  face: { embedding: Array.from({ length: 64 }, () => 0.1), livenessPassed: true },
};
const validGeofence = { centerLatitude: 17.45, centerLongitude: 78.39, radiusM: 100, maxAccuracyM: 50 };

Deno.test("staff-attendance: the 8 routes path-match handlers (not 404)", async () => {
  for (const [m, p, perm, body] of [
    ["POST", "/staff-attendance/check", "markStaffAttendance", validCheck],
    ["POST", "/staff-attendance/enroll-face", "markStaffAttendance", { embedding: Array.from({ length: 64 }, () => 0.1) }],
    ["GET", "/staff-attendance/geofence", "markStaffAttendance", undefined],
    ["PUT", "/staff-attendance/geofence", "manageSchoolGeofence", validGeofence],
    ["POST", "/staff-attendance/manual-request", "markStaffAttendance", { eventType: "check_in", reason: "camera broke" }],
    ["GET", "/staff-attendance/manual-requests?mine=true", "markStaffAttendance", undefined],
    ["GET", "/staff-attendance/manual-requests", "approveStaffAttendance", undefined],
    ["POST", "/staff-attendance/manual-request/decide", "approveStaffAttendance", { requestId: "r1", approve: true }],
    ["GET", "/staff-attendance/my-history", "markStaffAttendance", undefined],
  ] as const) {
    const res = await call(m, p, [perm], body);
    assertEquals(res !== null, true, `${m} ${p} should resolve`);
    assertEquals(res!.status !== 404, true, `${m} ${p} should not 404`);
  }
});

Deno.test("staff-attendance: unregistered path under prefix 404s; outside prefix is null", async () => {
  const under = await call("GET", "/staff-attendance/nope", ["markStaffAttendance"]);
  assertEquals(under?.status, 404);
  const outside = await call("POST", "/attendance/sessions", ["markStaffAttendance"]);
  assertEquals(outside, null);
});

Deno.test("staff-attendance: unauthenticated check-in is 401", async () => {
  const req = new Request("https://x/staff-attendance/check", { method: "POST" });
  const res = await routeStaffAttendance(req, config, "POST", "/staff-attendance/check");
  assertEquals(res?.status, 401);
});

Deno.test("staff-attendance: 403 without markStaffAttendance (parent/student never)", async () => {
  const denied = await call("POST", "/staff-attendance/check", [], validCheck);
  assertEquals(denied?.status, 403);
  assertEquals((await denied!.json()).error.code, "FORBIDDEN");
});

Deno.test("staff-attendance: 503 (authorized, DB-free) with markStaffAttendance + valid body", async () => {
  const allowed = await call("POST", "/staff-attendance/check", ["markStaffAttendance"], validCheck);
  assertEquals(allowed?.status, 503);
});

Deno.test("staff-attendance: TCH-9 my-history is self-service — 403 without markStaffAttendance, 503 with it", async () => {
  const denied = await call("GET", "/staff-attendance/my-history", []);
  assertEquals(denied?.status, 403);
  const allowed = await call("GET", "/staff-attendance/my-history", ["markStaffAttendance"]);
  assertEquals(allowed?.status, 503);
});

Deno.test("staff-attendance: SLICE 4 manual-requests list — mine is self-service, the queue is approver-only", async () => {
  // mine=true: the universal staff gate (same as POST /check).
  const mineDenied = await call("GET", "/staff-attendance/manual-requests?mine=true", []);
  assertEquals(mineDenied?.status, 403);
  const mineAllowed = await call("GET", "/staff-attendance/manual-requests?mine=true", ["markStaffAttendance"]);
  assertEquals(mineAllowed?.status, 503); // authorized, DB-free

  // Default (the pending APPROVAL QUEUE): markStaffAttendance alone must NOT see
  // the school's queue — it needs the same supervisory permission that decides.
  const queueDenied = await call("GET", "/staff-attendance/manual-requests", ["markStaffAttendance"]);
  assertEquals(queueDenied?.status, 403);
  const queueAllowed = await call("GET", "/staff-attendance/manual-requests", ["approveStaffAttendance"]);
  assertEquals(queueAllowed?.status, 503);
});

Deno.test("staff-attendance: SLICE 4 manual-requests is GET-only (POST is the create route, singular)", async () => {
  const post = await call("POST", "/staff-attendance/manual-requests", ["approveStaffAttendance"], {});
  assertEquals(post?.status, 404);
});

Deno.test("staff-attendance: SHAPE 422 before DB — missing location, missing face, bad event_type", async () => {
  const noLoc = await call("POST", "/staff-attendance/check", ["markStaffAttendance"], {
    eventType: "check_in",
    face: { embedding: [0.1, 0.2], livenessPassed: true },
  });
  assertEquals(noLoc?.status, 422);
  assertEquals((await noLoc!.json()).error.code, "STAFF_ATTENDANCE_LOCATION_REQUIRED");

  const noFace = await call("POST", "/staff-attendance/check", ["markStaffAttendance"], {
    eventType: "check_in",
    location: validCheck.location,
  });
  assertEquals(noFace?.status, 422);
  assertEquals((await noFace!.json()).error.code, "STAFF_ATTENDANCE_FACE_REQUIRED");

  const badEvent = await call("POST", "/staff-attendance/check", ["markStaffAttendance"], {
    ...validCheck,
    eventType: "lunch_break",
  });
  assertEquals(badEvent?.status, 422);
  assertEquals((await badEvent!.json()).error.code, "STAFF_ATTENDANCE_INVALID_EVENT_TYPE");
});

Deno.test("staff-attendance: NO device-biometric field is accepted as proof (superseded model)", async () => {
  // A body carrying the OLD device-biometric assertion but no location/face is rejected
  // 422 on shape — biometricVerified is meaningless for attendance now.
  const legacy = await call("POST", "/staff-attendance/check", ["markStaffAttendance"], {
    eventType: "check_in",
    biometricVerified: true,
  });
  assertEquals(legacy?.status, 422);
});

Deno.test("staff-attendance: geofence-set + decide need the SUPERVISORY permission, not markStaffAttendance", async () => {
  // markStaffAttendance alone cannot configure the geofence...
  const noGeo = await call("PUT", "/staff-attendance/geofence", ["markStaffAttendance"], validGeofence);
  assertEquals(noGeo?.status, 403);
  // ...but manageSchoolGeofence can (503 DB-free).
  const geo = await call("PUT", "/staff-attendance/geofence", ["manageSchoolGeofence"], validGeofence);
  assertEquals(geo?.status, 503);

  // markStaffAttendance cannot approve a manual request...
  const noApprove = await call("POST", "/staff-attendance/manual-request/decide", ["markStaffAttendance"], {
    requestId: "r1", approve: true,
  });
  assertEquals(noApprove?.status, 403);
  // ...but approveStaffAttendance can (503 DB-free).
  const approve = await call("POST", "/staff-attendance/manual-request/decide", ["approveStaffAttendance"], {
    requestId: "r1", approve: true,
  });
  assertEquals(approve?.status, 503);
});

Deno.test("staff-attendance: manual request needs a reason (422) but is authorized with markStaffAttendance", async () => {
  const noReason = await call("POST", "/staff-attendance/manual-request", ["markStaffAttendance"], {
    eventType: "check_in", reason: "",
  });
  assertEquals(noReason?.status, 422);
  assertEquals((await noReason!.json()).error.code, "STAFF_ATTENDANCE_REASON_REQUIRED");
});

Deno.test("staff-attendance: audit catalog backs every event (staff_attendance module)", () => {
  const checkIn = staffAttendanceAudit.checkInRecorded("chk_1", "u1", "face_match");
  assertEquals(checkIn.audit.eventType, "staffCheckInRecorded");
  assertEquals(checkIn.domain.sourceModule, "staff_attendance");

  const enrolled = staffAttendanceAudit.faceEnrolled("face_1", "u1");
  assertEquals(enrolled.domain.eventType, "staff_attendance.face.enrolled");

  const geofence = staffAttendanceAudit.geofenceConfigured("school-1", 100);
  assertEquals(geofence.domain.sourceModule, "staff_attendance");

  const created = staffAttendanceAudit.manualRequestCreated("req_1", "u1", "check_in");
  assertEquals(created.domain.eventType, "staff_attendance.manual_request.created");

  const decided = staffAttendanceAudit.manualRequestDecided("req_1", "boss", "approved");
  assertEquals(decided.domain.eventType, "staff_attendance.manual_request.decided");
});
