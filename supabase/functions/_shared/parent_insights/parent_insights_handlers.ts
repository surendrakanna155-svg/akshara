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
import { emitMutationAudit, parentInsightsAudit } from "../audit/mutation_audit_catalog.ts";
import {
  generateParentInsightSnapshot,
  type InsightPeriod,
} from "./parent_insights_service.ts";

export async function handleGenerateParentInsights(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewParentInsights") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    studentId: string;
    period?: InsightPeriod;
    language?: string;
  }>(req);
  if (!body?.studentId) {
    return errorEnvelope("VALIDATION_ERROR", "studentId is required", 422);
  }

  const period = body.period ?? "weekly";
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      let language = body.language?.trim();
      if (!language) {
        const prefRows = await db.queryObject<{ language: string }>(
          `SELECT language FROM parent_language_preferences
           WHERE organization_id = $1 AND school_id = $2 AND user_id = $3
             AND (student_id = $4 OR student_id IS NULL)
           ORDER BY student_id NULLS LAST
           LIMIT 1`,
          [orgId, schoolId, auth.claims.sub, body.studentId],
        );
        language = prefRows[0]?.language ?? "english";
      }

      const snapshot = await generateParentInsightSnapshot(db, body.studentId, period, language);
      const rows = await db.queryObject<{ id: string }>(
        `INSERT INTO parent_insight_snapshots (
           organization_id, school_id, student_id, period, language,
           strengths, weaknesses, attendance_insights, homework_insights,
           improvement_suggestions, teacher_remarks_summary, progress_summary
         ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8::jsonb, $9::jsonb, $10::jsonb, $11, $12)
         RETURNING id`,
        [
          orgId,
          schoolId,
          body.studentId,
          period,
          language,
          JSON.stringify(snapshot.strengths),
          JSON.stringify(snapshot.weaknesses),
          JSON.stringify(snapshot.attendanceInsights),
          JSON.stringify(snapshot.homeworkInsights),
          JSON.stringify(snapshot.improvementSuggestions),
          snapshot.teacherRemarksSummary,
          snapshot.progressSummary,
        ],
      );
      const id = rows[0]!.id;
      await emitMutationAudit(
        db,
        auth.claims,
        parentInsightsAudit.snapshotGenerated(id, body.studentId),
        req,
      );
      return { id, ...snapshot };
    });
    return jsonResponse(envelope(result), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PARENT_INSIGHTS_ERROR", String(error), 500);
  }
}

export async function handleListParentInsights(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewParentInsights") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      db.queryObject<Record<string, unknown>>(
        `SELECT id, period, language, progress_summary AS "progressSummary",
                strengths, weaknesses, attendance_insights AS "attendanceInsights",
                homework_insights AS "homeworkInsights",
                improvement_suggestions AS "improvementSuggestions",
                teacher_remarks_summary AS "teacherRemarksSummary",
                printable, voice_ready AS "voiceReady", generated_at AS "generatedAt"
         FROM parent_insight_snapshots
         WHERE student_id = $1
         ORDER BY generated_at DESC
         LIMIT 20`,
        [studentId],
      )
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PARENT_INSIGHTS_ERROR", String(error), 500);
  }
}

export async function handleGetParentLanguagePreference(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewParentInsights") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const studentId = url.searchParams.get("studentId");
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const language = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ language: string }>(
        `SELECT language FROM parent_language_preferences
         WHERE organization_id = $1 AND school_id = $2 AND user_id = $3
           AND (($4::uuid IS NULL AND student_id IS NULL) OR student_id = $4)
         LIMIT 1`,
        [orgId, schoolId, auth.claims.sub, studentId],
      );
      return rows[0]?.language ?? "english";
    });
    return jsonResponse(envelope({ language }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PARENT_INSIGHTS_ERROR", String(error), 500);
  }
}

export async function handleSaveParentLanguagePreference(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewParentInsights") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ language: string; studentId?: string }>(req);
  if (!body?.language) return errorEnvelope("VALIDATION_ERROR", "language is required", 422);

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    await withTenantContext(config, auth.claims, async (db) => {
      if (body.studentId) {
        await db.queryObject(
          `INSERT INTO parent_language_preferences (
             organization_id, school_id, user_id, student_id, language
           ) VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (organization_id, school_id, user_id, student_id)
             WHERE student_id IS NOT NULL
           DO UPDATE SET language = EXCLUDED.language, updated_at = timezone('utc', now())`,
          [orgId, schoolId, auth.claims.sub, body.studentId, body.language],
        );
      } else {
        await db.queryObject(
          `INSERT INTO parent_language_preferences (
             organization_id, school_id, user_id, student_id, language
           ) VALUES ($1, $2, $3, NULL, $4)
           ON CONFLICT (organization_id, school_id, user_id)
             WHERE student_id IS NULL
           DO UPDATE SET language = EXCLUDED.language, updated_at = timezone('utc', now())`,
          [orgId, schoolId, auth.claims.sub, body.language],
        );
      }
    });
    return jsonResponse(envelope({ language: body.language }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PARENT_INSIGHTS_ERROR", String(error), 500);
  }
}
