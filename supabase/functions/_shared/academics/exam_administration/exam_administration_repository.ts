import type { TenantQueryClient } from "../../tenant_db.ts";

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
  // EXM-6 — optional soft deadline for entering marks. NULL when unset. The
  // teacher reminder rides a future reminder-rule engine (XCT-2), not here.
  marks_entry_deadline: string | null;
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
  // EXM-D6 — NULL for a non-'present' student (absent / medical_leave /
  // debarred): they have no meaningful score. A present student always has a
  // (bounds-checked) integer once entered.
  marks_obtained: number | null;
  // EXM-D2 — the EFFECTIVE (original + grace) mark, baked ONLY at publish. NULL
  // until published / for a non-present student. The ORIGINAL marks_obtained is
  // never overwritten; parents/students read effective_marks (no grace breakdown).
  // Optional on the TS type (older fixtures / pre-migration rows omit it); the
  // read paths always fall back to `?? marks_obtained`.
  effective_marks?: number | null;
  max_marks: number;
  student_name: string | null;
  roll_number: string | null;
  student_code: string | null;
  published: boolean;
  grade_letter: string | null;
  marks_entered: boolean;
  // EXM-D6 — attendance status for this student's exam entry. 'present' is the
  // default; a non-'present' status ("absent" / "medical_leave" / "debarred") is
  // shown as "AB" and EXCLUDED from the average and class rank. marks_obtained is
  // kept (0 for an absent row) but ignored for stats by this status.
  status: ExamMarkStatus;
  updated_at: string;
  // Optimistic-concurrency version, bumped on every update (Data Reliability
  // Platform §8.2). Lets a queued offline edit detect that the row changed
  // underneath it (409 CONFLICT carrying this row).
  row_version: number;
}

/** EXM-D6 — allowed exam attendance statuses (mirrors the DB CHECK constraint). */
export type ExamMarkStatus =
  | "present"
  | "absent"
  | "medical_leave"
  | "debarred";

export const EXAM_MARK_STATUSES: readonly ExamMarkStatus[] = [
  "present",
  "absent",
  "medical_leave",
  "debarred",
] as const;

export function isExamMarkStatus(value: unknown): value is ExamMarkStatus {
  return typeof value === "string" &&
    (EXAM_MARK_STATUSES as readonly string[]).includes(value);
}

/**
 * EXM-D6 — display code for a non-present exam status shown on the report card /
 * result cell in place of a grade. A present student uses their computed grade,
 * so has no code here.
 */
