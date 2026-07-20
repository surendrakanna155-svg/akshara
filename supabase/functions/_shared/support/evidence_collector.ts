// ASIP — deterministic, PII-minimized evidence collector.
//
// "The platform automatically gathers technical evidence." This assembles the
// evidence snapshot at report time from (a) the structural context the client
// posts and (b) server-side enrichment (the reporter's recent audit events).
//
// Governance: SAFE DIAGNOSTICS ONLY. Free-text is redacted (emails, phones, long
// digit runs masked; length-capped); audit metadata is dropped (may carry
// names). The snapshot carries ids + structure + aggregates, never raw student
// PII (ASIP_DESIGN §5; Adaptive-AI doc 10 §4). The pure functions here are
// unit-testable without a DB.

import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { Breadcrumb, ClientContext, RecentApiCall } from "./support_types.ts";

const MAX_BREADCRUMBS = 40;
const MAX_API_CALLS = 40;
const MAX_TEXT = 200;

const EMAIL_RE = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g;
// 7+ consecutive digits (phones, Aadhaar, account numbers). UUIDs (hex+dashes)
// and short numbers (status codes, versions) are left intact.
const LONG_DIGITS_RE = /\d{7,}/g;

export interface Redaction<T> {
  value: T;
  redacted: boolean;
}

/** Mask likely-PII in a free-text string and cap its length. Returns whether any
 * masking/truncation happened so the snapshot can flag `redacted`. */
export function redactFreeText(input: string): Redaction<string> {
  let redacted = false;
  let out = input.replace(EMAIL_RE, () => {
    redacted = true;
    return "[email]";
  });
  out = out.replace(LONG_DIGITS_RE, () => {
    redacted = true;
    return "[number]";
  });
  if (out.length > MAX_TEXT) {
    out = out.slice(0, MAX_TEXT) + "…";
    redacted = true;
  }
  return { value: out, redacted };
}

function str(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const t = v.trim();
  return t.length === 0 ? null : t.slice(0, MAX_TEXT);
}

/** The technical fields lifted onto the incident row (the user typed none). */
export interface DerivedIncidentContext {
  appVersion: string | null;
  platform: string | null;
  deviceModel: string | null;
  osVersion: string | null;
  sessionId: string | null;
  screenRoute: string | null;
  moduleKey: string | null;
  correlationId: string | null;
}

export function deriveIncidentContext(ctx: ClientContext | undefined): DerivedIncidentContext {
  const c = ctx ?? {};
  const firstCorrelation = Array.isArray(c.correlationIds)
    ? c.correlationIds.map(str).find((x): x is string => x !== null) ?? null
    : null;
  return {
    appVersion: str(c.appVersion),
    platform: str(c.platform),
    deviceModel: str(c.deviceModel),
    osVersion: str(c.osVersion),
    sessionId: str(c.sessionId),
    screenRoute: str(c.screenRoute),
    moduleKey: str(c.moduleKey),
    correlationId: firstCorrelation,
  };
}

/** client_context evidence payload — purely technical, no redaction needed. */
export function buildClientContextEvidence(
  ctx: ClientContext | undefined,
): Redaction<Record<string, unknown>> {
  const d = deriveIncidentContext(ctx);
  const correlationIds = Array.isArray(ctx?.correlationIds)
    ? ctx!.correlationIds.map(str).filter((x): x is string => x !== null).slice(0, 20)
    : [];
  return {
    value: {
      appVersion: d.appVersion,
      platform: d.platform,
      deviceModel: d.deviceModel,
      osVersion: d.osVersion,
      sessionId: d.sessionId,
      screenRoute: d.screenRoute,
      moduleKey: d.moduleKey,
      correlationIds,
    },
    redacted: false,
  };
}

export function buildBreadcrumbsEvidence(
  ctx: ClientContext | undefined,
): Redaction<Record<string, unknown>> {
  const raw: Breadcrumb[] = Array.isArray(ctx?.breadcrumbs) ? ctx!.breadcrumbs : [];
  let redacted = false;
  const items = raw.slice(-MAX_BREADCRUMBS).map((b) => {
    const msg = str(b?.message);
    let safeMsg: string | null = null;
    if (msg) {
      const r = redactFreeText(msg);
      safeMsg = r.value;
      redacted = redacted || r.redacted;
    }
    return {
      type: str(b?.type),
      route: str(b?.route),
      message: safeMsg,
      at: str(b?.at),
    };
  });
  return { value: { count: items.length, items }, redacted };
}

