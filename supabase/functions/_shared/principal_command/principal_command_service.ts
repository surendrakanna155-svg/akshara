import type { TenantQueryClient } from "../tenant_db.ts";
import { buildPrincipalIntelligenceCenter } from "../intelligence/principal_intelligence_service.ts";
import { executePrincipalQuery } from "../intelligence/principal_query_service.ts";
import { listRiskSnapshots } from "../intelligence/student_risk_repository.ts";

export interface PrincipalCommandCenter {
  topPriorities: Array<{ priority: string; category: string; count: number }>;
  executiveSummary: string;
  actionRecommendations: string[];
  monthlyImprovement: string[];
  riskOverview: {
    critical: number;
    high: number;
    medium: number;
    total: number;
  };
  widgets: {
    attendanceConcern: number;
    feeOverdue: number;
    overloadedTeachers: number;
    decliningClasses: number;
  };
  priorityEngineScore: number;
}

export async function buildPrincipalCommandCenter(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<PrincipalCommandCenter> {
  const center = await buildPrincipalIntelligenceCenter(client, organizationId, schoolId, "monthly");
  const snapshots = await listRiskSnapshots(client, {});

  const critical = snapshots.filter((s) => s.risk_level === "critical").length;
  const high = snapshots.filter((s) => s.risk_level === "high").length;
  const medium = snapshots.filter((s) => s.risk_level === "medium").length;

  const attendanceQuery = await executePrincipalQuery(client, "students below 75% attendance");
  const feeQuery = await executePrincipalQuery(client, "fee defaulters");

  const topPriorities = [
    { priority: "Critical-risk students", category: "risk", count: critical },
    { priority: "Low attendance students", category: "attendance", count: attendanceQuery.count },
    { priority: "Fee overdue accounts", category: "finance", count: feeQuery.count },
    { priority: "Overloaded teachers", category: "staff", count: center.executiveDashboard.overloadedTeachers },
  ].filter((p) => p.count > 0);

  const priorityEngineScore = Math.max(
    0,
    Math.min(
      100,
      Math.round(
        center.executiveDashboard.schoolHealthScore * 0.4 +
          (100 - Math.min(100, critical * 10 + high * 5)) * 0.35 +
          (attendanceQuery.count === 0 ? 90 : Math.max(40, 100 - attendanceQuery.count * 3)) * 0.25,
      ),
    ),
  );

  return {
    topPriorities: topPriorities.length
      ? topPriorities
      : [{ priority: "Review weekly school health dashboard", category: "operations", count: 1 }],
    executiveSummary: center.exportReady.monthlySummary,
    actionRecommendations: center.interventionRecommendations,
    monthlyImprovement: center.schoolHealthInsights.slice(0, 4),
    riskOverview: { critical, high, medium, total: snapshots.length },
    widgets: {
      attendanceConcern: attendanceQuery.count,
      feeOverdue: feeQuery.count,
      overloadedTeachers: center.executiveDashboard.overloadedTeachers,
      decliningClasses: center.executiveDashboard.classPerformanceTrend === "mixed" ? 1 : 0,
    },
    priorityEngineScore,
  };
}
