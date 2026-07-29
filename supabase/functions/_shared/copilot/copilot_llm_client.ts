import { buildStubAssistantReply } from "./copilot_prompt_orchestrator.ts";
import type { CopilotContextBundle } from "./copilot_context_engine.ts";
import type { CopilotAssistantType } from "./copilot_types.ts";
import type { ClaudeMessage } from "../ai/anthropic_client.ts";
import { callModelGateway } from "../ai/model_gateway.ts";
import { mintCacheKey } from "../ai/ai_response_cache_repository.ts";
import { fingerprintQuestion } from "../ai/intent_fingerprint.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

export interface CopilotGenerationInput {
  systemPrompt: string;
  history: Array<{ role: "user" | "assistant"; content: string }>;
  userMessage: string;
  assistantType: CopilotAssistantType;
  context: CopilotContextBundle;
  /** Model id — used only to mint the Tier-2 cache-key signature; the model
   * actually served is whatever the gateway resolves. */
  model?: string;
  /**
   * Tenant DB + governance context. When both are supplied the call is routed
   * through the governed Model Gateway (timeout + rate-limit + spend-cap +
   * telemetry) — the ONLY structural path to a live model call (F12). Absent
   * only for callers with no tenant context (and unit tests exercising the
   * stub), which get the deterministic read-only stub — never a raw client call.
   */
  db?: TenantQueryClient;
  gatewayContext?: {
    organizationId: string;
    schoolId: string;
    userId?: string | null;
  };
}

export interface CopilotGenerationResult {
  content: string;
  model: string;
  stub: boolean;
  /** Deterministic summary of the turns dropped from the window (F5), for the
   * handler to persist to ai_copilot_sessions.rolling_summary. Undefined when
   * nothing was dropped. */
  rollingSummary?: string;
  /** How many older turns the summary condenses. */
  summarizedCount?: number;
}

const COPILOT_MAX_TOKENS = 1024;

/** Cap the raw turns re-sent each request (W1.3). Older turns are dropped rather
 * than resending the full transcript every turn — a large token saving on long
 * conversations. (The ai_copilot_sessions.rolling_summary column added in W1.2
 * is the substrate for summarizing the dropped prefix in a later refinement.) */
export const MAX_HISTORY_TURNS = 12;

export function boundHistory<T>(history: T[], maxTurns = MAX_HISTORY_TURNS): T[] {
  return history.length <= maxTurns ? history : history.slice(history.length - maxTurns);
}

/** Per-surface context budget for the copilot T3 call (F7 / doc 02 §7). ~3k
 * tokens at ≈4 chars/token — a hard ceiling on the assembled system prompt so a
 * data-heavy school can never inflate the prompt (cost/latency) unbounded. */
export const MAX_CONTEXT_CHARS = 12_000;

/** Cap the assembled context to the budget, truncating at a line boundary so a
 * fact is never split mid-value (the model then works from bounded context; any
 * number it can't ground is caught by the output guard). */
export function capContext(system: string, maxChars = MAX_CONTEXT_CHARS): string {
  if (system.length <= maxChars) return system;
  const head = system.slice(0, maxChars);
  const lastNl = head.lastIndexOf("\n");
  const body = lastNl > maxChars * 0.5 ? head.slice(0, lastNl) : head;
  return `${body}\n[context truncated to fit the budget]`;
}

const SUMMARY_STOPWORDS = new Set([
  "the", "and", "for", "are", "was", "were", "you", "your", "our", "this",
  "that", "with", "have", "has", "can", "could", "would", "please", "what",
  "when", "who", "how", "why", "which", "show", "tell", "give", "list",
  "about", "any", "there", "here", "from", "into", "does", "did", "not",
]);

/** Deterministic summary of the older turns dropped by boundHistory (W1.3/F5):
 * long-conversation context is condensed, not silently lost. Zero model calls —
 * the turn count plus the salient non-stopword keywords from the dropped USER
 * turns. Numbers are intentionally excluded (the reply's numbers are grounded
 * against the live facts, not a lossy history summary). */
export function summarizeCopilotHistory(
  dropped: Array<{ role: "user" | "assistant"; content: string }>,
): string {
  if (dropped.length === 0) return "";
  const seen = new Set<string>();
  const keywords: string[] = [];
  for (const m of dropped) {
    if (m.role !== "user") continue;
    const toks = m.content.toLowerCase().replace(/[^\p{L}\s]/gu, " ").split(/\s+/);
    for (const tok of toks) {
      if (tok.length < 3 || SUMMARY_STOPWORDS.has(tok) || seen.has(tok)) continue;
      seen.add(tok);
      keywords.push(tok);
      if (keywords.length >= 16) break;
    }
    if (keywords.length >= 16) break;
  }
  const topics = keywords.length > 0 ? keywords.join(", ") : "general school queries";
  return `${dropped.length} earlier message(s) in this conversation covered: ${topics}.`;
}

/** School-level cache entity tags this assistant's answers depend on, so the
 * Signal Refinery (W1.4) can proactively evict a cached answer when the
 * underlying data changes (audit F2 — writes must carry tags for invalidation
 * to match). Coarse-but-safe: the content-hash cache key already guarantees
 * correctness (a fact change mints a new key); tags add proactive freshness. */
