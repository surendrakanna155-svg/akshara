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
import { academicAudit, emitMutationAudit } from "../audit/mutation_audit_catalog.ts";
import {
  AcademicTransitionNotFoundError,
  AcademicTransitionValidationError,
  createTransitionPreviewJob,
  executeTransitionJob,
  getTransitionJob,
  suggestClassMappings,
  type ClassMappingRule,
} from "./academic_transition_repository.ts";

function requireTransitionView(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewSis") ??
    requireSchoolOperationalScope(claims);
}

function requireTransitionManage(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageSis") ??
    requireSchoolOperationalScope(claims);
}

function handleTransitionError(error: unknown, fallback: string): Response {
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  if (error instanceof AcademicTransitionNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof AcademicTransitionValidationError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  console.error(fallback, error);
  return errorEnvelope("INTERNAL_ERROR", fallback, 500);
}

function transitionToApi(row: NonNullable<Awaited<ReturnType<typeof getTransitionJob>>>) {
  return {
    id: row.id,
    sourceYearId: row.source_year_id,
    targetYearId: row.target_year_id,
    status: row.status,
    classMapping: row.class_mapping,
    previewReport: row.preview_report,
    executionReport: row.execution_report,
    promotedCount: row.promoted_count,
    skippedCount: row.skipped_count,
    failedCount: row.failed_count,
    setTargetCurrent: row.set_target_current,
    archiveSourceYear: row.archive_source_year,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    executedAt: row.executed_at,
  };
}

function parseClassMappings(body: Record<string, unknown>): ClassMappingRule[] {
  const raw = body.classMapping ?? body.class_mapping;
  if (!Array.isArray(raw)) return [];
  return raw.map((item) => {
    const row = item as Record<string, unknown>;
    return {
      sourceClassName: String(row.sourceClassName ?? row.source_class_name ?? "").trim(),
      targetClassName: String(row.targetClassName ?? row.target_class_name ?? "").trim(),
      keepSection: row.keepSection !== false && row.keep_section !== false,
      action: (row.action as ClassMappingRule["action"]) ?? "promote",
    };
  }).filter((m) => m.sourceClassName.length > 0);
}

export async function handleSuggestTransitionMappings(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTransitionView(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const sourceYearId = url.searchParams.get("sourceYearId") ?? url.searchParams.get("source_year_id");
  const targetYearId = url.searchParams.get("targetYearId") ?? url.searchParams.get("target_year_id");
  if (!sourceYearId || !targetYearId) {
    return errorEnvelope("VALIDATION_ERROR", "sourceYearId and targetYearId are required", 422);
  }

  try {
    const mappings = await withTenantContext(config, auth.claims, async (db) =>
      await suggestClassMappings(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        sourceYearId,
        targetYearId,
      ));
    return jsonResponse(envelope({ items: mappings }));
  } catch (error) {
    return handleTransitionError(error, "Failed to suggest mappings");
  }
}

export async function handlePreviewTransition(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTransitionManage(auth.claims);
  if (denied) return denied;

  let body: Record<string, unknown> = {};
  try {
    body = (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const sourceYearId = String(body.sourceYearId ?? body.source_year_id ?? "").trim();
  const targetYearId = String(body.targetYearId ?? body.target_year_id ?? "").trim();
  if (!sourceYearId || !targetYearId) {
    return errorEnvelope("VALIDATION_ERROR", "sourceYearId and targetYearId are required", 422);
  }

  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await createTransitionPreviewJob(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        auth.claims.sub,
        {
          sourceYearId,
          targetYearId,
          classMappings: parseClassMappings(body),
          setTargetCurrent: body.setTargetCurrent !== false && body.set_target_current !== false,
          archiveSourceYear: body.archiveSourceYear !== false && body.archive_source_year !== false,
        },
      ));

    return jsonResponse(envelope({
      job: transitionToApi(result.job),
      preview: result.preview,
    }), { status: 201 });
  } catch (error) {
    return handleTransitionError(error, "Transition preview failed");
  }
}

export async function handleExecuteTransition(
  req: Request,
  config: AppConfig,
  transitionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTransitionManage(auth.claims);
  if (denied) return denied;

  try {
    const job = await withTenantContext(config, auth.claims, async (db) => {
      const executed = await executeTransitionJob(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        transitionId,
        auth.claims.sub,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        academicAudit.yearTransitionExecuted(transitionId, {
          promoted: executed.promoted_count,
          skipped: executed.skipped_count,
          failed: executed.failed_count,
        }),
        req,
      );
      return executed;
    });
    return jsonResponse(envelope({ job: transitionToApi(job) }));
  } catch (error) {
    return handleTransitionError(error, "Transition execute failed");
  }
}

export async function handleGetTransition(
  req: Request,
  config: AppConfig,
  transitionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTransitionView(auth.claims);
  if (denied) return denied;

  try {
    const job = await withTenantContext(config, auth.claims, async (db) =>
      await getTransitionJob(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        transitionId,
      ));
    if (!job) return errorEnvelope("NOT_FOUND", "Transition not found", 404);
    return jsonResponse(envelope({ job: transitionToApi(job) }));
  } catch (error) {
    return handleTransitionError(error, "Failed to load transition");
  }
}
