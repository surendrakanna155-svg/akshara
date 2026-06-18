import type { TenantQueryClient } from "../tenant_db.ts";

export type ExamPhase =
  | "draft"
  | "scheduled"
  | "marks_entry"
  | "processed"
  | "published";

export interface ExamSessionRow {
  id: string;
  organization_id: string;
  school_id: string;
  title: string;
  subject: string;
  grade: string;
  section_name: string;
  term_label: string;
  date_label: string;
  time_label: string;
  venue_label: string;
  syllabus_label: string;
  max_marks: number;
  phase: ExamPhase;
  exam_type: string;
  coordinator_verified_by: string | null;
  coordinator_verified_at: string | null;
  rejection_comment: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface ExamMarkRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  exam_id: string;
  exam_title: string;
  class_label: string;
  marks_obtained: number;
  max_marks: number;
  student_name: string | null;
  roll_number: string | null;
  student_code: string | null;
  published: boolean;
  grade_letter: string | null;
  marks_entered: boolean;
  updated_at: string;
}

export class ExamNotFoundError extends Error {
  constructor(id: string) {
    super(`Exam not found: ${id}`);
    this.name = "ExamNotFoundError";
  }
}

export class ExamValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ExamValidationError";
  }
}

export class ExamApprovalRequiredError extends Error {
  constructor() {
    super("Approved principal approval is required before publishing exam results.");
    this.name = "ExamApprovalRequiredError";
  }
}

export class ExamApprovalMismatchError extends Error {
  constructor() {
    super("Provided approvalId does not match the approved request for this exam.");
    this.name = "ExamApprovalMismatchError";
  }
}

export class ExamMarkNotFoundError extends Error {
  constructor(id: string) {
    super(`Mark entry not found: ${id}`);
    this.name = "ExamMarkNotFoundError";
  }
}

function gradeForPercent(percent: number): string {
  if (percent >= 90) return "A+";
  if (percent >= 80) return "A";
  if (percent >= 70) return "B+";
  if (percent >= 60) return "B";
  if (percent >= 50) return "C";
  if (percent >= 40) return "D";
  return "F";
}

