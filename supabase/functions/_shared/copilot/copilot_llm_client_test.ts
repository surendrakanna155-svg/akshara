import { assertEquals } from "jsr:@std/assert@1";
import { generateCopilotResponse } from "./copilot_llm_client.ts";
import type { CopilotContextBundle } from "./copilot_context_engine.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

/** Fake tenant client for the gateway path: no provider-config row (falls to
 * env), zero usage counters, INSERTs accepted. */
function fakeGatewayDb(): TenantQueryClient {
  return {
    queryObject: (sql: string) => {
      if (sql.includes("count(*)")) return Promise.resolve([{ n: 0 }]);
      if (sql.includes("sum(")) return Promise.resolve([{ total: 0 }]);
      return Promise.resolve([]);
    },
    // deno-lint-ignore no-explicit-any
  } as any as TenantQueryClient;
}

const GATEWAY_CTX = { organizationId: "org-1", schoolId: "s1", userId: "u-1" };

function clearAiKeyEnv() {
  for (const k of ["AI_PROVIDER", "ANTHROPIC_API_KEY", "OPENROUTER_API_KEY", "AI_RATE_USER_PER_HOUR", "AI_RATE_SCHOOL_PER_DAY", "AI_MONTHLY_SPEND_CAP_MICROS"]) {
    Deno.env.delete(k);
  }
}

const baseContext: CopilotContextBundle = {
  school: { schoolId: "s1", name: "Akshara", code: "AKS" },
  academicYear: { label: "2026-27", status: "active" },
  finance: { access: "granted", completedCollections: 3, collectedAmount: "1000" },
  admissions: { access: "denied" },
  sis: { access: "denied" },
  communication: { access: "denied" },
  timetable: { access: "denied" },
  teacherOps: { access: "denied" },
  analytics: { access: "denied" },
  studentLookup: { access: "not_requested" },
};

function baseInput(apiKey?: string | null) {
  return {
    systemPrompt: "read-only policy",
    history: [],
    userMessage: "Summarize collections",
    assistantType: "finance" as const,
    context: baseContext,
    apiKey,
  };
}

Deno.test("copilot response is the deterministic stub without an api key", async () => {
  const result = await generateCopilotResponse(baseInput(undefined));
  assertEquals(result.stub, true);
  assertEquals(result.model, "akshara-stub");
  assertEquals(result.content.includes("read-only"), true);
});

Deno.test("copilot response falls back to the stub when Claude transport throws", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (() => Promise.reject(new Error("network down"))) as typeof fetch;
  try {
    // Must not throw — a transport failure degrades to the deterministic stub
    // so the handler never returns 500 with a dangling user message.
    const result = await generateCopilotResponse(baseInput("sk-ant-test"));
    assertEquals(result.stub, true);
    assertEquals(result.model, "akshara-stub");
    assertEquals(result.content.includes("read-only"), true);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("copilot response falls back to the stub on a non-OK Claude response", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(new Response("upstream error", { status: 503 }))) as typeof fetch;
  try {
    const result = await generateCopilotResponse(baseInput("sk-ant-test"));
    assertEquals(result.stub, true);
    assertEquals(result.model, "akshara-stub");
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("gateway path: no key configured → deterministic stub (W1.1b wiring)", async () => {
  clearAiKeyEnv();
  const result = await generateCopilotResponse({
    ...baseInput(undefined),
    db: fakeGatewayDb(),
    gatewayContext: GATEWAY_CTX,
  });
  assertEquals(result.stub, true);
  assertEquals(result.model, "akshara-stub");
  clearAiKeyEnv();
});

Deno.test("gateway path: serves the real model answer when a key is present", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const original = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          content: [{ type: "text", text: "Collections: ₹1000 collected." }],
          model: "claude-opus-4-8",
          stop_reason: "end_turn",
          usage: { input_tokens: 12, output_tokens: 9 },
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
    )) as typeof fetch;
  try {
    const result = await generateCopilotResponse({
      ...baseInput("sk-ant-test"),
      db: fakeGatewayDb(),
      gatewayContext: GATEWAY_CTX,
    });
    assertEquals(result.stub, false);
    assertEquals(result.content, "Collections: ₹1000 collected.");
    assertEquals(result.model, "claude-opus-4-8");
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});
