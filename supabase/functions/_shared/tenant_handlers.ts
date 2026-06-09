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

/** Runs RLS-enforced isolation probes via direct `erp_tenant` connection. */
export async function handleTenantAccessHealth(
  config: AppConfig,
): Promise<Response> {
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
