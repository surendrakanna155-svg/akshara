import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireAnyPermission,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { intelligenceAudit, emitMutationAudit } from "../audit/mutation_audit_catalog.ts";
import {
  classRiskToApi,
  communicationDraftToApi,
  parentGuidanceToApi,
  principalCenterToApi,
  riskSnapshotToApi,
  teacherSuccessToApi,
} from "./intelligence_mapper.ts";
import {
  generateCommunicationDrafts,
  rewriteCustomNote,
} from "./communication_generator.ts";
import { generateParentGuidanceReport } from "./parent_guidance_generator.ts";
import {
  computeAndStoreRiskSnapshots,
  getRiskSnapshotByStudent,
  listClassRiskSummaries,
  listRiskSnapshots,
} from "./student_risk_repository.ts";
import { buildTeacherSuccessCenter } from "./teacher_success_service.ts";
import { buildPrincipalIntelligenceCenter } from "./principal_intelligence_service.ts";
import { executePrincipalQuery } from "./principal_query_service.ts";
import type {
  CommunicationScenario,
  GuidanceMode,
  IntelLanguage,
} from "./intelligence_types.ts";

function requireRiskRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requireAnyPermission(claims, ["viewStudentRisk", "viewAnalytics"]) ??
    requireSchoolOperationalScope(claims);
}

function requireIntelligenceWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "generateIntelligence") ??
    requireSchoolOperationalScope(claims);
}

function handleError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  const message = error instanceof Error ? error.message : "Intelligence operation failed";
  return errorEnvelope("INTELLIGENCE_ERROR", message, 500);
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

// ─── v8.9 Student Risk ───────────────────────────────────────────────────────

export async function handleListStudentRisks(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireRiskRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  try {
    const items = await runTenant(config, auth.claims, (db) =>
      listRiskSnapshots(db, {
        className: url.searchParams.get("className") ?? undefined,
        riskLevel: url.searchParams.get("riskLevel") ?? undefined,
      })
    );
    return jsonResponse(envelope({ items: items.map(riskSnapshotToApi) }));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleGetStudentRisk(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireRiskRead(auth.claims);
  if (denied) return denied;

  try {
    const row = await runTenant(config, auth.claims, (db) =>
      getRiskSnapshotByStudent(db, studentId)
    );
    if (!row) return errorEnvelope("NOT_FOUND", "Student risk snapshot not found", 404);
    return jsonResponse(envelope(riskSnapshotToApi(row)));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleListClassRisks(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireRiskRead(auth.claims);
  if (denied) return denied;

  try {
    const items = await runTenant(config, auth.claims, (db) => listClassRiskSummaries(db));
    return jsonResponse(envelope({ items: items.map(classRiskToApi) }));
  } catch (error) {
    return handleError(error);
  }
}

export async function handleComputeStudentRisks(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireIntelligenceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ academicYearLabel?: string }>(req);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const yearLabel = body?.academicYearLabel ?? "2025-26";

  try {
    const stored = await runTenant(config, auth.claims, async (db) => {
      const rows = await computeAndStoreRiskSnapshots(db, orgId, schoolId, yearLabel);
      await emitMutationAudit(
        db,
        auth.claims,
        intelligenceAudit.studentRiskComputed(schoolId, rows.length),
        req,
      );
      return rows;
    });
    return jsonResponse(envelope({
      computed: stored.length,
      items: stored.map(riskSnapshotToApi),
    }), { status: 201 });
  } catch (error) {
    return handleError(error);
  }
}

// ─── v9.0 Communication Assistant ────────────────────────────────────────────

export async function handleGenerateCommunication(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireIntelligenceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    scenario: CommunicationScenario;
    studentId?: string;
    studentName?: string;
    className?: string;
    customNote?: string;
    languages?: IntelLanguage[];
    parentPreferredLanguage?: IntelLanguage;
    feeAmount?: string;
    dueDate?: string;
    examName?: string;
    meetingDate?: string;
  }>(req);
  if (!body?.scenario) {
    return errorEnvelope("VALIDATION_ERROR", "scenario is required", 422);
  }

  const note = body.customNote ? rewriteCustomNote(body.customNote) : undefined;
  const languages = body.languages?.length ? body.languages : ["english" as IntelLanguage];
  const drafts = generateCommunicationDrafts({
    scenario: body.scenario,
    studentName: body.studentName,
    className: body.className,
    customNote: note,
    languages,
    parentPreferredLanguage: body.parentPreferredLanguage,
    context: {
      feeAmount: body.feeAmount,
      dueDate: body.dueDate,
      examName: body.examName,
      meetingDate: body.meetingDate,
    },
  });

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const id = await runTenant(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ id: string }>(
        `INSERT INTO intel_communication_drafts (
           organization_id, school_id, scenario, student_id, custom_note, languages, outputs, created_by
         ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8)
         RETURNING id`,
        [
          orgId,
          schoolId,
          body.scenario,
          body.studentId ?? null,
          note ?? null,
          JSON.stringify(languages),
          JSON.stringify(communicationDraftToApi(drafts)),
          auth.claims.sub,
        ],
      );
      await emitMutationAudit(
        db,
        auth.claims,
        intelligenceAudit.communicationGenerated(rows[0]!.id),
        req,
      );
      return rows[0]!.id;
    });

    return jsonResponse(envelope({ id, ...communicationDraftToApi(drafts) }), { status: 201 });
  } catch (error) {
    return handleError(error);
  }
}

