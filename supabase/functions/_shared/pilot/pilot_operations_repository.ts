import type { TenantQueryClient } from "../tenant_db.ts";
import { attendancePercentFromCounts } from "../attendance/attendance_percentage.ts";

export const ATTENDANCE_SESSION_PROBE_SQL = `
  SELECT count(*)::text AS count FROM attendance_sessions WHERE id = $1::uuid
`;

export const ATTENDANCE_SESSION_PROBE_SCHOOL_A = "d3000000-0000-4000-8000-000000000001";
export const ATTENDANCE_SESSION_PROBE_SCHOOL_B = "d3000000-0000-4000-8000-000000000002";
export const ATTENDANCE_SESSION_PROBE_DETAIL_SQL = ATTENDANCE_SESSION_PROBE_SQL;

export const TIMETABLE_SLOT_PROBE_SCHOOL_A = "d4000000-0000-4000-8000-000000000001";
export const TIMETABLE_SLOT_PROBE_SCHOOL_B = "d4000000-0000-4000-8000-000000000002";
export const TIMETABLE_SLOT_PROBE_DETAIL_SQL = `
  SELECT count(*)::text AS count FROM timetable_slots WHERE id = $1::uuid
`;

export const MOBILE_LEAVE_PROBE_SCHOOL_A = "d5000000-0000-4000-8000-000000000001";
export const MOBILE_LEAVE_PROBE_SCHOOL_B = "d5000000-0000-4000-8000-000000000002";
export const MOBILE_LEAVE_PROBE_DETAIL_SQL = `
  SELECT count(*)::text AS count FROM mobile_leave_requests WHERE id = $1::uuid
`;

export const HOMEWORK_SUBMISSION_PROBE_SCHOOL_A = "d6000000-0000-4000-8000-000000000001";
export const HOMEWORK_SUBMISSION_PROBE_SCHOOL_B = "d6000000-0000-4000-8000-000000000002";
export const HOMEWORK_SUBMISSION_PROBE_DETAIL_SQL = `
  SELECT count(*)::text AS count FROM homework_submissions WHERE id = $1::uuid
`;

export const EXAM_MARK_PROBE_SCHOOL_A = "mark_probe_a";
export const EXAM_MARK_PROBE_SCHOOL_B = "mark_probe_b";
export const EXAM_MARK_PROBE_DETAIL_SQL = `
  SELECT count(*)::text AS count FROM exam_mark_entries WHERE id = $1
`;

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

export async function listGuardianUserIdsForStudent(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
): Promise<string[]> {
  const rows = await db.queryObject<{ guardian_user_id: string }>(
    `SELECT guardian_user_id FROM student_guardians
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3 AND status = 'active'`,
    [orgId, schoolId, studentId],
  );
  return rows.map((row) => row.guardian_user_id);
}

