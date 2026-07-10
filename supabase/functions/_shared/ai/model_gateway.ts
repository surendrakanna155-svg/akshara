// Adaptive AI — P3-AI-1 / W1.1: the Model Gateway.
//
// The single governed choke point for every live model call (Serving-Ladder
// Tier 3, design doc 01/03). It wraps `callClaude` with the four controls the
// audit found missing:
//   • per-request timeout (AbortController) → deterministic fallback   (AI-3)
//   • token-bucket rate limits, per user and per school                (AI-1)
//   • monthly spend cap with soft-degrade                             (AI-1)
//   • append-only `ai_call_log` telemetry + a no-key outcome           (AI-4)
//
// It NEVER fabricates: on any denial, timeout, error, or missing key it returns
// the caller's deterministic `fallbackText` and records the outcome. It touches
// no write/money/approval path — callers still own their fallback content; the
// gateway only decides whether the model may be consulted and records the fact.
//
// Design fidelity: pure decision helpers (`decideGateway`, `estimateCostMicros`,
// `resolveLimits`) are separated from IO so every branch is unit-tested without
// a DB or network. `callModelGateway` wires the real deps; tests inject fakes.

import {
  callClaude,
  type ClaudeMessage,
  type ClaudeUsage,
} from "./anthropic_client.ts";
import { type AiRuntimeConfig, resolveAiConfig } from "./ai_settings.ts";
import {
  type AiCallLogEntry,
  type AiCallOutcome,
  type AiTenantScope,
  countSchoolCallsSince,
  countUserCallsSince,
  recordAiCall,
  sumSchoolCostMicrosSince,
} from "./ai_call_log_repository.ts";
import {
  lookupResponseCache,
  writeResponseCache,
} from "./ai_response_cache_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

export const DEFAULT_TIMEOUT_MS = 20_000;

// ─── Limits ──────────────────────────────────────────────────────────────────

export interface GatewayLimits {
  /** Max T3 calls per user per rolling hour (0 = unlimited). */
  userCallsPerHour: number;
  /** Max T3 calls per school per rolling 24h (0 = unlimited). */
  schoolCallsPerDay: number;
  /** Per-school calendar-month spend cap in micro-USD (0 = no cap). */
  monthlySpendCapMicros: number;
}

/** Conservative defaults: rate limits ON (bounding worst-case spend even with
 * no $ cap configured — this is the AI-1 mitigation), $ cap OFF until an admin
 * sets one in the provider config or via env. */
export const DEFAULT_LIMITS: GatewayLimits = {
  userCallsPerHour: 30,
  schoolCallsPerDay: 500,
  monthlySpendCapMicros: 0,
};

function positiveNum(value: unknown, fallback: number): number {
  const n = typeof value === "number"
    ? value
    : typeof value === "string"
    ? Number(value.trim())
    : NaN;
  return Number.isFinite(n) && n >= 0 ? n : fallback;
}

function envNum(name: string, fallback: number): number {
  return positiveNum(Deno.env.get(name), fallback);
}

/** Resolve the effective limits: per-school provider `config` overrides env,
 * env overrides the hardcoded default. Config keys are snake_case to match the
 * admin panel JSON. */
export function resolveLimits(config?: Record<string, unknown> | null): GatewayLimits {
  const c = config ?? {};
  return {
    userCallsPerHour: positiveNum(
      c.ai_rate_user_per_hour,
      envNum("AI_RATE_USER_PER_HOUR", DEFAULT_LIMITS.userCallsPerHour),
    ),
    schoolCallsPerDay: positiveNum(
      c.ai_rate_school_per_day,
      envNum("AI_RATE_SCHOOL_PER_DAY", DEFAULT_LIMITS.schoolCallsPerDay),
    ),
    monthlySpendCapMicros: positiveNum(
      c.ai_monthly_spend_cap_micros,
      envNum("AI_MONTHLY_SPEND_CAP_MICROS", DEFAULT_LIMITS.monthlySpendCapMicros),
    ),
  };
}

// ─── Cost estimate (deterministic) ───────────────────────────────────────────

interface ModelPrice {
  /** micro-USD per input token. */
  inMicrosPerToken: number;
  /** micro-USD per output token. */
  outMicrosPerToken: number;
}

