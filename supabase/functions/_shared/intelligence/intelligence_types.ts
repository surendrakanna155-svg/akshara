export const RISK_LEVELS = ["low", "medium", "high", "critical"] as const;
export type RiskLevel = typeof RISK_LEVELS[number];

export const COMM_SCENARIOS = [
  "absent",
  "homework_missing",
  "low_attendance",
  "parent_meeting",
  "behavior_issue",
  "appreciation",
  "fee_reminder",
  "exam_reminder",
] as const;
export type CommunicationScenario = typeof COMM_SCENARIOS[number];

export const INTEL_LANGUAGES = [
  "english",
  "telugu",
  "hindi",
  "tamil",
  "kannada",
  "malayalam",
  "bengali",
  "marathi",
] as const;
export type IntelLanguage = typeof INTEL_LANGUAGES[number];

export const GUIDANCE_MODES = ["weekly", "monthly", "exam_review"] as const;
export type GuidanceMode = typeof GUIDANCE_MODES[number];

export interface StudentRiskInputs {
  attendancePercent: number;
  homeworkCompletionRate: number;
  averageMarksPercent: number;
  communicationGaps: number;
  behaviorIncidents: number;
  timetableMissedSessions: number;
  // feeOutstandingAmount: authoritative per-year fee balance (currency units) from
  // finance_student_accounts.outstanding_amount — the same column collections
  // decrement and the defaulters/finance-intelligence reads use. Default 0: a
  // paid-up student, or a fresh school with no fee accounts yet, carries no fee
  // risk (honest zero, never a fabricated balance).
  feeOutstandingAmount?: number;
  // feeOverdueDays: days past the earliest unpaid invoice due date (0 when no
  // overdue invoice / no account). Currently informational for the reason text.
  feeOverdueDays?: number;
}

export interface StudentRiskSnapshotRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  academic_year_label: string;
  class_name: string;
  section_name: string | null;
  risk_score: number;
  risk_level: string;
  reasons: unknown;
  interventions: unknown;
  teacher_actions: unknown;
  parent_notifications: unknown;
  inputs: unknown;
  computed_at: string;
  created_at: string;
}

export interface StudentSignalRow {
  student_id: string;
  student_name: string;
  class_name: string;
  section_name: string | null;
  attendance_percent: number;
  homework_completion_rate: number;
  average_marks_percent: number;
  communication_gaps: number;
  behavior_incidents: number;
  timetable_missed_sessions: number;
  fee_outstanding_amount: number;
  fee_overdue_days: number;
}
