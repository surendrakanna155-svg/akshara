// OFFICE / ADMIN student-attendance reads (ATT-1, ATT-2, ATT-4, ATT-D1, ATT-D2).
//
// All read-only. No attendance-write path is touched here. Every query is scoped
// to (organization_id, school_id) and only ever reads SUBMITTED sessions for the
// register/matrix/alerts (a draft is "not marked yet"). Student display name comes
// from `students.display_name`; roll/section come from the student's CURRENT
// enrollment when one exists, otherwise they are omitted (null).

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type AttendanceMarkCounts,
  attendancePercentFromCounts,
  attendancePercentSql,
  attendedDaysSql,
  attendedFromCounts,
} from "./attendance_percentage.ts";

// --- shared row shapes -------------------------------------------------------

export interface AttendanceRegisterRow {
  student_id: string;
  student_name: string;
  roll_number: string | null;
  class_label: string;
  mark: string;
}

export interface MonthlyStudentRow {
  student_id: string;
  student_name: string;
  roll_number: string | null;
  class_label: string;
  /** dayOfMonth (1..31) -> single-letter mark code: P/A/L/E (excused)/H (half_day). */
  marks: Record<number, string>;
  /** Attended days for the % (present + late + 0.5 × half_day) — CANONICAL, may be fractional. */
  present_days: number;
  marked_days: number;
  /** CANONICAL attendance % (attended / (marked − excused)); null when the denominator is 0. */
  percent_present: number | null;
}

export interface MonthlyRegister {
  class_label: string;
  month: string; // YYYY-MM
  day_count: number; // number of days in the month
  students: MonthlyStudentRow[];
}

export interface PendingClassRow {
  class_label: string;
  taken_by: string | null;
  teacher_name: string | null;
  status: string | null; // 'draft' when a draft exists, null when no session at all
  last_saved_at: string | null;
}

export interface ConsecutiveAbsenceRow {
  student_id: string;
  student_name: string;
  roll_number: string | null;
  class_label: string;
  consecutive_days: number;
  last_absent_date: string;
}

export interface ShortAttendanceRow {
  student_id: string;
  student_name: string;
  roll_number: string | null;
  class_label: string;
  /** Attended days for the % (present + late + 0.5 × half_day) — CANONICAL, may be fractional. */
  present_days: number;
  marked_days: number;
  percent_present: number;
}

// --- API mappers -------------------------------------------------------------

export function registerRowToApi(row: AttendanceRegisterRow): Record<string, unknown> {
  return {
    studentId: row.student_id,
    name: row.student_name,
    roll: row.roll_number,
    classLabel: row.class_label,
    mark: capitalizeMark(row.mark),
  };
}

export function monthlyRegisterToApi(register: MonthlyRegister): Record<string, unknown> {
  return {
    classLabel: register.class_label,
    month: register.month,
    dayCount: register.day_count,
    students: register.students.map((s) => ({
      studentId: s.student_id,
      name: s.student_name,
      roll: s.roll_number,
      classLabel: s.class_label,
      marks: s.marks,
      presentDays: s.present_days,
      markedDays: s.marked_days,
      percentPresent: s.percent_present,
    })),
  };
}

export function pendingClassRowToApi(row: PendingClassRow): Record<string, unknown> {
  return {
    classLabel: row.class_label,
    takenBy: row.taken_by,
    teacherName: row.teacher_name,
    status: row.status ?? "missing",
    lastSavedAt: row.last_saved_at,
  };
}

export function consecutiveAbsenceRowToApi(
  row: ConsecutiveAbsenceRow,
): Record<string, unknown> {
  return {
    studentId: row.student_id,
    name: row.student_name,
    roll: row.roll_number,
    classLabel: row.class_label,
    consecutiveDays: row.consecutive_days,
    lastAbsentDate: row.last_absent_date,
  };
}

