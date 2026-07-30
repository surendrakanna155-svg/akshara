import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  boundHistory,
  capContext,
  generateCopilotResponse,
  MAX_CONTEXT_CHARS,
  MAX_HISTORY_TURNS,
  summarizeCopilotHistory,
} from "./copilot_llm_client.ts";
import type { CopilotContextBundle } from "./copilot_context_engine.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

/** Fake tenant client for the gateway path: no provider-config row (falls to
 * env), zero usage counters, INSERTs accepted. Optionally returns a cache hit
 * for the ai_response_cache lookup. */
function fakeGatewayDb(cacheHit?: { payload: string; model: string }): TenantQueryClient {
  return {
    queryObject: (sql: string) => {
      if (sql.includes("count(*)")) return Promise.resolve([{ n: 0 }]);
      if (sql.includes("sum(")) return Promise.resolve([{ total: 0 }]);
      if (cacheHit && sql.trimStart().startsWith("SELECT") && sql.includes("FROM ai_response_cache")) {
        return Promise.resolve([{ id: "c1", payload: cacheHit.payload, model: cacheHit.model }]);
      }
      return Promise.resolve([]);
    },
    // deno-lint-ignore no-explicit-any
  } as any as TenantQueryClient;
}

const GATEWAY_CTX = { organizationId: "org-1", schoolId: "s1", userId: "u-1" };

/** Stateful cache fake: write-through persists, keyed by the cache_key param, so
 * a paraphrase that mints the same key hits on the second call. */
function statefulCacheDb(): TenantQueryClient {
  const store = new Map<string, { payload: string; model: string }>();
  return {
    queryObject: (sql: string, params?: unknown[]) => {
      if (sql.includes("count(*)")) return Promise.resolve([{ n: 0 }]);
      if (sql.includes("sum(")) return Promise.resolve([{ total: 0 }]);
      const s = sql.trimStart();
      if (s.startsWith("SELECT") && sql.includes("FROM ai_response_cache")) {
        const hit = store.get(params?.[2] as string);
        return Promise.resolve(hit ? [{ id: "c1", payload: hit.payload, model: hit.model }] : []);
      }
      if (s.startsWith("INSERT") && sql.includes("ai_response_cache")) {
        store.set(params?.[2] as string, {
          payload: params?.[5] as string,
          model: params?.[7] as string,
        });
        return Promise.resolve([]);
      }
      return Promise.resolve([]);
    },
    // deno-lint-ignore no-explicit-any
  } as any as TenantQueryClient;
}

function clearAiKeyEnv() {
  for (const k of ["AI_PROVIDER", "ANTHROPIC_API_KEY", "OPENROUTER_API_KEY", "AI_RATE_USER_PER_HOUR", "AI_RATE_SCHOOL_PER_DAY", "AI_MONTHLY_SPEND_CAP_MICROS"]) {
    Deno.env.delete(k);
  }
}

