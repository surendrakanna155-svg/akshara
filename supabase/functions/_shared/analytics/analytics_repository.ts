import type { TenantQueryClient } from "../tenant_db.ts";
import { loadRawSchoolMetrics } from "./analytics_metrics_service.ts";
import {
  buildAnalyticsRecommendations,
  buildPrincipalSummary,
  buildWeeklyBriefing,
  detectAnomalies,
} from "./analytics_recommendations.ts";
import {
  buildDashboardMetrics,
  buildRiskSummaries,
  buildSchoolHealthSummary,
  buildTrendSeries,
} from "./analytics_scoring.ts";

export const ANALYTICS_SNAPSHOT_PROBE_SCHOOL_A = "d0600000-0000-4000-8000-000000000001";
export const ANALYTICS_SNAPSHOT_PROBE_SCHOOL_B = "d0600000-0000-4000-8000-000000000002";
export const ANALYTICS_SNAPSHOT_PROBE_SQL = `
  SELECT count(*)::text AS count FROM analytics_score_snapshots WHERE id = $1::uuid
`;

export async function computeAnalyticsBundle(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
) {
  const raw = await loadRawSchoolMetrics(db, organizationId, schoolId);
  const dashboard = buildDashboardMetrics(raw);
  const health = buildSchoolHealthSummary(dashboard);
  const risks = buildRiskSummaries(dashboard);
  const trends = buildTrendSeries(dashboard, health.schoolHealthScore);
  const recommendations = buildAnalyticsRecommendations({ dashboard, health, risks });
  const anomalies = detectAnomalies(dashboard);
  const principalSummary = buildPrincipalSummary({
    dashboard,
    health,
    risks,
    recommendations,
  });
  const weeklyBriefing = buildWeeklyBriefing({ dashboard, health, risks });

  return {
    dashboard,
    health,
    risks,
    trends,
    recommendations,
    anomalies,
    principalSummary,
    weeklyBriefing,
  };
}
