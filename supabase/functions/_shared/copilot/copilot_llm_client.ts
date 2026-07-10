import { buildStubAssistantReply } from "./copilot_prompt_orchestrator.ts";
import type { CopilotContextBundle } from "./copilot_context_engine.ts";
import type { CopilotAssistantType } from "./copilot_types.ts";
import {
  type AiProvider,
  callClaude,
  claudeModel,
  type ClaudeMessage,
} from "../ai/anthropic_client.ts";
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
  apiKey?: string | null;
  /** Provider + model from the resolved AI config; default to env when unset. */
  provider?: AiProvider;
  model?: string;
  /**
   * When both are supplied the call is routed through the governed Model
   * Gateway (timeout + rate-limit + spend-cap + telemetry). Omitted by unit
   * tests and any not-yet-migrated caller, which keep the legacy direct path.
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
  "I can't help with that request. I'm Akshara's read-only operational " +
  "assistant — ask me about the school data you have access to and I'll summarize it.";

/**
 * Generate a copilot reply via Claude. Falls back to the deterministic
 * read-only stub when no ANTHROPIC_API_KEY is configured, so the copilot stays
 * safe and functional before the live key is provisioned.
 *
 * A Claude transport/non-OK error (timeout, 5xx, empty completion) also falls
 * back to the same deterministic stub — mirroring predictions_ai.ts and the
 * parent-insights client — so a transport failure yields a graceful assistant
 * reply instead of a 500 that leaves the user's persisted message dangling.
 */
export async function generateCopilotResponse(
  input: CopilotGenerationInput,
): Promise<CopilotGenerationResult> {
  const messages: ClaudeMessage[] = [
    ...boundHistory(input.history).map((m) => ({ role: m.role, content: m.content })),
    { role: "user" as const, content: input.userMessage },
  ];

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
      ...boundHistory(input.history).map((m) => ({ role: m.role, content: m.content })),
      { role: "user" as const, content: fingerprintQuestion(input.userMessage) },
    ];
    const cacheKey = await mintCacheKey({
      surface: "copilot",
      schoolId: input.gatewayContext.schoolId,
      language: "english",
      model: input.model ?? "",
      system: input.systemPrompt,
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
      { system: input.systemPrompt, messages, maxTokens: COPILOT_MAX_TOKENS },
      stub,
      {
        cache: {
          key: cacheKey,
          entityTags: copilotCacheTags(input.assistantType),
          ttlSeconds: 86_400,
          language: "english",
        },
      },
    );
    if (gw.refused) return { content: REFUSAL_REPLY, model: gw.model || "akshara-ai", stub: false };
    if (gw.ok) return { content: gw.text, model: gw.model, stub: false };
    return { content: stub, model: "akshara-stub", stub: true };
  }

  // Legacy direct path (no gateway context) — unchanged behaviour.
  if (!input.apiKey) {
    return {
      content: buildStubAssistantReply(
        input.assistantType,
        input.userMessage,
        input.context,
      ),
      model: "akshara-stub",
      stub: true,
    };
  }

  try {
    const result = await callClaude({
      apiKey: input.apiKey,
      provider: input.provider,
      model: input.model ?? claudeModel(),
      maxTokens: COPILOT_MAX_TOKENS,
      system: input.systemPrompt,
      messages,
    });

    return {
      content: result.refused ? REFUSAL_REPLY : result.text,
      model: result.model,
      stub: false,
    };
  } catch (_error) {
    // Transport/non-OK error — degrade to the deterministic stub rather than
    // propagating a 500 and orphaning the already-persisted user message.
    return {
      content: buildStubAssistantReply(
        input.assistantType,
        input.userMessage,
        input.context,
      ),
      model: "akshara-stub",
      stub: true,
    };
  }
}