export function copilotCacheTags(assistantType: CopilotAssistantType): string[] {
  switch (assistantType) {
    case "finance":
      return ["school:fees"];
    case "admissions":
      return ["school:admissions"];
    case "academic":
      return ["school:exams", "school:homework", "school:attendance"];
    case "teacher":
      return ["school:attendance", "school:exams", "school:homework"];
    case "sis":
      return ["school:attendance", "school:admissions"];
    case "parentGuidance":
      return ["school:fees", "school:attendance", "school:exams"];
    case "principal":
      return [
        "school:fees",
        "school:attendance",
        "school:exams",
        "school:approvals",
        "school:admissions",
      ];
    case "communication":
      return [];
  }
}

const REFUSAL_REPLY =
  "I can't help with that request. I'm NIKSHA's read-only operational " +
  "assistant — ask me about the school data you have access to and I'll summarize it.";

/**
 * Generate a copilot reply via the governed Model Gateway (F12: the ONLY
 * structural path to a live model call — there is no direct-to-provider
 * fallback here or anywhere else in this function). No key configured, a rate
 * limit, a spend cap, a timeout, a transport/non-OK error, or a missing
 * db/gatewayContext all degrade to the same deterministic read-only stub, so
 * the copilot stays safe and functional before a live key is provisioned and a
 * transport failure never surfaces a 500 that leaves the user's persisted
 * message dangling.
 */
export async function generateCopilotResponse(
  input: CopilotGenerationInput,
): Promise<CopilotGenerationResult> {
  const bounded = boundHistory(input.history);
  const messages: ClaudeMessage[] = [
    ...bounded.map((m) => ({ role: m.role, content: m.content })),
    { role: "user" as const, content: input.userMessage },
  ];

  // F5: condense the dropped older prefix into a deterministic rolling summary
  // and fold it into the system prompt (used for BOTH the model call AND the
  // cache key), so long-conversation context is summarized, not silently lost —
  // and two conversations with the same last-K but a different history don't
  // collide on the cache key.
  const summarizedCount = Math.max(0, input.history.length - MAX_HISTORY_TURNS);
  const rollingSummary = summarizedCount > 0
    ? summarizeCopilotHistory(input.history.slice(0, summarizedCount))
    : "";
  // F7: cap the context to the per-surface budget (the big part is the built
  // system prompt), then append the small rolling summary so it survives.
  const cappedBase = capContext(input.systemPrompt);
  const effectiveSystem = rollingSummary
    ? `${cappedBase}\n\n[Earlier conversation summary]\n${rollingSummary}`
    : cappedBase;
  const summaryFields = summarizedCount > 0 ? { rollingSummary, summarizedCount } : {};

  // Governed path: route through the Model Gateway when a tenant db + context
  // are supplied (production). Adds timeout/rate-limit/spend-cap/telemetry while
  // preserving the deterministic-stub and refusal semantics below: a
  // no-key/limit/timeout/error outcome returns the stub; a refusal returns the
  // read-only refusal reply; a real answer is served verbatim.
  if (input.db && input.gatewayContext) {
    const stub = buildStubAssistantReply(
      input.assistantType,
      input.userMessage,
      input.context,
    );
    // Tier-2 cache key over the prompt signature. The current question is
    // fingerprinted (W1.5) so paraphrases share one generation; the system
    // prompt embeds the live facts, so any data change still busts the key and
    // a hit never serves stale data.
    const keyMessages = [
      ...bounded.map((m) => ({ role: m.role, content: m.content })),
      { role: "user" as const, content: fingerprintQuestion(input.userMessage) },
    ];
    const cacheKey = await mintCacheKey({
      surface: "copilot",
      schoolId: input.gatewayContext.schoolId,
      language: "english",
      model: input.model ?? "",
      system: effectiveSystem,
      messages: keyMessages,
    });
    const gw = await callModelGateway(
      input.db,
      {
        organizationId: input.gatewayContext.organizationId,
        schoolId: input.gatewayContext.schoolId,
        userId: input.gatewayContext.userId ?? null,
        surface: "copilot",
      },
      { system: effectiveSystem, messages, maxTokens: COPILOT_MAX_TOKENS, guard: true },
      stub,
      {
        cache: {
          key: cacheKey,
          entityTags: copilotCacheTags(input.assistantType),
          ttlSeconds: 86_400,
          language: "english",
          // W2.8 Stage-2: an exact-fingerprint miss falls through to an
          // embedding-nearest lookup over the same cached answers (dormant
          // until an embeddings key + pgvector are provisioned).
          semanticText: input.userMessage,
          semanticSurface: "copilot",
        },
      },
    );
    if (gw.refused) {
      return { content: REFUSAL_REPLY, model: gw.model || "akshara-ai", stub: false, ...summaryFields };
    }
    if (gw.ok) return { content: gw.text, model: gw.model, stub: false, ...summaryFields };
    return { content: stub, model: "akshara-stub", stub: true, ...summaryFields };
  }

  // No tenant governance context (e.g. no db/gatewayContext supplied) — never
  // call the raw client; return the deterministic read-only stub.
  return {
    content: buildStubAssistantReply(
      input.assistantType,
      input.userMessage,
      input.context,
    ),
    model: "akshara-stub",
    stub: true,
    ...summaryFields,
  };
}
