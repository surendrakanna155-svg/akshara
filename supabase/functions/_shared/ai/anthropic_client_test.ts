import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  aiApiKey,
  aiProvider,
  anthropicApiKey,
  callClaude,
  claudeModel,
  DEFAULT_CLAUDE_MODEL,
  DEFAULT_OPENROUTER_MODEL,
  openrouterApiKey,
} from "./anthropic_client.ts";

Deno.test("claudeModel defaults to the latest Opus and honours override", () => {
  Deno.env.delete("ANTHROPIC_MODEL");
  assertEquals(claudeModel(), DEFAULT_CLAUDE_MODEL);
  Deno.env.set("ANTHROPIC_MODEL", "claude-sonnet-4-6");
  assertEquals(claudeModel(), "claude-sonnet-4-6");
  Deno.env.delete("ANTHROPIC_MODEL");
});

Deno.test("anthropicApiKey is undefined when unset or blank", () => {
  Deno.env.delete("ANTHROPIC_API_KEY");
  assertEquals(anthropicApiKey(), undefined);
  Deno.env.set("ANTHROPIC_API_KEY", "   ");
  assertEquals(anthropicApiKey(), undefined);
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  assertEquals(anthropicApiKey(), "sk-ant-test");
  Deno.env.delete("ANTHROPIC_API_KEY");
});

Deno.test("callClaude throws without an api key", async () => {
  await assertRejects(
    () => callClaude({ apiKey: "", system: "s", messages: [{ role: "user", content: "hi" }] }),
    Error,
    "AI API key not configured",
  );
});

Deno.test("aiProvider defaults to anthropic and honours openrouter", () => {
  Deno.env.delete("AI_PROVIDER");
  assertEquals(aiProvider(), "anthropic");
  Deno.env.set("AI_PROVIDER", "openrouter");
  assertEquals(aiProvider(), "openrouter");
  Deno.env.delete("AI_PROVIDER");
});

Deno.test("aiApiKey + claudeModel follow the active provider", () => {
  Deno.env.delete("AI_PROVIDER");
  Deno.env.delete("ANTHROPIC_MODEL");
  Deno.env.delete("AI_MODEL");
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  Deno.env.set("OPENROUTER_API_KEY", "sk-or-test");

  // Anthropic (default)
  assertEquals(aiApiKey(), "sk-ant-test");
  assertEquals(claudeModel(), DEFAULT_CLAUDE_MODEL);

  // OpenRouter
  Deno.env.set("AI_PROVIDER", "openrouter");
  assertEquals(aiApiKey(), "sk-or-test");
  assertEquals(claudeModel(), DEFAULT_OPENROUTER_MODEL);
  Deno.env.set("AI_MODEL", "openai/gpt-4o-mini");
  assertEquals(claudeModel(), "openai/gpt-4o-mini");

  Deno.env.delete("AI_PROVIDER");
  Deno.env.delete("AI_MODEL");
  Deno.env.delete("ANTHROPIC_API_KEY");
  Deno.env.delete("OPENROUTER_API_KEY");
  assertEquals(openrouterApiKey(), undefined);
});

