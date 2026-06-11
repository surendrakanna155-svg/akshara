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
  classSubjectToApi,
  computeSubjectWorkload,
  createClassSubjectAssignment,
  createTeacherSubjectAssignment,
  deleteClassSubjectAssignment,
  listClassSubjectAssignments,
  listTeacherSubjectAssignments,
  SubjectAssignmentValidationError,
  teacherSubjectToApi,
  workloadToApi,
} from "./subject_assignments_repository.ts";
import {
  computePrincipalCoverage,
  computeTeacherLessonAnalytics,
  fetchLessonLogsForAnalytics,
  fetchSyllabusTopics,
} from "./lesson_analytics_service.ts";
import { analyzeTimetableOptimization } from "./timetable_optimization_service.ts";
import {
  deliveryAnalyticsToApi,
  getDeliveryAnalytics,
  sendSchoolTemplateMessage,
} from "./communication_bridge_service.ts";
import { buildPilotDashboard, pilotDashboardToApi } from "./pilot_dashboard_service.ts";
import { schoolCompletionUuidPattern } from "./school_completion_handlers.ts";

function tenantError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  if (error instanceof SubjectAssignmentValidationError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  return errorEnvelope("INTERNAL_ERROR", String(error), 500);
}

export async function handleListClassSubjectAssignments(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewSubjectAssignments") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const academicYearId = url.searchParams.get("academicYearId") ?? undefined;

  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listClassSubjectAssignments(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        academicYearId,
      )
    );
    return jsonResponse(envelope({ items: items.map(classSubjectToApi) }));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleCreateClassSubjectAssignment(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageSubjectAssignments") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    academicYearId: string;
    classId: string;
    sectionId?: string;
    subjectId: string;
    isElective?: boolean;
    periodsPerWeek?: number;
  }>(req);
  if (!body?.academicYearId || !body.classId || !body.subjectId) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId, classId, subjectId required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createClassSubjectAssignment(db, orgId, schoolId, {
        ...body,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        schoolCompletionAudit.classSubjectAssigned(created.id),
        req,
      );
      return created;
    });
    return jsonResponse(envelope(classSubjectToApi(row)), { status: 201 });
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleDeleteClassSubjectAssignment(
  req: Request,
  config: AppConfig,
  assignmentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageSubjectAssignments") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const deleted = await withTenantContext(config, auth.claims, async (db) => {
      const ok = await deleteClassSubjectAssignment(db, orgId, schoolId, assignmentId);
      if (ok) {
        await emitMutationAudit(
          db,
          auth.claims,
          schoolCompletionAudit.classSubjectRemoved(assignmentId),
          req,
        );
      }
      return ok;
    });
    if (!deleted) return errorEnvelope("NOT_FOUND", "Assignment not found", 404);
    return jsonResponse(envelope({ deleted: true }));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleListTeacherSubjectAssignments(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewSubjectAssignments") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const academicYearId = url.searchParams.get("academicYearId") ?? undefined;

  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listTeacherSubjectAssignments(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        academicYearId,
      )
    );
    return jsonResponse(envelope({ items: items.map(teacherSubjectToApi) }));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleCreateTeacherSubjectAssignment(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageSubjectAssignments") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    academicYearId: string;
    teacherUserId: string;
    subjectId: string;
    classId?: string;
    sectionId?: string;
    periodsPerWeek?: number;
    isPrimary?: boolean;
  }>(req);
  if (!body?.academicYearId || !body.teacherUserId || !body.subjectId) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "academicYearId, teacherUserId, subjectId required",
      422,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createTeacherSubjectAssignment(db, orgId, schoolId, {
        ...body,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        schoolCompletionAudit.teacherSubjectAssigned(created.id),
        req,
      );
      return created;
    });
    return jsonResponse(envelope(teacherSubjectToApi(row)), { status: 201 });
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetSubjectWorkload(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewSubjectAssignments") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const workload = await withTenantContext(config, auth.claims, async (db) => {
      const assignments = await listTeacherSubjectAssignments(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      );
      return computeSubjectWorkload(assignments);
    });
    return jsonResponse(envelope({ items: workload.map(workloadToApi) }));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetTeacherLessonAnalytics(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewLessonAnalytics") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const className = url.searchParams.get("className") ?? undefined;
  const teacherUserId = url.searchParams.get("teacherUserId") ?? auth.claims.sub;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const analytics = await withTenantContext(config, auth.claims, async (db) => {
      const [topics, logs] = await Promise.all([
        fetchSyllabusTopics(db, orgId, schoolId, className),
        fetchLessonLogsForAnalytics(db, orgId, schoolId, teacherUserId, className),
      ]);
      return computeTeacherLessonAnalytics({ topics, logs, teacherUserId });
    });
    return jsonResponse(envelope(analytics));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetPrincipalLessonAnalytics(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewLessonAnalytics") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const coverage = await withTenantContext(config, auth.claims, async (db) => {
      const [topics, logs] = await Promise.all([
        fetchSyllabusTopics(db, orgId, schoolId),
        fetchLessonLogsForAnalytics(db, orgId, schoolId),
      ]);
      return computePrincipalCoverage({ topics, logs });
    });
    return jsonResponse(envelope({ items: coverage }));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetTimetableOptimization(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewTimetableOptimization") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const academicYearId = url.searchParams.get("academicYearId");
  if (!academicYearId) {
    return errorEnvelope("VALIDATION_ERROR", "academicYearId required", 422);
  }

  try {
    const result = await withTenantContext(config, auth.claims, (db) =>
      analyzeTimetableOptimization(
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

export async function handleGetDeliveryAnalytics(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewCommunicationDelivery") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const analytics = await withTenantContext(config, auth.claims, (db) =>
      getDeliveryAnalytics(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      )
    );
    return jsonResponse(envelope(deliveryAnalyticsToApi(analytics)));
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleSendTemplateMessage(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageCommunicationTemplates") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    templateCode: string;
    recipientUserId: string;
    variables?: Record<string, string>;
    channel?: string;
  }>(req);
  if (!body?.templateCode || !body.recipientUserId) {
    return errorEnvelope("VALIDATION_ERROR", "templateCode and recipientUserId required", 422);
  }

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const sent = await sendSchoolTemplateMessage(db, auth.claims, {
        templateCode: body.templateCode,
        recipientUserId: body.recipientUserId,
        variables: body.variables ?? {},
        channel: body.channel,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        schoolCompletionAudit.templateMessageSent(body.templateCode),
        req,
      );
      return sent;
    });
    return jsonResponse(envelope(result), { status: 201 });
  } catch (error) {
    return tenantError(error);
  }
}

export async function handleGetPilotDashboard(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewPilotDashboard") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const snapshot = await withTenantContext(config, auth.claims, (db) =>
      buildPilotDashboard(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
      )
    );
    return jsonResponse(envelope(pilotDashboardToApi(snapshot)));
  } catch (error) {
    return tenantError(error);
  }
}

export { schoolCompletionUuidPattern };
