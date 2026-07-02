// TCH-9 — "My Attendance" (P1): READ-ONLY staff self-service attendance history.
//
// Derives the Today / Yesterday / This-Month view from the append-only
// staff_check_ins ledger, REUSING the HR muster's day semantics
// (../hr/hr_reports_repository.ts) so the two views never disagree:
//   • UTC day/minute bucketing (matches how event_time is stored);
//   • late  = earliest check-in strictly after the late cutoff
//     (DEFAULT_LATE_AFTER 09:15 — the same shared constant HR-6 uses);
//   • absent = a working day with NO check-in (holidays from
//     school_calendar_events are excluded, mirroring inferMuster).
//
// SELF-SCOPING IS DOUBLE-ENFORCED:
//   1. every SQL read here binds user_id to the JWT subject — the caller can
//      NEVER address another user's rows (the parameter comes from claims.sub,
//      not from the request); and
//   2. RLS policy staff_check_ins_self_read (migration 20260841000000) pins
//      row visibility to app_current_user_id() as defense-in-depth.
//
// READ-ONLY: this module issues SELECTs only — no write path, no state change.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  DEFAULT_LATE_AFTER,
  daysInMonth,
  isoDateUtc,
  minutesOfDayUtc,
  parseHhMm,
} from "../hr/hr_reports_repository.ts";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** A single ledger event projected for the self-history. */
export interface MyHistoryEvent {
  eventType: string; // check_in | check_out
  eventTime: string; // ISO timestamp (UTC, as stored)
  method: string; // face_match | manual | ...
}

export type MyDayStatus = "present" | "late" | "absent" | "holiday";

export interface MyAttendanceDay {
  date: string; // yyyy-mm-dd
  checkIn: string | null; // earliest check_in of the day (ISO)
  checkOut: string | null; // latest check_out of the day (ISO)
  /** checkOut - checkIn in whole minutes; null without a completed pair. */
  workingMinutes: number | null;
  status: MyDayStatus;
  /** True when an APPROVED manual attendance request covers this day. */
  manualOverride: boolean;
}

export interface MyAttendanceSummary {
  /** On-time attended days (DISJOINT from lateDays; attended = present + late). */
  presentDays: number;
  lateDays: number;
  absentDays: number;
  /** Working days in the FULL month (days minus calendar holidays). */
  workingDaysInMonth: number;
  /** Mean of the completed-pair workingMinutes, rounded; null with no pairs. */
  avgWorkingMinutes: number | null;
}

export interface MyAttendanceHistory {
  month: string; // YYYY-MM
  days: MyAttendanceDay[];
  summary: MyAttendanceSummary;
  today: MyAttendanceDay | null;
  yesterday: MyAttendanceDay | null;
}

// ---------------------------------------------------------------------------
// Pure computation (unit-tested DB-free)
// ---------------------------------------------------------------------------

/**
 * Pure: builds the per-day self-history for one YYYY-MM from raw ledger events.
 *
 * Day semantics (mirrors the HR-6 muster):
 *   • checkIn  = earliest check_in of the UTC day; checkOut = latest check_out;
 *   • workingMinutes = checkOut - checkIn (null when either is missing or the
 *     pair is inverted — a data anomaly is surfaced as "no completed pair");
 *   • status: holiday when the (1-based) day number is in `holidayDays`;
 *     absent on a working day with no check_in (a lone check_out does NOT
 *     count as attended — same as inferMuster); late when the earliest
 *     check-in is strictly after `lateAfter` (default 09:15); else present.
 *   • manualOverride: an approved manual request covers the day — either the
 *     day is in `overrideDates` (approved staff_attendance_requests rows) or
 *     the day carries a ledger event with method='manual' (the row an approval
 *     materialises).
 *
 * `asOf` (yyyy-mm-dd, the caller's "today"): days AFTER asOf are omitted so a
 * current-month view never reports future days as absent. Summary counts are
 * over the emitted days; workingDaysInMonth is the full-month calendar fact.
 * today/yesterday are the asOf / asOf-1 entries, null when outside the month.
 */