/** Static price table (micro-USD/token). Deterministic estimate only — the
 * real invoice is the provider's; this exists to power caps + the cost panel. */
function priceFor(model: string): ModelPrice {
  const m = model.toLowerCase();
  if (m.includes("opus")) return { inMicrosPerToken: 15, outMicrosPerToken: 75 };
  if (m.includes("haiku")) return { inMicrosPerToken: 1, outMicrosPerToken: 5 };
  // sonnet + any unknown model fall to the mid/conservative tier.
  return { inMicrosPerToken: 3, outMicrosPerToken: 15 };
}

export function estimateCostMicros(model: string, usage: ClaudeUsage | null): number {
  if (!usage) return 0;
  const p = priceFor(model);
  return Math.round(
    Math.max(0, usage.inputTokens) * p.inMicrosPerToken +
      Math.max(0, usage.outputTokens) * p.outMicrosPerToken,
  );
}

// ─── Decision (pure) ─────────────────────────────────────────────────────────

export interface GatewayUsage {
  userCallsLastHour: number;
  schoolCallsToday: number;
  monthSpendMicros: number;
}

export type GatewayDenyReason = "no_key" | "rate_user" | "rate_school" | "spend_cap";

export interface GatewayDecision {
  allow: boolean;
  reason?: GatewayDenyReason;
}

/** Decide whether a live model call is permitted. Order: key → per-user rate →
 * per-school rate → spend cap. First failing gate wins. */
export function decideGateway(
  hasKey: boolean,
  limits: GatewayLimits,
  usage: GatewayUsage,
): GatewayDecision {
  if (!hasKey) return { allow: false, reason: "no_key" };
  if (limits.userCallsPerHour > 0 && usage.userCallsLastHour >= limits.userCallsPerHour) {
    return { allow: false, reason: "rate_user" };
  }
  if (limits.schoolCallsPerDay > 0 && usage.schoolCallsToday >= limits.schoolCallsPerDay) {
    return { allow: false, reason: "rate_school" };
  }
  if (
    limits.monthlySpendCapMicros > 0 &&
    usage.monthSpendMicros >= limits.monthlySpendCapMicros
  ) {
    return { allow: false, reason: "spend_cap" };
  }
  return { allow: true };
}

function denyOutcome(reason: GatewayDenyReason): AiCallOutcome {
  switch (reason) {
    case "no_key":
      return "fallback_no_key";
    case "rate_user":
      return "fallback_rate_user";
    case "rate_school":
      return "fallback_rate_school";
    case "spend_cap":
      return "fallback_spend_cap";
  }
}

// ─── IO wrapper ──────────────────────────────────────────────────────────────

export interface GatewayContext {
  organizationId: string;
  schoolId: string;
  userId?: string | null;
  /** Stable surface id for telemetry, e.g. "copilot" / "director_summary". */
  surface: string;
}

export interface GatewayInput {
  system: string;
  messages: ClaudeMessage[];
  maxTokens?: number;
}

export interface GatewayCallResult {
  /** The text to render — a real model answer, or the caller's fallback. */
  text: string;
  /** True only when a real, non-refused model answer was served. */
  ok: boolean;
  /** True when `text` is the deterministic fallback (no-key/limit/timeout/error/refusal). */
  fallbackUsed: boolean;
  outcome: AiCallOutcome;
  refused: boolean;
  /** True when served from the Tier-2 response cache (no model call, no cost). */
  fromCache: boolean;
  /** The resolved/served model id (provider-returned on success, else configured). */
  model: string;
  usage: ClaudeUsage | null;
}

/** Optional Tier-2 response-cache seam. */
export interface GatewayCacheDeps {
  lookup: (scope: AiTenantScope) => Promise<{ payload: string; model: string } | null>;
  write: (
    scope: AiTenantScope,
    surface: string,
    payload: string,
    model: string,
    tokensSaved: number,
  ) => Promise<void>;
}

/** Per-call cache configuration (the key is minted by the caller/Context Engine). */
export interface GatewayCacheConfig {
  key: string;
  entityTags?: string[];
  ttlSeconds?: number;
  language?: string;
}

