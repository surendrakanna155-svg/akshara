// Staff Face ID attendance — ROUTE + RBAC + hard-block contract (DB-free).
//
// Proven without a live Postgres:
//   1. PATH-MATCH: POST /staff-attendance/check resolves to a handler; an
//      unregistered path under the prefix 404s; outside the prefix returns null.
//   2. RBAC: 401 unauthenticated; 403 without markStaffAttendance; 503 (authorized,
//      DB-free) with it + a valid body.
//   3. HARD-BLOCK enforced server-side: an authorized request whose body does NOT
//      assert biometric verification is rejected 422 BEFORE any DB work — there is
//      no PIN fallback. A bad event_type is likewise 422.
//   4. The audit catalog backs both events (staff_attendance source module).
//
// Live RLS row-isolation + the 200 happy-path = the Track-B remainder.

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
  return routeStaffAttendance(req, config, method, path);
}

const validBody = { eventType: "check_in", method: "face_id", biometricVerified: true };

Deno.test("staff-attendance: POST /staff-attendance/check path-matches a handler", async () => {
  const res = await call("POST", "/staff-attendance/check", ["markStaffAttendance"], validBody);
  assertEquals(res !== null, true);
  assertEquals(res!.status !== 404, true);
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
  const denied = await call("POST", "/staff-attendance/check", [], validBody);
  assertEquals(denied?.status, 403);
  assertEquals((await denied!.json()).error.code, "FORBIDDEN");
});

Deno.test("staff-attendance: 503 (authorized, DB-free) with markStaffAttendance + valid body", async () => {
  const allowed = await call("POST", "/staff-attendance/check", ["markStaffAttendance"], validBody);
  assertEquals(allowed?.status, 503);
});

Deno.test("staff-attendance: HARD-BLOCK — authorized request without biometric is 422 (no PIN fallback)", async () => {
  const noBio = await call("POST", "/staff-attendance/check", ["markStaffAttendance"], {
    eventType: "check_in",
    method: "face_id",
    // biometricVerified omitted
  });
  assertEquals(noBio?.status, 422);
  assertEquals((await noBio!.json()).error.code, "STAFF_ATTENDANCE_VALIDATION");

  const explicitlyFalse = await call("POST", "/staff-attendance/check", ["markStaffAttendance"], {
    eventType: "check_in",
    biometricVerified: false,
  });
  assertEquals(explicitlyFalse?.status, 422);
});

Deno.test("staff-attendance: invalid event_type is 422 before any DB work", async () => {
  const bad = await call("POST", "/staff-attendance/check", ["markStaffAttendance"], {
    eventType: "lunch_break",
    biometricVerified: true,
  });
  assertEquals(bad?.status, 422);
});

Deno.test("staff-attendance: audit catalog backs both events (staff_attendance module)", () => {
  const checkIn = staffAttendanceAudit.checkInRecorded("chk_1", "u1", "face_id");
  assertEquals(checkIn.audit.eventType, "staffCheckInRecorded");
  assertEquals(checkIn.domain.sourceModule, "staff_attendance");

  const checkOut = staffAttendanceAudit.checkOutRecorded("chk_2", "u1", "fingerprint");
  assertEquals(checkOut.audit.eventType, "staffCheckOutRecorded");
  assertEquals(checkOut.domain.sourceModule, "staff_attendance");
});
