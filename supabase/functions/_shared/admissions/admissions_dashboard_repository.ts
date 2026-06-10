import type { TenantQueryClient } from "../tenant_db.ts";

const PIPELINE_STAGES = [
  "new_enquiry",
  "contacted",
  "school_visit",
  "demo_class",
  "application",
  "confirmed",
  "joined",
] as const;

export interface AdmissionsDashboardSnapshot {
  totalLeads: number;
  hotLeads: number;
  visitsScheduled: number;
  confirmed: number;
  joined: number;
  conversionRate: number;
  stageCounts: Record<string, number>;
  sourceCounts: Record<string, number>;
  counselorStats: Array<{
    counselor: string;
    leadsHandled: number;
    conversions: number;
    conversionRate: number;
  }>;
  followUps: Array<{
    id: string;
    dueLabel: string;
    leadName: string;
    task: string;
    counselor: string;
    priority: string;
    status: string;
  }>;
  pipelineLeads: Array<{
    stage: string;
    id: string;
    studentName: string;
    classLabel: string;
    score: string;
    source: string;
    daysInStage: number;
  }>;
}

export async function getDashboard(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<AdmissionsDashboardSnapshot> {
  const kpiRows = await db.queryObject<{
    total_leads: string;
    hot_leads: string;
    visits_scheduled: string;
    confirmed: string;
    joined: string;
  }>(
    `SELECT
       (SELECT count(*)::text FROM admissions_leads
        WHERE organization_id = $1 AND school_id = $2) AS total_leads,
       (SELECT count(*)::text FROM admissions_leads
        WHERE organization_id = $1 AND school_id = $2 AND score = 'hot') AS hot_leads,
       (SELECT count(*)::text FROM admissions_leads
        WHERE organization_id = $1 AND school_id = $2 AND stage = 'school_visit') AS visits_scheduled,
       (SELECT count(*)::text FROM admissions_leads
        WHERE organization_id = $1 AND school_id = $2 AND stage = 'confirmed') AS confirmed,
       (SELECT count(*)::text FROM admissions_leads
        WHERE organization_id = $1 AND school_id = $2 AND stage = 'joined') AS joined`,
    [organizationId, schoolId],
  );
  const kpi = kpiRows[0] ?? {
    total_leads: "0",
    hot_leads: "0",
    visits_scheduled: "0",
    confirmed: "0",
    joined: "0",
  };

  const totalLeads = Number(kpi.total_leads);
  const joined = Number(kpi.joined);
  const conversionRate = totalLeads > 0
    ? Math.round((joined / totalLeads) * 10000) / 100
    : 0;

  const stageRows = await db.queryObject<{ stage: string; count: string }>(
    `SELECT stage, count(*)::text AS count FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2
     GROUP BY stage`,
    [organizationId, schoolId],
  );
  const stageCounts: Record<string, number> = {};
  for (const stage of PIPELINE_STAGES) stageCounts[stage] = 0;
  for (const row of stageRows) stageCounts[row.stage] = Number(row.count);

  const sourceRows = await db.queryObject<{ source: string; count: string }>(
    `SELECT source, count(*)::text AS count FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2
     GROUP BY source`,
    [organizationId, schoolId],
  );
  const sourceCounts: Record<string, number> = {};
  for (const row of sourceRows) sourceCounts[row.source] = Number(row.count);

  const counselorRows = await db.queryObject<{
    counselor: string;
    leads_handled: string;
    conversions: string;
  }>(
    `SELECT counselor,
            count(*)::text AS leads_handled,
            count(*) FILTER (WHERE stage = 'joined')::text AS conversions
     FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2 AND counselor <> ''
     GROUP BY counselor
     ORDER BY count(*) DESC
     LIMIT 10`,
    [organizationId, schoolId],
  );

  const followUpRows = await db.queryObject<{
    id: string;
    student_name: string;
    next_follow_up_label: string;
    counselor: string;
    score: string;
  }>(
    `SELECT id, student_name, next_follow_up_label, counselor, score
     FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2
       AND next_follow_up_label <> 'Not scheduled'
     ORDER BY updated_at DESC
     LIMIT 10`,
    [organizationId, schoolId],
  );

  const pipelineLeadRows = await db.queryObject<{
    id: string;
    stage: string;
    student_name: string;
    class_label: string;
    score: string;
    source: string;
    days_in_stage: string;
  }>(
    `SELECT id, stage, student_name, class_label, score, source,
            GREATEST(0, EXTRACT(day FROM timezone('utc', now()) - updated_at))::text AS days_in_stage
     FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY updated_at DESC
     LIMIT 50`,
    [organizationId, schoolId],
  );

  return {
    totalLeads,
    hotLeads: Number(kpi.hot_leads),
    visitsScheduled: Number(kpi.visits_scheduled),
    confirmed: Number(kpi.confirmed),
    joined,
    conversionRate,
    stageCounts,
    sourceCounts,
    counselorStats: counselorRows.map((row) => {
      const leadsHandled = Number(row.leads_handled);
      const conversions = Number(row.conversions);
      return {
        counselor: row.counselor,
        leadsHandled,
        conversions,
        conversionRate: leadsHandled > 0
          ? Math.round((conversions / leadsHandled) * 10000) / 100
          : 0,
      };
    }),
    followUps: followUpRows.map((row) => ({
      id: row.id,
      dueLabel: row.next_follow_up_label,
      leadName: row.student_name,
      task: "Follow up",
      counselor: row.counselor,
      priority: row.score === "hot" ? "high" : "medium",
      status: "pending",
    })),
    pipelineLeads: pipelineLeadRows.map((row) => ({
      stage: row.stage,
      id: row.id,
      studentName: row.student_name,
      classLabel: row.class_label,
      score: row.score,
      source: row.source,
      daysInStage: Number(row.days_in_stage),
    })),
  };
}