export function shortAttendanceRowToApi(
  row: ShortAttendanceRow,
): Record<string, unknown> {
  return {
    studentId: row.student_id,
    name: row.student_name,
    roll: row.roll_number,
    classLabel: row.class_label,
    presentDays: row.present_days,
    markedDays: row.marked_days,
    percentPresent: row.percent_present,
  };
}

function capitalizeMark(mark: string): string {
  const value = mark.trim().toLowerCase();
  if (!value) return mark;
  return value.charAt(0).toUpperCase() + value.slice(1);
}

/** P/A/L/E/H code for a full mark string (unknown → '-'). */
function markCode(mark: string): string {
  switch (mark.trim().toLowerCase()) {
    case "present":
      return "P";
    case "absent":
      return "A";
    case "late":
      return "L";
    case "excused":
      return "E";
    case "half_day":
      return "H";
    default:
      return "-";
  }
}

// The current-enrollment roll/section join. LEFT JOIN so students without an
// enrollment row still appear (roll null). We can't assume the table exists in
// every tenant, but it is part of the SIS baseline; the LEFT JOIN degrades to
// null roll rather than failing when there is simply no matching enrollment row.
const CURRENT_ENROLLMENT_JOIN = `
  LEFT JOIN sis_student_enrollments se
    ON se.student_id = ar.student_id
   AND se.organization_id = ar.organization_id
   AND se.school_id = ar.school_id
   AND se.is_current = true`;

// --- ATT-1 register ----------------------------------------------------------

export async function getAttendanceRegister(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  classLabel: string,
  date: string,
): Promise<AttendanceRegisterRow[]> {
  return await db.queryObject<AttendanceRegisterRow>(
    `SELECT ar.student_id,
            COALESCE(s.display_name, '') AS student_name,
            se.roll_number,
            sess.class_label,
            ar.mark
     FROM attendance_records ar
     JOIN attendance_sessions sess ON sess.id = ar.session_id
     JOIN students s ON s.id = ar.student_id
     ${CURRENT_ENROLLMENT_JOIN}
     WHERE ar.organization_id = $1
       AND ar.school_id = $2
       AND sess.class_label = $3
       AND sess.session_date = $4::date
       AND sess.status = 'submitted'
     ORDER BY se.roll_number NULLS LAST, s.display_name`,
    [organizationId, schoolId, classLabel, date],
  );
}

// --- ATT-2 monthly register --------------------------------------------------

export async function getMonthlyRegister(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  classLabel: string,
  month: string, // YYYY-MM
): Promise<MonthlyRegister> {
  const monthStart = `${month}-01`;
  const rows = await db.queryObject<{
    student_id: string;
    student_name: string;
    roll_number: string | null;
    class_label: string;
    day_of_month: number;
    mark: string;
  }>(
    `SELECT ar.student_id,
            COALESCE(s.display_name, '') AS student_name,
            se.roll_number,
            sess.class_label,
            EXTRACT(DAY FROM sess.session_date)::int AS day_of_month,
            ar.mark
     FROM attendance_records ar
     JOIN attendance_sessions sess ON sess.id = ar.session_id
     JOIN students s ON s.id = ar.student_id
     ${CURRENT_ENROLLMENT_JOIN}
     WHERE ar.organization_id = $1
       AND ar.school_id = $2
       AND sess.class_label = $3
       AND sess.status = 'submitted'
       AND sess.session_date >= $4::date
       AND sess.session_date < ($4::date + INTERVAL '1 month')
     ORDER BY se.roll_number NULLS LAST, s.display_name, sess.session_date`,
    [organizationId, schoolId, classLabel, monthStart],
  );

  const dayCount = daysInMonth(month);
  const byStudent = new Map<string, MonthlyStudentRow>();
  // CANONICAL attendance-% (2026-07-09): per-student mark tallies, kept
  // alongside the display row so the % can be computed once via the shared
  // helper — see attendance_percentage.ts.
  const counts = new Map<string, AttendanceMarkCounts>();
  for (const r of rows) {
    let entry = byStudent.get(r.student_id);
    if (!entry) {
      entry = {
        student_id: r.student_id,
        student_name: r.student_name,
        roll_number: r.roll_number,
        class_label: r.class_label,
        marks: {},
        present_days: 0,
        marked_days: 0,
        percent_present: 0,
      };
      byStudent.set(r.student_id, entry);
      counts.set(r.student_id, { present: 0, late: 0, halfDay: 0, excused: 0, absent: 0 });
    }
    entry.marks[r.day_of_month] = markCode(r.mark);
    entry.marked_days += 1;
    const tally = counts.get(r.student_id)!;
    switch (r.mark.trim().toLowerCase()) {
      case "present":
        tally.present += 1;
        break;
      case "late":
        tally.late += 1;
        break;
      case "half_day":
        tally.halfDay += 1;
        break;
      case "excused":
        tally.excused += 1;
        break;
      case "absent":
        tally.absent += 1;
        break;
    }
  }

  const students = [...byStudent.values()].map((s) => {
    const tally = counts.get(s.student_id)!;
    return {
      ...s,
      present_days: attendedFromCounts(tally),
      percent_present: attendancePercentFromCounts(tally),
    };
  });

  return {
    class_label: classLabel,
    month,
    day_count: dayCount,
    students,
  };
}

