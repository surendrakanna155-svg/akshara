// ASIP — AI Incident Package assembly. DETERMINISTIC-FIRST: categorization,
// severity suggestion, summary, likely root cause and next steps are computed
// from rules + evidence. A governed LLM call (via the gateway — spend cap, rate
// limit, cache, timeout, telemetry, deterministic fallback for free) then
// OPTIONALLY refines the narrative. The package is always complete even when the
// model declines. AI produces a DRAFT; a human approves it (never auto-applied).

import { callModelGateway } from "../ai/model_gateway.ts";
import { withTenantContext } from "../tenant_db.ts";
import type { AppConfig } from "../config.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { Diagnostics } from "./evidence_collector.ts";
import type { SupportCategory, SupportSeverity } from "./support_types.ts";

export interface IncidentSummaryInput {
  title: string;
  description: string;
  reporterRole: string;
  moduleKey: string | null;
  screenRoute: string | null;
  platform: string | null;
  appVersion: string | null;
}

export interface DeterministicPackage {
  categorization: { category: SupportCategory; signals: string[] };
  severitySuggestion: SupportSeverity;
  summary: string;
  likelyRootCause: string;
  suggestedNextSteps: string[];
  confidence: number;
}

interface CategoryRule {
  category: SupportCategory;
  keywords: string[];
  /** boosted when this diagnostics signal fragment is present */
  signal?: (d: Diagnostics) => boolean;
}

// Priority order: the FIRST rule that matches (keyword OR signal) wins the
// category; signals from all rules are collected for explainability.
const CATEGORY_RULES: CategoryRule[] = [
  { category: "crash", keywords: ["crash", "crashed", "froze", "frozen", "hang", "hung", "white screen", "blank screen", "closed itself", "force close"] },
  { category: "login_auth", keywords: ["login", "log in", "sign in", "signin", "otp", "password", "logged out", "can't log", "cannot log", "authenticat"], signal: (d) => d.signals.some((s) => s.includes("401")) },
  { category: "permission_rbac", keywords: ["permission", "access denied", "forbidden", "not allowed", "can't see", "cannot see", "no access", "unauthor"], signal: (d) => d.signals.some((s) => s.includes("403")) },
  { category: "payment_billing", keywords: ["payment", "pay ", "fee", "invoice", "refund", "transaction", "paid", "billing", "receipt"] },
  { category: "sync_offline", keywords: ["sync", "offline", "not updating", "old data", "stale", "not refreshing"] },
  { category: "data_incorrect", keywords: ["wrong", "incorrect", "mismatch", "not showing", "missing data", "duplicate", "not saved", "disappeared"] },
  { category: "performance", keywords: ["slow", "lag", "laggy", "timeout", "timed out", "stuck loading", "spinner", "takes too long"], signal: (d) => d.signals.some((s) => s.includes("5xx")) },
  { category: "notification", keywords: ["notification", "alert", "reminder", "push", "not notified"] },
  { category: "ui_display", keywords: ["button", "layout", "overlap", "cut off", "cutoff", "misaligned", "display", "screen looks", "not visible", "color", "font"] },
  { category: "missing_feature", keywords: ["can't find", "cannot find", "no option", "how do i", "how to", "where is", "feature request", "would be nice"] },
];

const COSMETIC_KEYWORDS = ["color", "font", "typo", "spelling", "align", "alignment", "cosmetic", "looks odd"];

export function categorize(
  input: IncidentSummaryInput,
  diagnostics: Diagnostics,
): { category: SupportCategory; signals: string[] } {
  const text = `${input.title}\n${input.description}`.toLowerCase();
  const signals: string[] = [...diagnostics.signals];
  let chosen: SupportCategory = "unknown";
  for (const rule of CATEGORY_RULES) {
    const kw = rule.keywords.find((k) => text.includes(k));
    const sig = rule.signal?.(diagnostics) ?? false;
    if (kw || sig) {
      if (chosen === "unknown") chosen = rule.category;
      if (kw) signals.push(`keyword: "${kw}"`);
    }
  }
  return { category: chosen, signals: Array.from(new Set(signals)) };
}

export function suggestSeverity(
  category: SupportCategory,
  diagnostics: Diagnostics,
  text: string,
): SupportSeverity {
  const lower = text.toLowerCase();
  const widespread = /(all users|everyone|whole school|entire school|nobody can|no one can|all staff)/.test(lower);
  const has5xx = diagnostics.signals.some((s) => s.includes("5xx"));

  if ((category === "crash" && (has5xx || widespread)) ||
      (category === "payment_billing" && has5xx) ||
      (category === "login_auth" && widespread)) {
    return "sev1";
  }
  if (["crash", "login_auth", "permission_rbac", "payment_billing"].includes(category)) {
    return "sev2";
  }
  if (category === "ui_display" && COSMETIC_KEYWORDS.some((k) => lower.includes(k))) {
    return "sev4";
  }
  return "sev3";
}

