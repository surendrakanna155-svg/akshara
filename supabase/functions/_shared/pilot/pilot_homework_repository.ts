import type { TenantQueryClient } from "../tenant_db.ts";
import { parseClassLabel } from "./pilot_teacher_repository.ts";
import { listGuardianUserIdsForStudent } from "./pilot_leave_repository.ts";

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
    // PRA-P1-30 — tenant-prefixed path of the REAL uploaded submission file (null
    // when the student submits without an attachment). attachment_label stays as
    // the human file-name label.
    attachmentStoragePath?: string | null;
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
         organization_id, school_id, student_id, homework_id, notes,
         attachment_label, attachment_storage_path
       ) VALUES ($1,$2,$3,$4,$5,$6,$7)
       RETURNING id`,
      [
        input.organizationId,
        input.schoolId,
        input.studentId,
        input.homeworkId,
        input.notes,
        input.attachmentLabel ?? null,
        input.attachmentStoragePath ?? null,
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

// PRA-P0-12 (S0/T1a): `updateExamMark` was removed together with its only caller,
// the shadowing pilot handler `handleTeacherExamMarkUpdate`. The governed exam
// engine (`exam_administration_repository.applyMarkUpdate`) is now the sole writer
// of `exam_mark_entries` on the teacher path, preserving subject-teacher scoping.

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
    attachment_storage_path: string | null;
  }>(
    `SELECT homework_id, status, grade, comment,
            to_char(submitted_at, 'DD Mon YYYY') AS submitted_label,
            attachment_storage_path
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
    // PRA-P1-30 — surface the real stored submission object so the client can
    // request a signed download URL for it.
    if (sub.attachment_storage_path != null) {
      overlay.submissionAttachmentStoragePath = sub.attachment_storage_path;
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
    attachment_storage_path: string | null;
  }>(
    `SELECT id,
            payload->>'attachmentName' AS attachment_name,
            payload->>'attachmentRef' AS attachment_ref,
            payload->>'attachmentStoragePath' AS attachment_storage_path
       FROM student_entities
      WHERE organization_id = $1 AND school_id = $2 AND student_id = $3::uuid
        AND entity_type = 'homework_item'
        AND id = ANY($4::text[])`,
    [orgId, schoolId, studentId, homeworkIds],
  );
  const attachmentByHw = new Map<
    string,
    { name: string | null; ref: string | null; storagePath: string | null }
  >();
  for (const r of itemRows) {
    attachmentByHw.set(r.id, {
      name: r.attachment_name,
      ref: r.attachment_ref,
      storagePath: r.attachment_storage_path,
    });
  }

  // The child's own submission (note + attachment + status/grade/comment).
  const subRows = await db.queryObject<{
    homework_id: string;
    status: string;
    grade: string | null;
    comment: string | null;
    notes: string | null;
    attachment_label: string | null;
    attachment_storage_path: string | null;
    submitted_label: string | null;
  }>(
    `SELECT homework_id, status, grade, comment, notes, attachment_label,
            attachment_storage_path,
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
      // PRA-P1-30 — the teacher worksheet's real stored object.
      if (attachment.storagePath) {
        item.attachmentStoragePath = attachment.storagePath;
      }
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
      // PRA-P1-30 — the child's submitted file's real stored object.
      if (sub.attachment_storage_path != null) {
        item.submissionAttachmentStoragePath = sub.attachment_storage_path;
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
    // PRA-P1-30 — tenant-prefixed path of the REAL uploaded teacher worksheet
    // (null when the teacher attaches no file). Rides the assignment + delivered
    // item JSONB payload alongside the display name.
    attachmentStoragePath?: string | null;
  },
): Promise<{ id: string; deliveredCount: number }> {
  const attachmentName = input.attachmentName?.trim() || null;
  const attachmentRef = input.attachmentRef?.trim() || null;
  const attachmentStoragePath = input.attachmentStoragePath?.trim() || null;
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
         'attachmentStoragePath', $12::text,
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
      attachmentStoragePath,
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
           'attachmentStoragePath', $11::text,
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
        attachmentStoragePath,
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
