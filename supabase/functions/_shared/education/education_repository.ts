import type { TenantQueryClient } from "../tenant_db.ts";
import { computeQuestionFingerprint } from "./education_fingerprint.ts";
import type {
  EduCognitiveLevel,
  EduDifficulty,
  EduExamType,
  EduHomeworkType,
  EduProgramTrack,
  EduQuestionSource,
  EduQuestionType,
  EduRemarkLanguage,
  EduRemarkType,
  EduReviewStatus,
  QuestionBankItemRow,
  QuestionPaperItemRow,
  QuestionPaperReviewRow,
  QuestionPaperRow,
} from "./education_types.ts";

export const EDU_QUESTION_BANK_PROBE_SCHOOL_A = "e0500000-0000-4000-8000-000000000001";
export const EDU_QUESTION_BANK_PROBE_SCHOOL_B = "e0500000-0000-4000-8000-000000000002";

export const EDU_QUESTION_BANK_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM edu_question_bank_items
  WHERE id = $1::uuid
`;

export const EDU_QUESTION_BANK_API_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM edu_question_bank_items
  WHERE organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
`;

export const EDU_QUESTION_PAPERS_API_PROBE_SQL = `
  SELECT count(*)::text AS count
  FROM edu_question_papers
  WHERE organization_id = app_current_tenant_id()
    AND school_id = app_current_school_id()
`;

export interface PaginationResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}

function clampPageSize(pageSize: number): number {
  return Math.min(100, Math.max(1, pageSize));
}

export interface QuestionBankListFilters {
  subjectName?: string;
  chapter?: string;
  chapters?: string[];
  topic?: string;
  difficulty?: string;
  questionType?: string;
  status?: string;
  reviewStatus?: string;
  programTrack?: string;
  source?: string;
  search?: string;
  page?: number;
  pageSize?: number;
}

export interface CreateQuestionBankInput {
  subjectName: string;
  chapter: string;
  topic?: string;
  difficulty: EduDifficulty;
  questionType: EduQuestionType;
  marks: number;
  questionText: string;
  answerText?: string;
  options?: string[];
  source?: EduQuestionSource;
  sourceReference?: string;
  programTrack?: EduProgramTrack;
  jeeQuestionType?: string;
  cognitiveLevel?: EduCognitiveLevel;
  syllabusChapterId?: string;
  syllabusTopicId?: string;
  learningOutcome?: string;
  reviewStatus?: EduReviewStatus;
  createdBy: string;
}

export interface ImportQuestionBankInput {
  items: CreateQuestionBankInput[];
  createdBy?: string;
}

export async function listQuestionBankItems(
  client: TenantQueryClient,
  filters: QuestionBankListFilters,
): Promise<PaginationResult<QuestionBankItemRow>> {
  const page = Math.max(1, filters.page ?? 1);
  const pageSize = clampPageSize(filters.pageSize ?? 20);
  const offset = (page - 1) * pageSize;

  const conditions = ["status = $1"];
  const params: unknown[] = [filters.status ?? "active"];
  let paramIndex = 2;

  if (filters.subjectName) {
    conditions.push(`subject_name ILIKE $${paramIndex}`);
    params.push(`%${filters.subjectName}%`);
    paramIndex += 1;
  }
  if (filters.chapter) {
    conditions.push(`chapter ILIKE $${paramIndex}`);
    params.push(`%${filters.chapter}%`);
    paramIndex += 1;
  }
  if (filters.chapters && filters.chapters.length > 0) {
    conditions.push(`chapter = ANY($${paramIndex}::text[])`);
    params.push(filters.chapters);
    paramIndex += 1;
  }
  if (filters.topic) {
    conditions.push(`topic ILIKE $${paramIndex}`);
    params.push(`%${filters.topic}%`);
    paramIndex += 1;
  }
  if (filters.difficulty) {
    conditions.push(`difficulty = $${paramIndex}`);
    params.push(filters.difficulty);
    paramIndex += 1;
  }
  if (filters.questionType) {
    conditions.push(`question_type = $${paramIndex}`);
    params.push(filters.questionType);
    paramIndex += 1;
  }
  if (filters.reviewStatus) {
    conditions.push(`review_status = $${paramIndex}`);
    params.push(filters.reviewStatus);
    paramIndex += 1;
  }
  if (filters.programTrack) {
    conditions.push(`program_track = $${paramIndex}`);
    params.push(filters.programTrack);
    paramIndex += 1;
  }
  if (filters.source) {
    conditions.push(`source = $${paramIndex}`);
    params.push(filters.source);
    paramIndex += 1;
  }
  if (filters.search) {
    conditions.push(
      `(question_text ILIKE $${paramIndex} OR topic ILIKE $${paramIndex} OR chapter ILIKE $${paramIndex})`,
    );
    params.push(`%${filters.search}%`);
    paramIndex += 1;
  }

  const where = conditions.join(" AND ");
  const total = await client.queryCount(
    `SELECT count(*)::text AS count FROM edu_question_bank_items WHERE ${where}`,
    params,
  );

  const items = await client.queryObject<QuestionBankItemRow>(
    `SELECT * FROM edu_question_bank_items
     WHERE ${where}
     ORDER BY updated_at DESC
     LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
    [...params, pageSize, offset],
  );

  return { items, total, page, pageSize };
}

export async function createQuestionBankItem(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateQuestionBankInput,
): Promise<QuestionBankItemRow> {
  const fingerprint = computeQuestionFingerprint({
    subjectName: input.subjectName,
    chapter: input.chapter,
    questionType: input.questionType,
    questionText: input.questionText,
  });
  const result = await client.queryObject<QuestionBankItemRow>(
    `INSERT INTO edu_question_bank_items (
       organization_id, school_id, subject_name, chapter, topic,
       difficulty, question_type, marks, question_text, answer_text, options,
       source, source_reference, program_track, jee_question_type, cognitive_level,
       syllabus_chapter_id, syllabus_topic_id, learning_outcome, fingerprint,
       review_status, created_by
     ) VALUES (
       $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb,
       $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22
     )
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.subjectName,
      input.chapter,
      input.topic ?? "",
      input.difficulty,
      input.questionType,
      input.marks,
      input.questionText,
      input.answerText ?? null,
      JSON.stringify(input.options ?? []),
      input.source ?? "teacher",
      input.sourceReference ?? null,
      input.programTrack ?? "board",
      input.jeeQuestionType ?? null,
      input.cognitiveLevel ?? null,
      input.syllabusChapterId ?? null,
      input.syllabusTopicId ?? null,
      input.learningOutcome ?? null,
      fingerprint,
      input.reviewStatus ?? "approved",
      input.createdBy,
    ],
  );
  return result[0]!;
}

