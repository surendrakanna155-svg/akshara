// ASIP — orchestration between the deterministic collector/package and the
// repository. Kept separate from the HTTP handlers so the collection + analysis
// flows are unit-testable with an in-memory TenantQueryClient.

import type { AccessTokenClaims } from "../jwt.ts";
import type { AppConfig } from "../config.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildApiCallsEvidence,
  buildBreadcrumbsEvidence,
  buildClientContextEvidence,
  buildDiagnostics,
  collectAuditEvidence,
  deriveIncidentContext,
  type DerivedIncidentContext,
  type Diagnostics,
  type Redaction,
} from "./evidence_collector.ts";
import {
  assembleDeterministic,
  enrichWithModel,
  type IncidentSummaryInput,
  sha256Hex,
} from "./incident_package.ts";
import {
  insertAnalysis,
  insertEvidence,
  nextAnalysisVersion,
} from "./support_repository.ts";
import type { AnalysisRow, ClientContext, EvidenceRow, IncidentRow } from "./support_types.ts";

export interface EvidenceParts {
  derived: DerivedIncidentContext;
  clientContextEv: Redaction<Record<string, unknown>>;
  breadcrumbEv: Redaction<Record<string, unknown>>;
  apiCallsEv: Redaction<Record<string, unknown>>;
  auditEv: Redaction<Record<string, unknown>>;
  diagnostics: Diagnostics;
}

/** Assemble every evidence part deterministically (one audit read; no writes). */
export async function buildEvidenceParts(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  context: ClientContext | undefined,
  reporterUserId: string,
): Promise<EvidenceParts> {
  const derived = deriveIncidentContext(context);
  const clientContextEv = buildClientContextEvidence(context);
  const breadcrumbEv = buildBreadcrumbsEvidence(context);
  const apiCallsEv = buildApiCallsEvidence(context);
  const auditEv = await collectAuditEvidence(db, claims, reporterUserId);

  const apiItems = (apiCallsEv.value.items as Array<Record<string, unknown>>).map((i) => ({
    statusCode: typeof i.statusCode === "number" ? i.statusCode : null,
    path: typeof i.path === "string" ? i.path : null,
    correlationId: typeof i.correlationId === "string" ? i.correlationId : null,
  }));

  const diagnostics = buildDiagnostics({
    appVersion: derived.appVersion,
    platform: derived.platform,
    moduleKey: derived.moduleKey,
    screenRoute: derived.screenRoute,
    correlationId: derived.correlationId,
    apiCalls: apiItems,
    auditCount: Number(auditEv.value.count ?? 0),
    breadcrumbCount: Number(breadcrumbEv.value.count ?? 0),
  });

  return { derived, clientContextEv, breadcrumbEv, apiCallsEv, auditEv, diagnostics };
}

/** Persist the five evidence rows for an incident (append-only snapshot). */
export async function persistEvidence(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incidentId: string,
  parts: EvidenceParts,
): Promise<void> {
  await insertEvidence(db, claims, incidentId, {
    kind: "client_context",
    payload: parts.clientContextEv.value,
    redacted: parts.clientContextEv.redacted,
  });
  await insertEvidence(db, claims, incidentId, {
    kind: "breadcrumbs",
    payload: parts.breadcrumbEv.value,
    redacted: parts.breadcrumbEv.redacted,
  });
  await insertEvidence(db, claims, incidentId, {
    kind: "api_calls",
    payload: parts.apiCallsEv.value,
    redacted: parts.apiCallsEv.redacted,
  });
  await insertEvidence(db, claims, incidentId, {
    kind: "audit_events",
    payload: parts.auditEv.value,
    redacted: parts.auditEv.redacted,
  });
  await insertEvidence(db, claims, incidentId, {
    kind: "diagnostics",
    payload: diagnosticsToPayload(parts.diagnostics),
    redacted: false,
  });
}

function diagnosticsToPayload(d: Diagnostics): Record<string, unknown> {
  return {
    failingCorrelationId: d.failingCorrelationId,
    apiErrorCount: d.apiErrorCount,
    topErrorStatus: d.topErrorStatus,
    topErrorPath: d.topErrorPath,
    hasAppVersion: d.hasAppVersion,
    signals: d.signals,
  };
}

