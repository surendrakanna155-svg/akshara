import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type AdmissionsDashboardSnapshot,
  getDashboard,
} from "./admissions_dashboard_repository.ts";

const APPLICATION_STATUSES = [
  "draft",
  "submitted",
  "documents_pending",
  "under_review",
  "approved",
  "rejected",
] as const;

export interface AdmissionsReportsSnapshot {
  dashboard: AdmissionsDashboardSnapshot;
  sourceAnalysis: Array<{
    source: string;
    leads: number;
    converted: number;
    conversionRate: number;
  }>;
  counselorPerformance: Array<{
    counselor: string;
    leads: number;
    applications: number;
    approved: number;
    conversionRate: number;
  }>;
  applicationStatus: Array<{ status: string; count: number; percent: number }>;
  // ADM-D1: why leads are lost — count by lost_reason (fixed picklist).
  lostReasons: Array<{ reason: string; count: number }>;
}

// Mirrors LEAD_LOST_REASONS in admissions_repository.ts; kept local so the
// rollup always reports all buckets (including zeros) in a stable order.
const LOST_REASONS = ["fees_high", "competitor", "distance", "other"] as const;

export async function getReports(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<AdmissionsReportsSnapshot> {
  // Reuse the real funnel snapshot for stage/source/leaderboard aggregates.
  const dashboard = await getDashboard(db, organizationId, schoolId);

  // Source × conversion, computed from real leads.
  const sourceRows = await db.queryObject<{
    source: string;
    leads: string;
    converted: string;
  }>(
    `SELECT source,
            count(*)::text AS leads,
            count(*) FILTER (WHERE stage = 'joined')::text AS converted
     FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2
     GROUP BY source
     ORDER BY count(*) DESC`,
    [organizationId, schoolId],
  );
  const sourceAnalysis = sourceRows.map((row) => {
    const leads = Number(row.leads);
    const converted = Number(row.converted);
    return {
      source: row.source,
      leads,
      converted,
      conversionRate: leads > 0
        ? Math.round((converted / leads) * 10000) / 100
        : 0,
    };
  });

  // Counselor performance: leads handled vs applications raised vs approvals,
  // all from real rows. LEFT JOINs keep counselors with zero apps/approvals.
  const counselorRows = await db.queryObject<{
    counselor: string;
    leads: string;
    applications: string;
    approved: string;
  }>(
    `SELECT c.counselor,
            c.leads::text AS leads,
            COALESCE(a.applications, 0)::text AS applications,
            COALESCE(a.approved, 0)::text AS approved
     FROM (
       SELECT counselor, count(*) AS leads
       FROM admissions_leads
       WHERE organization_id = $1 AND school_id = $2 AND counselor <> ''
       GROUP BY counselor
     ) c
     LEFT JOIN (
       SELECT counselor,
              count(*) AS applications,
              count(*) FILTER (WHERE status = 'approved') AS approved
       FROM admissions_applications
       WHERE organization_id = $1 AND school_id = $2 AND counselor <> ''
       GROUP BY counselor
     ) a ON a.counselor = c.counselor
     ORDER BY c.leads DESC
     LIMIT 20`,
    [organizationId, schoolId],
  );
  const counselorPerformance = counselorRows.map((row) => {
    const leads = Number(row.leads);
    const approved = Number(row.approved);
    return {
      counselor: row.counselor,
      leads,
      applications: Number(row.applications),
      approved,
      conversionRate: leads > 0
        ? Math.round((approved / leads) * 10000) / 100
        : 0,
    };
  });

  // Application status distribution, from real applications.
  const statusRows = await db.queryObject<{ status: string; count: string }>(
    `SELECT status, count(*)::text AS count
     FROM admissions_applications
     WHERE organization_id = $1 AND school_id = $2
     GROUP BY status`,
    [organizationId, schoolId],
  );
  const statusCounts: Record<string, number> = {};
  for (const status of APPLICATION_STATUSES) statusCounts[status] = 0;
  for (const row of statusRows) {
    statusCounts[row.status] = Number(row.count);
  }
  const statusTotal = Object.values(statusCounts).reduce((s, n) => s + n, 0);
  const applicationStatus = APPLICATION_STATUSES.map((status) => ({
    status,
    count: statusCounts[status] ?? 0,
    percent: statusTotal > 0
      ? Math.round(((statusCounts[status] ?? 0) / statusTotal) * 100)
      : 0,
  }));

  // ADM-D1: lost-reason rollup. Counts only leads that were marked lost with a
  // reason; all four buckets are always present (zero-filled) for a stable UI.
  const lostRows = await db.queryObject<{ lost_reason: string; count: string }>(
    `SELECT lost_reason, count(*)::text AS count
     FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2
       AND stage = 'lost' AND lost_reason IS NOT NULL
     GROUP BY lost_reason`,
    [organizationId, schoolId],
  );
  const lostCounts: Record<string, number> = {};
  for (const reason of LOST_REASONS) lostCounts[reason] = 0;
  for (const row of lostRows) {
    // Fold any unexpected legacy value into 'other' so the total stays honest.
    const reason = (LOST_REASONS as readonly string[]).includes(row.lost_reason)
      ? row.lost_reason
      : "other";
    lostCounts[reason] = (lostCounts[reason] ?? 0) + Number(row.count);
  }
  const lostReasons = LOST_REASONS.map((reason) => ({
    reason,
    count: lostCounts[reason] ?? 0,
  }));

  return {
    dashboard,
    sourceAnalysis,
    counselorPerformance,
    applicationStatus,
    lostReasons,
  };
}
