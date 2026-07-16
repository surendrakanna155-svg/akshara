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
import {
  consumeReservation,
  monthStartIso,
  releaseReservation,
  type ReserveArgs,
  type ReserveResult,
  reserveOutOfBand,
} from "./ai_call_reservations_repository.ts";
import { logAiDegradation } from "./ai_telemetry.ts";
import { aiWalletEnforcementEnabled } from "./ai_wallet_enforcement.ts";
import { readWalletBalance } from "./ai_wallet_repository.ts";
import { reservedCreditsFor } from "./ai_wallet_units.ts";
import { embeddingsConfigured, embedText } from "./embeddings_client.ts";
import {
  findNearestCachedResponse,
  findStoredEmbedding,
  questionHash,
  semanticCacheAvailable,
  semanticMaxDistance,
  storeSemanticEmbedding,
  vectorLiteral,
} from "./ai_semantic_cache_repository.ts";
import { type GuardOptions, guardModelReply } from "./output_guard.ts";
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
  /**
   * PRC-A Batch 3 — is the org's purchased credit wallet enforced?
   *
   * Read from the env master switch, NOT from the per-school provider config: the
   * wallet is a commercial fact about what the org bought, so a school editing its
   * own AI settings must never be able to switch its own wallet off. The three
   * limits above are self-governance a school may legitimately tune; this is not.
   */
  walletEnforced: boolean;
}

/** Conservative defaults: rate limits ON, and a non-zero monthly $ backstop ON
 * by default (P1-3). The backstop is deliberately GENEROUS — well above realistic
 * per-school usage under the daily rate limit, even Opus-heavy — so it never
 * throttles legitimate use, but it is a hard ceiling that bounds any runaway
 * (misconfig / pricing spike / concurrent-burst overage) to cap + one window
 * instead of the previous UNLIMITED dollar exposure. Tune per pricing plan via
 * the per-school provider config (`ai_monthly_spend_cap_micros`) or the
 * `AI_MONTHLY_SPEND_CAP_MICROS` env var, both of which override this. Unit is
 * micro-USD (1 USD = 1_000_000); 1_000_000_000 = US$1,000 / school / month. */