export async function createLeaveRequest(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    requesterUserId: string;
    requesterScope: "parent" | "teacher";
    studentId: string | null;
    typeLabel: string;
    fromDateLabel: string;
    toDateLabel: string;
    // ATT-D3 Part B — optional machine-readable ISO (YYYY-MM-DD) bounds. When
    // provided on a leave that is later APPROVED, they let the auto-excuse fire.
    // Omitted → legacy label-only leave (never auto-excuses).
    fromDate?: string | null;
    toDate?: string | null;
    reason: string;
    hasAttachment?: boolean;
    attachmentName?: string | null;
  },
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO mobile_leave_requests (
       organization_id, school_id, requester_user_id, requester_scope,
       student_id, type_label, from_date_label, to_date_label, reason,
       has_attachment, attachment_name, from_date, to_date
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12::date,$13::date)
     RETURNING id`,
    [
      input.organizationId,
      input.schoolId,
      input.requesterUserId,
      input.requesterScope,
      input.studentId,
      input.typeLabel,
      input.fromDateLabel,
      input.toDateLabel,
      input.reason,
      input.hasAttachment ?? false,
      input.attachmentName ?? null,
      input.fromDate ?? null,
      input.toDate ?? null,
    ],
  );
  const id = rows[0]!.id;
  return leaveToApi(id, input);
}

function leaveToApi(id: string, input: {
  typeLabel: string;
  fromDateLabel: string;
  toDateLabel: string;
  reason: string;
  hasAttachment?: boolean;
  attachmentName?: string | null;
  requesterScope: "parent" | "teacher";
}): Record<string, unknown> {
  return {
    id,
    childName: input.requesterScope === "parent" ? "Linked child" : "",
    childClass: input.requesterScope === "parent" ? "8-A" : "",
    type: input.typeLabel,
    typeLabel: input.typeLabel,
    fromDateLabel: input.fromDateLabel,
    toDateLabel: input.toDateLabel,
    reason: input.reason,
    status: "pending",
    submittedLabel: "Just now",
    timeline: [{ label: "Submitted", timeLabel: "Just now", isComplete: true }],
    hasAttachment: input.hasAttachment ?? false,
    attachmentName: input.attachmentName ?? null,
  };
}

/**
 * MJ-H12 — list a parent's leave applications for GET /parent/leave.
 *
 * POST /parent/leave persists into `mobile_leave_requests` (the canonical store
 * the school/HR approval + intelligence side reads). The parent's leave history
 * screen, however, read the `parent_entities` "leave_request" cache, so a parent
 * never saw the leave they just submitted. This reads the real rows back for the
 * resolved child, mapped to the same shape `leaveToApi` returns so the existing
 * parent_mapper.toLeaveRequest parser consumes it unchanged. Paginated in-memory
 * (a parent has few leave rows). Newest first.
 */
export async function listParentLeaveRequests(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  pagination: { page: number; pageSize: number },
): Promise<{
  items: Array<Record<string, unknown>>;
  page: number;
  pageSize: number;
  total: number;
  hasMore: boolean;
}> {
  const rows = await db.queryObject<{
    id: string;
    type_label: string;
    from_date_label: string;
    to_date_label: string;
    reason: string;
    status: string;
    has_attachment: boolean;
    attachment_name: string | null;
    submitted_label: string;
  }>(
    `SELECT id, type_label, from_date_label, to_date_label, reason, status,
            has_attachment, attachment_name,
            to_char(created_at, 'DD Mon YYYY') AS submitted_label
       FROM mobile_leave_requests
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3::uuid
      ORDER BY created_at DESC`,
    [organizationId, schoolId, studentId],
  );
  const all = rows.map((r) => ({
    id: r.id,
    // Convention mirrors leaveToApi (the POST response): this list is already
    // scoped to the active child, so a placeholder label is honest, not faked
    // identity. The parent app shows the child from its own active-child context.
    childName: "Linked child",
    childClass: "",
    type: r.type_label,
    typeLabel: r.type_label,
    fromDateLabel: r.from_date_label,
    toDateLabel: r.to_date_label,
    reason: r.reason,
    status: r.status,
    submittedLabel: r.submitted_label,
    timeline: [{ label: "Submitted", timeLabel: r.submitted_label, isComplete: true }],
    hasAttachment: r.has_attachment,
    attachmentName: r.attachment_name,
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

// ── PAR-D1 / PAR-3 — parent leave mutations (cancel + attachment) ────────────

/**
 * PAR-D1 — a leave the parent tried to cancel does not exist for them, or is no
 * longer pending. Both surface distinctly to the handler: NOT_FOUND (the id is
 * not one of this parent's own-child pending leaves) vs a non-pending status
 * (already decided → immutable, mirroring the leave-decision-immutability rule).
 */
export class ParentLeaveNotFoundError extends Error {
  constructor(leaveId: string) {
    super(`Leave request not found: ${leaveId}`);
    this.name = "ParentLeaveNotFoundError";
  }
}

/** PAR-D1 — the leave exists but is already approved/rejected/cancelled. */
export class ParentLeaveNotPendingError extends Error {
  readonly status: string;
  constructor(status: string) {
    super(
      `Leave request is '${status}' and can no longer be cancelled — only a pending request may be withdrawn`,
    );
    this.name = "ParentLeaveNotPendingError";
    this.status = status;
  }
}

/**
 * Load a leave request that MUST belong to this parent and one of their own
 * children. Ownership is enforced two ways (defence in depth):
 *   1. `requester_user_id = requesterUserId` — the RLS parent policy already
 *      restricts a parent to leaves they themselves submitted, but we re-assert
 *      it here so the guard holds even under a service-role/test client.
 *   2. `student_id = ANY(childIds)` — the caller's JWT `child_ids` (the own-child
 *      choke point). A leave for a child no longer linked to this parent is
 *      treated as not-found, never mutated.
 * Returns null when no such row exists (→ NOT_FOUND, no cross-family leak).
 */
async function loadOwnChildLeave(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  requesterUserId: string,
  childIds: string[],
  leaveId: string,
): Promise<{ id: string; student_id: string | null; status: string } | null> {
  if (childIds.length === 0) return null;
  const rows = await db.queryObject<
    { id: string; student_id: string | null; status: string }
  >(
    `SELECT id, student_id, status
       FROM mobile_leave_requests
      WHERE organization_id = $1 AND school_id = $2
        AND id = $3::uuid
        AND requester_scope = 'parent'
        AND requester_user_id = $4::uuid
        AND student_id = ANY($5::uuid[])
      LIMIT 1`,
    [organizationId, schoolId, leaveId, requesterUserId, childIds],
  );
  return rows[0] ?? null;
}

/**
 * PAR-D1 — withdraw a PENDING leave the parent submitted for their own child.
 * Own-child scoped (see {@link loadOwnChildLeave}) and pending-only: an already
 * approved/rejected/cancelled request is immutable (→ 409), mirroring the
 * leave-decision-immutability rule. Flips status to 'cancelled' and returns the
 * canonical row so the parent's leave history (GET /parent/leave) reflects it.
 */
export async function cancelParentLeaveRequest(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    requesterUserId: string;
    childIds: string[];
    leaveId: string;
  },
): Promise<{ id: string; studentId: string | null; status: string }> {
  const existing = await loadOwnChildLeave(
    db,
    input.organizationId,
    input.schoolId,
    input.requesterUserId,
    input.childIds,
    input.leaveId,
  );
  if (!existing) {
    throw new ParentLeaveNotFoundError(input.leaveId);
  }
  if (existing.status !== "pending") {
    throw new ParentLeaveNotPendingError(existing.status);
  }
  // Conditional UPDATE (WHERE status = 'pending') closes the race with a
  // concurrent school-side approval: if the row was decided between the load and
  // the write, no row is returned and we treat it as no-longer-pending (409).
  const rows = await db.queryObject<{ id: string; student_id: string | null }>(
    `UPDATE mobile_leave_requests
        SET status = 'cancelled', updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2
        AND id = $3::uuid
        AND requester_user_id = $4::uuid
        AND status = 'pending'
      RETURNING id, student_id`,
    [input.organizationId, input.schoolId, input.leaveId, input.requesterUserId],
  );
  const updated = rows[0];
  if (!updated) {
    // Lost the race — the row was decided concurrently; still immutable.
    throw new ParentLeaveNotPendingError("approved");
  }
  return { id: updated.id, studentId: updated.student_id, status: "cancelled" };
}

/**
 * PAR-3 — attach a medical certificate reference to a leave the parent submitted
 * for their own child. Own-child scoped (see {@link loadOwnChildLeave}). Follows
 * the HWK-7 "attachment reference, real upload pending storage" pattern: the
 * reference (storage path / file name) is persisted on the existing
 * `has_attachment` + `attachment_name` columns so GET /parent/leave surfaces it;
 * wiring a real parent-leave storage bucket is the residual. Allowed while the
 * leave is still pending — an already-decided leave is immutable (→ 409), the
 * same rule as cancel. A parent can NEVER attach to another child's leave.
 */
export async function attachParentLeaveDocument(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    requesterUserId: string;
    childIds: string[];
    leaveId: string;
    attachmentName: string;
    storagePath: string | null;
  },
): Promise<{ id: string; studentId: string | null; attachmentName: string }> {
  const existing = await loadOwnChildLeave(
    db,
    input.organizationId,
    input.schoolId,
    input.requesterUserId,
    input.childIds,
    input.leaveId,
  );
  if (!existing) {
    throw new ParentLeaveNotFoundError(input.leaveId);
  }
  if (existing.status !== "pending") {
    throw new ParentLeaveNotPendingError(existing.status);
  }
  const rows = await db.queryObject<{ id: string; student_id: string | null }>(
    `UPDATE mobile_leave_requests
        SET has_attachment = true,
            attachment_name = $5,
            updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2
        AND id = $3::uuid
        AND requester_user_id = $4::uuid
        AND status = 'pending'
      RETURNING id, student_id`,
    [
      input.organizationId,
      input.schoolId,
      input.leaveId,
      input.requesterUserId,
      input.attachmentName,
    ],
  );
  const updated = rows[0];
  if (!updated) {
    throw new ParentLeaveNotPendingError("approved");
  }
  return {
    id: updated.id,
    studentId: updated.student_id,
    attachmentName: input.attachmentName,
  };
}

// ── Homework submission integrity guards (security hardening) ────────────────

/**
 * Cross-class scope guard: a student may only submit against an assignment that
 * was actually DELIVERED to them (a `homework_item` entity exists for this
 * student_id + homework_id). Without this a student could POST a homework_id
 * belonging to another class/student and get a row written for their own
 * student_id — a horizontal privilege leak on the shared `homework_id` space.
 */
export class HomeworkNotDeliveredError extends Error {
  constructor() {
    super("Homework assignment was not delivered to this student");
    this.name = "HomeworkNotDeliveredError";
  }
}

/**
 * A student has already submitted this assignment. Surfaced as 409 instead of a
 * silent overwrite (previously ON CONFLICT DO UPDATE) or a raw 500 unique
 * violation — a re-submit is an explicit conflict the client must handle.
 */
export class HomeworkAlreadySubmittedError extends Error {
  constructor() {
    super("Homework has already been submitted");
    this.name = "HomeworkAlreadySubmittedError";
  }
}

// Postgres unique_violation SQLSTATE.
const PG_UNIQUE_VIOLATION = "23505";

function isUniqueViolation(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const code = (error as { code?: unknown; fields?: { code?: unknown } }).code ??
    (error as { fields?: { code?: unknown } }).fields?.code;
  return code === PG_UNIQUE_VIOLATION;
}

export async function submitHomework(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    studentId: string;
    homeworkId: string;
    notes: string;
    attachmentLabel?: string | null;
  },
): Promise<Record<string, unknown>> {
  // Cross-class scope: the assignment must have been delivered to THIS student.
  // A student can only see/submit their own delivered `homework_item` entities
  // (student_entities RLS scopes reads to the student), so a missing row means
  // the homework_id was never assigned to them — reject rather than persist a
  // submission against another class's assignment.
  const delivered = await db.queryObject<{ id: string }>(
    `SELECT id FROM student_entities
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3::uuid
       AND entity_type = 'homework_item' AND id = $4
     LIMIT 1`,
    [input.organizationId, input.schoolId, input.studentId, input.homeworkId],
  );
  if (!delivered[0]) {
    throw new HomeworkNotDeliveredError();
  }

  // Plain INSERT (no ON CONFLICT): a duplicate submission raises the unique
  // violation on idx_homework_submissions_student_hw, which we map to a 409.
  try {
    await db.queryObject<{ id: string }>(
      `INSERT INTO homework_submissions (
         organization_id, school_id, student_id, homework_id, notes, attachment_label
       ) VALUES ($1,$2,$3,$4,$5,$6)
       RETURNING id`,
      [
        input.organizationId,
        input.schoolId,
        input.studentId,
        input.homeworkId,
        input.notes,
        input.attachmentLabel ?? null,
      ],
    );
  } catch (error) {
    if (isUniqueViolation(error)) {
      throw new HomeworkAlreadySubmittedError();
    }
    throw error;
  }
  return {
    id: input.homeworkId,
    homeworkId: input.homeworkId,
    title: "Homework submission",
    subjectLabel: "General",
    dueLabel: "Submitted",
    status: "submitted",
    submittedLabel: "Just now",
  };
}

export async function reviewHomework(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  submissionId: string,
  input: { grade: string; comment: string; reviewerId: string },
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{
    id: string;
    homework_id: string;
    student_id: string;
  }>(
    // Match by the submission's own id (cast to text so the single $1 param is
    // unambiguously text — comparing a uuid column to a text-bound param via
    // `id = $1::uuid` made the driver infer $1 as uuid, which then broke the
    // `homework_id = $1` text comparison with "operator does not exist: text =
    // uuid"). The review route always passes a real homework_submissions.id now
    // (MJ-C2), but we keep the homework_id fallback for safety.
    `UPDATE homework_submissions
     SET status = 'reviewed', grade = $2, comment = $3, reviewed_by = $4,
         updated_at = timezone('utc', now())
     WHERE id::text = $1 OR homework_id = $1
     RETURNING id, homework_id, student_id`,
    [submissionId, input.grade, input.comment, input.reviewerId],
  );
  const row = rows[0];

  // MJ-H7: push the grade/status back onto the student's own `homework_item`
  // entity so a reviewed assignment reflects as 'reviewed' (with grade +
  // teacher comment) in the student app. Without this the student keeps seeing
  // 'pending'. jsonb merge (||) preserves the item's other fields.
  if (row?.homework_id && row?.student_id) {
    await db.queryObject(
      `UPDATE student_entities
       SET payload = payload || jsonb_build_object(
             'status', 'reviewed',
             'reviewGrade', $4::text,
             'reviewComment', $5::text
           )
       WHERE organization_id = $1 AND school_id = $2
         AND entity_type = 'homework_item'
         AND id = $3 AND student_id = $6::uuid`,
      [orgId, schoolId, row.homework_id, input.grade, input.comment, row.student_id],
    );
  }

  // Resolve the real student display name for the review result so the teacher
  // sees who they just graded instead of a placeholder.
  let studentName = "Student";
  if (row?.student_id) {
    const nameRows = await db.queryObject<{ display_name: string }>(
      `SELECT display_name FROM students
       WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid LIMIT 1`,
      [orgId, schoolId, row.student_id],
    );
    if (nameRows[0]?.display_name) studentName = nameRows[0].display_name;
  }

  return {
    // `matched` (additive, non-breaking) tells callers whether an actual row was
    // updated — HWK-6 bulk review relies on this to count reviewed vs skipped,
    // since the `submission` shape below always reports status 'reviewed' even on
    // a miss (it echoes the requested id for a stable client shape).
    matched: row != null,
    submission: {
      id: row?.id ?? submissionId,
      studentName,
      classLabel: "",
      title: row?.homework_id ?? "Homework",
      submittedLabel: "Reviewed",
      status: "reviewed",
      grade: input.grade,
      comment: input.comment,
    },
  };
}

export async function updateExamMark(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  markEntryId: string,
  marksObtained: number,
  updatedBy: string,
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{
    id: string;
    exam_id: string;
    exam_title: string;
    class_label: string;
    marks_obtained: number;
    max_marks: number;
    student_id: string;
  }>(
    `UPDATE exam_mark_entries
     SET marks_obtained = $4, marks_entered = true, updated_by = $5, updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND id = $3
       AND published = false
     RETURNING *`,
    [orgId, schoolId, markEntryId, marksObtained, updatedBy],
  );
  const row = rows[0];
  if (!row) {
    // Enforce the SAME published-immutability as the academics path: a published
    // mark changes only via the correction workflow. Distinguish a published
    // (locked) row from a genuinely missing one for a precise error.
    const existing = await db.queryObject<{ published: boolean }>(
      `SELECT published FROM exam_mark_entries
       WHERE organization_id = $1 AND school_id = $2 AND id = $3`,
      [orgId, schoolId, markEntryId],
    );
    if (existing[0]?.published) {
      throw new Error(`Exam mark is published and immutable: ${markEntryId}`);
    }
    throw new Error(`Exam mark entry not found: ${markEntryId}`);
  }
  return {
    id: row.id,
    examId: row.exam_id,
    title: row.exam_title,
    classLabel: row.class_label,
    marksObtained: row.marks_obtained,
    maxMarks: row.max_marks,
    studentId: row.student_id,
  };
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

export async function lookupClassTeacherPhone(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  classLabel: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ phone: string }>(
    `SELECT u.phone
     FROM timetable_slots ts
     INNER JOIN users u ON u.id = COALESCE(ts.substitute_teacher_user_id, ts.teacher_user_id)
     WHERE ts.organization_id = $1 AND ts.school_id = $2 AND ts.class_label = $3
     LIMIT 1`,
    [orgId, schoolId, classLabel],
  );
  return rows[0]?.phone ?? null;
}

export async function lookupGuardianPhoneForStudent(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ phone: string }>(
    `SELECT u.phone
     FROM student_guardians sg
     INNER JOIN users u ON u.id = sg.guardian_user_id
     WHERE sg.organization_id = $1 AND sg.school_id = $2 AND sg.student_id = $3
       AND sg.status = 'active' AND sg.is_primary = true
     LIMIT 1`,
    [orgId, schoolId, studentId],
  );
  return rows[0]?.phone ?? null;
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

const TIMETABLE_DAY_META = [
  { id: "mon", shortLabel: "Mon", fullLabel: "Monday", dayOfWeek: 1 },
  { id: "tue", shortLabel: "Tue", fullLabel: "Tuesday", dayOfWeek: 2 },
  { id: "wed", shortLabel: "Wed", fullLabel: "Wednesday", dayOfWeek: 3 },
  { id: "thu", shortLabel: "Thu", fullLabel: "Thursday", dayOfWeek: 4 },
  { id: "fri", shortLabel: "Fri", fullLabel: "Friday", dayOfWeek: 5 },
  { id: "sat", shortLabel: "Sat", fullLabel: "Saturday", dayOfWeek: 6 },
  { id: "sun", shortLabel: "Sun", fullLabel: "Sunday", dayOfWeek: 7 },
] as const;

function periodTimeRange(periodNumber: number): string {
  const startHour = 7 + periodNumber;
  const endHour = startHour + 1;
  const pad = (value: number) => String(value).padStart(2, "0");
  return `${pad(startHour)}:30 - ${pad(endHour)}:15`;
}

function mondayOfCurrentWeek(reference = new Date()): Date {
  const date = new Date(Date.UTC(reference.getUTCFullYear(), reference.getUTCMonth(), reference.getUTCDate()));
  const weekday = date.getUTCDay() === 0 ? 7 : date.getUTCDay();
  date.setUTCDate(date.getUTCDate() - (weekday - 1));
  return date;
}

function formatIsoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function weekRangeLabel(reference = new Date()): string {
  const monday = mondayOfCurrentWeek(reference);
  const friday = new Date(monday);
  friday.setUTCDate(friday.getUTCDate() + 4);
  const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return `${monday.getUTCDate()}–${friday.getUTCDate()} ${monthNames[friday.getUTCMonth()]}`;
}

export type TimetableViewScope = "parent" | "student" | "teacher";

async function loadTimetableSlotRows(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  filter: { classLabel?: string; teacherUserId?: string },
): Promise<Array<{
  day_of_week: number;
  period_number: number;
  subject_label: string;
  room_label: string | null;
  class_label: string;
  substitute_teacher_user_id: string | null;
  teacher_name: string | null;
}>> {
  return await db.queryObject<{
    day_of_week: number;
    period_number: number;
    subject_label: string;
    room_label: string | null;
    class_label: string;
    substitute_teacher_user_id: string | null;
    teacher_name: string | null;
  }>(
    `SELECT ts.day_of_week, ts.period_number, ts.subject_label, ts.room_label, ts.class_label,
            ts.substitute_teacher_user_id, u.display_name AS teacher_name
     FROM timetable_slots ts
     LEFT JOIN users u ON u.id = COALESCE(ts.substitute_teacher_user_id, ts.teacher_user_id)
     WHERE ts.organization_id = $1 AND ts.school_id = $2
       AND ($3::text IS NULL OR ts.class_label = $3)
       AND (
         $4::uuid IS NULL
         OR ts.teacher_user_id = $4
         OR ts.substitute_teacher_user_id = $4
       )
     ORDER BY ts.day_of_week, ts.period_number`,
    [orgId, schoolId, filter.classLabel ?? null, filter.teacherUserId ?? null],
  );
}

export async function overlayTimetableSnapshotFromSlots(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  snapshot: Record<string, unknown>,
  options: {
    view: TimetableViewScope;
    classLabel?: string;
    teacherUserId?: string;
  },
): Promise<Record<string, unknown>> {
  const classLabel = options.classLabel ??
    String(snapshot.childClass ?? snapshot.classLabel ?? "");
  const rows = await loadTimetableSlotRows(db, orgId, schoolId, {
    classLabel: options.view === "teacher" ? undefined : (classLabel || undefined),
    teacherUserId: options.view === "teacher" ? options.teacherUserId : undefined,
  });

  if (rows.length === 0) {
    return snapshot;
  }

  const todayIso = formatIsoDate(new Date());
  const monday = mondayOfCurrentWeek();
  const slotsByDay = new Map<number, typeof rows>();
  for (const row of rows) {
    const bucket = slotsByDay.get(row.day_of_week) ?? [];
    bucket.push(row);
    slotsByDay.set(row.day_of_week, bucket);
  }

  const days: Record<string, unknown>[] = [];
  let totalPeriods = 0;
  let completedToday = 0;
  let upcomingToday = 0;

  for (const meta of TIMETABLE_DAY_META) {
    const daySlots = slotsByDay.get(meta.dayOfWeek) ?? [];
    if (daySlots.length === 0) continue;

    const dayDate = new Date(monday);
    dayDate.setUTCDate(dayDate.getUTCDate() + (meta.dayOfWeek - 1));
    const dateIso = formatIsoDate(dayDate);
    const isToday = dateIso === todayIso;

    const periods: Record<string, unknown>[] = [];
    for (const slot of daySlots) {
      totalPeriods += 1;
      const status = "upcoming";
      if (isToday) upcomingToday += 1;

      const basePeriod = {
        id: `${meta.id}-p${slot.period_number}`,
        periodLabel: `Period ${slot.period_number}`,
        timeRange: periodTimeRange(slot.period_number),
        subject: slot.subject_label,
        roomLabel: slot.room_label ?? "",
        status,
      };

      periods.push(
        options.view === "teacher"
          ? { ...basePeriod, classLabel: slot.class_label }
          : {
            ...basePeriod,
            teacherName: slot.teacher_name ?? "Teacher",
            isRoomChanged: slot.substitute_teacher_user_id != null,
          },
      );
    }

    days.push({
      id: meta.id,
      shortLabel: meta.shortLabel,
      fullLabel: meta.fullLabel,
      date: dateIso,
      isSelected: isToday,
      isToday,
      periods,
    });
  }

  const merged: Record<string, unknown> = {
    ...snapshot,
    weekRangeLabel: weekRangeLabel(),
    days,
  };

  if (options.view !== "teacher") {
    merged.totalPeriodsThisWeek = totalPeriods;
    merged.completedPeriodsToday = completedToday;
    merged.upcomingPeriodsToday = upcomingToday;
  }

  return merged;
}

export interface ParentSnapshotContext {
  childName: string;
  childClass: string;
}

export async function loadStudentParentSnapshotContext(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
): Promise<ParentSnapshotContext> {
  const rows = await db.queryObject<{
    display_name: string;
    class_name: string | null;
    section_name: string | null;
  }>(
    `SELECT s.display_name, e.class_name, e.section_name
     FROM students s
     LEFT JOIN sis_student_enrollments e
       ON e.student_id = s.id
      AND e.organization_id = s.organization_id
      AND e.school_id = s.school_id
      AND e.is_current = true
     WHERE s.organization_id = $1 AND s.school_id = $2 AND s.id = $3
     LIMIT 1`,
    [orgId, schoolId, studentId],
  );
  const row = rows[0];
  if (!row) {
    return { childName: "Student", childClass: "" };
  }
  const className = row.class_name ?? "";
  const sectionName = row.section_name ?? "";
  const childClass = className
    ? sectionName
      ? `${className}-${sectionName}`
      : className
    : "";
  return { childName: row.display_name, childClass };
}

export function buildDefaultParentSnapshot(
  entityType: string,
  context: ParentSnapshotContext,
): Record<string, unknown> {
  const base = {
    childName: context.childName,
    childClass: context.childClass,
    unreadNotifications: 0,
  };
  switch (entityType) {
    case "snapshot_attendance":
      return {
        ...base,
        month: new Date().toISOString().slice(0, 7),
        kpi: { attendancePercent: 0, absentDays: 0, lateDays: 0 },
        calendarDays: [],
        recentLogs: [],
      };
    case "snapshot_timetable":
      return {
        ...base,
        weekRangeLabel: weekRangeLabel(),
        totalPeriodsThisWeek: 0,
        completedPeriodsToday: 0,
        upcomingPeriodsToday: 0,
        days: [],
      };
    case "snapshot_fees":
      return {
        ...base,
        summaryLabel: "Fees",
        totalDue: 0,
        installments: [],
      };
    default:
      return base;
  }
}

// ─── P0-1 — student-scope default-snapshot fallback ──────────────────────────
//
// The student app must NOT 404 for a real student who has no seeded
// `student_entities` row (only the 2-UUID demo seed carries one). Mirrors the
// parent fallback (loadStudentParentSnapshotContext / buildDefaultParentSnapshot
// above): build a default from real `students` + `sis_student_enrollments`
// rows, shaped to the EXACT keys `lib/core/repositories/api/student/mapper/
// student_mapper.dart` reads (verified against that file) — this also fixes the
// pre-existing seed-contract mismatch (seed shipped `rollNumber`/`guardianName`,
// the client reads `rollNo`; seed never carried `attendanceKpi`/`homeworkDue`/
// `examReminder`/`todaySchedule`/`quickActions`/`admissionNo`/`dateOfBirth`/
// `bloodGroup`/`parentContacts`/`academicSummary` at all).
//
// KNOWN LIMITATION (out of this fix's file-ownership — entity_read/pilot only):
// `student_profiles` and `student_guardians` currently carry NO student-scope
// RLS read policy (only 'school' / 'parent' branches — see
// 20260613000000_sis_slice0_foundation.sql and 20260609100000_phase2_rls_scope.sql).
// The queries below are written to pick these fields up correctly the moment
// that follow-up RLS grant lands; until then `admissionNo`/`dateOfBirth`/
// `bloodGroup`/`parentContacts` gracefully read back empty (evidenced-missing,
// not fabricated) rather than erroring — `students` + `sis_student_enrollments`
// already grant student-scope self-read (20260703100000_parent_student_exam_read_rls.sql),
// so `studentName`/`classLabel`/`rollNo` DO populate for a real student today.

