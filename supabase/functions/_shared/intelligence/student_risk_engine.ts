import type { RiskLevel, StudentRiskInputs } from "./intelligence_types.ts";

export interface RiskReason {
  code: string;
  label: string;
  severity: RiskLevel;
  detail: string;
}

export interface RiskIntervention {
  action: string;
  owner: "teacher" | "principal" | "parent" | "counselor";
  priority: "low" | "medium" | "high";
}

export interface ComputedStudentRisk {
  riskScore: number;
  riskLevel: RiskLevel;
  reasons: RiskReason[];
  interventions: RiskIntervention[];
  teacherActions: string[];
  parentNotifications: string[];
}

function clamp(n: number): number {
  return Math.max(0, Math.min(100, Math.round(n)));
}

export function riskLevelFromScore(score: number): RiskLevel {
  if (score >= 85) return "critical";
  if (score >= 65) return "high";
  if (score >= 40) return "medium";
  return "low";
}

export function computeStudentRisk(inputs: StudentRiskInputs): ComputedStudentRisk {
  const attendanceGap = clamp(100 - inputs.attendancePercent);
  const homeworkGap = clamp(100 - inputs.homeworkCompletionRate);
  const academicGap = clamp(100 - inputs.averageMarksPercent);
  const commGap = clamp(inputs.communicationGaps * 15);
  const behaviorGap = clamp(inputs.behaviorIncidents * 20);
  const timetableGap = clamp(inputs.timetableMissedSessions * 10);

  const riskScore = clamp(
    attendanceGap * 0.28 +
      homeworkGap * 0.22 +
      academicGap * 0.22 +
      commGap * 0.1 +
      behaviorGap * 0.1 +
      timetableGap * 0.08,
  );

  const reasons: RiskReason[] = [];
  if (inputs.attendancePercent < 75) {
    reasons.push({
      code: "low_attendance",
      label: "Low attendance",
      severity: inputs.attendancePercent < 60 ? "high" : "medium",
      detail: `Attendance is ${inputs.attendancePercent}% (below 75% threshold).`,
    });
  }
  if (inputs.homeworkCompletionRate < 70) {
    reasons.push({
      code: "homework_gap",
      label: "Homework completion gap",
      severity: inputs.homeworkCompletionRate < 50 ? "high" : "medium",
      detail: `Homework completion rate is ${inputs.homeworkCompletionRate}%.`,
    });
  }
  if (inputs.averageMarksPercent < 50) {
    reasons.push({
      code: "academic_underperformance",
      label: "Academic underperformance",
      severity: inputs.averageMarksPercent < 35 ? "critical" : "high",
      detail: `Average marks are ${inputs.averageMarksPercent}% of maximum.`,
    });
  }
  if (inputs.communicationGaps > 0) {
    reasons.push({
      code: "communication_gap",
      label: "Parent communication gap",
      severity: inputs.communicationGaps >= 3 ? "high" : "medium",
      detail: `${inputs.communicationGaps} pending or failed parent communications.`,
    });
  }
  if (inputs.behaviorIncidents > 0) {
    reasons.push({
      code: "behavior",
      label: "Behavior incidents",
      severity: inputs.behaviorIncidents >= 2 ? "high" : "medium",
      detail: `${inputs.behaviorIncidents} behavior record(s) on file.`,
    });
  }
  if (inputs.timetableMissedSessions > 2) {
    reasons.push({
      code: "timetable_pattern",
      label: "Timetable disruption pattern",
      severity: "medium",
      detail: `${inputs.timetableMissedSessions} missed or irregular sessions detected.`,
    });
  }
  if (reasons.length === 0) {
    reasons.push({
      code: "stable",
      label: "Stable profile",
      severity: "low",
      detail: "No significant risk signals detected in current inputs.",
    });
  }

  const riskLevel = riskLevelFromScore(riskScore);
  const interventions: RiskIntervention[] = [];

  if (reasons.some((r) => r.code === "low_attendance")) {
    interventions.push({
      action: "Schedule parent call within 48 hours to discuss attendance pattern",
      owner: "teacher",
      priority: riskLevel === "critical" ? "high" : "medium",
    });
  }
  if (reasons.some((r) => r.code === "homework_gap")) {
    interventions.push({
      action: "Assign targeted revision worksheet and track submission",
      owner: "teacher",
      priority: "medium",
    });
  }
  if (reasons.some((r) => r.code === "academic_underperformance")) {
    interventions.push({
      action: "Arrange subject teacher intervention session",
      owner: "principal",
      priority: "high",
    });
  }
  if (reasons.some((r) => r.code === "communication_gap")) {
    interventions.push({
      action: "Send structured parent update via preferred channel",
      owner: "teacher",
      priority: "medium",
    });
  }

  const teacherActions = interventions
    .filter((i) => i.owner === "teacher")
    .map((i) => i.action);

  const parentNotifications = [
    ...(reasons.some((r) => r.code === "low_attendance")
      ? ["Recommend attendance improvement notice to parent"]
      : []),
    ...(reasons.some((r) => r.code === "homework_gap")
      ? ["Recommend homework support message to parent"]
      : []),
    ...(riskLevel === "critical" || riskLevel === "high"
      ? ["Recommend principal escalation notice to parent"]
      : []),
  ];

  return {
    riskScore,
    riskLevel,
    reasons,
    interventions,
    teacherActions,
    parentNotifications,
  };
}