export function assembleDeterministic(
  input: IncidentSummaryInput,
  diagnostics: Diagnostics,
): DeterministicPackage {
  const { category, signals } = categorize(input, diagnostics);
  const severity = suggestSeverity(category, diagnostics, `${input.title} ${input.description}`);

  const where = input.moduleKey
    ? `module "${input.moduleKey}"`
    : (input.screenRoute ? `screen "${input.screenRoute}"` : "an unspecified screen");
  const errorClause = diagnostics.apiErrorCount > 0
    ? ` ${diagnostics.apiErrorCount} recent API error(s)${diagnostics.topErrorStatus ? ` (last: ${diagnostics.topErrorStatus}${diagnostics.topErrorPath ? ` ${diagnostics.topErrorPath}` : ""})` : ""}.`
    : " No recent API errors captured.";
  const summary =
    `${category.replace(/_/g, "/")} issue reported by ${input.reporterRole || "a user"} on ${where}.${errorClause}`;

  const rootCause = deterministicRootCause(category, diagnostics);
  const nextSteps = deterministicNextSteps(category, diagnostics, input);

  let confidence = 40;
  if (category !== "unknown") confidence += 15;
  if (diagnostics.apiErrorCount > 0) confidence += 15;
  if (input.moduleKey) confidence += 10;
  if (diagnostics.failingCorrelationId) confidence += 10;
  confidence = Math.min(confidence, 85);

  return {
    categorization: { category, signals },
    severitySuggestion: severity,
    summary,
    likelyRootCause: rootCause,
    suggestedNextSteps: nextSteps,
    confidence,
  };
}

function deterministicRootCause(category: SupportCategory, d: Diagnostics): string {
  const cid = d.failingCorrelationId ? ` (correlation ${d.failingCorrelationId})` : "";
  if (d.signals.some((s) => s.includes("403"))) {
    return `Recent 403 responses${d.topErrorPath ? ` on ${d.topErrorPath}` : ""} suggest a permissions/RBAC gap for this user${cid}.`;
  }
  if (d.signals.some((s) => s.includes("401"))) {
    return `Recent 401 responses suggest an expired/invalid session — re-auth or token refresh${cid}.`;
  }
  if (d.signals.some((s) => s.includes("5xx"))) {
    return `Recent 5xx${d.topErrorPath ? ` on ${d.topErrorPath}` : ""} suggests a server-side error; inspect edge logs${cid}.`;
  }
  if (category === "crash") {
    return `Client-side crash with no captured API error; inspect client breadcrumbs and logs${cid}.`;
  }
  return "Insufficient deterministic signal; needs support review of the evidence and screenshot.";
}

function deterministicNextSteps(
  category: SupportCategory,
  d: Diagnostics,
  input: IncidentSummaryInput,
): string[] {
  const steps: string[] = ["Review the attached screenshot/recording."];
  if (d.failingCorrelationId) {
    steps.push(`Search edge logs for correlation id ${d.failingCorrelationId}.`);
  }
  if (category === "permission_rbac" || d.signals.some((s) => s.includes("403"))) {
    steps.push(`Verify the reporter's role permissions${input.moduleKey ? ` for ${input.moduleKey}` : ""}.`);
  }
  if (d.signals.some((s) => s.includes("5xx"))) {
    steps.push("Check the edge function logs and DB for the failing endpoint.");
  }
  if (category === "login_auth" || d.signals.some((s) => s.includes("401"))) {
    steps.push("Confirm session/token refresh behavior for this account.");
  }
  steps.push(`Reproduce on ${input.platform ?? "the reported platform"}${input.appVersion ? ` ${input.appVersion}` : ""}.`);
  steps.push("Reply to the reporter with findings.");
  return steps;
}

// ─── SHA-256 digest of the evidence the package read (audit anchor) ────────────