export interface StudentSnapshotContext {
  studentName: string;
  classLabel: string;
  rollNo: string;
  admissionNo: string;
  dateOfBirth: string;
  bloodGroup: string;
  schoolName: string;
  parentContacts: Array<
    { name: string; relation: string; phoneLabel: string; email: string }
  >;
}

export async function loadStudentSnapshotContext(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
): Promise<StudentSnapshotContext> {
  const rows = await db.queryObject<{
    display_name: string;
    class_name: string | null;
    section_name: string | null;
    roll_number: string | null;
    admission_number: string | null;
    date_of_birth: string | null;
    blood_group: string | null;
  }>(
    `SELECT s.display_name,
            e.class_name, e.section_name, e.roll_number,
            sp.admission_number,
            sp.date_of_birth::text AS date_of_birth,
            sp.blood_group
     FROM students s
     LEFT JOIN sis_student_enrollments e
       ON e.student_id = s.id
      AND e.organization_id = s.organization_id
      AND e.school_id = s.school_id
      AND e.is_current = true
     LEFT JOIN student_profiles sp
       ON sp.student_id = s.id
      AND sp.organization_id = s.organization_id
      AND sp.school_id = s.school_id
     WHERE s.organization_id = $1 AND s.school_id = $2 AND s.id = $3
     LIMIT 1`,
    [orgId, schoolId, studentId],
  );

  const schoolRows = await db.queryObject<{ name: string }>(
    `SELECT name FROM schools WHERE id = $1 LIMIT 1`,
    [schoolId],
  );
  const schoolName = schoolRows[0]?.name ?? "Akshara Public School";

  const guardianRows = await db.queryObject<{
    name: string;
    relation: string;
    phone: string | null;
    email: string | null;
  }>(
    `SELECT u.display_name AS name, sg.relationship AS relation, u.phone, u.email
     FROM student_guardians sg
     JOIN users u ON u.id = sg.guardian_user_id
     WHERE sg.organization_id = $1 AND sg.school_id = $2 AND sg.student_id = $3
       AND sg.status = 'active'
     ORDER BY sg.is_primary DESC`,
    [orgId, schoolId, studentId],
  );
  const parentContacts = guardianRows.map((g) => ({
    name: g.name,
    relation: g.relation,
    phoneLabel: g.phone ?? "",
    email: g.email ?? "",
  }));

  const row = rows[0];
  if (!row) {
    return {
      studentName: "Student",
      classLabel: "",
      rollNo: "",
      admissionNo: "",
      dateOfBirth: "",
      bloodGroup: "",
      schoolName,
      parentContacts,
    };
  }
  const className = row.class_name ?? "";
  const sectionName = row.section_name ?? "";
  const classLabel = className
    ? sectionName
      ? `${className}-${sectionName}`
      : className
    : "";
  return {
    studentName: row.display_name,
    classLabel,
    rollNo: row.roll_number ?? "",
    admissionNo: row.admission_number ?? "",
    dateOfBirth: row.date_of_birth ?? "",
    bloodGroup: row.blood_group ?? "",
    schoolName,
    parentContacts,
  };
}