/** Existing approved/pending bank item with the same fingerprint, if any. */
async function findBankItemByFingerprint(
  client: TenantQueryClient,
  fingerprint: string,
): Promise<QuestionBankItemRow | null> {
  const rows = await client.queryObject<QuestionBankItemRow>(
    `SELECT * FROM edu_question_bank_items
     WHERE fingerprint = $1 AND status = 'active'
     LIMIT 1`,
    [fingerprint],
  );
  return rows[0] ?? null;
}

export interface ImportResult {
  created: QuestionBankItemRow[];
  skippedDuplicates: number;
}

/** Bulk import with graceful in-school dedup (duplicates are skipped, counted). */
export async function importQuestionBankItems(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: ImportQuestionBankInput,
): Promise<ImportResult> {
  const created: QuestionBankItemRow[] = [];
  let skippedDuplicates = 0;
  const seenInBatch = new Set<string>();

  for (const item of input.items) {
    const fingerprint = computeQuestionFingerprint({
      subjectName: item.subjectName,
      chapter: item.chapter,
      questionType: item.questionType,
      questionText: item.questionText,
    });
    if (seenInBatch.has(fingerprint)) {
      skippedDuplicates += 1;
      continue;
    }
    const existing = await findBankItemByFingerprint(client, fingerprint);
    if (existing) {
      skippedDuplicates += 1;
      seenInBatch.add(fingerprint);
      continue;
    }
    seenInBatch.add(fingerprint);
    created.push(
      await createQuestionBankItem(client, organizationId, schoolId, {
        ...item,
        createdBy: item.createdBy ?? input.createdBy ?? "",
      }),
    );
  }
  return { created, skippedDuplicates };
}

export interface UpdateQuestionBankInput {
  subjectName?: string;
  chapter?: string;
  topic?: string;
  difficulty?: EduDifficulty;
  questionType?: EduQuestionType;
  marks?: number;
  questionText?: string;
  answerText?: string | null;
  options?: string[];
  programTrack?: EduProgramTrack;
  cognitiveLevel?: EduCognitiveLevel | null;
  syllabusChapterId?: string | null;
  syllabusTopicId?: string | null;
  learningOutcome?: string | null;
  sourceReference?: string | null;
}

/**
 * Edit a saved bank question in place (Feature C, token-free). Only the supplied
 * fields change; the dedup fingerprint is recomputed from the resulting
 * subject/chapter/type/text so a corrected question still de-duplicates cleanly
 * on the next import or generation.
 */
