// PRC-A caps 44-49 — platform-scoped DB access path (the AI/WhatsApp/SMS
// provider vault). See `20260882000000_platform_db_role.sql` for the DB-side
// half of this fix and the full defect writeup.
//
// `tenant_db.ts`'s `withTenantContext` is, BY DESIGN, a non-bypass
// `erp_tenant` connection scoped to a single organization's data. Platform
// secrets (`platform_secret_vault` / `platform_provider_configs` /
// `platform_secret_audit_log`) are SUPER-ADMIN/platform scope, not tenant
// data, and `erp_tenant` correctly has NO grant on them (RT-15) — so every
// Control-Center vault handler that ran on `withTenantContext` has always
// failed `permission denied`. This module is the missing platform-scoped
// counterpart: a SEPARATE role (`erp_platform`), a SEPARATE connection pool,
// and an app-layer defense-in-depth check that runs BEFORE a connection is
// even opened.
//
// `erp_platform` does NOT call `app.set_request_context` — unlike the tenant
// tables, the three platform tables above carry no `organization_id =
// app_current_tenant_id()`-style RLS to satisfy, so there is no tenant
// request context to set (see the migration for the RLS detail).

import {
  Pool,
  type PoolClient,
} from "https://deno.land/x/postgres@v0.19.3/mod.ts";
import type { AppConfig } from "./config.ts";
import { errorEnvelope } from "./http.ts";
import type { AccessTokenClaims, AuthScope } from "./jwt.ts";

/**
 * Platform/admin surface is low-traffic (Control-Center provider config,
 * infrequent rotate/health calls) compared to the tenant data path, so a
 * smaller pool than `tenant_db.ts`'s `POOL_SIZE = 10` is plenty.
 */
const POOL_SIZE = 5;
let _pool: Pool | null = null;
let _poolUrl: string | null = null;