export const DEFAULT_LIMITS: GatewayLimits = {
  userCallsPerHour: 30,
  schoolCallsPerDay: 500,
  monthlySpendCapMicros: 1_000_000_000,
  // Default OFF. A 0 balance would otherwise deny every AI call for every org
  // that has never been granted credit — i.e. all of them, on the deploy that
  // ships this. See ai_wallet_enforcement.ts.
  walletEnforced: false,
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
    // Deliberately NOT read from `c` (the per-school provider config). The three
    // limits above are self-governance a school may tune from its own admin
    // panel; the wallet is a commercial fact about what the org purchased. If it
    // were config-driven, a school could disable its own wallet by editing its
    // AI settings — which is the same as having no wallet at all.
    walletEnforced: aiWalletEnforcementEnabled(),
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

/** Matches anthropic_client's `maxTokens ?? 1024` default. */
const DEFAULT_MAX_OUTPUT_TOKENS = 1024;

/** Pre-call worst-case cost estimate for the atomic reservation: prompt size
 * approximated at 4 chars/token, output at the request's maxTokens ceiling.
 * Deliberately conservative — the reservation is finalized with the real
 * post-call estimate, so an over-estimate only over-blocks near the cap for
 * the seconds the call is in flight. */
export function estimateReservationMicros(model: string, input: GatewayInput): number {
  const p = priceFor(model);
  const promptChars = input.system.length +
    input.messages.reduce((sum, m) => sum + m.content.length, 0);
  const inputTokens = Math.ceil(promptChars / 4);
  const outputTokens = Math.max(1, Math.trunc(input.maxTokens ?? DEFAULT_MAX_OUTPUT_TOKENS));
  return Math.round(inputTokens * p.inMicrosPerToken + outputTokens * p.outMicrosPerToken);
}

// ─── Decision (pure) ─────────────────────────────────────────────────────────

export interface GatewayUsage {
  userCallsLastHour: number;
  schoolCallsToday: number;
  monthSpendMicros: number;
  /**
   * PRC-A Batch 3 — org wallet credits available (granted - debited - reserved).
   *
   * This exists on the LEGACY window-count path on purpose. `runReservation`
   * normally enforces the wallet inside its atomic admit clause, but when the
   * reservation connection is unavailable the gateway degrades to
   * `readUsage` + `decideGateway` (see the ReservationsUnavailableError branch in
   * runGateway). If the wallet were only wired into the reservation path, a
   * reservation-infra outage would silently become a FREE-USAGE BYPASS rather
   * than merely a rate-limit bypass — an outage would be the cheapest way to
   * spend credits you do not have. Both paths must carry the balance.
   *
   * Optional so every existing caller/test compiles unchanged; absent means the
   * wallet term is skipped, which is correct when the wallet is not enforced.
   */
  walletAvailableUnits?: number;
  /** Credits this specific call needs. Paired with walletAvailableUnits. */
  walletRequiredUnits?: number;
}

export type GatewayDenyReason =
  | "no_key"
  | "rate_user"
  | "rate_school"
  | "spend_cap"
  | "wallet_empty";

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
  // Wallet last, matching runReservation's admit-clause order so both paths name
  // the same gate for the same call. Only evaluated when the caller supplied a
  // balance (i.e. the wallet is enforced) — otherwise inert.
  if (
    usage.walletAvailableUnits !== undefined &&
    usage.walletAvailableUnits < (usage.walletRequiredUnits ?? 0)
  ) {
    return { allow: false, reason: "wallet_empty" };
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
    case "wallet_empty":
      // A distinct outcome, not folded into fallback_spend_cap: "you ran out of
      // the credits you bought" and "we hit our own cost governance" are
      // different events with different remedies (top up vs wait for the 1st).
      return "fallback_wallet_empty";
  }
}

// ─── IO wrapper ──────────────────────────────────────────────────────────────

export interface GatewayContext {
  organizationId: string;
  /** Null for an org-scoped call (director / org-builder / onboarding). */
  schoolId: string | null;
  userId?: string | null;
  /** Stable surface id for telemetry, e.g. "copilot" / "director_summary". */
  surface: string;
}

export interface GatewayInput {
  system: string;
  messages: ClaudeMessage[];
  maxTokens?: number;
  /** Opt-in output-side guard (F3): validate the reply against the injected
   * context before serving/caching. `true` = defaults; an object = tuned caps.
   * On violation the reply is discarded, the fallback served, and the call
   * logged as `fallback_guard`. Off by default (structured-JSON callers keep
   * their own field re-validation). */
  guard?: boolean | GuardOptions;
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
  /** W2.8 Stage-2: the raw question text. When present (and an embeddings
   * provider + the pgvector substrate are available), an exact-key miss falls
   * through to an embedding-nearest lookup over the same cached answers, and
   * a write-through also stores the question's embedding. Absent ⇒ Stage-1
   * behavior exactly as before. */
  semanticText?: string;
  /** Surface filter for the Stage-2 read (defaults to "copilot"). */
  semanticSurface?: string;
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
  /** Atomic pre-call quota reservation (A5). When present it REPLACES the
   * read-then-decide window check with a race-free admit; when absent (or
   * failing) the gateway degrades to the legacy readUsage+decideGateway path. */
  reserve?: (args: ReserveArgs) => Promise<ReserveResult>;
  /** Finalize a reservation on the caller's own transaction: consumed with the
   * real cost when tokens were billed, released when the call cost nothing. */
  finalizeReservation?: (
    reservationId: string,
    outcome: { consumed: boolean; costMicros: number },
  ) => Promise<void>;
}