function daysInMonth(month: string): number {
  const [y, m] = month.split("-").map((v) => Number(v));
  if (!y || !m) return 31;
  return new Date(Date.UTC(y, m, 0)).getUTCDate();
}

// --- ATT-4 pending (not-yet-marked) monitor ----------------------------------

export async function getPendingAttendance(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  date: string,
): Promise<PendingClassRow[]> {
  // A class is "pending" for a date when it has NO submitted session on that
  // date. We surface every distinct class_label that has ever had a session for
  // this school (so the office knows what classes exist), and flag those without
  // a submitted session on the target date. If a draft exists we show its
  // teacher + last-saved; if nothing exists at all, status = missing (null here).
  return await db.queryObject<PendingClassRow>(
    `WITH known_classes AS (
       SELECT DISTINCT class_label
       FROM attendance_sessions
       WHERE organization_id = $1 AND school_id = $2 AND class_label <> ''
     ),
     today_sessions AS (
       SELECT class_label, status, taken_by, updated_at
       FROM attendance_sessions
       WHERE organization_id = $1 AND school_id = $2
         AND session_date = $3::date
     ),
     submitted_today AS (
       SELECT DISTINCT class_label FROM today_sessions WHERE status = 'submitted'
     )
     SELECT kc.class_label,
            ts.taken_by::text AS taken_by,
            u.display_name AS teacher_name,
            ts.status,
            ts.updated_at::text AS last_saved_at
     FROM known_classes kc
     LEFT JOIN today_sessions ts ON ts.class_label = kc.class_label
     LEFT JOIN users u ON u.id = ts.taken_by
     WHERE kc.class_label NOT IN (SELECT class_label FROM submitted_today)
     ORDER BY kc.class_label`,
    [organizationId, schoolId, date],
  );
}

// --- ATT-D1 consecutive absence escalation -----------------------------------