export function buildMyAttendanceHistory(
  month: string,
  events: MyHistoryEvent[],
  options: {
    lateAfter?: string;
    holidayDays?: number[];
    overrideDates?: string[];
    asOf?: string;
  } = {},
): MyAttendanceHistory {
  const lateCutoff = parseHhMm(options.lateAfter ?? DEFAULT_LATE_AFTER) ?? (9 * 60 + 15);
  const holidaySet = new Set(options.holidayDays ?? []);
  const overrideSet = new Set(options.overrideDates ?? []);
  const asOf = options.asOf ?? "";
  const dim = daysInMonth(month);

  // Bucket the events per UTC date.
  const earliestIn = new Map<string, string>(); // date -> ISO of earliest check_in
  const latestOut = new Map<string, string>(); // date -> ISO of latest check_out
  const manualDates = new Set<string>(); // dates carrying a method='manual' event
  for (const ev of events) {
    const date = isoDateUtc(ev.eventTime);
    if (!date.startsWith(month + "-")) continue;
    const t = Date.parse(ev.eventTime);
    if (Number.isNaN(t)) continue;
    if (ev.method === "manual") manualDates.add(date);
    if (ev.eventType === "check_in") {
      const prev = earliestIn.get(date);
      if (prev === undefined || t < Date.parse(prev)) earliestIn.set(date, ev.eventTime);
    } else if (ev.eventType === "check_out") {
      const prev = latestOut.get(date);
      if (prev === undefined || t > Date.parse(prev)) latestOut.set(date, ev.eventTime);
    }
  }

  const days: MyAttendanceDay[] = [];
  let workingDaysInMonth = 0;
  let presentDays = 0;
  let lateDays = 0;
  let absentDays = 0;
  let minutesSum = 0;
  let minutesCount = 0;

  for (let day = 1; day <= dim; day++) {
    const date = `${month}-${String(day).padStart(2, "0")}`;
    const isHoliday = holidaySet.has(day);
    if (!isHoliday) workingDaysInMonth++;
    if (asOf !== "" && date > asOf) continue; // never report the future as absent

    const checkIn = earliestIn.get(date) ?? null;
    const checkOut = latestOut.get(date) ?? null;
    let workingMinutes: number | null = null;
    if (checkIn !== null && checkOut !== null) {
      const diff = Math.round((Date.parse(checkOut) - Date.parse(checkIn)) / 60_000);
      workingMinutes = diff >= 0 ? diff : null;
    }

    let status: MyDayStatus;
    if (isHoliday) {
      status = "holiday";
    } else if (checkIn === null) {
      status = "absent";
      absentDays++;
    } else if ((minutesOfDayUtc(checkIn) ?? 0) > lateCutoff) {
      status = "late";
      lateDays++;
    } else {
      status = "present";
      presentDays++;
    }
    if (status !== "holiday" && workingMinutes !== null) {
      minutesSum += workingMinutes;
      minutesCount++;
    }

    days.push({
      date,
      checkIn,
      checkOut,
      workingMinutes,
      status,
      manualOverride: overrideSet.has(date) || manualDates.has(date),
    });
  }

  const findDay = (date: string) => days.find((d) => d.date === date) ?? null;
  const yesterdayDate = asOf !== "" ? previousDate(asOf) : "";

  return {
    month,
    days,
    summary: {
      presentDays,
      lateDays,
      absentDays,
      workingDaysInMonth,
      avgWorkingMinutes: minutesCount > 0 ? Math.round(minutesSum / minutesCount) : null,
    },
    today: asOf !== "" ? findDay(asOf) : null,
    yesterday: yesterdayDate !== "" ? findDay(yesterdayDate) : null,
  };
}

/** yyyy-mm-dd of the day before (UTC); "" on a malformed date. */
function previousDate(date: string): string {
  const t = Date.parse(date + "T00:00:00Z");
  if (Number.isNaN(t)) return "";
  return new Date(t - 86_400_000).toISOString().slice(0, 10);
}

// ---------------------------------------------------------------------------
// DB reads — SELF-scoped: user_id is ALWAYS a bound parameter ($3) sourced
// from the JWT subject by the handler. SELECTs only.
// ---------------------------------------------------------------------------

/** Loads the caller's OWN ledger events for a YYYY-MM window. */
export async function loadMyCheckInEvents(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  month: string,
): Promise<MyHistoryEvent[]> {
  const rows = await db.queryObject<{
    event_type: string;
    event_time: string;
    method: string;
  }>(
    `SELECT event_type,
            to_char(event_time, 'YYYY-MM-DD"T"HH24:MI:SSOF') AS event_time,
            method
       FROM staff_check_ins
      WHERE organization_id = $1
        AND school_id = $2
        AND user_id = $3
        AND to_char(event_time, 'YYYY-MM') = $4
      ORDER BY event_time`,
    [organizationId, schoolId, userId, month],
  );
  return rows.map((r) => ({
    eventType: r.event_type,
    eventTime: r.event_time,
    method: r.method,
  }));
}

/**
 * Loads the yyyy-mm-dd days of the caller's OWN APPROVED manual attendance
 * requests in a YYYY-MM window. An approval materialises its manual ledger row
 * at decision time, so decided_at dates the day the override covers.
 */
export async function loadMyApprovedOverrideDates(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  userId: string,
  month: string,
): Promise<string[]> {
  const rows = await db.queryObject<{ day: string }>(
    `SELECT DISTINCT to_char(COALESCE(decided_at, created_at), 'YYYY-MM-DD') AS day
       FROM staff_attendance_requests
      WHERE organization_id = $1
        AND school_id = $2
        AND user_id = $3
        AND status = 'approved'
        AND to_char(COALESCE(decided_at, created_at), 'YYYY-MM') = $4`,
    [organizationId, schoolId, userId, month],
  );
  return rows.map((r) => r.day);
}