export function buildDefaultStudentSnapshot(
  entityType: string,
  context: StudentSnapshotContext,
): Record<string, unknown> {
  const base = {
    studentName: context.studentName,
    classLabel: context.classLabel,
    // Mirrors the parent/attendance/timetable overlay naming convention
    // (childName/childClass) so overlayAttendanceSnapshotFromRecords /
    // overlayTimetableSnapshotFromSlots — which read `childClass ?? classLabel`
    // — resolve the real class label either way.
    childName: context.studentName,
    childClass: context.classLabel,
    unreadNotifications: 0,
  };
  switch (entityType) {
    case "snapshot_dashboard":
      return {
        ...base,
        greetingHeadline: context.studentName
          ? `Welcome, ${context.studentName}`
          : "Welcome",
        greetingSubtitle: "",
        todaySchedule: [],
        attendanceKpi: {
          label: "Attendance",
          value: "--",
          detail: "No attendance recorded yet",
          tone: "neutral",
        },
        homeworkDue: [],
        examReminder: { id: "", title: "", subject: "", dateLabel: "", daysUntil: 0 },
        quickActions: [],
        aiInsight: { message: "", actionLabel: "" },
      };
    case "snapshot_attendance":
      return {
        ...base,
        month: new Date().toISOString().slice(0, 7),
        kpi: { attendancePercent: 0, absentDays: 0, lateDays: 0 },
        calendarDays: [],
        recentLogs: [],
      };
    case "snapshot_exams":
      return {
        ...base,
        averagePercent: 0,
        upcomingExams: [],
        examResults: [],
        subjectScores: [],
      };
    case "snapshot_timetable":
      return {
        ...base,
        weekRangeLabel: weekRangeLabel(),
        totalPeriodsThisWeek: 0,
        completedPeriodsToday: 0,
        upcomingPeriodsToday: 0,
        days: [],
      };
    case "snapshot_profile":
      return {
        ...base,
        rollNo: context.rollNo,
        admissionNo: context.admissionNo,
        dateOfBirth: context.dateOfBirth,
        bloodGroup: context.bloodGroup,
        schoolName: context.schoolName,
        parentContacts: context.parentContacts,
        academicSummary: [],
      };
    default:
      return base;
  }
}

export async function overlayFeesSnapshotFromFinance(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
  snapshot: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{
    id: string;
    outstanding_amount: string;
    invoice_status: string;
    due_date: string;
  }>(
    `SELECT id, outstanding_amount, invoice_status, due_date::text AS due_date
     FROM finance_invoices
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3
       AND invoice_status NOT IN ('cancelled', 'draft')
     ORDER BY due_date ASC
     LIMIT 12`,
    [orgId, schoolId, studentId],
  );
  // Correct child identity from real records (seed snapshot may be stale), mirroring
  // the exam/receipt overlays so the parent never sees another child's name.
  let childName = snapshot.childName;
  let childClass = snapshot.childClass;
  try {
    const context = await loadStudentParentSnapshotContext(db, orgId, schoolId, studentId);
    if (context.childName) childName = context.childName;
    if (context.childClass) childClass = context.childClass;
  } catch {
    // keep snapshot identity on any lookup failure
  }

  if (rows.length === 0) {
    return { ...snapshot, childName, childClass };
  }

  const installments = rows.map((row, index) => ({
    id: row.id,
    label: `Invoice ${index + 1}`,
    amountDue: parseFloat(row.outstanding_amount),
    dueDateLabel: row.due_date.slice(0, 10),
    statusLabel: row.invoice_status,
  }));
  const totalDue = installments.reduce((sum, item) => sum + item.amountDue, 0);
  const hasOutstanding = installments.some((item) =>
    item.statusLabel === "issued" || item.statusLabel === "partially_paid"
  );

  return {
    ...snapshot,
    childName,
    childClass,
    summaryLabel: hasOutstanding ? "Outstanding fees" : "Fees",
    totalDue,
    installments,
  };
}

const RECEIPT_STATUS_LABELS: Record<string, string> = {
  completed: "Paid",
  cancelled: "Cancelled",
  partially_refunded: "Partially refunded",
  refunded: "Refunded",
  draft: "Draft",
};

