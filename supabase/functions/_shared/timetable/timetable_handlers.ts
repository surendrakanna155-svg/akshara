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
import { buildSchedulingRecommendations } from "./timetable_scheduling_advisor.ts";
import {
  generateTimetablesForYear,
  getSchoolConflicts,
  getSchoolWorkload,
  getTimetable,
  getTimetableSummary,
  listTimetablePeriods,
  listTimetables,
  moveTimetablePeriod,
  publishTimetableById,
  reassignTimetablePeriodTeacher,
  TimetableClashError,
  TimetableNotFoundError,
  TimetablePublishedError,
  validateTimetableById,
} from "./timetable_repository.ts";
import {
  createSubstitution,
  deleteSubstitution,
  listSubstitutions,
  listTeachersOnLeave,
  SubstitutionValidationError,
} from "./substitution_repository.ts";
import { buildTeacherWorkloadRollup } from "./workload_rollup.ts";

function requireTimetableView(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewAcademicTimetable") ??
    requireSchoolOperationalScope(claims);
}

function requireTimetableManage(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageAcademicTimetable") ??
    requireSchoolOperationalScope(claims);
}

function requireTimetablePublish(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "publishAcademicTimetable") ??
    requireSchoolOperationalScope(claims);
}

function requireSubstitutionManage(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "manageTimetableSubstitution") ??
    requireSchoolOperationalScope(claims);
}

