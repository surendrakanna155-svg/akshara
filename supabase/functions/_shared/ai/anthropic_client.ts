// Shared AI client for Akshara AI surfaces (copilot, parent insights,
// question-intelligence gap-fill).
//
// Provider is config-driven so the same call sites work against either:
//   • Anthropic directly  (AI_PROVIDER=anthropic, default) — POST api.anthropic.com
//   • OpenRouter          (AI_PROVIDER=openrouter)         — POST openrouter.ai
//                                                            (OpenAI-compatible)
// One key change switches everything; no code edit needed to swap provider,
// key, or model — see deploy/akshara-vps/.env.akshara.example.
//
// With no key for the active provider, callers fall back to their own safe
// deterministic/stub output — nothing here ever fabricates.

export const DEFAULT_CLAUDE_MODEL = "claude-opus-4-8";
/** Default OpenRouter model — Claude via OpenRouter (system is tuned for Claude;
 * Sonnet balances quality and cost). Override with AI_MODEL / OPENROUTER_MODEL. */
export const DEFAULT_OPENROUTER_MODEL = "anthropic/claude-sonnet-4-6";

const ANTHROPIC_MESSAGES_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";
const OPENROUTER_CHAT_URL = "https://openrouter.ai/api/v1/chat/completions";

export type AiProvider = "anthropic" | "openrouter";

export interface ClaudeMessage {
  role: "user" | "assistant";
  content: string;
}

export interface ClaudeCallInput {
  system: string;
  messages: ClaudeMessage[];
  maxTokens?: number;
  model?: string;
  apiKey: string;
  /** Defaults to the configured {@link aiProvider}. */
  provider?: AiProvider;
  /**
   * Optional abort signal for a per-request timeout. The Model Gateway
   * (`model_gateway.ts`) supplies one so a hung provider call aborts and falls
   * back deterministically (closes AI-3); direct callers may omit it.
   */
  signal?: AbortSignal;
}

export interface ClaudeUsage {
  inputTokens: number;
  outputTokens: number;
}

export interface ClaudeCallResult {
  /** Concatenated assistant text (empty on refusal). */
  text: string;
  model: string;
  /** true when the provider declined (refusal / content filter). */
  refused: boolean;
  usage: ClaudeUsage | null;
}

/** Which AI provider is configured. Defaults to Anthropic-direct. */
export function aiProvider(): AiProvider {
  return Deno.env.get("AI_PROVIDER")?.trim().toLowerCase() === "openrouter"
    ? "openrouter"
    : "anthropic";
}

function trimmedEnv(name: string): string | undefined {
  const value = Deno.env.get(name)?.trim();
  return value && value.length > 0 ? value : undefined;
}

/** The Anthropic-direct API key, or undefined when unset. */
export function anthropicApiKey(): string | undefined {
  return trimmedEnv("ANTHROPIC_API_KEY");
}

/** The OpenRouter API key, or undefined when unset. */
export function openrouterApiKey(): string | undefined {
  return trimmedEnv("OPENROUTER_API_KEY");
}

/**
 * The API key for the active provider, or undefined when AI is not enabled.
 * Callers gate on this and fall back to deterministic output when it is unset.
 */
export function aiApiKey(): string | undefined {
  return aiProvider() === "openrouter" ? openrouterApiKey() : anthropicApiKey();
}

/** The configured model for the active provider. */
export function claudeModel(): string {
  if (aiProvider() === "openrouter") {
    return trimmedEnv("AI_MODEL") ?? trimmedEnv("OPENROUTER_MODEL") ?? DEFAULT_OPENROUTER_MODEL;
  }
  return trimmedEnv("ANTHROPIC_MODEL") ?? trimmedEnv("AI_MODEL") ?? DEFAULT_CLAUDE_MODEL;
}

interface AnthropicContentBlock {
  type: string;
  text?: string;
}

