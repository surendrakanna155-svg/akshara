import type { AdmissionsReportsSnapshot } from "./admissions_reports_repository.ts";

const PIPELINE_STAGES = [
  "new_enquiry",
  "contacted",
  "school_visit",
  "demo_class",
  "application",
  "confirmed",
  "joined",
] as const;

function formatLabel(value: string): string {
  return value.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

/**
 * Builds the admissions reports client contract from the real snapshot.
 * `funnelSegments` mirrors the dashboard funnel shape (label/value/percent);
 * the remaining lists carry the snake_case enum strings the Flutter codec
 * parses (source / status).
 */
export function reportsToApi(
  snapshot: AdmissionsReportsSnapshot,
): Record<string, unknown> {
  const stageCounts = snapshot.dashboard.stageCounts;
  const funnelTotal = Object.values(stageCounts).reduce((s, n) => s + n, 0);

  return {
    funnelSegments: PIPELINE_STAGES.map((stage) => ({
      label: formatLabel(stage),
      value: stageCounts[stage] ?? 0,
      percent: funnelTotal > 0
        ? Math.round(((stageCounts[stage] ?? 0) / funnelTotal) * 100)
        : 0,
    })),
    sourceAnalysis: snapshot.sourceAnalysis.map((row) => ({
      source: row.source,
      leads: row.leads,
      converted: row.converted,
      conversionRate: row.conversionRate,
    })),
    counselorPerformance: snapshot.counselorPerformance.map((row) => ({
      counselor: row.counselor,
      leads: row.leads,
      applications: row.applications,
      approved: row.approved,
      conversionRate: row.conversionRate,
    })),
    applicationStatus: snapshot.applicationStatus.map((row) => ({
      status: row.status,
      count: row.count,
      percent: row.percent,
    })),
    lostReasons: snapshot.lostReasons.map((row) => ({
      reason: row.reason,
      count: row.count,
    })),
  };
}
