import type { TenantQueryClient } from "./tenant_db.ts";

// Diagnostic counters read by the provider-health check. Kept out of the
// handler so it only orchestrates; these are simple tenant-scoped counts.

/** Number of notification deliveries still queued (status = 'pending'). */
export async function countPendingNotificationDeliveries(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<number> {
  const rows = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count FROM notification_deliveries
     WHERE organization_id = $1 AND school_id = $2 AND status = 'pending'`,
    [organizationId, schoolId],
  );
  return Number(rows[0]?.count ?? 0);
}

/** Number of platform secret-vault entries for the organization. */
export async function countPlatformSecretVaultEntries(
  db: TenantQueryClient,
  organizationId: string,
): Promise<number> {
  const rows = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count FROM platform_secret_vault WHERE organization_id = $1`,
    [organizationId],
  );
  return Number(rows[0]?.count ?? 0);
}

// ── Operations snapshot counters (org-scoped outbox / ops health) ──────────────

/** Domain-event outbox rows still pending or failed for the organization. */
export async function countPendingOrFailedDomainEvents(
  db: TenantQueryClient,
  organizationId: string,
): Promise<number> {
  return await db.queryCount(
    `SELECT count(*)::text AS count FROM domain_events
     WHERE organization_id = $1 AND status IN ('pending', 'failed')`,
    [organizationId],
  );
}

/** Open accounts-payable commitments for the school. */
export async function countOpenApCommitments(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<number> {
  return await db.queryCount(
    `SELECT count(*)::text AS count FROM finance_ap_commitments
     WHERE organization_id = $1 AND school_id = $2 AND status = 'open'`,
    [organizationId, schoolId],
  );
}

/** Onboarding import jobs sitting in the 'previewed' state for the school. */
export async function countPreviewedImportJobs(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<number> {
  return await db.queryCount(
    `SELECT count(*)::text AS count FROM onboarding_import_jobs
     WHERE organization_id = $1 AND school_id = $2 AND status = 'previewed'`,
    [organizationId, schoolId],
  );
}

/**
 * Pending notification deliveries for the school, via db.queryCount. Mirrors the
 * exact query the operations snapshot issued inline.
 */
export async function countPendingNotificationDeliveriesForOps(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<number> {
  return await db.queryCount(
    `SELECT count(*)::text AS count FROM notification_deliveries
     WHERE organization_id = $1 AND school_id = $2 AND status = 'pending'`,
    [organizationId, schoolId],
  );
}
