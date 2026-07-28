import type { TenantQueryClient } from "../tenant_db.ts";
import {
  teacherOwnsClass,
  teacherOwnsClassSubject,
} from "../school_completion/subject_assignments_repository.ts";
import { listTeacherClassLabels, periodTimeRange } from "./pilot_operations_shared.ts";

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

// ─── PRA-P0-11 (S3): per-class ownership guards for the pilot write lane ─────────
//
// The pilot teacher writes (attendance, homework) checked PERMISSION but never
// CLASS OWNERSHIP — any teacher with `markAttendance`/`manageHomework` could
// write to ANY class. These guards close that hole using the canonical binding.
//
// Scope mirrors the certified exam engine's `isSubjectTeacherScoped`: only a
// PLAIN teacher (one WITHOUT `verifyExamResults`) is ownership-scoped; oversight
// roles (superAdmin / schoolAdmin / principal / vicePrincipal / management, who
// hold `verifyExamResults`) may write to any class. Fail-closed for scoped
// teachers — identical to the behaviour already shipping on /academics/exams/*.

/** Raised when an ownership-scoped teacher writes to a class they are not bound to. */
export class ClassOwnershipError extends Error {
  readonly classLabel: string;
  constructor(classLabel: string) {
    super(`You are not assigned to class ${classLabel}`);
    this.name = "ClassOwnershipError";
    this.classLabel = classLabel;
  }
}

/** True when the caller must be ownership-scoped (a plain teacher). */
function isOwnershipScoped(permissions: readonly string[]): boolean {
  return !permissions.includes("verifyExamResults");
}

/**
 * PRA-P0-11 — a plain teacher may only mark attendance for a class they own
 * (teach any subject in, or are the class teacher of). Oversight roles bypass.
 */
export async function assertTeacherOwnsClass(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherUserId: string,
  permissions: readonly string[],
  classLabel: string,
): Promise<void> {
  if (!isOwnershipScoped(permissions)) return;
  const { className, sectionName } = parseClassLabel(classLabel);
  const owns = await teacherOwnsClass(
    db,
    organizationId,
    schoolId,
    teacherUserId,
    className,
    sectionName,
  );
  if (!owns) throw new ClassOwnershipError(classLabel);
}

/**
 * PRA-P0-11 — a plain teacher may only assign homework for a (class, subject)
 * they are assigned to teach. Oversight roles bypass.
 */
export async function assertTeacherOwnsClassSubject(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherUserId: string,
  permissions: readonly string[],
  classLabel: string,
  subject: string,
): Promise<void> {
  if (!isOwnershipScoped(permissions)) return;
  const { className, sectionName } = parseClassLabel(classLabel);
  const owns = await teacherOwnsClassSubject(
    db,
    organizationId,
    schoolId,
    teacherUserId,
    className,
    sectionName,
    subject,
  );
  if (!owns) throw new ClassOwnershipError(classLabel);
}

/**
 * PRA-P0-11 — a plain teacher may only review/grade/notify on a homework they
 * OWN (created). `teacher_entities` records the assignment with the owning
 * `teacher_id`; the id may arrive as a homework_submissions.id or the homework_id
 * itself, so we resolve either to the homework_id first. Oversight roles bypass.
 */
export async function assertTeacherOwnsHomework(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherUserId: string,
  permissions: readonly string[],
  submissionOrHomeworkId: string,
): Promise<void> {
  if (!isOwnershipScoped(permissions)) return;
  const rows = await db.queryObject<{ owns: boolean }>(
    `SELECT EXISTS (
        SELECT 1
        FROM teacher_entities te
        WHERE te.organization_id = $1 AND te.school_id = $2
          AND te.entity_type = 'homework_assignment'
          AND te.teacher_id = $3
          AND (
            te.id = $4
            OR te.id IN (
              SELECT hs.homework_id FROM homework_submissions hs
              WHERE hs.organization_id = $1 AND hs.school_id = $2
                AND (hs.id::text = $4 OR hs.homework_id = $4)
            )
          )
     ) AS owns`,
    [organizationId, schoolId, teacherUserId, submissionOrHomeworkId],
  );
  if (rows[0]?.owns !== true) throw new ClassOwnershipError(submissionOrHomeworkId);
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
