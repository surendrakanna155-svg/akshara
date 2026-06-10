import type {
  AnalyticsDashboardMetrics,
  AnalyticsRecommendation,
  PrincipalSummary,
  RiskMetric,
  SchoolHealthSummary,
  WeeklyBriefing,
} from "./analytics_types.ts";

export function buildAnalyticsRecommendations(input: {
  dashboard: AnalyticsDashboardMetrics;
  health: SchoolHealthSummary;
  risks: RiskMetric[];
}): AnalyticsRecommendation[] {
  const items: AnalyticsRecommendation[] = [];

  for (const risk of input.risks.filter((r) => r.level === "high").slice(0, 3)) {
    items.push({
      kind: "risk_mitigation",
      title: `Address ${risk.label}`,
      detail: `${risk.detail} Current score: ${risk.score}/100 risk. Review affected cohorts manually — no automated action taken.`,
      readOnly: true,
    });
  }

  if (input.dashboard.timetableHealthScore < 70) {
    items.push({
      kind: "operations",
      title: "Review timetable conflicts",
      detail: "Timetable health is below target. Use Smart Timetable conflict review before next publish.",
      readOnly: true,
    });
  }

  if (input.dashboard.feeCollectionRisk >= 50) {
    items.push({
      kind: "finance",
      title: "Prioritize fee follow-up",
      detail: "Open invoice pressure is elevated. Finance team should review defaulter list and collection cadence.",
      readOnly: true,
    });
  }

  if (items.length === 0) {
    items.push({
      kind: "general",
      title: "School metrics stable",
      detail: `School health score ${input.health.schoolHealthScore}/100 with no high-severity risk flags.`,
      readOnly: true,
    });
  }

  return items;
}

export function buildPrincipalSummary(input: {
  dashboard: AnalyticsDashboardMetrics;
  health: SchoolHealthSummary;
  risks: RiskMetric[];
  recommendations: AnalyticsRecommendation[];
}): PrincipalSummary {
  const highRisks = input.risks.filter((r) => r.level === "high");
  return {
    headline: `School health ${input.health.schoolHealthScore}/100 — ${
      highRisks.length > 0 ? `${highRisks.length} high-risk areas` : "stable operations"
    }`,
    highlights: [
      `Admissions conversion at ${input.dashboard.admissionConversionRate}%`,
      `Timetable health ${input.dashboard.timetableHealthScore}/100`,
      `Communication engagement ${input.dashboard.communicationEngagementScore}/100`,
    ],
    risks: highRisks.map((r) => `${r.label}: ${r.score}/100 (${r.level})`),
    recommendations: input.recommendations.slice(0, 5),
    computedAt: input.dashboard.computedAt,
  };
}

export function buildWeeklyBriefing(input: {
  dashboard: AnalyticsDashboardMetrics;
  health: SchoolHealthSummary;
  risks: RiskMetric[];
}): WeeklyBriefing {
  const weekLabel = new Date().toISOString().slice(0, 10);
  return {
    weekLabel,
    sections: [
      {
        title: "Executive summary",
        bullets: [
          `Overall school health: ${input.health.schoolHealthScore}/100`,
          `Student composite risk: ${input.dashboard.studentRiskScore}/100`,
        ],
      },
      {
        title: "Academic & attendance",
        bullets: [
          `Attendance risk ${input.dashboard.attendanceRiskScore}/100`,
          `Academic performance risk ${input.dashboard.academicPerformanceRisk}/100`,
        ],
      },
      {
        title: "Finance & admissions",
        bullets: [
          `Fee collection risk ${input.dashboard.feeCollectionRisk}/100`,
          `Admissions conversion ${input.dashboard.admissionConversionRate}%`,
        ],
      },
      {
        title: "Operations & engagement",
        bullets: [
          `Timetable health ${input.dashboard.timetableHealthScore}/100`,
          `Communication engagement ${input.dashboard.communicationEngagementScore}/100`,
          `${input.risks.filter((r) => r.level === "high").length} high-priority risk flags`,
        ],
      },
    ],
    readOnly: true,
    computedAt: input.dashboard.computedAt,
  };
}

export function detectAnomalies(dashboard: AnalyticsDashboardMetrics): string[] {
  const anomalies: string[] = [];
  if (dashboard.attendanceRiskScore >= 70) {
    anomalies.push("Attendance absent rate spike vs typical baseline");
  }
  if (dashboard.feeCollectionRisk >= 65) {
    anomalies.push("Open invoice count disproportionate to enrollment");
  }
  if (dashboard.teacherWorkloadIndex >= 60) {
    anomalies.push("Multiple teachers exceed workload threshold");
  }
  if (dashboard.communicationEngagementScore <= 40) {
    anomalies.push("Notification delivery failure rate elevated");
  }
  return anomalies;
}