/** Injectable seam so the wrapper is testable without a DB or network. */
export interface GatewayDeps {
  resolveConfig: (orgId?: string | null) => Promise<AiRuntimeConfig>;
  readUsage: (
    scope: AiTenantScope,
    userId: string | null,
    now: Date,
  ) => Promise<GatewayUsage>;
  record: (entry: AiCallLogEntry) => Promise<void>;
  callModel: typeof callClaude;
  now: () => Date;
  timeoutMs: number;
  /** Present only when the caller supplied a cache key. */
  cache?: GatewayCacheDeps;
}

function hoursAgoIso(now: Date, hours: number): string {
  return new Date(now.getTime() - hours * 3_600_000).toISOString();
}

function monthStartIso(now: Date): string {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)).toISOString();
}

async function defaultReadUsage(
  db: TenantQueryClient,
  scope: AiTenantScope,
  userId: string | null,
  now: Date,
): Promise<GatewayUsage> {
  const [userCallsLastHour, schoolCallsToday, monthSpendMicros] = await Promise.all([
    userId ? countUserCallsSince(db, scope, userId, hoursAgoIso(now, 1)) : Promise.resolve(0),
    countSchoolCallsSince(db, scope, hoursAgoIso(now, 24)),
    sumSchoolCostMicrosSince(db, scope, monthStartIso(now)),
  ]);
  return { userCallsLastHour, schoolCallsToday, monthSpendMicros };
}

/** Build the production deps bound to a tenant DB client. */
export function gatewayDepsFor(
  db: TenantQueryClient,
  opts?: { timeoutMs?: number; cache?: GatewayCacheConfig },
): GatewayDeps {
  const cacheCfg = opts?.cache;
  return {
    resolveConfig: (orgId) => resolveAiConfig(db, orgId),
    readUsage: (scope, userId, now) => defaultReadUsage(db, scope, userId, now),
    record: (entry) => recordAiCall(db, entry),
    callModel: callClaude,
    now: () => new Date(),
    timeoutMs: opts?.timeoutMs ?? DEFAULT_TIMEOUT_MS,
    cache: cacheCfg
      ? {
        lookup: (scope) => lookupResponseCache(db, scope, cacheCfg.key),
        write: (scope, surface, payload, model, tokensSaved) =>
          writeResponseCache(db, scope, {
            cacheKey: cacheCfg.key,
            surface,
            language: cacheCfg.language ?? "english",
            payload,
            entityTags: cacheCfg.entityTags ?? [],
            model,
            tokensSaved,
            ttlSeconds: cacheCfg.ttlSeconds,
          }),
      }
      : undefined,
  };
}

function baseEntry(
  ctx: GatewayContext,
  cfg: AiRuntimeConfig,
): Pick<
  AiCallLogEntry,
  "organizationId" | "schoolId" | "userId" | "surface" | "provider" | "model"
> {
  return {
    organizationId: ctx.organizationId,
    schoolId: ctx.schoolId,
    userId: ctx.userId ?? null,
    surface: ctx.surface,
    provider: cfg.provider,
    model: cfg.model,
  };
}

/** Telemetry must never fail the user's request. */
async function safeRecord(deps: GatewayDeps, entry: AiCallLogEntry): Promise<void> {
  try {
    await deps.record(entry);
  } catch {
    // swallow — an unlogged call is preferable to a failed user action
  }
}

