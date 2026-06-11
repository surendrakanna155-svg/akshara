export const EDU_DIFFICULTIES = ["easy", "medium", "hard", "mixed"] as const;
export type EduDifficulty = typeof EDU_DIFFICULTIES[number];

export const EDU_QUESTION_TYPES = [
  "mcq",
  "fill_blank",
  "match",
  "short_answer",
  "long_answer",
  "diagram",
] as const;
export type EduQuestionType = typeof EDU_QUESTION_TYPES[number];

export const EDU_EXAM_TYPES = [
  "unit_test",
  "weekly_test",
  "monthly_test",
  "quarterly",
  "half_yearly",
  "annual",
] as const;
export type EduExamType = typeof EDU_EXAM_TYPES[number];

export const EDU_HOMEWORK_TYPES = [
  "homework",
  "practice_worksheet",
  "revision_worksheet",
  "holiday_homework",
] as const;
export type EduHomeworkType = typeof EDU_HOMEWORK_TYPES[number];

export const EDU_REMARK_TYPES = [
  "principal",
  "class_teacher",
  "subject_teacher",
] as const;
export type EduRemarkType = typeof EDU_REMARK_TYPES[number];

export const EDU_REMARK_LANGUAGES = ["english", "telugu", "hindi"] as const;
export type EduRemarkLanguage = typeof EDU_REMARK_LANGUAGES[number];

export interface GenerateQuestionPaperInput {
  academicYearId?: string;
  academicYearLabel: string;
  className: string;
  sectionName?: string;
  subjectName: string;
  chapters: string[];
  difficulty: EduDifficulty;
  totalMarks: number;
  examType: EduExamType;
  questionTypeMix?: Partial<Record<EduQuestionType, number>>;
}

export interface QuestionBankItemRow {
  id: string;
  organization_id: string;
  school_id: string;
  subject_name: string;
  chapter: string;
  topic: string;
  difficulty: string;
  question_type: string;
  marks: number;
  question_text: string;
  answer_text: string | null;
  options: unknown;
  status: string;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

export interface QuestionPaperRow {
  id: string;
  organization_id: string;
  school_id: string;
  academic_year_id: string | null;
  academic_year_label: string;
  class_name: string;
  section_name: string | null;
  subject_name: string;
  chapters: unknown;
  difficulty: string;
  total_marks: number;
  exam_type: string;
  title: string;
  status: string;
  blueprint: Record<string, unknown>;
  answer_key: unknown;
  created_by: string | null;
  published_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface QuestionPaperItemRow {
  id: string;
  paper_id: string;
  organization_id: string;
  school_id: string;
  sort_order: number;
  bank_item_id: string | null;
  question_type: string;
  marks: number;
  question_text: string;
  answer_text: string | null;
  options: unknown;
  source: string;
}