export async function updateQuestionBankItem(
  client: TenantQueryClient,
  id: string,
  input: UpdateQuestionBankInput,
): Promise<QuestionBankItemRow | null> {
  const existingRows = await client.queryObject<QuestionBankItemRow>(
    `SELECT * FROM edu_question_bank_items WHERE id = $1`,
    [id],
  );
  const existing = existingRows[0];
  if (!existing) return null;

  const subjectName = input.subjectName ?? existing.subject_name;
  const chapter = input.chapter ?? existing.chapter;
  const questionType = input.questionType ?? (existing.question_type as EduQuestionType);
  const questionText = input.questionText ?? existing.question_text;
  const fingerprint = computeQuestionFingerprint({
    subjectName,
    chapter,
    questionType,
    questionText,
  });

  const rows = await client.queryObject<QuestionBankItemRow>(
    `UPDATE edu_question_bank_items SET
       subject_name = $2,
       chapter = $3,
       topic = COALESCE($4, topic),
       difficulty = COALESCE($5, difficulty),
       question_type = $6,
       marks = COALESCE($7, marks),
       question_text = $8,
       answer_text = $9,
       options = COALESCE($10::jsonb, options),
       program_track = COALESCE($11, program_track),
       cognitive_level = $12,
       syllabus_chapter_id = $13,
       syllabus_topic_id = $14,
       learning_outcome = $15,
       source_reference = $16,
       fingerprint = $17,
       updated_at = now()
     WHERE id = $1
     RETURNING *`,
    [
      id,
      subjectName,
      chapter,
      input.topic ?? null,
      input.difficulty ?? null,
      questionType,
      input.marks ?? null,
      questionText,
      input.answerText === undefined ? existing.answer_text : input.answerText,
      input.options === undefined ? null : JSON.stringify(input.options),
      input.programTrack ?? null,
      input.cognitiveLevel === undefined ? existing.cognitive_level : input.cognitiveLevel,
      input.syllabusChapterId === undefined ? existing.syllabus_chapter_id : input.syllabusChapterId,
      input.syllabusTopicId === undefined ? existing.syllabus_topic_id : input.syllabusTopicId,
      input.learningOutcome === undefined ? existing.learning_outcome : input.learningOutcome,
      input.sourceReference === undefined ? existing.source_reference : input.sourceReference,
      fingerprint,
    ],
  );
  return rows[0] ?? null;
}

export async function archiveQuestionBankItem(
  client: TenantQueryClient,
  id: string,
): Promise<QuestionBankItemRow | null> {
  const result = await client.queryObject<QuestionBankItemRow>(
    `UPDATE edu_question_bank_items SET status = 'archived', updated_at = now()
     WHERE id = $1 RETURNING *`,
    [id],
  );
  return result[0] ?? null;
}

export interface CreateQuestionPaperInput {
  academicYearId?: string;
  academicYearLabel: string;
  className: string;
  sectionName?: string;
  subjectName: string;
  chapters: string[];
  difficulty: EduDifficulty;
  totalMarks: number;
  examType: EduExamType;
  programTrack?: EduProgramTrack;
  title: string;
  blueprint: Record<string, unknown>;
  answerKey: unknown;
  createdBy: string;
  items: Array<{
    bankItemId?: string;
    questionType: string;
    marks: number;
    questionText: string;
    answerText: string;
    options: string[];
    source: string;
    reviewStatus?: EduReviewStatus;
  }>;
}

export async function createQuestionPaper(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateQuestionPaperInput,
): Promise<{ paper: QuestionPaperRow; items: QuestionPaperItemRow[] }> {
  const paperResult = await client.queryObject<QuestionPaperRow>(
    `INSERT INTO edu_question_papers (
       organization_id, school_id, academic_year_id, academic_year_label,
       class_name, section_name, subject_name, chapters, difficulty,
       total_marks, exam_type, program_track, title, blueprint, answer_key, created_by
     ) VALUES (
       $1, $2, $3, $4, $5, $6, $7, $8::jsonb, $9, $10, $11, $12, $13, $14::jsonb, $15::jsonb, $16
     )
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.academicYearId ?? null,
      input.academicYearLabel,
      input.className,
      input.sectionName ?? null,
      input.subjectName,
      JSON.stringify(input.chapters),
      input.difficulty,
      input.totalMarks,
      input.examType,
      input.programTrack ?? "board",
      input.title,
      JSON.stringify(input.blueprint),
      JSON.stringify(input.answerKey),
      input.createdBy,
    ],
  );
  const paper = paperResult[0]!;

  const items: QuestionPaperItemRow[] = [];
  for (let i = 0; i < input.items.length; i++) {
    const item = input.items[i]!;
    const itemRows = await client.queryObject<QuestionPaperItemRow>(
      `INSERT INTO edu_question_paper_items (
         paper_id, organization_id, school_id, sort_order, bank_item_id,
         question_type, marks, question_text, answer_text, options, source, review_status
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11, $12)
       RETURNING *`,
      [
        paper.id,
        organizationId,
        schoolId,
        i,
        item.bankItemId ?? null,
        item.questionType,
        item.marks,
        item.questionText,
        item.answerText,
        JSON.stringify(item.options),
        item.source,
        item.reviewStatus ?? "approved",
      ],
    );
    items.push(itemRows[0]!);
  }

  return { paper, items };
}

export async function listQuestionPapers(
  client: TenantQueryClient,
  filters: { className?: string; subjectName?: string; page?: number; pageSize?: number },
): Promise<PaginationResult<QuestionPaperRow>> {
  const page = Math.max(1, filters.page ?? 1);
  const pageSize = clampPageSize(filters.pageSize ?? 20);
  const offset = (page - 1) * pageSize;
  const conditions: string[] = ["1=1"];
  const params: unknown[] = [];
  let paramIndex = 1;

  if (filters.className) {
    conditions.push(`class_name ILIKE $${paramIndex}`);
    params.push(`%${filters.className}%`);
    paramIndex += 1;
  }
  if (filters.subjectName) {
    conditions.push(`subject_name ILIKE $${paramIndex}`);
    params.push(`%${filters.subjectName}%`);
    paramIndex += 1;
  }

  const where = conditions.join(" AND ");
  const total = await client.queryCount(
    `SELECT count(*)::text AS count FROM edu_question_papers WHERE ${where}`,
    params,
  );

  const items = await client.queryObject<QuestionPaperRow>(
    `SELECT * FROM edu_question_papers WHERE ${where}
     ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
    [...params, pageSize, offset],
  );

  return { items, total, page, pageSize };
}