export interface FinanceReceiptsPage {
  items: Record<string, unknown>[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

/**
 * List the child's REAL fee receipts (from finance_receipts → finance_collections)
 * shaped exactly as the parent/student receipts list expects. Replaces the stale
 * `parent_entities` seed cache so a collection recorded by the office actually
 * surfaces as a receipt in the parent app. Returns an empty page when the child
 * has no receipts yet (RLS restricts visibility to the caller's own children).
 */
export async function overlayReceiptsFromFinance(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
  pagination: { page: number; pageSize: number },
): Promise<FinanceReceiptsPage> {
  const pageSize = Math.min(100, Math.max(1, pagination.pageSize));
  const page = Math.max(1, pagination.page);
  const offset = (page - 1) * pageSize;

  const countRows = await db.queryObject<{ total: string }>(
    `SELECT count(*)::text AS total
       FROM finance_receipts r
       JOIN finance_collections c ON c.id = r.collection_id
      WHERE r.organization_id = $1 AND r.school_id = $2 AND c.student_id = $3`,
    [orgId, schoolId, studentId],
  );
  const total = parseInt(countRows[0]?.total ?? "0", 10);

  let childName = "Student";
  let childClass = "";
  try {
    const context = await loadStudentParentSnapshotContext(db, orgId, schoolId, studentId);
    if (context.childName) childName = String(context.childName);
    if (context.childClass) childClass = String(context.childClass);
  } catch {
    // fall back to defaults on any lookup failure
  }

  const schoolRows = await db.queryObject<{ name: string }>(
    `SELECT name FROM schools WHERE id = $1 LIMIT 1`,
    [schoolId],
  );
  const schoolName = schoolRows[0]?.name ?? "Akshara Public School";

  const rows = await db.queryObject<{
    id: string;
    receipt_number: string;
    date_label: string;
    amount: string;
    payment_method: string;
    collection_status: string;
    invoice_number: string;
  }>(
    `SELECT r.id,
            r.receipt_number,
            to_char(r.receipt_date, 'DD Mon YYYY') AS date_label,
            r.amount::text AS amount,
            c.payment_method,
            c.collection_status,
            i.invoice_number
       FROM finance_receipts r
       JOIN finance_collections c ON c.id = r.collection_id
       JOIN finance_invoices i ON i.id = c.invoice_id
      WHERE r.organization_id = $1 AND r.school_id = $2 AND c.student_id = $3
      ORDER BY r.receipt_date DESC, r.created_at DESC, r.id DESC
      LIMIT $4 OFFSET $5`,
    [orgId, schoolId, studentId, pageSize, offset],
  );

  const items = rows.map((row) => {
    const amount = Math.round(parseFloat(row.amount));
    const statusLabel = RECEIPT_STATUS_LABELS[row.collection_status] ??
      row.collection_status;
    return {
      id: row.id,
      receiptNumber: row.receipt_number,
      title: `Fee payment · ${row.invoice_number}`,
      dateLabel: row.date_label,
      amount,
      paymentMethod: row.payment_method,
      statusLabel,
      childName,
      childClass,
      category: "Fees",
      lineItems: [{ label: `Invoice ${row.invoice_number}`, amount }],
      schoolName,
    } as Record<string, unknown>;
  });

  return {
    items,
    total,
    page,
    pageSize,
    hasMore: offset + rows.length < total,
  };
}

// ─── PAR-D3 — annual / 80C fee-payment certificate DATA ─────────────────────
//
// Aggregates the child's REAL fee payments (finance_receipts → finance_collections)
// for one financial/academic year into the data an 80C tax certificate needs. The
// PDF itself is rendered client-side in a later wave; this endpoint only returns
// the honest, tenant-authoritative numbers. Signatory title is a per-school
// setting (schools.settings->>'feeCertificateSignatoryTitle'), defaulting to the
// owner-ruled "Principal" — read-with-default, no settings subsystem added.
//
// Only `completed` collections count toward the certificate: a cancelled or
// refunded payment is not a valid tax-deductible amount, so it must not inflate
// the 80C total. Own-child scoping is enforced twice — the caller's JWT child_ids
// at the handler, and the finance_receipts/collections parent RLS policy
// (20260704000000_parent_student_finance_read_rls.sql, keyed on student_guardians)
// underneath — so a child not linked to the parent yields zero rows either way.

export interface FeeCertificatePayment {
  date: string;
  receiptNo: string;
  amount: number;
  paymentMethod: string;
  description: string;
}

export interface FeeCertificateData {
  schoolName: string;
  guardianName: string;
  studentName: string;
  publicStudentId: string;
  admissionNumber: string;
  academicYear: string;
  totalPaidAmount: number;
  payments: FeeCertificatePayment[];
  signatoryTitle: string;
}

/**
 * Parse an academic/financial year label ("2025-2026", "2025-26" or a single
 * "2025") into the [start, endExclusive) date window an Indian financial year
 * spans: 1 Apr of the start year → 1 Apr of the next year. Returns null for an
 * unparseable / missing input so the caller can fall back to the current FY.
 */
export function financialYearWindow(
  academicYear: string | null | undefined,
): { startYear: number; label: string; start: string; endExclusive: string } | null {
  if (!academicYear) return null;
  const match = academicYear.match(/^(\d{4})(?:\s*-\s*(\d{2,4}))?$/);
  if (!match) return null;
  const startYear = parseInt(match[1], 10);
  if (!Number.isFinite(startYear)) return null;
  const endYear = startYear + 1;
  return {
    startYear,
    label: `${startYear}-${endYear}`,
    start: `${startYear}-04-01`,
    endExclusive: `${endYear}-04-01`,
  };
}

/** The financial year (Apr–Mar) that `now` falls in. */
export function currentFinancialYear(now = new Date()): {
  startYear: number;
  label: string;
  start: string;
  endExclusive: string;
} {
  const month = now.getUTCMonth(); // 0=Jan
  const startYear = month >= 3 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
  return financialYearWindow(String(startYear))!;
}

export async function buildFeeCertificateData(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
  academicYear: string | null | undefined,
): Promise<FeeCertificateData> {
  const window = financialYearWindow(academicYear) ?? currentFinancialYear();

  // School name + the per-school configurable signatory title. Both live on the
  // schools row, which parent scope may read for its own active school (RLS
  // schools_scope_access). Default signatory is the owner-ruled "Principal".
  const schoolRows = await db.queryObject<{ name: string; signatory_title: string | null }>(
    `SELECT name,
            NULLIF(TRIM(settings->>'feeCertificateSignatoryTitle'), '') AS signatory_title
       FROM schools
      WHERE id = $1
      LIMIT 1`,
    [schoolId],
  );
  const schoolName = schoolRows[0]?.name ?? "Akshara Public School";
  const signatoryTitle = schoolRows[0]?.signatory_title ?? "Principal";

  // Child identity: display name (students), PSID + admission number
  // (student_profiles). Scoped to org+school+student; parent RLS restricts the
  // student/profile rows to the caller's own children.
  const studentRows = await db.queryObject<{
    display_name: string;
    public_student_id: string | null;
    admission_number: string | null;
  }>(
    `SELECT s.display_name,
            sp.public_student_id,
            sp.admission_number
       FROM students s
       LEFT JOIN student_profiles sp
         ON sp.student_id = s.id
        AND sp.organization_id = s.organization_id
        AND sp.school_id = s.school_id
      WHERE s.organization_id = $1 AND s.school_id = $2 AND s.id = $3
      LIMIT 1`,
    [orgId, schoolId, studentId],
  );
  const studentRow = studentRows[0];
  const studentName = studentRow?.display_name ?? "Student";
  const publicStudentId = studentRow?.public_student_id ?? "";
  const admissionNumber = studentRow?.admission_number ?? "";

  // Guardian (the parent making the request) — their own users row, readable
  // under RLS users_self_access (id = app_current_user_id() = the parent's sub).
  // A parent-scoped context sets parent_user_id; we read the caller's name for
  // the certificate's "paid by" line.
  const guardianRows = await db.queryObject<{ display_name: string }>(
    `SELECT display_name FROM users WHERE id = app_current_user_id() LIMIT 1`,
  );
  const guardianName = guardianRows[0]?.display_name ?? "";

  // The year's payments for THIS child. finance_receipts.receipt_date is the
  // payment date the parent needs for 80C; join finance_collections for the
  // student scope + payment method, and finance_invoices for a description.
  // Only completed collections count (a cancelled/refunded one is not deductible).
  const rows = await db.queryObject<{
    date_label: string;
    receipt_number: string;
    amount: string;
    payment_method: string;
    invoice_number: string | null;
  }>(
    `SELECT to_char(r.receipt_date, 'DD Mon YYYY') AS date_label,
            r.receipt_number,
            r.amount::text AS amount,
            c.payment_method,
            i.invoice_number
       FROM finance_receipts r
       JOIN finance_collections c ON c.id = r.collection_id
       LEFT JOIN finance_invoices i ON i.id = c.invoice_id
      WHERE r.organization_id = $1 AND r.school_id = $2 AND c.student_id = $3
        AND c.collection_status = 'completed'
        AND r.receipt_date >= $4::date AND r.receipt_date < $5::date
      ORDER BY r.receipt_date ASC, r.created_at ASC, r.id ASC`,
    [orgId, schoolId, studentId, window.start, window.endExclusive],
  );

  const payments: FeeCertificatePayment[] = rows.map((row) => ({
    date: row.date_label,
    receiptNo: row.receipt_number,
    amount: parseFloat(row.amount),
    paymentMethod: row.payment_method,
    description: row.invoice_number
      ? `Fee payment · ${row.invoice_number}`
      : "Fee payment",
  }));
  const totalPaidAmount = payments.reduce((sum, p) => sum + p.amount, 0);

  return {
    schoolName,
    guardianName,
    studentName,
    publicStudentId,
    admissionNumber,
    academicYear: window.label,
    totalPaidAmount,
    payments,
    signatoryTitle,
  };
}

/**
 * Overlay the parent/student "exams" snapshot with the child's REAL published
 * exam results (and correct child identity). Mirrors the attendance/fees
 * overlays so published marks reach the parent durably instead of stale seed
 * snapshot data. Returns the snapshot untouched (minus identity fix) when no
 * results are published yet.
 */
export async function overlayExamsSnapshotFromResults(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
  snapshot: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  // Correct child identity from real records (seed snapshot may be stale).
  let childName = snapshot.childName;
  let childClass = snapshot.childClass;
  try {
    const context = await loadStudentParentSnapshotContext(db, orgId, schoolId, studentId);
    if (context.childName) childName = context.childName;
    if (context.childClass) childClass = context.childClass;
  } catch {
    // keep snapshot identity on any lookup failure
  }

  // P2 cosmetic-correctness fix — the report-card PDF (parent + student both
  // export off this exams snapshot) must brand with the REAL per-tenant school,
  // never a seeded/hardcoded label. `schools` is the single source of truth;
  // always overlay it live, same precedent query as loadStudentSnapshotContext.
  let schoolName = snapshot.schoolName;
  try {
    const schoolRows = await db.queryObject<{ name: string }>(
      `SELECT name FROM schools WHERE id = $1 LIMIT 1`,
      [schoolId],
    );
    if (schoolRows[0]?.name) schoolName = schoolRows[0].name;
  } catch {
    // keep snapshot schoolName on any lookup failure
  }

  const { listPublishedResultsForStudent } = await import(
    "../academics/exam_administration/exam_administration_repository.ts"
  );
  const published = await listPublishedResultsForStudent(db, orgId, schoolId, studentId);

  if (published.length === 0) {
    return { ...snapshot, childName, childClass, schoolName };
  }

  const examResults = published.map((r) => ({
    id: String(r.markEntryId ?? ""),
    title: String(r.subject ?? r.examTitle ?? ""),
    termLabel: String(r.termLabel ?? ""),
    dateLabel: String(r.dateLabel ?? ""),
    scoreObtained: Number(r.scoreObtained ?? 0),
    maxScore: Number(r.maxScore ?? 0),
    grade: String(r.grade ?? ""),
  }));

  return { ...snapshot, childName, childClass, schoolName, examResults };
}

// --- Student homework READ overlay (MJ-H7 belt-and-suspenders) ---
//
// Joins the student's own homework_submissions onto their `homework_item`
// payloads so status/grade/comment reflect the latest real state even if the
// review write-back to student_entities was missed. A 'submitted' submission
// marks the item submitted; a 'reviewed' one marks it reviewed and carries the
// grade + teacher comment. Items with no submission are returned untouched.
export async function overlayStudentHomeworkFromSubmissions(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
  items: Record<string, unknown>[],
): Promise<Record<string, unknown>[]> {
  if (items.length === 0) return items;

  const homeworkIds = items
    .map((item) => String(item.id ?? ""))
    .filter((id) => id.length > 0);
  if (homeworkIds.length === 0) return items;

  const rows = await db.queryObject<{
    homework_id: string;
    status: string;
    grade: string | null;
    comment: string | null;
    submitted_label: string | null;
  }>(
    `SELECT homework_id, status, grade, comment,
            to_char(submitted_at, 'DD Mon YYYY') AS submitted_label
     FROM homework_submissions
     WHERE organization_id = $1 AND school_id = $2 AND student_id = $3::uuid
       AND homework_id = ANY($4::text[])`,
    [orgId, schoolId, studentId, homeworkIds],
  );

  const byHomework = new Map<string, typeof rows[number]>();
  for (const row of rows) byHomework.set(row.homework_id, row);

  return items.map((item) => {
    const sub = byHomework.get(String(item.id ?? ""));
    // HWK-1 — derive overdue from the real dueDate carried in the item payload.
    // A pending item past its due date reads as 'overdue'; a submitted/reviewed
    // one never does. Items with no dueDate keep their raw status (legacy).
    const dueDate = (item.dueDate as string | null | undefined) ?? null;
    if (!sub) {
      const rawStatus = String(item.status ?? "pending");
      const displayStatus = deriveHomeworkDisplayStatus(rawStatus, dueDate);
      return displayStatus === rawStatus
        ? item
        : { ...item, status: displayStatus };
    }
    const displayStatus = deriveHomeworkDisplayStatus(sub.status, dueDate);
    const overlay: Record<string, unknown> = {
      ...item,
      status: displayStatus,
      submittedLabel: sub.submitted_label ?? item.submittedLabel ?? "Submitted",
    };
    if (sub.status === "reviewed") {
      overlay.reviewGrade = sub.grade ?? null;
      overlay.reviewComment = sub.comment ?? null;
    }
    return overlay;
  });
}

// --- Teacher homework READ overlay (MJ-C2) ---
//
// The generic teacher list returns `homework_assignment` payloads with no
// submissions, so the teacher can never see or grade student work. This overlay
// joins homework_submissions (keyed by homework_id) onto each assignment and
// attaches a real `submissions` array — each entry carrying the submission's
// real UUID (so the review POST targets a real row), the student's display
// name, status, grade, comment and a submittedLabel. It also recomputes
// pendingReviews = count of submissions still awaiting review (status =
// 'submitted'). RLS keeps the read tenant/school scoped.
export async function overlayTeacherHomeworkSubmissions(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  items: Record<string, unknown>[],
): Promise<Record<string, unknown>[]> {
  if (items.length === 0) return items;

  const homeworkIds = items
    .map((item) => String(item.id ?? ""))
    .filter((id) => id.length > 0);
  if (homeworkIds.length === 0) return items;

  const rows = await db.queryObject<{
    id: string;
    homework_id: string;
    student_name: string | null;
    class_label: string | null;
    status: string;
    grade: string | null;
    comment: string | null;
    submitted_label: string | null;
  }>(
    `SELECT hs.id::text AS id,
            hs.homework_id,
            s.display_name AS student_name,
            CASE
              WHEN e.class_name IS NULL THEN NULL
              WHEN e.section_name IS NULL OR e.section_name = '' THEN e.class_name
              ELSE e.class_name || '-' || e.section_name
            END AS class_label,
            hs.status,
            hs.grade,
            hs.comment,
            to_char(hs.submitted_at, 'DD Mon YYYY') AS submitted_label
     FROM homework_submissions hs
     LEFT JOIN students s ON s.id = hs.student_id
       AND s.organization_id = hs.organization_id
       AND s.school_id = hs.school_id
     LEFT JOIN sis_student_enrollments e ON e.student_id = hs.student_id
       AND e.organization_id = hs.organization_id
       AND e.school_id = hs.school_id
       AND e.is_current = true
     WHERE hs.organization_id = $1 AND hs.school_id = $2
       AND hs.homework_id = ANY($3::text[])
     ORDER BY hs.submitted_at DESC`,
    [orgId, schoolId, homeworkIds],
  );

  const byHomework = new Map<string, Record<string, unknown>[]>();
  for (const row of rows) {
    const bucket = byHomework.get(row.homework_id) ?? [];
    bucket.push({
      id: row.id,
      studentName: row.student_name ?? "Student",
      classLabel: row.class_label ?? "",
      title: row.homework_id,
      submittedLabel: row.submitted_label ?? "Submitted",
      status: row.status,
      grade: row.grade ?? null,
      comment: row.comment ?? null,
    });
    byHomework.set(row.homework_id, bucket);
  }

  return items.map((item) => {
    const homeworkId = String(item.id ?? "");
    const submissions = byHomework.get(homeworkId) ?? [];
    const pendingReviews = submissions.filter(
      (s) => s.status === "submitted",
    ).length;
    return { ...item, submissions, pendingReviews };
  });
}

// Parse a teacher-entered class label ("8-A", "8 A", or just "8") into the
// enrollment columns used by sis_student_enrollments. The section is optional;
// when omitted the whole class (all sections) is targeted.
export function parseClassLabel(
  classLabel: string,
): { className: string; sectionName: string | null } {
  const trimmed = (classLabel ?? "").trim();
  if (!trimmed) return { className: "", sectionName: null };
  // Split on the first '-' or whitespace separator.
  const match = trimmed.match(/^(.+?)[\s-]+(.+)$/);
  if (match) {
    return {
      className: match[1].trim(),
      sectionName: match[2].trim() || null,
    };
  }
  return { className: trimmed, sectionName: null };
}

// --- HWK-1 real due date helpers (pilot homework path) ---
//
// The pilot homework assignment previously carried only a free-text `dueLabel`
// ("Due next Monday"), so nothing could compute whether a task was actually
// overdue. These pure helpers give the create path a real, validated ISO
// due_date and the read path a deterministic overdue derivation. Kept pure (no
// DB) so they unit-test without a database.

const MONTH_SHORT = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
] as const;

/**
 * Validate a due date. Accepts a real calendar date in strict ISO YYYY-MM-DD
 * form (also verifies the components round-trip, so "2026-02-30" is rejected).
 * Returns the normalised ISO string, or null when blank/unparseable — the
 * handler maps a null on a required due date to 422.
 */
export function validateDueDate(raw: unknown): string | null {
  if (raw == null) return null;
  const value = String(raw).trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const [y, m, d] = value.split("-").map((p) => parseInt(p, 10));
  const date = new Date(Date.UTC(y, m - 1, d));
  if (
    date.getUTCFullYear() !== y ||
    date.getUTCMonth() !== m - 1 ||
    date.getUTCDate() !== d
  ) {
    return null;
  }
  return value;
}

/** True when the ISO due date is strictly before today (past). Warn-not-block:
 * the create path allows a past date; this only powers a client-side warning. */
export function isDueDateInPast(isoDueDate: string, today = new Date()): boolean {
  const validated = validateDueDate(isoDueDate);
  if (!validated) return false;
  const todayIso = today.toISOString().slice(0, 10);
  return validated < todayIso;
}

/** Human "Due 08 Jun" label derived from an ISO due date, for backward-compat
 * rendering alongside the machine-readable dueDate. */
export function dueDateToLabel(isoDueDate: string): string {
  const validated = validateDueDate(isoDueDate);
  if (!validated) return "";
  const [, m, d] = validated.split("-").map((p) => parseInt(p, 10));
  return `Due ${String(d).padStart(2, "0")} ${MONTH_SHORT[m - 1]}`;
}

/**
 * Deterministic homework display state from the real due date + submission
 * status. `overdue` = still pending AND the due date is strictly before today;
 * a submitted/reviewed item is never overdue. Items with no dueDate keep their
 * raw status (legacy label-only assignments). Pure so it is unit-testable and
 * so both the student and parent overlays derive overdue identically.
 */
export function deriveHomeworkDisplayStatus(
  rawStatus: string,
  isoDueDate: string | null | undefined,
  today = new Date(),
): string {
  const status = rawStatus || "pending";
  // Handed-in states are terminal — never overdue.
  if (status === "submitted" || status === "reviewed" || status === "returned") {
    return status;
  }
  if (status !== "pending") return status;
  if (!isoDueDate) return status;
  return isDueDateInPast(isoDueDate, today) ? "overdue" : status;
}

/**
 * HWK-1 — derive overdue on the parent homework snapshot items from their real
 * `dueDate` (mirrors the student overlay). Pure over the snapshot's items array:
 * a pending item whose dueDate is past reads as 'overdue'; items with no dueDate
 * keep their status (legacy label-only). No DB access — the parent snapshot is
 * already resolved under RLS before this runs.
 */
export function overlayParentHomeworkDueState(
  snapshot: Record<string, unknown>,
  today = new Date(),
): Record<string, unknown> {
  const items = snapshot.items;
  if (!Array.isArray(items)) return snapshot;
  const mapped = items.map((raw) => {
    if (typeof raw !== "object" || raw === null) return raw;
    const item = raw as Record<string, unknown>;
    const dueDate = (item.dueDate as string | null | undefined) ?? null;
    const rawStatus = String(item.status ?? "pending");
    const displayStatus = deriveHomeworkDisplayStatus(rawStatus, dueDate, today);
    return displayStatus === rawStatus ? item : { ...item, status: displayStatus };
  });
  return { ...snapshot, items: mapped };
}

/**
 * HWK-4 + HWK-7 — enrich the parent homework snapshot items with the child's
 * REAL homework state, scoped to the parent's linked child under RLS:
 *   • the teacher's assignment attachment (attachmentName/attachmentRef) from the
 *     delivered `homework_item` payload (HWK-4);
 *   • the child's submission note + attachment, plus status/grade/comment, from
 *     `homework_submissions` (HWK-7 + review).
 * Items are keyed by homework id. Items with no matching real row are left as-is
 * (identity + due-state preserved). The overdue derivation is applied afterwards
 * by overlayParentHomeworkDueState (the caller runs both).
 */
export async function overlayParentHomeworkFromRealState(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  studentId: string,
  snapshot: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const items = snapshot.items;
  if (!Array.isArray(items) || items.length === 0) return snapshot;

  const homeworkIds = items
    .map((raw) =>
      typeof raw === "object" && raw !== null
        ? String((raw as Record<string, unknown>).id ?? "")
        : ""
    )
    .filter((id) => id.length > 0);
  if (homeworkIds.length === 0) return snapshot;

  // Teacher attachment carried on the delivered item payload for this child.
  const itemRows = await db.queryObject<{
    id: string;
    attachment_name: string | null;
    attachment_ref: string | null;
  }>(
    `SELECT id,
            payload->>'attachmentName' AS attachment_name,
            payload->>'attachmentRef' AS attachment_ref
       FROM student_entities
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3::uuid
        AND entity_type = 'homework_item'
        AND id = ANY($4::text[])`,
    [orgId, schoolId, studentId, homeworkIds],
  );
  const attachmentByHw = new Map<string, { name: string | null; ref: string | null }>();
  for (const r of itemRows) {
    attachmentByHw.set(r.id, { name: r.attachment_name, ref: r.attachment_ref });
  }

  // The child's own submission (note + attachment + status/grade/comment).
  const subRows = await db.queryObject<{
    homework_id: string;
    status: string;
    grade: string | null;
    comment: string | null;
    notes: string | null;
    attachment_label: string | null;
    submitted_label: string | null;
  }>(
    `SELECT homework_id, status, grade, comment, notes, attachment_label,
            to_char(submitted_at, 'DD Mon YYYY') AS submitted_label
       FROM homework_submissions
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3::uuid
        AND homework_id = ANY($4::text[])`,
    [orgId, schoolId, studentId, homeworkIds],
  );
  const subByHw = new Map<string, typeof subRows[number]>();
  for (const r of subRows) subByHw.set(r.homework_id, r);

  const mapped = items.map((raw) => {
    if (typeof raw !== "object" || raw === null) return raw;
    const item = { ...(raw as Record<string, unknown>) };
    const id = String(item.id ?? "");
    const attachment = attachmentByHw.get(id);
    if (attachment) {
      if (attachment.name) item.attachmentName = attachment.name;
      if (attachment.ref) item.attachmentRef = attachment.ref;
    }
    const sub = subByHw.get(id);
    if (sub) {
      item.status = sub.status;
      if (sub.grade != null) item.reviewGrade = sub.grade;
      if (sub.comment != null) item.reviewComment = sub.comment;
      if (sub.notes != null && sub.notes.length > 0) item.submissionNote = sub.notes;
      if (sub.attachment_label != null) {
        item.submissionAttachmentLabel = sub.attachment_label;
      }
      if (sub.submitted_label != null) item.submittedLabel = sub.submitted_label;
    }
    return item;
  });
  return { ...snapshot, items: mapped };
}

// --- Teacher homework CREATE (TCH-1 / MJ-H8) ---
//
// Persists a homework assignment as a durable `homework_assignment` entity for
// the teacher (survives restart, visible across the teacher's devices) and
// delivers a `homework_item` entity to each target student so the existing
// student/parent read path surfaces it.
//
// Targeting (MJ-H8): a named student matches display_name; otherwise the
// homework is delivered only to students whose CURRENT enrollment
// (sis_student_enrollments.is_current = true) matches the parsed class label
// (class_name, and section_name when a section was given). Back-compat safety:
// if the school has ZERO enrollment rows at all, fall back to the whole active
// roster so un-enrolled pilots are never silently starved of homework.
export async function insertHomeworkAssignment(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    teacherId: string;
    homeworkId: string;
    classLabel: string;
    subject: string;
    title: string;
    dueLabel: string;
    // HWK-1 — real machine-readable ISO (YYYY-MM-DD) due date. Persisted into
    // both the teacher assignment and each student homework_item payload so the
    // student/parent surfaces can compute overdue from a real date instead of a
    // free-text label. Null keeps a legacy label-only assignment (back-compat).
    dueDate: string | null;
    studentName: string | null;
    // HWK-4 — an OPTIONAL teacher attachment carried on the assignment. There is
    // no homework storage bucket yet, so this is a reference/label (a name plus
    // an optional URL/reference the teacher pastes — e.g. a shared-drive link),
    // NOT a real file upload. Both keys are stored on the teacher assignment and
    // on every delivered student homework_item payload so the student/parent
    // homework detail can surface it. Null keeps a plain assignment.
    attachmentName?: string | null;
    attachmentRef?: string | null;
  },
): Promise<{ id: string; deliveredCount: number }> {
  const attachmentName = input.attachmentName?.trim() || null;
  const attachmentRef = input.attachmentRef?.trim() || null;
  // teacher_entities is teacher-scoped (PK + RLS include teacher_id =
  // app_current_user_id()), so the assignment is owned by the creating teacher.
  // dueDate is stored as a top-level payload key; when null it degrades to a
  // label-only assignment (jsonb value 'null', which the client reads as absent).
  // HWK-4 attachmentName/attachmentRef ride the same payload (null when absent).
  await db.queryObject(
    `INSERT INTO teacher_entities (id, organization_id, school_id, teacher_id, entity_type, payload)
     VALUES ($1, $2, $3, $9::uuid, 'homework_assignment',
       jsonb_build_object(
         'id', $1::text, 'title', $4::text, 'classLabel', $5::text,
         'subject', $6::text, 'dueLabel', $7::text, 'dueDate', $8::text,
         'attachmentName', $10::text, 'attachmentRef', $11::text,
         'pendingReviews', 0))
     ON CONFLICT (organization_id, school_id, teacher_id, entity_type, id)
       DO UPDATE SET payload = EXCLUDED.payload`,
    [
      input.homeworkId,
      input.organizationId,
      input.schoolId,
      input.title,
      input.classLabel,
      input.subject,
      input.dueLabel,
      input.dueDate,
      input.teacherId,
      attachmentName,
      attachmentRef,
    ],
  );

  let targets: Array<{ id: string }>;
  if (input.studentName && input.studentName.trim().length > 0) {
    // Named-student branch: deliver to that one student only.
    targets = await db.queryObject<{ id: string }>(
      `SELECT id::text AS id FROM students
       WHERE organization_id = $1 AND school_id = $2 AND status = 'active'
         AND lower(display_name) = lower($3)`,
      [input.organizationId, input.schoolId, input.studentName.trim()],
    );
  } else {
    // Whole-class branch (MJ-H8): target by current enrollment when the school
    // has enrollment data; otherwise fall back to the full active roster.
    const enrollmentCountRows = await db.queryObject<{ total: string }>(
      `SELECT count(*)::text AS total FROM sis_student_enrollments
       WHERE organization_id = $1 AND school_id = $2`,
      [input.organizationId, input.schoolId],
    );
    const hasEnrollments = parseInt(enrollmentCountRows[0]?.total ?? "0", 10) > 0;

    if (hasEnrollments) {
      const { className, sectionName } = parseClassLabel(input.classLabel);
      targets = await db.queryObject<{ id: string }>(
        `SELECT s.id::text AS id
         FROM students s
         INNER JOIN sis_student_enrollments e
           ON e.student_id = s.id
          AND e.organization_id = s.organization_id
          AND e.school_id = s.school_id
          AND e.is_current = true
         WHERE s.organization_id = $1 AND s.school_id = $2 AND s.status = 'active'
           AND e.class_name = $3
           AND ($4::text IS NULL OR e.section_name = $4)`,
        [input.organizationId, input.schoolId, className, sectionName],
      );
    } else {
      targets = await db.queryObject<{ id: string }>(
        `SELECT id::text AS id FROM students
         WHERE organization_id = $1 AND school_id = $2 AND status = 'active'`,
        [input.organizationId, input.schoolId],
      );
    }
  }

  for (const target of targets) {
    await db.queryObject(
      `INSERT INTO student_entities (id, organization_id, school_id, student_id, entity_type, payload)
       VALUES ($1, $2, $3, $4::uuid, 'homework_item',
         jsonb_build_object(
           'id', $1::text, 'subject', $5::text, 'title', $6::text,
           'dueLabel', $7::text, 'dueDate', $8::text,
           'attachmentName', $9::text, 'attachmentRef', $10::text,
           'status', 'pending'))
       ON CONFLICT (organization_id, school_id, student_id, entity_type, id)
         DO UPDATE SET payload = EXCLUDED.payload`,
      [
        input.homeworkId,
        input.organizationId,
        input.schoolId,
        target.id,
        input.subject,
        input.title,
        input.dueLabel,
        input.dueDate,
        attachmentName,
        attachmentRef,
      ],
    );
  }

  return { id: input.homeworkId, deliveredCount: targets.length };
}

