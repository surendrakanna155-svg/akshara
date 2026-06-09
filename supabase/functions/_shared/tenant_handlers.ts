import type { AppConfig } from "./config.ts";
import { createServiceClient } from "./db.ts";
import { envelope, errorEnvelope, jsonResponse } from "./http.ts";
import { probeTenantConnection, TenantDbNotConfiguredError } from "./tenant_db.ts";

interface EnforcedTestResult {
  pass: boolean;
  enforced?: boolean;
  role?: string;
  tests?: Array<{ name: string; pass: boolean; detail?: string }>;
}

/** Runs RLS-enforced isolation probes via `erp_tenant` SECURITY DEFINER RPC. */
export async function handleTenantAccessHealth(
  config: AppConfig,
): Promise<Response> {
  const connection = await probeTenantConnection(config);

  const client = createServiceClient(config);
  const { data, error } = await client.rpc("run_tenant_isolation_enforced_test");

  if (error) {
    return jsonResponse(
      envelope({
        status: "degraded",
        connection,
        isolation: { pass: false, error: error.message },
      }),
      { status: 503 },
    );
  }

  const result = data as EnforcedTestResult;
  const pass = result?.pass === true;

  return jsonResponse(
    envelope({
      status: pass ? "ok" : "degraded",
      connection,
      isolation: result,
    }),
    { status: pass ? 200 : 503 },
  );
}

export function tenantDbNotConfiguredResponse(error: TenantDbNotConfiguredError): Response {
  return errorEnvelope("TENANT_DB_NOT_CONFIGURED", error.message, 503);
}