export async function getQuestionPaperWithItems(
  client: TenantQueryClient,
  paperId: string,
): Promise<{ paper: QuestionPaperRow; items: QuestionPaperItemRow[] } | null> {
  const paperResult = await client.queryObject<QuestionPaperRow>(
    `SELECT * FROM edu_question_papers WHERE id = $1`,
    [paperId],
  );
  const paper = paperResult[0];
  if (!paper) return null;

  const items = await client.queryObject<QuestionPaperItemRow>(
    `SELECT * FROM edu_question_paper_items WHERE paper_id = $1 ORDER BY sort_order`,
    [paperId],
  );
  return { paper, items };
}

/** Count of paper items still awaiting moderation (unapproved AI candidates). */
export async function countPendingPaperItems(
  client: TenantQueryClient,
  paperId: string,
): Promise<number> {
  return await client.queryCount(
    `SELECT count(*)::text AS count FROM edu_question_paper_items
     WHERE paper_id = $1 AND review_status = 'pending'`,
    [paperId],
  );
}

export type PublishPaperResult =
  | { ok: true; paper: QuestionPaperRow }
  | { ok: false; reason: "not_found" | "not_approved" | "pending_items"; pendingItems?: number };

/**
 * Publish gate (Batch 8b governance). Two rules:
 *   1. HARD, always: a paper with any pending AI candidate cannot publish —
 *      nothing AI-authored reaches students without a human sign-off (the one
 *      non-negotiable from the AI policy).
 *   2. If a review has been STARTED (submitted / changes_requested), the paper
 *      must reach 'approved' before publishing — we don't let a publish bypass
 *      an in-flight review.
 * A plain draft with no pending AI candidates still publishes directly, so
 * existing 100%-bank flows are unaffected until the 8c moderation UI lands.
 */
export async function publishQuestionPaper(
  client: TenantQueryClient,
  paperId: string,
): Promise<PublishPaperResult> {
  const rows = await client.queryObject<QuestionPaperRow>(
    `SELECT * FROM edu_question_papers WHERE id = $1`,
    [paperId],
  );
  const paper = rows[0];
  if (!paper) return { ok: false, reason: "not_found" };

  const pending = await countPendingPaperItems(client, paperId);
  if (pending > 0) return { ok: false, reason: "pending_items", pendingItems: pending };

  if (paper.review_status === "submitted" || paper.review_status === "changes_requested") {
    return { ok: false, reason: "not_approved" };
  }

  const updated = await client.queryObject<QuestionPaperRow>(
    `UPDATE edu_question_papers
     SET status = 'published', review_status = 'published',
         published_at = now(), updated_at = now()
     WHERE id = $1 RETURNING *`,
    [paperId],
  );
  return { ok: true, paper: updated[0]! };
}

// ─── Paper review / approval governance (Batch 8b) ───────────────────────────