export async function sha256Hex(input: string): Promise<string> {
  const data = new TextEncoder().encode(input);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// ─── Governed LLM enrichment (optional, drafts only) ──────────────────────────

export interface EnrichedPackage extends DeterministicPackage {
  method: "deterministic" | "ai_enriched";
  model: string;
}

/**
 * Refine the deterministic package with one governed model call. On any decline
 * (no key / rate / spend cap / timeout / unparseable) the deterministic package
 * is returned unchanged with method "deterministic" — never fabricated. The
 * evidence handed to the model is the ALREADY-MINIMIZED summary (no raw PII).
 *
 * The gateway call runs in its OWN transaction (a nested withTenantContext) so a
 * gateway-side DB error can never poison the caller's write transaction — the
 * caller then persists the deterministic package on a clean transaction.
 */
export async function enrichWithModel(
  config: AppConfig,
  claims: AccessTokenClaims,
  base: DeterministicPackage,
  input: IncidentSummaryInput,
  minimizedEvidenceSummary: string,
): Promise<EnrichedPackage> {
  const system =
    "You are an NIKSHA OS support engineer. You are given a software-support " +
    "incident and a DETERMINISTIC first-pass analysis plus minimized (PII-free) " +
    "evidence. Refine ONLY the narrative. You must NOT invent data not present in " +
    "the evidence. Reply with strict JSON: " +
    '{"summary": string, "likelyRootCause": string, "suggestedNextSteps": string[], ' +
    '"severity": "sev1"|"sev2"|"sev3"|"sev4", "confidence": number(0-100)}. ' +
    "No prose outside the JSON.";

  const user =
    `INCIDENT\ntitle: ${input.title}\nrole: ${input.reporterRole}\n` +
    `module: ${input.moduleKey ?? "-"} screen: ${input.screenRoute ?? "-"}\n` +
    `platform: ${input.platform ?? "-"} appVersion: ${input.appVersion ?? "-"}\n` +
    `description: ${input.description}\n\n` +
    `DETERMINISTIC ANALYSIS\ncategory: ${base.categorization.category}\n` +
    `severity: ${base.severitySuggestion}\nsummary: ${base.summary}\n` +
    `rootCause: ${base.likelyRootCause}\nnextSteps: ${base.suggestedNextSteps.join("; ")}\n\n` +
    `MINIMIZED EVIDENCE\n${minimizedEvidenceSummary}`;

  let result;
  try {
    result = await withTenantContext(config, claims, (db) =>
      callModelGateway(
        db,
        {
          organizationId: claims.tenant_id,
          schoolId: claims.school_id,
          userId: claims.sub,
          surface: "support_rca",
        },
        { system, messages: [{ role: "user", content: user }], maxTokens: 700 },
        "", // no fallback text — a decline means "keep the deterministic package"
      ));
  } catch {
    return { ...base, method: "deterministic", model: "" };
  }

  if (!result.ok || !result.text) {
    return { ...base, method: "deterministic", model: result?.model ?? "" };
  }

  const parsed = safeParseEnrichment(result.text);
  if (!parsed) {
    return { ...base, method: "deterministic", model: result.model };
  }
  return {
    categorization: base.categorization, // category stays deterministic
    severitySuggestion: parsed.severity ?? base.severitySuggestion,
    summary: parsed.summary ?? base.summary,
    likelyRootCause: parsed.likelyRootCause ?? base.likelyRootCause,
    suggestedNextSteps: parsed.suggestedNextSteps ?? base.suggestedNextSteps,
    confidence: parsed.confidence ?? base.confidence,
    method: "ai_enriched",
    model: result.model,
  };
}

interface ParsedEnrichment {
  summary?: string;
  likelyRootCause?: string;
  suggestedNextSteps?: string[];
  severity?: SupportSeverity;
  confidence?: number;
}

export function safeParseEnrichment(text: string): ParsedEnrichment | null {
  // Tolerate the model wrapping JSON in prose/fences: extract the first {...}.
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  let obj: unknown;
  try {
    obj = JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
  if (typeof obj !== "object" || obj === null) return null;
  const o = obj as Record<string, unknown>;
  const out: ParsedEnrichment = {};
  if (typeof o.summary === "string" && o.summary.trim()) out.summary = o.summary.slice(0, 2000);
  if (typeof o.likelyRootCause === "string" && o.likelyRootCause.trim()) {
    out.likelyRootCause = o.likelyRootCause.slice(0, 2000);
  }
  if (Array.isArray(o.suggestedNextSteps)) {
    const steps = o.suggestedNextSteps
      .filter((s): s is string => typeof s === "string" && s.trim().length > 0)
      .map((s) => s.slice(0, 400))
      .slice(0, 12);
    if (steps.length > 0) out.suggestedNextSteps = steps;
  }
  if (o.severity === "sev1" || o.severity === "sev2" || o.severity === "sev3" || o.severity === "sev4") {
    out.severity = o.severity;
  }
  if (typeof o.confidence === "number" && Number.isFinite(o.confidence)) {
    out.confidence = Math.max(0, Math.min(100, Math.round(o.confidence)));
  }
  return out;
}
