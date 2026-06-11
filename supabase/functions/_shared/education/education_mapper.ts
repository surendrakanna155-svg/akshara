import type {
  HomeworkRow,
  ReportRemarkRow,
} from "./education_repository.ts";
import type {
  QuestionBankItemRow,
  QuestionPaperItemRow,
  QuestionPaperRow,
} from "./education_types.ts";

export function questionBankToApi(row: QuestionBankItemRow) {
  return {
    id: row.id,
    subjectName: row.subject_name,
    chapter: row.chapter,
    topic: row.topic,
    difficulty: row.difficulty,
    questionType: row.question_type,
    marks: row.marks,
    questionText: row.question_text,
    answerText: row.answer_text,
    options: row.options,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function questionPaperToApi(row: QuestionPaperRow) {
  return {
    id: row.id,
    academicYearId: row.academic_year_id,
    academicYearLabel: row.academic_year_label,
    className: row.class_name,
    sectionName: row.section_name,
    subjectName: row.subject_name,
    chapters: row.chapters,
    difficulty: row.difficulty,
    totalMarks: row.total_marks,
    examType: row.exam_type,
    title: row.title,
    status: row.status,
    blueprint: row.blueprint,
    answerKey: row.answer_key,
    publishedAt: row.published_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function questionPaperItemToApi(row: QuestionPaperItemRow, index: number) {
  return {
    id: row.id,
    questionNumber: index + 1,
    bankItemId: row.bank_item_id,
    questionType: row.question_type,
    marks: row.marks,
    questionText: row.question_text,
    answerText: row.answer_text,
    options: row.options,
    source: row.source,
  };
}

export function homeworkToApi(row: HomeworkRow) {
  return {
    id: row.id,
    academicYearLabel: row.academic_year_label,
    className: row.class_name,
    sectionName: row.section_name,
    subjectName: row.subject_name,
    topic: row.topic,
    difficulty: row.difficulty,
    assignmentType: row.assignment_type,
    title: row.title,
    content: row.content,
    dueDate: row.due_date,
    status: row.status,
    publishedAt: row.published_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function reportRemarkToApi(row: ReportRemarkRow) {
  return {
    id: row.id,
    studentId: row.student_id,
    academicYearLabel: row.academic_year_label,
    remarkType: row.remark_type,
    language: row.language,
    inputs: row.inputs,
    generatedRemark: row.generated_remark,
    editedRemark: row.edited_remark,
    displayRemark: row.edited_remark ?? row.generated_remark,
    status: row.status,
    publishedAt: row.published_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function paperExportDocument(
  paper: QuestionPaperRow,
  items: QuestionPaperItemRow[],
): Record<string, unknown> {
  return {
    title: paper.title,
    meta: {
      className: paper.class_name,
      sectionName: paper.section_name,
      subjectName: paper.subject_name,
      examType: paper.exam_type,
      totalMarks: paper.total_marks,
      difficulty: paper.difficulty,
    },
    questions: items.map((item, i) => questionPaperItemToApi(item, i)),
    answerKey: paper.answer_key,
    blueprint: paper.blueprint,
    generatedAt: new Date().toISOString(),
    format: "akshara-education-pdf-v1",
  };
}