interface AnthropicResponse {
  content?: AnthropicContentBlock[];
  model?: string;
  stop_reason?: string;
  usage?: { input_tokens?: number; output_tokens?: number };
}

interface OpenRouterResponse {
  model?: string;
  choices?: Array<{
    finish_reason?: string;
    message?: { content?: string | null };
  }>;
  usage?: { prompt_tokens?: number; completion_tokens?: number };
}

/**
 * Call the configured AI provider. Caller must supply a non-empty `apiKey`
 * (gate on {@link aiApiKey} and fall back to deterministic output when absent).
 * Throws on transport/HTTP errors so callers can fall back.
 *
 * Note: `temperature`/`top_p`/`top_k` are intentionally NOT sent — they are
 * rejected (HTTP 400) on Opus 4.8/4.7 and the Fable family, and omitting them
 * is harmless on OpenRouter (provider defaults apply).
 */
export async function callClaude(input: ClaudeCallInput): Promise<ClaudeCallResult> {
  if (!input.apiKey) {
    throw new Error("AI API key not configured");
  }
  const provider = input.provider ?? aiProvider();
  const model = input.model ?? claudeModel();
  return provider === "openrouter"
    ? await callOpenRouter(input, model)
    : await callAnthropic(input, model);
}

async function callAnthropic(input: ClaudeCallInput, model: string): Promise<ClaudeCallResult> {
  const response = await fetch(ANTHROPIC_MESSAGES_URL, {
    method: "POST",
    headers: {
      "x-api-key": input.apiKey,
      "anthropic-version": ANTHROPIC_VERSION,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model,
      max_tokens: input.maxTokens ?? 1024,
      system: input.system,
      messages: input.messages,
    }),
    signal: input.signal,
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Anthropic request failed: ${response.status} ${body.slice(0, 200)}`);
  }

  const payload = await response.json() as AnthropicResponse;
  const refused = payload.stop_reason === "refusal";
  const text = (payload.content ?? [])
    .filter((block) => block.type === "text" && typeof block.text === "string")
    .map((block) => block.text!.trim())
    .filter((part) => part.length > 0)
    .join("\n\n");

  if (!refused && !text) {
    throw new Error("Anthropic returned an empty completion");
  }

  return {
    text,
    model: payload.model ?? model,
    refused,
    usage: payload.usage
      ? {
        inputTokens: payload.usage.input_tokens ?? 0,
        outputTokens: payload.usage.output_tokens ?? 0,
      }
      : null,
  };
}

async function callOpenRouter(input: ClaudeCallInput, model: string): Promise<ClaudeCallResult> {
  // OpenAI-compatible Chat Completions shape: system is a message, not top-level.
  const messages = [
    { role: "system", content: input.system },
    ...input.messages.map((m) => ({ role: m.role, content: m.content })),
  ];
  const response = await fetch(OPENROUTER_CHAT_URL, {
    method: "POST",
    headers: {
      "authorization": `Bearer ${input.apiKey}`,
      "content-type": "application/json",
      // Optional OpenRouter attribution headers — harmless if ignored.
      "x-title": "Akshara",
    },
    body: JSON.stringify({
      model,
      max_tokens: input.maxTokens ?? 1024,
      messages,
    }),
    signal: input.signal,
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenRouter request failed: ${response.status} ${body.slice(0, 200)}`);
  }

  const payload = await response.json() as OpenRouterResponse;
  const choice = payload.choices?.[0];
  const refused = choice?.finish_reason === "content_filter";
  const text = (choice?.message?.content ?? "").trim();

  if (!refused && !text) {
    throw new Error("OpenRouter returned an empty completion");
  }

  return {
    text,
    model: payload.model ?? model,
    refused,
    usage: payload.usage
      ? {
        inputTokens: payload.usage.prompt_tokens ?? 0,
        outputTokens: payload.usage.completion_tokens ?? 0,
      }
      : null,
  };
}
