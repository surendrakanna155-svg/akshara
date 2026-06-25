// Director portal HTTP handlers — organization scope.
//
// Reads gate on `viewDirectorPortal`; writes (acknowledge compliance, mark a
// report generated) gate on `manageDirectorPortal`. Every request must carry an
// org-level token scope — Director is never a school-scoped feature. All data
// access runs through `withTenantContext`, so the additive org-scope RLS
// policies (not these handlers) enforce that a caller only ever sees their own
// organization's aggregates.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
} from "../permission_middleware.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  TenantDbNotConfiguredError,
  type TenantQueryClient,
  withTenantContext,
} from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  acknowledgeCompliance,
  buildBoardPack,
  buildExecutiveSummary,
  getAdmissions,
  getCompliance,
  getDashboard,
  getGrowth,
  getMarketing,
  getMetricInputs,
  getRevenue,
  getReports,
  getSchoolRows,
  markReportGenerated,
  type MetricInputDraft,
  upsertMetricInput,
} from "./director_repository.ts";
import { refineExecutiveSummaryWithClaude } from "./director_ai.ts";
import { resolveAiConfig } from "../ai/ai_settings.ts";

const ORG_SCOPES = ["organization", "school_group", "platform"];

function requireOrgScope(claims: AccessTokenClaims): Response | null {
  if (!ORG_SCOPES.includes(claims.scope)) {
    return errorEnvelope("FORBIDDEN", "Director portal requires organization scope", 403);
  }
  return null;
}

function gate(claims: AccessTokenClaims, permission: string): Response | null {
  return requirePermission(claims, permission) ?? requireOrgScope(claims);
}

function failure(error: unknown, message: string): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  console.error(`${message}:`, error);
  return errorEnvelope("INTERNAL_ERROR", message, 500);
}

/** Read handler: auth → viewDirectorPortal → org scope → run aggregation. */
async function read(
  req: Request,
  config: AppConfig,
  message: string,
  run: (db: TenantQueryClient, orgId: string) => Promise<unknown>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = gate(auth.claims, "viewDirectorPortal");
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  try {
    const data = await withTenantContext(config, auth.claims, (db) => run(db, orgId));
    return jsonResponse(envelope(data));
  } catch (error) {
    return failure(error, message);
  }
}

export function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return read(req, config, "Failed to load director dashboard", (db, orgId) =>
    getDashboard(db, orgId, new Date()));
}

export function handleSchools(req: Request, config: AppConfig): Promise<Response> {
  return read(req, config, "Failed to load multi-school overview", async (db, orgId) => ({
    items: await getSchoolRows(db, orgId),
  }));
}

export function handlePortfolio(req: Request, config: AppConfig): Promise<Response> {
  return read(req, config, "Failed to load portfolio analytics", (db, orgId) =>
    getGrowth(db, orgId, new Date()));
}

export function handleRevenue(req: Request, config: AppConfig): Promise<Response> {
  return read(req, config, "Failed to load revenue overview", (db, orgId) =>
    getRevenue(db, orgId, new Date()));
}

export function handleGrowth(req: Request, config: AppConfig): Promise<Response> {
  return read(req, config, "Failed to load growth analytics", (db, orgId) =>
    getGrowth(db, orgId, new Date()));
}

export function handleMarketing(req: Request, config: AppConfig): Promise<Response> {
  return read(req, config, "Failed to load marketing performance", (db, orgId) =>
    getMarketing(db, orgId));
}

export function handleAdmissions(req: Request, config: AppConfig): Promise<Response> {
  return read(req, config, "Failed to load admissions performance", (db, orgId) =>
    getAdmissions(db, orgId));
}

export function handleCompliance(req: Request, config: AppConfig): Promise<Response> {
  return read(req, config, "Failed to load compliance monitoring", async (db, orgId) => ({
    items: await getCompliance(db, orgId),
  }));
}

export function handleReports(req: Request, config: AppConfig): Promise<Response> {
  return read(req, config, "Failed to load strategic reports", async (db, orgId) => ({
    items: await getReports(db, orgId),
  }));
}

export function handleMetricInputs(req: Request, config: AppConfig): Promise<Response> {
  return read(req, config, "Failed to load metric inputs", async (db, orgId) => ({
    items: await getMetricInputs(db, orgId),
  }));
}

