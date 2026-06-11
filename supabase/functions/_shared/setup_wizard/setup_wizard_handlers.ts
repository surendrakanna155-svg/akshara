import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { TenantDbNotConfiguredError } from "../tenant_db.ts";
import { emitMutationAudit, setupWizardAudit } from "../audit/mutation_audit_catalog.ts";
import { buildSetupRecommendations, type SetupWizardInputs } from "./setup_wizard_service.ts";
import { provisionSchoolFromWizard } from "./setup_wizard_provision_service.ts";

const STEPS = [
  "school_profile",
  "academic_year",
  "classes",
  "sections",
  "subjects",
  "fee_structure",
  "imports",
  "timetable",
  "review",
] as const;

export async function handleCreateSetupWizard(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageSchoolSetup") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ inputs?: SetupWizardInputs }>(req);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const inputs = body?.inputs ?? {};
  const result = buildSetupRecommendations(inputs);

  try {
    const id = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{ id: string }>(
        `INSERT INTO setup_wizard_sessions (
           organization_id, school_id, inputs, recommendations, warnings, missing_items, created_by
         ) VALUES ($1, $2, $3::jsonb, $4::jsonb, $5::jsonb, $6::jsonb, $7)
         RETURNING id`,
        [
          orgId,
          schoolId,
          JSON.stringify(inputs),
          JSON.stringify(result.recommendations),
          JSON.stringify(result.warnings),
          JSON.stringify(result.missingItems),
          auth.claims.sub,
        ],
      );
      await emitMutationAudit(db, auth.claims, setupWizardAudit.sessionCreated(rows[0]!.id), req);
      return rows[0]!.id;
    });
    return jsonResponse(envelope({
      id,
      status: "in_progress",
      currentStep: "school_profile",
      inputs,
      ...result,
      steps: STEPS,
    }), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("SETUP_WIZARD_ERROR", String(error), 500);
  }
}

export async function handleGetSetupWizard(
  req: Request,
  config: AppConfig,
  sessionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewSchoolSetup") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<{
        id: string;
        status: string;
        current_step: string;
        inputs: unknown;
        recommendations: unknown;
        warnings: unknown;
        missing_items: unknown;
      }>(
        `SELECT id, status, current_step, inputs, recommendations, warnings, missing_items
         FROM setup_wizard_sessions WHERE id = $1`,
        [sessionId],
      );
      return rows[0];
    });
    if (!row) return errorEnvelope("NOT_FOUND", "Setup wizard session not found", 404);
    return jsonResponse(envelope({
      id: row.id,
      status: row.status,
      currentStep: row.current_step,
      inputs: row.inputs,
      recommendations: row.recommendations,
      warnings: row.warnings,
      missingItems: row.missing_items,
      steps: STEPS,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("SETUP_WIZARD_ERROR", String(error), 500);
  }
}

export async function handleAdvanceSetupWizard(
  req: Request,
  config: AppConfig,
  sessionId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageSchoolSetup") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ step: string; inputs?: SetupWizardInputs; complete?: boolean }>(req);
  if (!body?.step) return errorEnvelope("VALIDATION_ERROR", "step is required", 422);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const existing = await db.queryObject<{ inputs: SetupWizardInputs }>(
        `SELECT inputs FROM setup_wizard_sessions WHERE id = $1`,
        [sessionId],
      );
      if (!existing[0]) throw new Error("Session not found");
      const merged = { ...existing[0].inputs, ...(body.inputs ?? {}) };
      const built = buildSetupRecommendations(merged);
      const status = body.complete ? "completed" : "in_progress";
      await db.queryObject(
        `UPDATE setup_wizard_sessions
         SET current_step = $2, inputs = $3::jsonb, recommendations = $4::jsonb,
             warnings = $5::jsonb, missing_items = $6::jsonb, status = $7,
             updated_at = timezone('utc', now())
         WHERE id = $1`,
        [
          sessionId,
          body.step,
          JSON.stringify(merged),
          JSON.stringify(built.recommendations),
          JSON.stringify(built.warnings),
          JSON.stringify(built.missingItems),
          status,
        ],
      );
      let provisionWarnings: string[] = [];
      if (body.complete) {
        const provision = await provisionSchoolFromWizard(
          db,
          organizationIdFromClaims(auth.claims),
          schoolIdFromClaims(auth.claims),
          auth.claims.sub,
          merged,
        );
        provisionWarnings = provision.warnings;
        await emitMutationAudit(db, auth.claims, setupWizardAudit.sessionCompleted(sessionId), req);
      }
      return {
        ...built,
        inputs: merged,
        warnings: [...built.warnings, ...provisionWarnings],
        status,
        currentStep: body.step,
      };
    });
    return jsonResponse(envelope({ id: sessionId, ...result, steps: STEPS }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("SETUP_WIZARD_ERROR", String(error), 500);
  }
}