// --- HWK-2 not-submitted list ------------------------------------------------
//
// The delivered roster for an assignment IS the set of students who received a
// `homework_item` entity for that homework_id (that is how insertHomeworkAssignment
// targets a class). LEFT JOIN homework_submissions to find who has NOT submitted.
// Scoped to the tenant/school under RLS (teacher/school scope reads all rows in
// its own school). Returns the missing students {studentId, name} for the
// teacher's "Not submitted (N)" tab. Ordered by student name for stable display.
export async function listHomeworkNonSubmitters(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  homeworkId: string,
): Promise<Array<{ studentId: string; name: string }>> {
  const rows = await db.queryObject<{ student_id: string; name: string }>(
    `SELECT se.student_id::text AS student_id,
            COALESCE(s.display_name, 'Student') AS name
       FROM student_entities se
       LEFT JOIN students s ON s.id = se.student_id
         AND s.organization_id = se.organization_id
         AND s.school_id = se.school_id
       LEFT JOIN homework_submissions hs ON hs.homework_id = se.id
         AND hs.organization_id = se.organization_id
         AND hs.school_id = se.school_id
         AND hs.student_id = se.student_id
      WHERE se.organization_id = $1 AND se.school_id = $2
        AND se.entity_type = 'homework_item'
        AND se.id = $3
        AND hs.id IS NULL
      ORDER BY name`,
    [orgId, schoolId, homeworkId],
  );
  return rows.map((r) => ({ studentId: r.student_id, name: r.name }));
}

