// Organization Builder HTTP handlers — organization scope.
//
// Reads gate on `viewOrganizationBuilder`; writes (save interview step, generate
// preview, provision) gate on `manageOrganizationBuilder`. Every request must
// carry an org-level token scope — the Organization Builder is a chains/trusts
// feature, never school-scoped. All access runs through `withTenantContext`, so
// the org-scope RLS (not these handlers) is the isolation boundary. Access is
// additionally entitlement-gated (feature.organization_builder) in the router.

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
import { resolveAiConfig } from "../ai/ai_settings.ts";
import {
  buildPreview,
  getJob,
  getOrCreateDraft,
  getPack,
  listDrafts,
  listPacks,
  provision,
  saveStep,
} from "./organization_builder_repository.ts";
import { recommendForStep } from "./organization_builder_ai.ts";

const ORG_SCOPES = ["organization", "school_group", "platform"];
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function requireOrgScope(claims: AccessTokenClaims): Response | null {
  if (!ORG_SCOPES.includes(claims.scope)) {
    return errorEnvelope("FORBIDDEN", "Organization Builder requires organization scope", 403);
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

/** Read handler: auth → viewOrganizationBuilder → org scope → run. */
async function read(
  req: Request,
  config: AppConfig,
  message: string,
  run: (db: TenantQueryClient, orgId: string) => Promise<unknown>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = gate(auth.claims, "viewOrganizationBuilder");
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  try {
    const data = await withTenantContext(config, auth.claims, (db) => run(db, orgId));
    return jsonResponse(envelope(data));
  } catch (error) {
    return failure(error, message);
  }
}

export function handlePacks(req: Request, config: AppConfig): Promise<Response> {
  return read(req, config, "Failed to load vertical packs", async (db) => ({
    items: await listPacks(db),
  }));
}

export function handleDrafts(req: Request, config: AppConfig): Promise<Response> {
  return read(req, config, "Failed to load interview drafts", async (db, orgId) => ({
    items: await listDrafts(db, orgId),
  }));
}

export function handleDraft(
  req: Request,
  config: AppConfig,
  draftId: string,
): Promise<Response> {
  return read(req, config, "Failed to load interview draft", (db, orgId) =>
    getOrCreateDraft(db, orgId, draftId));
}

export async function handleProvisioningJob(
  req: Request,
  config: AppConfig,
  jobId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = gate(auth.claims, "viewOrganizationBuilder");
  if (denied) return denied;
  if (!UUID_RE.test(jobId)) {
    return errorEnvelope("NOT_FOUND", "Provisioning job not found", 404);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  try {
    const job = await withTenantContext(config, auth.claims, (db) => getJob(db, orgId, jobId));
    if (!job) return errorEnvelope("NOT_FOUND", "Provisioning job not found", 404);
    return jsonResponse(envelope(job));
  } catch (error) {
    return failure(error, "Failed to load provisioning job");
  }
}

/** Write handler scaffold: auth → manageOrganizationBuilder → org scope. */
async function write(
  req: Request,
  config: AppConfig,
  message: string,
  run: (db: TenantQueryClient, orgId: string, claims: AccessTokenClaims) => Promise<unknown>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = gate(auth.claims, "manageOrganizationBuilder");
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  try {
    const data = await withTenantContext(config, auth.claims, (db) =>
      run(db, orgId, auth.claims));
    return jsonResponse(envelope(data));
  } catch (error) {
    if (error instanceof NotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof ValidationError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    return failure(error, message);
  }
}

class NotFoundError extends Error {}
class ValidationError extends Error {}

function parseAnswers(value: unknown): Record<string, string> {
  if (!value || typeof value !== "object") return {};
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
    if (typeof k !== "string") continue;
    out[k] = v == null ? "" : String(v);
  }
  return out;
}

export function handleSaveStep(
  req: Request,
  config: AppConfig,
  draftId: string,
): Promise<Response> {
  return write(req, config, "Failed to save interview step", async (db, orgId, claims) => {
    const body = await readJson<{ stepIndex?: number; answers?: unknown }>(req);
    const stepIndex = Number(body?.stepIndex);
    if (!Number.isInteger(stepIndex) || stepIndex < 0 || stepIndex > 6) {
      throw new ValidationError("stepIndex must be an integer between 0 and 6");
    }
    const answers = parseAnswers(body?.answers);

    const existing = await getOrCreateDraft(db, orgId, draftId);
    const packId = answers["pack_id"] || existing.packId || "pack_school";
    const pack = (await getPack(db, packId)) ?? (await getPack(db, "pack_school"))!;
    const orgName = answers["identity_name"] || existing.organizationName || "New Organization";

    // Real AI recommendation (deterministic baseline + Claude, safe fallback).
    const ai = await resolveAiConfig(db, orgId);
    const rec = await recommendForStep(
      {
        packId: pack.id,
        packType: pack.type,
        packName: pack.name,
        organizationName: orgName,
        stepIndex,
        answers,
      },
      ai.apiKey,
      { provider: ai.provider, model: ai.model },
      // Governed path (org-scoped: org-builder has no school context).
      { db, organizationId: orgId, schoolId: null, userId: claims.sub },
    );
    // Prepend the fresh rec, drop any prior rec for the same step (stable id).
    const recommendations = [rec, ...existing.recommendations.filter((r) => r.id !== rec.id)];

    const result = await saveStep(db, orgId, draftId, stepIndex, answers, recommendations);
    // SEC-5 — audit the interview-step write (mirrors handleProvision).
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("orgBuilder.interview.step_saved", "interviewDraft", `${draftId}:${stepIndex}`, {
        draftId,
        stepIndex,
        packId: pack.id,
      }),
      req,
    );
    return result;
  });
}

export function handlePreview(req: Request, config: AppConfig): Promise<Response> {
  return write(req, config, "Failed to generate configuration preview", async (db, orgId) => {
    const body = await readJson<{ draftId?: string }>(req);
    const draftId = (body?.draftId ?? "").trim();
    if (!draftId) throw new ValidationError("draftId is required");

    const draft = await getOrCreateDraft(db, orgId, draftId);
    const pack = (await getPack(db, draft.packId)) ?? (await getPack(db, "pack_school"))!;
    return buildPreview(draft, pack, new Date().toISOString());
  });
}

export function handleProvision(req: Request, config: AppConfig): Promise<Response> {
  return write(req, config, "Failed to start provisioning", async (db, orgId, claims) => {
    const body = await readJson<{ draftId?: string }>(req);
    const draftId = (body?.draftId ?? "").trim();
    if (!draftId) throw new ValidationError("draftId is required");

    const result = await provision(db, orgId, draftId, new Date().toISOString());
    // Audit real provisioning only on a genuinely completed job; a failed job
    // means the SECURITY DEFINER function rolled back, so nothing was created.
    const eventType = result.job.status === "completed"
      ? "orgBuilder.organization.provisioned"
      : "orgBuilder.organization.provision_failed";
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit(eventType, "provisioningJob", result.job.id, {
        draftId,
        organizationName: result.job.organizationName,
        packId: result.resolvedConfig.packId,
        status: result.job.status,
      }),
      req,
    );
    return result.job;
  });
}
