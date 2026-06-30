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
import {
  buildAcademicForecast,
  buildExamAnalytics,
  buildRankMovement,
  buildResultIntelligence,
  buildSubjectPerformance,
  detectWeakChapters,
  type ExamIntelligenceFilters,
} from "./exam_intelligence_service.ts";

function requireExamIntelRead(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requireAnyPermission(claims, ["viewExamIntelligence", "viewEducation", "viewAnalytics"]) ??
    requireSchoolOperationalScope(claims);
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function handleError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  const message = error instanceof Error ? error.message : "Exam intelligence operation failed";
  return errorEnvelope("EXAM_INTELLIGENCE_ERROR", message, 500);
}

function filtersFromUrl(url: URL): ExamIntelligenceFilters {
  return {
    className: url.searchParams.get("className") ?? undefined,
    subjectName: url.searchParams.get("subjectName") ?? undefined,
    examType: url.searchParams.get("examType") ?? undefined,
  };
}

export async function handleExamAnalytics(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireExamIntelRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const filters = filtersFromUrl(new URL(req.url));

  try {
    const analytics = await runTenant(config, auth.claims, (db) =>
      buildExamAnalytics(db, orgId, schoolId, filters)
    );
    return jsonResponse(envelope({ analytics }));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleExamSubjectPerformance(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireExamIntelRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const filters = filtersFromUrl(new URL(req.url));

  try {
    const items = await runTenant(config, auth.claims, (db) =>
      buildSubjectPerformance(db, orgId, schoolId, filters)
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleExamWeakChapters(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireExamIntelRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const filters = filtersFromUrl(new URL(req.url));

  try {
    const items = await runTenant(config, auth.claims, (db) =>
      detectWeakChapters(db, orgId, schoolId, filters)
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleExamResultIntelligence(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireExamIntelRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const filters = filtersFromUrl(new URL(req.url));

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      buildResultIntelligence(db, orgId, schoolId, filters)
    );
    return jsonResponse(envelope({ result }));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleExamForecast(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireExamIntelRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const filters = filtersFromUrl(new URL(req.url));

  try {
    const forecast = await runTenant(config, auth.claims, (db) =>
      buildAcademicForecast(db, orgId, schoolId, filters)
    );
    return jsonResponse(envelope({ forecast }));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleExamRankMovement(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireExamIntelRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const filters = filtersFromUrl(new URL(req.url));

  try {
    const items = await runTenant(config, auth.claims, (db) =>
      buildRankMovement(db, orgId, schoolId, filters)
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    return handleError(error);
  }
}
