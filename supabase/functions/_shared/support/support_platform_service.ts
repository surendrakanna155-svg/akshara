// ASIP — Phase 2: support-side intelligence. DETERMINISTIC-FIRST clustering,
// cross-incident investigation and engineering-handoff export; a governed LLM
// call (via the gateway) only refines the narrative. "Investigate once, resolve
// many": incidents sharing a deterministic fingerprint join one cluster.

import { callModelGateway } from "../ai/model_gateway.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { safeParseEnrichment } from "./incident_package.ts";
import {
  type ClusterRow,
  linkIncidentToCluster,
  type PlatformEvidenceRow,
  type PlatformIncidentRow,
  type PlatformNoteRow,
  upsertCluster,
} from "./support_platform_repository.ts";

export interface MirrorDiagnostics {
  signals: string[];
  apiErrorCount: number;
  topErrorStatus: number | null;
  topErrorPath: string | null;
  failingCorrelationId: string | null;
}

const EMPTY_DIAG: MirrorDiagnostics = {
  signals: [],
  apiErrorCount: 0,
  topErrorStatus: null,
  topErrorPath: null,
  failingCorrelationId: null,
};

export function diagnosticsFromMirrorEvidence(rows: PlatformEvidenceRow[]): MirrorDiagnostics {
  const row = rows.find((r) => r.kind === "diagnostics");
  if (!row) return EMPTY_DIAG;
  const p = row.payload as Record<string, unknown>;
  return {
    signals: Array.isArray(p.signals) ? p.signals.filter((s): s is string => typeof s === "string") : [],
    apiErrorCount: Number(p.apiErrorCount ?? 0),
    topErrorStatus: typeof p.topErrorStatus === "number" ? p.topErrorStatus : null,
    topErrorPath: typeof p.topErrorPath === "string" ? p.topErrorPath : null,
    failingCorrelationId: typeof p.failingCorrelationId === "string" ? p.failingCorrelationId : null,
  };
}

/** A compact, deterministic signature of the failure signals. */
export function errorSignature(diag: MirrorDiagnostics): string {
  const parts: string[] = [];
  if (diag.signals.some((s) => s.includes("401"))) parts.push("401");
  if (diag.signals.some((s) => s.includes("403"))) parts.push("403");
  if (diag.signals.some((s) => s.includes("5xx"))) parts.push("5xx");
  if (diag.topErrorPath) parts.push(diag.topErrorPath);
  return parts.length ? parts.join(",") : "none";
}

/** Deterministic cluster key: same category + module + error-signature ⇒ one
 * shared incident, across every reporting school. */
export function clusterFingerprint(
  category: string,
  moduleKey: string | null,
  diag: MirrorDiagnostics,
): string {
  return `${category}|${moduleKey ?? "-"}|${errorSignature(diag)}`;
}

export function clusterTitle(
  category: string,
  moduleKey: string | null,
  diag: MirrorDiagnostics,
): string {
  const where = moduleKey ? ` in ${moduleKey}` : "";
  const sig = errorSignature(diag);
  const sigLabel = sig === "none" ? "" : ` (${sig})`;
  return `${category.replace(/_/g, "/")}${where}${sigLabel}`;
}

/** Compute the fingerprint, upsert the cluster, link the incident, refresh count. */
export async function autoCluster(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incident: PlatformIncidentRow,
  evidence: PlatformEvidenceRow[],
): Promise<ClusterRow> {
  const diag = diagnosticsFromMirrorEvidence(evidence);
  const key = clusterFingerprint(incident.category, incident.module_key, diag);
  const cluster = await upsertCluster(
    db,
    claims,
    key,
    clusterTitle(incident.category, incident.module_key, diag),
    incident.category,
    incident.module_key,
  );
  await linkIncidentToCluster(db, incident.id, cluster.id);
  return cluster;
}

// ─── Engineering handoff (deterministic export — no AI required) ───────────────

export interface EngineeringHandoff {
  incidentRef: string;
  category: string;
  severity: string;
  environment: {
    module: string | null;
    screenRoute: string | null;
    appVersion: string | null;
    platform: string | null;
  };
  reproduction: {
    failingCorrelationId: string | null;
    topErrorStatus: number | null;
    topErrorPath: string | null;
    signals: string[];
  };
  cluster: { id: string | null; affectedIncidents: number } | null;
  evidence: Record<string, unknown>;
  supportNotes: string[];
}

export function buildEngineeringHandoff(
  incident: PlatformIncidentRow,
  evidence: PlatformEvidenceRow[],
  notes: PlatformNoteRow[],
  clusterSize: number,
): EngineeringHandoff {
  const diag = diagnosticsFromMirrorEvidence(evidence);
  const evidenceMap: Record<string, unknown> = {};
  for (const e of evidence) evidenceMap[e.kind] = e.payload;
  return {
    incidentRef: incident.public_ref,
    category: incident.category,
    severity: incident.severity,
    environment: {
      module: incident.module_key,
      screenRoute: incident.screen_route,
      appVersion: incident.app_version,
      platform: incident.platform,
    },
    reproduction: {
      failingCorrelationId: diag.failingCorrelationId,
      topErrorStatus: diag.topErrorStatus,
      topErrorPath: diag.topErrorPath,
      signals: diag.signals,
    },
    cluster: incident.cluster_id
      ? { id: incident.cluster_id, affectedIncidents: clusterSize }
      : null,
    evidence: evidenceMap,
    supportNotes: notes.map((n) => n.body),
  };
}