export function buildApiCallsEvidence(
  ctx: ClientContext | undefined,
): Redaction<Record<string, unknown>> {
  const raw: RecentApiCall[] = Array.isArray(ctx?.recentApiCalls) ? ctx!.recentApiCalls : [];
  const items = raw.slice(-MAX_API_CALLS).map((a) => ({
    method: str(a?.method),
    path: str(a?.path),
    statusCode: typeof a?.statusCode === "number" ? a.statusCode : null,
    correlationId: str(a?.correlationId),
    at: str(a?.at),
  }));
  const errors = items.filter((i) => (i.statusCode ?? 0) >= 400).length;
  return { value: { count: items.length, errorCount: errors, items }, redacted: false };
}

interface AuditEvidenceRow {
  event_type: string;
  category: string;
  entity_type: string | null;
  entity_id: string | null;
  correlation_id: string | null;
  created_at: string;
}

/** Server-side enrichment: the reporter's most recent tenant audit events,
 * minimized (metadata + entity_id dropped — keep only structural signals).
 *
 * Self-contained (queries audit_events directly on the RLS-enforced erp_tenant
 * client) and BEST-EFFORT: if the deployed base has no tenant-read grant/policy
 * on audit_events, the read simply yields no evidence rather than failing the
 * report. Keeps ASIP deployable on any base without depending on a read helper
 * that may not exist there. */
export async function collectAuditEvidence(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  reporterUserId: string,
): Promise<Redaction<Record<string, unknown>>> {
  let rows: AuditEvidenceRow[] = [];
  try {
    rows = await db.queryObject<AuditEvidenceRow>(
      `SELECT event_type, category, entity_type, entity_id, correlation_id, created_at
         FROM audit_events
        WHERE organization_id = $1 AND user_id = $2::uuid
        ORDER BY created_at DESC, id DESC
        LIMIT 25`,
      [claims.tenant_id, reporterUserId],
    );
  } catch (_err) {
    rows = []; // audit read unavailable on this base → best-effort skip
  }
  const items = rows.map((e) => ({
    eventType: e.event_type,
    category: e.category,
    entityType: e.entity_type,
    hasEntity: e.entity_id !== null,
    correlationId: e.correlation_id,
    createdAt: e.created_at,
  }));
  // redacted: we deliberately dropped metadata/entity_id to honor minimization.
  return { value: { count: items.length, items }, redacted: rows.length > 0 };
}

// ─── Deterministic diagnostics summary ────────────────────────────────────────

export interface DiagnosticsInput {
  appVersion: string | null;
  platform: string | null;
  moduleKey: string | null;
  screenRoute: string | null;
  correlationId: string | null;
  apiCalls: { statusCode: number | null; path: string | null; correlationId: string | null }[];
  auditCount: number;
  breadcrumbCount: number;
}

export interface Diagnostics {
  failingCorrelationId: string | null;
  apiErrorCount: number;
  topErrorStatus: number | null;
  topErrorPath: string | null;
  hasAppVersion: boolean;
  signals: string[];
}

/** Pure: turn the collected parts into a small deterministic diagnostics object
 * (the backbone the AI Incident Package reasons over, LLM or not). */
export function buildDiagnostics(input: DiagnosticsInput): Diagnostics {
  const errors = input.apiCalls.filter((c) => (c.statusCode ?? 0) >= 400);
  const topError = errors[errors.length - 1] ?? null; // most recent error
  const signals: string[] = [];

  if (errors.length > 0) {
    signals.push(`${errors.length} recent API error(s)`);
  }
  const has401 = errors.some((e) => e.statusCode === 401);
  const has403 = errors.some((e) => e.statusCode === 403);
  const has5xx = errors.some((e) => (e.statusCode ?? 0) >= 500);
  if (has401) signals.push("recent 401 (authentication)");
  if (has403) signals.push("recent 403 (permission/RBAC)");
  if (has5xx) signals.push("recent 5xx (server error)");
  if (!input.appVersion) signals.push("app version not reported");
  if (input.moduleKey) signals.push(`module: ${input.moduleKey}`);

  return {
    failingCorrelationId: input.correlationId ??
      topError?.correlationId ?? null,
    apiErrorCount: errors.length,
    topErrorStatus: topError?.statusCode ?? null,
    topErrorPath: topError?.path ?? null,
    hasAppVersion: input.appVersion !== null,
    signals,
  };
}
