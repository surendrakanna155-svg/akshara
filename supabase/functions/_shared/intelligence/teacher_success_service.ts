import type { TenantQueryClient } from "../tenant_db.ts";
import { listRiskSnapshots } from "./student_risk_repository.ts";
import type { StudentRiskSnapshotRow } from "./intelligence_types.ts";

export interface TeacherSuccessCenter {
  studentsNeedingAttention: Array<{
    studentId: string;
    studentName: string;
    className: string;
    riskLevel: string;
    riskScore: number;
    topReason: string;
  }>;
  riskStudents: number;
  homeworkGaps: number;
  attendanceConcerns: number;
  pendingParentCommunication: number;
  insights: {
    weakStudents: string[];
    improvingStudents: string[];
    highPerformers: string[];
  };
  suggestedActions: Array<{
    action: string;
    target: string;
    type: "communicate_parent" | "assign_homework" | "schedule_intervention";
  }>;
  dailyActionPlan: Array<{
    priority: "high" | "medium" | "low";
    action: string;
    category: string;
  }>;
}

function studentNameFromInputs(row: StudentRiskSnapshotRow): string {
  const inputs = row.inputs as { student_name?: string } | null;
  return inputs?.student_name ?? row.student_id;
}

function topReason(row: StudentRiskSnapshotRow): string {
  const reasons = row.reasons as Array<{ label?: string }> | null;
  return reasons?.[0]?.label ?? "Risk signal detected";
}

export async function buildTeacherSuccessCenter(
  client: TenantQueryClient,
): Promise<TeacherSuccessCenter> {
  const snapshots = await listRiskSnapshots(client, {});

  const atRisk = snapshots.filter((s) =>
    s.risk_level === "critical" || s.risk_level === "high" || s.risk_level === "medium"
  );

  const homeworkGaps = snapshots.filter((s) => {
    const inputs = s.inputs as { homework_completion_rate?: number } | null;
    return (inputs?.homework_completion_rate ?? 100) < 70;
  }).length;

  const attendanceConcerns = snapshots.filter((s) => {
    const inputs = s.inputs as { attendance_percent?: number } | null;
    return (inputs?.attendance_percent ?? 100) < 75;
  }).length;

  const pendingComm = snapshots.reduce((sum, s) => {
    const notifs = s.parent_notifications as string[] | null;
    return sum + (notifs?.length ?? 0);
  }, 0);

  const weakStudents = snapshots
    .filter((s) => s.risk_level === "high" || s.risk_level === "critical")
    .slice(0, 5)
    .map(studentNameFromInputs);

  const highPerformers = snapshots
    .filter((s) => s.risk_level === "low")
    .slice(0, 5)
    .map(studentNameFromInputs);

  const improvingStudents = snapshots
    .filter((s) => s.risk_level === "medium")
    .slice(0, 3)
    .map(studentNameFromInputs);

  const suggestedActions = atRisk.slice(0, 8).flatMap((row) => {
    const name = studentNameFromInputs(row);
    const actions: TeacherSuccessCenter["suggestedActions"] = [];
    if ((row.parent_notifications as string[] | null)?.length) {
      actions.push({
        action: `Send parent communication for ${name}`,
        target: row.student_id,
        type: "communicate_parent",
      });
    }
    const teacherActs = row.teacher_actions as string[] | null;
    if (teacherActs?.some((a) => a.toLowerCase().includes("worksheet"))) {
      actions.push({
        action: `Assign revision worksheet to ${name}`,
        target: row.student_id,
        type: "assign_homework",
      });
    }
    if (row.risk_level === "critical" || row.risk_level === "high") {
      actions.push({
        action: `Schedule intervention for ${name}`,
        target: row.student_id,
        type: "schedule_intervention",
      });
    }
    return actions;
  });

  const dailyActionPlan: TeacherSuccessCenter["dailyActionPlan"] = [];

  if (attendanceConcerns > 0) {
    dailyActionPlan.push({
      priority: "high",
      action: `Review attendance for ${attendanceConcerns} students below 75%`,
      category: "attendance",
    });
  }
  if (homeworkGaps > 0) {
    dailyActionPlan.push({
      priority: "high",
      action: `Follow up on homework for ${homeworkGaps} students below 70% completion`,
      category: "homework",
    });
  }
  if (pendingComm > 0) {
    dailyActionPlan.push({
      priority: "medium",
      action: `Send ${Math.min(pendingComm, 5)} parent communication drafts today`,
      category: "communication",
    });
  }
  const criticalCount = snapshots.filter((s) => s.risk_level === "critical").length;
  if (criticalCount > 0) {
    dailyActionPlan.push({
      priority: "high",
      action: `Schedule intervention for ${criticalCount} critical-risk students`,
      category: "intervention",
    });
  }
  if (weakStudents.length > 0) {
    dailyActionPlan.push({
      priority: "medium",
      action: `Assign revision worksheet to weak performers: ${weakStudents.slice(0, 3).join(", ")}`,
      category: "academic",
    });
  }
  if (improvingStudents.length > 0) {
    dailyActionPlan.push({
      priority: "low",
      action: `Recognize improving students: ${improvingStudents.join(", ")}`,
      category: "appreciation",
    });
  }
  if (dailyActionPlan.length === 0) {
    dailyActionPlan.push({
      priority: "low",
      action: "Review class risk dashboard and plan tomorrow's priorities",
      category: "planning",
    });
  }

  return {
    studentsNeedingAttention: atRisk.slice(0, 15).map((row) => ({
      studentId: row.student_id,
      studentName: studentNameFromInputs(row),
      className: row.class_name,
      riskLevel: row.risk_level,
      riskScore: row.risk_score,
      topReason: topReason(row),
    })),
    riskStudents: atRisk.length,
    homeworkGaps,
    attendanceConcerns,
    pendingParentCommunication: pendingComm,
    insights: { weakStudents, improvingStudents, highPerformers },
    suggestedActions: suggestedActions.slice(0, 12),
    dailyActionPlan: dailyActionPlan.slice(0, 8),
  };
}
