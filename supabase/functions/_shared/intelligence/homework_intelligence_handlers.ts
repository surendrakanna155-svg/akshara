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
import { emitMutationAudit, intelligenceAudit } from "../audit/mutation_audit_catalog.ts";
import {
  applyHomeworkRecommendations,
  buildHomeworkIntelligencePlan,
  storeHomeworkIntelligenceRun,
} from "./homework_intelligence_service.ts";

function requireHwIntelRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requireAnyPermission(claims, ["viewHomeworkIntelligence", "viewEducation", "viewStudentRisk"]) ??
    requireSchoolOperationalScope(claims);
}

function requireHwIntelWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requireAnyPermission(claims, ["manageHomeworkIntelligence", "manageEducation"]) ??
    requireSchoolOperationalScope(claims);
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

export async function handleHomeworkIntelligencePlan(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireHwIntelRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const className = url.searchParams.get("className");
  const subjectName = url.searchParams.get("subjectName");
  const examType = url.searchParams.get("examType") ?? "unit_test";
  if (!className || !subjectName) {
    return errorEnvelope("VALIDATION_ERROR", "className and subjectName are required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const plan = await runTenant(config, auth.claims, (db) =>
      buildHomeworkIntelligencePlan(db, orgId, schoolId, {
        className,
        sectionName: url.searchParams.get("sectionName") ?? undefined,
        subjectName,
        examType,
        academicYearLabel: url.searchParams.get("academicYearLabel") ?? undefined,
      })
    );
    return jsonResponse(envelope({ plan }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const message = error instanceof Error ? error.message : "Homework intelligence plan failed";
    return errorEnvelope("HOMEWORK_INTELLIGENCE_ERROR", message, 500);
  }
}

export async function handleHomeworkIntelligenceGenerate(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireHwIntelWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    className: string;
    subjectName: string;
    examType?: string;
    sectionName?: string;
    academicYearLabel?: string;
    apply?: boolean;
    studentIds?: string[];
  }>(req);
  if (!body?.className || !body.subjectName) {
    return errorEnvelope("VALIDATION_ERROR", "className and subjectName are required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const input = {
    className: body.className,
    subjectName: body.subjectName,
    examType: body.examType ?? "unit_test",
    sectionName: body.sectionName,
    academicYearLabel: body.academicYearLabel,
  };

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const plan = await buildHomeworkIntelligencePlan(db, orgId, schoolId, input);
      const runId = await storeHomeworkIntelligenceRun(
        db,
        orgId,
        schoolId,
        input,
        plan,
        auth.claims.sub,
      );

      let applied: { homeworkIds: string[]; targetCount: number } | null = null;
      if (body.apply) {
        applied = await applyHomeworkRecommendations(
          db,
          orgId,
          schoolId,
          runId,
          auth.claims.sub,
          body.studentIds,
        );
      }

      await emitMutationAudit(
        db,
        auth.claims,
        intelligenceAudit.homeworkIntelligenceGenerated(runId, applied?.homeworkIds.length ?? 0),
        req,
      );

      return { runId, plan, applied };
    });

    return jsonResponse(envelope(result), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    const message = error instanceof Error ? error.message : "Homework intelligence generate failed";
    return errorEnvelope("HOMEWORK_INTELLIGENCE_ERROR", message, 500);
  }
}
