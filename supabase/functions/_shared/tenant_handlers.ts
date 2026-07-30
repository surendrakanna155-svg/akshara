import type { AppConfig } from "./config.ts";
import { createServiceClient } from "./db.ts";
import { createStorageAdmin } from "./storage/storage_service.ts";
import type { AccessTokenClaims } from "./jwt.ts";
import { envelope, errorEnvelope, jsonResponse } from "./http.ts";
import {
  assertEdgeTenantRole,
  probeTenantConnection,
  TenantDbNotConfiguredError,
  withTenantContext,
  type TenantQueryClient,
} from "./tenant_db.ts";
import {
  runEnforcedIsolationProbes,
  type IsolationProbeResult,
} from "./tenant_isolation_probes.ts";
import { requireInternalHealthAccess } from "./internal_health_auth.ts";
import {
  countOpenApCommitments,
  countPendingNotificationDeliveries,
  countPendingNotificationDeliveriesForOps,
  countPendingOrFailedDomainEvents,
  countPlatformSecretVaultEntries,
  countPreviewedImportJobs,
} from "./provider_health_repository.ts";

/** Runs RLS-enforced isolation probes via direct `erp_tenant` connection. */
export async function handleTenantAccessHealth(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const denied = requireInternalHealthAccess(req, config);
  if (denied) return denied;

  const connection = await probeTenantConnection(config);

  if (!connection.ok) {
    return jsonResponse(
      envelope({
        status: "degraded",
        connection,
        isolation: { pass: false, error: connection.error ?? "Tenant DB unavailable" },
      }),
      { status: 503 },
    );
  }

  // P0-INFRA-6 / DB-2: fail the health check (→ deploy fails) if the edge is not
  // connected as the non-bypass `erp_tenant` role.
  const roleError = assertEdgeTenantRole(connection);
  if (roleError) {
    return jsonResponse(
      envelope({
        status: "degraded",
        connection,
        isolation: { pass: false, error: roleError },
      }),
      { status: 503 },
    );
  }

  try {
    const runWithClaims = async (
      claims: AccessTokenClaims,
      fn: (db: TenantQueryClient) => Promise<IsolationProbeResult>,
    ): Promise<IsolationProbeResult> => {
      return await withTenantContext(config, claims, fn);
    };

    const isolation = await runEnforcedIsolationProbes(runWithClaims);

    return jsonResponse(
      envelope({
        status: isolation.pass ? "ok" : "degraded",
        connection,
        isolation,
      }),
      { status: isolation.pass ? 200 : 503 },
    );
  } catch (error) {
    return jsonResponse(
      envelope({
        status: "degraded",
        connection,
        isolation: {
          pass: false,
          error: error instanceof Error ? error.message : "Isolation probe failed",
        },
      }),
      { status: 503 },
    );
  }
}

export function tenantDbNotConfiguredResponse(
  error: TenantDbNotConfiguredError = new TenantDbNotConfiguredError(),
): Response {
  return errorEnvelope("TENANT_DB_NOT_CONFIGURED", error.message, 503);
}

