import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import {
  buildPrintableReport,
  generateParentAcademicSummary,
  getParentAcademicSummary,
  getParentActivationStats,
  parentSummaryToApi,
} from "./parent_experience_service.ts";

export async function routeParentExperience(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/parent/experience/")) return null;

  if (path === "/parent/experience/summary" && method === "GET") {
    return handleGetParentSummary(req, config);
  }
  if (path === "/parent/experience/summary/refresh" && method === "POST") {
    return handleRefreshParentSummary(req, config);
  }
  if (path === "/parent/experience/report/printable" && method === "GET") {
    return handleGetPrintableReport(req, config);
  }
  if (path === "/parent/experience/activation" && method === "GET") {
    return handleGetParentActivation(req, config);
  }

  // This sub-router does NOT own every /parent/experience/* path — e.g.
  // /parent/experience/acknowledge and /parent/experience/hub are handled by
  // routeParent (registered after this one). Return null so the router chain
  // continues; the global handler emits the 404 if nobody claims the path.
  return null;
}

async function handleGetParentSummary(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewParentAcademicSummary");
  if (denied) return denied;

  const studentId = new URL(req.url).searchParams.get("studentId");
  if (!studentId) return errorEnvelope("VALIDATION_ERROR", "studentId required", 422);

  try {
    const summary = await withTenantContext(config, auth.claims, async (db) => {
      const existing = await getParentAcademicSummary(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        studentId,
      );
      if (existing) return existing;
      return await generateParentAcademicSummary(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        studentId,
      );
    });
    return jsonResponse(envelope(parentSummaryToApi(summary)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", String(error), 500);
  }
}

async function handleRefreshParentSummary(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewParentAcademicSummary");
  if (denied) return denied;

  const studentId = new URL(req.url).searchParams.get("studentId");
  if (!studentId) return errorEnvelope("VALIDATION_ERROR", "studentId required", 422);

  try {
    const summary = await withTenantContext(config, auth.claims, (db) =>
      generateParentAcademicSummary(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        studentId,
      )
    );
    return jsonResponse(envelope(parentSummaryToApi(summary)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", String(error), 500);
  }
}

async function handleGetPrintableReport(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewParentAcademicSummary");
  if (denied) return denied;

  const studentId = new URL(req.url).searchParams.get("studentId");
  if (!studentId) return errorEnvelope("VALIDATION_ERROR", "studentId required", 422);

  try {
    const report = await withTenantContext(config, auth.claims, async (db) => {
      const summary = await getParentAcademicSummary(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        studentId,
      ) ?? await generateParentAcademicSummary(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        studentId,
      );
      return buildPrintableReport(parentSummaryToApi(summary));
    });
    return jsonResponse(envelope({ report }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", String(error), 500);
  }
}

async function handleGetParentActivation(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewPilotDashboard");
  if (denied) return denied;

  try {
    const stats = await withTenantContext(config, auth.claims, (db) =>
      getParentActivationStats(db, schoolIdFromClaims(auth.claims))
    );
    return jsonResponse(envelope(stats));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", String(error), 500);
  }
}
