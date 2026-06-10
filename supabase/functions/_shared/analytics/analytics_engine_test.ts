import { assertEquals } from "jsr:@std/assert@1";
import {
  buildDashboardMetrics,
  buildRiskSummaries,
  buildSchoolHealthSummary,
  buildTrendSeries,
  scoreStudentRisk,
} from "./analytics_scoring.ts";
import { buildAnalyticsRecommendations, detectAnomalies } from "./analytics_recommendations.ts";
import type { RawSchoolMetrics } from "./analytics_types.ts";

const sampleRaw: RawSchoolMetrics = {
  studentCount: 500,
  enrollmentCount: 480,
  absentRate: 0.12,
  lowMarksRate: 0.18,
  openInvoiceCount: 40,
  completedCollections: 120,
  leadCount: 80,
  convertedApplications: 32,
  timetableConflictCount: 2,
  timetableGapCount: 1,
  overloadedTeachers: 3,
  notificationDelivered: 900,
  notificationFailed: 50,
  teacherAssignmentCount: 24,
};

Deno.test("student risk score combines attendance academic and fee signals", () => {
  const score = scoreStudentRisk(40, 50, 60);
  assertEquals(score >= 40 && score <= 60, true);
});

Deno.test("dashboard metrics cover eight intelligence domains", () => {
  const dashboard = buildDashboardMetrics(sampleRaw);
  assertEquals(typeof dashboard.studentRiskScore, "number");
  assertEquals(typeof dashboard.timetableHealthScore, "number");
  assertEquals(typeof dashboard.communicationEngagementScore, "number");
});

Deno.test("school health summary explains composition weights", () => {
  const dashboard = buildDashboardMetrics(sampleRaw);
  const health = buildSchoolHealthSummary(dashboard);
  assertEquals(health.composition.length, 4);
  assertEquals(health.composition.reduce((s, c) => s + c.weight, 0), 1);
  assertEquals(health.schoolHealthScore >= 0 && health.schoolHealthScore <= 100, true);
});

Deno.test("recommendations are read-only", () => {
  const dashboard = buildDashboardMetrics(sampleRaw);
  const health = buildSchoolHealthSummary(dashboard);
  const risks = buildRiskSummaries(dashboard);
  const recommendations = buildAnalyticsRecommendations({ dashboard, health, risks });
  assertEquals(recommendations.every((r) => r.readOnly === true), true);
});

Deno.test("trend series includes school health trajectory", () => {
  const dashboard = buildDashboardMetrics(sampleRaw);
  const health = buildSchoolHealthSummary(dashboard);
  const trends = buildTrendSeries(dashboard, health.schoolHealthScore);
  assertEquals(trends.schoolHealth?.length, 5);
});

Deno.test("anomaly detection flags elevated attendance risk", () => {
  const dashboard = buildDashboardMetrics({ ...sampleRaw, absentRate: 0.8 });
  const anomalies = detectAnomalies(dashboard);
  assertEquals(anomalies.length > 0, true);
});

Deno.test("analytics router exposes health and briefing routes", async () => {
  const { matchAnalyticsRoute } = await import("./analytics_router.ts");
  assertEquals(matchAnalyticsRoute("GET", "/analytics/health")?.handler.name, "handleAnalyticsHealth");
  assertEquals(
    matchAnalyticsRoute("GET", "/analytics/weekly-briefing")?.handler.name,
    "handleWeeklyBriefing",
  );
});
