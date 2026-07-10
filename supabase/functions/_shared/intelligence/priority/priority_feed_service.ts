// Adaptive AI — P3-AI-2 / W2.0: shared persona-feed loader.
//
// The one place that turns a request into a scored, personalized feed context,
// used by BOTH the raw priority route (W2.0a) and the recommendation route
// (W2.0b) so RBAC gating, source loading, and persona-memory application live
// in exactly one spot. Runs INSIDE an existing tenant transaction (RLS applied).
// Deterministic, zero model calls.

import type { AccessTokenClaims } from "../../jwt.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import { organizationIdFromClaims, schoolIdFromClaims } from "../../permission_middleware.ts";
import { computeAnalyticsBundle } from "../../analytics/analytics_repository.ts";
import { listRiskSnapshots } from "../student_risk_repository.ts";
import {
  deriveLearnedWeights,
  dismissedKeysOf,
  getPersonaMemory,
} from "../../ai/ai_persona_memory_repository.ts";
import { collectRawItems, type PrioritySourceInputs } from "./priority_sources.ts";
import { loadTeacherFeedSources } from "./teacher_sources.ts";
import { loadParentFeedSources } from "./parent_sources.ts";
import type { LearnedWeights, Persona, RawPriorityItem } from "./priority_types.ts";

export interface PersonaFeedContext {
  persona: Persona;
  rawItems: RawPriorityItem[];
  weights: LearnedWeights;
  dismissedKeys: Set<string>;
  /** A source was skipped for lack of permission → this feed is a subset. */
  degraded: boolean;
}

interface RawSourceResult {
  rawItems: RawPriorityItem[];
  degraded: boolean;
}

/** School-scoped / aggregate personas (principal, finance, director, admin):
 * the W2.0a analytics + student-risk sources, each loaded ONLY if the caller
 * holds its permission (RBAC is the real wall, doc 02 §5 — a director never
 * loads per-student rows). */
async function loadSchoolFeedSources(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  persona: Persona,
): Promise<RawSourceResult> {
  const orgId = organizationIdFromClaims(claims);
  const schoolId = schoolIdFromClaims(claims);
  const perms = claims.permissions;

  const canViewAnalytics = perms.includes("viewAnalytics");
  const canViewRisk = persona !== "director" &&
    (perms.includes("viewStudentRisk") || perms.includes("viewAnalytics"));

  const inputs: PrioritySourceInputs = {};
  if (canViewAnalytics) {
    const bundle = await computeAnalyticsBundle(db, orgId, schoolId);
    inputs.analytics = {
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
    inputs.riskSnapshots = snapshots.map((s) => ({
      studentId: s.student_id,
      className: s.class_name,
      sectionName: s.section_name,
      riskScore: s.risk_score,
      riskLevel: s.risk_level,
    }));
  }

  return {
    rawItems: collectRawItems(inputs),
    // Director intentionally has no risk source, so its absence is not degraded.
    degraded: !canViewAnalytics || (persona !== "director" && !canViewRisk),
  };
}

/** The one place that turns a request into a scored-feed context, for BOTH the
 * priority route and the recommendation route. Dispatches raw-item collection by
 * persona class (school-aggregate vs. per-user-scoped), then applies the shared
 * Persona-Memory tail (learned weights + dismissed keys) uniformly — memory is
 * keyed on `claims.sub`, so the tail is identical for every persona. Runs INSIDE
 * an existing tenant transaction (RLS applied). Deterministic, zero model calls. */
export async function loadPersonaFeedContext(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  persona: Persona,
  nowIso: string,
): Promise<PersonaFeedContext> {
  const orgId = organizationIdFromClaims(claims);
  const schoolId = schoolIdFromClaims(claims);

  const sources: RawSourceResult = persona === "teacher"
    ? await loadTeacherFeedSources(db, claims, nowIso)
    : persona === "parent"
    ? await loadParentFeedSources(db, claims, nowIso)
    : await loadSchoolFeedSources(db, claims, persona);

  // Persona memory personalizes ordering (learned weights) and hides dismissed
  // items. Best-effort: an empty/absent row yields neutral defaults, so the feed
  // is identical to the un-personalized one for a first-time user.
  const memory = await getPersonaMemory(db, { organizationId: orgId, schoolId, userId: claims.sub });

  return {
    persona,
    rawItems: sources.rawItems,
    weights: deriveLearnedWeights(memory),
    dismissedKeys: dismissedKeysOf(memory),
    degraded: sources.degraded,
  };
}
