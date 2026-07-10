// Adaptive AI — P3-AI-3 / W2.1: brief/digest routes.
//
//   GET  /intelligence/briefs/daily?persona=teacher|principal
//        The persona's daily brief: live T1 sections + the shared cached
//        narrative (see brief_service.ts). Same scope wall as the priority
//        feed (requirePriorityFeedScope).
//
//   POST /intelligence/briefs/prewarm
//        The off-peak generation pass (doc 03 §3.4). Two callers, mirroring
//        the COM-4 run-scheduled pattern exactly:
//        • internal cron (x-internal-cron-token, fail-closed) → sweeps every
//          active org's schools and warms each school's principal pulse. The
//          nightly auto-fire stays ops-gated on INTERNAL_CRON_TOKEN.
//        • a school-scoped staff JWT with viewAnalytics → warms their own
//          school (manual/testing path).

import type { AppConfig } from "../../config.ts";
import type { AccessTokenClaims } from "../../jwt.ts";
import { envelope, errorEnvelope, jsonResponse } from "../../http.ts";
import {
  authenticateRequest,
  requirePermission,
  requireSchoolOperationalScope,
} from "../../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../../tenant_handlers.ts";
import { createServiceClient } from "../../db.ts";
import {
  INTERNAL_CRON_ACTOR_ID,
  INTERNAL_CRON_ROLE,
  INTERNAL_CRON_SESSION_ID,
  INTERNAL_CRON_TOKEN_HEADER,
  loadCommunicationCronConfig,
  verifyInternalCronToken,
} from "../../communication/communication_cron_auth.ts";
import { requirePriorityFeedScope } from "../priority/priority_handlers.ts";
import { type BriefPersona, loadDailyBrief } from "./brief_service.ts";

function parseBriefPersona(url: URL): BriefPersona | null {
  const raw = url.searchParams.get("persona") ?? "";
  return raw === "teacher" || raw === "principal" ? raw : null;
}

/** GET /intelligence/briefs/daily?persona=… */
export async function handleDailyBrief(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const persona = parseBriefPersona(new URL(req.url));
  if (!persona) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      "persona must be one of: teacher, principal",
      422,
    );
  }
  const denied = requirePriorityFeedScope(auth.claims, persona);
  if (denied) return denied;

  try {
    const brief = await withTenantContext(config, auth.claims, (db) =>
      loadDailyBrief(db, auth.claims, persona, new Date().toISOString()));
    return jsonResponse(envelope(brief));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load the daily brief", 500);
  }
}

// ─── Pre-warm ─────────────────────────────────────────────────────────────────

/** Synthetic school-scoped claims for the cron warm pass. The pulse loader
 * gates every source on claims.permissions, so the cron actor carries exactly
 * the view-side permissions a principal's pulse composes from — read-only,
 * one school at a time, RLS-scoped like any school session. */
function cronClaimsForSchool(orgId: string, schoolId: string): AccessTokenClaims {
  return {
    sub: INTERNAL_CRON_ACTOR_ID,
    tenant_id: orgId,
    organization_id: orgId,
    school_id: schoolId,
    role: INTERNAL_CRON_ROLE,
    role_slugs: [INTERNAL_CRON_ROLE],
    primary_role: INTERNAL_CRON_ROLE,
    permissions: [
      "viewAnalytics",
      "viewStudentRisk",
      "viewFinance",
      "viewInventory",
      "viewTransport",
      "viewHr",
      "viewLibrary",
    ],
    permissions_version: 0,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: INTERNAL_CRON_SESSION_ID,
  };
}

interface PrewarmSchoolResult {
  organizationId: string;
  schoolId: string;
  warmed: boolean;
  fromCache: boolean;
  error?: string;
}

async function warmSchoolPulse(
  config: AppConfig,
  orgId: string,
  schoolId: string,
): Promise<PrewarmSchoolResult> {
  const claims = cronClaimsForSchool(orgId, schoolId);
  try {
    const brief = await withTenantContext(config, claims, (db) =>
      loadDailyBrief(db, claims, "principal", new Date().toISOString()));
    return {
      organizationId: orgId,
      schoolId,
      warmed: brief.narrative !== null,
      fromCache: brief.narrativeFromCache,
    };
  } catch (error) {
    return {
      organizationId: orgId,
      schoolId,
      warmed: false,
      fromCache: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

/** Active orgs + their non-deleted schools, via the service client (the same
 * enumeration shape as the COM-4 cron sweep). */
async function listActiveSchools(
  config: AppConfig,
): Promise<Array<{ orgId: string; schoolId: string }>> {
  const client = createServiceClient(config);
  const orgs = await client
    .from("organizations")
    .select("id")
    .in("status", ["trial", "active"])
    .is("deleted_at", null);
  if (orgs.error) throw new Error(`organizations lookup failed: ${orgs.error.message}`);
  const orgIds = ((orgs.data ?? []) as { id: string }[]).map((r) => r.id);
  if (orgIds.length === 0) return [];

  const schools = await client
    .from("schools")
    .select("id, organization_id")
    .in("organization_id", orgIds)
    .is("deleted_at", null);
  if (schools.error) throw new Error(`schools lookup failed: ${schools.error.message}`);
  return ((schools.data ?? []) as { id: string; organization_id: string }[])
    .map((r) => ({ orgId: r.organization_id, schoolId: r.id }));
}

/** POST /intelligence/briefs/prewarm */
export async function handleBriefPrewarm(req: Request, config: AppConfig): Promise<Response> {
  // Internal-cron path: fail-closed token check, then the all-schools sweep.
  const cronToken = req.headers.get(INTERNAL_CRON_TOKEN_HEADER);
  if (await verifyInternalCronToken(loadCommunicationCronConfig(), cronToken)) {
    let targets: Array<{ orgId: string; schoolId: string }>;
    try {
      targets = await listActiveSchools(config);
    } catch (_error) {
      return errorEnvelope(
        "INTERNAL_ERROR",
        "Failed to enumerate schools for the pre-warm sweep",
        500,
      );
    }
    const results: PrewarmSchoolResult[] = [];
    for (const t of targets) {
      results.push(await warmSchoolPulse(config, t.orgId, t.schoolId));
    }
    return jsonResponse(envelope({
      cron: true,
      schoolsConsidered: targets.length,
      warmed: results.filter((r) => r.warmed).length,
      failures: results.filter((r) => r.error).length,
      results,
    }));
  }

  // Staff path: warm the caller's own school (manual/testing).
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const scopeDenied = requireSchoolOperationalScope(auth.claims);
  if (scopeDenied) return scopeDenied;
  const denied = requirePermission(auth.claims, "viewAnalytics");
  if (denied) return denied;

  try {
    const brief = await withTenantContext(config, auth.claims, (db) =>
      loadDailyBrief(db, auth.claims, "principal", new Date().toISOString()));
    return jsonResponse(envelope({
      cron: false,
      warmed: brief.narrative !== null,
      fromCache: brief.narrativeFromCache,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to pre-warm the daily brief", 500);
  }
}
