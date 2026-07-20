/** Academics / Exams / Timetable contracts — mirror lib/features/academics/**. */

/** Exam lifecycle phase (ExamLifecyclePhase / ExamApprovalStatus). Rendered generically. */
export type ExamPhase =
  | 'none'
  | 'scheduled'
  | 'marksInProgress'
  | 'awaitingVerification'
  | 'awaitingApproval'
  | 'returned'
  | 'published';

export interface ExamListItem {
  id: string;
  title: string;
  subject: string;
  grade: string;
  section: string;
  termLabel: string;
  dateLabel: string;
  maxMarks: number;
  phase: ExamPhase;
  examType: string;
}

export interface ExamProgressItem {
  id: string;
  title: string;
  grade: string;
  section: string;
  subject: string;
  entered: number;
  total: number;
  phase: ExamPhase;
}

export interface ExamMarkRow {
  id: string;
  studentName: string;
  rollNo: string;
  marksObtained: number | null;
  maxMarks: number;
  status: string;
  published: boolean;
}

export interface TimetableListItem {
  id: string;
  sectionLabel: string;
  status: 'draft' | 'validated' | 'published' | 'archived';
  periodCount: number;
  conflictCount: number;
}

export interface TimetableSubstitution {
  id: string;
  subDate: string;
  originalTeacherName?: string;
  substituteTeacherName?: string;
  reason: string;
  status: string;
  sectionLabel?: string;
  periodNumber?: number;
  subjectLabel?: string;
}
