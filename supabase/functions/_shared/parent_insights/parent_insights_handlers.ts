import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireParentInsightsScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, parentInsightsAudit } from "../audit/mutation_audit_catalog.ts";
import {
  generateParentInsightSnapshot,
  type InsightPeriod,
  ParentInsightsNoDataError,
} from "./parent_insights_service.ts";
import { enrichParentInsightWithClaude, normalizeInsightLanguage } from "./parent_insights_ai.ts";
import {
  getLanguagePreference,
  getLanguagePreferenceForStudent,
  insertInsightSnapshot,
  listInsightSnapshots,
  upsertLanguagePreferenceDefault,
  upsertLanguagePreferenceForStudent,
} from "./parent_insights_repository.ts";

/**
 * PRA-P0-21: a parent-scope caller may only touch insights for their OWN child.
 * `studentId` is client-supplied and was never checked against `child_ids`, so a
 * parent could name any student id. Returns a 403 Response when the caller is a
 * parent and the studentId is not one of their linked children; null otherwise
 * (school-scope staff are governed by RLS + their operational scope). This is
 * defence-in-depth alongside the parent-scope RLS on the source snapshot table.
 */
function denyForeignChild(
  claims: Parameters<typeof requirePermission>[0],
  studentId: string,
): Response | null {
  if (claims.scope !== "parent") return null;
  const childIds = claims.child_ids ?? [];
  if (!childIds.includes(studentId)) {
    return errorEnvelope("FORBIDDEN", "You can only view insights for your own child", 403);
  }
  return null;
}

export async function handleGenerateParentInsights(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewParentInsights") ??
    requireParentInsightsScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    studentId: string;
    period?: InsightPeriod;
    language?: string;
  }>(req);
  if (!body?.studentId) {
    return errorEnvelope("VALIDATION_ERROR", "studentId is required", 422);
  }
  const foreign = denyForeignChild(auth.claims, body.studentId);
  if (foreign) return foreign;

  const period = body.period ?? "weekly";
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      let language = body.language?.trim();
      if (!language) {
        const prefRows = await getLanguagePreferenceForStudent(
          db,
          orgId,
          schoolId,
          auth.claims.sub,
          body.studentId,
        );
        language = prefRows[0]?.language ?? "english";
      }
      // Both the request body and the stored preference are free text; the
      // language reaches the model prompt as an INSTRUCTION, so clamp it to
      // the fixed catalog (P2-5).
      language = normalizeInsightLanguage(language);

      const baseSnapshot = await generateParentInsightSnapshot(db, body.studentId, period, language);
      const snapshot = await enrichParentInsightWithClaude(
        baseSnapshot,
        { db, organizationId: orgId, schoolId, userId: auth.claims.sub },
      );
      const rows = await insertInsightSnapshot(db, {
        organizationId: orgId,
        schoolId,
        studentId: body.studentId,
        period,
        language,
        strengths: snapshot.strengths,
        weaknesses: snapshot.weaknesses,
        attendanceInsights: snapshot.attendanceInsights,
        homeworkInsights: snapshot.homeworkInsights,
        improvementSuggestions: snapshot.improvementSuggestions,
        teacherRemarksSummary: snapshot.teacherRemarksSummary,
        progressSummary: snapshot.progressSummary,
      });
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
    // PRA-P0-21: no readable risk snapshot → honest "not available yet", never a
    // fabricated snapshot. Nothing was persisted and the model was never called.
    if (error instanceof ParentInsightsNoDataError) {
      return errorEnvelope(
        "PARENT_INSIGHTS_NO_DATA",
        "No insights are available for this student yet.",
        404,
      );
    }
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
    requireParentInsightsScope(auth.claims);
  if (denied) return denied;
  const foreign = denyForeignChild(auth.claims, studentId);
  if (foreign) return foreign;

  try {
    const items = await withTenantContext(config, auth.claims, (db) =>
      listInsightSnapshots(db, studentId)
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
    requireParentInsightsScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const studentId = url.searchParams.get("studentId");
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const language = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await getLanguagePreference(
        db,
        orgId,
        schoolId,
        auth.claims.sub,
        studentId,
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
    requireParentInsightsScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ language: string; studentId?: string }>(req);
  if (!body?.language) return errorEnvelope("VALIDATION_ERROR", "language is required", 422);

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    await withTenantContext(config, auth.claims, async (db) => {
      if (body.studentId) {
        await upsertLanguagePreferenceForStudent(
          db,
          orgId,
          schoolId,
          auth.claims.sub,
          body.studentId,
          body.language,
        );
      } else {
        await upsertLanguagePreferenceDefault(
          db,
          orgId,
          schoolId,
          auth.claims.sub,
          body.language,
        );
      }
    });
    return jsonResponse(envelope({ language: body.language }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("PARENT_INSIGHTS_ERROR", String(error), 500);
  }
}
