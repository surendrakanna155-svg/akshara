// Shared Anthropic (Claude) client for Akshara AI surfaces.
//
// One place to talk to the Claude Messages API so every AI feature (copilot,
// parent insights, future question-intelligence) shares the same request shape,
// refusal handling, and model/key configuration. Raw `fetch` (Deno edge
// function) — no SDK dependency, matching the rest of the backend.
//
// Provider/model is config-driven: ANTHROPIC_API_KEY enables live calls,
// ANTHROPIC_MODEL overrides the default. With no key, callers fall back to
// their own safe deterministic/stub output — nothing here ever fabricates.

export const DEFAULT_CLAUDE_MODEL = "claude-opus-4-8";
const ANTHROPIC_MESSAGES_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

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
}

export interface ClaudeUsage {
  inputTokens: number;
  outputTokens: number;
}

export interface ClaudeCallResult {
  /** Concatenated text of all `text` content blocks (empty on refusal). */
  text: string;
  model: string;
  /** true when the safety classifier declined (stop_reason === "refusal"). */
  refused: boolean;
  usage: ClaudeUsage | null;
}

/** The configured Anthropic API key, or undefined when AI is not enabled. */
export function anthropicApiKey(): string | undefined {
  const key = Deno.env.get("ANTHROPIC_API_KEY")?.trim();
  return key && key.length > 0 ? key : undefined;
}

/** The configured Claude model, defaulting to the latest Opus. */
export function claudeModel(): string {
  return Deno.env.get("ANTHROPIC_MODEL")?.trim() || DEFAULT_CLAUDE_MODEL;
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

/**
 * Call the Claude Messages API. Caller must supply a non-empty `apiKey`
 * (gate on {@link anthropicApiKey} and fall back to deterministic output when
 * it is absent). Throws on transport/HTTP errors so callers can fall back.
 *
 * Note: `temperature`/`top_p`/`top_k` are intentionally NOT sent — they are
 * rejected (HTTP 400) on Opus 4.8 / 4.7 and the Fable family.
 */
export async function callClaude(input: ClaudeCallInput): Promise<ClaudeCallResult> {
  if (!input.apiKey) {
    throw new Error("ANTHROPIC_API_KEY not configured");
  }
  const model = input.model ?? claudeModel();
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
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(
      `Anthropic request failed: ${response.status} ${body.slice(0, 200)}`,
    );
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
