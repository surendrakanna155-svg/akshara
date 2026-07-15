import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import {
  PlatformDbNotConfiguredError,
  platformDbNotConfiguredResponse,
  PlatformScopeDeniedError,
  withPlatformContext,
} from "../platform_db.ts";
import { emitMutationAudit, schoolCompletionAudit } from "../audit/mutation_audit_catalog.ts";
import {
  getUsageAnalytics,
  listFeatureEnablements,
  setFeatureEnablement,
  usageAnalyticsToApi,
} from "./platform_providers_service.ts";
import {
  checkSecretHealth,
  listProviderConfigs,
  providerConfigToApi,
  rotateSecret,
  storeSecret,
  upsertProviderConfig,
  vaultSecretToApi,
} from "../vault/vault_service.ts";

// PRC-A caps 44-49 — `platform_secret_vault` / `platform_provider_configs` /
// `platform_secret_audit_log` are platform/super-admin tables that
// `erp_tenant` (the `withTenantContext` connection) has never had a grant on
// (RT-15, `20260815000000_red_team_wave2_tenant_privacy_rls.sql`) — every
// handler below that touches them ran on `withTenantContext` and therefore
// ALWAYS failed `permission denied` in production. Rewired to
// `withPlatformContext` (`../platform_db.ts`), the platform-scoped
// counterpart added in `20260882000000_platform_db_role.sql`.
//
// `handleGetPlatformUsage` / `handleListFeatureEnablements` /
// `handleSetFeatureEnablement` are UNCHANGED (still `withTenantContext`):
// they read/write `platform_usage_events` / `platform_feature_enablements`,
// not the vault tables — a separate, pre-existing "no erp_tenant grant on
// these two tables either" gap outside this fix's named scope (see delivery
// report; not silently touched here).

function tenantError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  return errorEnvelope("INTERNAL_ERROR", String(error), 500);
}

function platformError(error: unknown): Response {
  if (error instanceof PlatformDbNotConfiguredError) return platformDbNotConfiguredResponse(error);
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  if (error instanceof PlatformScopeDeniedError) return errorEnvelope("FORBIDDEN", error.message, 403);
  return errorEnvelope("INTERNAL_ERROR", String(error), 500);
}

export async function handleListPlatformProviders(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "managePlatformProviders");
  if (denied) return denied;

  try {
    const items = await withPlatformContext(config, auth.claims, (db) =>
      listProviderConfigs(db, organizationIdFromClaims(auth.claims))
    );
    return jsonResponse(envelope({ items: items.map(providerConfigToApi) }));
  } catch (error) {
    return platformError(error);
  }
}

export async function handleUpsertPlatformProvider(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "managePlatformProviders");
  if (denied) return denied;

  const body = await readJson<{
    providerCategory: string;
    providerName: string;
    credential?: string;
    isActive?: boolean;
    isPrimary?: boolean;
    config?: Record<string, unknown>;
  }>(req);
  if (!body?.providerCategory || !body.providerName) {
    return errorEnvelope("VALIDATION_ERROR", "providerCategory and providerName required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);

  try {
    const saved = await withPlatformContext(config, auth.claims, async (db) => {
      let vaultSecretId: string | undefined;
      if (body.credential) {
        const secret = await storeSecret(db, {
          organizationId: orgId,
          providerCategory: body.providerCategory,
          providerName: body.providerName,
          credential: body.credential,
          actorUserId: auth.claims.sub,
        });
        vaultSecretId = secret.id;
      }
      return await upsertProviderConfig(db, {
        organizationId: orgId,
        providerCategory: body.providerCategory,
        providerName: body.providerName,
        vaultSecretId,
        isActive: body.isActive,
        isPrimary: body.isPrimary,
        config: body.config,
      });
    });
    // The vault write above runs on the platform-scoped connection
    // (`erp_platform` — no tenant RLS context). Audit/domain-event emission
    // is tenant-scoped (`domain_events`/`audit_events` RLS on
    // `app_current_tenant_id()`), so it stays on the existing, already-working
    // `withTenantContext` path. This is necessarily a SEPARATE transaction
    // from the platform write above — a cross-role write can't share one DB
    // transaction — so the audit record is best-effort-after-commit, not
    // atomic with the vault write; see the PRC-A 44-49 delivery report.
    await withTenantContext(config, auth.claims, (db) =>
      emitMutationAudit(db, auth.claims, schoolCompletionAudit.platformProviderUpdated(saved.id), req)
    );
    return jsonResponse(envelope(providerConfigToApi(saved)));
  } catch (error) {
    return platformError(error);
  }
}

export async function handleGetPlatformUsage(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewPlatformUsage");
  if (denied) return denied;

  try {
    const analytics = await withTenantContext(config, auth.claims, (db) =>
      getUsageAnalytics(db, organizationIdFromClaims(auth.claims))
    );
    return jsonResponse(envelope(usageAnalyticsToApi(analytics)));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleListFeatureEnablements(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "managePlatformFeatures");
  if (denied) return denied;

  const schoolId = new URL(req.url).searchParams.get("schoolId") ?? undefined;
  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listFeatureEnablements(db, organizationIdFromClaims(auth.claims), schoolId)
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleSetFeatureEnablement(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "managePlatformFeatures");
  if (denied) return denied;

  const body = await readJson<{ schoolId: string; featureKey: string; enabled: boolean }>(req);
  if (!body?.schoolId || !body.featureKey) {
    return errorEnvelope("VALIDATION_ERROR", "schoolId and featureKey required", 422);
  }

  try {
    await withTenantContext(config, auth.claims, async (db) => {
      await setFeatureEnablement(
        db,
        organizationIdFromClaims(auth.claims),
        body.schoolId,
        body.featureKey,
        body.enabled ?? true,
        auth.claims.sub,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        schoolCompletionAudit.featureEnablementUpdated(body.featureKey),
        req,
      );
    });
    return jsonResponse(envelope({ updated: true }));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleRotateVaultSecret(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "managePlatformVault");
  if (denied) return denied;

  const body = await readJson<{ secretId: string; newCredential: string }>(req);
  if (!body?.secretId || !body.newCredential) {
    return errorEnvelope("VALIDATION_ERROR", "secretId and newCredential required", 422);
  }

  try {
    const secret = await withPlatformContext(
      config,
      auth.claims,
      (db) => rotateSecret(db, body.secretId, body.newCredential, auth.claims.sub),
    );
    // See handleUpsertPlatformProvider for why the audit emission is a
    // separate `withTenantContext` call (audit tables are tenant-scoped,
    // the rotate above is platform-scoped — two roles, two transactions).
    await withTenantContext(config, auth.claims, (db) =>
      emitMutationAudit(db, auth.claims, schoolCompletionAudit.vaultSecretRotated(body.secretId), req)
    );
    return jsonResponse(envelope(vaultSecretToApi(secret)));
  } catch (error) {
    return platformError(error);
  }
}

export async function handleCheckVaultHealth(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "managePlatformVault");
  if (denied) return denied;

  const secretId = new URL(req.url).searchParams.get("secretId");
  if (!secretId) return errorEnvelope("VALIDATION_ERROR", "secretId required", 422);

  try {
    const health = await withPlatformContext(config, auth.claims, (db) => checkSecretHealth(db, secretId));
    return jsonResponse(envelope(health));
  } catch (error) {
    return platformError(error);
  }
}
