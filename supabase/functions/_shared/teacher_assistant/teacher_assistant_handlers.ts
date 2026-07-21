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
import { emitMutationAudit, teacherAssistantAudit } from "../audit/mutation_audit_catalog.ts";
import { buildTeacherAssistantInsights } from "./teacher_assistant_service.ts";
import {
  insertIntervention,
  listOpenInterventions,
  updateIntervention,
} from "./teacher_assistant_repository.ts";

export async function handleTeacherAssistantInsights(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewTeacherAssistant") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const className = url.searchParams.get("className")?.trim() ?? undefined;

  try {
    const insights = await withTenantContext(config, auth.claims, (db) =>
      buildTeacherAssistantInsights(db, className)
    );
    return jsonResponse(envelope(insights));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("TEACHER_ASSISTANT_ERROR", String(error), 500);
  }
}

export async function handleListInterventions(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewTeacherAssistant") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      listOpenInterventions(db)
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("TEACHER_ASSISTANT_ERROR", String(error), 500);
  }
}

export async function handleCreateIntervention(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageTeacherAssistant") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    studentId: string;
    interventionType: string;
    title: string;
    notes?: string;
    priority?: string;
    followUpAt?: string;
  }>(req);
  if (!body?.studentId || !body.title || !body.interventionType) {
    return errorEnvelope("VALIDATION_ERROR", "studentId, interventionType, title required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const id = await withTenantContext(config, auth.claims, async (db) => {
      const interventionId = await insertIntervention(db, {
        organizationId: orgId,
        schoolId,
        teacherUserId: auth.claims.sub,
        studentId: body.studentId,
        interventionType: body.interventionType,
        title: body.title,
        notes: body.notes ?? null,
        priority: body.priority ?? "medium",
        followUpAt: body.followUpAt ?? null,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        teacherAssistantAudit.interventionCreated(interventionId),
        req,
      );
      return interventionId;
    });
    return jsonResponse(envelope({ id }), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("TEACHER_ASSISTANT_ERROR", String(error), 500);
  }
}

export async function handleUpdateIntervention(
  req: Request,
  config: AppConfig,
  interventionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageTeacherAssistant") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ status?: string; notes?: string; followUpAt?: string }>(req);

  try {
    await withTenantContext(config, auth.claims, async (db) => {
      await updateIntervention(db, interventionId, {
        status: body?.status ?? null,
        notes: body?.notes ?? null,
        followUpAt: body?.followUpAt ?? null,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        teacherAssistantAudit.interventionUpdated(interventionId),
        req,
      );
    });
    return jsonResponse(envelope({ id: interventionId }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("TEACHER_ASSISTANT_ERROR", String(error), 500);
  }
}