async function recordPaperReview(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  paperId: string,
  status: "submitted" | "changes_requested" | "approved",
  reviewerUserId: string,
  comments: string | null,
): Promise<QuestionPaperReviewRow> {
  const roundResult = await client.queryObject<{ next_round: number }>(
    `SELECT COALESCE(MAX(round_number), 0) + 1 AS next_round
     FROM edu_question_paper_reviews WHERE paper_id = $1`,
    [paperId],
  );
  const round = roundResult[0]?.next_round ?? 1;
  const rows = await client.queryObject<QuestionPaperReviewRow>(
    `INSERT INTO edu_question_paper_reviews (
       paper_id, organization_id, school_id, round_number, status,
       reviewer_user_id, comments
     ) VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [paperId, organizationId, schoolId, round, status, reviewerUserId, comments],
  );
  return rows[0]!;
}

/** Move a draft / changes_requested paper to 'submitted' for review. */
export async function submitQuestionPaper(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  paperId: string,
  submittedBy: string,
): Promise<{ paper: QuestionPaperRow; review: QuestionPaperReviewRow } | null> {
  const rows = await client.queryObject<QuestionPaperRow>(
    `UPDATE edu_question_papers
     SET review_status = 'submitted', submitted_by = $2, submitted_at = now(),
         updated_at = now()
     WHERE id = $1 AND review_status IN ('draft', 'changes_requested')
     RETURNING *`,
    [paperId, submittedBy],
  );
  const paper = rows[0];
  if (!paper) return null;
  const review = await recordPaperReview(
    client, organizationId, schoolId, paperId, "submitted", submittedBy, null,
  );
  return { paper, review };
}

/** Reviewer decision on a submitted paper: approve or request changes. */
export async function reviewQuestionPaper(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  paperId: string,
  decision: "approved" | "changes_requested",
  reviewerUserId: string,
  comments: string | null,
): Promise<{ paper: QuestionPaperRow; review: QuestionPaperReviewRow } | null> {
  const setApproval = decision === "approved"
    ? "review_status = 'approved', approved_by = $2, approved_at = now()"
    : "review_status = 'changes_requested'";
  const rows = await client.queryObject<QuestionPaperRow>(
    `UPDATE edu_question_papers
     SET ${setApproval}, updated_at = now()
     WHERE id = $1 AND review_status = 'submitted'
     RETURNING *`,
    [paperId, reviewerUserId],
  );
  const paper = rows[0];
  if (!paper) return null;
  const review = await recordPaperReview(
    client, organizationId, schoolId, paperId, decision, reviewerUserId, comments,
  );
  return { paper, review };
}

/** Approve or reject a single AI-candidate paper item (moderation). */
export async function moderatePaperItem(
  client: TenantQueryClient,
  paperId: string,
  itemId: string,
  decision: "approved" | "rejected",
): Promise<QuestionPaperItemRow | null> {
  const rows = await client.queryObject<QuestionPaperItemRow>(
    `UPDATE edu_question_paper_items
     SET review_status = $3
     WHERE id = $1 AND paper_id = $2 AND review_status = 'pending'
     RETURNING *`,
    [itemId, paperId, decision],
  );
  return rows[0] ?? null;
}

/** A paper can be edited only before it is locked (published / archived). */
function paperIsEditable(reviewStatus: string): boolean {
  return reviewStatus !== "published" && reviewStatus !== "archived";
}

/** Rebuild the stored answer key from the paper's current items, in order. */
async function rebuildPaperAnswerKey(
  client: TenantQueryClient,
  paperId: string,
): Promise<void> {
  const items = await client.queryObject<QuestionPaperItemRow>(
    `SELECT * FROM edu_question_paper_items WHERE paper_id = $1 ORDER BY sort_order`,
    [paperId],
  );
  const answerKey = items.map((item, index) => ({
    questionNumber: index + 1,
    answer: item.answer_text ?? "",
    marks: item.marks,
  }));
  await client.queryObject(
    `UPDATE edu_question_papers SET answer_key = $2::jsonb, updated_at = now()
     WHERE id = $1`,
    [paperId, JSON.stringify(answerKey)],
  );
}

export interface UpdatePaperItemInput {
  questionType?: EduQuestionType;
  marks?: number;
  questionText?: string;
  answerText?: string | null;
  options?: string[];
}

export type UpdatePaperItemResult =
  | { ok: true; item: QuestionPaperItemRow; approvalReset: boolean }
  | { ok: false; reason: "not_found" | "not_editable" };

/**
 * Edit one question inside a paper (Feature A, token-free). This is the fast
 * "just fix that one question" path — the rest of the paper is untouched.
 *
 * Guards:
 *  - A published / archived paper is locked → not_editable.
 *  - Editing an already-approved paper invalidates the sign-off, so the paper is
 *    reset to 'draft' and must be re-submitted for the principal's approval. The
 *    stored answer key is rebuilt so exports stay consistent with the edit.
 */
export async function updatePaperItem(
  client: TenantQueryClient,
  paperId: string,
  itemId: string,
  input: UpdatePaperItemInput,
): Promise<UpdatePaperItemResult> {
  const paperRows = await client.queryObject<QuestionPaperRow>(
    `SELECT * FROM edu_question_papers WHERE id = $1`,
    [paperId],
  );
  const paper = paperRows[0];
  if (!paper) return { ok: false, reason: "not_found" };
  if (!paperIsEditable(paper.review_status)) return { ok: false, reason: "not_editable" };

  const rows = await client.queryObject<QuestionPaperItemRow>(
    `UPDATE edu_question_paper_items SET
       question_type = COALESCE($3, question_type),
       marks = COALESCE($4, marks),
       question_text = COALESCE($5, question_text),
       answer_text = $6,
       options = COALESCE($7::jsonb, options)
     WHERE id = $1 AND paper_id = $2
     RETURNING *`,
    [
      itemId,
      paperId,
      input.questionType ?? null,
      input.marks ?? null,
      input.questionText ?? null,
      input.answerText === undefined ? null : input.answerText,
      input.options === undefined ? null : JSON.stringify(input.options),
    ],
  );
  const item = rows[0];
  if (!item) return { ok: false, reason: "not_found" };

  await rebuildPaperAnswerKey(client, paperId);

  let approvalReset = false;
  if (paper.review_status === "approved") {
    await client.queryObject(
      `UPDATE edu_question_papers
       SET review_status = 'draft', approved_by = NULL, approved_at = NULL,
           updated_at = now()
       WHERE id = $1`,
      [paperId],
    );
    approvalReset = true;
  }

  return { ok: true, item, approvalReset };
}

/**
 * Replace one paper item's content with a freshly AI-authored candidate
 * (Feature B). The slot becomes source='ai_candidate', review_status='pending'
 * again, so it must be re-moderated before the paper can be published — the AI
 * sign-off rule still holds. Approval (if any) is reset, like an edit.
 */
export async function applyRegeneratedPaperItem(
  client: TenantQueryClient,
  paperId: string,
  itemId: string,
  content: {
    questionType: EduQuestionType;
    marks: number;
    questionText: string;
    answerText: string;
    options: string[];
  },
): Promise<UpdatePaperItemResult> {
  const paperRows = await client.queryObject<QuestionPaperRow>(
    `SELECT * FROM edu_question_papers WHERE id = $1`,
    [paperId],
  );
  const paper = paperRows[0];
  if (!paper) return { ok: false, reason: "not_found" };
  if (!paperIsEditable(paper.review_status)) return { ok: false, reason: "not_editable" };

  const rows = await client.queryObject<QuestionPaperItemRow>(
    `UPDATE edu_question_paper_items SET
       question_type = $3, marks = $4, question_text = $5, answer_text = $6,
       options = $7::jsonb, source = 'ai_candidate', review_status = 'pending'
     WHERE id = $1 AND paper_id = $2
     RETURNING *`,
    [
      itemId,
      paperId,
      content.questionType,
      content.marks,
      content.questionText,
      content.answerText,
      JSON.stringify(content.options),
    ],
  );
  const item = rows[0];
  if (!item) return { ok: false, reason: "not_found" };

  await rebuildPaperAnswerKey(client, paperId);

  let approvalReset = false;
  if (paper.review_status === "approved") {
    await client.queryObject(
      `UPDATE edu_question_papers
       SET review_status = 'draft', approved_by = NULL, approved_at = NULL,
           updated_at = now()
       WHERE id = $1`,
      [paperId],
    );
    approvalReset = true;
  }
  return { ok: true, item, approvalReset };
}

/** Read one paper + a single item (for the regenerate slot reconstruction). */
export async function getPaperItem(
  client: TenantQueryClient,
  paperId: string,
  itemId: string,
): Promise<{ paper: QuestionPaperRow; item: QuestionPaperItemRow } | null> {
  const paperRows = await client.queryObject<QuestionPaperRow>(
    `SELECT * FROM edu_question_papers WHERE id = $1`,
    [paperId],
  );
  const paper = paperRows[0];
  if (!paper) return null;
  const itemRows = await client.queryObject<QuestionPaperItemRow>(
    `SELECT * FROM edu_question_paper_items WHERE id = $1 AND paper_id = $2`,
    [itemId, paperId],
  );
  const item = itemRows[0];
  if (!item) return null;
  return { paper, item };
}

/**
 * Promote an approved AI-candidate paper item into the reusable bank
 * (Feature E, token-free). Only an item a human has already approved is
 * eligible — nothing AI-authored enters the bank without sign-off. Subject /
 * program track default from the parent paper; chapter and the optional
 * syllabus/cognitive metadata come from the caller. De-dupes by fingerprint.
 */
export type PromotePaperItemResult =
  | { ok: true; item: QuestionBankItemRow; duplicate: boolean }
  | { ok: false; reason: "not_found" | "not_approved" };

export async function promotePaperItemToBank(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  paperId: string,
  itemId: string,
  overrides: {
    chapter?: string;
    topic?: string;
    difficulty?: EduDifficulty;
    cognitiveLevel?: EduCognitiveLevel;
    syllabusChapterId?: string;
    syllabusTopicId?: string;
    learningOutcome?: string;
  },
  createdBy: string,
): Promise<PromotePaperItemResult> {
  const paperRows = await client.queryObject<QuestionPaperRow>(
    `SELECT * FROM edu_question_papers WHERE id = $1`,
    [paperId],
  );
  const paper = paperRows[0];
  if (!paper) return { ok: false, reason: "not_found" };

  const itemRows = await client.queryObject<QuestionPaperItemRow>(
    `SELECT * FROM edu_question_paper_items WHERE id = $1 AND paper_id = $2`,
    [itemId, paperId],
  );
  const item = itemRows[0];
  if (!item) return { ok: false, reason: "not_found" };
  // Only an AI item that a human has approved may enter the reusable bank.
  const isAiItem = item.source === "ai_candidate" || item.source === "ai_generated";
  if (!isAiItem || item.review_status !== "approved") {
    return { ok: false, reason: "not_approved" };
  }

  const paperChapters = Array.isArray(paper.chapters) ? paper.chapters as string[] : [];
  const chapter = overrides.chapter ?? paperChapters[0] ?? "General";
  const difficulty: EduDifficulty = overrides.difficulty ??
    (paper.difficulty === "mixed" ? "medium" : (paper.difficulty as EduDifficulty));

  const fingerprint = computeQuestionFingerprint({
    subjectName: paper.subject_name,
    chapter,
    questionType: item.question_type,
    questionText: item.question_text,
  });
  const existing = await findBankItemByFingerprint(client, fingerprint);
  if (existing) return { ok: true, item: existing, duplicate: true };

  const created = await createQuestionBankItem(client, organizationId, schoolId, {
    subjectName: paper.subject_name,
    chapter,
    topic: overrides.topic,
    difficulty,
    questionType: item.question_type as EduQuestionType,
    marks: item.marks,
    questionText: item.question_text,
    answerText: item.answer_text ?? undefined,
    options: Array.isArray(item.options) ? item.options as string[] : [],
    source: "ai_candidate",
    sourceReference: `paper:${paperId}`,
    programTrack: paper.program_track as EduProgramTrack,
    cognitiveLevel: overrides.cognitiveLevel,
    syllabusChapterId: overrides.syllabusChapterId,
    syllabusTopicId: overrides.syllabusTopicId,
    learningOutcome: overrides.learningOutcome,
    reviewStatus: "approved",
    createdBy,
  });
  return { ok: true, item: created, duplicate: false };
}

export async function listPaperReviews(
  client: TenantQueryClient,
  paperId: string,
): Promise<QuestionPaperReviewRow[]> {
  return await client.queryObject<QuestionPaperReviewRow>(
    `SELECT * FROM edu_question_paper_reviews
     WHERE paper_id = $1 ORDER BY round_number`,
    [paperId],
  );
}

export interface CreateHomeworkInput {
  academicYearLabel: string;
  className: string;
  sectionName?: string;
  subjectName: string;
  topic: string;
  difficulty: EduDifficulty;
  assignmentType: EduHomeworkType;
  title: string;
  content: Array<{ prompt: string; answerHint: string }>;
  dueDate?: string;
  createdBy: string;
}

export interface HomeworkRow {
  id: string;
  organization_id: string;
  school_id: string;
  academic_year_label: string;
  class_name: string;
  section_name: string | null;
  subject_name: string;
  topic: string;
  difficulty: string;
  assignment_type: string;
  title: string;
  content: unknown;
  due_date: string | null;
  status: string;
  created_by: string | null;
  published_at: string | null;
  created_at: string;
  updated_at: string;
}

export async function createHomeworkAssignment(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateHomeworkInput,
): Promise<HomeworkRow> {
  const result = await client.queryObject<HomeworkRow>(
    `INSERT INTO edu_homework_assignments (
       organization_id, school_id, academic_year_label, class_name, section_name,
       subject_name, topic, difficulty, assignment_type, title, content, due_date, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, $12, $13)
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.academicYearLabel,
      input.className,
      input.sectionName ?? null,
      input.subjectName,
      input.topic,
      input.difficulty,
      input.assignmentType,
      input.title,
      JSON.stringify(input.content),
      input.dueDate ?? null,
      input.createdBy,
    ],
  );
  return result[0]!;
}

