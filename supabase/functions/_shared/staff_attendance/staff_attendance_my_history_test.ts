// TCH-9 — "My Attendance" self-service history (DB-free).
//
// Proven without a live Postgres:
//   (a) ROUTE CONTRACT: 401 unauthenticated; 403 without markStaffAttendance;
//       503 (authorized, DB-free) with it; 400 on a malformed ?month BEFORE any
//       DB work; the default month (no param) also reaches the DB seam.
//   (b) PURE MATH: day pairing (earliest in / latest out), working minutes,
//       late (> 09:15 cutoff, shared with the HR muster), absent, holiday,
//       future-day truncation, summary counts, today/yesterday extraction.
//   (c) SELF-BINDING: every SQL read binds user_id to the caller ($3) and is
//       SELECT-only — captured with a fake client. The caller can never read
//       another user's rows (defense-in-depth over staff_check_ins_self_read).
//   (d) MANUAL OVERRIDE: flagged from an approved-request date AND from a
//       method='manual' ledger event.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { signAccessToken } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { routeStaffAttendance } from "./staff_attendance_router.ts";
import {
  buildMyAttendanceHistory,
  loadMyApprovedOverrideDates,
  loadMyCheckInEvents,
  type MyHistoryEvent,
} from "./staff_attendance_my_history.ts";

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

async function get(path: string, perms: string[]): Promise<Response | null> {
  const token = await signAccessToken(SECRET, claims(perms), 900);
  const req = new Request(`https://x${path}`, {
    method: "GET",
    headers: { authorization: `Bearer ${token}` },
  });
  return routeStaffAttendance(req, config, "GET", path.split("?")[0]!);
}

// ── (a) route contract ───────────────────────────────────────────────────────

Deno.test("my-history: unauthenticated is 401", async () => {
  const req = new Request("https://x/staff-attendance/my-history", { method: "GET" });
  const res = await routeStaffAttendance(req, config, "GET", "/staff-attendance/my-history");
  assertEquals(res?.status, 401);
});

Deno.test("my-history: 403 without markStaffAttendance (parents/students never read the ledger)", async () => {
  const res = await get("/staff-attendance/my-history", []);
  assertEquals(res?.status, 403);
  assertEquals((await res!.json()).error.code, "FORBIDDEN");
});

Deno.test("my-history: 503 (authorized, DB-free) with markStaffAttendance — explicit and default month", async () => {
  const explicit = await get("/staff-attendance/my-history?month=2026-06", ["markStaffAttendance"]);
  assertEquals(explicit?.status, 503);
  assertEquals((await explicit!.json()).error.code, "TENANT_DB_NOT_CONFIGURED");
  // No ?month → defaults to the current month and still reaches the DB seam.
  const defaulted = await get("/staff-attendance/my-history", ["markStaffAttendance"]);
  assertEquals(defaulted?.status, 503);
});

Deno.test("my-history: malformed month is 400 BEFORE any DB work", async () => {
  for (const bad of ["2026-13", "202606", "junk", "2026-6"]) {
    const res = await get(`/staff-attendance/my-history?month=${bad}`, ["markStaffAttendance"]);
    assertEquals(res?.status, 400, `month=${bad} should 400`);
    assertEquals((await res!.json()).error.code, "BAD_REQUEST");
  }
});

// ── (b) pure day-pairing / late / absent / working-minutes math ──────────────

function ev(eventType: string, eventTime: string, method = "face_match"): MyHistoryEvent {
  return { eventType, eventTime, method };
}

Deno.test("my-history math: pairs earliest check-in with latest check-out and computes minutes", () => {
  const out = buildMyAttendanceHistory("2026-06", [
    ev("check_in", "2026-06-10T09:05:00Z"),
    ev("check_in", "2026-06-10T08:55:00Z"), // earliest wins
    ev("check_out", "2026-06-10T13:00:00Z"),
    ev("check_out", "2026-06-10T17:25:00Z"), // latest wins
  ], { asOf: "2026-06-10" });
  const day = out.days.find((d) => d.date === "2026-06-10")!;
  assertEquals(day.checkIn, "2026-06-10T08:55:00Z");
  assertEquals(day.checkOut, "2026-06-10T17:25:00Z");
  assertEquals(day.workingMinutes, 510); // 08:55 -> 17:25
  assertEquals(day.status, "present"); // 08:55 <= 09:15
  assertEquals(day.manualOverride, false);
});