const EMPTY_DIAGNOSTICS: Diagnostics = {
  failingCorrelationId: null,
  apiErrorCount: 0,
  topErrorStatus: null,
  topErrorPath: null,
  hasAppVersion: false,
  signals: [],
};

/** Reconstruct Diagnostics from the stored `diagnostics` evidence row. */
export function diagnosticsFromEvidence(rows: EvidenceRow[]): Diagnostics {
  const row = rows.find((r) => r.kind === "diagnostics");
  if (!row) return EMPTY_DIAGNOSTICS;
  const p = row.payload as Record<string, unknown>;
  return {
    failingCorrelationId: typeof p.failingCorrelationId === "string" ? p.failingCorrelationId : null,
    apiErrorCount: Number(p.apiErrorCount ?? 0),
    topErrorStatus: typeof p.topErrorStatus === "number" ? p.topErrorStatus : null,
    topErrorPath: typeof p.topErrorPath === "string" ? p.topErrorPath : null,
    hasAppVersion: p.hasAppVersion === true,
    signals: Array.isArray(p.signals) ? p.signals.filter((s): s is string => typeof s === "string") : [],
  };
}

export function incidentToSummary(incident: IncidentRow): IncidentSummaryInput {
  return {
    title: incident.title,
    description: incident.description,
    reporterRole: incident.reporter_role,
    moduleKey: incident.module_key,
    screenRoute: incident.screen_route,
    platform: incident.platform,
    appVersion: incident.app_version,
  };
}

/** A short, PII-free evidence summary handed to the (optional) model. */
export function minimizedEvidenceSummary(
  diagnostics: Diagnostics,
  evidenceRows: EvidenceRow[],
): string {
  const audit = evidenceRows.find((r) => r.kind === "audit_events");
  const auditCount = audit ? Number((audit.payload as Record<string, unknown>).count ?? 0) : 0;
  return [
    `signals: ${diagnostics.signals.join("; ") || "none"}`,
    `apiErrors: ${diagnostics.apiErrorCount}`,
    `topError: ${diagnostics.topErrorStatus ?? "-"} ${diagnostics.topErrorPath ?? ""}`.trim(),
    `recentAuditEvents: ${auditCount}`,
    `failingCorrelationId: ${diagnostics.failingCorrelationId ?? "-"}`,
  ].join("\n");
}

/**
 * Assemble the AI Incident Package (deterministic + optional governed
 * enrichment) and persist a new analysis version. The model call, if any, runs
 * through the governed gateway on the SAME tenant transaction (spend cap, rate
 * limit, ai_call_log). Returns the persisted row.
 */
export async function runAnalysis(
  config: AppConfig,
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  incident: IncidentRow,
  evidenceRows: EvidenceRow[],
): Promise<AnalysisRow> {
  const diagnostics = diagnosticsFromEvidence(evidenceRows);
  const summaryInput = incidentToSummary(incident);
  const base = assembleDeterministic(summaryInput, diagnostics);
  const minimized = minimizedEvidenceSummary(diagnostics, evidenceRows);
  const digest = await sha256Hex(
    JSON.stringify(evidenceRows.map((e) => ({ kind: e.kind, payload: e.payload }))),
  );

  // Enrichment runs in its OWN transaction (inside enrichWithModel) so a
  // gateway-side error can never abort this analysis-write transaction.
  const enriched = await enrichWithModel(config, claims, base, summaryInput, minimized);

  const version = await nextAnalysisVersion(db, claims, incident.id);
  return await insertAnalysis(db, claims, incident.id, version, {
    categorization: enriched.categorization,
    severitySuggestion: enriched.severitySuggestion,
    summary: enriched.summary,
    likelyRootCause: enriched.likelyRootCause,
    suggestedNextSteps: enriched.suggestedNextSteps,
    confidence: enriched.confidence,
    method: enriched.method,
    model: enriched.model,
    evidenceDigest: digest,
  });
}