export async function listHomeworkAssignments(
  client: TenantQueryClient,
  filters: {
    className?: string;
    subjectName?: string;
    status?: string;
    page?: number;
    pageSize?: number;
  },
): Promise<PaginationResult<HomeworkRow>> {
  const page = Math.max(1, filters.page ?? 1);
  const pageSize = clampPageSize(filters.pageSize ?? 20);
  const offset = (page - 1) * pageSize;
  const conditions: string[] = ["1=1"];
  const params: unknown[] = [];
  let paramIndex = 1;

  if (filters.className) {
    conditions.push(`class_name ILIKE $${paramIndex}`);
    params.push(`%${filters.className}%`);
    paramIndex += 1;
  }
  if (filters.subjectName) {
    conditions.push(`subject_name ILIKE $${paramIndex}`);
    params.push(`%${filters.subjectName}%`);
    paramIndex += 1;
  }
  if (filters.status) {
    conditions.push(`status = $${paramIndex}`);
    params.push(filters.status);
    paramIndex += 1;
  }

  const where = conditions.join(" AND ");
  const total = await client.queryCount(
    `SELECT count(*)::text AS count FROM edu_homework_assignments WHERE ${where}`,
    params,
  );

  const items = await client.queryObject<HomeworkRow>(
    `SELECT * FROM edu_homework_assignments WHERE ${where}
     ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
    [...params, pageSize, offset],
  );

  return { items, total, page, pageSize };
}

export async function getHomeworkAssignment(
  client: TenantQueryClient,
  id: string,
): Promise<HomeworkRow | null> {
  const result = await client.queryObject<HomeworkRow>(
    `SELECT * FROM edu_homework_assignments WHERE id = $1`,
    [id],
  );
  return result[0] ?? null;
}

export async function publishHomeworkAssignment(
  client: TenantQueryClient,
  id: string,
): Promise<HomeworkRow | null> {
  const result = await client.queryObject<HomeworkRow>(
    `UPDATE edu_homework_assignments
     SET status = 'published', published_at = now(), updated_at = now()
     WHERE id = $1 RETURNING *`,
    [id],
  );
  return result[0] ?? null;
}

export interface CreateReportRemarkInput {
  studentId: string;
  academicYearLabel: string;
  remarkType: EduRemarkType;
  language: EduRemarkLanguage;
  inputs: Record<string, unknown>;
  generatedRemark: string;
  createdBy: string;
}

export interface ReportRemarkRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  academic_year_label: string;
  remark_type: string;
  language: string;
  inputs: unknown;
  generated_remark: string;
  edited_remark: string | null;
  status: string;
  created_by: string | null;
  published_at: string | null;
  created_at: string;
  updated_at: string;
}

export async function createReportRemark(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: CreateReportRemarkInput,
): Promise<ReportRemarkRow> {
  const result = await client.queryObject<ReportRemarkRow>(
    `INSERT INTO edu_report_card_remarks (
       organization_id, school_id, student_id, academic_year_label,
       remark_type, language, inputs, generated_remark, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9)
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.studentId,
      input.academicYearLabel,
      input.remarkType,
      input.language,
      JSON.stringify(input.inputs),
      input.generatedRemark,
      input.createdBy,
    ],
  );
  return result[0]!;
}

