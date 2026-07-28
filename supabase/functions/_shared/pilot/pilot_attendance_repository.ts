import type { TenantQueryClient } from "../tenant_db.ts";
import { attendancePercentFromCounts } from "../attendance/attendance_percentage.ts";
import {
  buildClassLabel,
  listCanonicalTeacherClasses,
} from "../school_completion/subject_assignments_repository.ts";
import { lookupClassTeacherPhone, parseClassLabel } from "./pilot_teacher_repository.ts";
import { listTeacherClassLabels } from "./pilot_operations_shared.ts";

export interface AttendanceMarkEntry {
  studentId: string;
  mark: string;
}

function countMarks(entries: AttendanceMarkEntry[]): {
  present: number;
  absent: number;
  late: number;
  excused: number;
  halfDay: number;
} {
  let present = 0;
  let absent = 0;
  let late = 0;
  let excused = 0;
  let halfDay = 0;
  for (const entry of entries) {
    if (entry.mark === "present") present += 1;
    else if (entry.mark === "absent") absent += 1;
    else if (entry.mark === "late") late += 1;
    else if (entry.mark === "excused") excused += 1;
    else if (entry.mark === "half_day") halfDay += 1;
  }
  return { present, absent, late, excused, halfDay };
}

/** Test-only re-export of the private countMarks (ATT-D3 counting assertions). */
export const countMarksForTest = countMarks;

/**
 * ATT-D3 Part B — pure auto-excuse override. Given the marking entries and the
 * set of student ids that have an APPROVED leave covering the attendance date,
 * return a NEW entries array where those students' marks are forced to
 * 'excused'. Kept pure (no DB) so it is unit-testable and so it can run BEFORE
 * the roster diff / inserts in upsertAttendanceSession WITHOUT touching the
 * integrity guards. Students already excused are unchanged; excused students
 * remain in the entries list (they stay on the roster).
 */
export function applyApprovedLeaveExcuse(
  entries: AttendanceMarkEntry[],
  approvedLeaveStudentIds: ReadonlySet<string>,
): AttendanceMarkEntry[] {
  if (approvedLeaveStudentIds.size === 0) return entries;
  return entries.map((entry) =>
    approvedLeaveStudentIds.has(entry.studentId) && entry.mark !== "excused"
      ? { ...entry, mark: "excused" }
      : entry
  );
}

/**
 * ATT-D3 Part B — the set of student ids with an APPROVED leave whose window
 * (from_date … to_date) covers TODAY. Legacy label-only leaves (from_date NULL)
 * are intentionally excluded — they have no machine-readable window so they
 * cannot auto-excuse. Scoped to the tenant/school under RLS.
 */
