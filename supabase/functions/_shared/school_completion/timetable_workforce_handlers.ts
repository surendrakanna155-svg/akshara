import type { AppConfig } from "../config.ts";
import { recordServerAuditEvent } from "../audit/audit_repository.ts";
import { academicAudit, emitMutationAudit } from "../audit/mutation_audit_catalog.ts";
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
import { applyTimetableOptimization } from "./timetable_optimization_service.ts";
import {
  assignSubstitute,
  getSubstituteCoverage,
  getTeacherReassignmentOptions,
  reassignTeacherBulk,
  SubstitutionValidationError,
  TimetableClashError,
  TimetablePublishedError,
  WorkforceValidationError,
} from "./timetable_workforce_service.ts";

// P0-2 (gap-remediation wave) — the 5 backend routes SubstituteManagerScreen,
// TeacherReassignmentScreen, and TimetableOptimizationScreen have been calling
// since they shipped. Reads gate on viewTimetableOptimization, writes on
// manageAcademicTimetable — matching route_guards.dart (RouteNames.
// substituteManager / teacherReassignment → manageAcademicTimetable;
// RouteNames.timetableOptimization → viewTimetableOptimization) and the
// permissions already granted to superAdmin/schoolAdmin/principal for both
// slugs (20260615050000 + 20260624210000).

function requireOptimizationView(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewTimetableOptimization") ??
    requireSchoolOperationalScope(claims);
}

function requireTimetableManage(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageAcademicTimetable") ??
    requireSchoolOperationalScope(claims);
}

function workforceError(error: unknown): Response {
  if (error instanceof WorkforceValidationError) {
    return errorEnvelope(error.code, error.message, error.httpStatus);
  }
  if (error instanceof SubstitutionValidationError) {
    return errorEnvelope(error.code, error.message, error.httpStatus);
  }
  if (error instanceof TimetablePublishedError) {
    return errorEnvelope("TIMETABLE_PUBLISHED", error.message, 409);
  }
  if (error instanceof TimetableClashError) {
    return errorEnvelope("TIMETABLE_CLASH", error.message, 409);
  }
  if (error instanceof Error && error.message.toLowerCase().includes("not found")) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  return errorEnvelope("INTERNAL_ERROR", String(error), 500);
}

export async function handleGetSubstituteCoverage(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOptimizationView(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const academicYearId = url.searchParams.get("academicYearId")?.trim();
  if (!academicYearId) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId query param required", 422);
  }
  const dayOfWeek = url.searchParams.get("dayOfWeek")?.trim() || undefined;

  try {
    const data = await withTenantContext(config, auth.claims, (db) =>
      getSubstituteCoverage(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        academicYearId,
        dayOfWeek,
      )
    );
    return jsonResponse(envelope(data));
  } catch (error) {
    return workforceError(error);
  }
}

export async function handleAssignSubstitute(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableManage(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    slotId?: string;
    substituteTeacherId?: string;
    notifySubstituteTeacher?: boolean;
    notifyClassIncharge?: boolean;
    notifyStudents?: boolean;
  }>(req);
  if (!body?.slotId?.trim() || !body.substituteTeacherId?.trim()) {
    return errorEnvelope("VALIDATION_ERROR", "slotId and substituteTeacherId required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const assigned = await assignSubstitute(
        db,
        orgId,
        schoolId,
        {
          slotId: body.slotId!.trim(),
          substituteTeacherId: body.substituteTeacherId!.trim(),
          notifySubstituteTeacher: body.notifySubstituteTeacher ?? false,
          notifyClassIncharge: body.notifyClassIncharge ?? false,
          notifyStudents: body.notifyStudents ?? false,
        },
        auth.claims.sub,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        academicAudit.timetableSubstituted(assigned.assignmentId, "assigned", {
          slotId: assigned.slotId,
          substituteTeacherId: body.substituteTeacherId,
          source: "substitute_teacher_wizard",
        }),
        req,
      );
      return assigned;
    });
    return jsonResponse(envelope(result), { status: 201 });
  } catch (error) {
    return workforceError(error);
  }
}

export async function handleGetTeacherReassignmentOptions(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireOptimizationView(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const academicYearId = url.searchParams.get("academicYearId")?.trim();
  if (!academicYearId) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId query param required", 422);
  }
  const sourceTeacherId = url.searchParams.get("sourceTeacherId")?.trim() || undefined;

  try {
    const data = await withTenantContext(config, auth.claims, (db) =>
      getTeacherReassignmentOptions(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        academicYearId,
        sourceTeacherId,
      )
    );
    return jsonResponse(envelope(data));
  } catch (error) {
    return workforceError(error);
  }
}

export async function handleReassignTeacher(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableManage(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    academicYearId?: string;
    sourceTeacherId?: string;
    targetTeacherId?: string;
    slotIds?: string[];
    notifySourceTeacher?: boolean;
    notifyTargetTeacher?: boolean;
    notifyStudents?: boolean;
  }>(req);
  if (
    !body?.academicYearId?.trim() ||
    !body.sourceTeacherId?.trim() ||
    !body.targetTeacherId?.trim() ||
    !Array.isArray(body.slotIds) ||
    body.slotIds.length === 0
  ) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "academicYearId, sourceTeacherId, targetTeacherId, and a non-empty slotIds array are required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const reassigned = await reassignTeacherBulk(db, orgId, schoolId, {
        academicYearId: body.academicYearId!.trim(),
        sourceTeacherId: body.sourceTeacherId!.trim(),
        targetTeacherId: body.targetTeacherId!.trim(),
        slotIds: body.slotIds!,
        notifySourceTeacher: body.notifySourceTeacher ?? false,
        notifyTargetTeacher: body.notifyTargetTeacher ?? false,
        notifyStudents: body.notifyStudents ?? false,
      });
      await recordServerAuditEvent(db, auth.claims, {
        eventType: "schoolTeacherPeriodsReassigned",
        category: "workflow",
        entityType: "academic_timetable_period",
        entityId: reassigned.reassignmentId,
        metadata: {
          academicYearId: body.academicYearId,
          sourceTeacherId: reassigned.sourceTeacherId,
          targetTeacherId: reassigned.targetTeacherId,
          updatedSlotIds: reassigned.updatedSlotIds,
        },
      }, req);
      return reassigned;
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    return workforceError(error);
  }
}

export async function handleApplyTimetableOptimization(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableManage(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    academicYearId?: string;
    recommendationIds?: string[];
    applyAll?: boolean;
  }>(req);
  if (!body?.academicYearId?.trim()) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const academicYearId = body.academicYearId.trim();

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const applied = await applyTimetableOptimization(
        db,
        orgId,
        schoolId,
        academicYearId,
        Array.isArray(body.recommendationIds) ? body.recommendationIds : [],
        body.applyAll ?? false,
      );
      await recordServerAuditEvent(db, auth.claims, {
        eventType: "schoolTimetableOptimizationApplied",
        category: "workflow",
        entityType: "academic_timetable",
        entityId: academicYearId,
        metadata: {
          academicYearId,
          appliedRecommendationIds: applied.appliedRecommendationIds,
          appliedCount: applied.appliedCount,
        },
      }, req);
      return applied;
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    return workforceError(error);
  }
}