/** The testable gateway core. Prefer {@link callModelGateway} in production. */
export async function runGateway(
  ctx: GatewayContext,
  input: GatewayInput,
  fallbackText: string,
  deps: GatewayDeps,
): Promise<GatewayCallResult> {
  const scope: AiTenantScope = {
    organizationId: ctx.organizationId,
    schoolId: ctx.schoolId,
  };
  const now = deps.now();

  // Tier-2: a cache hit is free — served before config/limits/model, no
  // ai_call_log row (the cache's own hit_count tracks it). A lookup failure is
  // treated as a miss so the live path still runs.
  if (deps.cache) {
    try {
      const hit = await deps.cache.lookup(scope);
      if (hit) {
        return {
          text: hit.payload,
          ok: true,
          fallbackUsed: false,
          outcome: "ok",
          refused: false,
          fromCache: true,
          model: hit.model,
          usage: null,
        };
      }
    } catch {
      // treat as a miss
    }
  }

  let cfg: AiRuntimeConfig;
  try {
    cfg = await deps.resolveConfig(ctx.organizationId);
  } catch {
    cfg = { provider: "anthropic", model: "", apiKey: undefined, source: "env" };
  }
  const limits = resolveLimits(cfg.rawConfig);
  const hasKey = !!cfg.apiKey;

  let usage: GatewayUsage = {
    userCallsLastHour: 0,
    schoolCallsToday: 0,
    monthSpendMicros: 0,
  };
  if (hasKey) {
    try {
      usage = await deps.readUsage(scope, ctx.userId ?? null, now);
    } catch {
      // Usage unreadable → do not block the user; the call is still logged so
      // the next window accounts for it. Worst case remains provider-bounded.
      usage = { userCallsLastHour: 0, schoolCallsToday: 0, monthSpendMicros: 0 };
    }
  }

  const decision = decideGateway(hasKey, limits, usage);
  if (!decision.allow) {
    const outcome = denyOutcome(decision.reason!);
    await safeRecord(deps, {
      ...baseEntry(ctx, cfg),
      outcome,
      inputTokens: 0,
      outputTokens: 0,
      estimatedCostMicros: 0,
      latencyMs: 0,
      cacheWritten: false,
      fallbackUsed: true,
    });
    return {
      text: fallbackText,
      ok: false,
      fallbackUsed: true,
      outcome,
      refused: false,
      fromCache: false,
      model: cfg.model,
      usage: null,
    };
  }

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), deps.timeoutMs);
  const started = deps.now().getTime();
  try {
    const result = await deps.callModel({
      system: input.system,
      messages: input.messages,
      maxTokens: input.maxTokens,
      apiKey: cfg.apiKey!,
      provider: cfg.provider,
      model: cfg.model,
      signal: controller.signal,
    });
    const latencyMs = Math.max(0, deps.now().getTime() - started);
    const model = result.model || cfg.model;
    const outcome: AiCallOutcome = result.refused ? "refused" : "ok";
    await safeRecord(deps, {
      ...baseEntry(ctx, cfg),
      model,
      outcome,
      inputTokens: result.usage?.inputTokens ?? 0,
      outputTokens: result.usage?.outputTokens ?? 0,
      estimatedCostMicros: estimateCostMicros(model, result.usage),
      latencyMs,
      cacheWritten: false,
      fallbackUsed: result.refused,
    });
    if (result.refused) {
      return {
        text: fallbackText,
        ok: false,
        fallbackUsed: true,
        outcome: "refused",
        refused: true,
        fromCache: false,
        model,
        usage: result.usage,
      };
    }
    // Write-through: this validated answer becomes a Tier-2 asset (doc 01 §2).
    if (deps.cache) {
      try {
        await deps.cache.write(scope, ctx.surface, result.text, model, result.usage?.outputTokens ?? 0);
      } catch {
        // caching is best-effort; never fail the served answer
      }
    }
    return {
      text: result.text,
      ok: true,
      fallbackUsed: false,
      outcome: "ok",
      refused: false,
      fromCache: false,
      model,
      usage: result.usage,
    };
  } catch (err) {
    const aborted = controller.signal.aborted ||
      (err instanceof Error && err.name === "AbortError");
    const outcome: AiCallOutcome = aborted ? "fallback_timeout" : "fallback_error";
    const latencyMs = Math.max(0, deps.now().getTime() - started);
    await safeRecord(deps, {
      ...baseEntry(ctx, cfg),
      outcome,
      inputTokens: 0,
      outputTokens: 0,
      estimatedCostMicros: 0,
      latencyMs,
      cacheWritten: false,
      fallbackUsed: true,
    });
    return {
      text: fallbackText,
      ok: false,
      fallbackUsed: true,
      outcome,
      refused: false,
      fromCache: false,
      model: cfg.model,
      usage: null,
    };
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Governed model call bound to a tenant DB client. On any denial, timeout,
 * error, missing key, or refusal it returns `fallbackText` (never throws into
 * the caller's happy path) and records exactly one `ai_call_log` row.
 */
export function callModelGateway(
  db: TenantQueryClient,
  ctx: GatewayContext,
  input: GatewayInput,
  fallbackText: string,
  opts?: { timeoutMs?: number; cache?: GatewayCacheConfig },
): Promise<GatewayCallResult> {
  return runGateway(ctx, input, fallbackText, gatewayDepsFor(db, opts));
}