function hoursAgoIso(now: Date, hours: number): string {
  return new Date(now.getTime() - hours * 3_600_000).toISOString();
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
  // PRC-A Batch 3 (hazard H3): the wallet balance is read on the LEGACY path too.
  // This path only runs when the reservation connection is unavailable — exactly
  // when it would be most tempting to skip the balance. Skipping it would make a
  // reservation-infra outage a free-usage bypass. Read only when the wallet is
  // actually enforced, so the default path costs no extra query.
  //
  // This read is genuinely check-then-act (the atomic admit lives in
  // runReservation), so it is weaker than the primary path — but weaker-and-
  // enforced is strictly better than not-enforced, and this branch is already
  // the degraded mode for the rate/spend gates too.
  if (!aiWalletEnforcementEnabled()) {
    return { userCallsLastHour, schoolCallsToday, monthSpendMicros };
  }
  const balance = await readWalletBalance(db, scope);
  return {
    userCallsLastHour,
    schoolCallsToday,
    monthSpendMicros,
    walletAvailableUnits: balance.availableUnits,
  };
}

/** Run a telemetry write inside a savepoint so a DB-level failure cannot
 * poison the caller's request transaction (audit P2-3): without this, a
 * failed INSERT aborts the surrounding Postgres transaction and every LATER
 * handler write fails with "current transaction is aborted" despite the
 * catch — turning a served model answer into a user-facing 500. */
async function withTelemetrySavepoint(
  db: TenantQueryClient,
  fn: () => Promise<void>,
): Promise<void> {
  await db.queryObject("SAVEPOINT ai_telemetry");
  try {
    await fn();
    await db.queryObject("RELEASE SAVEPOINT ai_telemetry");
  } catch (err) {
    await db.queryObject("ROLLBACK TO SAVEPOINT ai_telemetry");
    throw err;
  }
}

/** Build the production deps bound to a tenant DB client. */
export function gatewayDepsFor(
  db: TenantQueryClient,
  opts?: { timeoutMs?: number; cache?: GatewayCacheConfig },
): GatewayDeps {
  const cacheCfg = opts?.cache;
  // The reservation rides its own immediate-commit connection; wire it only
  // when the tenant DB is configured (unit tests with fake deps stay on the
  // legacy path with zero noise).
  const reservationsConfigured = !!Deno.env.get("ERP_TENANT_DATABASE_URL");
  return {
    resolveConfig: (orgId) => resolveAiConfig(db, orgId),
    readUsage: (scope, userId, now) => defaultReadUsage(db, scope, userId, now),
    record: (entry) => withTelemetrySavepoint(db, () => recordAiCall(db, entry)),
    callModel: callClaude,
    now: () => new Date(),
    timeoutMs: opts?.timeoutMs ?? DEFAULT_TIMEOUT_MS,
    reserve: reservationsConfigured ? (args) => reserveOutOfBand(args) : undefined,
    finalizeReservation: reservationsConfigured
      ? (reservationId, outcome) =>
        withTelemetrySavepoint(db, () =>
          outcome.consumed
            ? consumeReservation(db, reservationId, outcome.costMicros)
            : releaseReservation(db, reservationId))
      : undefined,
    cache: cacheCfg
      ? (() => {
        // W2.8 Stage-2 state shared between lookup and write so the question
        // is embedded at most once per request.
        let semanticVector: string | null = null;
        let semanticHash: string | null = null;
        const semanticEligible = () =>
          !!cacheCfg.semanticText && embeddingsConfigured();

        const semanticLookup = async (
          scope: AiTenantScope,
        ): Promise<{ payload: string; model: string } | null> => {
          // The substrate is school-scoped; org-bucket calls stay Stage-1.
          if (!semanticEligible() || scope.schoolId === null) return null;
          try {
            if (!(await semanticCacheAvailable(db))) return null;
            semanticHash = await questionHash(cacheCfg.semanticText!);
            semanticVector = await findStoredEmbedding(db, scope, semanticHash);
            if (!semanticVector) {
              const embedded = await embedText(cacheCfg.semanticText!);
              if (!embedded) return null;
              semanticVector = vectorLiteral(embedded);
            }
            const hit = await findNearestCachedResponse(db, scope, {
              surface: cacheCfg.semanticSurface ?? "copilot",
              language: cacheCfg.language ?? "english",
              embedding: semanticVector,
              maxDistance: semanticMaxDistance(),
            });
            return hit ? { payload: hit.payload, model: hit.model } : null;
          } catch (err) {
            logAiDegradation("semantic_cache.lookup", err);
            return null;
          }
        };

        return {
          lookup: async (scope: AiTenantScope) => {
            const exact = await lookupResponseCache(db, scope, cacheCfg.key);
            if (exact) return exact;
            return await semanticLookup(scope);
          },
          // Savepoint-wrapped like record/finalize: a DB-level cache-write
          // failure must degrade to "not cached", never abort the request
          // transaction (round-3 N2).
          write: async (
            scope: AiTenantScope,
            surface: string,
            payload: string,
            model: string,
            tokensSaved: number,
          ) => {
            await withTelemetrySavepoint(db, () =>
              writeResponseCache(db, scope, {
                cacheKey: cacheCfg.key,
                surface,
                language: cacheCfg.language ?? "english",
                payload,
                entityTags: cacheCfg.entityTags ?? [],
                model,
                tokensSaved,
                ttlSeconds: cacheCfg.ttlSeconds,
              }));
            // Stage-2 write-through: store the question's embedding keyed to
            // this cache entry. Best-effort and savepointed; reuses the
            // vector computed during lookup when present.
            if (semanticEligible() && scope.schoolId !== null) {
              try {
                if (!(await semanticCacheAvailable(db))) return;
                semanticHash ??= await questionHash(cacheCfg.semanticText!);
                if (!semanticVector) {
                  const embedded = await embedText(cacheCfg.semanticText!);
                  if (!embedded) return;
                  semanticVector = vectorLiteral(embedded);
                }
                await withTelemetrySavepoint(db, () =>
                  storeSemanticEmbedding(db, scope, {
                    cacheKey: cacheCfg.key,
                    surface,
                    language: cacheCfg.language ?? "english",
                    questionHash: semanticHash!,
                    embedding: semanticVector!,
                  }));
              } catch (err) {
                logAiDegradation("semantic_cache.write", err);
              }
            }
          },
        };
      })()
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
  } catch (err) {
    // swallow — an unlogged call is preferable to a failed user action — but
    // an operator must be able to see the undercount (P2-8).
    logAiDegradation("gateway.record", err, {
      surface: entry.surface,
      outcome: entry.outcome,
    });
  }
}

