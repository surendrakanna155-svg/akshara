import type { AppConfig } from "./config.ts";
import type { AccessTokenClaims } from "./jwt.ts";
import { envelope, errorEnvelope, jsonResponse } from "./http.ts";
import {
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

export function tenantDbNotConfiguredResponse(error: TenantDbNotConfiguredError): Response {
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
      const pendingEvents = await db.queryCount(
        `SELECT count(*)::text AS count FROM domain_events
         WHERE organization_id = $1 AND status IN ('pending', 'failed')`,
        [orgId],
      );
      const pendingDeliveries = await db.queryCount(
        `SELECT count(*)::text AS count FROM notification_deliveries
         WHERE organization_id = $1 AND school_id = $2 AND status = 'pending'`,
        [orgId, schoolId],
      );
      const openAp = await db.queryCount(
        `SELECT count(*)::text AS count FROM finance_ap_commitments
         WHERE organization_id = $1 AND school_id = $2 AND status = 'open'`,
        [orgId, schoolId],
      );
      const importJobs = await db.queryCount(
        `SELECT count(*)::text AS count FROM onboarding_import_jobs
         WHERE organization_id = $1 AND school_id = $2 AND status = 'previewed'`,
        [orgId, schoolId],
      );
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
