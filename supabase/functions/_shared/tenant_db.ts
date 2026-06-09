import { Client } from "https://deno.land/x/postgres@v0.19.3/mod.ts";
import type { AppConfig } from "./config.ts";
import type { AccessTokenClaims } from "./jwt.ts";

/** Thrown when ERP_TENANT_DATABASE_URL is not configured. */
export class TenantDbNotConfiguredError extends Error {
  constructor() {
    super(
      "ERP_TENANT_DATABASE_URL is not configured — tenant-enforced queries unavailable",
    );
    this.name = "TenantDbNotConfiguredError";
  }
}

export interface TenantContextParams {
  tenantId: string;
  scope: string;
  userId: string;
  schoolId: string | null;
  schoolGroupId: string | null;
  studentId: string | null;
  parentUserId: string | null;
}

export function claimsToTenantParams(claims: AccessTokenClaims): TenantContextParams {
  return {
    tenantId: claims.tenant_id,
    scope: claims.scope,
    userId: claims.sub,
    schoolId: claims.school_id,
    schoolGroupId: claims.school_group_id,
    studentId: claims.student_id,
    parentUserId: claims.scope === "parent" ? claims.sub : null,
  };
}

async function applyRequestContext(
  client: Client,
  params: TenantContextParams,
): Promise<void> {
  await client.queryObject`
    SELECT app.set_request_context(
      ${params.tenantId}::uuid,
      ${params.scope},
      ${params.userId}::uuid,
      ${params.schoolId}::uuid,
      ${params.schoolGroupId}::uuid,
      ${params.studentId}::uuid,
      ${params.parentUserId}::uuid
    )
  `;
}

/** Read-only query executor on a non-bypass `erp_tenant` connection with RLS enforced. */
export class TenantQueryClient {
  constructor(private readonly client: Client) {}

  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    const result = await this.client.queryObject<{ count: string }>(sql, args);
    return parseInt(result.rows[0]?.count ?? "0", 10);
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    const result = await this.client.queryObject<T>(sql, args);
    return result.rows;
  }

  get raw(): Client {
    return this.client;
  }
}

/**
 * Executes `operation` on a non-bypass `erp_tenant` PostgreSQL connection.
 * Calls `app.set_request_context` before any tenant query (TD-P0-01 AC-1).
 *
 * Auth plumbing must continue using `createServiceClient` — this helper is for
 * tenant operational data reads/writes in module APIs.
 */
export async function withTenantContext<T>(
  config: AppConfig,
  claims: AccessTokenClaims,
  operation: (db: TenantQueryClient) => Promise<T>,
): Promise<T> {
  if (!config.erpTenantDatabaseUrl) {
    throw new TenantDbNotConfiguredError();
  }

  const client = new Client(config.erpTenantDatabaseUrl);

  await client.connect();
  const params = claimsToTenantParams(claims);

  try {
    await applyRequestContext(client, params);
    return await operation(new TenantQueryClient(client));
  } finally {
    await client.end();
  }
}

/** Probe that the tenant connection is configured and authenticates as erp_tenant. */
export async function probeTenantConnection(
  config: AppConfig,
): Promise<{ ok: boolean; role?: string; error?: string }> {
  if (!config.erpTenantDatabaseUrl) {
    return { ok: false, error: "ERP_TENANT_DATABASE_URL not set" };
  }

  const client = new Client(config.erpTenantDatabaseUrl);
  try {
    await client.connect();
    const result = await client.queryObject<{ role: string }>`
      SELECT current_user::text AS role
    `;
    return { ok: true, role: result.rows[0]?.role };
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : "Connection failed",
    };
  } finally {
    await client.end();
  }
}