/** Best-effort reservation finalization: consumed (with the real cost) in the
 * same transaction that records the call, released when nothing was billed.
 * The pending-TTL sweep is the backstop if this fails. */
async function settleReservation(
  deps: GatewayDeps,
  reservationId: string | null,
  consumed: boolean,
  costMicros: number,
): Promise<void> {
  if (!reservationId || !deps.finalizeReservation) return;
  try {
    await deps.finalizeReservation(reservationId, { consumed, costMicros });
  } catch (err) {
    logAiDegradation("gateway.finalize_reservation", err);
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
    } catch (err) {
      // treat as a miss
      logAiDegradation("gateway.cache_lookup", err, { surface: ctx.surface });
    }
  }

  let cfg: AiRuntimeConfig;
  try {
    cfg = await deps.resolveConfig(ctx.organizationId);
  } catch (err) {
    logAiDegradation("gateway.resolve_config", err, { surface: ctx.surface });
    cfg = { provider: "anthropic", model: "", apiKey: undefined, source: "env" };
  }
  const limits = resolveLimits(cfg.rawConfig);
  const hasKey = !!cfg.apiKey;
  // Product credits this call costs. Deterministic from the model tier — NOT
  // derived from estimated_cost_micros, which would smuggle currency semantics
  // back into a unit-denominated wallet (owner decision #3). Computed once and
  // used for BOTH the reservation hold and the settle-time debit, so a call can
  // never be held at one price and charged at another.
  const creditsForThisCall = limits.walletEnforced ? reservedCreditsFor(cfg.model) : 0;

  // Admission control. Preferred: the atomic reservation (A5) — committed
  // out-of-band BEFORE the provider call, so concurrent requests can never
  // pass the same window check together. Fallback (reservation dep absent or
  // its infrastructure failing): the legacy read-then-decide window check —
  // availability over strictness, but the degradation is logged loudly.
  let reservationId: string | null = null;
  let decision: GatewayDecision;
  if (!hasKey) {
    decision = { allow: false, reason: "no_key" };
  } else {
    let reserveDenied: GatewayDenyReason | null = null;
    if (deps.reserve) {
      try {
        const r = await deps.reserve({
          scope,
          userId: ctx.userId ?? null,
          surface: ctx.surface,
          estimatedCostMicros: estimateReservationMicros(cfg.model, input),
          // Hold the credits on the reservation row itself, so a concurrent
          // admit sees them immediately. This is what makes the wallet
          // double-spend-proof without a lock of its own.
          creditsRequired: creditsForThisCall,
          limits,
          now,
        });
        if (r.allow) reservationId = r.reservationId;
        else reserveDenied = r.reason;
      } catch (err) {
        logAiDegradation("gateway.reserve", err, { surface: ctx.surface });
      }
    }
    if (reservationId) {
      decision = { allow: true };
    } else if (reserveDenied) {
      decision = { allow: false, reason: reserveDenied };
    } else {
      let usage: GatewayUsage = {
        userCallsLastHour: 0,
        schoolCallsToday: 0,
        monthSpendMicros: 0,
      };
      try {
        usage = await deps.readUsage(scope, ctx.userId ?? null, now);
      } catch (err) {
        // Usage unreadable → do not block the user; the call is still logged
        // so the next window accounts for it. Worst case remains
        // provider-bounded — but say so where an operator can see it (P2-8).
        logAiDegradation("gateway.read_usage", err, { surface: ctx.surface });
        usage = { userCallsLastHour: 0, schoolCallsToday: 0, monthSpendMicros: 0 };
        // PRC-A Batch 3 — the wallet FAILS CLOSED here, unlike the rate/spend
        // gates above which deliberately fail open. The asymmetry is intended:
        // rate/spend are OUR self-governance (failing open costs us a bounded
        // amount and keeps schools working), whereas the wallet is the
        // commercial boundary — failing open serves calls the school has not
        // paid for, and a DB blip becomes free usage. Denying costs the user
        // only the deterministic fallback response they would get anyway, so the
        // safe direction is cheap here. Only applies when the wallet is enforced.
        if (limits.walletEnforced) {
          usage.walletAvailableUnits = -1;
        }
      }
      // Tell decideGateway what this call needs; without it the wallet term is
      // inert on this path (available >= 0 always passes).
      if (limits.walletEnforced) {
        usage.walletRequiredUnits = creditsForThisCall;
      }
      decision = decideGateway(hasKey, limits, usage);
    }
  }

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
      // No reservation was taken and the provider was never consulted, so no
      // credit is consumed. A school must never be charged for a call we
      // refused — least of all for a wallet_empty refusal, which would drive
      // the balance further negative for doing nothing.
      creditsDebited: 0,
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
    const inputTokens = result.usage?.inputTokens ?? 0;
    const outputTokens = result.usage?.outputTokens ?? 0;
    const estimatedCostMicros = estimateCostMicros(model, result.usage);

    if (result.refused) {
      await safeRecord(deps, {
        ...baseEntry(ctx, cfg),
        model,
        outcome: "refused",
        inputTokens,
        outputTokens,
        estimatedCostMicros,
        latencyMs,
        cacheWritten: false,
        fallbackUsed: true,
        // ONE RULE: debit iff the reservation is consumed (see the
        // settleReservation call directly below). The provider WAS consulted and
        // billed us, so the credit is spent — exactly as estimated_cost_micros
        // is. Tying the debit to the same condition as the consume is what keeps
        // wallet and reservation from ever disagreeing.
        creditsDebited: creditsForThisCall,
      });
      // Record-then-consume: if the consume is lost the reservation stays
      // pending until the TTL sweep (over-count, conservative). The one
      // residual undercount is a lost RECORD with a successful consume —
      // bounded to that single call and logged via gateway.record.
      await settleReservation(deps, reservationId, true, estimatedCostMicros);
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

    // Output-side guard (F3): validate the reply against the injected context
    // BEFORE it is served or cached. A violation is discarded — the model was
    // consulted (tokens/cost still logged) but the deterministic fallback wins.
    if (input.guard) {
      const guardOpts = typeof input.guard === "object" ? input.guard : undefined;
      const guardContext = [input.system, ...input.messages.map((m) => m.content)].join("\n");
      const verdict = guardModelReply(result.text, guardContext, guardOpts);
      if (!verdict.ok) {
        await safeRecord(deps, {
          ...baseEntry(ctx, cfg),
          model,
          outcome: "fallback_guard",
          inputTokens,
          outputTokens,
          estimatedCostMicros,
          latencyMs,
          cacheWritten: false,
          fallbackUsed: true,
          // Consumed below => debited. The model was consulted and billed even
          // though its reply failed the output guard.
          creditsDebited: creditsForThisCall,
        });
        await settleReservation(deps, reservationId, true, estimatedCostMicros);
        return {
          text: fallbackText,
          ok: false,
          fallbackUsed: true,
          outcome: "fallback_guard",
          refused: false,
          fromCache: false,
          model,
          usage: result.usage,
        };
      }
    }

    // Write-through: this validated answer becomes a Tier-2 asset (doc 01 §2).
    let cacheWritten = false;
    if (deps.cache) {
      try {
        await deps.cache.write(scope, ctx.surface, result.text, model, outputTokens);
        cacheWritten = true;
      } catch (err) {
        // caching is best-effort; never fail the served answer
        logAiDegradation("gateway.cache_write", err, { surface: ctx.surface });
      }
    }
    await safeRecord(deps, {
      ...baseEntry(ctx, cfg),
      model,
      outcome: "ok",
      inputTokens,
      outputTokens,
      estimatedCostMicros,
      latencyMs,
      cacheWritten,
      fallbackUsed: false,
      // Consumed below => debited. The served answer is what the credit bought.
      creditsDebited: creditsForThisCall,
    });
    await settleReservation(deps, reservationId, true, estimatedCostMicros);
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
      // The reservation is RELEASED below, not consumed, so by the one rule
      // (debit iff consumed) nothing is charged. No tokens were billed, so the
      // school must not lose a credit to our timeout.
      creditsDebited: 0,
    });
    // No tokens were billed on a timeout/transport failure — free the slot.
    await settleReservation(deps, reservationId, false, 0);
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