export async function handleOperationsHealth(req: Request, config: AppConfig): Promise<Response> {
  const denied = requireInternalHealthAccess(req, config);
  if (denied) return denied;

  const connection = await probeTenantConnection(config);
  if (!connection.ok) {
    return jsonResponse(envelope({ status: "degraded", connection }), { status: 503 });
  }

  try {
    const orgId = "a1000000-0000-4000-8000-000000000001";
    const schoolId = "a2000000-0000-4000-8000-000000000001";
    const staffClaims: AccessTokenClaims = {
      sub: "a3000000-0000-4000-8000-000000000001",
      tenant_id: orgId,
      organization_id: orgId,
      school_id: schoolId,
      role: "schoolAdmin",
      role_slugs: ["schoolAdmin"],
      primary_role: "schoolAdmin",
      permissions: ["viewAdminHub"],
      permissions_version: 1,
      scope: "school",
      school_group_id: null,
      student_id: null,
      child_ids: [],
      session_id: "ops-health",
    };

    const snapshot = await withTenantContext(config, staffClaims, async (db) => {
      const pendingEvents = await countPendingOrFailedDomainEvents(db, orgId);
      const pendingDeliveries = await countPendingNotificationDeliveriesForOps(db, orgId, schoolId);
      const openAp = await countOpenApCommitments(db, orgId, schoolId);
      const importJobs = await countPreviewedImportJobs(db, orgId, schoolId);
      return { pendingEvents, pendingDeliveries, openApCommitments: openAp, previewedImportJobs: importJobs };
    });

    return jsonResponse(envelope({ status: "ok", connection, snapshot }));
  } catch (error) {
    return jsonResponse(
      envelope({
        status: "degraded",
        connection,
        error: error instanceof Error ? error.message : "Operations snapshot failed",
      }),
      { status: 503 },
    );
  }
}

const MEMORY_BUCKET = "school-memories";

/** Storage bucket reachability for platform health probes (v15.6). */
export async function handleStorageHealth(req: Request, config: AppConfig): Promise<Response> {
  const denied = requireInternalHealthAccess(req, config);
  if (denied) return denied;

  try {
    const client = createStorageAdmin(config);
    const { data, error } = await client.storage.from(MEMORY_BUCKET).list("", { limit: 1 });
    if (error) {
      return jsonResponse(
        envelope({
          status: "degraded",
          bucket: MEMORY_BUCKET,
          reachable: false,
          error: error.message,
        }),
        { status: 503 },
      );
    }
    return jsonResponse(
      envelope({
        status: "ok",
        bucket: MEMORY_BUCKET,
        reachable: true,
        objectSampleCount: data?.length ?? 0,
      }),
    );
  } catch (error) {
    return jsonResponse(
      envelope({
        status: "degraded",
        bucket: MEMORY_BUCKET,
        reachable: false,
        error: error instanceof Error ? error.message : "Storage probe failed",
      }),
      { status: 503 },
    );
  }
}

/** Aggregated provider + delivery health (v15.6). */
export async function handleProviderHealth(req: Request, config: AppConfig): Promise<Response> {
  const denied = requireInternalHealthAccess(req, config);
  if (denied) return denied;

  const connection = await probeTenantConnection(config);
  let deliveryPending = 0;
  let vaultConfigured = false;

  if (connection.ok) {
    try {
      const orgId = "a1000000-0000-4000-8000-000000000001";
      const schoolId = "a2000000-0000-4000-8000-000000000001";
      const staffClaims: AccessTokenClaims = {
        sub: "a3000000-0000-4000-8000-000000000001",
        tenant_id: orgId,
        organization_id: orgId,
        school_id: schoolId,
        role: "schoolAdmin",
        role_slugs: ["schoolAdmin"],
        primary_role: "schoolAdmin",
        permissions: ["viewAdminHub"],
        permissions_version: 1,
        scope: "school",
        school_group_id: null,
        student_id: null,
        child_ids: [],
        session_id: "provider-health",
      };
      deliveryPending = await withTenantContext(config, staffClaims, async (db) => {
        const pending = await countPendingNotificationDeliveries(db, orgId, schoolId);
        vaultConfigured = (await countPlatformSecretVaultEntries(db, orgId)) > 0;
        return pending;
      });
    } catch {
      deliveryPending = -1;
    }
  }

  let storageOk = false;
  try {
    const client = createStorageAdmin(config);
    const { error } = await client.storage.from(MEMORY_BUCKET).list("", { limit: 1 });
    storageOk = !error;
  } catch {
    storageOk = false;
  }

  const status = connection.ok && storageOk ? "ok" : "degraded";
  return jsonResponse(
    envelope({
      status,
      connection,
      storage: { bucket: MEMORY_BUCKET, reachable: storageOk },
      vault: { configured: vaultConfigured },
      delivery: { pendingQueue: deliveryPending },
    }),
    { status: status === "ok" ? 200 : 503 },
  );
}

