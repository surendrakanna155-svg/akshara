import type { TenantQueryClient } from "../tenant_db.ts";
import { getRiskSnapshotByStudent } from "../intelligence/student_risk_repository.ts";

export type InsightPeriod = "daily" | "weekly" | "monthly" | "exam_prep";

/**
 * PRA-P0-21 (S6): thrown when no risk snapshot is readable for the requested
 * student — a parent whose child has none computed yet, or (defence in depth
 * behind the RLS + child_ids gate) a studentId the caller can't see. The handler
 * maps it to an honest 404 "no insights yet". This REPLACES the old behaviour of
 * silently defaulting the missing metrics to 85%/80%/70%/"your child" and having
 * the model narrate the fabrication as real school data.
 */
export class ParentInsightsNoDataError extends Error {
  constructor(public readonly studentId: string) {
    super(`No insight data available for student ${studentId}`);
    this.name = "ParentInsightsNoDataError";
  }
}

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
  // PRA-P0-21: when there is NO readable risk snapshot for this student, do NOT
  // fabricate metrics. Previously this silently defaulted to 85%/80%/70%/"your
  // child" — so a parent whose token could not read the (school-scoped) source
  // row got invented data narrated as real. Reject before the model call.
  if (!risk) {
    throw new ParentInsightsNoDataError(studentId);
  }
  const inputs = risk.inputs as Record<string, unknown> | null;
  const attendance = inputs?.attendance_percent as number | undefined;
  const homework = inputs?.homework_completion_rate as number | undefined;
  const marks = inputs?.average_marks as number | undefined;
  const name = (inputs?.student_name as string | undefined) ?? "your child";

  const periodLabel = period === "exam_prep" ? "Exam preparation" : period;

  // Each metric is only asserted when it is actually present on the snapshot —
  // a missing field is reported as "not available yet", never as a number.
  const attendanceInsights: string[] = [];
  if (typeof attendance === "number") {
    attendanceInsights.push(
      attendance < 75
        ? `Attendance is ${attendance}% — below the recommended 75% threshold`
        : `Attendance is ${attendance}% — on track`,
    );
  } else {
    attendanceInsights.push("Attendance data is not available yet.");
  }

  const homeworkInsights: string[] = [];
  if (typeof homework === "number") {
    homeworkInsights.push(
      homework < 70
        ? `Homework completion is ${homework}% — follow up on pending assignments`
        : `Homework completion is ${homework}% — good consistency`,
    );
  } else {
    homeworkInsights.push("Homework completion data is not available yet.");
  }

  const langTag = language === "english" ? "" : ` (${language})`;
  const marksLabel = typeof marks === "number" ? `${marks}%` : "not available";
  const attendanceLabel = typeof attendance === "number" ? `${attendance}%` : "not available";
  const homeworkLabel = typeof homework === "number" ? `${homework}%` : "not available";

  return {
    period,
    language,
    progressSummary:
      `${periodLabel} summary${langTag} for ${name}: marks ${marksLabel}, attendance ${attendanceLabel}, homework ${homeworkLabel}.`,
    strengths: ["Consistent class participation", "Positive attitude toward learning"],
    weaknesses: typeof marks === "number" && marks < 60
      ? ["Needs support in core subjects"]
      : ["Time management during assessments"],
    attendanceInsights,
    homeworkInsights,
    improvementSuggestions: [
      "Allocate 30 minutes daily for revision",
      period === "exam_prep"
        ? "Focus on chapters with lowest mock scores"
        : "Review teacher feedback before next class",
      "Maintain regular sleep schedule before school days",
    ],
    teacherRemarksSummary: `Teachers note steady effort with room to improve in ${typeof marks === "number" && marks < 60 ? "academic scores" : "assessment preparation"}.`,
    voiceReady: true,
    printable: true,
  };
}
