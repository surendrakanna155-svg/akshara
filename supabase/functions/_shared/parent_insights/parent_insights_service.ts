import type { TenantQueryClient } from "../tenant_db.ts";
import { getRiskSnapshotByStudent } from "../intelligence/student_risk_repository.ts";

export type InsightPeriod = "daily" | "weekly" | "monthly" | "exam_prep";

export interface ParentInsightSnapshot {
  period: InsightPeriod;
  language: string;
  progressSummary: string;
  strengths: string[];
  weaknesses: string[];
  attendanceInsights: string[];
  homeworkInsights: string[];
  improvementSuggestions: string[];
  teacherRemarksSummary: string;
  voiceReady: boolean;
  printable: boolean;
}

export async function generateParentInsightSnapshot(
  client: TenantQueryClient,
  studentId: string,
  period: InsightPeriod,
  language = "english",
): Promise<ParentInsightSnapshot> {
  const risk = await getRiskSnapshotByStudent(client, studentId);
  const inputs = risk?.inputs as Record<string, unknown> | null;
  const attendance = (inputs?.attendance_percent as number | undefined) ?? 85;
  const homework = (inputs?.homework_completion_rate as number | undefined) ?? 80;
  const marks = (inputs?.average_marks as number | undefined) ?? 70;
  const name = (inputs?.student_name as string | undefined) ?? "your child";

  const periodLabel = period === "exam_prep" ? "Exam preparation" : period;

  const attendanceInsights: string[] = [];
  if (attendance < 75) {
    attendanceInsights.push(`Attendance is ${attendance}% — below the recommended 75% threshold`);
  } else {
    attendanceInsights.push(`Attendance is ${attendance}% — on track`);
  }

  const homeworkInsights: string[] = [];
  if (homework < 70) {
    homeworkInsights.push(`Homework completion is ${homework}% — follow up on pending assignments`);
  } else {
    homeworkInsights.push(`Homework completion is ${homework}% — good consistency`);
  }

  const langTag = language === "english" ? "" : ` (${language})`;

  return {
    period,
    language,
    progressSummary:
      `${periodLabel} summary${langTag} for ${name}: marks ${marks}%, attendance ${attendance}%, homework ${homework}%.`,
    strengths: ["Consistent class participation", "Positive attitude toward learning"],
    weaknesses: marks < 60 ? ["Needs support in core subjects"] : ["Time management during assessments"],
    attendanceInsights,
    homeworkInsights,
    improvementSuggestions: [
      "Allocate 30 minutes daily for revision",
      period === "exam_prep"
        ? "Focus on chapters with lowest mock scores"
        : "Review teacher feedback before next class",
      "Maintain regular sleep schedule before school days",
    ],
    teacherRemarksSummary: `Teachers note steady effort with room to improve in ${marks < 60 ? "academic scores" : "assessment preparation"}.`,
    voiceReady: true,
    printable: true,
  };
}