// ─── Cross-incident AI investigation (deterministic + governed enrichment) ─────

export interface InvestigationResult {
  summary: string;
  likelyRootCause: string;
  recommendedFix: string;
  confidence: number;
  method: "deterministic" | "ai_enriched";
  model: string;
  clusterSize: number;
}

export function deterministicInvestigation(
  incident: PlatformIncidentRow,
  diag: MirrorDiagnostics,
  clusterSize: number,
): Omit<InvestigationResult, "method" | "model"> {
  const many = clusterSize > 1;
  const scope = many
    ? `${clusterSize} schools report this same signature`
    : "a single school reports this";
  let rootCause = "Needs engineering review of the evidence.";
  let fix = "Reproduce with the correlation id, then patch and verify.";
  if (diag.signals.some((s) => s.includes("403"))) {
    rootCause = `Permission/RBAC gap${diag.topErrorPath ? ` on ${diag.topErrorPath}` : ""} — the role lacks the required permission or a policy is too strict.`;
    fix = "Verify the role→permission grant and the RLS/handler check for this endpoint; add the missing grant or fix the policy.";
  } else if (diag.signals.some((s) => s.includes("401"))) {
    rootCause = "Session/token handling — expired or unrefreshed access token.";
    fix = "Confirm the token-refresh path and session validity for the affected accounts.";
  } else if (diag.signals.some((s) => s.includes("5xx"))) {
    rootCause = `Server-side error${diag.topErrorPath ? ` on ${diag.topErrorPath}` : ""}.`;
    fix = "Inspect the edge logs for the correlation id, reproduce the endpoint, and patch the failing handler/query.";
  }
  const confidence = Math.min(
    40 + (diag.apiErrorCount > 0 ? 20 : 0) + (many ? 20 : 0) + (incident.module_key ? 10 : 0),
    85,
  );
  return {
    summary: `${incident.category.replace(/_/g, "/")} issue${incident.module_key ? ` in ${incident.module_key}` : ""}; ${scope}.`,
    likelyRootCause: rootCause,
    recommendedFix: fix,
    confidence,
    clusterSize,
  };
}

export async function investigate(
  db: TenantQueryClient,
  gov: { organizationId: string; userId: string | null },
  incident: PlatformIncidentRow,
  evidence: PlatformEvidenceRow[],
  clusterSize: number,
): Promise<InvestigationResult> {
  const diag = diagnosticsFromMirrorEvidence(evidence);
  const base = deterministicInvestigation(incident, diag, clusterSize);

  const system =
    "You are an Akshara platform engineer triaging a software-support incident " +
    "cluster. Given a deterministic first-pass and minimized (PII-free) evidence, " +
    "refine ONLY the narrative. Do NOT invent data. Reply with strict JSON: " +
    '{"summary":string,"likelyRootCause":string,"suggestedNextSteps":string[],"confidence":number}.';
  const user =
    `category=${incident.category} module=${incident.module_key ?? "-"} severity=${incident.severity}\n` +
    `clusterSize=${clusterSize}\nsignals=${diag.signals.join("; ") || "none"}\n` +
    `topError=${diag.topErrorStatus ?? "-"} ${diag.topErrorPath ?? ""}\n` +
    `deterministic.rootCause=${base.likelyRootCause}\ndeterministic.fix=${base.recommendedFix}`;

  let model = "";
  let method: "deterministic" | "ai_enriched" = "deterministic";
  let summary = base.summary;
  let rootCause = base.likelyRootCause;
  let fix = base.recommendedFix;
  let confidence = base.confidence;

  try {
    const res = await callModelGateway(
      db,
      { organizationId: gov.organizationId, schoolId: null, userId: gov.userId, surface: "support_investigation" },
      { system, messages: [{ role: "user", content: user }], maxTokens: 600 },
      "",
    );
    if (res.ok && res.text) {
      const parsed = safeParseEnrichment(res.text);
      if (parsed) {
        method = "ai_enriched";
        model = res.model;
        summary = parsed.summary ?? summary;
        rootCause = parsed.likelyRootCause ?? rootCause;
        if (parsed.suggestedNextSteps && parsed.suggestedNextSteps.length > 0) {
          fix = parsed.suggestedNextSteps.join("; ");
        }
        confidence = parsed.confidence ?? confidence;
      }
    }
  } catch (_err) {
    // deterministic result stands
  }

  return { summary, likelyRootCause: rootCause, recommendedFix: fix, confidence, method, model, clusterSize };
}
