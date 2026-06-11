import type { TenantQueryClient } from "../tenant_db.ts";
import { computeAnalyticsBundle } from "../analytics/analytics_repository.ts";
import { listClassRiskSummaries, listRiskSnapshots } from "./student_risk_repository.ts";

export type PrincipalPeriod = "monthly" | "quarterly";

export interface PrincipalIntelligenceCenter {
  executiveDashboard: {
    schoolHealthScore: number;
    studentsAtRisk: number;
    criticalRiskCount: number;
    overloadedTeachers: number;
    attendanceTrend: string;
    feeCollectionTrend: string;
    communicationEffectiveness: string;
    classPerformanceTrend: string;
  };
  schoolHealthInsights: string[];
  interventionRecommendations: string[];
  classRiskSummaries: Awaited<ReturnType<typeof listClassRiskSummaries>>;
  exportReady: {
    monthlySummary: string;
    quarterlySummary: string;
  };
}

export async function buildPrincipalIntelligenceCenter(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  period: PrincipalPeriod,
): Promise<PrincipalIntelligenceCenter> {
  const bundle = await computeAnalyticsBundle(client, organizationId, schoolId);
  const snapshots = await listRiskSnapshots(client, {});
  const classSummaries = await listClassRiskSummaries(client);

  const critical = snapshots.filter((s) => s.risk_level === "critical").length;
  const atRisk = snapshots.filter((s) =>
    s.risk_level !== "low"
  ).length;

  const insights = [
    `School health score is ${bundle.health.schoolHealthScore}/100.`,
    `${atRisk} students currently flagged above low risk (${critical} critical).`,
    `Teacher workload index: ${bundle.dashboard.teacherWorkloadIndex} (higher = more overload).`,
    `Communication engagement: ${bundle.dashboard.communicationEngagementScore}%.`,
    `Fee collection risk score: ${bundle.dashboard.feeCollectionRisk}.`,
  ];

  const interventions = bundle.recommendations
    .slice(0, 6)
    .map((r) => r.title);

  const monthlySummary =
    `Monthly Principal Intelligence Summary\n` +
    `Health: ${bundle.health.schoolHealthScore} | At-risk students: ${atRisk} | ` +
    `Critical: ${critical} | Attendance risk: ${bundle.dashboard.attendanceRiskScore}`;

  const quarterlySummary =
    `Quarterly Principal Intelligence Summary\n` +
    `Academic health: ${bundle.health.academicHealth} | Finance health: ${bundle.health.financeHealth} | ` +
    `Operations: ${bundle.health.operationsHealth} | Engagement: ${bundle.health.engagementHealth}`;

  return {
    executiveDashboard: {
      schoolHealthScore: bundle.health.schoolHealthScore,
      studentsAtRisk: atRisk,
      criticalRiskCount: critical,
      overloadedTeachers: Math.round(bundle.dashboard.teacherWorkloadIndex / 10),
      attendanceTrend: bundle.dashboard.attendanceRiskScore > 50 ? "declining" : "stable",
      feeCollectionTrend: bundle.dashboard.feeCollectionRisk > 50 ? "needs attention" : "on track",
      communicationEffectiveness:
        bundle.dashboard.communicationEngagementScore >= 70 ? "effective" : "improving",
      classPerformanceTrend:
        bundle.dashboard.academicPerformanceRisk > 50 ? "mixed" : "positive",
    },
    schoolHealthInsights: insights,
    interventionRecommendations: interventions.length > 0
      ? interventions
      : ["Review class risk dashboards weekly", "Prioritize critical-risk student interventions"],
    classRiskSummaries: classSummaries,
    exportReady: {
      monthlySummary: period === "monthly" ? monthlySummary : monthlySummary,
      quarterlySummary,
    },
  };
}
