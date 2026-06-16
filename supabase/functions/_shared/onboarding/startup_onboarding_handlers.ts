import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import {
  getStartupOnboarding,
  goLiveStartupOnboarding,
  provisionToApi,
  rowToApi,
  type StartupOnboardingPayload,
  upsertStartupOnboarding,
} from "./startup_onboarding_repository.ts";
import { requireOnboardingView } from "./onboarding_handlers.ts";

function defaultStartupApi() {
  return rowToApi({
    id: "",
    organization_id: "",
    school_id: "",
    current_step: "schoolProfile",
    school_name: "",
    board: "",
    curriculum: "CBSE",
    address: "",
    contact_phone: "",
    contact_email: "",
    academic_year: "2026-27",
    classes: [],
    sections: [],
    fee_model: "",
    fee_categories: [],
    logo_url: "",
    theme_primary: "#1565C0",
    theme_secondary: "#42A5F5",
    branding_preferences: {},
    default_language: "en",
    modules_enabled: ["sis", "finance", "attendance"],
    is_live: false,
    go_live_at: null,
    updated_at: new Date().toISOString(),
  });
}

export async function handleGetStartupOnboarding(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOnboardingView(auth.claims);
  if (denied) return denied;

  try {
    const row = await withTenantContext(config, auth.claims, async (db) =>
      await getStartupOnboarding(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
      )
    );
    return jsonResponse(envelope(row ? rowToApi(row) : defaultStartupApi()));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("STARTUP_ONBOARDING_ERROR", String(error), 500);
  }
}

export async function handleSaveStartupOnboarding(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageOnboarding") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<StartupOnboardingPayload>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Request body required", 422);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) =>
      await upsertStartupOnboarding(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        auth.claims.sub,
        body,
      )
    );
    return jsonResponse(envelope(rowToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("STARTUP_ONBOARDING_ERROR", String(error), 500);
  }
}

export async function handleGoLiveStartupOnboarding(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageOnboarding") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await goLiveStartupOnboarding(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        auth.claims.sub,
      )
    );
    if (result.errors.length > 0) {
      return jsonResponse(
        envelope({
          ...(result.row ? rowToApi(result.row) : defaultStartupApi()),
          validationErrors: result.errors,
          isLive: false,
        }),
        { status: 422 },
      );
    }
    return jsonResponse(envelope({
      ...rowToApi(result.row!),
      validationErrors: [],
      provision: result.provision ? provisionToApi(result.provision) : undefined,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("STARTUP_ONBOARDING_ERROR", String(error), 500);
  }
}
