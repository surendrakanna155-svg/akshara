import type {
  HomeworkRow,
  ReportRemarkRow,
} from "./education_repository.ts";
import type {
  QuestionBankItemRow,
  QuestionPaperItemRow,
  QuestionPaperReviewRow,
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
    source: row.source,
    sourceReference: row.source_reference,
    programTrack: row.program_track,
    jeeQuestionType: row.jee_question_type,
    cognitiveLevel: row.cognitive_level,
    syllabusChapterId: row.syllabus_chapter_id,
    syllabusTopicId: row.syllabus_topic_id,
    learningOutcome: row.learning_outcome,
    reviewStatus: row.review_status,
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
    programTrack: row.program_track,
    reviewStatus: row.review_status,
    blueprint: row.blueprint,
    answerKey: row.answer_key,
    submittedBy: row.submitted_by,
    submittedAt: row.submitted_at,
    approvedBy: row.approved_by,
    approvedAt: row.approved_at,
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
    reviewStatus: row.review_status,
  };
}

export function questionPaperReviewToApi(row: QuestionPaperReviewRow) {
  return {
    id: row.id,
    paperId: row.paper_id,
    roundNumber: row.round_number,
    status: row.status,
    reviewerUserId: row.reviewer_user_id,
    comments: row.comments,
    createdAt: row.created_at,
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
  // AI-1 moderation gate: only human-approved items may reach a student-facing
  // paper. Bank items default to 'approved' at creation; AI candidates are
  // 'pending' until moderated and become 'approved' or 'rejected'. A rejected
  // (human-disapproved) or still-pending item must never print. We renumber
  // and rebuild the answer key from the surviving items so question numbers and
  // the answer key stay aligned (the stored answer_key may reference excluded
  // items).
  const printable = items.filter((item) => item.review_status === "approved");
  const answerKey = printable.map((item, i) => ({
    questionNumber: i + 1,
    answer: item.answer_text ?? "",
    marks: item.marks,
  }));
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
    questions: printable.map((item, i) => questionPaperItemToApi(item, i)),
    answerKey,
    blueprint: paper.blueprint,
    generatedAt: new Date().toISOString(),
    format: "akshara-education-pdf-v1",
  };
}