function timetableToApi(row: Awaited<ReturnType<typeof listTimetables>>[number]) {
  return {
    id: row.id,
    academicYearId: row.academic_year_id,
    sectionId: row.section_id,
    status: row.status,
    version: row.version,
    periodsPerDay: row.periods_per_day,
    daysPerWeek: row.days_per_week,
    validationSummary: row.validation_summary,
    publishedAt: row.published_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function periodToApi(row: Awaited<ReturnType<typeof listTimetablePeriods>>[number]) {
  return {
    id: row.id,
    timetableId: row.timetable_id,
    dayOfWeek: row.day_of_week,
    periodNumber: row.period_number,
    subjectLabel: row.subject_label,
    teacherId: row.teacher_id,
    teacherAssignmentId: row.teacher_assignment_id,
    roomLabel: row.room_label,
  };
}

export async function handleTimetableSummary(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableView(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const academicYearId = url.searchParams.get("academicYearId")?.trim();
  if (!academicYearId) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId query param required", 422);
  }

  try {
    const summary = await withTenantContext(config, auth.claims, async (db) => {
      return await getTimetableSummary(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        academicYearId,
      );
    });
    return jsonResponse(envelope(summary));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleTimetableWorkload(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableView(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const academicYearId = url.searchParams.get("academicYearId")?.trim();
  if (!academicYearId) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId query param required", 422);
  }

  try {
    const items = await withTenantContext(config, auth.claims, async (db) => {
      return await getSchoolWorkload(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        academicYearId,
      );
    });
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

/**
 * Roadmap gap #9 — unified per-teacher workload rollup. Unlike /workload (a flat
 * scheduled-period count with an empty sections[]), this returns the ONE
 * reconciled rollup: periodCount + populated sections[] + subjectIds +
 * over/under/balanced status per teacher, plus a school aggregate. Principal
 * scope, single school. Read-only, back-compat sibling of /workload.
 */
export async function handleTimetableWorkloadRollup(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableView(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const academicYearId = url.searchParams.get("academicYearId")?.trim();
  if (!academicYearId) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId query param required", 422);
  }

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      return await buildTeacherWorkloadRollup(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        academicYearId,
      );
    });
    return jsonResponse(envelope({ teachers: result.teachers, summary: result.summary }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleTimetableConflicts(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableView(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const academicYearId = url.searchParams.get("academicYearId")?.trim();
  if (!academicYearId) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId query param required", 422);
  }

  try {
    const data = await withTenantContext(config, auth.claims, async (db) => {
      const orgId = organizationIdFromClaims(auth.claims);
      const schoolId = schoolIdFromClaims(auth.claims);
      const conflicts = await getSchoolConflicts(db, orgId, schoolId, academicYearId);
      const workload = await getSchoolWorkload(db, orgId, schoolId, academicYearId);
      const summary = await getTimetableSummary(db, orgId, schoolId, academicYearId);
      const validation = {
        valid: conflicts.length === 0 && summary.gapCount === 0,
        conflictCount: conflicts.length,
        gapCount: summary.gapCount,
        conflicts,
        gaps: [],
      };
      const recommendations = buildSchedulingRecommendations({ validation, workload, summary });
      return { conflicts, recommendations };
    });
    return jsonResponse(envelope(data));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleListTimetables(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableView(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const academicYearId = url.searchParams.get("academicYearId")?.trim();

  try {
    const items = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await listTimetables(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        academicYearId,
      );
      return rows.map(timetableToApi);
    });
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleGetTimetable(
  req: Request,
  config: AppConfig,
  timetableId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableView(auth.claims);
  if (denied) return denied;

  try {
    const data = await withTenantContext(config, auth.claims, async (db) => {
      const orgId = organizationIdFromClaims(auth.claims);
      const schoolId = schoolIdFromClaims(auth.claims);
      const timetable = await getTimetable(db, orgId, schoolId, timetableId);
      const periods = await listTimetablePeriods(db, orgId, schoolId, timetableId);
      return {
        timetable: timetableToApi(timetable),
        periods: periods.map(periodToApi),
      };
    });
    return jsonResponse(envelope(data));
  } catch (error) {
    if (error instanceof TimetableNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleGenerateTimetables(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableManage(auth.claims);
  if (denied) return denied;

  const body = (await readJson<{
    academicYearId?: string;
    sectionId?: string;
    periodsPerDay?: number;
    daysPerWeek?: number;
  }>(req)) ?? {};
  if (!body.academicYearId?.trim()) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId required", 422);
  }
  const academicYearId = body.academicYearId.trim();
  const sectionId = body.sectionId?.trim();

  try {
    const items = await withTenantContext(config, auth.claims, async (db) => {
      const orgId = organizationIdFromClaims(auth.claims);
      const schoolId = schoolIdFromClaims(auth.claims);
      const created = await generateTimetablesForYear(
        db,
        orgId,
        schoolId,
        academicYearId,
        auth.claims.sub,
        {
          sectionId,
          periodsPerDay: body.periodsPerDay,
          daysPerWeek: body.daysPerWeek,
        },
      );
      for (const timetable of created) {
        await recordServerAuditEvent(db, auth.claims, {
          eventType: "academicTimetableGenerated",
          category: "workflow",
          entityType: "academic_timetable",
          entityId: timetable.id,
          metadata: {
            academicYearId,
            sectionId: timetable.section_id,
            version: timetable.version,
          },
        }, req);
      }
      return created.map(timetableToApi);
    });
    return jsonResponse(envelope({ items }), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleValidateTimetable(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableManage(auth.claims);
  if (denied) return denied;

  const body = (await readJson<{ timetableId?: string }>(req)) ?? {};
  if (!body.timetableId?.trim()) {
    return errorEnvelope("VALIDATION_ERROR", "timetableId required", 422);
  }
  const timetableId = body.timetableId.trim();

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      return await validateTimetableById(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        timetableId,
      );
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TimetableNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handlePublishTimetable(
  req: Request,
  config: AppConfig,
  timetableId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetablePublish(auth.claims);
  if (denied) return denied;

  try {
    const timetable = await withTenantContext(config, auth.claims, async (db) => {
      const orgId = organizationIdFromClaims(auth.claims);
      const schoolId = schoolIdFromClaims(auth.claims);
      const published = await publishTimetableById(db, orgId, schoolId, timetableId);
      await recordServerAuditEvent(db, auth.claims, {
        eventType: "academicTimetablePublished",
        category: "workflow",
        entityType: "academic_timetable",
        entityId: published.id,
        metadata: {
          academicYearId: published.academic_year_id,
          sectionId: published.section_id,
          version: published.version,
        },
      }, req);
      return published;
    });
    return jsonResponse(envelope({ timetable: timetableToApi(timetable) }));
  } catch (error) {
    if (error instanceof TimetableNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof Error && error.message.includes("validated")) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleMoveTimetablePeriod(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableManage(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    periodId: string;
    targetDayOfWeek: number;
    targetPeriodNumber: number;
    roomLabel?: string;
  }>(req);
  if (!body?.periodId || !body.targetDayOfWeek || !body.targetPeriodNumber) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "periodId, targetDayOfWeek, and targetPeriodNumber required",
      422,
    );
  }

  try {
    const moved = await withTenantContext(config, auth.claims, async (db) => {
      const result = await moveTimetablePeriod(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        body,
      );
      await recordServerAuditEvent(db, auth.claims, {
        eventType: "academicTimetablePeriodMoved",
        category: "workflow",
        entityType: "academic_timetable_period",
        entityId: result.periodId,
        metadata: {
          dayOfWeek: result.dayOfWeek,
          periodNumber: result.periodNumber,
          roomLabel: result.roomLabel,
        },
      }, req);
      return result;
    });
    return jsonResponse(envelope(moved));
  } catch (error) {
    if (error instanceof TimetablePublishedError) {
      return errorEnvelope("TIMETABLE_PUBLISHED", error.message, 409);
    }
    if (error instanceof TimetableClashError) {
      return errorEnvelope("TIMETABLE_CLASH", error.message, 409);
    }
    if (error instanceof Error && error.message.includes("not found")) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

/**
 * #4 — POST /academic/timetables/periods/reassign-teacher. Real UI: the
 * timetable editor's per-row "Change teacher" menu (`_reassign` →
 * `reassignPeriodTeacher`) called this path with no backend route registered
 * (only periods/move existed), so every reassignment 404'd. Mirrors
 * handleMoveTimetablePeriod's RBAC (manageAcademicTimetable + school scope),
 * validation shape, error mapping, and audit pattern — a distinct event name
 * (`academicTimetablePeriodTeacherReassigned`) so the two mutations are
 * separately auditable.
 */
export async function handleReassignPeriodTeacher(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableManage(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ periodId: string; teacherId: string }>(req);
  if (!body?.periodId || !body.teacherId) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "periodId and teacherId required",
      422,
    );
  }

  try {
    const reassigned = await withTenantContext(config, auth.claims, async (db) => {
      const result = await reassignTimetablePeriodTeacher(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        body,
      );
      await recordServerAuditEvent(db, auth.claims, {
        eventType: "academicTimetablePeriodTeacherReassigned",
        category: "workflow",
        entityType: "academic_timetable_period",
        entityId: result.id,
        metadata: {
          dayOfWeek: result.dayOfWeek,
          periodNumber: result.periodNumber,
          teacherId: result.teacherId,
        },
      }, req);
      return result;
    });
    return jsonResponse(envelope(reassigned));
  } catch (error) {
    if (error instanceof TimetablePublishedError) {
      return errorEnvelope("TIMETABLE_PUBLISHED", error.message, 409);
    }
    if (error instanceof TimetableClashError) {
      return errorEnvelope("TIMETABLE_CLASH", error.message, 409);
    }
    if (error instanceof Error && error.message.includes("not found")) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleCreateSubstitution(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSubstitutionManage(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    periodId?: string;
    subDate?: string;
    substituteTeacherId?: string;
    reason?: string;
  }>(req);
  if (!body?.periodId?.trim() || !body.subDate?.trim() || !body.substituteTeacherId?.trim()) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "periodId, subDate, and substituteTeacherId required",
      422,
    );
  }

  try {
    const sub = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createSubstitution(db, {
        orgId: organizationIdFromClaims(auth.claims),
        schoolId: schoolIdFromClaims(auth.claims),
        periodId: body.periodId!.trim(),
        subDate: body.subDate!.trim(),
        substituteTeacherId: body.substituteTeacherId!.trim(),
        reason: body.reason?.trim(),
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        academicAudit.timetableSubstituted(created.id, "assigned", {
          periodId: created.period_id,
          subDate: created.sub_date,
          substituteTeacherId: created.substitute_teacher_id,
        }),
        req,
      );
      return created;
    });
    return jsonResponse(envelope({ substitution: sub }), { status: 201 });
  } catch (error) {
    if (error instanceof SubstitutionValidationError) {
      return errorEnvelope(error.code, error.message, error.httpStatus);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleListSubstitutions(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableView(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const date = url.searchParams.get("date")?.trim();
  if (!date) {
    return errorEnvelope("VALIDATION_ERROR", "date query param required (YYYY-MM-DD)", 422);
  }

  try {
    const data = await withTenantContext(config, auth.claims, async (db) => {
      const orgId = organizationIdFromClaims(auth.claims);
      const schoolId = schoolIdFromClaims(auth.claims);
      const substitutions = await listSubstitutions(db, orgId, schoolId, { date });
      const onLeave = await listTeachersOnLeave(db, orgId, schoolId, date);
      return { date, substitutions, onLeave };
    });
    return jsonResponse(envelope(data));
  } catch (error) {
    if (error instanceof SubstitutionValidationError) {
      return errorEnvelope(error.code, error.message, error.httpStatus);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleSubstitutionCandidates(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTimetableView(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const date = url.searchParams.get("date")?.trim();
  if (!date) {
    return errorEnvelope("VALIDATION_ERROR", "date query param required (YYYY-MM-DD)", 422);
  }

  try {
    const data = await withTenantContext(config, auth.claims, async (db) => {
      const orgId = organizationIdFromClaims(auth.claims);
      const schoolId = schoolIdFromClaims(auth.claims);
      const onLeave = await listTeachersOnLeave(db, orgId, schoolId, date);
      return { date, onLeave };
    });
    return jsonResponse(envelope(data));
  } catch (error) {
    if (error instanceof SubstitutionValidationError) {
      return errorEnvelope(error.code, error.message, error.httpStatus);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleDeleteSubstitution(
  req: Request,
  config: AppConfig,
  substitutionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireSubstitutionManage(auth.claims);
  if (denied) return denied;

  try {
    const removed = await withTenantContext(config, auth.claims, async (db) => {
      const deleted = await deleteSubstitution(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        substitutionId,
      );
      if (!deleted) return null;
      await emitMutationAudit(
        db,
        auth.claims,
        academicAudit.timetableSubstituted(deleted.id, "removed", {
          periodId: deleted.period_id,
          subDate: deleted.sub_date,
        }),
        req,
      );
      return deleted;
    });
    if (!removed) {
      return errorEnvelope("NOT_FOUND", "Substitution not found", 404);
    }
    return jsonResponse(envelope({ substitution: removed }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}