// ─── v9.1 Parent Guidance ──────────────────────────────────────────────────────

export async function handleGenerateParentGuidance(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireIntelligenceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    studentId: string;
    mode: GuidanceMode;
    language?: IntelLanguage;
    inputs?: Record<string, unknown>;
    publish?: boolean;
    autoFillFromRisk?: boolean;
  }>(req);
  if (!body?.studentId || !body.mode) {
    return errorEnvelope("VALIDATION_ERROR", "studentId and mode are required", 422);
  }

  const language = body.language ?? "english";
  const publish = body.publish ?? true;
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      let inputs = { ...(body.inputs ?? {}) } as {
        attendancePercent?: number;
        averageMarks?: number;
        homeworkCompletionRate?: number;
        strengths?: string[];
        weaknesses?: string[];
        studentName?: string;
      };

      if (body.autoFillFromRisk !== false) {
        const risk = await getRiskSnapshotByStudent(db, body.studentId);
        if (risk) {
          const riskInputs = risk.inputs as Record<string, unknown> | null;
          inputs = {
            attendancePercent: inputs.attendancePercent ??
              (riskInputs?.attendance_percent as number | undefined),
            averageMarks: inputs.averageMarks ??
              (riskInputs?.average_marks as number | undefined),
            homeworkCompletionRate: inputs.homeworkCompletionRate ??
              (riskInputs?.homework_completion_rate as number | undefined),
            studentName: inputs.studentName ??
              (riskInputs?.student_name as string | undefined),
            strengths: inputs.strengths?.length
              ? inputs.strengths
              : ["Class participation"],
            weaknesses: inputs.weaknesses?.length
              ? inputs.weaknesses
              : (risk.reasons as Array<{ label?: string }> | null)
                  ?.map((r) => r.label ?? "Academic support")
                  .filter(Boolean)
                  .slice(0, 3) ?? ["Time management"],
          };
        }
      }

      const report = generateParentGuidanceReport(body.mode, language, inputs);
      const status = publish ? "published" : "draft";

      const rows = await db.queryObject<{ id: string }>(
        `INSERT INTO intel_parent_guidance_reports (
           organization_id, school_id, student_id, mode, language, inputs, report, status, created_by
         ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7::jsonb, $8, $9)
         RETURNING id`,
        [
          orgId,
          schoolId,
          body.studentId,
          body.mode,
          language,
          JSON.stringify(inputs),
          JSON.stringify(report),
          status,
          auth.claims.sub,
        ],
      );
      await emitMutationAudit(
        db,
        auth.claims,
        intelligenceAudit.parentGuidanceGenerated(rows[0]!.id),
        req,
      );
      return { id: rows[0]!.id, report, inputs };
    });

    return jsonResponse(envelope(
      parentGuidanceToApi(result.report, {
        id: result.id,
        mode: body.mode,
        language,
        studentId: body.studentId,
        status: publish ? "published" : "draft",
      }),
    ), { status: 201 });
  } catch (error) {
    return handleError(error);
  }
}

export async function handlePublishParentGuidance(
  req: Request,
  config: AppConfig,
  reportId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireIntelligenceWrite(auth.claims);
  if (denied) return denied;

  try {
    await runTenant(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ id: string }>(
        `UPDATE intel_parent_guidance_reports
         SET status = 'published', updated_at = timezone('utc', now())
         WHERE id = $1
         RETURNING id`,
        [reportId],
      );
      if (!rows.length) throw new Error("Guidance report not found");
      await emitMutationAudit(
        db,
        auth.claims,
        intelligenceAudit.parentGuidanceGenerated(reportId),
        req,
      );
    });
    return jsonResponse(envelope({ id: reportId, status: "published" }));
  } catch (error) {
    return handleError(error);
  }
}

// ─── v9.2 Teacher Success Center ─────────────────────────────────────────────

export async function handleTeacherSuccessCenter(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireRiskRead(auth.claims);
  if (denied) return denied;

  try {
    const center = await runTenant(config, auth.claims, (db) =>
      buildTeacherSuccessCenter(db)
    );
    return jsonResponse(envelope(teacherSuccessToApi(center)));
  } catch (error) {
    return handleError(error);
  }
}

export async function handlePrincipalQuery(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyPermission(auth.claims, ["viewAnalytics", "viewSchoolHealth"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const query = url.searchParams.get("q")?.trim() ?? "";
  if (!query) {
    return errorEnvelope("VALIDATION_ERROR", "q query parameter is required", 422);
  }

  try {
    const result = await runTenant(config, auth.claims, (db) =>
      executePrincipalQuery(db, query)
    );
    return jsonResponse(envelope(result));
  } catch (error) {
    return handleError(error);
  }
}

// ─── v9.3 Principal Intelligence Center ──────────────────────────────────────

export async function handlePrincipalIntelligenceCenter(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireAnyPermission(auth.claims, ["viewAnalytics", "viewSchoolHealth"]) ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const period = url.searchParams.get("period") === "quarterly" ? "quarterly" : "monthly";
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const center = await runTenant(config, auth.claims, (db) =>
      buildPrincipalIntelligenceCenter(db, orgId, schoolId, period)
    );
    return jsonResponse(envelope(principalCenterToApi(center)));
  } catch (error) {
    return handleError(error);
  }
}
