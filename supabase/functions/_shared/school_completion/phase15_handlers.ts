import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireAnyPermission,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { getParentActivationStats } from "../parent_experience/parent_experience_service.ts";
import {
  buildAnalyticsDelivery,
  buildCampaignAnalytics,
  buildCommunicationAnalyticsSummary,
  buildCommunicationEffectiveness,
  buildParentAdoptionAnalytics,
  buildParentEngagementAnalytics,
  communicationAnalyticsSummaryToApi,
} from "./communication_analytics_service.ts";

function tenantError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  return errorEnvelope("INTERNAL_ERROR", String(error), 500);
}

function requireAnalyticsRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requireAnyPermission(claims, ["viewCommunicationAnalytics", "viewCommunicationDelivery"]) ??
    requireSchoolOperationalScope(claims);
}

export async function handleGetCommunicationAnalyticsSummary(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnalyticsRead(auth.claims);
  if (denied) return denied;

  try {
    const summary = await withTenantContext(config, auth.claims, (db) =>
      buildCommunicationAnalyticsSummary(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      )
    );
    return jsonResponse(envelope(communicationAnalyticsSummaryToApi(summary)));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetCampaignAnalytics(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnalyticsRead(auth.claims);
  if (denied) return denied;

  try {
    const analytics = await withTenantContext(config, auth.claims, (db) =>
      buildCampaignAnalytics(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      )
    );
    return jsonResponse(envelope(analytics));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetAnalyticsDelivery(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnalyticsRead(auth.claims);
  if (denied) return denied;

  try {
    const analytics = await withTenantContext(config, auth.claims, (db) =>
      buildAnalyticsDelivery(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      )
    );
    return jsonResponse(envelope(analytics));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetCommunicationEffectiveness(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnalyticsRead(auth.claims);
  if (denied) return denied;

  try {
    const analytics = await withTenantContext(config, auth.claims, (db) =>
      buildCommunicationEffectiveness(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      )
    );
    return jsonResponse(envelope(analytics));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetParentEngagementAnalytics(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnalyticsRead(auth.claims);
  if (denied) return denied;

  try {
    const analytics = await withTenantContext(config, auth.claims, (db) =>
      buildParentEngagementAnalytics(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      )
    );
    return jsonResponse(envelope(analytics));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetParentAdoptionAnalytics(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnalyticsRead(auth.claims);
  if (denied) return denied;

  try {
    const analytics = await withTenantContext(config, auth.claims, (db) =>
      buildParentAdoptionAnalytics(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      )
    );
    return jsonResponse(envelope(analytics));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetParentActivationDashboard(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnalyticsRead(auth.claims);
  if (denied) return denied;

  try {
    const stats = await withTenantContext(config, auth.claims, (db) =>
      getParentActivationStats(db, schoolIdFromClaims(auth.claims))
    );
    return jsonResponse(envelope(stats));
  } catch (error) {
    return tenantError(error);
  }
}