export async function handleSummary(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = gate(auth.claims, "viewDirectorPortal");
  if (denied) return denied;

  const body = await readJson<{ focusArea?: string }>(req);
  const focusArea = (body?.focusArea ?? "dashboard").trim() || "dashboard";
  const orgId = organizationIdFromClaims(auth.claims);
  try {
    const summary = await withTenantContext(config, auth.claims, async (db) => {
      const schools = await getSchoolRows(db, orgId);
      const revenue = await getRevenue(db, orgId, new Date());
      const admissions = await getAdmissions(db, orgId);
      const deterministic = buildExecutiveSummary(focusArea, schools, revenue, admissions);

      // Real AI refinement, grounded in the deterministic numbers. resolveAiConfig
      // prefers the org's saved provider, else env; with no key configured the
      // refine call returns the deterministic brief unchanged (safe fallback).
      const ai = await resolveAiConfig(db, orgId);
      const atRiskSchools = schools
        .filter((s) => s.status === "atRisk" || s.status === "critical")
        .map((s) => s.schoolName);
      return await refineExecutiveSummaryWithClaude(
        deterministic,
        {
          focusArea,
          schoolCount: schools.length,
          totalStudents: schools.reduce((sum, s) => sum + s.students, 0),
          chainRevenueCr: revenue.chainRevenueCr,
          marginPercent: revenue.marginPercent,
          enrolled: admissions.enrolled,
          inquiries: admissions.inquiries,
          conversionPercent: admissions.conversionPercent,
          atRiskSchools,
        },
        ai.apiKey,
        { provider: ai.provider, model: ai.model },
      );
    });
    return jsonResponse(envelope({ summary }));
  } catch (error) {
    return failure(error, "Failed to generate executive summary");
  }
}

export async function handleAcknowledgeCompliance(
  req: Request,
  config: AppConfig,
  complianceId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = gate(auth.claims, "manageDirectorPortal");
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  try {
    const item = await withTenantContext(config, auth.claims, async (db) => {
      const updated = await acknowledgeCompliance(db, orgId, auth.claims.sub, complianceId);
      if (updated) {
        await emitMutationAudit(
          db,
          auth.claims,
          moduleEntityAudit("director.compliance.acknowledged", "compliance", complianceId, {
            schoolName: updated.schoolName,
          }),
          req,
        );
      }
      return updated;
    });
    if (!item) return errorEnvelope("NOT_FOUND", "Compliance item not found", 404);
    return jsonResponse(envelope(item));
  } catch (error) {
    return failure(error, "Failed to acknowledge compliance item");
  }
}

function parseMetricDraft(body: unknown): MetricInputDraft | null {
  if (!body || typeof body !== "object") return null;
  const b = body as Record<string, unknown>;
  const schoolId = typeof b.schoolId === "string" ? b.schoolId.trim() : "";
  let period = typeof b.periodMonth === "string" ? b.periodMonth.trim() : "";
  if (!schoolId || !period) return null;
  if (/^\d{4}-\d{2}$/.test(period)) period = `${period}-01`;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(period)) return null;

  const num = (v: unknown): number => {
    const n = typeof v === "number" ? v : Number(v);
    return Number.isFinite(n) && n >= 0 ? n : 0;
  };
  return {
    schoolId,
    periodMonth: period,
    marketingSpendInr: num(b.marketingSpendInr),
    operatingExpenseInr: num(b.operatingExpenseInr),
    studentCapacity: Math.round(num(b.studentCapacity)),
  };
}

export async function handleSaveMetricInput(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = gate(auth.claims, "manageDirectorPortal");
  if (denied) return denied;

  const draft = parseMetricDraft(await readJson<unknown>(req));
  if (!draft) {
    return errorEnvelope("VALIDATION_ERROR", "schoolId and periodMonth (YYYY-MM) are required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  try {
    const saved = await withTenantContext(config, auth.claims, async (db) => {
      const result = await upsertMetricInput(db, orgId, draft);
      if (result) {
        await emitMutationAudit(
          db,
          auth.claims,
          moduleEntityAudit("director.metricInput.saved", "metricInput", result.id, {
            schoolId: result.schoolId,
            periodMonth: result.periodMonth,
          }),
          req,
        );
      }
      return result;
    });
    if (!saved) return errorEnvelope("NOT_FOUND", "School not found in this organization", 404);
    return jsonResponse(envelope(saved));
  } catch (error) {
    return failure(error, "Failed to save metric input");
  }
}

export async function handleExportReport(
  req: Request,
  config: AppConfig,
  reportId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = gate(auth.claims, "manageDirectorPortal");
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const marked = await markReportGenerated(db, orgId, auth.claims.sub, reportId);
      if (!marked) return null;
      // Build the real board-pack document from live aggregates — the client
      // renders this into a PDF. Export now produces an actual document, not
      // just a stamp.
      const document = await buildBoardPack(db, orgId, reportId, new Date());
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("director.report.exported", "report", reportId, {}),
        req,
      );
      return {
        reference: `director-report-${reportId}-${new Date(marked.last_generated_at).getTime()}`,
        document,
      };
    });
    if (!result) return errorEnvelope("NOT_FOUND", "Report not found", 404);
    return jsonResponse(envelope(result));
  } catch (error) {
    return failure(error, "Failed to export report");
  }
}
