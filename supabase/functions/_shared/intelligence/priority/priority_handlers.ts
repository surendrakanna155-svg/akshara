// Adaptive AI — P3-AI-2 / W2.0a: the per-persona Priority Feed route handler.
//
// GET /intelligence/priorities?persona=<principal|finance|director|admin>&limit=N
//
// Deterministic, Tier-1, ZERO model calls (doc 04 §3.3): it loads the existing
// analytics + student-risk intelligence the caller is PERMITTED to read, turns
// those numbers into typed priority items (priority_sources), and scores them
// through the pure engine (priority_engine). RBAC is the real wall — a generator
// whose permission the caller lacks simply contributes nothing, and the feed is
// flagged `degraded` so the subset is honest. No new table; no clock in scoring.

import type { AppConfig } from "../../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../../tenant_handlers.ts";
import { computeAnalyticsBundle } from "../../analytics/analytics_repository.ts";
import { listRiskSnapshots } from "../student_risk_repository.ts";
import { buildFeed } from "./priority_engine.ts";
import { collectRawItems, type PrioritySourceInputs } from "./priority_sources.ts";
import { isPersona, type Persona, W2_0_SUPPORTED_PERSONAS } from "./priority_types.ts";

function isSupportedPersona(p: Persona): boolean {
  return W2_0_SUPPORTED_PERSONAS.includes(p);
}

function parseLimit(raw: string | null): number {
  const n = Number.parseInt(raw ?? "", 10);
  if (!Number.isFinite(n) || n <= 0) return 20;
  return Math.min(50, n);
}

/** GET /intelligence/priorities — the W2.0 per-persona priority feed. */
export async function handlePriorityFeed(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  // Any authenticated user with a school operational scope may request a feed;
  // WHAT they see is bounded per-generator by their real read permissions.
  const denied = requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const personaParam = (url.searchParams.get("persona") ?? "principal").toLowerCase();
  if (!isPersona(personaParam) || !isSupportedPersona(personaParam)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `persona must be one of: ${W2_0_SUPPORTED_PERSONAS.join(", ")} ` +
        `(per-user personas ship in their rollout wave)`,
      422,
    );
  }
  const persona: Persona = personaParam;
  const limit = parseLimit(url.searchParams.get("limit"));

  // Permission gates (the RBAC pre-filter, doc 02 §5): only load what the caller
  // could read via the normal APIs. A director never loads per-student rows.
  const perms = auth.claims.permissions;
  const canViewAnalytics = perms.includes("viewAnalytics");
  const canViewRisk = persona !== "director" &&
    (perms.includes("viewStudentRisk") || perms.includes("viewAnalytics"));

  try {
    const orgId = organizationIdFromClaims(auth.claims);
    const schoolId = schoolIdFromClaims(auth.claims)!;

    const inputs = await withTenantContext(config, auth.claims, async (db) => {
      const assembled: PrioritySourceInputs = {};
      if (canViewAnalytics) {
        const bundle = await computeAnalyticsBundle(db, orgId, schoolId);
        assembled.analytics = {
          dashboard: {
            attendanceRiskScore: bundle.dashboard.attendanceRiskScore,
            feeCollectionRisk: bundle.dashboard.feeCollectionRisk,
            timetableHealthScore: bundle.dashboard.timetableHealthScore,
          },
          risks: bundle.risks.map((r) => ({
            key: r.id,
            label: r.label,
            score: r.score,
            level: r.level,
            detail: r.detail,
          })),
        };
      }
      if (canViewRisk) {
        const snapshots = await listRiskSnapshots(db, {});
        assembled.riskSnapshots = snapshots.map((s) => ({
          studentId: s.student_id,
          className: s.class_name,
          sectionName: s.section_name,
          riskScore: s.risk_score,
          riskLevel: s.risk_level,
        }));
      }
      return assembled;
    });

    // `degraded` = a source was skipped for lack of permission, so this feed is
    // a subset of what a fully-permitted caller would see. Director intentionally
    // has no risk source, so its absence is not "degraded".
    const degraded = !canViewAnalytics || (persona !== "director" && !canViewRisk);

    const rawItems = collectRawItems(inputs);
    const feed = buildFeed(rawItems, persona, new Date().toISOString(), { limit });

    return jsonResponse(envelope({ ...feed, degraded }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    const message = error instanceof Error ? error.message : "Failed to build priority feed";
    return errorEnvelope("INTERNAL_ERROR", message, 500);
  }
}