export async function getConsecutiveAbsences(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  days: number,
): Promise<ConsecutiveAbsenceRow[]> {
  // The last N distinct SUBMITTED school days for this school. A student is
  // flagged when they are marked 'absent' on ALL of those days (and were marked
  // on all of them — a gap day breaks the streak). Excused is NOT absent.
  return await db.queryObject<ConsecutiveAbsenceRow>(
    `WITH school_days AS (
       SELECT DISTINCT sess.session_date
       FROM attendance_sessions sess
       WHERE sess.organization_id = $1 AND sess.school_id = $2
         AND sess.status = 'submitted'
       ORDER BY sess.session_date DESC
       LIMIT $3
     ),
     day_count AS (SELECT count(*)::int AS n FROM school_days),
     student_absences AS (
       SELECT ar.student_id,
              count(*) FILTER (WHERE ar.mark = 'absent')::int AS absent_days,
              count(*)::int AS marked_days,
              max(sess.session_date) FILTER (WHERE ar.mark = 'absent') AS last_absent_date
       FROM attendance_records ar
       JOIN attendance_sessions sess ON sess.id = ar.session_id
       WHERE ar.organization_id = $1 AND ar.school_id = $2
         AND sess.status = 'submitted'
         AND sess.session_date IN (SELECT session_date FROM school_days)
       GROUP BY ar.student_id
     )
     SELECT sa.student_id,
            COALESCE(s.display_name, '') AS student_name,
            se.roll_number,
            COALESCE(
              (SELECT sess2.class_label
               FROM attendance_records ar2
               JOIN attendance_sessions sess2 ON sess2.id = ar2.session_id
               WHERE ar2.organization_id = $1 AND ar2.school_id = $2
                 AND ar2.student_id = sa.student_id AND sess2.status = 'submitted'
               ORDER BY sess2.session_date DESC LIMIT 1),
              ''
            ) AS class_label,
            (SELECT n FROM day_count) AS consecutive_days,
            sa.last_absent_date::text AS last_absent_date
     FROM student_absences sa
     JOIN students s ON s.id = sa.student_id
     LEFT JOIN sis_student_enrollments se
       ON se.student_id = sa.student_id
      AND se.organization_id = $1 AND se.school_id = $2 AND se.is_current = true
     WHERE sa.absent_days = (SELECT n FROM day_count)
       AND sa.marked_days = (SELECT n FROM day_count)
       AND (SELECT n FROM day_count) >= $3
     ORDER BY s.display_name`,
    [organizationId, schoolId, days],
  );
}

// --- ATT-D2 short-attendance list --------------------------------------------

export async function getShortAttendance(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  threshold: number,
  windowDays: number,
): Promise<ShortAttendanceRow[]> {
  // CANONICAL attendance-% (2026-07-09, attendance_percentage.ts): attended =
  // present + late + 0.5×half_day; denominator = marked − excused. A student
  // whose denominator is 0 (nothing marked, or every marked day excused) has
  // NULL percent_present and is never flagged as "short" (there is nothing to
  // measure against).
  return await db.queryObject<ShortAttendanceRow>(
    `WITH school_days AS (
       SELECT DISTINCT sess.session_date
       FROM attendance_sessions sess
       WHERE sess.organization_id = $1 AND sess.school_id = $2
         AND sess.status = 'submitted'
       ORDER BY sess.session_date DESC
       LIMIT $4
     ),
     student_stats AS (
       SELECT ar.student_id,
              ${attendedDaysSql("ar.mark")}::float8 AS present_days,
              count(*)::int AS marked_days,
              ${attendancePercentSql("ar.mark")} AS percent_present
       FROM attendance_records ar
       JOIN attendance_sessions sess ON sess.id = ar.session_id
       WHERE ar.organization_id = $1 AND ar.school_id = $2
         AND sess.status = 'submitted'
         AND sess.session_date IN (SELECT session_date FROM school_days)
       GROUP BY ar.student_id
     )
     SELECT ss.student_id,
            COALESCE(s.display_name, '') AS student_name,
            se.roll_number,
            COALESCE(
              (SELECT sess2.class_label
               FROM attendance_records ar2
               JOIN attendance_sessions sess2 ON sess2.id = ar2.session_id
               WHERE ar2.organization_id = $1 AND ar2.school_id = $2
                 AND ar2.student_id = ss.student_id AND sess2.status = 'submitted'
               ORDER BY sess2.session_date DESC LIMIT 1),
              ''
            ) AS class_label,
            ss.present_days,
            ss.marked_days,
            ss.percent_present
     FROM student_stats ss
     JOIN students s ON s.id = ss.student_id
     LEFT JOIN sis_student_enrollments se
       ON se.student_id = ss.student_id
      AND se.organization_id = $1 AND se.school_id = $2 AND se.is_current = true
     WHERE ss.marked_days > 0
       AND ss.percent_present < $3
     ORDER BY percent_present ASC, s.display_name`,
    [organizationId, schoolId, threshold, windowDays],
  );
}
