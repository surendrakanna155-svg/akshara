// B4 AI Admissions Assistant — intelligence snapshot loader.
//
// Reuses the B1 dashboard aggregation (getDashboard) and adds the two extra
// CRM signals the next-best-action advisor needs: open follow-ups and
// unassigned leads. Read-only.

import type { TenantQueryClient } from "../tenant_db.ts";
import { getDashboard } from "./admissions_dashboard_repository.ts";
import {
  type AdmissionsIntelligence,
  buildAdmissionsIntelligence,
} from "./admissions_intelligence.ts";

export async function loadAdmissionsIntelligence(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<AdmissionsIntelligence> {
  const dashboard = await getDashboard(db, organizationId, schoolId);

  const [pendingRow] = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count FROM admissions_lead_follow_ups
     WHERE organization_id = $1 AND school_id = $2 AND status = 'pending'`,
    [organizationId, schoolId],
  );
  const pendingFollowUps = Number(pendingRow?.count ?? "0");

  const [unassignedRow] = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2 AND counselor = ''`,
    [organizationId, schoolId],
  );
  const unassignedLeads = Number(unassignedRow?.count ?? "0");

  // A few highest-value unassigned leads (hot first) for per-lead actions.
  const sampleRows = await db.queryObject<{
    id: string;
    student_name: string;
    score: string;
  }>(
    `SELECT id, student_name, score FROM admissions_leads
     WHERE organization_id = $1 AND school_id = $2 AND counselor = ''
     ORDER BY (score = 'hot') DESC, updated_at DESC
     LIMIT 5`,
    [organizationId, schoolId],
  );
  const unassignedSample = sampleRows.map((row) => ({
    id: row.id,
    studentName: row.student_name,
    score: row.score,
  }));

  return buildAdmissionsIntelligence({
    dashboard,
    pendingFollowUps,
    unassignedLeads,
    unassignedSample,
  });
}
