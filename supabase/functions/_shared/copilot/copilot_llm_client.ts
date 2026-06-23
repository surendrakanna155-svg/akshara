import { buildStubAssistantReply } from "./copilot_prompt_orchestrator.ts";
import type { CopilotContextBundle } from "./copilot_context_engine.ts";
import type { CopilotAssistantType } from "./copilot_types.ts";
import { callClaude, claudeModel, type ClaudeMessage } from "../ai/anthropic_client.ts";

export interface CopilotGenerationInput {
  systemPrompt: string;
  history: Array<{ role: "user" | "assistant"; content: string }>;
  userMessage: string;
  assistantType: CopilotAssistantType;
  context: CopilotContextBundle;
  apiKey?: string | null;
}

export interface CopilotGenerationResult {
  content: string;
  model: string;
  stub: boolean;
}

const COPILOT_MAX_TOKENS = 1024;

const REFUSAL_REPLY =
  "I can't help with that request. I'm Akshara's read-only operational " +
  "assistant — ask me about the school data you have access to and I'll summarize it.";

/**
 * Generate a copilot reply via Claude. Falls back to the deterministic
 * read-only stub when no ANTHROPIC_API_KEY is configured, so the copilot stays
 * safe and functional before the live key is provisioned.
 */
export async function generateCopilotResponse(
  input: CopilotGenerationInput,
): Promise<CopilotGenerationResult> {
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

  const messages: ClaudeMessage[] = [
    ...input.history.map((m) => ({ role: m.role, content: m.content })),
    { role: "user" as const, content: input.userMessage },
  ];

  const result = await callClaude({
    apiKey: input.apiKey,
    model: claudeModel(),
    maxTokens: COPILOT_MAX_TOKENS,
    system: input.systemPrompt,
    messages,
  });

  return {
    content: result.refused ? REFUSAL_REPLY : result.text,
    model: result.model,
    stub: false,
  };
}
