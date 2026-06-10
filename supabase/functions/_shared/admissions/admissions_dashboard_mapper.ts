import type { AdmissionsDashboardSnapshot } from "./admissions_dashboard_repository.ts";

const PIPELINE_STAGES = [
  "new_enquiry",
  "contacted",
  "school_visit",
  "demo_class",
  "application",
  "confirmed",
  "joined",
] as const;

function formatSourceLabel(source: string): string {
  return source.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

export function dashboardToApi(snapshot: AdmissionsDashboardSnapshot): Record<string, unknown> {
  const funnelTotal = Object.values(snapshot.stageCounts).reduce((sum, n) => sum + n, 0);
  const sourceTotal = Object.values(snapshot.sourceCounts).reduce((sum, n) => sum + n, 0);

  const pipeline = PIPELINE_STAGES.map((stage) => {
    const leads = snapshot.pipelineLeads
      .filter((lead) => lead.stage === stage)
      .slice(0, 5)
      .map((lead) => ({
        id: lead.id,
        studentName: lead.studentName,
        classLabel: lead.classLabel,
        score: lead.score,
        source: lead.source,
        daysInStage: lead.daysInStage,
      }));
    return { stage, count: snapshot.stageCounts[stage] ?? 0, leads };
  });

  return {
    kpis: [
      {
        id: "total_leads",
        value: String(snapshot.totalLeads),
        label: "Total Leads (MTD)",
        accentName: "primary",
      },
      {
        id: "hot_leads",
        value: String(snapshot.hotLeads),
        label: "Hot Leads",
        accentName: "error",
      },
      {
        id: "visits",
        value: String(snapshot.visitsScheduled),
        label: "Visits Scheduled",
        accentName: "warning",
      },
      {
        id: "confirmed",
        value: String(snapshot.confirmed),
        label: "Confirmed",
        accentName: "success",
      },
      {
        id: "joined",
        value: String(snapshot.joined),
        label: "Joined",
        accentName: "success",
      },
      {
        id: "conversion",
        value: `${snapshot.conversionRate}%`,
        label: "Conversion Rate",
        accentName: "neutral",
      },
    ],
    pipeline,
    funnelSegments: PIPELINE_STAGES.map((stage) => ({
      label: formatSourceLabel(stage),
      value: snapshot.stageCounts[stage] ?? 0,
      percent: funnelTotal > 0
        ? Math.round(((snapshot.stageCounts[stage] ?? 0) / funnelTotal) * 100)
        : 0,
    })),
    sourceSegments: Object.entries(snapshot.sourceCounts).map(([source, value]) => ({
      label: formatSourceLabel(source),
      value,
      percent: sourceTotal > 0 ? Math.round((value / sourceTotal) * 100) : 0,
    })),
    followUps: snapshot.followUps,
    leaderboard: snapshot.counselorStats,
    aiInsight: snapshot.totalLeads > 0
      ? `${snapshot.hotLeads} hot leads need follow-up this week.`
      : "No leads yet — start capturing enquiries.",
    aiActionLabel: "Review hot leads",
  };
}