export function examStatusDisplayCode(status: ExamMarkStatus): string | null {
  switch (status) {
    case "absent":
      return "AB";
    case "medical_leave":
      return "ML";
    case "debarred":
      return "DB";
    case "present":
      return null;
  }
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

/**
 * Gap-sweep wave 2 · step 2 (security hardening) — raised when a caller asks
 * to publish results WITHOUT the verify→approve chain (`requireApproval:
 * false`) but does not hold the dedicated `overridePublishApproval`
 * permission. Distinct from {@link ExamApprovalRequiredError} (a missing
 * APPROVAL): this is a missing PERMISSION — skipping governance is a more
 * privileged action than a normal `publishExamResults` grant, so it is gated
 * on its own senior-only slug (superAdmin/schoolAdmin/principal).
 */
export class ExamPublishOverrideForbiddenError extends Error {
  constructor() {
    super(
      "Publishing without the verify→approve chain requires the overridePublishApproval permission.",
    );
    this.name = "ExamPublishOverrideForbiddenError";
  }
}

export class ExamMarkNotFoundError extends Error {
  constructor(id: string) {
    super(`Mark entry not found: ${id}`);
    this.name = "ExamMarkNotFoundError";
  }
}

/**
 * Optimistic-concurrency conflict on a mark entry (Data Reliability Platform
 * §8.2): the client's queued edit was based on an older `row_version`. Carries
 * the current server row so the client can show "yours vs theirs" / re-apply.
 */
export class ExamMarkConflictError extends Error {
  constructor(id: string, readonly currentRow: ExamMarkRow) {
    super(`Mark entry changed since last read: ${id}`);
    this.name = "ExamMarkConflictError";
  }
}

/** Raised when a subject teacher touches marks for a class/subject they do not teach (P2). */
export class ExamScopeForbiddenError extends Error {
  constructor(
    message = "You are not assigned to this exam's subject and class.",
  ) {
    super(message);
    this.name = "ExamScopeForbiddenError";
  }
}

/**
 * PRA-P1-13 — one row of a grading scale: any percentage `>= minPercent` earns
 * [letter]. Bands are held highest-threshold-first.
 */
export interface GradeBand {
  minPercent: number;
  letter: string;
}

/**
 * PRA-P1-13 — the compiled LEGACY grading scale, kept EXACTLY as the old
 * hardcoded `gradeForPercent` (>=90 A+, >=80 A, >=70 B+, >=60 B, >=50 C, >=40 D,
 * else F). Used as the fallback when a school has NOT configured its own scale,
 * so an unconfigured school sees ZERO behaviour change at publish/report time.
 */
export const DEFAULT_GRADE_BANDS: readonly GradeBand[] = [
  { minPercent: 90, letter: "A+" },
  { minPercent: 80, letter: "A" },
  { minPercent: 70, letter: "B+" },
  { minPercent: 60, letter: "B" },
  { minPercent: 50, letter: "C" },
  { minPercent: 40, letter: "D" },
  { minPercent: 0, letter: "F" },
];

/**
 * Grade letter for [percent] (0–100) using [bands] (highest threshold first).
 * Defaults to {@link DEFAULT_GRADE_BANDS} so every call site that has not resolved
 * a school scale reproduces the previous fixed output verbatim.
 */
export function gradeForPercent(
  percent: number,
  bands: readonly GradeBand[] = DEFAULT_GRADE_BANDS,
): string {
  for (const band of bands) {
    if (percent >= band.minPercent) return band.letter;
  }
  return bands.length > 0 ? bands[bands.length - 1]!.letter : "";
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
    // EXM-6 — surfaced on the exam DTO; null when no deadline is set.
    marksEntryDeadline: row.marks_entry_deadline,
    coordinatorVerified: row.coordinator_verified_by != null,
    coordinatorVerifiedBy: row.coordinator_verified_by,
    rejectionComment: row.rejection_comment,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function examMarkToApi(row: ExamMarkRow): Record<string, unknown> {
  const status: ExamMarkStatus = isExamMarkStatus(row.status)
    ? row.status
    : "present";
  return {
    id: row.id,
    examId: row.exam_id,
    sisStudentId: row.student_code ?? row.student_id,
    studentName: row.student_name ?? "",
    rollNo: row.roll_number ?? "",
    // A non-present student has NULL marks (the client renders the display code
    // AB/ML/DB). A present student shows entered marks once entered.
    marksObtained: status === "present"
      ? (row.marks_entered ? row.marks_obtained : null)
      : null,
    published: row.published,
    grade: row.grade_letter,
    maxMarks: row.max_marks,
    status,
    // Display code for a non-present status (AB/ML/DB), null for present.
    statusCode: examStatusDisplayCode(status),
    rowVersion: row.row_version,
  };
}

export function publishedResultToApi(
  row: ExamMarkRow,
  session: ExamSessionRow,
  // PRA-P1-13 — resolved grading bands; defaults to the legacy scale so an
  // unconfigured school is unchanged.
  bands: readonly GradeBand[] = DEFAULT_GRADE_BANDS,
): Record<string, unknown> {
  const status: ExamMarkStatus = isExamMarkStatus(row.status)
    ? row.status
    : "present";
  // 🔴 EXM-D2 — parents/students see the EFFECTIVE (grace-applied) score, never
  // the original + the adjustment breakdown. effective_marks is baked at publish;
  // fall back to marks_obtained for pre-grace / legacy rows.
  const effective = status === "present"
    ? (row.effective_marks ?? row.marks_obtained)
    : null;
  return {
    markEntryId: row.id,
    sisStudentId: row.student_code ?? row.student_id,
    studentName: row.student_name ?? "",
    examId: session.id,
    examTitle: session.title,
    termLabel: session.term_label,
    dateLabel: session.date_label,
    // NULL for a non-present student — the client renders the display code
    // instead of a score.
    scoreObtained: effective,
    maxScore: session.max_marks,
    grade: row.grade_letter ?? (effective != null
      ? gradeForPercent(
        session.max_marks > 0 ? (effective / session.max_marks) * 100 : 0,
        bands,
      )
      : (examStatusDisplayCode(status) ?? "")),
    status,
    statusCode: examStatusDisplayCode(status),
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
  // EXM-6 — optional ISO-8601 marks-entry deadline (null when unset).
  marksEntryDeadline?: string | null;
}

export async function createExamSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateExamInput,
): Promise<ExamSessionRow> {
  // RT-05: a `count(*)+1` id raced to primary-key (org, school, id) conflicts
  // under concurrent exam creation (two callers compute the same `exam_<n>` →
  // one 500s / a duplicate is created). A UUID-suffixed id is collision-free
  // without a lock.
  const id = `exam_${crypto.randomUUID()}`;

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
       max_marks, phase, exam_type, created_by, marks_entry_deadline
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, 'draft', $14, $15, $16)
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
      input.marksEntryDeadline ?? null,
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
       -- Key the mark-entry id on student_id (always present + unique per
       -- exam+student), NOT roll_number: roll_number is optional on import, and
       -- concatenating a NULL roll_number produced a NULL id -> a NOT-NULL
       -- violation that 500'd open-marks for the WHOLE class when any student
       -- lacked a roll number. Still deterministic, so ON CONFLICT (id) keeps
       -- re-provision idempotent.
       $3 || '_' || e.student_id::text,
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
  // EXM-6 — when provided, (re)sets the marks-entry deadline as part of
  // scheduling. `undefined` leaves the existing value untouched; an explicit
  // `null` clears it.
  marksEntryDeadline?: string | null,
): Promise<ExamSessionRow> {
  const session = await getExamSession(db, organizationId, schoolId, examId);
  if (!session) throw new ExamNotFoundError(examId);
  if (marksEntryDeadline !== undefined) {
    await setMarksEntryDeadline(
      db,
      organizationId,
      schoolId,
      examId,
      marksEntryDeadline,
    );
  }
  const updated = await updateExamPhase(db, organizationId, schoolId, examId, "scheduled");
  await provisionMarkSlots(db, organizationId, schoolId, updated);
  return updated;
}

/**
 * EXM-6 — sets (or clears, with null) an exam's marks-entry deadline. Does NOT
 * touch phase; used by scheduleExamSession and callable standalone.
 */
export async function setMarksEntryDeadline(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
  marksEntryDeadline: string | null,
): Promise<ExamSessionRow> {
  const rows = await db.queryObject<ExamSessionRow>(
    `UPDATE exam_sessions
     SET marks_entry_deadline = $4, updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND id = $3
     RETURNING *`,
    [organizationId, schoolId, examId, marksEntryDeadline],
  );
  const row = rows[0];
  if (!row) throw new ExamNotFoundError(examId);
  return row;
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

export async function getExamMark(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  markEntryId: string,
): Promise<ExamMarkRow | null> {
  const rows = await db.queryObject<ExamMarkRow>(
    `SELECT * FROM exam_mark_entries
     WHERE organization_id = $1 AND school_id = $2 AND id = $3`,
    [organizationId, schoolId, markEntryId],
  );
  return rows[0] ?? null;
}

/**
 * P2 — whether a subject teacher is assigned to teach an exam's subject for its
 * class + section. Bridges the text-based exam_sessions (subject/grade/section_name)
 * to the UUID-keyed academic structure by name, the same way mark slots are
 * provisioned (class_name = grade, section_name). Only active assignments count.
 */
export async function teacherTeachesExamSession(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherUserId: string,
  session: ExamSessionRow,
): Promise<boolean> {
  const rows = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count
     FROM teacher_subject_assignments tsa
     JOIN academic_subjects subj ON subj.id = tsa.subject_id
     JOIN classes c ON c.id = tsa.class_id
     JOIN sections sec ON sec.id = tsa.section_id
     WHERE tsa.organization_id = $1
       AND tsa.school_id = $2
       AND tsa.teacher_user_id = $3
       AND tsa.status = 'active'
       AND subj.subject_name = $4
       AND c.class_name = $5
       AND sec.section_name = $6`,
    [
      organizationId,
      schoolId,
      teacherUserId,
      session.subject,
      session.grade,
      session.section_name,
    ],
  );
  return parseInt(rows[0]?.count ?? "0", 10) > 0;
}

export async function updateExamMark(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  markEntryId: string,
  marksObtained: number,
  expectedVersion?: number | null,
  status: ExamMarkStatus = "present",
): Promise<ExamMarkRow> {
  // Optimistic concurrency (Data Reliability Platform §8.2): when the client
  // sends the row_version its edit was based on, reject with the current row if
  // it has since changed, so the platform can resolve the conflict (low-risk
  // last-write-wins re-applies with the new version; high-risk parks it).
  if (expectedVersion != null) {
    const current = await getExamMark(db, organizationId, schoolId, markEntryId);
    if (!current) throw new ExamMarkNotFoundError(markEntryId);
    if (Number(current.row_version) !== Number(expectedVersion)) {
      throw new ExamMarkConflictError(markEntryId, current);
    }
  }
  // EXM-D6 — a non-'present' status (absent / medical_leave / debarred) has NO
  // meaningful score: force marks_obtained = NULL regardless of any supplied
  // number. A present student keeps their (bounds-checked) integer. In BOTH
  // cases marks_entered = true, so a non-present student satisfies the "all
  // marks entered" process-gate (they are not pending).
  const persistedMarks: number | null = status === "present"
    ? marksObtained
    : null;
  // The `bump_row_version` BEFORE-UPDATE trigger increments row_version; the
  // RETURNING row therefore carries the new version.
  const rows = await db.queryObject<ExamMarkRow>(
    `UPDATE exam_mark_entries
     SET marks_obtained = $4,
         marks_entered = true,
         status = $5,
         updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND id = $3 AND published = false
     RETURNING *`,
    [organizationId, schoolId, markEntryId, persistedMarks, status],
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

/**
 * EXM-2 — marks-entry progress for a school. One row per exam CURRENTLY in the
 * `marks_entry` phase, with how many of its provisioned mark slots are "entered".
 *
 * "Entered" = `marks_entered = true`, which the repository sets for BOTH a
 * present student with a saved mark AND a non-present (AB/ML/DB) student (see
 * updateExamMark). So a coordinator's `pending` count is exactly the students
 * who still owe a decision before the exam can be processed.
 */
export interface MarksEntryProgressRow {
  exam_id: string;
  title: string;
  subject: string;
  grade: string;
  section_name: string;
  entered_count: number;
  total_count: number;
  // EXM-6 — the exam's marks-entry deadline (null when unset), so the progress
  // board / marks-entry banner can flag exams approaching / past their deadline.
  marks_entry_deadline: string | null;
}

export async function listMarksEntryProgress(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<MarksEntryProgressRow[]> {
  const rows = await db.queryObject<{
    exam_id: string;
    title: string;
    subject: string;
    grade: string;
    section_name: string;
    entered_count: string;
    total_count: string;
    marks_entry_deadline: string | null;
  }>(
    `SELECT es.id AS exam_id,
            es.title AS title,
            es.subject AS subject,
            es.grade AS grade,
            es.section_name AS section_name,
            es.marks_entry_deadline AS marks_entry_deadline,
            count(m.id) FILTER (WHERE m.marks_entered = true)::text AS entered_count,
            count(m.id)::text AS total_count
       FROM exam_sessions es
       LEFT JOIN exam_mark_entries m
         ON m.organization_id = es.organization_id
        AND m.school_id = es.school_id
        AND m.exam_id = es.id
      WHERE es.organization_id = $1
        AND es.school_id = $2
        AND es.phase = 'marks_entry'
      GROUP BY es.id, es.title, es.subject, es.grade, es.section_name, es.marks_entry_deadline, es.updated_at
      ORDER BY es.updated_at DESC`,
    [organizationId, schoolId],
  );
  return rows.map((row) => ({
    exam_id: row.exam_id,
    title: row.title,
    subject: row.subject,
    grade: row.grade,
    section_name: row.section_name,
    entered_count: parseInt(row.entered_count ?? "0", 10),
    total_count: parseInt(row.total_count ?? "0", 10),
    marks_entry_deadline: row.marks_entry_deadline,
  }));
}

export function marksEntryProgressToApi(
  row: MarksEntryProgressRow,
): Record<string, unknown> {
  const entered = row.entered_count;
  const total = row.total_count;
  return {
    examId: row.exam_id,
    title: row.title,
    subject: row.subject,
    grade: row.grade,
    sectionName: row.section_name,
    enteredCount: entered,
    totalCount: total,
    pending: Math.max(0, total - entered),
    // EXM-6 — deadline surfaced on the progress payload (null when unset).
    marksEntryDeadline: row.marks_entry_deadline,
  };
}

export interface OverdueMarksEntryRow {
  exam_id: string;
  title: string;
  subject: string;
  grade: string;
  section_name: string;
  marks_entry_deadline: string;
  entered_count: number;
  total_count: number;
}

/**
 * EXM-6 — exams still in the `marks_entry` phase whose `marks_entry_deadline`
 * has PASSED (`< asOfIso`) and that still have unentered marks. This is the set
 * a teacher reminder is raised for; an exam with no deadline, no pending marks,
 * or a future deadline is excluded. Ordered oldest-overdue first.
 */
export async function listOverdueMarksEntry(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  asOfIso: string,
): Promise<OverdueMarksEntryRow[]> {
  const rows = await db.queryObject<{
    exam_id: string;
    title: string;
    subject: string;
    grade: string;
    section_name: string;
    marks_entry_deadline: string;
    entered_count: string;
    total_count: string;
  }>(
    `SELECT es.id AS exam_id,
            es.title AS title,
            es.subject AS subject,
            es.grade AS grade,
            es.section_name AS section_name,
            es.marks_entry_deadline AS marks_entry_deadline,
            count(m.id) FILTER (WHERE m.marks_entered = true)::text AS entered_count,
            count(m.id)::text AS total_count
       FROM exam_sessions es
       LEFT JOIN exam_mark_entries m
         ON m.organization_id = es.organization_id
        AND m.school_id = es.school_id
        AND m.exam_id = es.id
      WHERE es.organization_id = $1
        AND es.school_id = $2
        AND es.phase = 'marks_entry'
        AND es.marks_entry_deadline IS NOT NULL
        AND es.marks_entry_deadline < $3::timestamptz
      GROUP BY es.id, es.title, es.subject, es.grade, es.section_name, es.marks_entry_deadline
      HAVING count(m.id) > count(m.id) FILTER (WHERE m.marks_entered = true)
      ORDER BY es.marks_entry_deadline ASC`,
    [organizationId, schoolId, asOfIso],
  );
  return rows.map((row) => ({
    exam_id: row.exam_id,
    title: row.title,
    subject: row.subject,
    grade: row.grade,
    section_name: row.section_name,
    marks_entry_deadline: row.marks_entry_deadline,
    entered_count: parseInt(row.entered_count ?? "0", 10),
    total_count: parseInt(row.total_count ?? "0", 10),
  }));
}

/**
 * EXM-1 — outcome of applying one entry inside a bulk save. A row that is
 * rejected (published, not found, out of bounds, bad status, or a concurrency
 * conflict) is reported in `failed` and never mutates; the remaining entries
 * still apply (partial success).
 */
export interface BulkMarkEntryInput {
  id: string;
  marksObtained: number | null;
  status?: ExamMarkStatus;
  expectedVersion?: number | null;
}

export interface BulkMarkUpdateResult {
  updated: ExamMarkRow[];
  failed: Array<{ id: string; reason: string }>;
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

  // RT round-3 RT-6-1: publish must NOT strand students. processExamResults
  // enforces completeness before advancing to 'processed', but the publish path is
  // ALSO reachable via the generic approval endpoint (bypassing processExamResults),
  // and had no such gate — so an incomplete exam could publish only the entered
  // subset and flip to 'published', permanently excluding students whose marks were
  // never entered (there is no republish path once phase='published'). Enforce the
  // same completeness invariant here: every provisioned mark slot must be entered
  // (a present student's marks, or an AB/ML/DB status) before results go out.
  const pending = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count FROM exam_mark_entries
     WHERE organization_id = $1 AND school_id = $2 AND exam_id = $3
       AND marks_entered = false`,
    [organizationId, schoolId, examId],
  );
  const pendingCount = parseInt(pending[0]?.count ?? "0", 10);
  if (pendingCount > 0) {
    throw new ExamValidationError(
      `Cannot publish: ${pendingCount} student(s) have no marks entered`,
    );
  }

  const marks = await listExamMarks(db, organizationId, schoolId, examId);
  const enterable = marks.filter((m) => m.marks_entered);
  if (enterable.length === 0) {
    throw new ExamValidationError(`No marks entered for exam: ${examId}`);
  }

  // PRA-P1-13 — resolve the school's grading scale ONCE, then bake every letter
  // grade against it. Falls back to the legacy bands when the school has no row,
  // so an unconfigured school publishes identical grades to before.
  const gradeScale = await loadGradeScale(db, organizationId, schoolId);

  let publishedCount = 0;
  for (const mark of enterable) {
    // EXM-D6 — a non-'present' student publishes with their display code
    // (AB/ML/DB), not a computed letter grade. A present student's grade is
    // derived from their EFFECTIVE (original + grace) marks.
    const status: ExamMarkStatus = isExamMarkStatus(mark.status)
      ? mark.status
      : "present";
    // 🔴 EXM-D2 — bake the effective mark = clamp(original + Σgrace, 0, max).
    // The ORIGINAL marks_obtained is NEVER overwritten (audit-safe); the grade +
    // the parent-visible effective_marks reflect grace, WITHOUT the breakdown.
    let effectiveMark: number | null = null;
    if (status === "present" && mark.marks_obtained != null) {
      const totalDelta = await sumAdjustments(
        db,
        organizationId,
        schoolId,
        examId,
        mark.student_id,
      );
      effectiveMark = clampEffectiveMark(
        mark.marks_obtained + totalDelta,
        mark.max_marks,
      );
    }
    const percent = session.max_marks > 0 && effectiveMark != null
      ? (effectiveMark / session.max_marks) * 100
      : 0;
    const gradeLetter = status === "present"
      ? gradeForPercent(percent, gradeScale.bands)
      : examStatusDisplayCode(status)!;
    await db.queryObject(
      `UPDATE exam_mark_entries
       SET published = true, grade_letter = $4, effective_marks = $5,
           updated_at = timezone('utc', now())
       WHERE organization_id = $1 AND school_id = $2 AND id = $3`,
      [organizationId, schoolId, mark.id, gradeLetter, effectiveMark],
    );
    publishedCount++;
  }

  await updateExamPhase(db, organizationId, schoolId, examId, "published");
  return publishedCount;
}

/**
 * PRA-P1-12: reopen a PUBLISHED exam so a wrong mark can be corrected (or a
 * re-evaluation / supplementary applied) and then re-published. Previously
 * publish was one-way — the `AND published = false` fence in {@link updateExamMark}
 * made every mark immutable forever, so a single error found after publish was
 * uncorrectable in-system. This clears the `published` flag and the BAKED
 * grade/effective marks (the ORIGINAL `marks_obtained` is never touched — the
 * grace ledger stays intact and re-bakes on the next publish) and moves the phase
 * back to `processed`, at which point marks are editable again through the normal
 * per-mark path. Returns the number of rows reopened. Senior-gated at the handler.
 */
export async function unpublishExamResults(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<number> {
  const session = await getExamSession(db, organizationId, schoolId, examId);
  if (!session) throw new ExamNotFoundError(examId);
  if (session.phase !== "published") {
    throw new ExamValidationError(
      `Exam ${examId} is not published (phase: ${session.phase}); nothing to reopen.`,
    );
  }
  const reopened = await db.queryObject<{ id: string }>(
    `UPDATE exam_mark_entries
       SET published = false, grade_letter = NULL, effective_marks = NULL,
           updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND exam_id = $3 AND published = true
     RETURNING id`,
    [organizationId, schoolId, examId],
  );
  await updateExamPhase(db, organizationId, schoolId, examId, "processed");
  return reopened.length;
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

  // PRA-P1-13 — resolve the school scale once so any grade derived on read
  // (legacy rows without a baked grade_letter) honours the school's bands.
  const gradeScale = await loadGradeScale(db, organizationId, schoolId);

  return rows.map((row) => {
    const status: ExamMarkStatus = isExamMarkStatus(row.status)
      ? row.status
      : "present";
    // 🔴 EXM-D2 — surface the EFFECTIVE (grace-applied) score to parent/student,
    // never the original + the per-delta breakdown.
    const effective = status === "present"
      ? (row.effective_marks ?? row.marks_obtained)
      : null;
    return {
    markEntryId: row.id,
    sisStudentId: row.student_code ?? row.student_id,
    studentName: row.student_name ?? "",
    examId: row.exam_id,
    examTitle: row.session_title,
    termLabel: row.session_term,
    dateLabel: row.session_date,
    scoreObtained: effective,
    maxScore: row.session_max,
    status,
    statusCode: examStatusDisplayCode(status),
    grade: row.grade_letter ?? (effective != null
      ? gradeForPercent(
        row.session_max > 0 ? (effective / row.session_max) * 100 : 0,
        gradeScale.bands,
      )
      : (examStatusDisplayCode(status) ?? "")),
    subject: row.session_subject,
    };
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// EXM-3 / EXM-4 / EXM-5 / EXM-7 — read-only exam reports.
//
// 🔴 CRITICAL correctness rule (frozen): a row whose status != 'present'
// (marks_obtained IS NULL; codes AB/ML/DB) is EXCLUDED from every statistic —
// totals, averages, percent, ranking, pass/fail, and grade distribution — and
// is only ever DISPLAYED via its status code, never counted. This mirrors the
// Flutter reference semantics in lib/core/exams/exam_report_card.dart
// (`countsTowardStats` / `_classRank`). The SQL below enforces this by:
//   • aggregating totals/averages ONLY over `status = 'present'` rows, and
//   • ranking students by present-only totals (a fully-non-present student is
//     NOT ranked and never shifts another student's rank).
// A published (or processed) exam contributes its marks; unpublished/draft
// exams never leak into a report.
// ═══════════════════════════════════════════════════════════════════════════

/** Term exams considered "reportable": published OR processed (verified). */
const REPORTABLE_PHASES = ["published", "processed"] as const;

/** Default pass threshold (%) when no school setting exists — see EXM-5. */
export const DEFAULT_PASS_MARK_PERCENT = 40;

// ═══════════════════════════════════════════════════════════════════════════
// PRA-P1-13 — per-school grade scale (grading bands + pass mark).
//
// The scale is stored in `exam_grade_scales` (one row per school) and is
// AUTHORITATIVE at publish + report time. When a school has NO row, every read
// resolves to {@link DEFAULT_GRADE_BANDS} + {@link DEFAULT_PASS_MARK_PERCENT},
// which reproduces the legacy hardcoded scale EXACTLY — so a school that never
// configures a scale has zero behaviour change.
// ═══════════════════════════════════════════════════════════════════════════

/** A grading scale resolved for a school (its own row, or the legacy default). */
export interface ResolvedGradeScale {
  scaleCode: string | null;
  bands: readonly GradeBand[];
  passMarkPercent: number;
  source: "school" | "default";
}

/** The legacy scale, resolved — used whenever a school has no configured row. */
export function defaultGradeScale(): ResolvedGradeScale {
  return {
    scaleCode: null,
    bands: DEFAULT_GRADE_BANDS,
    passMarkPercent: DEFAULT_PASS_MARK_PERCENT,
    source: "default",
  };
}

/**
 * Coerce the persisted `bands` JSONB (or client input) into an ordered
 * (descending) list of {@link GradeBand}. Invalid rows are dropped; the result
 * is re-sorted highest-threshold-first so grading is deterministic regardless of
 * stored order.
 */
function normalizeBands(raw: unknown): GradeBand[] {
  if (!Array.isArray(raw)) return [];
  const bands: GradeBand[] = [];
  for (const entry of raw) {
    if (typeof entry !== "object" || entry === null) continue;
    const record = entry as Record<string, unknown>;
    const min = Number(record.minPercent ?? record.min_percent);
    const letter = String(record.letter ?? record.label ?? "").trim();
    if (!Number.isFinite(min) || min < 0 || min > 100 || letter.length === 0) {
      continue;
    }
    bands.push({ minPercent: min, letter });
  }
  bands.sort((a, b) => b.minPercent - a.minPercent);
  return bands;
}

/**
 * Load the school's grade scale, falling back to the legacy default when no row
 * exists (or the stored bands are unusable). One SELECT — callers resolve it
 * once per publish/report.
 */
export async function loadGradeScale(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<ResolvedGradeScale> {
  const rows = await db.queryObject<{
    scale_code: string | null;
    bands: unknown;
    pass_mark_percent: number | string;
  }>(
    `SELECT scale_code, bands, pass_mark_percent
       FROM exam_grade_scales
      WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  const row = rows[0];
  if (!row) return defaultGradeScale();

  const bands = normalizeBands(row.bands);
  if (bands.length === 0) return defaultGradeScale();

  const passMark = Number(row.pass_mark_percent);
  return {
    scaleCode: row.scale_code,
    bands,
    passMarkPercent: Number.isFinite(passMark)
      ? passMark
      : DEFAULT_PASS_MARK_PERCENT,
    source: "school",
  };
}

/** A validated grade-scale save request (from the PUT endpoint). */
export interface GradeScaleInput {
  scaleCode: string;
  bands: GradeBand[];
  passMarkPercent: number;
}

/**
 * Validate a client grade-scale payload (PUT /academics/exams/grade-scale).
 * Enforces: a non-empty band list; each band a percentage in 0–100 with a
 * non-empty letter; STRICTLY DESCENDING minPercent (no duplicates); and a pass
 * mark in 0–100. Throws {@link ExamValidationError} (→ 422) on any violation so
 * a malformed scale can never be persisted.
 */
export function parseGradeScaleInput(
  body: Record<string, unknown>,
): GradeScaleInput {
  const rawBands = body.bands;
  if (!Array.isArray(rawBands) || rawBands.length === 0) {
    throw new ExamValidationError("bands must be a non-empty array");
  }
  const bands: GradeBand[] = [];
  for (const entry of rawBands) {
    if (typeof entry !== "object" || entry === null) {
      throw new ExamValidationError("each band must be an object");
    }
    const record = entry as Record<string, unknown>;
    const min = Number(record.minPercent ?? record.min_percent);
    const letter = String(record.letter ?? record.label ?? "").trim();
    if (!Number.isFinite(min) || min < 0 || min > 100) {
      throw new ExamValidationError(
        "each band minPercent must be a number in 0–100",
      );
    }
    if (letter.length === 0) {
      throw new ExamValidationError("each band letter must be non-empty");
    }
    bands.push({ minPercent: min, letter });
  }
  // Reject anything not strictly descending (each threshold below the previous):
  // an out-of-order or duplicate band would silently shadow another grade.
  for (let i = 1; i < bands.length; i++) {
    if (bands[i]!.minPercent >= bands[i - 1]!.minPercent) {
      throw new ExamValidationError(
        "bands must be ordered by strictly descending minPercent",
      );
    }
  }

  const passRaw = body.passMarkPercent ?? body.pass_mark_percent ??
    DEFAULT_PASS_MARK_PERCENT;
  const passMarkPercent = Number(passRaw);
  if (!Number.isFinite(passMarkPercent) || passMarkPercent < 0 ||
    passMarkPercent > 100) {
    throw new ExamValidationError("passMarkPercent must be a number in 0–100");
  }

  const scaleCode =
    String(body.scaleCode ?? body.scale_code ?? "custom").trim() || "custom";

  return { scaleCode, bands, passMarkPercent };
}

/**
 * Upsert the school's grade scale (one row per school). Stores the validated
 * bands verbatim (descending) and returns the resolved scale the client reads
 * back. `actorId` is recorded as created_by/updated_by for the audit trail.
 */
export async function saveGradeScale(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: GradeScaleInput,
  actorId: string | null,
): Promise<ResolvedGradeScale> {
  const bandsJson = JSON.stringify(
    input.bands.map((b) => ({ minPercent: b.minPercent, letter: b.letter })),
  );
  await db.queryObject(
    `INSERT INTO exam_grade_scales
       (organization_id, school_id, scale_code, bands, pass_mark_percent,
        created_by, updated_by)
     VALUES ($1, $2, $3, $4::jsonb, $5, $6, $6)
     ON CONFLICT (organization_id, school_id) DO UPDATE
       SET scale_code = EXCLUDED.scale_code,
           bands = EXCLUDED.bands,
           pass_mark_percent = EXCLUDED.pass_mark_percent,
           updated_by = EXCLUDED.updated_by`,
    [
      organizationId,
      schoolId,
      input.scaleCode,
      bandsJson,
      input.passMarkPercent,
      actorId,
    ],
  );
  return {
    scaleCode: input.scaleCode,
    bands: input.bands,
    passMarkPercent: input.passMarkPercent,
    source: "school",
  };
}

/** Serialise a resolved grade scale for the API (GET/PUT response). */
export function gradeScaleToApi(
  scale: ResolvedGradeScale,
): Record<string, unknown> {
  return {
    scaleCode: scale.scaleCode,
    source: scale.source,
    passMarkPercent: scale.passMarkPercent,
    bands: scale.bands.map((b) => ({
      minPercent: b.minPercent,
      letter: b.letter,
    })),
  };
}

// --- EXM-3 — Tabulation register (students × subjects for a class + term) ---

export interface TabulationSubjectResult {
  subject: string;
  // Marks the student scored in that subject, or null for a non-present row.
  marks: number | null;
  maxMarks: number;
  // Display code (AB/ML/DB) for a non-present row, else null. NEVER counted.
  statusCode: string | null;
}

export interface TabulationStudentRow {
  studentId: string;
  studentCode: string;
  studentName: string;
  rollNumber: string | null;
  // Per-subject results keyed by subject (present marks or an AB/ML/DB code).
  perSubject: Record<string, TabulationSubjectResult>;
  // Totals over PRESENT subjects only.
  total: number;
  totalMax: number;
  percent: number;
  // 1-based rank by present-only total %, or null when the student is not ranked
  // (no present result this term).
  rank: number | null;
}

export interface TabulationRegister {
  classLabel: string;
  term: string;
  // Subject columns in a stable order (first-seen order across the term's exams).
  subjects: string[];
  students: TabulationStudentRow[];
}

/**
 * EXM-3 — tabulation register: every student in [classLabel] across the term's
 * reportable exams, one column per subject. Present marks aggregate into a total,
 * percent + rank; a non-present cell (AB/ML/DB) shows its code and is EXCLUDED
 * from the student's total / percent / rank.
 *
 * `classLabel` is "<grade>-<section>" (e.g. "8-A"), matching the mark-entry
 * class_label; a plain grade (e.g. "8") matches all sections of that grade.
 */
export async function loadTabulationRegister(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  classLabel: string,
  term: string,
): Promise<TabulationRegister> {
  const rows = await db.queryObject<{
    student_id: string;
    student_code: string | null;
    student_name: string | null;
    roll_number: string | null;
    subject: string;
    exam_type: string | null;
    marks_obtained: number | null;
    max_marks: number;
    status: string;
    exam_updated_at: string;
  }>(
    // EXM-D2 — a published row's grace-applied effective mark drives the stats;
    // an un-published (processed) row has no effective_marks yet → original.
    // ICA-H1 — es.exam_type identifies the ASSESSMENT SLOT within a subject so
    // distinct assessments in one term (e.g. unit_test + terminal, FA + SA) are
    // aggregated rather than collapsed to the latest-updated one.
    `SELECT m.student_id AS student_id,
            m.student_code AS student_code,
            m.student_name AS student_name,
            m.roll_number AS roll_number,
            es.subject AS subject,
            es.exam_type AS exam_type,
            COALESCE(m.effective_marks, m.marks_obtained) AS marks_obtained,
            m.max_marks AS max_marks,
            m.status AS status,
            es.updated_at AS exam_updated_at
       FROM exam_mark_entries m
       JOIN exam_sessions es
         ON es.organization_id = m.organization_id
        AND es.school_id = m.school_id
        AND es.id = m.exam_id
      WHERE m.organization_id = $1
        AND m.school_id = $2
        AND (m.class_label = $3 OR es.grade = $3)
        AND es.term_label = $4
        AND es.phase = ANY($5)
      ORDER BY es.updated_at ASC, m.roll_number NULLS LAST, m.id`,
    [organizationId, schoolId, classLabel, term, REPORTABLE_PHASES],
  );

  // Subject columns in first-seen (exam) order.
  const subjects: string[] = [];
  const byStudent = new Map<string, TabulationStudentRow>();
  // ICA-H1 — per student → per subject → per ASSESSMENT SLOT (keyed by exam_type).
  // Rows arrive oldest→newest (ORDER BY es.updated_at ASC), so within one slot a
  // later session (a supplementary / re-exam of the SAME assessment) REPLACES the
  // earlier one — preserving PRA-P1-12 (a re-exam must not double-count). But two
  // DISTINCT assessments in the same term (different exam_type — e.g. unit_test +
  // terminal, FA + SA) occupy DIFFERENT slots and are AGGREGATED into the subject
  // cell below, rather than being silently collapsed to the latest-updated one.
  const slotsByStudent = new Map<
    string,
    Map<string, Map<string, TabulationSubjectResult>>
  >();

  for (const r of rows) {
    if (!subjects.includes(r.subject)) subjects.push(r.subject);

    let student = byStudent.get(r.student_id);
    if (!student) {
      student = {
        studentId: r.student_id,
        studentCode: r.student_code ?? r.student_id,
        studentName: r.student_name ?? "",
        rollNumber: r.roll_number,
        perSubject: {},
        total: 0,
        totalMax: 0,
        percent: 0,
        rank: null,
      };
      byStudent.set(r.student_id, student);
      slotsByStudent.set(r.student_id, new Map());
    }

    const status = isExamMarkStatus(r.status) ? r.status : "present";
    const present = status === "present" && r.marks_obtained != null;
    const bySubject = slotsByStudent.get(r.student_id)!;
    let slots = bySubject.get(r.subject);
    if (!slots) {
      slots = new Map();
      bySubject.set(r.subject, slots);
    }
    // exam_type is the assessment-slot key; a re-run of the same slot replaces.
    slots.set(r.exam_type ?? "", {
      subject: r.subject,
      marks: present ? r.marks_obtained : null,
      maxMarks: r.max_marks,
      statusCode: examStatusDisplayCode(status),
    });
  }

  const students = [...byStudent.values()];
  for (const s of students) {
    // Aggregate each subject's distinct assessment slots into ONE subject cell:
    // present slots (non-null marks) SUM into the cell and the student total; a
    // non-present slot (AB/ML/DB) never counts (frozen exclusion rule). A subject
    // with only non-present slots shows a status code and contributes nothing.
    const bySubject = slotsByStudent.get(s.studentId)!;
    let total = 0;
    let totalMax = 0;
    for (const subject of subjects) {
      const slots = bySubject.get(subject);
      if (!slots) continue; // this student sat no exam for the subject
      let subjMarks = 0;
      let subjMax = 0;
      let anyPresent = false;
      let nonPresentCell: TabulationSubjectResult | null = null;
      for (const cell of slots.values()) {
        if (cell.marks != null) {
          anyPresent = true;
          subjMarks += cell.marks;
          subjMax += cell.maxMarks;
        } else {
          nonPresentCell = cell;
        }
      }
      if (anyPresent) {
        s.perSubject[subject] = {
          subject,
          marks: subjMarks,
          maxMarks: subjMax,
          statusCode: null,
        };
        total += subjMarks;
        totalMax += subjMax;
      } else {
        // All slots non-present → display the latest status code; never counted.
        s.perSubject[subject] = nonPresentCell ??
          { subject, marks: null, maxMarks: 0, statusCode: null };
      }
    }
    s.total = total;
    s.totalMax = totalMax;
    s.percent = totalMax > 0 ? (total / totalMax) * 100 : 0;
  }

  // Rank by present-only percent. A student with NO present result this term
  // (totalMax === 0) is NOT ranked (rank stays null) and is not in the pool, so
  // absent students never shift another student's rank.
  const ranked = students.filter((s) => s.totalMax > 0);
  for (const s of ranked) {
    const ahead = ranked.filter((o) => o.percent > s.percent + 1e-9).length;
    s.rank = ahead + 1;
  }

  return { classLabel, term, subjects, students };
}

export function tabulationRegisterToApi(
  register: TabulationRegister,
): Record<string, unknown> {
  return {
    classLabel: register.classLabel,
    term: register.term,
    subjects: register.subjects,
    students: register.students.map((s) => ({
      studentId: s.studentId,
      sisStudentId: s.studentCode,
      studentName: s.studentName,
      rollNo: s.rollNumber,
      perSubject: Object.fromEntries(
        Object.entries(s.perSubject).map(([subject, r]) => [
          subject,
          {
            marks: r.marks,
            maxMarks: r.maxMarks,
            statusCode: r.statusCode,
          },
        ]),
      ),
      total: s.total,
      totalMax: s.totalMax,
      percent: Math.round(s.percent * 100) / 100,
      rank: s.rank,
    })),
  };
}

// --- EXM-4 — Subject toppers (per exam) + Merit list (per class + term) ---

export interface TopperRow {
  studentId: string;
  studentCode: string;
  studentName: string;
  rollNumber: string | null;
  marks: number;
  maxMarks: number;
  percent: number;
  rank: number;
}

/**
 * EXM-4a — top-N students by marks for ONE exam. PRESENT rows only: a
 * non-present student (AB/ML/DB) has no score and is never a topper.
 */
export async function loadExamToppers(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
  limit: number,
): Promise<TopperRow[]> {
  const session = await getExamSession(db, organizationId, schoolId, examId);
  if (!session) throw new ExamNotFoundError(examId);

  const rows = await db.queryObject<{
    student_id: string;
    student_code: string | null;
    student_name: string | null;
    roll_number: string | null;
    marks_obtained: number;
    max_marks: number;
  }>(
    // 🔴 EXCLUSION — status = 'present' AND marks_obtained IS NOT NULL only.
    // EXM-D2 — rank by the effective (grace-applied) mark once published.
    `SELECT m.student_id AS student_id,
            m.student_code AS student_code,
            m.student_name AS student_name,
            m.roll_number AS roll_number,
            COALESCE(m.effective_marks, m.marks_obtained) AS marks_obtained,
            m.max_marks AS max_marks
       FROM exam_mark_entries m
      WHERE m.organization_id = $1
        AND m.school_id = $2
        AND m.exam_id = $3
        AND m.status = 'present'
        AND m.marks_obtained IS NOT NULL
      ORDER BY COALESCE(m.effective_marks, m.marks_obtained) DESC, m.roll_number NULLS LAST, m.id
      LIMIT $4`,
    [organizationId, schoolId, examId, Math.max(1, limit)],
  );

  return rows.map((r, index) => ({
    studentId: r.student_id,
    studentCode: r.student_code ?? r.student_id,
    studentName: r.student_name ?? "",
    rollNumber: r.roll_number,
    marks: r.marks_obtained,
    maxMarks: r.max_marks,
    percent: r.max_marks > 0
      ? Math.round((r.marks_obtained / r.max_marks) * 10000) / 100
      : 0,
    // Dense-ish 1-based position by descending marks (ties keep query order).
    rank: index + 1,
  }));
}

export function topperToApi(row: TopperRow): Record<string, unknown> {
  return {
    studentId: row.studentId,
    sisStudentId: row.studentCode,
    studentName: row.studentName,
    rollNo: row.rollNumber,
    marks: row.marks,
    maxMarks: row.maxMarks,
    percent: row.percent,
    rank: row.rank,
  };
}

export interface MeritRow {
  studentId: string;
  studentCode: string;
  studentName: string;
  rollNumber: string | null;
  total: number;
  totalMax: number;
  percent: number;
  rank: number;
}

/**
 * EXM-4b — merit list: students in [classLabel] ranked by their term total %
 * across the term's reportable exams. Built on present-only totals (reuses the
 * tabulation aggregation), so a non-present subject never inflates/deflates a
 * ranking and a fully-non-present student is excluded from the merit list.
 */
export async function loadMeritList(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  classLabel: string,
  term: string,
): Promise<MeritRow[]> {
  const register = await loadTabulationRegister(
    db,
    organizationId,
    schoolId,
    classLabel,
    term,
  );
  // Only ranked students (at least one present result) appear on the merit list.
  const ranked = register.students.filter((s) => s.rank != null);
  ranked.sort((a, b) => (a.rank ?? 0) - (b.rank ?? 0));
  return ranked.map((s) => ({
    studentId: s.studentId,
    studentCode: s.studentCode,
    studentName: s.studentName,
    rollNumber: s.rollNumber,
    total: s.total,
    totalMax: s.totalMax,
    percent: Math.round(s.percent * 100) / 100,
    rank: s.rank!,
  }));
}

export function meritRowToApi(row: MeritRow): Record<string, unknown> {
  return {
    studentId: row.studentId,
    sisStudentId: row.studentCode,
    studentName: row.studentName,
    rollNo: row.rollNumber,
    total: row.total,
    totalMax: row.totalMax,
    percent: row.percent,
    rank: row.rank,
  };
}

// --- EXM-5 — Pass/fail + grade distribution (per exam) ---

export interface ExamDistribution {
  examId: string;
  passMarkPercent: number;
  passMarkSource: string;
  passCount: number;
  failCount: number;
  gradeBreakdown: Array<{ grade: string; count: number }>;
  // Number of PRESENT rows the distribution was computed over.
  presentCount: number;
  // Number of non-present rows (shown for context, EXCLUDED from all counts).
  excludedCount: number;
}

/**
 * EXM-5 — pass/fail split + grade-letter distribution for one exam.
 *
 * 🔴 EXCLUSION — computed over PRESENT rows only. A non-present student (AB/ML/DB)
 * is counted in [excludedCount] for transparency but NEVER in passCount,
 * failCount, or any grade bucket.
 *
 * Pass threshold source (documented): the school's exam/finance settings do not
 * currently expose a configurable exam pass mark (there is no such column/table),
 * so the default is [DEFAULT_PASS_MARK_PERCENT] (40%). `passMarkSource` records
 * which source was used so the client can label it; when a setting is later added
 * this function can read it and set the source accordingly.
 */
export async function loadExamDistribution(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<ExamDistribution> {
  const session = await getExamSession(db, organizationId, schoolId, examId);
  if (!session) throw new ExamNotFoundError(examId);

  // PRA-P1-13 — the school's grade scale is authoritative for BOTH the pass
  // boundary and the grade buckets. Falls back to the legacy 40% + default bands
  // when the school has no configured row.
  const gradeScale = await loadGradeScale(db, organizationId, schoolId);
  const passMarkPercent = gradeScale.passMarkPercent;
  const passMarkSource = gradeScale.source === "school" ? "school" : "default";

  const rows = await db.queryObject<{
    marks_obtained: number | null;
    max_marks: number;
    status: string;
    grade_letter: string | null;
  }>(
    // EXM-D2 — the effective (grace-applied) mark drives pass/fail + grade once
    // published; an un-published row uses its original mark.
    `SELECT COALESCE(m.effective_marks, m.marks_obtained) AS marks_obtained,
            m.max_marks AS max_marks,
            m.status AS status,
            m.grade_letter AS grade_letter
       FROM exam_mark_entries m
      WHERE m.organization_id = $1
        AND m.school_id = $2
        AND m.exam_id = $3
        AND m.marks_entered = true`,
    [organizationId, schoolId, examId],
  );

  let passCount = 0;
  let failCount = 0;
  let presentCount = 0;
  let excludedCount = 0;
  const gradeCounts = new Map<string, number>();

  for (const r of rows) {
    const status = isExamMarkStatus(r.status) ? r.status : "present";
    // 🔴 EXCLUSION — a non-present row (or a null mark) never enters the stats.
    if (status !== "present" || r.marks_obtained == null) {
      excludedCount++;
      continue;
    }
    presentCount++;
    const percent = r.max_marks > 0
      ? (r.marks_obtained / r.max_marks) * 100
      : 0;
    if (percent >= passMarkPercent) passCount++;
    else failCount++;
    // Prefer the persisted (published) grade letter; else derive from percent
    // using the school's resolved scale.
    const grade = r.grade_letter && r.grade_letter.length > 0
      ? r.grade_letter
      : gradeForPercent(percent, gradeScale.bands);
    gradeCounts.set(grade, (gradeCounts.get(grade) ?? 0) + 1);
  }

  const gradeBreakdown = [...gradeCounts.entries()]
    .map(([grade, count]) => ({ grade, count }))
    .sort((a, b) => b.count - a.count || a.grade.localeCompare(b.grade));

  return {
    examId,
    passMarkPercent,
    passMarkSource,
    passCount,
    failCount,
    gradeBreakdown,
    presentCount,
    excludedCount,
  };
}

export function examDistributionToApi(
  dist: ExamDistribution,
): Record<string, unknown> {
  return {
    examId: dist.examId,
    passMarkPercent: dist.passMarkPercent,
    passMarkSource: dist.passMarkSource,
    passCount: dist.passCount,
    failCount: dist.failCount,
    gradeBreakdown: dist.gradeBreakdown,
    presentCount: dist.presentCount,
    excludedCount: dist.excludedCount,
  };
}

// --- EXM-7 — Datesheet (schedule) for a class + term ---

export interface DatesheetRow {
  examId: string;
  subject: string;
  dateLabel: string;
  timeLabel: string;
  venueLabel: string;
  maxMarks: number;
}

/**
 * EXM-7 — the exam schedule ("datesheet") for [classLabel] in [term]: one row
 * per exam session, sorted by date then subject. Read-only; no marks involved,
 * so no exclusion logic applies here. All phases are included (a datesheet is a
 * schedule, not a results report) so students/parents can see upcoming exams.
 */
export async function loadDatesheet(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  classLabel: string,
  term: string,
): Promise<DatesheetRow[]> {
  const rows = await db.queryObject<{
    id: string;
    subject: string;
    date_label: string;
    time_label: string;
    venue_label: string;
    max_marks: number;
  }>(
    `SELECT es.id AS id,
            es.subject AS subject,
            es.date_label AS date_label,
            es.time_label AS time_label,
            es.venue_label AS venue_label,
            es.max_marks AS max_marks
       FROM exam_sessions es
      WHERE es.organization_id = $1
        AND es.school_id = $2
        AND ((es.grade || '-' || es.section_name) = $3 OR es.grade = $3)
        AND es.term_label = $4
      ORDER BY es.date_label ASC, es.subject ASC`,
    [organizationId, schoolId, classLabel, term],
  );
  return rows.map((r) => ({
    examId: r.id,
    subject: r.subject,
    dateLabel: r.date_label,
    timeLabel: r.time_label,
    venueLabel: r.venue_label,
    maxMarks: r.max_marks,
  }));
}

export function datesheetRowToApi(row: DatesheetRow): Record<string, unknown> {
  return {
    examId: row.examId,
    subject: row.subject,
    dateLabel: row.dateLabel,
    timeLabel: row.timeLabel,
    venueLabel: row.venueLabel,
    maxMarks: row.maxMarks,
  };
}

// --- Exam-session remarks (class-teacher authored, audit trail) ---

export interface ExamRemarkRow {
  id: string;
  organization_id: string;
  school_id: string;
  exam_id: string;
  student_id: string;
  text: string;
  author_id: string | null;
  author_name: string;
  author_role: string;
  history: unknown;
  created_at: string;
  updated_at: string;
}

export function examRemarkToApi(row: ExamRemarkRow): Record<string, unknown> {
  return {
    examId: row.exam_id,
    sisStudentId: row.student_id,
    text: row.text,
    authorId: row.author_id,
    authorName: row.author_name,
    authorRole: row.author_role,
    history: row.history ?? [],
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export async function listExamRemarks(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<ExamRemarkRow[]> {
  return await db.queryObject<ExamRemarkRow>(
    `SELECT * FROM exam_remarks
     WHERE organization_id = $1 AND school_id = $2 AND exam_id = $3
     ORDER BY student_id`,
    [organizationId, schoolId, examId],
  );
}

/**
 * PRA-P0-10 (S3): resolve the author's display name SERVER-SIDE from the
 * authenticated user record. NEVER trust a client-supplied name. Keyed on the
 * author id (= claims.sub of the writer). `users.display_name` is
 * `TEXT NOT NULL DEFAULT ''`, so treat empty/whitespace as "unset" and fall back
 * to a safe default (the author id, else "Staff").
 */
async function resolveAuthorDisplayName(
  db: TenantQueryClient,
  authorId: string,
): Promise<string> {
  const rows = await db.queryObject<{ display_name: string | null }>(
    `SELECT display_name FROM users WHERE id = $1`,
    [authorId],
  );
  const name = rows[0]?.display_name?.trim();
  if (name && name.length > 0) return name;
  return authorId && authorId.length > 0 ? authorId : "Staff";
}

/** Creates or edits a (student, exam session) remark, appending to the audit trail. */
export async function upsertExamRemark(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: {
    examId: string;
    studentId: string;
    text: string;
    authorId: string;
    // PRA-P0-10 (S3): author display name is NO LONGER accepted from the caller.
    // It is resolved server-side from users.display_name below.
    authorRole?: string;
  },
): Promise<ExamRemarkRow> {
  const authorRole = input.authorRole ?? "classTeacher";
  // PRA-P0-10 (S3): trusted author name from the user record, not the request.
  const authorName = await resolveAuthorDisplayName(db, input.authorId);
  // Two independent remark slots per (exam, student): the class-teacher remark
  // and the leadership (principal/VP) remark. The id carries the slot so the two
  // never collide / overwrite each other (matches the app's store keying).
  const slot = authorRole === "classTeacher" ? "teacher" : "leadership";
  const id = `${input.examId}|${input.studentId}|${slot}`;
  const revision = JSON.stringify({
    text: input.text,
    authorId: input.authorId,
    authorName, // PRA-P0-10 (S3): server-resolved trusted name into the audit trail
    authorRole,
  });
  const rows = await db.queryObject<ExamRemarkRow>(
    `INSERT INTO exam_remarks (
       id, organization_id, school_id, exam_id, student_id, text,
       author_id, author_name, author_role,
       history
     ) VALUES (
       $1, $2, $3, $4, $5, $6, $7, $8, $9,
       jsonb_build_array(($10::jsonb) || jsonb_build_object('timestamp', timezone('utc', now())::text))
     )
     ON CONFLICT (organization_id, school_id, id) DO UPDATE SET
       text = EXCLUDED.text,
       author_id = EXCLUDED.author_id,
       author_name = EXCLUDED.author_name,
       author_role = EXCLUDED.author_role,
       updated_at = timezone('utc', now()),
       history = exam_remarks.history
         || jsonb_build_array(($10::jsonb) || jsonb_build_object('timestamp', timezone('utc', now())::text))
     RETURNING *`,
    [
      id,
      organizationId,
      schoolId,
      input.examId,
      input.studentId,
      input.text,
      input.authorId,
      authorName, // PRA-P0-10 (S3): server-resolved trusted name into the column
      authorRole,
      revision,
    ],
  );
  return rows[0]!;
}

/**
 * Whether [teacherUserId] is the class teacher of the exam's class+section.
 * Class-teacher status is the authority to author remarks (P2-style scope, but
 * keyed on the class_teacher assignment role).
 */
export async function isClassTeacherForExam(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  teacherUserId: string,
  session: ExamSessionRow,
): Promise<boolean> {
  const rows = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count
     FROM teacher_assignments ta
     JOIN sections sec ON sec.id = ta.section_id
     JOIN classes c ON c.id = sec.class_id
     WHERE ta.organization_id = $1
       AND ta.school_id = $2
       AND ta.teacher_id = $3
       AND ta.role = 'class_teacher'
       AND c.class_name = $4
       AND sec.section_name = $5`,
    [organizationId, schoolId, teacherUserId, session.grade, session.section_name],
  );
  return parseInt(rows[0]?.count ?? "0", 10) > 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// EXM-D2 — Grace marks / moderation (coordinator, at verify; audited; hidden
// from parents/students).
//
// 🔴 Integrity (frozen): the ORIGINAL entered mark on exam_mark_entries is NEVER
// overwritten. Each grace is a SEPARATE row in exam_mark_adjustments. The
// EFFECTIVE mark = clamp(original + SUM(deltas), 0, max_marks), applied to the
// computed grade/totals at publish/report time. Grace is allowed ONLY before
// publish (phase processed/coordinator_verified); it is rejected once published.
// ═══════════════════════════════════════════════════════════════════════════

export class ExamGracePhaseError extends Error {
  constructor(phase: string) {
    super(
      `Grace / moderation is only allowed before publish (current phase: ${phase}).`,
    );
    this.name = "ExamGracePhaseError";
  }
}

export interface ExamMarkAdjustmentRow {
  id: string;
  organization_id: string;
  school_id: string;
  exam_id: string;
  student_id: string;
  delta: number;
  reason: string;
  adjusted_by: string | null;
  created_at: string;
}

/** Clamp an effective mark into the valid [0, max] band (never negative / over max). */
export function clampEffectiveMark(value: number, maxMarks: number): number {
  if (value < 0) return 0;
  if (value > maxMarks) return maxMarks;
  return value;
}

/**
 * Records a single grace/moderation delta for (exam, student). Preserves the
 * ORIGINAL mark (never touches exam_mark_entries.marks_obtained). Allowed only
 * while the exam is processed or coordinator_verified (before publish) — rejected
 * after publish so a published (immutable) result can never be silently changed.
 */
export async function recordExamMarkAdjustment(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: {
    examId: string;
    studentId: string;
    delta: number;
    reason: string;
    adjustedBy: string | null;
  },
): Promise<{ adjustment: ExamMarkAdjustmentRow; effectiveMark: number | null; maxMarks: number }> {
  const session = await getExamSession(db, organizationId, schoolId, input.examId);
  if (!session) throw new ExamNotFoundError(input.examId);
  // Only before publish. draft/scheduled/marks_entry have no processed marks to
  // moderate; published is immutable.
  if (session.phase !== "processed") {
    throw new ExamGracePhaseError(session.phase);
  }
  if (!Number.isInteger(input.delta)) {
    throw new ExamValidationError("delta must be an integer");
  }
  if (input.reason.trim().length === 0) {
    throw new ExamValidationError("reason is required for a grace / moderation adjustment");
  }

  // The student's mark entry for this exam (needed for bounds + effective calc).
  const markRows = await db.queryObject<ExamMarkRow>(
    `SELECT * FROM exam_mark_entries
     WHERE organization_id = $1 AND school_id = $2 AND exam_id = $3 AND student_id = $4`,
    [organizationId, schoolId, input.examId, input.studentId],
  );
  const mark = markRows[0];
  if (!mark) throw new ExamMarkNotFoundError(`${input.examId}:${input.studentId}`);
  // A non-present (AB/ML/DB) student has no score to moderate.
  const status: ExamMarkStatus = isExamMarkStatus(mark.status) ? mark.status : "present";
  if (status !== "present" || mark.marks_obtained == null) {
    throw new ExamValidationError(
      "Cannot apply grace to a non-present student (absent / medical leave / debarred).",
    );
  }

  const adjustedBy = input.adjustedBy &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        input.adjustedBy,
      )
    ? input.adjustedBy
    : null;

  const inserted = await db.queryObject<ExamMarkAdjustmentRow>(
    `INSERT INTO exam_mark_adjustments
       (organization_id, school_id, exam_id, student_id, delta, reason, adjusted_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.examId,
      input.studentId,
      input.delta,
      input.reason.trim(),
      adjustedBy,
    ],
  );

  const totalDelta = await sumAdjustments(
    db,
    organizationId,
    schoolId,
    input.examId,
    input.studentId,
  );
  const effectiveMark = clampEffectiveMark(
    mark.marks_obtained + totalDelta,
    mark.max_marks,
  );

  return { adjustment: inserted[0]!, effectiveMark, maxMarks: mark.max_marks };
}

/** Sum of all grace deltas for one (exam, student). 0 when there are none. */
export async function sumAdjustments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
  studentId: string,
): Promise<number> {
  const rows = await db.queryObject<{ total: string | null }>(
    `SELECT COALESCE(SUM(delta), 0)::text AS total
       FROM exam_mark_adjustments
      WHERE organization_id = $1 AND school_id = $2
        AND exam_id = $3 AND student_id = $4`,
    [organizationId, schoolId, examId, studentId],
  );
  return parseInt(rows[0]?.total ?? "0", 10) || 0;
}

/**
 * All grace/moderation adjustments for an exam (coordinator/principal only —
 * the breakdown is NEVER exposed to parents/students). One row per adjustment.
 */
export async function listExamMarkAdjustments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<ExamMarkAdjustmentRow[]> {
  return await db.queryObject<ExamMarkAdjustmentRow>(
    `SELECT * FROM exam_mark_adjustments
     WHERE organization_id = $1 AND school_id = $2 AND exam_id = $3
     ORDER BY student_id, created_at`,
    [organizationId, schoolId, examId],
  );
}

export function examMarkAdjustmentToApi(
  row: ExamMarkAdjustmentRow,
): Record<string, unknown> {
  return {
    id: row.id,
    examId: row.exam_id,
    studentId: row.student_id,
    delta: row.delta,
    reason: row.reason,
    adjustedBy: row.adjusted_by,
    createdAt: row.created_at,
  };
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

// ═══════════════════════════════════════════════════════════════════════════
// EXM-D1 — Batch report-card data (published results, one card per student for a
// class + term). No schema change: reuses exam_mark_entries + exam_sessions and
// the same present-only exclusion + effective-mark (grace) semantics as reports.
// The client renders/prints each card (reusing buildReportCardPdf).
// ═══════════════════════════════════════════════════════════════════════════

export interface ReportCardSubject {
  subject: string;
  examTitle: string;
  score: number | null;
  maxScore: number;
  grade: string;
  statusCode: string | null;
}

export interface ReportCardData {
  sisStudentId: string;
  studentName: string;
  classLabel: string;
  termLabel: string;
  subjects: ReportCardSubject[];
  totalScore: number;
  totalMax: number;
  overallPercent: number;
  overallGrade: string;
  rank: number | null;
  classSize: number;
}

/**
 * EXM-D1 — the per-student report cards for [classLabel] over [term], built from
 * PUBLISHED results only. Each subject line uses the EFFECTIVE (original + grace)
 * mark via effective_marks (baked at publish) — the grace breakdown is never
 * present. Non-present (AB/ML/DB) lines show their code and are excluded from the
 * total / percent / rank (frozen exclusion rule).
 */
export async function loadReportCards(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  classLabel: string,
  term: string,
): Promise<ReportCardData[]> {
  const rows = await db.queryObject<{
    student_id: string;
    student_code: string | null;
    student_name: string | null;
    subject: string;
    exam_type: string | null;
    exam_title: string;
    marks_obtained: number | null;
    effective_marks: number | null;
    max_marks: number;
    status: string;
    grade_letter: string | null;
    exam_updated_at: string;
  }>(
    // ICA-H1 — es.exam_type identifies the ASSESSMENT SLOT within a subject so a
    // term's DISTINCT assessments (e.g. unit_test + terminal, FA + SA) each keep
    // their own report-card line instead of collapsing to the latest-updated one.
    `SELECT m.student_id AS student_id,
            m.student_code AS student_code,
            m.student_name AS student_name,
            es.subject AS subject,
            es.exam_type AS exam_type,
            es.title AS exam_title,
            m.marks_obtained AS marks_obtained,
            m.effective_marks AS effective_marks,
            m.max_marks AS max_marks,
            m.status AS status,
            m.grade_letter AS grade_letter,
            es.updated_at AS exam_updated_at
       FROM exam_mark_entries m
       JOIN exam_sessions es
         ON es.organization_id = m.organization_id
        AND es.school_id = m.school_id
        AND es.id = m.exam_id
      WHERE m.organization_id = $1
        AND m.school_id = $2
        AND (m.class_label = $3 OR es.grade = $3)
        AND es.term_label = $4
        AND es.phase = 'published'
        AND m.published = true
      ORDER BY es.updated_at ASC, m.roll_number NULLS LAST, m.id`,
    [organizationId, schoolId, classLabel, term],
  );

  // PRA-P1-13 — resolve the school scale once; every derived letter grade on the
  // report card honours it (baked grade_letter still wins where present).
  const gradeScale = await loadGradeScale(db, organizationId, schoolId);

  const byStudent = new Map<string, ReportCardData>();
  // ICA-H1 / PRA-P1-12: dedupe rows PER (subject, ASSESSMENT SLOT) — the slot is
  // keyed by exam_type. Rows come oldest→newest (ORDER BY es.updated_at ASC); an
  // insertion-ordered Map keeps first-seen line order while replacing the value
  // with the NEWEST session's cell. Two sessions of the SAME slot (a supplementary
  // / re-exam of one assessment) therefore contribute ONE line — preserving
  // PRA-P1-12 (no double-count) — while DISTINCT assessments in the same term
  // (different exam_type — e.g. unit_test + terminal, FA + SA) keep their own line
  // and each contribute to totalScore, instead of collapsing to the latest.
  const subjectsByStudent = new Map<string, Map<string, ReportCardData["subjects"][number]>>();
  for (const r of rows) {
    let card = byStudent.get(r.student_id);
    if (!card) {
      card = {
        sisStudentId: r.student_code ?? r.student_id,
        studentName: r.student_name ?? "",
        classLabel,
        termLabel: term,
        subjects: [],
        totalScore: 0,
        totalMax: 0,
        overallPercent: 0,
        overallGrade: "",
        rank: null,
        classSize: 0,
      };
      byStudent.set(r.student_id, card);
      subjectsByStudent.set(r.student_id, new Map());
    }
    const status = isExamMarkStatus(r.status) ? r.status : "present";
    // Effective (grace-applied) score for a present student; null for AB/ML/DB.
    const score = status === "present"
      ? (r.effective_marks ?? r.marks_obtained)
      : null;
    // Slot key = subject + exam_type. NUL-separated so distinct fields never
    // alias (e.g. "Math" + "1" vs "Math1" + "").
    const slotKey = `${r.subject}\u0000${r.exam_type ?? ""}`;
    subjectsByStudent.get(r.student_id)!.set(slotKey, {
      subject: r.subject,
      examTitle: r.exam_title,
      score,
      maxScore: r.max_marks,
      grade: r.grade_letter ??
        (score != null
          ? gradeForPercent(
            r.max_marks > 0 ? (score / r.max_marks) * 100 : 0,
            gradeScale.bands,
          )
          : (examStatusDisplayCode(status) ?? "")),
      statusCode: examStatusDisplayCode(status),
    });
  }

  for (const [studentId, c] of byStudent) {
    // Materialize the deduped subjects and sum ONCE per subject.
    c.subjects = [...subjectsByStudent.get(studentId)!.values()];
    let totalScore = 0;
    let totalMax = 0;
    for (const cell of c.subjects) {
      if (cell.score != null) {
        totalScore += cell.score;
        totalMax += cell.maxScore;
      }
    }
    c.totalScore = totalScore;
    c.totalMax = totalMax;
    c.overallPercent = c.totalMax > 0
      ? Math.round((c.totalScore / c.totalMax) * 10000) / 100
      : 0;
    c.overallGrade = c.totalMax > 0
      ? gradeForPercent(c.overallPercent, gradeScale.bands)
      : "";
  }
  const cards = [...byStudent.values()];

  // Present-only rank across the class (a student with no present result is not
  // ranked and never shifts another's rank — frozen exclusion rule).
  const ranked = cards.filter((c) => c.totalMax > 0);
  for (const c of ranked) {
    const ahead = ranked.filter((o) => o.overallPercent > c.overallPercent + 1e-9)
      .length;
    c.rank = ahead + 1;
    c.classSize = ranked.length;
  }
  return cards;
}

export function reportCardToApi(card: ReportCardData): Record<string, unknown> {
  return {
    sisStudentId: card.sisStudentId,
    studentName: card.studentName,
    classLabel: card.classLabel,
    termLabel: card.termLabel,
    subjects: card.subjects.map((s) => ({
      subject: s.subject,
      examTitle: s.examTitle,
      score: s.score,
      maxScore: s.maxScore,
      grade: s.grade,
      statusCode: s.statusCode,
    })),
    totalScore: card.totalScore,
    totalMax: card.totalMax,
    overallPercent: card.overallPercent,
    overallGrade: card.overallGrade,
    rank: card.rank,
    classSize: card.classSize,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// EXM-D4 — Hall-ticket / admit-card data (per student for one exam). No schema
// change: reads the exam session + its mark-entry roster (one entry per enrolled
// student). Standard-template instructions supplied by the backend.
// ═══════════════════════════════════════════════════════════════════════════

/** Standard admit-card instructions (adopted default). */
export const HALL_TICKET_INSTRUCTIONS: readonly string[] = [
  "Carry this hall ticket to the examination hall.",
  "Reach the venue at least 15 minutes before the start time.",
  "Electronic devices and unauthorised materials are prohibited.",
  "Follow all instructions given by the invigilator.",
] as const;

export interface HallTicketRow {
  sisStudentId: string;
  studentName: string;
  rollNo: string | null;
  classLabel: string;
  subject: string;
  examTitle: string;
  dateLabel: string;
  timeLabel: string;
  venueLabel: string;
  maxMarks: number;
  instructions: string[];
}

export async function loadHallTickets(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<HallTicketRow[]> {
  const session = await getExamSession(db, organizationId, schoolId, examId);
  if (!session) throw new ExamNotFoundError(examId);

  const rows = await db.queryObject<{
    student_id: string;
    student_code: string | null;
    student_name: string | null;
    roll_number: string | null;
    class_label: string;
  }>(
    `SELECT m.student_id AS student_id,
            m.student_code AS student_code,
            m.student_name AS student_name,
            m.roll_number AS roll_number,
            m.class_label AS class_label
       FROM exam_mark_entries m
      WHERE m.organization_id = $1 AND m.school_id = $2 AND m.exam_id = $3
      ORDER BY m.roll_number NULLS LAST, m.id`,
    [organizationId, schoolId, examId],
  );

  return rows.map((r) => ({
    sisStudentId: r.student_code ?? r.student_id,
    studentName: r.student_name ?? "",
    rollNo: r.roll_number,
    classLabel: r.class_label || `${session.grade}-${session.section_name}`,
    subject: session.subject,
    examTitle: session.title,
    dateLabel: session.date_label,
    timeLabel: session.time_label,
    venueLabel: session.venue_label,
    maxMarks: session.max_marks,
    instructions: [...HALL_TICKET_INSTRUCTIONS],
  }));
}

export function hallTicketToApi(row: HallTicketRow): Record<string, unknown> {
  return {
    sisStudentId: row.sisStudentId,
    studentName: row.studentName,
    rollNo: row.rollNo,
    classLabel: row.classLabel,
    subject: row.subject,
    examTitle: row.examTitle,
    dateLabel: row.dateLabel,
    timeLabel: row.timeLabel,
    venueLabel: row.venueLabel,
    maxMarks: row.maxMarks,
    instructions: row.instructions,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// EXM-D5 — Seating arrangement generator (mixed-class default, configurable).
//
// Default room capacity 30 (configurable). Mixed-class rule: when MULTIPLE
// classes sit the exam, no two ADJACENT seats (consecutive seat_no in the same
// room) hold students of the same class — achieved by round-robin interleaving
// the classes into the seat sequence. For a SINGLE class, students are seated
// sequentially by roll across rooms of the given capacity.
// ═══════════════════════════════════════════════════════════════════════════

export const DEFAULT_SEATING_ROOM_CAPACITY = 30;

export interface SeatingAssignmentRow {
  id: string;
  organization_id: string;
  school_id: string;
  exam_id: string;
  student_id: string;
  room_label: string;
  seat_no: number;
  created_at: string;
}

export interface SeatingCandidate {
  studentId: string;
  studentCode: string | null;
  studentName: string | null;
  rollNumber: string | null;
  classLabel: string;
}

export interface PlannedSeat {
  studentId: string;
  roomLabel: string;
  seatNo: number;
}

/**
 * Pure seat planner (unit-testable without a DB). Interleaves classes so no two
 * adjacent seats share a class when multiple classes are present; a single class
 * seats sequentially by roll. Rooms fill to [capacity] then a new room opens.
 * Room labels are "Room 1", "Room 2", ...; seatNo is 1-based within a room.
 */
export function planSeating(
  candidates: SeatingCandidate[],
  capacity: number,
): PlannedSeat[] {
  const cap = Number.isFinite(capacity) && capacity > 0
    ? Math.floor(capacity)
    : DEFAULT_SEATING_ROOM_CAPACITY;

  // Group by class, each group ordered by roll (nulls last), then id.
  const byClass = new Map<string, SeatingCandidate[]>();
  for (const c of candidates) {
    const list = byClass.get(c.classLabel) ?? [];
    list.push(c);
    byClass.set(c.classLabel, list);
  }
  for (const list of byClass.values()) {
    list.sort((a, b) => {
      const ra = a.rollNumber ?? "￿";
      const rb = b.rollNumber ?? "￿";
      if (ra !== rb) return ra < rb ? -1 : 1;
      return a.studentId < b.studentId ? -1 : a.studentId > b.studentId ? 1 : 0;
    });
  }

  // Ordered class keys (stable: first appearance order).
  const classKeys = [...byClass.keys()];
  const singleClass = classKeys.length <= 1;

  // Build the seating order:
  //  • single class → straight roll order;
  //  • multiple classes → round-robin, but never place the same class as the
  //    immediately-previous pick (greedy: pick the largest remaining group whose
  //    class differs from the last placed one).
  const order: SeatingCandidate[] = [];
  if (singleClass) {
    for (const c of byClass.values()) order.push(...c);
  } else {
    // Working queues (copies) so we can pop from the front.
    const queues = new Map<string, SeatingCandidate[]>();
    for (const [k, v] of byClass) queues.set(k, [...v]);
    let lastClass: string | null = null;
    let remaining = candidates.length;
    while (remaining > 0) {
      // Candidate classes with students left, excluding the last-placed class.
      let pickKey: string | null = null;
      let pickLen = -1;
      for (const k of classKeys) {
        const q = queues.get(k)!;
        if (q.length === 0) continue;
        if (k === lastClass) continue;
        if (q.length > pickLen) {
          pickLen = q.length;
          pickKey = k;
        }
      }
      // Only the last-placed class still has students → unavoidable repeat
      // (that class outnumbers the rest); place it.
      if (pickKey == null) {
        for (const k of classKeys) {
          const q = queues.get(k)!;
          if (q.length > 0) {
            pickKey = k;
            break;
          }
        }
      }
      const q = queues.get(pickKey!)!;
      order.push(q.shift()!);
      lastClass = pickKey;
      remaining--;
    }
  }

  // Chunk into rooms of `cap`.
  const seats: PlannedSeat[] = [];
  for (let i = 0; i < order.length; i++) {
    const roomIndex = Math.floor(i / cap);
    const seatNo = (i % cap) + 1;
    seats.push({
      studentId: order[i]!.studentId,
      roomLabel: `Room ${roomIndex + 1}`,
      seatNo,
    });
  }
  return seats;
}

/** The students who sit an exam: the mark-entry roster, enriched with class label. */
export async function loadSeatingCandidates(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<SeatingCandidate[]> {
  const rows = await db.queryObject<{
    student_id: string;
    student_code: string | null;
    student_name: string | null;
    roll_number: string | null;
    class_label: string;
  }>(
    `SELECT m.student_id AS student_id,
            m.student_code AS student_code,
            m.student_name AS student_name,
            m.roll_number AS roll_number,
            m.class_label AS class_label
       FROM exam_mark_entries m
      WHERE m.organization_id = $1 AND m.school_id = $2 AND m.exam_id = $3`,
    [organizationId, schoolId, examId],
  );
  return rows.map((r) => ({
    studentId: r.student_id,
    studentCode: r.student_code,
    studentName: r.student_name,
    rollNumber: r.roll_number,
    classLabel: r.class_label,
  }));
}

/**
 * EXM-D5 — (re)generate the seating plan for an exam. Clears any existing plan
 * for the exam, then inserts the freshly-planned seats. Idempotent per exam.
 */
export async function generateSeating(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
  capacity: number = DEFAULT_SEATING_ROOM_CAPACITY,
): Promise<SeatingAssignmentRow[]> {
  const session = await getExamSession(db, organizationId, schoolId, examId);
  if (!session) throw new ExamNotFoundError(examId);

  const candidates = await loadSeatingCandidates(
    db,
    organizationId,
    schoolId,
    examId,
  );
  if (candidates.length === 0) {
    throw new ExamValidationError(
      "No students provisioned for this exam — open marks entry first.",
    );
  }
  const plan = planSeating(candidates, capacity);
  const byId = new Map(candidates.map((c) => [c.studentId, c]));

  // Replace the whole plan for this exam (regenerate == clean slate).
  await db.queryObject(
    `DELETE FROM exam_seating_assignments
     WHERE organization_id = $1 AND school_id = $2 AND exam_id = $3`,
    [organizationId, schoolId, examId],
  );
  for (const seat of plan) {
    await db.queryObject(
      `INSERT INTO exam_seating_assignments
         (organization_id, school_id, exam_id, student_id, room_label, seat_no)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        organizationId,
        schoolId,
        examId,
        seat.studentId,
        seat.roomLabel,
        seat.seatNo,
      ],
    );
  }
  return await loadSeating(db, organizationId, schoolId, examId, byId);
}

/** Reads an exam's seating plan (room + seat + student label), ordered for print. */
export async function loadSeating(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
  candidatesById?: Map<string, SeatingCandidate>,
): Promise<SeatingAssignmentRow[]> {
  return await db.queryObject<SeatingAssignmentRow>(
    `SELECT * FROM exam_seating_assignments
     WHERE organization_id = $1 AND school_id = $2 AND exam_id = $3
     ORDER BY room_label, seat_no`,
    [organizationId, schoolId, examId],
  ).then((rows) => {
    // Attach candidate labels if provided (avoids a JOIN; the roster is small).
    if (candidatesById) return rows;
    return rows;
  });
}

/** A seating plan enriched with student labels, grouped by room, for the client. */
export interface SeatingPlanApi {
  examId: string;
  roomCapacity: number;
  rooms: Array<{
    roomLabel: string;
    seats: Array<{
      seatNo: number;
      sisStudentId: string;
      studentName: string;
      rollNo: string | null;
      classLabel: string;
    }>;
  }>;
}

export async function loadSeatingPlan(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
): Promise<SeatingPlanApi> {
  const session = await getExamSession(db, organizationId, schoolId, examId);
  if (!session) throw new ExamNotFoundError(examId);

  const rows = await db.queryObject<
    SeatingAssignmentRow & {
      student_code: string | null;
      student_name: string | null;
      roll_number: string | null;
      class_label: string | null;
    }
  >(
    `SELECT sa.*, m.student_code AS student_code, m.student_name AS student_name,
            m.roll_number AS roll_number, m.class_label AS class_label
       FROM exam_seating_assignments sa
       LEFT JOIN exam_mark_entries m
         ON m.organization_id = sa.organization_id
        AND m.school_id = sa.school_id
        AND m.exam_id = sa.exam_id
        AND m.student_id = sa.student_id
      WHERE sa.organization_id = $1 AND sa.school_id = $2 AND sa.exam_id = $3
      ORDER BY sa.room_label, sa.seat_no`,
    [organizationId, schoolId, examId],
  );

  const rooms: SeatingPlanApi["rooms"] = [];
  const roomIndex = new Map<string, number>();
  for (const r of rows) {
    let idx = roomIndex.get(r.room_label);
    if (idx == null) {
      idx = rooms.length;
      roomIndex.set(r.room_label, idx);
      rooms.push({ roomLabel: r.room_label, seats: [] });
    }
    rooms[idx]!.seats.push({
      seatNo: r.seat_no,
      sisStudentId: r.student_code ?? r.student_id,
      studentName: r.student_name ?? "",
      rollNo: r.roll_number,
      classLabel: r.class_label ?? "",
    });
  }
  return { examId, roomCapacity: DEFAULT_SEATING_ROOM_CAPACITY, rooms };
}