interface BackupRunRow {
  status: string;
  kind: string;
  artifact_bytes: number | null;
  sha256: string | null;
  offsite: boolean | null;
  offsite_location: string | null;
  finished_at: string | null;
  created_at: string;
  error: string | null;
}

interface RestoreDrillRow {
  status: string;
  tables_checked: number | null;
  rows_sampled: number | null;
  mismatch: string | null;
  finished_at: string | null;
  created_at: string;
}

/**
 * Backup freshness probe (Batch 7). Reads the ops backup ledger via the
 * service-role connection (it bypasses the no-policy RLS on ops_* tables) and
 * reports degraded (503) when there is no successful backup within
 * `backupMaxAgeHours`, or the most recent run failed. `offsite=false` is a
 * warning surfaced in the body but does NOT flip status (a local backup still
 * protects against most data loss).
 */
export async function handleBackupHealth(req: Request, config: AppConfig): Promise<Response> {
  const denied = requireInternalHealthAccess(req, config);
  if (denied) return denied;

  try {
    const client = createServiceClient(config);

    const { data: latestSuccess, error: e1 } = await client
      .from("ops_backup_runs")
      .select("status,kind,artifact_bytes,sha256,offsite,offsite_location,finished_at,created_at,error")
      .eq("status", "success")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle<BackupRunRow>();

    const { data: latestAny, error: e2 } = await client
      .from("ops_backup_runs")
      .select("status,kind,finished_at,created_at,error")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle<BackupRunRow>();

    if (e1 || e2) {
      return jsonResponse(
        envelope({ status: "degraded", reason: "ledger_unreadable", error: (e1 ?? e2)?.message }),
        { status: 503 },
      );
    }

    const now = Date.now();
    let ageHours: number | null = null;
    if (latestSuccess?.created_at) {
      const ref = latestSuccess.finished_at ?? latestSuccess.created_at;
      ageHours = Math.round(((now - new Date(ref).getTime()) / 3_600_000) * 10) / 10;
    }

    const lastRunFailed = latestAny?.status === "failed";
    const noBackup = !latestSuccess;
    const stale = ageHours !== null && ageHours > config.backupMaxAgeHours;
    const healthy = !noBackup && !stale;

    const { data: drill } = await client
      .from("ops_restore_drills")
      .select("status,tables_checked,rows_sampled,mismatch,finished_at,created_at")
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle<RestoreDrillRow>();

    const reason = noBackup ? "no_successful_backup" : stale ? "backup_stale" : null;

    return jsonResponse(
      envelope({
        status: healthy ? "ok" : "degraded",
        reason,
        maxAgeHours: config.backupMaxAgeHours,
        lastBackup: latestSuccess
          ? {
            kind: latestSuccess.kind,
            ageHours,
            bytes: latestSuccess.artifact_bytes,
            sha256: latestSuccess.sha256,
            offsite: latestSuccess.offsite ?? false,
            offsiteLocation: latestSuccess.offsite_location,
            finishedAt: latestSuccess.finished_at,
          }
          : null,
        lastRunFailed,
        lastRunError: lastRunFailed ? latestAny?.error ?? null : null,
        offsiteWarning: latestSuccess ? !(latestSuccess.offsite ?? false) : null,
        lastDrill: drill
          ? {
            status: drill.status,
            tablesChecked: drill.tables_checked,
            rowsSampled: drill.rows_sampled,
            mismatch: drill.mismatch,
            finishedAt: drill.finished_at,
          }
          : null,
      }),
      { status: healthy ? 200 : 503 },
    );
  } catch (error) {
    return jsonResponse(
      envelope({
        status: "degraded",
        reason: "probe_error",
        error: error instanceof Error ? error.message : "Backup probe failed",
      }),
      { status: 503 },
    );
  }
}
