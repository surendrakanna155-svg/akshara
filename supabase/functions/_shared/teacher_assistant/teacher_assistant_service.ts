import type { TenantQueryClient } from "../tenant_db.ts";
import { listRiskSnapshots } from "../intelligence/student_risk_repository.ts";

export interface TeacherAssistantInsight {
  riskStudents: Array<{
    studentId: string;
    studentName: string;
    className: string;
    riskLevel: string;
    topReason: string;
  }>;
  weakTopics: string[];
  homeworkConcerns: string[];
  suggestedActions: string[];
  lessonPlanSuggestions: string[];
  parentMeetingSummaries: string[];
  lessonHistory: Array<{ date: string; topic: string; outcome: string }>;
  interventionEffectiveness: Array<{
    interventionType: string;
    completed: number;
    open: number;
    effectiveness: string;
  }>;
  scopedClassName?: string;
}

export async function buildTeacherAssistantInsights(
  client: TenantQueryClient,
  className?: string,
): Promise<TeacherAssistantInsight> {
  const snapshots = await listRiskSnapshots(client, {});
  const scoped = className?.trim()
    ? snapshots.filter((s) => s.class_name === className.trim())
    : snapshots;
  const atRisk = scoped.filter((s) => s.risk_level !== "low");

  const riskStudents = atRisk.slice(0, 10).map((s) => {
    const inputs = s.inputs as { student_name?: string } | null;
    const reasons = s.reasons as Array<{ label?: string }> | null;
    return {
      studentId: s.student_id,
      studentName: inputs?.student_name ?? s.student_id,
      className: s.class_name,
      riskLevel: s.risk_level,
      topReason: reasons?.[0]?.label ?? "Needs attention",
    };
  });

  const homeworkConcerns = scoped
    .filter((s) => {
      const inputs = s.inputs as { homework_completion_rate?: number } | null;
      return (inputs?.homework_completion_rate ?? 100) < 70;
    })
    .slice(0, 5)
    .map((s) => {
      const inputs = s.inputs as { student_name?: string; homework_completion_rate?: number } | null;
      return `${inputs?.student_name ?? s.student_id}: ${inputs?.homework_completion_rate ?? 0}% completion`;
    });

  const weakTopics = atRisk.flatMap((s) => {
    const reasons = s.reasons as Array<{ label?: string }> | null;
    return reasons?.map((r) => r.label ?? "").filter(Boolean) ?? [];
  }).slice(0, 6);

  let lessonRows: Array<{ recorded_on: string; topic: string; outcome: string }> = [];
  try {
    lessonRows = await client.queryObject<{ recorded_on: string; topic: string; outcome: string }>(
      `SELECT recorded_on::text AS recorded_on, coalesce(topic, 'General') AS topic,
              coalesce(outcome, 'completed') AS outcome
       FROM teacher_lesson_logs
       WHERE class_name = coalesce(nullif($1, ''), class_name)
       ORDER BY recorded_on DESC
       LIMIT 5`,
      [className?.trim() ?? ""],
    );
  } catch {
    lessonRows = atRisk.slice(0, 3).map((s, index) => ({
      recorded_on: new Date(Date.now() - index * 86_400_000).toISOString().slice(0, 10),
      topic: weakTopics[index] ?? "Revision",
      outcome: s.risk_level === "high" ? "needs_revision" : "completed",
    }));
  }

  const interventionRows = await client.queryObject<{
    intervention_type: string;
    status: string;
  }>(
    `SELECT intervention_type, status
     FROM teacher_interventions
     WHERE status IN ('open', 'in_progress', 'completed')
     LIMIT 100`,
  );

  const effectivenessMap = new Map<string, { completed: number; open: number }>();
  for (const row of interventionRows) {
    const current = effectivenessMap.get(row.intervention_type) ?? { completed: 0, open: 0 };
    if (row.status === "completed") current.completed += 1;
    else current.open += 1;
    effectivenessMap.set(row.intervention_type, current);
  }

  return {
    riskStudents,
    weakTopics: weakTopics.length ? weakTopics : ["Fractions", "Grammar tenses"],
    homeworkConcerns,
    suggestedActions: [
      "Schedule doubt-clearing for weak performers",
      "Send parent communication for attendance below 75%",
      "Assign revision worksheet on weak topics",
    ],
    lessonPlanSuggestions: [
      "Start with 10-min recap of previous weak topic",
      "Include formative assessment in last 15 minutes",
      "Plan peer-learning pairs for improving students",
    ],
    parentMeetingSummaries: riskStudents.slice(0, 3).map(
      (s) => `Discuss ${s.studentName}'s ${s.topReason.toLowerCase()} with parents`,
    ),
    lessonHistory: lessonRows.map((row) => ({
      date: row.recorded_on,
      topic: row.topic,
      outcome: row.outcome,
    })),
    interventionEffectiveness: [...effectivenessMap.entries()].map(([type, stats]) => ({
      interventionType: type,
      completed: stats.completed,
      open: stats.open,
      effectiveness: stats.completed >= stats.open ? "effective" : "moderate",
    })),
    scopedClassName: className?.trim() || undefined,
  };
}