export function examSessionToApi(row: ExamSessionRow): Record<string, unknown> {
  return {
    id: row.id,
    title: row.title,
    subject: row.subject,
    grade: row.grade,
    section: row.section_name,
    termLabel: row.term_label,
    dateLabel: row.date_label,
    timeLabel: row.time_label,
    venueLabel: row.venue_label,
    syllabusLabel: row.syllabus_label,
    maxMarks: row.max_marks,
    phase: row.phase,
    examType: row.exam_type,
    coordinatorVerified: row.coordinator_verified_by != null,
    coordinatorVerifiedBy: row.coordinator_verified_by,
    rejectionComment: row.rejection_comment,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function examMarkToApi(row: ExamMarkRow): Record<string, unknown> {
  return {
    id: row.id,
    examId: row.exam_id,
    sisStudentId: row.student_code ?? row.student_id,
    studentName: row.student_name ?? "",
    rollNo: row.roll_number ?? "",
    marksObtained: row.marks_entered ? row.marks_obtained : null,
    published: row.published,
    grade: row.grade_letter,
    maxMarks: row.max_marks,
  };
}

export function publishedResultToApi(
  row: ExamMarkRow,
  session: ExamSessionRow,
): Record<string, unknown> {
  return {
    markEntryId: row.id,
    sisStudentId: row.student_code ?? row.student_id,
    studentName: row.student_name ?? "",
    examId: session.id,
    examTitle: session.title,
    termLabel: session.term_label,
    dateLabel: session.date_label,
    scoreObtained: row.marks_obtained,
    maxScore: session.max_marks,
    grade: row.grade_letter ?? gradeForPercent(
      session.max_marks > 0 ? (row.marks_obtained / session.max_marks) * 100 : 0,
    ),
    subject: session.subject,
  };
}

export async function listExamSessions(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<ExamSessionRow[]> {
  return await db.queryObject<ExamSessionRow>(
    `SELECT * FROM exam_sessions
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY updated_at DESC`,
    [organizationId, schoolId],
  );
}

export async function getExamSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<ExamSessionRow | null> {
  const rows = await db.queryObject<ExamSessionRow>(
    `SELECT * FROM exam_sessions
     WHERE organization_id = $1 AND school_id = $2 AND id = $3`,
    [organizationId, schoolId, examId],
  );
  return rows[0] ?? null;
}

export interface CreateExamInput {
  title: string;
  subject: string;
  grade: string;
  section: string;
  termLabel: string;
  dateLabel: string;
  timeLabel: string;
  venueLabel: string;
  syllabusLabel: string;
  maxMarks: number;
  examType: string;
  createdBy?: string;
}

export async function createExamSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateExamInput,
): Promise<ExamSessionRow> {
  const countRows = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count FROM exam_sessions
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  const next = (parseInt(countRows[0]?.count ?? "0", 10) || 0) + 1;
  const id = `exam_${next}`;

  const createdBy = input.createdBy &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        input.createdBy,
      )
    ? input.createdBy
    : null;

  const rows = await db.queryObject<ExamSessionRow>(
    `INSERT INTO exam_sessions (
       id, organization_id, school_id, title, subject, grade, section_name,
       term_label, date_label, time_label, venue_label, syllabus_label,
       max_marks, phase, exam_type, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, 'draft', $14, $15)
     RETURNING *`,
    [
      id,
      organizationId,
      schoolId,
      input.title,
      input.subject,
      input.grade,
      input.section,
      input.termLabel,
      input.dateLabel,
      input.timeLabel,
      input.venueLabel,
      input.syllabusLabel,
      input.maxMarks,
      input.examType,
      createdBy,
    ],
  );
  return rows[0]!;
}

async function provisionMarkSlots(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  session: ExamSessionRow,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO exam_mark_entries (
       id, organization_id, school_id, student_id, exam_id, exam_title, class_label,
       marks_obtained, max_marks, student_name, roll_number, student_code, published,
       marks_entered
     )
     SELECT
       $3 || '_' || e.roll_number,
       e.organization_id,
       e.school_id,
       e.student_id,
       $3,
       $4,
       e.class_name || '-' || e.section_name,
       0,
       $5,
       s.display_name,
       e.roll_number,
       s.student_code,
       false,
       false
     FROM sis_student_enrollments e
     JOIN students s ON s.id = e.student_id
     WHERE e.organization_id = $1
       AND e.school_id = $2
       AND e.class_name = $6
       AND e.section_name = $7
       AND e.is_current = true
     ON CONFLICT (id) DO NOTHING`,
    [
      organizationId,
      schoolId,
      session.id,
      session.title,
      session.max_marks,
      session.grade,
      session.section_name,
    ],
  );
}

async function updateExamPhase(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
  phase: ExamPhase,
): Promise<ExamSessionRow> {
  const rows = await db.queryObject<ExamSessionRow>(
    `UPDATE exam_sessions SET phase = $4, updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND id = $3
     RETURNING *`,
    [organizationId, schoolId, examId, phase],
  );
  const row = rows[0];
  if (!row) throw new ExamNotFoundError(examId);
  return row;
}

export async function scheduleExamSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<ExamSessionRow> {
  const session = await getExamSession(db, organizationId, schoolId, examId);
  if (!session) throw new ExamNotFoundError(examId);
  const updated = await updateExamPhase(db, organizationId, schoolId, examId, "scheduled");
  await provisionMarkSlots(db, organizationId, schoolId, updated);
  return updated;
}

export async function openMarksEntry(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<ExamSessionRow> {
  const session = await getExamSession(db, organizationId, schoolId, examId);
  if (!session) throw new ExamNotFoundError(examId);
  const updated = await updateExamPhase(db, organizationId, schoolId, examId, "marks_entry");
  await provisionMarkSlots(db, organizationId, schoolId, updated);
  return updated;
}

export async function listExamMarks(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<ExamMarkRow[]> {
  return await db.queryObject<ExamMarkRow>(
    `SELECT * FROM exam_mark_entries
     WHERE organization_id = $1 AND school_id = $2 AND exam_id = $3
     ORDER BY roll_number NULLS LAST, id`,
    [organizationId, schoolId, examId],
  );
}

export async function updateExamMark(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  markEntryId: string,
  marksObtained: number,
): Promise<ExamMarkRow> {
  const rows = await db.queryObject<ExamMarkRow>(
    `UPDATE exam_mark_entries
     SET marks_obtained = $4,
         marks_entered = true,
         updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND id = $3 AND published = false
     RETURNING *`,
    [organizationId, schoolId, markEntryId, marksObtained],
  );
  const row = rows[0];
  if (!row) throw new ExamMarkNotFoundError(markEntryId);

  await db.queryObject(
    `UPDATE exam_sessions SET coordinator_verified_by = NULL, coordinator_verified_at = NULL
     WHERE organization_id = $1 AND school_id = $2 AND id = $3`,
    [organizationId, schoolId, row.exam_id],
  );
  return row;
}

export async function processExamResults(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<ExamSessionRow> {
  const session = await getExamSession(db, organizationId, schoolId, examId);
  if (!session) throw new ExamNotFoundError(examId);

  const pending = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count FROM exam_mark_entries
     WHERE organization_id = $1 AND school_id = $2 AND exam_id = $3
       AND marks_entered = false`,
    [organizationId, schoolId, examId],
  );
  const pendingCount = parseInt(pending[0]?.count ?? "0", 10);
  if (pendingCount > 0) {
    throw new ExamValidationError(`Marks incomplete: ${pendingCount} students pending`);
  }

  const zeroMarks = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count FROM exam_mark_entries
     WHERE organization_id = $1 AND school_id = $2 AND exam_id = $3`,
    [organizationId, schoolId, examId],
  );
  if (parseInt(zeroMarks[0]?.count ?? "0", 10) === 0) {
    throw new ExamValidationError("No mark slots provisioned for exam");
  }

  return await updateExamPhase(db, organizationId, schoolId, examId, "processed");
}

export async function verifyCoordinatorResults(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
  verifiedBy: string,
): Promise<ExamSessionRow> {
  const session = await getExamSession(db, organizationId, schoolId, examId);
  if (!session) throw new ExamNotFoundError(examId);
  if (session.phase !== "processed") {
    throw new ExamValidationError(
      `Exam must be processed before coordinator verification (current: ${session.phase})`,
    );
  }

  const rows = await db.queryObject<ExamSessionRow>(
    `UPDATE exam_sessions
     SET coordinator_verified_by = $4,
         coordinator_verified_at = timezone('utc', now()),
         rejection_comment = NULL
     WHERE organization_id = $1 AND school_id = $2 AND id = $3
     RETURNING *`,
    [organizationId, schoolId, examId, verifiedBy],
  );
  return rows[0]!;
}

export async function publishExamResults(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<number> {
  const session = await getExamSession(db, organizationId, schoolId, examId);
  if (!session) throw new ExamNotFoundError(examId);

  if (session.phase === "published") {
    const published = await db.queryObject<{ count: string }>(
      `SELECT count(*)::text AS count FROM exam_mark_entries
       WHERE organization_id = $1 AND school_id = $2 AND exam_id = $3 AND published = true`,
      [organizationId, schoolId, examId],
    );
    return parseInt(published[0]?.count ?? "0", 10);
  }

  const marks = await listExamMarks(db, organizationId, schoolId, examId);
  const enterable = marks.filter((m) => m.marks_entered);
  if (enterable.length === 0) {
    throw new ExamValidationError(`No marks entered for exam: ${examId}`);
  }

  let publishedCount = 0;
  for (const mark of enterable) {
    const percent = session.max_marks > 0
      ? (mark.marks_obtained / session.max_marks) * 100
      : 0;
    const gradeLetter = gradeForPercent(percent);
    await db.queryObject(
      `UPDATE exam_mark_entries
       SET published = true, grade_letter = $4, updated_at = timezone('utc', now())
       WHERE organization_id = $1 AND school_id = $2 AND id = $3`,
      [organizationId, schoolId, mark.id, gradeLetter],
    );
    publishedCount++;
  }

  await updateExamPhase(db, organizationId, schoolId, examId, "published");
  return publishedCount;
}

export async function listPublishedResultsForStudent(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentIdOrCode: string,
): Promise<Record<string, unknown>[]> {
  const rows = await db.queryObject<ExamMarkRow & { session_title: string; session_term: string; session_date: string; session_subject: string; session_max: number }>(
    `SELECT m.*, s.title AS session_title, s.term_label AS session_term,
            s.date_label AS session_date, s.subject AS session_subject, s.max_marks AS session_max
     FROM exam_mark_entries m
     JOIN exam_sessions s
       ON s.organization_id = m.organization_id
      AND s.school_id = m.school_id
      AND s.id = m.exam_id
     WHERE m.organization_id = $1
       AND m.school_id = $2
       AND m.published = true
       AND (m.student_code = $3 OR m.student_id::text = $3)`,
    [organizationId, schoolId, studentIdOrCode],
  );

  return rows.map((row) => ({
    markEntryId: row.id,
    sisStudentId: row.student_code ?? row.student_id,
    studentName: row.student_name ?? "",
    examId: row.exam_id,
    examTitle: row.session_title,
    termLabel: row.session_term,
    dateLabel: row.session_date,
    scoreObtained: row.marks_obtained,
    maxScore: row.session_max,
    grade: row.grade_letter ?? gradeForPercent(
      row.session_max > 0 ? (row.marks_obtained / row.session_max) * 100 : 0,
    ),
    subject: row.session_subject,
  }));
}

export async function recordExamRejection(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
  comment: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE exam_sessions
     SET rejection_comment = $4,
         coordinator_verified_by = NULL,
         coordinator_verified_at = NULL,
         updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND id = $3`,
    [organizationId, schoolId, examId, comment],
  );
}