// --- HWK-D1 parent no-submit nudge (manual, teacher-triggered) ---------------
//
// For each non-submitter of `homeworkId`, resolve their active guardian user ids
// and enqueue ONE notification per guardian via the supplied `enqueue` callback
// (the handler passes enqueueNotificationRequested so we avoid importing the
// communication service into the repository — no circular dep, and this stays
// unit-testable with a mock enqueue). Returns how many students were pending and
// how many notifications were queued. The teacher-authored (or default) message
// body is passed straight through by the caller.
export async function notifyHomeworkNonSubmitters(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  homeworkId: string,
  enqueue: (guardianUserId: string) => Promise<void>,
): Promise<{ studentsPending: number; notificationsQueued: number }> {
  const nonSubmitters = await listHomeworkNonSubmitters(
    db,
    orgId,
    schoolId,
    homeworkId,
  );
  let notificationsQueued = 0;
  for (const student of nonSubmitters) {
    const guardians = await listGuardianUserIdsForStudent(
      db,
      orgId,
      schoolId,
      student.studentId,
    );
    for (const guardianUserId of guardians) {
      await enqueue(guardianUserId);
      notificationsQueued += 1;
    }
  }
  return { studentsPending: nonSubmitters.length, notificationsQueued };
}

// --- HWK-6 bulk review -------------------------------------------------------
//
// Mark many submissions reviewed in one action. Callers pass either an explicit
// list of submission ids, or (submissionIds omitted / empty) request ALL still-
// pending ('submitted') submissions of a homework_id. Each row is graded via the
// SAME reviewHomework path (so the student_entities write-back + name resolution
// stay identical to single review) — no bypass. Returns a partial-success
// summary {reviewed, skipped}: a submission that no longer exists / is already
// reviewed / errors is skipped, not fatal.
export async function bulkReviewHomework(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: {
    homeworkId: string;
    submissionIds: string[];
    grade: string;
    comment: string;
    reviewerId: string;
  },
): Promise<{ reviewed: number; skipped: number; reviewedIds: string[] }> {
  let ids = input.submissionIds.filter((id) => id.trim().length > 0);
  // All-for-assignment: resolve the still-pending submissions of this homework.
  if (ids.length === 0) {
    const rows = await db.queryObject<{ id: string }>(
      `SELECT id::text AS id FROM homework_submissions
        WHERE organization_id = $1 AND school_id = $2
          AND homework_id = $3 AND status = 'submitted'`,
      [orgId, schoolId, input.homeworkId],
    );
    ids = rows.map((r) => r.id);
  }

  const reviewedIds: string[] = [];
  let skipped = 0;
  for (const submissionId of ids) {
    try {
      const result = await reviewHomework(db, orgId, schoolId, submissionId, {
        grade: input.grade,
        comment: input.comment,
        reviewerId: input.reviewerId,
      });
      // reviewHomework echoes the requested id (status 'reviewed') even when no
      // row matched, so trust its `matched` flag to count a real update only.
      if (result.matched === true) {
        reviewedIds.push(submissionId);
      } else {
        skipped += 1;
      }
    } catch {
      skipped += 1;
    }
  }
  return { reviewed: reviewedIds.length, skipped, reviewedIds };
}

