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
import { emitMutationAudit, schoolCompletionAudit } from "../audit/mutation_audit_catalog.ts";
import {
  buildPrincipalAcademicDashboard,
  buildTeacherProgressDashboard,
  completeTopic,
} from "./academic_tracking_service.ts";
import {
  chapterToApi,
  cloneSyllabusForYear,
  generateSyllabusFromTemplates,
  listSubjectTemplates,
  listSyllabusChapters,
  listSyllabusTopics,
  NoSyllabusTemplateError,
  templateToApi,
  topicToApi,
} from "./syllabus_automation_service.ts";
import {
  allocateRoomsForTimetable,
  analyzeTimetableIntelligence,
  createRoom,
  generateExamTimetable,
  listRooms,
  examToApi,
  roomToApi,
} from "./timetable_intelligence_service.ts";
import { schoolCompletionUuidPattern } from "./school_completion_handlers.ts";

function tenantError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  // PRA-P1-18: an unseeded grade/board is a client-actionable state, not a 500.
  if (error instanceof NoSyllabusTemplateError) {
    return errorEnvelope("NO_SYLLABUS_TEMPLATE", error.message, 422);
  }
  return errorEnvelope("INTERNAL_ERROR", String(error), 500);
}

export async function handleListSubjectTemplates(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageSyllabus") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listSubjectTemplates(db, url.searchParams.get("board") ?? undefined, url.searchParams.get("gradeLabel") ?? undefined)
    );
    return jsonResponse(envelope({ items: items.map(templateToApi) }));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGenerateSyllabus(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageSyllabus") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    academicYearId: string;
    className: string;
    subjectId: string;
    subjectName: string;
    gradeLabel: string;
    board?: string;
  }>(req);
  if (!body?.academicYearId || !body.className || !body.subjectId || !body.subjectName) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId, className, subjectId, subjectName required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const generated = await generateSyllabusFromTemplates(db, orgId, schoolId, {
        ...body,
        gradeLabel: body.gradeLabel ?? body.className,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(db, auth.claims, schoolCompletionAudit.syllabusGenerated(generated.generationId), req);
      return generated;
    });
    return jsonResponse(envelope(result), { status: 201 });
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleCloneSyllabus(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageSyllabus") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ fromYearId: string; toYearId: string }>(req);
  if (!body?.fromYearId || !body.toYearId) {
    return errorEnvelope("VALIDATION_ERROR", "fromYearId and toYearId required", 422);
  }

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const cloned = await cloneSyllabusForYear(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        body.fromYearId,
        body.toYearId,
        auth.claims.sub,
      );
      await emitMutationAudit(db, auth.claims, schoolCompletionAudit.syllabusCloned(body.toYearId), req);
      return cloned;
    });
    return jsonResponse(envelope(result), { status: 201 });
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleListSyllabusChapters(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewAcademicProgress") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const academicYearId = new URL(req.url).searchParams.get("academicYearId") ?? undefined;
  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listSyllabusChapters(db, organizationIdFromClaims(auth.claims), schoolIdFromClaims(auth.claims), academicYearId)
    );
    return jsonResponse(envelope({ items: items.map(chapterToApi) }));
  } catch (error) {
    return tenantError(error);
  }
}

/**
 * Real syllabus topics for a class/subject — backs the teacher's daily-capture
 * topic picker so the client can send a REAL `topicId` to `completeTopic`
 * instead of a fabricated one (P1 fix, caps 58-61).
 */
export async function handleListSyllabusTopics(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewAcademicProgress") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listSyllabusTopics(db, organizationIdFromClaims(auth.claims), schoolIdFromClaims(auth.claims), {
        className: url.searchParams.get("className") ?? undefined,
        subjectId: url.searchParams.get("subjectId") ?? undefined,
        chapterId: url.searchParams.get("chapterId") ?? undefined,
      })
    );
    return jsonResponse(envelope({ items: items.map(topicToApi) }));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleCompleteTopic(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageAcademicProgress") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ topicId: string; lessonLogId?: string }>(req);
  if (!body?.topicId) return errorEnvelope("VALIDATION_ERROR", "topicId required", 422);

  try {
    await withTenantContext(config, auth.claims, async (db) => {
      await completeTopic(db, organizationIdFromClaims(auth.claims), schoolIdFromClaims(auth.claims), {
        topicId: body.topicId,
        teacherUserId: auth.claims.sub,
        lessonLogId: body.lessonLogId,
      });
      await emitMutationAudit(db, auth.claims, schoolCompletionAudit.topicCompleted(body.topicId), req);
    });
    return jsonResponse(envelope({ completed: true }));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetTeacherProgress(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewAcademicProgress") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const dashboard = await withTenantContext(config, auth.claims, (db) =>
      buildTeacherProgressDashboard(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        auth.claims.sub,
      )
    );
    return jsonResponse(envelope(dashboard));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetPrincipalAcademicProgress(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewAcademicProgress") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const dashboard = await withTenantContext(config, auth.claims, (db) =>
      buildPrincipalAcademicDashboard(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      )
    );
    return jsonResponse(envelope(dashboard));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleListRooms(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageAcademicRooms") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listRooms(db, organizationIdFromClaims(auth.claims), schoolIdFromClaims(auth.claims))
    );
    return jsonResponse(envelope({ items: items.map(roomToApi) }));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleCreateRoom(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageAcademicRooms") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ roomLabel: string; roomType?: string; capacity?: number }>(req);
  if (!body?.roomLabel) return errorEnvelope("VALIDATION_ERROR", "roomLabel required", 422);

  try {
    const room = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createRoom(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        body,
      );
      await emitMutationAudit(db, auth.claims, schoolCompletionAudit.roomCreated(created.id), req);
      return created;
    });
    return jsonResponse(envelope(roomToApi(room)), { status: 201 });
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleAllocateRooms(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageAcademicRooms") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const academicYearId = new URL(req.url).searchParams.get("academicYearId");
  if (!academicYearId) return errorEnvelope("VALIDATION_ERROR", "academicYearId required", 422);

  try {
    const result = await withTenantContext(config, auth.claims, (db) =>
      allocateRoomsForTimetable(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        academicYearId,
      )
    );
    return jsonResponse(envelope(result));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGenerateExamTimetable(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageAcademicRooms") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    academicYearId: string;
    className: string;
    subjects: string[];
    startDate: string;
  }>(req);
  if (!body?.academicYearId || !body.className || !body.subjects?.length || !body.startDate) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId, className, subjects, startDate required", 422);
  }

  try {
    const entries = await withTenantContext(config, auth.claims, async (db) => {
      const created = await generateExamTimetable(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        body,
      );
      await emitMutationAudit(db, auth.claims, schoolCompletionAudit.examTimetableGenerated(body.className), req);
      return created;
    });
    return jsonResponse(envelope({ items: entries.map(examToApi) }), { status: 201 });
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetTimetableIntelligence(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewTimetableOptimization") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const academicYearId = new URL(req.url).searchParams.get("academicYearId");
  if (!academicYearId) return errorEnvelope("VALIDATION_ERROR", "academicYearId required", 422);

  try {
    const result = await withTenantContext(config, auth.claims, (db) =>
      analyzeTimetableIntelligence(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        academicYearId,
      )
    );
    return jsonResponse(envelope(result));
  } catch (error) {
    return tenantError(error);
  }
}

export { schoolCompletionUuidPattern };
