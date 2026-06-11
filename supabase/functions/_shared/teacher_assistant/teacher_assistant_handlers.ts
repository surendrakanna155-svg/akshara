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
      db.queryObject<Record<string, unknown>>(
        `SELECT id, student_id AS "studentId", intervention_type AS "interventionType",
                status, priority, title, notes, follow_up_at AS "followUpAt"
         FROM teacher_interventions
         WHERE status IN ('open', 'in_progress')
         ORDER BY priority DESC, created_at DESC
         LIMIT 50`,
      )
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
      const rows = await db.queryObject<{ id: string }>(
        `INSERT INTO teacher_interventions (
           organization_id, school_id, teacher_user_id, student_id,
           intervention_type, title, notes, priority, follow_up_at, created_by
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         RETURNING id`,
        [
          orgId,
          schoolId,
          auth.claims.sub,
          body.studentId,
          body.interventionType,
          body.title,
          body.notes ?? null,
          body.priority ?? "medium",
          body.followUpAt ?? null,
          auth.claims.sub,
        ],
      );
      await emitMutationAudit(
        db,
        auth.claims,
        teacherAssistantAudit.interventionCreated(rows[0]!.id),
        req,
      );
      return rows[0]!.id;
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
      await db.queryObject(
        `UPDATE teacher_interventions
         SET status = coalesce($2, status),
             notes = coalesce($3, notes),
             follow_up_at = coalesce($4::timestamptz, follow_up_at),
             completed_at = CASE WHEN $2 = 'completed' THEN timezone('utc', now()) ELSE completed_at END,
             updated_at = timezone('utc', now())
         WHERE id = $1`,
        [interventionId, body?.status ?? null, body?.notes ?? null, body?.followUpAt ?? null],
      );
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