/**
 * Governed model call for callers that produce STRUCTURED output (parse the
 * model text, else fall back to a computed object). Returns the model text, or
 * null when the gateway did not serve a live answer (no-key / rate / spend cap /
 * timeout / error / refusal) — the caller then uses its own deterministic
 * fallback. All governance (timeout, limits, spend cap, ai_call_log) applies.
 */
export async function governedModelText(
  db: TenantQueryClient,
  ctx: GatewayContext,
  input: GatewayInput,
  opts?: { timeoutMs?: number },
): Promise<string | null> {
  const result = await callModelGateway(db, ctx, input, "", opts);
  return result.ok ? result.text : null;
}

/**
 * The tenant governance handle a module caller threads from its handler so its
 * model call can be routed through the gateway. schoolId is null for org-scoped
 * surfaces (director / org-builder / onboarding).
 */
export interface Governance {
  db: TenantQueryClient;
  organizationId: string;
  schoolId: string | null;
  userId?: string | null;
}

/** governedModelText bound to a {@link Governance} handle + a surface id. */
export function governedTextFor(
  gov: Governance,
  surface: string,
  input: GatewayInput,
  opts?: { timeoutMs?: number },
): Promise<string | null> {
  return governedModelText(gov.db, {
    organizationId: gov.organizationId,
    schoolId: gov.schoolId,
    userId: gov.userId ?? null,
    surface,
  }, input, opts);
}
