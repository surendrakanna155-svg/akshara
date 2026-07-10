// Advanced AI Predictions (B9) — school-scoped HTTP handlers.
//
// Three read endpoints, each gated by the natural domain-view permission
// (fee-default → viewFinance, admission-conversion → viewAdmissions,
// student-risk → viewStudentRisk) and scoped to the caller's school via
// `withTenantContext` (RLS is the boundary). The whole router additionally sits
// behind the `feature.ai_predictions` entitlement (registered in api/index.ts).
//
// Each response carries the deterministic prediction list plus an optional AI
// narrative that safely falls back to a deterministic baseline when no AI key is
// configured. No numbers are ever invented — the scorers own every figure.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { resolveAiConfig } from "../ai/ai_settings.ts";
import {
  type AdmissionConversionPrediction,
  buildPredictionsBaseline,
  computeAdmissionConversion,
  computeFeeDefaultRisk,
  computeStudentRiskList,
  type FeeDefaultPrediction,
  type StudentRiskPrediction,
} from "./predictions_service.ts";
import { narratePredictionsWithClaude } from "./predictions_ai.ts";

function failure(error: unknown, message: string): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  console.error(`${message}:`, error);
  return errorEnvelope("INTERNAL_ERROR", message, 500);
}

const HIGH = new Set(["high", "critical"]);

async function readScoped(
  req: Request,
  config: AppConfig,
  permission: string,
  message: string,
  run: (
    db: Parameters<Parameters<typeof withTenantContext>[2]>[0],
    orgId: string,
    schoolId: string,
    claims: AccessTokenClaims,
  ) => Promise<unknown>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, permission);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  let schoolId: string;
  try {
    schoolId = schoolIdFromClaims(auth.claims);
  } catch {
    return errorEnvelope("FORBIDDEN", "Predictions require a school-scoped token", 403);
  }
  try {
    const data = await withTenantContext(
      config,
      auth.claims,
      (db) => run(db, orgId, schoolId, auth.claims),
    );
    return jsonResponse(envelope(data));
  } catch (error) {
    return failure(error, message);
  }
}

export function handleFeeDefault(req: Request, config: AppConfig): Promise<Response> {
  return readScoped(req, config, "viewFinance", "Failed to predict fee defaults",
    async (db, orgId, schoolId, claims) => {
      const items = await computeFeeDefaultRisk(db, orgId, schoolId);
      const narrative = await narrate(db, orgId, schoolId, claims.sub, "fee-default", items,
        items.map((i) => ({ name: i.studentName, metric: `₹${i.outstandingInr}, ${i.daysOverdue}d overdue` })),
        (i: FeeDefaultPrediction) => i.riskLevel);
      return { items, narrative };
    });
}

export function handleAdmissionConversion(req: Request, config: AppConfig): Promise<Response> {
  return readScoped(req, config, "viewAdmissions", "Failed to predict admission conversion",
    async (db, orgId, schoolId, claims) => {
      const items = await computeAdmissionConversion(db, orgId, schoolId);
      // "high priority" for conversion = high likelihood worth chasing now.
      const high = items.filter((i) => i.band === "hot").length;
      const narrative = await narrateWithCount(db, orgId, schoolId, claims.sub, "admission-conversion", items.length, high,
        items.slice(0, 3).map((i) => ({ name: i.studentName, metric: `${i.likelihood}% likely` })));
      return { items, narrative };
    });
}

export function handleStudentRisk(req: Request, config: AppConfig): Promise<Response> {
  return readScoped(req, config, "viewStudentRisk", "Failed to predict student risk",
    async (db, orgId, schoolId, claims) => {
      const items = await computeStudentRiskList(db, orgId, schoolId);
      const narrative = await narrate(db, orgId, schoolId, claims.sub, "student-risk", items,
        items.map((i) => ({ name: i.studentName, metric: `${i.riskScore} (${i.topReason})` })),
        (i: StudentRiskPrediction) => i.riskLevel);
      return { items, narrative };
    });
}

/** Narrative for lists that carry a `riskLevel` (fee-default, student-risk). */
async function narrate(
  db: Parameters<Parameters<typeof withTenantContext>[2]>[0],
  orgId: string,
  schoolId: string,
  userId: string | null,
  kind: "fee-default" | "student-risk",
  items: Array<FeeDefaultPrediction | StudentRiskPrediction>,
  topItems: { name: string; metric: string }[],
  level: (i: never) => string,
): Promise<string> {
  const high = items.filter((i) => HIGH.has(level(i as never))).length;
  return narrateWithCount(db, orgId, schoolId, userId, kind, items.length, high, topItems.slice(0, 3));
}

async function narrateWithCount(
  db: Parameters<Parameters<typeof withTenantContext>[2]>[0],
  orgId: string,
  schoolId: string,
  userId: string | null,
  kind: "fee-default" | "admission-conversion" | "student-risk",
  total: number,
  high: number,
  topItems: { name: string; metric: string }[],
): Promise<string> {
  const baseline = buildPredictionsBaseline(kind, { total, high }, topItems.map((t) => t.name));
  const ai = await resolveAiConfig(db, orgId);
  return narratePredictionsWithClaude(
    baseline,
    { kind, total, high, topItems },
    ai.apiKey,
    { provider: ai.provider, model: ai.model },
    { db, organizationId: orgId, schoolId, userId },
  );
}

// re-exported types kept for any downstream import convenience
export type { AdmissionConversionPrediction, FeeDefaultPrediction, StudentRiskPrediction };
