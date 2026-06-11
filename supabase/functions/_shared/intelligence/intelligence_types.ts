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
}