export async function listReportRemarks(
  client: TenantQueryClient,
  filters: { studentId?: string; academicYearLabel?: string; page?: number; pageSize?: number },
): Promise<PaginationResult<ReportRemarkRow>> {
  const page = Math.max(1, filters.page ?? 1);
  const pageSize = clampPageSize(filters.pageSize ?? 20);
  const offset = (page - 1) * pageSize;
  const conditions: string[] = ["1=1"];
  const params: unknown[] = [];
  let paramIndex = 1;

  if (filters.studentId) {
    conditions.push(`student_id = $${paramIndex}::uuid`);
    params.push(filters.studentId);
    paramIndex += 1;
  }
  if (filters.academicYearLabel) {
    conditions.push(`academic_year_label = $${paramIndex}`);
    params.push(filters.academicYearLabel);
    paramIndex += 1;
  }

  const where = conditions.join(" AND ");
  const total = await client.queryCount(
    `SELECT count(*)::text AS count FROM edu_report_card_remarks WHERE ${where}`,
    params,
  );

  const items = await client.queryObject<ReportRemarkRow>(
    `SELECT * FROM edu_report_card_remarks WHERE ${where}
     ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
    [...params, pageSize, offset],
  );

  return { items, total, page, pageSize };
}

export async function updateReportRemark(
  client: TenantQueryClient,
  id: string,
  editedRemark: string,
): Promise<ReportRemarkRow | null> {
  const result = await client.queryObject<ReportRemarkRow>(
    `UPDATE edu_report_card_remarks
     SET edited_remark = $2, updated_at = now()
     WHERE id = $1 RETURNING *`,
    [id, editedRemark],
  );
  return result[0] ?? null;
}

export async function publishReportRemark(
  client: TenantQueryClient,
  id: string,
): Promise<ReportRemarkRow | null> {
  const result = await client.queryObject<ReportRemarkRow>(
    `UPDATE edu_report_card_remarks
     SET status = 'published', published_at = now(), updated_at = now()
     WHERE id = $1 RETURNING *`,
    [id],
  );
  return result[0] ?? null;
}
