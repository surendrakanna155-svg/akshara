import type { TenantQueryClient } from "../tenant_db.ts";
import type {
  EduDifficulty,
  EduExamType,
  EduHomeworkType,
  EduQuestionType,
  EduRemarkLanguage,
  EduRemarkType,
  QuestionBankItemRow,
  QuestionPaperItemRow,
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
  const result = await client.queryObject<QuestionBankItemRow>(
    `INSERT INTO edu_question_bank_items (
       organization_id, school_id, subject_name, chapter, topic,
       difficulty, question_type, marks, question_text, answer_text, options, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, $12)
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
      input.createdBy,
    ],
  );
  return result[0]!;
}

export async function importQuestionBankItems(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: ImportQuestionBankInput,
): Promise<QuestionBankItemRow[]> {
  const created: QuestionBankItemRow[] = [];
  for (const item of input.items) {
    created.push(
      await createQuestionBankItem(client, organizationId, schoolId, {
        ...item,
        createdBy: item.createdBy ?? input.createdBy ?? "",
      }),
    );
  }
  return created;
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
       total_marks, exam_type, title, blueprint, answer_key, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb, $9, $10, $11, $12, $13::jsonb, $14::jsonb, $15)
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
         question_type, marks, question_text, answer_text, options, source
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11)
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

export async function publishQuestionPaper(
  client: TenantQueryClient,
  paperId: string,
): Promise<QuestionPaperRow | null> {
  const result = await client.queryObject<QuestionPaperRow>(
    `UPDATE edu_question_papers
     SET status = 'published', published_at = now(), updated_at = now()
     WHERE id = $1 RETURNING *`,
    [paperId],
  );
  return result[0] ?? null;
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