export async function approvedLeaveStudentIdsForToday(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Set<string>> {
  const rows = await db.queryObject<{ student_id: string }>(
    `SELECT DISTINCT student_id FROM mobile_leave_requests
      WHERE organization_id = $1 AND school_id = $2
        AND status = 'approved'
        AND student_id IS NOT NULL
        AND from_date IS NOT NULL AND to_date IS NOT NULL
        AND CURRENT_DATE BETWEEN from_date AND to_date`,
    [organizationId, schoolId],
  );
  return new Set(rows.map((r) => r.student_id));
}

// ── Attendance integrity guards (owner completion gates #1/#5/#6/#7/#8) ───────

/** #1 — a submitted session can only change through the correction workflow. */
export class AttendanceLockedError extends Error {
  constructor() {
    super("Submitted attendance is immutable — use the correction workflow");
    this.name = "AttendanceLockedError";
  }
}

/** #5 / #8 — marking is blocked on a holiday or after academic-year closure. */
export class AttendanceClosedDayError extends Error {
  constructor(reason: string) {
    super(reason);
    this.name = "AttendanceClosedDayError";
  }
}

/** #6 / #7 — the submitted set must exactly equal the active class roster. */
export class AttendanceRosterMismatchError extends Error {
  readonly missing: string[];
  readonly extra: string[];
  constructor(missing: string[], extra: string[]) {
    super(
      `Attendance roster mismatch: ${missing.length} enrolled student(s) not marked, ` +
        `${extra.length} marked student(s) not on the active roster`,
    );
    this.name = "AttendanceRosterMismatchError";
    this.missing = missing;
    this.extra = extra;
  }
}

/**
 * #5 (holiday) + #8 (year closure): reject marking for TODAY when the school
 * calendar has a holiday covering today, or the academic year that contains
 * today is archived (closed). Applies to draft AND submit.
 */
export async function assertAttendanceDayOpen(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<void> {
  const holiday = await db.queryObject<{ title: string }>(
    `SELECT title FROM school_calendar_events
      WHERE organization_id = $1 AND school_id = $2 AND event_type = 'holiday'
        AND CURRENT_DATE BETWEEN event_date AND COALESCE(end_date, event_date)
      LIMIT 1`,
    [organizationId, schoolId],
  );
  if (holiday[0]) {
    throw new AttendanceClosedDayError(
      `Attendance cannot be marked on a holiday (${holiday[0].title})`,
    );
  }
  const closed = await db.queryObject<{ year_label: string }>(
    `SELECT year_label FROM academic_years
      WHERE organization_id = $1 AND school_id = $2
        AND CURRENT_DATE BETWEEN start_date AND end_date
        AND status = 'archived'
      LIMIT 1`,
    [organizationId, schoolId],
  );
  if (closed[0]) {
    throw new AttendanceClosedDayError(
      `Academic year ${closed[0].year_label} is closed — attendance is locked`,
    );
  }
}

/**
 * #6 / #7 — the active roster for a class: current-year, is_current enrollments.
 * Withdrawn/transferred students (is_current=false) are excluded; newly admitted
 * students (is_current=true) are included; promotion moves the is_current row to
 * the new year. Matched on the several class-label conventions the client uses.
 */
export async function activeRosterStudentIds(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  classLabel: string,
): Promise<string[]> {
  const rows = await db.queryObject<{ student_id: string }>(
    `SELECT e.student_id FROM sis_student_enrollments e
       JOIN academic_years ay
         ON ay.organization_id = e.organization_id
        AND ay.school_id = e.school_id
        AND ay.year_label = e.academic_year
        AND ay.is_current = true
      WHERE e.organization_id = $1 AND e.school_id = $2 AND e.is_current = true
        AND (
          e.class_name = $3
          OR (e.class_name || '-' || COALESCE(e.section_name, '')) = $3
          OR (e.class_name || COALESCE(e.section_name, '')) = $3
        )`,
    [organizationId, schoolId, classLabel],
  );
  return rows.map((r) => r.student_id);
}

/** Pure roster reconciliation — `missing` = enrolled but unmarked, `extra` =
 * marked but not on the active roster (withdrawn/transferred/unknown). */
export function diffRoster(
  submitted: string[],
  roster: string[],
): { missing: string[]; extra: string[] } {
  const submittedSet = new Set(submitted);
  const rosterSet = new Set(roster);
  const missing = [...rosterSet].filter((id) => !submittedSet.has(id));
  const extra = [...submittedSet].filter((id) => !rosterSet.has(id));
  return { missing, extra };
}

export async function upsertAttendanceSession(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    classId: string;
    classLabel: string;
    takenBy: string;
    status: "draft" | "submitted";
    entries: AttendanceMarkEntry[];
    periodLabel?: string;
  },
): Promise<{ sessionId: string; counts: ReturnType<typeof countMarks> }> {
  const periodLabel = input.periodLabel ?? "";

  // #5 / #8 — holiday / year-closure block (draft and submit).
  await assertAttendanceDayOpen(db, input.organizationId, input.schoolId);

  // ATT-D3 Part B — auto-excuse: on SUBMIT, override the mark to 'excused' for
  // any student who has an APPROVED leave covering today. This is an ADDITIVE
  // step applied to the entry marks BEFORE the roster diff and before inserts,
  // so it does NOT weaken any integrity guard: excused students keep their
  // studentId (so #6/#7 roster reconciliation still passes), and #1/#5/#8 and
  // the unique-index insert are untouched below. Draft is left as-marked.
  let entries = input.entries;
  if (input.status === "submitted") {
    const excused = await approvedLeaveStudentIdsForToday(
      db,
      input.organizationId,
      input.schoolId,
    );
    entries = applyApprovedLeaveExcuse(entries, excused);
  }

  // #6 / #7 — on SUBMIT, the marked set must exactly match the active roster
  // (when the class resolves to current enrollments). Draft may be partial.
  if (input.status === "submitted") {
    const roster = await activeRosterStudentIds(
      db,
      input.organizationId,
      input.schoolId,
      input.classLabel,
    );
    if (roster.length > 0) {
      const { missing, extra } = diffRoster(
        entries.map((e) => e.studentId),
        roster,
      );
      if (missing.length > 0 || extra.length > 0) {
        throw new AttendanceRosterMismatchError(missing, extra);
      }
    }
  }

  // Session natural key is (school, class, date, period) — NOT the teacher, so a
  // class has ONE session/day/period regardless of who marks it (#3).
  const existing = await db.queryObject<{ id: string; status: string }>(
    `SELECT id, status FROM attendance_sessions
     WHERE organization_id = $1 AND school_id = $2 AND class_label = $3
       AND session_date = CURRENT_DATE AND period_label = $4
     LIMIT 1`,
    [input.organizationId, input.schoolId, input.classLabel, periodLabel],
  );

  // #1 — a submitted session is immutable via this path.
  if (existing[0] && existing[0].status === "submitted") {
    throw new AttendanceLockedError();
  }

  let sessionId: string;
  if (existing[0]) {
    sessionId = existing[0].id;
    await db.queryObject(
      `UPDATE attendance_sessions SET status = $2, taken_by = $3,
         submitted_at = CASE WHEN $2 = 'submitted' THEN timezone('utc', now()) ELSE submitted_at END,
         updated_at = timezone('utc', now())
       WHERE id = $1`,
      [sessionId, input.status, input.takenBy],
    );
    await db.queryObject(`DELETE FROM attendance_records WHERE session_id = $1`, [sessionId]);
  } else {
    // #2 / #3 — race-safe insert on the unique (org,school,class,date,period)
    // index. DO UPDATE ... WHERE status <> 'submitted' so a concurrent submit
    // that already locked the row is NOT overwritten (returns no row → locked).
    const rows = await db.queryObject<{ id: string }>(
      `INSERT INTO attendance_sessions (
         organization_id, school_id, class_label, period_label, taken_by, status, submitted_at
       ) VALUES ($1, $2, $3, $4, $5, $6,
         CASE WHEN $6 = 'submitted' THEN timezone('utc', now()) ELSE NULL END)
       ON CONFLICT (organization_id, school_id, class_label, session_date, period_label)
       DO UPDATE SET status = EXCLUDED.status, taken_by = EXCLUDED.taken_by,
         submitted_at = EXCLUDED.submitted_at, updated_at = timezone('utc', now())
       WHERE attendance_sessions.status <> 'submitted'
       RETURNING id`,
      [input.organizationId, input.schoolId, input.classLabel, periodLabel, input.takenBy, input.status],
    );
    if (!rows[0]) {
      // Conflict hit an already-submitted row → immutable.
      throw new AttendanceLockedError();
    }
    sessionId = rows[0].id;
    await db.queryObject(`DELETE FROM attendance_records WHERE session_id = $1`, [sessionId]);
  }

  for (const entry of entries) {
    await db.queryObject(
      `INSERT INTO attendance_records (
         session_id, organization_id, school_id, student_id, mark
       ) VALUES ($1, $2, $3, $4, $5)`,
      [sessionId, input.organizationId, input.schoolId, entry.studentId, entry.mark],
    );
  }

  return { sessionId, counts: countMarks(entries) };
}

// Map a stored mark to the parent/student calendar status (AttendanceDayStatus
// on the client). excused + half_day now render as their own distinct cells.
function markToStatus(mark: string): string {
  if (mark === "absent") return "absent";
  if (mark === "late") return "late";
  if (mark === "excused") return "excused";
  if (mark === "half_day") return "halfDay";
  return "present";
}

export async function overlayAttendanceSnapshotFromRecords(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
  snapshot: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ session_date: string; mark: string }>(
    `SELECT ar.mark, s.session_date::text AS session_date
     FROM attendance_records ar
     INNER JOIN attendance_sessions s ON s.id = ar.session_id
     WHERE ar.organization_id = $1 AND ar.school_id = $2 AND ar.student_id = $3
       AND s.status = 'submitted'
     ORDER BY s.session_date DESC
     LIMIT 31`,
    [orgId, schoolId, studentId],
  );

  const classLabel = String(snapshot.childClass ?? snapshot.classLabel ?? "");
  const classTeacherPhone = classLabel
    ? await lookupClassTeacherPhone(db, orgId, schoolId, classLabel)
    : null;

  if (rows.length === 0) {
    return classTeacherPhone ? { ...snapshot, classTeacherPhone } : snapshot;
  }

  let present = 0;
  let absent = 0;
  let late = 0;
  let halfDay = 0;
  let excused = 0;
  const recentLogs: Record<string, unknown>[] = [];
  for (const row of rows) {
    if (row.mark === "present") present += 1;
    else if (row.mark === "absent") absent += 1;
    else if (row.mark === "late") late += 1;
    else if (row.mark === "half_day") halfDay += 1;
    else if (row.mark === "excused") excused += 1;
    const date = row.session_date.slice(0, 10);
    recentLogs.push({
      date,
      status: markToStatus(row.mark),
      detail: row.mark === "absent"
        ? "Marked absent"
        : row.mark === "excused"
        ? "Excused"
        : row.mark === "half_day"
        ? "Half day"
        : "Marked present",
      detailTitle: date,
      detailBody: `Attendance: ${row.mark}`,
    });
  }

  // CANONICAL attendance-% (2026-07-09, attendance_percentage.ts): attended =
  // present + late + 0.5×half_day; denominator = marked − excused. NULL (not
  // 0) when the denominator is 0 — nothing to compute a rate from.
  const attendancePercent = attendancePercentFromCounts({
    present,
    late,
    halfDay,
    excused,
    absent,
  });
  const kpi = {
    attendancePercent,
    absentDays: absent,
    lateDays: late,
  };

  return {
    ...snapshot,
    kpi,
    recentLogs,
    ...(classTeacherPhone ? { classTeacherPhone } : {}),
  };
}

