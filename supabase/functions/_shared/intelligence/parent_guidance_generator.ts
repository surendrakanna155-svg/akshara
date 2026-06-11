import type { GuidanceMode, IntelLanguage } from "./intelligence_types.ts";

export interface ParentGuidanceInputs {
  attendancePercent?: number;
  averageMarks?: number;
  homeworkCompletionRate?: number;
  strengths?: string[];
  weaknesses?: string[];
  studentName?: string;
}

export interface ParentGuidanceReport {
  progressSummary: string;
  strengths: string[];
  concerns: string[];
  studyRecommendations: string[];
  nextStepGuidance: string[];
}

const MODE_LABEL: Record<GuidanceMode, string> = {
  weekly: "Weekly",
  monthly: "Monthly",
  exam_review: "Exam review",
};

export function generateParentGuidanceReport(
  mode: GuidanceMode,
  language: IntelLanguage,
  inputs: ParentGuidanceInputs,
): ParentGuidanceReport {
  const name = inputs.studentName ?? "the student";
  const attendance = inputs.attendancePercent ?? 0;
  const marks = inputs.averageMarks ?? 0;
  const homework = inputs.homeworkCompletionRate ?? 0;
  const strengths = inputs.strengths?.length
    ? inputs.strengths
    : ["Consistent class participation"];
  const weaknesses = inputs.weaknesses?.length
    ? inputs.weaknesses
    : ["Time management during assessments"];

  const langTag = language === "english" ? "" : ` (${language})`;
  const period = MODE_LABEL[mode];

  const strengthExplanation = strengths.map(
    (s) => `${s}: consistent effort visible in class activities`,
  );
  const weaknessExplanation = weaknesses.map(
    (w) => `${w}: targeted practice and teacher check-ins recommended`,
  );

  const examExtras = mode === "exam_review"
    ? [
        "Create a chapter-wise revision timetable for the next 10 days",
        "Attempt one previous-year paper under timed conditions",
        "Review incorrect answers from the latest mock test",
      ]
    : [];

  const monthlyExtras = mode === "monthly"
    ? [
        "Track weekly attendance and homework completion on a simple chart",
        "Celebrate one academic win from this month with your child",
      ]
    : [];

  const weeklyExtras = mode === "weekly"
    ? [
        "Check the school diary daily for homework and notices",
        "Ensure 8 hours of sleep before school days",
      ]
    : [];

  return {
    progressSummary:
      `${period} progress summary${langTag} for ${name}: attendance ${attendance}% ` +
      `(${attendance >= 85 ? "on track" : "needs improvement"}), average marks ${marks}% ` +
      `(${marks >= 60 ? "satisfactory" : "below target"}), homework completion ${homework}%.`,
    strengths: strengthExplanation,
    concerns: weaknessExplanation.map((w) => `Area to support: ${w}`),
    studyRecommendations: [
      "Allocate 30 minutes daily for revision of weak topics",
      "Review homework feedback before the next class",
      ...(marks < 60 ? ["Schedule a subject teacher doubt-clearing session"] : []),
      ...examExtras,
      ...monthlyExtras,
      ...weeklyExtras,
    ],
    nextStepGuidance: [
      attendance < 75
        ? "Priority: improve attendance — discuss barriers with class teacher"
        : "Maintain regular attendance above 85%",
      homework < 70
        ? "Complete all pending homework this week before new assignments"
        : "Complete all pending homework this week",
      mode === "exam_review"
        ? "Focus revision on chapters with lowest mock scores"
        : "Check in with class teacher during the next PTM",
      "Print this report for PTM reference",
    ],
  };
}