Deno.test("my-history math: late is strictly after the 09:15 shared cutoff", () => {
  const out = buildMyAttendanceHistory("2026-06", [
    ev("check_in", "2026-06-01T09:15:00Z"), // exactly 09:15 -> present (same as muster)
    ev("check_in", "2026-06-02T09:16:00Z"), // 09:16 -> late
  ], { asOf: "2026-06-02" });
  assertEquals(out.days[0]!.status, "present");
  assertEquals(out.days[1]!.status, "late");
  assertEquals(out.summary.presentDays, 1);
  assertEquals(out.summary.lateDays, 1);
});

Deno.test("my-history math: lateAfter override changes the cutoff", () => {
  const out = buildMyAttendanceHistory("2026-06", [
    ev("check_in", "2026-06-01T09:16:00Z"),
  ], { asOf: "2026-06-01", lateAfter: "09:30" });
  assertEquals(out.days[0]!.status, "present");
});

Deno.test("my-history math: no check-out -> workingMinutes null; lone check-out day stays absent", () => {
  const out = buildMyAttendanceHistory("2026-06", [
    ev("check_in", "2026-06-01T09:00:00Z"), // no checkout
    ev("check_out", "2026-06-02T17:00:00Z"), // no check-in -> absent (muster semantics)
  ], { asOf: "2026-06-02" });
  assertEquals(out.days[0]!.workingMinutes, null);
  assertEquals(out.days[0]!.status, "present");
  assertEquals(out.days[1]!.status, "absent");
  assertEquals(out.days[1]!.checkOut, "2026-06-02T17:00:00Z");
  assertEquals(out.days[1]!.workingMinutes, null);
});

Deno.test("my-history math: inverted pair (check-out before check-in) yields null minutes", () => {
  const out = buildMyAttendanceHistory("2026-06", [
    ev("check_in", "2026-06-01T17:00:00Z"),
    ev("check_out", "2026-06-01T09:00:00Z"),
  ], { asOf: "2026-06-01" });
  assertEquals(out.days[0]!.workingMinutes, null);
});

Deno.test("my-history math: holidays excluded from working days and never absent", () => {
  const out = buildMyAttendanceHistory("2026-06", [], {
    asOf: "2026-06-03",
    holidayDays: [2],
  });
  assertEquals(out.days.length, 3);
  assertEquals(out.days[1]!.status, "holiday");
  assertEquals(out.summary.absentDays, 2); // days 1 and 3 only
  assertEquals(out.summary.workingDaysInMonth, 29); // 30 - 1 holiday, FULL month
});

Deno.test("my-history math: future days are omitted, never reported absent", () => {
  const out = buildMyAttendanceHistory("2026-06", [
    ev("check_in", "2026-06-09T09:00:00Z"),
    ev("check_out", "2026-06-09T17:00:00Z"),
  ], { asOf: "2026-06-10" });
  assertEquals(out.days.length, 10); // 1..10 only, not 30
  assertEquals(out.summary.absentDays, 9);
  assertEquals(out.summary.presentDays, 1);
  assertEquals(out.summary.avgWorkingMinutes, 480);
});

Deno.test("my-history math: summary averages only completed pairs; empty month -> null", () => {
  const out = buildMyAttendanceHistory("2026-06", [
    ev("check_in", "2026-06-01T09:00:00Z"),
    ev("check_out", "2026-06-01T17:00:00Z"), // 480
    ev("check_in", "2026-06-02T09:00:00Z"),
    ev("check_out", "2026-06-02T16:00:00Z"), // 420
    ev("check_in", "2026-06-03T09:00:00Z"), // no checkout -> excluded from avg
  ], { asOf: "2026-06-03" });
  assertEquals(out.summary.avgWorkingMinutes, 450);

  const empty = buildMyAttendanceHistory("2026-06", [], { asOf: "2026-06-01" });
  assertEquals(empty.summary.avgWorkingMinutes, null);
});

