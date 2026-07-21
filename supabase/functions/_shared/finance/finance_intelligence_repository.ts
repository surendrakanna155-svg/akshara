import type { TenantQueryClient } from "../tenant_db.ts";

// Data access for the finance intelligence snapshots table
// (finance_intelligence_snapshots). The computed copilot/executive payloads are
// persisted here for the executive dashboard + audit trail; the compute itself
// lives in finance_intelligence_service.ts and the orchestration in the handler.

export type FinanceIntelligenceSnapshotType = "copilot" | "executive";

/**
 * Persist a computed finance intelligence snapshot (copilot or executive) for
 * the current tenant scope. Tenant-scoped via the RLS context on `db`.
 */
export async function insertIntelligenceSnapshot(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  snapshotType: FinanceIntelligenceSnapshotType,
  payload: unknown,
  createdBy: string | null,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO finance_intelligence_snapshots (organization_id, school_id, snapshot_type, payload, created_by)
     VALUES ($1, $2, $3, $4::jsonb, $5)`,
    [organizationId, schoolId, snapshotType, JSON.stringify(payload), createdBy],
  );
}