// Map a stored attendance mark to the client-facing status string. Wire values
// mirror the DB marks so the Flutter StudentAttendanceMark codec round-trips:
// present/absent/late/excused/half_day. Anything unknown falls back to present.
function markToAttendanceStatus(mark: string): string {
  if (mark === "absent") return "absent";
  if (mark === "late") return "late";
  if (mark === "excused") return "excused";
  if (mark === "half_day") return "half_day";
  return "present";
}

// --- TEACH-1: attendance class list (GET /teacher/attendance/classes) ---
//
// The class picker that feeds the roster. Computed from the teacher's real
// timetable classes so its `id` (class_<label>) matches the studentsByClass
// keys the roster returns. studentCount = current enrolled students; isPending
// = no submitted attendance session for this class today. Empty => [].
export async function listTeacherAttendanceClasses(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
  pagination: { page: number; pageSize: number },
): Promise<{
  items: Array<Record<string, unknown>>;
  page: number;
  pageSize: number;
  total: number;
  hasMore: boolean;
}> {
  // PRA-P0-07 / P1-31 (S3): the class list comes from the CANONICAL binding —
  // one row per class the teacher is bound to, NOT one per weekly timetable slot.
  // This repairs the picker for real tenants (timetable_slots is unwritten) AND
  // fixes P1-31: the old query exploded the teacher's whole weekly timetable, so
  // every class/period showed as "pending today"; now each class appears once and
  // `isPending` is the real "no submitted session today" signal.
  const canonical = await listCanonicalTeacherClasses(db, orgId, schoolId, teacherUserId);
  const labels = canonical.map((c) => buildClassLabel(c.class_name, c.section_name));
  if (labels.length === 0) {
    return {
      items: [],
      page: pagination.page,
      pageSize: pagination.pageSize,
      total: 0,
      hasMore: false,
    };
  }

  const rows = await db.queryObject<{
    class_label: string;
    marked: boolean;
    student_count: number;
  }>(
    `SELECT cl.class_label,
            EXISTS (
              SELECT 1 FROM attendance_sessions ses
               WHERE ses.organization_id = $1 AND ses.school_id = $2
                 AND ses.class_label = cl.class_label
                 AND ses.session_date = CURRENT_DATE
                 AND ses.status = 'submitted'
            ) AS marked,
            (
              SELECT count(*)::int FROM sis_student_enrollments e2
               WHERE e2.organization_id = $1 AND e2.school_id = $2
                 AND e2.is_current = true
                 AND (e2.class_name || '-' || e2.section_name) = cl.class_label
            ) AS student_count
       FROM unnest($3::text[]) AS cl(class_label)
      ORDER BY cl.class_label`,
    [orgId, schoolId, labels],
  );

  const all = rows.map((r) => ({
    id: `class_${r.class_label}`,
    label: r.class_label,
    // subject/periodLabel are not part of the daily-class-attendance model; kept
    // in the shape (empty) so existing clients ignore them without breaking.
    subject: "",
    periodLabel: "",
    studentCount: r.student_count,
    isPending: !r.marked,
  }));
  const total = all.length;
  const start = Math.max(0, (pagination.page - 1) * pagination.pageSize);
  const items = all.slice(start, start + pagination.pageSize);
  return {
    items,
    page: pagination.page,
    pageSize: pagination.pageSize,
    total,
    hasMore: start + items.length < total,
  };
}