Deno.test("my-history math: today/yesterday extracted; yesterday null at month start; past month -> both null", () => {
  const out = buildMyAttendanceHistory("2026-06", [
    ev("check_in", "2026-06-10T09:00:00Z"),
  ], { asOf: "2026-06-10" });
  assertEquals(out.today?.date, "2026-06-10");
  assertEquals(out.today?.status, "present");
  assertEquals(out.yesterday?.date, "2026-06-09");
  assertEquals(out.yesterday?.status, "absent");

  const monthStart = buildMyAttendanceHistory("2026-06", [], { asOf: "2026-06-01" });
  assertEquals(monthStart.today?.date, "2026-06-01");
  assertEquals(monthStart.yesterday, null); // 2026-05-31 is outside the month

  const pastMonth = buildMyAttendanceHistory("2026-05", [], { asOf: "2026-06-10" });
  assertEquals(pastMonth.days.length, 31); // full past month
  assertEquals(pastMonth.today, null);
  assertEquals(pastMonth.yesterday, null);
});

Deno.test("my-history math: events outside the month are ignored", () => {
  const out = buildMyAttendanceHistory("2026-06", [
    ev("check_in", "2026-05-31T09:00:00Z"),
    ev("check_in", "2026-07-01T09:00:00Z"),
  ], { asOf: "2026-06-01" });
  assertEquals(out.days[0]!.status, "absent");
});

// ── (c) SQL always binds user_id to the caller ───────────────────────────────

function fakeDb(rows: unknown[] = []) {
  const calls: Array<{ sql: string; args: unknown[] }> = [];
  const db = {
    queryObject: (sql: string, args: unknown[] = []) => {
      calls.push({ sql, args });
      return Promise.resolve(rows);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

Deno.test("my-history reads: ledger query binds user_id=$3 to the caller and is SELECT-only", async () => {
  const { db, calls } = fakeDb();
  await loadMyCheckInEvents(db, "org-1", "school-1", "caller-sub", "2026-06");
  assertEquals(calls.length, 1);
  const { sql, args } = calls[0]!;
  assert(/user_id = \$3/.test(sql), "ledger SQL must pin user_id to $3");
  assertEquals(args[2], "caller-sub");
  assertEquals(args, ["org-1", "school-1", "caller-sub", "2026-06"]);
  assert(/^\s*SELECT/i.test(sql) && !/INSERT|UPDATE|DELETE/i.test(sql), "read-only");
});

Deno.test("my-history reads: overrides query binds user_id=$3, status='approved', SELECT-only", async () => {
  const { db, calls } = fakeDb();
  await loadMyApprovedOverrideDates(db, "org-1", "school-1", "caller-sub", "2026-06");
  assertEquals(calls.length, 1);
  const { sql, args } = calls[0]!;
  assert(/user_id = \$3/.test(sql), "overrides SQL must pin user_id to $3");
  assertEquals(args[2], "caller-sub");
  assert(/status = 'approved'/.test(sql), "only APPROVED requests override");
  assert(/^\s*SELECT/i.test(sql) && !/INSERT|UPDATE|DELETE/i.test(sql), "read-only");
});

// ── (d) manual-override flag ─────────────────────────────────────────────────

Deno.test("my-history: manualOverride from an approved-request date AND a manual ledger event", () => {
  const out = buildMyAttendanceHistory("2026-06", [
    ev("check_in", "2026-06-01T09:00:00Z"), // normal face-match day
    ev("check_in", "2026-06-02T09:00:00Z", "manual"), // approval-materialised row
  ], {
    asOf: "2026-06-03",
    overrideDates: ["2026-06-03"], // approved request covering day 3
  });
  assertEquals(out.days[0]!.manualOverride, false);
  assertEquals(out.days[1]!.manualOverride, true); // via method='manual'
  assertEquals(out.days[2]!.manualOverride, true); // via approved-request date
  assertEquals(out.days[1]!.status, "present"); // an override still counts as attended
});
