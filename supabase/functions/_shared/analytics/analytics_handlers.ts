import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { computeAnalyticsBundle } from "./analytics_repository.ts";

function requireAnalyticsView(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewAnalytics") ??
    requireSchoolOperationalScope(claims);
}

function requireSchoolHealthView(claims: Parameters<typeof requirePermission>[0]): Response | null {
  // School-health/principal views are allowed for EITHER permission (viewSchoolHealth
  // OR viewAnalytics), then must hold school scope. NB: chaining the two permission
  // checks with `??` would have ANDed them (requirePermission returns null on
  // success, so a held first permission fell through to require the second too) —
  // that denied legitimate viewAnalytics-only principals. Evaluate the OR explicitly.
  const denied = requirePermission(claims, "viewSchoolHealth");
  if (denied && requirePermission(claims, "viewAnalytics")) return denied;
  return requireSchoolOperationalScope(claims);
}

async function loadBundle(req: Request, config: AppConfig, auth: Awaited<ReturnType<typeof authenticateRequest>> & { ok: true }) {
  return await withTenantContext(config, auth.claims, async (db) => {
    return await computeAnalyticsBundle(
      db,
      organizationIdFromClaims(auth.claims),
      schoolIdFromClaims(auth.claims),
    );
  });
}

export async function handleAnalyticsDashboard(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnalyticsView(auth.claims);
  if (denied) return denied;
  try {
    const bundle = await loadBundle(req, config, auth);
    return jsonResponse(envelope(bundle.dashboard));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleAnalyticsTrends(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnalyticsView(auth.claims);
  if (denied) return denied;
  try {
    const bundle = await loadBundle(req, config, auth);
    return jsonResponse(envelope({ series: bundle.trends }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleAnalyticsRisks(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnalyticsView(auth.claims);
  if (denied) return denied;
  try {
    const bundle = await loadBundle(req, config, auth);
    return jsonResponse(envelope({ items: bundle.risks, anomalies: bundle.anomalies }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleAnalyticsHealth(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSchoolHealthView(auth.claims);
  if (denied) return denied;
  try {
    const bundle = await loadBundle(req, config, auth);
    return jsonResponse(envelope(bundle.health));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleAnalyticsRecommendations(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnalyticsView(auth.claims);
  if (denied) return denied;
  try {
    const bundle = await loadBundle(req, config, auth);
    return jsonResponse(envelope({ items: bundle.recommendations, readOnly: true }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handlePrincipalSummary(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSchoolHealthView(auth.claims);
  if (denied) return denied;
  try {
    const bundle = await loadBundle(req, config, auth);
    return jsonResponse(envelope(bundle.principalSummary));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleWeeklyBriefing(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnalyticsView(auth.claims);
  if (denied) return denied;
  try {
    const bundle = await loadBundle(req, config, auth);
    return jsonResponse(envelope(bundle.weeklyBriefing));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}