// --- TEACH-1: attendance roster (GET /teacher/attendance/students) ---
//
// Builds the `studentsByClass` map the client expects: for each class the
// teacher teaches, the real enrolled students (from sis_student_enrollments)
// keyed by the seed class id ("class_<label>"), each carrying the latest
// submitted attendance mark for today (else 'unmarked'). The summary + labels
// reflect the first class. Empty school => studentsByClass:{} and zeroed
// summary, never the seed fiction.
export async function overlayTeacherAttendanceStudents(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
  snapshot: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const classLabels = await listTeacherClassLabels(db, orgId, schoolId, teacherUserId);
  if (classLabels.length === 0) {
    return {
      ...snapshot,
      classLabel: "",
      studentsByClass: {},
      students: [],
      summary: { present: 0, absent: 0, late: 0 },
    };
  }

  const studentsByClass: Record<string, Record<string, unknown>[]> = {};
  let firstClassPresent = 0;
  let firstClassAbsent = 0;
  let firstClassLate = 0;

  for (let i = 0; i < classLabels.length; i += 1) {
    const classLabel = classLabels[i]!;
    const { className, sectionName } = parseClassLabel(classLabel);
    // Real enrolled students for this class, with today's submitted mark (if any).
    const rows = await db.queryObject<{
      id: string;
      name: string;
      roll_no: string | null;
      mark: string | null;
    }>(
      `SELECT s.id::text AS id,
              s.display_name AS name,
              e.roll_number AS roll_no,
              ar.mark AS mark
         FROM students s
         INNER JOIN sis_student_enrollments e
           ON e.student_id = s.id
          AND e.organization_id = s.organization_id
          AND e.school_id = s.school_id
          AND e.is_current = true
         LEFT JOIN attendance_sessions ses
           ON ses.organization_id = s.organization_id
          AND ses.school_id = s.school_id
          AND ses.class_label = $3
          AND ses.session_date = CURRENT_DATE
          AND ses.status = 'submitted'
         LEFT JOIN attendance_records ar
           ON ar.session_id = ses.id
          AND ar.student_id = s.id
        WHERE s.organization_id = $1 AND s.school_id = $2 AND s.status = 'active'
          AND e.class_name = $4
          AND ($5::text IS NULL OR e.section_name = $5)
        ORDER BY e.roll_number NULLS LAST, s.display_name`,
      [orgId, schoolId, classLabel, className, sectionName],
    );

    const classId = `class_${classLabel}`;
    studentsByClass[classId] = rows.map((row) => ({
      id: row.id,
      name: row.name,
      rollNo: row.roll_no ?? "",
      mark: row.mark ? markToAttendanceStatus(row.mark) : "unmarked",
    }));

    if (i === 0) {
      for (const row of rows) {
        if (!row.mark) continue;
        const status = markToAttendanceStatus(row.mark);
        if (status === "present") firstClassPresent += 1;
        else if (status === "absent") firstClassAbsent += 1;
        else if (status === "late") firstClassLate += 1;
      }
    }
  }

  const firstClassLabel = classLabels[0]!;
  return {
    ...snapshot,
    classLabel: firstClassLabel,
    studentsByClass,
    students: studentsByClass[`class_${firstClassLabel}`] ?? [],
    summary: {
      present: firstClassPresent,
      absent: firstClassAbsent,
      late: firstClassLate,
    },
  };
}
