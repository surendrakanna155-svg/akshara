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

// Batch 8b — Question Intelligence foundation.

export const EDU_PROGRAM_TRACKS = [
  "board",
  "jee_foundation",
  "neet_foundation",
  "ntse",
  "olympiad",
] as const;
export type EduProgramTrack = typeof EDU_PROGRAM_TRACKS[number];

export const EDU_QUESTION_SOURCES = [
  "teacher",
  "school",
  "import",
  "pyq",
  "publisher",
  "ai_candidate",
] as const;
export type EduQuestionSource = typeof EDU_QUESTION_SOURCES[number];

export const EDU_COGNITIVE_LEVELS = [
  "remember",
  "understand",
  "apply",
  "analyze",
  "hots",
] as const;
export type EduCognitiveLevel = typeof EDU_COGNITIVE_LEVELS[number];

/** Per-row moderation state shared by bank items and AI paper candidates. */
export const EDU_REVIEW_STATUSES = ["pending", "approved", "rejected"] as const;
export type EduReviewStatus = typeof EDU_REVIEW_STATUSES[number];

/** Paper-level approval lifecycle (governance, mirrors marks approval). */
export const EDU_PAPER_REVIEW_STATUSES = [
  "draft",
  "submitted",
  "changes_requested",
  "approved",
  "published",
  "archived",
] as const;
export type EduPaperReviewStatus = typeof EDU_PAPER_REVIEW_STATUSES[number];

/** How a paper item was sourced; 'ai_candidate' requires teacher approval. */
export const EDU_PAPER_ITEM_SOURCES = ["bank", "ai_generated", "ai_candidate"] as const;
export type EduPaperItemSource = typeof EDU_PAPER_ITEM_SOURCES[number];

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
  programTrack?: EduProgramTrack;
  questionTypeMix?: Partial<Record<EduQuestionType, number>>;
  /**
   * When true (default) and an Anthropic key is configured, blueprint gaps the
   * bank cannot fill are offered to Claude as moderation candidates (never
   * auto-published). When false, gaps are reported and left unfilled — no
   * placeholder/stub text is ever written into a paper.
   */
  allowAiGapFill?: boolean;
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
  source: string;
  source_reference: string | null;
  program_track: string;
  jee_question_type: string | null;
  cognitive_level: string | null;
  syllabus_chapter_id: string | null;
  syllabus_topic_id: string | null;
  learning_outcome: string | null;
  fingerprint: string | null;
  review_status: string;
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
  program_track: string;
  review_status: string;
  blueprint: Record<string, unknown>;
  answer_key: unknown;
  created_by: string | null;
  submitted_by: string | null;
  submitted_at: string | null;
  approved_by: string | null;
  approved_at: string | null;
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
  review_status: string;
}

export interface QuestionPaperReviewRow {
  id: string;
  paper_id: string;
  organization_id: string;
  school_id: string;
  round_number: number;
  status: string;
  reviewer_user_id: string | null;
  comments: string | null;
  created_at: string;
}
