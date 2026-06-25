import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { resolveAiConfig } from "../ai/ai_settings.ts";
import { buildSchoolBlueprint, normalizeBrief } from "./ai_school_builder_service.ts";
import { enrichSchoolBlueprintWithClaude } from "./ai_school_builder_ai.ts";

/**
 * POST /onboarding/startup/ai-prefill
 *
 * AI School Builder (Phase 1): turn a short founder brief into a complete,
 * board-appropriate startup-onboarding proposal. Deterministic baseline always
 * succeeds; Claude refines it when an AI key is configured, with safe fallback.
 *
 * NON-DESTRUCTIVE: this only proposes. The admin reviews the proposal, then
 * saves it via PUT /onboarding/startup and provisions via the go-live endpoint.
 */
export async function handleAiPrefillStartupOnboarding(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageOnboarding") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<unknown>(req);
  const brief = normalizeBrief(body ?? {});

  try {
    const baseline = buildSchoolBlueprint(brief);
    const blueprint = await withTenantContext(config, auth.claims, async (db) => {
      const ai = await resolveAiConfig(db, organizationIdFromClaims(auth.claims));
      return await enrichSchoolBlueprintWithClaude(baseline, brief, ai.apiKey, {
        provider: ai.provider,
        model: ai.model,
      });
    });

    return jsonResponse(envelope({
      proposal: blueprint.proposal,
      source: blueprint.source,
      rationale: blueprint.rationale,
      warnings: blueprint.warnings,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    // The deterministic baseline is safe even if AI-config resolution failed.
    const fallback = buildSchoolBlueprint(brief);
    return jsonResponse(envelope({
      proposal: fallback.proposal,
      source: fallback.source,
      rationale: fallback.rationale,
      warnings: [...fallback.warnings, "AI refinement unavailable — used deterministic baseline"],
    }));
  }
}