const baseContext: CopilotContextBundle = {
  school: { schoolId: "s1", name: "NIKSHA", code: "AKS" },
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

function baseInput() {
  return {
    systemPrompt: "read-only policy",
    history: [],
    userMessage: "Summarize collections",
    assistantType: "finance" as const,
    context: baseContext,
  };
}

Deno.test("boundHistory keeps only the last K turns (W1.3 token bounding)", () => {
  const short = [{ n: 1 }, { n: 2 }];
  assertEquals(boundHistory(short), short); // untouched when under the cap
  const long = Array.from({ length: MAX_HISTORY_TURNS + 8 }, (_, i) => ({ n: i }));
  const bounded = boundHistory(long);
  assertEquals(bounded.length, MAX_HISTORY_TURNS);
  assertEquals(bounded[0], { n: 8 }); // oldest 8 dropped
  assertEquals(bounded[bounded.length - 1], { n: MAX_HISTORY_TURNS + 7 });
  assert(bounded.length < long.length);
});

Deno.test("copilot response is the deterministic stub without a gateway context", async () => {
  // No db/gatewayContext supplied (e.g. a caller with no tenant context) —
  // F12: there is no direct-callClaude fallback left to reach; the ONLY
  // structural path to a live model call is the governed gateway branch below.
  const result = await generateCopilotResponse(baseInput());
  assertEquals(result.stub, true);
  assertEquals(result.model, "akshara-stub");
  assertEquals(result.content.includes("read-only"), true);
});

Deno.test("copilot response never dials out without a gateway context, even if fetch would throw", async () => {
  const original = globalThis.fetch;
  let fetchCalls = 0;
  globalThis.fetch = (() => {
    fetchCalls++;
    return Promise.reject(new Error("must not be called"));
  }) as typeof fetch;
  try {
    const result = await generateCopilotResponse(baseInput());
    assertEquals(result.stub, true);
    assertEquals(result.model, "akshara-stub");
    assertEquals(fetchCalls, 0);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("gateway path: falls back to the stub when the model transport throws", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const original = globalThis.fetch;
  globalThis.fetch = (() => Promise.reject(new Error("network down"))) as typeof fetch;
  try {
    // Must not throw — a transport failure degrades to the deterministic stub
    // so the handler never returns 500 with a dangling user message.
    const result = await generateCopilotResponse({
      ...baseInput(),
      db: fakeGatewayDb(),
      gatewayContext: GATEWAY_CTX,
    });
    assertEquals(result.stub, true);
    assertEquals(result.model, "akshara-stub");
    assertEquals(result.content.includes("read-only"), true);
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("gateway path: falls back to the stub on a non-OK model response", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const original = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(new Response("upstream error", { status: 503 }))) as typeof fetch;
  try {
    const result = await generateCopilotResponse({
      ...baseInput(),
      db: fakeGatewayDb(),
      gatewayContext: GATEWAY_CTX,
    });
    assertEquals(result.stub, true);
    assertEquals(result.model, "akshara-stub");
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("gateway path: no key configured → deterministic stub (W1.1b wiring)", async () => {
  clearAiKeyEnv();
  const result = await generateCopilotResponse({
    ...baseInput(),
    db: fakeGatewayDb(),
    gatewayContext: GATEWAY_CTX,
  });
  assertEquals(result.stub, true);
  assertEquals(result.model, "akshara-stub");
  clearAiKeyEnv();
});

Deno.test("gateway path: a cache hit is served with zero model calls (W1.2b)", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const original = globalThis.fetch;
  globalThis.fetch = (() => {
    throw new Error("the model must not be called on a cache hit");
  }) as unknown as typeof fetch;
  try {
    const result = await generateCopilotResponse({
      ...baseInput(),
      db: fakeGatewayDb({ payload: "cached: 3 fees due", model: "claude-opus-4-8" }),
      gatewayContext: GATEWAY_CTX,
    });
    assertEquals(result.stub, false);
    assertEquals(result.content, "cached: 3 fees due");
    assertEquals(result.model, "claude-opus-4-8");
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("gateway path: a paraphrase hits the same cache entry (W1.5 fingerprint)", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const db = statefulCacheDb();
  let fetchCalls = 0;
  const original = globalThis.fetch;
  globalThis.fetch = (() => {
    fetchCalls++;
    return Promise.resolve(
      new Response(
        JSON.stringify({
          content: [{ type: "text", text: "Aarav's fee is due 2026-07-15." }],
          model: "claude-opus-4-8",
          stop_reason: "end_turn",
          usage: { input_tokens: 10, output_tokens: 8 },
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
    );
  }) as unknown as typeof fetch;
  try {
    const first = await generateCopilotResponse({
      ...baseInput(),
      userMessage: "When is Aarav's fee due?",
      db,
      gatewayContext: GATEWAY_CTX,
    });
    const second = await generateCopilotResponse({
      ...baseInput(),
      userMessage: "fee due for Aarav??", // paraphrase → same fingerprint → same key
      db,
      gatewayContext: GATEWAY_CTX,
    });
    assertEquals(first.stub, false);
    assertEquals(second.content, first.content);
    assertEquals(fetchCalls, 1); // second served from cache, model called only once
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
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
      ...baseInput(),
      // The system prompt embeds the fact (as production buildSystemPrompt does),
      // so the ₹1000 in the reply is grounded and passes the F3 output guard.
      systemPrompt: "read-only policy. Collections this month: ₹1000.",
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

Deno.test("gateway path: an ungrounded number in the reply is guarded → stub (F3)", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const original = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          // ₹9,999 is nowhere in the (stub) system prompt → fabricated → guarded.
          content: [{ type: "text", text: "You owe ₹9,999 immediately." }],
          model: "claude-opus-4-8",
          stop_reason: "end_turn",
          usage: { input_tokens: 12, output_tokens: 9 },
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
    )) as typeof fetch;
  try {
    const result = await generateCopilotResponse({
      ...baseInput(),
      systemPrompt: "read-only policy. No dues on record.",
      db: fakeGatewayDb(),
      gatewayContext: GATEWAY_CTX,
    });
    // Fabricated ₹ amount discarded → deterministic stub served instead.
    assertEquals(result.stub, true);
    assertEquals(result.model, "akshara-stub");
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("capContext enforces the per-surface budget at a line boundary (F7)", () => {
  const small = "line1\nline2";
  assertEquals(capContext(small), small); // under budget → untouched
  const huge = Array.from({ length: 5000 }, (_, i) => `fact ${i}`).join("\n");
  const capped = capContext(huge);
  assert(capped.length <= MAX_CONTEXT_CHARS + 40); // budget + truncation marker
  assert(capped.endsWith("[context truncated to fit the budget]"));
  assert(!capped.slice(0, -40).endsWith("fact")); // truncated at a newline, not mid-fact
});

Deno.test("summarizeCopilotHistory condenses dropped turns deterministically (F5)", () => {
  assertEquals(summarizeCopilotHistory([]), "");
  const dropped = [
    { role: "user" as const, content: "What are the pending fees for class 6?" },
    { role: "assistant" as const, content: "Here is the breakdown." },
    { role: "user" as const, content: "And the attendance summary?" },
  ];
  const s = summarizeCopilotHistory(dropped);
  assert(s.startsWith("3 earlier message(s)"));
  assert(s.includes("fees"));
  assert(s.includes("attendance"));
  // Only keywords from USER turns are kept (assistant-turn word excluded).
  assertEquals(s.includes("breakdown"), false);
  assertEquals(summarizeCopilotHistory(dropped), s); // deterministic
});

Deno.test("gateway path: a long history yields a rolling summary to persist (F5)", async () => {
  clearAiKeyEnv(); // no key → stub path, but summary fields are still computed
  const history = Array.from({ length: MAX_HISTORY_TURNS + 5 }, (_, i) => ({
    role: (i % 2 === 0 ? "user" : "assistant") as "user" | "assistant",
    content: i % 2 === 0 ? `question ${i} about admissions` : `answer ${i}`,
  }));
  const result = await generateCopilotResponse({
    ...baseInput(),
    history,
    db: fakeGatewayDb(),
    gatewayContext: GATEWAY_CTX,
  });
  assertEquals(result.summarizedCount, 5); // history.length - MAX_HISTORY_TURNS
  assert((result.rollingSummary ?? "").startsWith("5 earlier message(s)"));
  clearAiKeyEnv();
});

Deno.test("gateway path: a short history has no rolling summary (F5)", async () => {
  clearAiKeyEnv();
  const result = await generateCopilotResponse({
    ...baseInput(),
    history: [{ role: "user", content: "hi" }],
    db: fakeGatewayDb(),
    gatewayContext: GATEWAY_CTX,
  });
  assertEquals(result.summarizedCount, undefined);
  assertEquals(result.rollingSummary, undefined);
  clearAiKeyEnv();
});
