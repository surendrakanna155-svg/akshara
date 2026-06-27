import {
  Pool,
  type PoolClient,
} from "https://deno.land/x/postgres@v0.19.3/mod.ts";
import type { AppConfig } from "./config.ts";
import type { AccessTokenClaims } from "./jwt.ts";

/**
 * RT-35 — a process-level connection pool replaces the previous per-request
 * `new Client() → connect() → end()`, which opened (and tore down) a fresh
 * Postgres connection on EVERY tenant query and would exhaust the database's
 * connection slots under a traffic spike (a 500 cascade). One small pool of
 * `erp_tenant` connections is created lazily per edge isolate and reused across
 * requests; `POOL_SIZE` caps the concurrent connections this isolate can hold.
 */
const POOL_SIZE = 10;
let _pool: Pool | null = null;
let _poolUrl: string | null = null;

function tenantPool(url: string): Pool {
  if (_pool && _poolUrl === url) return _pool;
  // Connection string changed (config reload) — drain the stale pool first.
  if (_pool) {
    const stale = _pool;
    _pool = null;
    stale.end().catch(() => {});
  }
  _pool = new Pool(url, POOL_SIZE, /* lazy */ true);
  _poolUrl = url;
  return _pool;
}

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
  client: PoolClient,
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
  constructor(private readonly client: PoolClient) {}

  async queryCount(sql: string, args: unknown[] = []): Promise<number> {
    const result = await this.client.queryObject<{ count: string }>(sql, args);
    return parseInt(result.rows[0]?.count ?? "0", 10);
  }

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    const result = await this.client.queryObject<T>(sql, args);
    return result.rows;
  }

  get raw(): PoolClient {
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

  // RT-35: acquire a pooled connection instead of opening a new one per request.
  const client = await tenantPool(config.erpTenantDatabaseUrl).connect();
  const params = claimsToTenantParams(claims);

  try {
    // set_request_context uses transaction-local config (is_local=true); keep one transaction.
    await client.queryObject`BEGIN`;
    try {
      await applyRequestContext(client, params);
      const result = await operation(new TenantQueryClient(client));
      await client.queryObject`COMMIT`;
      return result;
    } catch (error) {
      await client.queryObject`ROLLBACK`;
      throw error;
    }
  } finally {
    // Return the connection to the pool (does not close it).
    client.release();
  }
}

/** Probe that the tenant connection is configured and authenticates as erp_tenant. */
export async function probeTenantConnection(
  config: AppConfig,
): Promise<{ ok: boolean; role?: string; error?: string }> {
  if (!config.erpTenantDatabaseUrl) {
    return { ok: false, error: "ERP_TENANT_DATABASE_URL not set" };
  }

  // Probe through the pool (RT-35) so it also exercises the pooled path.
  let client: PoolClient | null = null;
  try {
    client = await tenantPool(config.erpTenantDatabaseUrl).connect();
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
    client?.release();
  }
}
