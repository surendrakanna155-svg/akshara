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
import { emitMutationAudit, intelligenceAudit } from "../audit/mutation_audit_catalog.ts";
import {
  buildStudentSuccessDashboard,
  computeAndStoreStudentSuccessSnapshots,
  getStudentSuccessByStudent,
  listImprovementTracking,
  listInterventionEffectiveness,
  listLatestStudentSuccessSnapshots,
  studentSuccessSnapshotToApi,
} from "./student_success_service.ts";

function requireStudentSuccessRead(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requireAnyPermission(claims, ["viewStudentSuccessIntelligence", "viewStudentRisk", "viewAnalytics"]) ??
    requireSchoolOperationalScope(claims);
}

function requireStudentSuccessWrite(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "generateIntelligence") ??
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
  const message = error instanceof Error ? error.message : "Student success operation failed";
  return errorEnvelope("STUDENT_SUCCESS_ERROR", message, 500);
}

export async function handleStudentSuccessDashboard(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireStudentSuccessRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const dashboard = await runTenant(config, auth.claims, (db) =>
      buildStudentSuccessDashboard(db, orgId, schoolId)
    );
    return jsonResponse(envelope({ dashboard }));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleStudentSuccessPredictions(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireStudentSuccessRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const className = url.searchParams.get("className") ?? undefined;
  const minDropoutRisk = url.searchParams.has("minDropoutRisk")
    ? Number(url.searchParams.get("minDropoutRisk"))
    : undefined;

  try {
    const items = await runTenant(config, auth.claims, (db) =>
      listLatestStudentSuccessSnapshots(db, orgId, schoolId, {
        className,
        minDropoutRisk,
      })
    );
    return jsonResponse(envelope({
      items: items.map(studentSuccessSnapshotToApi),
    }));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleGetStudentSuccess(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireStudentSuccessRead(auth.claims);
  if (denied) return denied;

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      getStudentSuccessByStudent(db, studentId)
    );
    if (!row) return errorEnvelope("NOT_FOUND", "Student success snapshot not found", 404);
    return jsonResponse(envelope(studentSuccessSnapshotToApi(row)));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleComputeStudentSuccess(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireStudentSuccessWrite(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const stored = await runTenant(config, auth.claims, async (db) => {
      const rows = await computeAndStoreStudentSuccessSnapshots(db, orgId, schoolId);
      await emitMutationAudit(
        db,
        auth.claims,
        intelligenceAudit.studentSuccessComputed(schoolId, rows.length),
        req,
      );
      return rows;
    });
    return jsonResponse(envelope({
      computed: stored.length,
      items: stored.map(studentSuccessSnapshotToApi),
    }), { status: 201 });
  } catch (error) {
    return handleError(error);
  }
}

export async function handleStudentSuccessImprovements(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireStudentSuccessRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const className = url.searchParams.get("className") ?? undefined;

  try {
    const items = await runTenant(config, auth.claims, (db) =>
      listImprovementTracking(db, orgId, schoolId, className)
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleStudentSuccessInterventions(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireStudentSuccessRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const studentId = url.searchParams.get("studentId") ?? undefined;

  try {
    const items = await runTenant(config, auth.claims, (db) =>
      listInterventionEffectiveness(db, orgId, schoolId, studentId)
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    return handleError(error);
  }
}