function platformPool(url: string): Pool {
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

/** Thrown when ERP_PLATFORM_DATABASE_URL is not configured. */
export class PlatformDbNotConfiguredError extends Error {
  constructor() {
    super(
      "ERP_PLATFORM_DATABASE_URL is not configured — platform-scoped queries unavailable",
    );
    this.name = "PlatformDbNotConfiguredError";
  }
}

/**
 * Thrown by `withPlatformContext`'s app-layer defense-in-depth check when the
 * caller is not genuinely a platform/super-admin session — BEFORE any DB
 * connection is opened. This is IN ADDITION to (never instead of) the
 * route-level `requirePermission("managePlatformVault"/"managePlatformProviders"/...)`
 * gate every handler already has; RT-15's `platform_secret_vault_deny_all` RLS
 * policy is the last line of defense, the route gate is the first, this is a
 * second independent check in between.
 */
export class PlatformScopeDeniedError extends Error {
  constructor() {
    super(
      "Caller is not a platform/super-admin session — platform DB access denied",
    );
    this.name = "PlatformScopeDeniedError";
  }
}

/**
 * Scopes eligible for platform-owner operations — the SAME allow-list already
 * used (as a local `ORG_SCOPES` constant) in
 * `organization_builder_handlers.ts` and `director_handlers.ts`, reused here
 * rather than invented. "platform" is reserved for a future literal
 * platform-scope session (the `AuthScope` union already has the literal, but
 * `auth_context.ts`'s `resolveScopeContext` has no `case "platform"` yet, so
 * no login can produce it today); today's superAdmin session carries scope
 * "organization", which is why that value must stay in the allow-list.
 */
const PLATFORM_CALLER_SCOPES: readonly AuthScope[] = [
  "organization",
  "school_group",
  "platform",
];

/**
 * The Platform-category permission catalog
 * (`20260625010000_phase10_permissions.sql` /
 * `20260627105000_pilot_permission_catalog_recovery.sql`), granted ONLY to the
 * `superAdmin` role. Holding ANY of these (combined with a platform-caller
 * scope above) is this codebase's existing signal for "this is the platform
 * owner" — the same signal every vault handler's route-level
 * `requirePermission(...)` already checks; reused here as the independent
 * app-layer check, not a new concept.
 */
const PLATFORM_PERMISSIONS: readonly string[] = [
  "managePlatformProviders",
  "viewPlatformUsage",
  "managePlatformVault",
  "managePlatformFeatures",
  "managePlatformWhatsApp",
];

/** Pure predicate — exported so callers/tests can reason about it directly. */
export function isPlatformCaller(claims: AccessTokenClaims): boolean {
  return PLATFORM_CALLER_SCOPES.includes(claims.scope) &&
    PLATFORM_PERMISSIONS.some((p) => claims.permissions.includes(p));
}

/** Read/write query executor on a non-bypass `erp_platform` connection. */
export class PlatformQueryClient {
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
 * Executes `operation` on a non-bypass `erp_platform` PostgreSQL connection —
 * the platform-scoped counterpart to `tenant_db.ts`'s `withTenantContext`.
 *
 * Two gates run BEFORE any connection is opened, in order:
 *   1. App-layer defense in depth — `isPlatformCaller(claims)` — throws
 *      `PlatformScopeDeniedError` otherwise. Independent of, and in addition
 *      to, the route-level `requirePermission` gate the caller already ran.
 *   2. Config check — throws `PlatformDbNotConfiguredError` when
 *      `ERP_PLATFORM_DATABASE_URL` is unset, so handlers can return the same
 *      503 shape `tenantDbNotConfiguredResponse()` produces (see
 *      `platformDbNotConfiguredResponse` below).
 *
 * `config: AppConfig` is accepted for call-site parity with
 * `withTenantContext(config, claims, operation)` (every existing call site
 * already has `config` in scope), but the connection string is read directly
 * from `Deno.env` rather than threaded through `AppConfig` — `AppConfig` is a
 * large, exhaustively-typed interface shared by ~270 files across every
 * module lane, and adding a field to it is outside this fix's scope.
 */
export async function withPlatformContext<T>(
  _config: AppConfig,
  claims: AccessTokenClaims,
  operation: (db: PlatformQueryClient) => Promise<T>,
): Promise<T> {
  if (!isPlatformCaller(claims)) {
    throw new PlatformScopeDeniedError();
  }

  const url = Deno.env.get("ERP_PLATFORM_DATABASE_URL");
  if (!url) {
    throw new PlatformDbNotConfiguredError();
  }

  const client = await platformPool(url).connect();
  try {
    await client.queryObject`BEGIN`;
    try {
      const result = await operation(new PlatformQueryClient(client));
      await client.queryObject`COMMIT`;
      return result;
    } catch (error) {
      await client.queryObject`ROLLBACK`;
      throw error;
    }
  } finally {
    client.release();
  }
}

/**
 * 503 response shape for a not-configured platform DB — mirrors
 * `tenantDbNotConfiguredResponse` in `tenant_handlers.ts` (not duplicated
 * there: this module owns the platform DB path end to end).
 */
export function platformDbNotConfiguredResponse(
  error: PlatformDbNotConfiguredError = new PlatformDbNotConfiguredError(),
): Response {
  return errorEnvelope("PLATFORM_DB_NOT_CONFIGURED", error.message, 503);
}

/** Probe that the platform connection is configured and authenticates as erp_platform. */
export async function probePlatformConnection(): Promise<
  { ok: boolean; role?: string; bypassRls?: boolean; error?: string }
> {
  const url = Deno.env.get("ERP_PLATFORM_DATABASE_URL");
  if (!url) {
    return { ok: false, error: "ERP_PLATFORM_DATABASE_URL not set" };
  }

  let client: PoolClient | null = null;
  try {
    client = await platformPool(url).connect();
    const result = await client.queryObject<
      { role: string; bypass_rls: boolean }
    >`
      SELECT current_user::text AS role,
             (SELECT rolbypassrls FROM pg_roles WHERE rolname = current_user) AS bypass_rls
    `;
    return {
      ok: true,
      role: result.rows[0]?.role,
      bypassRls: result.rows[0]?.bypass_rls ?? undefined,
    };
  } catch (error) {
    return {
      ok: false,
      error: error instanceof Error ? error.message : "Connection failed",
    };
  } finally {
    client?.release();
  }
}

/**
 * Deploy-time assertion that the edge connects as the non-bypass
 * `erp_platform` role — the platform-path counterpart to `tenant_db.ts`'s
 * `assertEdgeTenantRole`. Not wired into any health route by this change (no
 * route file is owned here) — exported for whoever owns `tenant_handlers.ts`
 * / the health routes to wire up, same as `assertEdgeTenantRole` is today.
 */
export const EDGE_PLATFORM_ROLE = "erp_platform";
export function assertEdgePlatformRole(
  connection: { role?: string; bypassRls?: boolean },
): string | null {
  if (connection.role !== EDGE_PLATFORM_ROLE) {
    return `edge platform DB role is '${connection.role ?? "unknown"}', expected '${EDGE_PLATFORM_ROLE}' ` +
      `(never service_role, never erp_tenant — platform secrets are a separate role)`;
  }
  if (connection.bypassRls === true) {
    return `edge platform DB role '${connection.role}' can BYPASS RLS (rolbypassrls=true); ` +
      `it must be NOBYPASSRLS`;
  }
  return null;
}
