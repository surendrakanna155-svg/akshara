import type { TenantQueryClient } from "../tenant_db.ts";

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
} {
  let present = 0;
  let absent = 0;
  let late = 0;
  for (const entry of entries) {
    if (entry.mark === "present") present += 1;
    else if (entry.mark === "absent") absent += 1;
    else if (entry.mark === "late") late += 1;
  }
  return { present, absent, late };
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
  },
): Promise<{ sessionId: string; counts: ReturnType<typeof countMarks> }> {
  const existing = await db.queryObject<{ id: string }>(
    `SELECT id FROM attendance_sessions
     WHERE organization_id = $1 AND school_id = $2 AND class_label = $3
       AND session_date = CURRENT_DATE AND taken_by = $4
     LIMIT 1`,
    [input.organizationId, input.schoolId, input.classLabel, input.takenBy],
  );

  let sessionId: string;
  if (existing[0]) {
    sessionId = existing[0].id;
    await db.queryObject(
      `UPDATE attendance_sessions SET status = $2, updated_at = timezone('utc', now())
       WHERE id = $1`,
      [sessionId, input.status],
    );
    await db.queryObject(`DELETE FROM attendance_records WHERE session_id = $1`, [sessionId]);
  } else {
    const rows = await db.queryObject<{ id: string }>(
      `INSERT INTO attendance_sessions (
         organization_id, school_id, class_label, taken_by, status
       ) VALUES ($1, $2, $3, $4, $5)
       RETURNING id`,
      [input.organizationId, input.schoolId, input.classLabel, input.takenBy, input.status],
    );
    sessionId = rows[0]!.id;
  }

  for (const entry of input.entries) {
    await db.queryObject(
      `INSERT INTO attendance_records (
         session_id, organization_id, school_id, student_id, mark
       ) VALUES ($1, $2, $3, $4, $5)`,
      [sessionId, input.organizationId, input.schoolId, entry.studentId, entry.mark],
    );
  }

  return { sessionId, counts: countMarks(input.entries) };
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
    reason: string;
    hasAttachment?: boolean;
    attachmentName?: string | null;
  },
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO mobile_leave_requests (
       organization_id, school_id, requester_user_id, requester_scope,
       student_id, type_label, from_date_label, to_date_label, reason,
       has_attachment, attachment_name
     ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
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
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO homework_submissions (
       organization_id, school_id, student_id, homework_id, notes, attachment_label
     ) VALUES ($1,$2,$3,$4,$5,$6)
     ON CONFLICT (organization_id, school_id, student_id, homework_id)
     DO UPDATE SET notes = EXCLUDED.notes, attachment_label = EXCLUDED.attachment_label,
       status = 'submitted', updated_at = timezone('utc', now())
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
  submissionId: string,
  input: { grade: string; comment: string; reviewerId: string },
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{
    id: string;
    homework_id: string;
    student_id: string;
  }>(
    `UPDATE homework_submissions
     SET status = 'reviewed', grade = $2, comment = $3, reviewed_by = $4,
         updated_at = timezone('utc', now())
     WHERE id = $1::uuid OR (organization_id IS NOT NULL AND homework_id = $1)
     RETURNING id, homework_id, student_id`,
    [submissionId, input.grade, input.comment, input.reviewerId],
  );
  const row = rows[0];
  return {
    submission: {
      id: row?.id ?? submissionId,
      studentName: "Student",
      classLabel: "8-A",
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
     SET marks_obtained = $4, updated_by = $5, updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND id = $3
     RETURNING *`,
    [orgId, schoolId, markEntryId, marksObtained, updatedBy],
  );
  const row = rows[0];
  if (!row) {
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

export async function listTimetableSlots(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  classLabel?: string,
): Promise<Record<string, unknown>[]> {
  const rows = await db.queryObject<{
    day_of_week: number;
    period_number: number;
    subject_label: string;
    room_label: string | null;
    teacher_user_id: string | null;
    substitute_teacher_user_id: string | null;
  }>(
    `SELECT day_of_week, period_number, subject_label, room_label,
            teacher_user_id, substitute_teacher_user_id
     FROM timetable_slots
     WHERE organization_id = $1 AND school_id = $2
       AND ($3::text IS NULL OR class_label = $3)
     ORDER BY day_of_week, period_number`,
    [orgId, schoolId, classLabel ?? null],
  );
  return rows.map((row) => ({
    dayOfWeek: row.day_of_week,
    periodNumber: row.period_number,
    subjectLabel: row.subject_label,
    roomLabel: row.room_label ?? "",
    teacherUserId: row.teacher_user_id,
    substituteTeacherUserId: row.substitute_teacher_user_id,
  }));
}

function markToStatus(mark: string): string {
  if (mark === "absent") return "absent";
  if (mark === "late") return "late";
  if (mark === "excused") return "present";
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
  const recentLogs: Record<string, unknown>[] = [];
  for (const row of rows) {
    if (row.mark === "present" || row.mark === "excused") present += 1;
    else if (row.mark === "absent") absent += 1;
    else if (row.mark === "late") late += 1;
    const date = row.session_date.slice(0, 10);
    recentLogs.push({
      date,
      status: markToStatus(row.mark),
      detail: row.mark === "absent" ? "Marked absent" : "Marked present",
      detailTitle: date,
      detailBody: `Attendance: ${row.mark}`,
    });
  }

  const total = present + absent + late;
  const attendancePercent = total > 0 ? Math.round((present / total) * 100) : 0;
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
  if (rows.length === 0) {
    return snapshot;
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
    summaryLabel: hasOutstanding ? "Outstanding fees" : "Fees",
    totalDue,
    installments,
  };
}
