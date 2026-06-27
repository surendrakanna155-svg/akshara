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
import { emitMutationAudit, intelligenceAudit } from "../audit/mutation_audit_catalog.ts";
import {
  buildLessonEffectivenessScores,
  buildTeacherPerformanceInsightsForUser,
  buildTeacherPlanningCenterForUser,
  buildTopicMasteryAnalytics,
  generateStructuredParentMeetingSummary,
  storeParentMeetingSummary,
  type ParentMeetingSummaryInput,
} from "./teacher_effectiveness_service.ts";

function handleError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  const message = error instanceof Error ? error.message : "Teacher effectiveness operation failed";
  return errorEnvelope("TEACHER_EFFECTIVENESS_ERROR", message, 500);
}

function requireTeacherEffectivenessRead(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "viewTeacherEffectiveness") ??
    requirePermission(claims, "viewLessonAnalytics") ??
    requireSchoolOperationalScope(claims);
}

/**
 * RT-22 — generating + persisting a parent-meeting summary is a WRITE, so it
 * requires a manage-tier slug (`manageLessonLogs`, held by teachers and school
 * admins) rather than the read slug. Previously a view-only user could trigger
 * the AI generation and write a row.
 */
function requireTeacherEffectivenessManage(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  return requirePermission(claims, "manageLessonLogs") ??
    requireSchoolOperationalScope(claims);
}

export async function handleGetLessonEffectivenessScores(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTeacherEffectivenessRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const teacherUserId = url.searchParams.get("teacherUserId") ?? auth.claims.sub;
  const className = url.searchParams.get("className") ?? undefined;

  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      buildLessonEffectivenessScores(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        teacherUserId,
        className,
      )
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleGetTopicMasteryAnalytics(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTeacherEffectivenessRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const teacherUserId = url.searchParams.get("teacherUserId") ?? auth.claims.sub;

  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      buildTopicMasteryAnalytics(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        teacherUserId,
      )
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleGetTeacherPerformanceInsights(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTeacherEffectivenessRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const teacherUserId = url.searchParams.get("teacherUserId") ?? auth.claims.sub;

  try {
    const insights = await withTenantContext(config, auth.claims, (db) =>
      buildTeacherPerformanceInsightsForUser(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        teacherUserId,
      )
    );
    return jsonResponse(envelope(insights));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleGetTeacherPlanningCenter(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTeacherEffectivenessRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const teacherUserId = url.searchParams.get("teacherUserId") ?? auth.claims.sub;

  try {
    const center = await withTenantContext(config, auth.claims, (db) =>
      buildTeacherPlanningCenterForUser(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        teacherUserId,
      )
    );
    return jsonResponse(envelope(center));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleGenerateParentMeetingSummary(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTeacherEffectivenessManage(auth.claims);
  if (denied) return denied;

  const body = await readJson<ParentMeetingSummaryInput>(req);
  if (!body?.studentId || !body.studentName || !body.className || !body.meetingDate) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "studentId, studentName, className, meetingDate required",
      422,
    );
  }

  const summary = generateStructuredParentMeetingSummary(body);

  try {
    const stored = await withTenantContext(config, auth.claims, async (db) => {
      const result = await storeParentMeetingSummary(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims),
        auth.claims.sub,
        summary,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        intelligenceAudit.parentMeetingSummaryGenerated(body.studentId),
        req,
      );
      return result;
    });
    return jsonResponse(envelope({ ...summary, id: stored.id }), { status: 201 });
  } catch (error) {
    return handleError(error);
  }
}