Deno.test("callClaude routes to OpenRouter with OpenAI shape when selected", async () => {
  const original = globalThis.fetch;
  let capturedUrl = "";
  let capturedInit: RequestInit | undefined;
  globalThis.fetch = ((url: string | URL | Request, init?: RequestInit) => {
    capturedUrl = String(url);
    capturedInit = init;
    return Promise.resolve(
      new Response(
        JSON.stringify({
          model: "anthropic/claude-sonnet-4-6",
          choices: [{ finish_reason: "stop", message: { content: "Routed via OpenRouter." } }],
          usage: { prompt_tokens: 9, completion_tokens: 4 },
        }),
        { status: 200 },
      ),
    );
  }) as typeof fetch;

  try {
    const result = await callClaude({
      apiKey: "sk-or-test",
      provider: "openrouter",
      model: "anthropic/claude-sonnet-4-6",
      maxTokens: 256,
      system: "You are read-only.",
      messages: [{ role: "user", content: "How are collections?" }],
    });

    assertEquals(capturedUrl, "https://openrouter.ai/api/v1/chat/completions");
    const headers = capturedInit?.headers as Record<string, string>;
    assertEquals(headers["authorization"], "Bearer sk-or-test");

    const body = JSON.parse(String(capturedInit?.body));
    assertEquals(body.model, "anthropic/claude-sonnet-4-6");
    // OpenAI shape: system is the first message, not a top-level field.
    assertEquals(body.system, undefined);
    assertEquals(body.messages[0].role, "system");
    assertEquals(body.messages[1].role, "user");
    assertEquals("temperature" in body, false);

    assertEquals(result.text, "Routed via OpenRouter.");
    assertEquals(result.refused, false);
    assertEquals(result.usage?.inputTokens, 9);
    assertEquals(result.usage?.outputTokens, 4);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("callClaude maps OpenRouter content_filter to a refusal", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          model: "anthropic/claude-sonnet-4-6",
          choices: [{ finish_reason: "content_filter", message: { content: "" } }],
        }),
        { status: 200 },
      ),
    )) as typeof fetch;
  try {
    const result = await callClaude({
      apiKey: "sk-or-test",
      provider: "openrouter",
      system: "s",
      messages: [{ role: "user", content: "do something disallowed" }],
    });
    assertEquals(result.refused, true);
    assertEquals(result.text, "");
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("callClaude sends the Anthropic request shape and parses text", async () => {
  const original = globalThis.fetch;
  let capturedUrl = "";
  let capturedInit: RequestInit | undefined;
  globalThis.fetch = ((url: string | URL | Request, init?: RequestInit) => {
    capturedUrl = String(url);
    capturedInit = init;
    return Promise.resolve(
      new Response(
        JSON.stringify({
          model: "claude-opus-4-8",
          stop_reason: "end_turn",
          content: [{ type: "text", text: "Collections are healthy." }],
          usage: { input_tokens: 12, output_tokens: 5 },
        }),
        { status: 200 },
      ),
    );
  }) as typeof fetch;

  try {
    const result = await callClaude({
      apiKey: "sk-ant-test",
      model: "claude-opus-4-8",
      maxTokens: 256,
      system: "You are read-only.",
      messages: [{ role: "user", content: "How are collections?" }],
    });

    assertEquals(capturedUrl, "https://api.anthropic.com/v1/messages");
    const headers = capturedInit?.headers as Record<string, string>;
    assertEquals(headers["x-api-key"], "sk-ant-test");
    assertEquals(headers["anthropic-version"], "2023-06-01");

    const body = JSON.parse(String(capturedInit?.body));
    assertEquals(body.model, "claude-opus-4-8");
    assertEquals(body.system, "You are read-only.");
    assertEquals(body.max_tokens, 256);
    assertEquals(body.messages.length, 1);
    // temperature/top_p/top_k must NOT be sent (rejected on Opus 4.8).
    assertEquals("temperature" in body, false);
    assertEquals("top_p" in body, false);

    assertEquals(result.text, "Collections are healthy.");
    assertEquals(result.refused, false);
    assertEquals(result.usage?.inputTokens, 12);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("callClaude surfaces refusals without throwing", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify({ model: "claude-opus-4-8", stop_reason: "refusal", content: [] }),
        { status: 200 },
      ),
    )) as typeof fetch;
  try {
    const result = await callClaude({
      apiKey: "sk-ant-test",
      system: "s",
      messages: [{ role: "user", content: "do something disallowed" }],
    });
    assertEquals(result.refused, true);
    assertEquals(result.text, "");
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("callClaude throws on a non-ok HTTP response", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(new Response("rate limited", { status: 429 }))) as typeof fetch;
  try {
    await assertRejects(
      () =>
        callClaude({
          apiKey: "sk-ant-test",
          system: "s",
          messages: [{ role: "user", content: "hi" }],
        }),
      Error,
      "Anthropic request failed: 429",
    );
  } finally {
    globalThis.fetch = original;
  }
});