// --- HWK-5 homework history / export ----------------------------------------
//
// The teacher's homework history: their own `homework_assignment` entities
// (teacher-scoped by RLS) with real submitted/total counts, optionally filtered
// to an inclusive ISO date range on the assignment's real due_date (fromDate /
// toDate). `total` = students the assignment was delivered to (homework_item
// rows for that homework_id); `submitted` = how many have a submission. The
// CSV export (client-side, via the shared export service) rides these rows.
export async function listTeacherHomeworkHistory(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
  filter: { fromDate?: string | null; toDate?: string | null },
  pagination: { page: number; pageSize: number },
): Promise<{
  items: Array<Record<string, unknown>>;
  page: number;
  pageSize: number;
  total: number;
  hasMore: boolean;
}> {
  const fromDate = filter.fromDate ?? null;
  const toDate = filter.toDate ?? null;
  const rows = await db.queryObject<{
    id: string;
    title: string;
    class_label: string;
    subject: string;
    due_label: string;
    due_date: string | null;
    delivered: number;
    submitted: number;
  }>(
    `SELECT te.id::text AS id,
            COALESCE(te.payload->>'title', '') AS title,
            COALESCE(te.payload->>'classLabel', '') AS class_label,
            COALESCE(te.payload->>'subject', '') AS subject,
            COALESCE(te.payload->>'dueLabel', '') AS due_label,
            NULLIF(te.payload->>'dueDate', '') AS due_date,
            (
              SELECT count(*)::int FROM student_entities se
               WHERE se.organization_id = te.organization_id
                 AND se.school_id = te.school_id
                 AND se.entity_type = 'homework_item'
                 AND se.id = te.id
            ) AS delivered,
            (
              SELECT count(*)::int FROM homework_submissions hs
               WHERE hs.organization_id = te.organization_id
                 AND hs.school_id = te.school_id
                 AND hs.homework_id = te.id
            ) AS submitted
       FROM teacher_entities te
      WHERE te.organization_id = $1 AND te.school_id = $2
        AND te.teacher_id = $3::uuid
        AND te.entity_type = 'homework_assignment'
        AND ($4::date IS NULL OR NULLIF(te.payload->>'dueDate','')::date >= $4::date)
        AND ($5::date IS NULL OR NULLIF(te.payload->>'dueDate','')::date <= $5::date)
      ORDER BY NULLIF(te.payload->>'dueDate','')::date DESC NULLS LAST, te.created_at DESC`,
    [orgId, schoolId, teacherUserId, fromDate, toDate],
  );

  const all = rows.map((r) => ({
    id: r.id,
    title: r.title,
    classLabel: r.class_label,
    subject: r.subject,
    dueLabel: r.due_label,
    dueDate: r.due_date,
    submittedCount: r.submitted,
    totalCount: r.delivered,
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

// ===========================================================================
// MJ-C7 (TEACH-1 + TEACH-5) — teacher static-snapshot read modernization.
//
// The teacher mobile reads (attendance roster, upcoming exams, exam marks,
// leave history, dashboard) were served from the pre-seeded `teacher_entities`
// snapshot rows, so they showed fixed fiction and never reflected real class
// data or the teacher's own writes. The helpers below recompute each from the
// canonical operational tables, scoped to THIS teacher (sub) inside the tenant
// RLS context. A fresh school with no data returns honest zeros/empty arrays.
// ===========================================================================

// The teacher's own classes (class labels) come from the timetable: any slot
// where the teacher is the assigned or substitute teacher. Distinct, ordered.
async function listTeacherClassLabels(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
): Promise<string[]> {
  const rows = await db.queryObject<{ class_label: string }>(
    `SELECT DISTINCT class_label
       FROM timetable_slots
      WHERE organization_id = $1 AND school_id = $2
        AND (teacher_user_id = $3::uuid OR substitute_teacher_user_id = $3::uuid)
        AND class_label IS NOT NULL AND class_label <> ''
      ORDER BY class_label`,
    [orgId, schoolId, teacherUserId],
  );
  return rows.map((r) => r.class_label);
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
  // One slot row per (class, subject, period) the teacher teaches; the picker
  // shows the class with its subject + earliest period label.
  const rows = await db.queryObject<{
    class_label: string;
    subject_label: string;
    period_number: number;
    marked: boolean;
    student_count: number;
  }>(
    `SELECT ts.class_label,
            ts.subject_label,
            min(ts.period_number) AS period_number,
            bool_or(ses.id IS NOT NULL) AS marked,
            (
              SELECT count(*)::int FROM sis_student_enrollments e2
               WHERE e2.organization_id = $1
                 AND e2.school_id = $2
                 AND e2.is_current = true
                 AND (e2.class_name || '-' || e2.section_name) = ts.class_label
            ) AS student_count
       FROM timetable_slots ts
       LEFT JOIN attendance_sessions ses
         ON ses.organization_id = ts.organization_id
        AND ses.school_id = ts.school_id
        AND ses.class_label = ts.class_label
        AND ses.session_date = CURRENT_DATE
        AND ses.status = 'submitted'
      WHERE ts.organization_id = $1 AND ts.school_id = $2
        AND (ts.teacher_user_id = $3::uuid OR ts.substitute_teacher_user_id = $3::uuid)
        AND ts.class_label IS NOT NULL AND ts.class_label <> ''
      GROUP BY ts.class_label, ts.subject_label
      ORDER BY ts.class_label, ts.subject_label`,
    [orgId, schoolId, teacherUserId],
  );

  const all = rows.map((r) => ({
    id: `class_${r.class_label}`,
    label: `${r.class_label} ${r.subject_label}`,
    subject: r.subject_label,
    periodLabel: `Period ${r.period_number}`,
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

// --- TEACH-1: upcoming exams (GET /teacher/exams/upcoming) ---
//
// Real exam_sessions for the classes this teacher teaches that are not yet
// published, mapped to the client's upcoming-exam shape. Empty => [].
export async function listTeacherUpcomingExams(
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
  const classLabels = await listTeacherClassLabels(db, orgId, schoolId, teacherUserId);
  if (classLabels.length === 0) {
    return { items: [], page: pagination.page, pageSize: pagination.pageSize, total: 0, hasMore: false };
  }

  const rows = await db.queryObject<{
    id: string;
    title: string;
    subject: string;
    grade: string;
    section_name: string;
    date_label: string;
    max_marks: number;
  }>(
    `SELECT id, title, subject, grade, section_name, date_label, max_marks
       FROM exam_sessions
      WHERE organization_id = $1 AND school_id = $2
        AND phase <> 'published'
        AND (grade || '-' || section_name) = ANY($3::text[])
      ORDER BY updated_at DESC`,
    [orgId, schoolId, classLabels],
  );

  const all = rows.map((r) => ({
    id: r.id,
    title: r.title,
    subject: r.subject,
    classLabel: `${r.grade}-${r.section_name}`,
    dateLabel: r.date_label,
    maxMarks: r.max_marks,
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

// --- TEACH-1: exam marks (GET /teacher/exams/marks) ---
//
// Real exam_mark_entries for the teacher's classes that are in marks-entry (not
// yet published), mapped to the client's ExamMarkEntry shape. Empty => [].
export async function listTeacherExamMarks(
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
  const classLabels = await listTeacherClassLabels(db, orgId, schoolId, teacherUserId);
  if (classLabels.length === 0) {
    return { items: [], page: pagination.page, pageSize: pagination.pageSize, total: 0, hasMore: false };
  }

  const rows = await db.queryObject<{
    id: string;
    student_id: string;
    student_code: string | null;
    student_name: string | null;
    roll_number: string | null;
    marks_obtained: number;
    marks_entered: boolean;
    max_marks: number;
  }>(
    `SELECT me.id, me.student_id::text AS student_id, me.student_code,
            me.student_name, me.roll_number, me.marks_obtained,
            me.marks_entered, me.max_marks
       FROM exam_mark_entries me
       INNER JOIN exam_sessions es ON es.id = me.exam_id
        AND es.organization_id = me.organization_id
        AND es.school_id = me.school_id
      WHERE me.organization_id = $1 AND me.school_id = $2
        AND me.published = false
        AND me.class_label = ANY($3::text[])
      ORDER BY me.roll_number NULLS LAST, me.id`,
    [orgId, schoolId, classLabels],
  );

  const all = rows.map((r) => ({
    id: r.id,
    sisStudentId: r.student_code ?? r.student_id,
    studentName: r.student_name ?? "",
    rollNo: r.roll_number ?? "",
    marksObtained: r.marks_entered ? r.marks_obtained : null,
    maxMarks: r.max_marks,
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

// --- TEACH-1: leave history (GET /teacher/leave) ---
//
// The teacher's own leave applications from mobile_leave_requests (the canonical
// store the HR/approval side reads). Scoped to requester_user_id = teacher and
// requester_scope = 'teacher'. Same shape the leave_request seed used. Empty
// => []. Newest first.
export async function listTeacherLeaveRequests(
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
  const rows = await db.queryObject<{
    id: string;
    type_label: string;
    from_date_label: string;
    to_date_label: string;
    reason: string;
    status: string;
    submitted_label: string;
  }>(
    `SELECT id, type_label, from_date_label, to_date_label, reason, status,
            to_char(created_at, 'DD Mon YYYY') AS submitted_label
       FROM mobile_leave_requests
      WHERE organization_id = $1 AND school_id = $2
        AND requester_user_id = $3::uuid AND requester_scope = 'teacher'
      ORDER BY created_at DESC`,
    [orgId, schoolId, teacherUserId],
  );

  const all = rows.map((r) => ({
    id: r.id,
    type: r.type_label,
    typeLabel: r.type_label,
    fromDateLabel: r.from_date_label,
    toDateLabel: r.to_date_label,
    reason: r.reason,
    status: r.status,
    submittedLabel: r.submitted_label,
    timeline: [
      { label: "Submitted", dateLabel: r.submitted_label, isComplete: true },
      {
        label: r.status === "rejected" ? "Rejected" : "Approved",
        dateLabel: "",
        isComplete: r.status === "approved" || r.status === "rejected",
      },
    ],
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

// --- TEACH-5: dashboard (GET /teacher/dashboard) ---
//
// Replaces the canned snapshot_dashboard `todaySchedule`/`pendingTasks`/
// `aiInsight`/`attendanceSummary` with values derived from the teacher's real
// timetable (today's classes), real submitted attendance sessions (which classes
// are marked) and pending homework reviews. Preserves the snapshot's other
// scaffolding fields (greeting, teacherName, quickActions, etc.). A fresh school
// returns an empty schedule, zero pending tasks and a neutral insight — never
// the seed "2 classes need attendance today" fiction.
export async function overlayTeacherDashboard(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  teacherUserId: string,
  snapshot: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const todayDow = (() => {
    const day = new Date().getUTCDay();
    return day === 0 ? 7 : day; // 1=Mon..7=Sun
  })();

  // Today's classes from the teacher's timetable.
  const slotRows = await db.queryObject<{
    period_number: number;
    subject_label: string;
    class_label: string;
    room_label: string | null;
  }>(
    `SELECT period_number, subject_label, class_label, room_label
       FROM timetable_slots
      WHERE organization_id = $1 AND school_id = $2
        AND day_of_week = $3
        AND (teacher_user_id = $4::uuid OR substitute_teacher_user_id = $4::uuid)
      ORDER BY period_number`,
    [orgId, schoolId, todayDow, teacherUserId],
  );

  const todaySchedule = slotRows.map((row) => ({
    id: `p${row.period_number}-${row.class_label}`,
    timeLabel: periodTimeRange(row.period_number),
    subject: row.subject_label,
    classLabel: row.class_label,
    room: row.room_label ?? "",
    status: "upcoming",
  }));

  // Distinct classes the teacher teaches today, and which already have a
  // submitted attendance session today.
  const todaysClassLabels = Array.from(
    new Set(slotRows.map((r) => r.class_label).filter((l) => l && l.length > 0)),
  );

  let markedClassLabels: string[] = [];
  if (todaysClassLabels.length > 0) {
    const markedRows = await db.queryObject<{ class_label: string }>(
      `SELECT DISTINCT class_label
         FROM attendance_sessions
        WHERE organization_id = $1 AND school_id = $2
          AND session_date = CURRENT_DATE AND status = 'submitted'
          AND class_label = ANY($3::text[])`,
      [orgId, schoolId, todaysClassLabels],
    );
    markedClassLabels = markedRows.map((r) => r.class_label);
  }
  const classesMarked = markedClassLabels.length;
  const classesTotal = todaysClassLabels.length;
  const pendingAttendanceCount = Math.max(0, classesTotal - classesMarked);
  const firstUnmarked = todaysClassLabels.find(
    (label) => !markedClassLabels.includes(label),
  );

  // Pending homework reviews (submissions still awaiting review) for this
  // teacher's assignments.
  const reviewRows = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count
       FROM homework_submissions hs
       INNER JOIN teacher_entities te
         ON te.id = hs.homework_id
        AND te.organization_id = hs.organization_id
        AND te.school_id = hs.school_id
        AND te.entity_type = 'homework_assignment'
        AND te.teacher_id = $3::uuid
      WHERE hs.organization_id = $1 AND hs.school_id = $2
        AND hs.status = 'submitted'`,
    [orgId, schoolId, teacherUserId],
  );
  const pendingReviewCount = parseInt(reviewRows[0]?.count ?? "0", 10) || 0;

  const pendingTasks: Record<string, unknown>[] = [];
  if (pendingAttendanceCount > 0) {
    pendingTasks.push({
      id: "attendance",
      icon: "attendance",
      count: pendingAttendanceCount,
      label: pendingAttendanceCount === 1
        ? "1 class needs attendance"
        : `${pendingAttendanceCount} classes need attendance`,
    });
  }
  if (pendingReviewCount > 0) {
    pendingTasks.push({
      id: "homework",
      icon: "homework",
      count: pendingReviewCount,
      label: pendingReviewCount === 1
        ? "1 homework to review"
        : `${pendingReviewCount} homework to review`,
    });
  }

  // Deterministic insight derived from the real pending state (no Claude call —
  // teacher has no existing AI insight pipeline).
  let aiInsight: Record<string, unknown>;
  if (pendingAttendanceCount > 0) {
    aiInsight = {
      message: pendingAttendanceCount === 1
        ? "1 class needs attendance today."
        : `${pendingAttendanceCount} classes need attendance today.`,
      actionLabel: "Mark now",
    };
  } else if (pendingReviewCount > 0) {
    aiInsight = {
      message: pendingReviewCount === 1
        ? "1 homework submission is waiting for your review."
        : `${pendingReviewCount} homework submissions are waiting for your review.`,
      actionLabel: "Review",
    };
  } else if (classesTotal > 0) {
    aiInsight = {
      message: "All caught up — attendance is marked for today's classes.",
      actionLabel: "",
    };
  } else {
    aiInsight = { message: "No classes scheduled for today.", actionLabel: "" };
  }

  const attendanceSummary: Record<string, unknown> = {
    ...(snapshot.attendanceSummary as Record<string, unknown> ?? {}),
    classesMarked,
    classesTotal,
    pendingClassId: firstUnmarked ? `class_${firstUnmarked}` : null,
    pendingBannerMessage: pendingAttendanceCount > 0
      ? (pendingAttendanceCount === 1
        ? "1 class still needs attendance"
        : `${pendingAttendanceCount} classes still need attendance`)
      : null,
    pendingBannerActionLabel: pendingAttendanceCount > 0 ? "Mark now" : "",
  };

  return {
    ...snapshot,
    todaySchedule,
    pendingTasks,
    aiInsight,
    attendanceSummary,
  };
}
