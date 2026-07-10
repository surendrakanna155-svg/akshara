import { assert, assertEquals } from "jsr:@std/assert@1";
import type { ClaudeCallResult } from "./anthropic_client.ts";
import type { AiRuntimeConfig } from "./ai_settings.ts";
import type { AiCallLogEntry } from "./ai_call_log_repository.ts";
import {
  callModelGateway as _callModelGateway,
  decideGateway,
  DEFAULT_LIMITS,
  estimateCostMicros,
  type GatewayContext,
  type GatewayDeps,
  type GatewayUsage,
  resolveLimits,
  runGateway,
} from "./model_gateway.ts";

// keep the production export referenced (compile guard)
const _ref = _callModelGateway;

const CTX: GatewayContext = {
  organizationId: "org-1",
  schoolId: "sch-1",
  userId: "u-1",
  surface: "copilot",
};

const OK_RESULT: ClaudeCallResult = {
  text: "real answer",
  model: "claude-opus-4-8",
  refused: false,
  usage: { inputTokens: 100, outputTokens: 50 },
};

function clearLimitEnv() {
  for (
    const k of [
      "AI_RATE_USER_PER_HOUR",
      "AI_RATE_SCHOOL_PER_DAY",
      "AI_MONTHLY_SPEND_CAP_MICROS",
    ]
  ) Deno.env.delete(k);
}

function makeDeps(o: {
  apiKey?: string | null;
  rawConfig?: Record<string, unknown> | null;
  usage?: Partial<GatewayUsage>;
  callModel?: (input: { signal?: AbortSignal }) => Promise<ClaudeCallResult>;
  timeoutMs?: number;
  cacheHit?: { payload: string; model: string } | null;
  withCache?: boolean;
} = {}): {
  deps: GatewayDeps;
  records: AiCallLogEntry[];
  modelCalls: () => number;
  cacheWrites: Array<{ payload: string; model: string }>;
} {
  const records: AiCallLogEntry[] = [];
  const cacheWrites: Array<{ payload: string; model: string }> = [];
  let calls = 0;
  const apiKey = "apiKey" in o ? o.apiKey ?? undefined : "sk-test";
  const cfg: AiRuntimeConfig = {
    provider: "anthropic",
    model: "claude-opus-4-8",
    apiKey,
    source: "panel",
    rawConfig: o.rawConfig ?? null,
  };
  const inner = o.callModel ?? (() => Promise.resolve(OK_RESULT));
  const deps: GatewayDeps = {
    resolveConfig: () => Promise.resolve(cfg),
    readUsage: () =>
      Promise.resolve({
        userCallsLastHour: 0,
        schoolCallsToday: 0,
        monthSpendMicros: 0,
        ...(o.usage ?? {}),
      }),
    record: (e) => {
      records.push(e);
      return Promise.resolve();
    },
    // deno-lint-ignore no-explicit-any
    callModel: ((input: any) => {
      calls++;
      return inner(input);
    }) as GatewayDeps["callModel"],
    now: () => new Date(1_700_000_000_000),
    timeoutMs: o.timeoutMs ?? 20_000,
  };
  if (o.withCache || o.cacheHit !== undefined) {
    deps.cache = {
      lookup: () => Promise.resolve(o.cacheHit ?? null),
      write: (_scope, _surface, payload, model) => {
        cacheWrites.push({ payload, model });
        return Promise.resolve();
      },
    };
  }
  return { deps, records, modelCalls: () => calls, cacheWrites };
}

// ─── estimateCostMicros ──────────────────────────────────────────────────────

Deno.test("estimateCostMicros prices opus/sonnet/haiku and handles null usage", () => {
  assertEquals(estimateCostMicros("claude-opus-4-8", { inputTokens: 100, outputTokens: 50 }), 100 * 15 + 50 * 75);
  assertEquals(estimateCostMicros("anthropic/claude-sonnet-4-6", { inputTokens: 100, outputTokens: 50 }), 100 * 3 + 50 * 15);
  assertEquals(estimateCostMicros("claude-haiku-4-5", { inputTokens: 100, outputTokens: 50 }), 100 * 1 + 50 * 5);
  assertEquals(estimateCostMicros("some-unknown-model", { inputTokens: 10, outputTokens: 10 }), 10 * 3 + 10 * 15);
  assertEquals(estimateCostMicros("claude-opus-4-8", null), 0);
});

// ─── resolveLimits ───────────────────────────────────────────────────────────

Deno.test("resolveLimits: defaults when no config or env", () => {
  clearLimitEnv();
  assertEquals(resolveLimits(null), DEFAULT_LIMITS);
  clearLimitEnv();
});

Deno.test("resolveLimits: config overrides env overrides default", () => {
  clearLimitEnv();
  Deno.env.set("AI_RATE_USER_PER_HOUR", "7");
  // env sets user rate; config overrides school + cap
  const limits = resolveLimits({ ai_rate_school_per_day: 42, ai_monthly_spend_cap_micros: 5_000_000 });
  assertEquals(limits.userCallsPerHour, 7); // from env
  assertEquals(limits.schoolCallsPerDay, 42); // from config
  assertEquals(limits.monthlySpendCapMicros, 5_000_000); // from config
  clearLimitEnv();
});

// ─── decideGateway (pure) ────────────────────────────────────────────────────

const ZERO: GatewayUsage = { userCallsLastHour: 0, schoolCallsToday: 0, monthSpendMicros: 0 };

Deno.test("decideGateway: allows a fresh call with a key", () => {
  assertEquals(decideGateway(true, DEFAULT_LIMITS, ZERO), { allow: true });
});

Deno.test("decideGateway: denies with no key", () => {
  assertEquals(decideGateway(false, DEFAULT_LIMITS, ZERO), { allow: false, reason: "no_key" });
});

Deno.test("decideGateway: per-user then per-school then spend-cap ordering", () => {
  const limits = { userCallsPerHour: 5, schoolCallsPerDay: 10, monthlySpendCapMicros: 1000 };
  assertEquals(
    decideGateway(true, limits, { ...ZERO, userCallsLastHour: 5 }),
    { allow: false, reason: "rate_user" },
  );
  assertEquals(
    decideGateway(true, limits, { ...ZERO, schoolCallsToday: 10 }),
    { allow: false, reason: "rate_school" },
  );
  assertEquals(
    decideGateway(true, limits, { ...ZERO, monthSpendMicros: 1000 }),
    { allow: false, reason: "spend_cap" },
  );
});

Deno.test("decideGateway: a 0 limit disables that gate", () => {
  const limits = { userCallsPerHour: 0, schoolCallsPerDay: 0, monthlySpendCapMicros: 0 };
  assertEquals(
    decideGateway(true, limits, { userCallsLastHour: 9999, schoolCallsToday: 9999, monthSpendMicros: 9e9 }),
    { allow: true },
  );
});

// ─── runGateway (IO wrapper, injected deps) ──────────────────────────────────

Deno.test("runGateway: no key → deterministic fallback, logs fallback_no_key, no model call", async () => {
  clearLimitEnv();
  const { deps, records, modelCalls } = makeDeps({ apiKey: null });
  const r = await runGateway(CTX, { system: "s", messages: [] }, "FALLBACK", deps);
  assertEquals(r.text, "FALLBACK");
  assertEquals(r.ok, false);
  assert(r.fallbackUsed);
  assertEquals(r.outcome, "fallback_no_key");
  assertEquals(modelCalls(), 0);
  assertEquals(records.length, 1);
  assertEquals(records[0].outcome, "fallback_no_key");
  assert(records[0].fallbackUsed);
});

Deno.test("runGateway: over per-user rate → fallback_rate_user, no model call", async () => {
  clearLimitEnv();
  const { deps, records, modelCalls } = makeDeps({ usage: { userCallsLastHour: 30 } });
  const r = await runGateway(CTX, { system: "s", messages: [] }, "FB", deps);
  assertEquals(r.outcome, "fallback_rate_user");
  assertEquals(r.text, "FB");
  assertEquals(modelCalls(), 0);
  assertEquals(records[0].outcome, "fallback_rate_user");
  clearLimitEnv();
});

Deno.test("runGateway: over per-school rate → fallback_rate_school", async () => {
  clearLimitEnv();
  const { deps, records } = makeDeps({ usage: { schoolCallsToday: 500 } });
  const r = await runGateway(CTX, { system: "s", messages: [] }, "FB", deps);
  assertEquals(r.outcome, "fallback_rate_school");
  assertEquals(records[0].outcome, "fallback_rate_school");
  clearLimitEnv();
});

Deno.test("runGateway: over spend cap (from config) → fallback_spend_cap", async () => {
  clearLimitEnv();
  const { deps, records, modelCalls } = makeDeps({
    rawConfig: { ai_monthly_spend_cap_micros: 1_000_000 },
    usage: { monthSpendMicros: 1_000_000 },
  });
  const r = await runGateway(CTX, { system: "s", messages: [] }, "FB", deps);
  assertEquals(r.outcome, "fallback_spend_cap");
  assertEquals(modelCalls(), 0);
  assertEquals(records[0].outcome, "fallback_spend_cap");
  clearLimitEnv();
});

Deno.test("runGateway: success → real text, logs ok with tokens + estimated cost", async () => {
  clearLimitEnv();
  const { deps, records, modelCalls } = makeDeps({});
  const r = await runGateway(CTX, { system: "s", messages: [] }, "FB", deps);
  assertEquals(r.text, "real answer");
  assertEquals(r.ok, true);
  assertEquals(r.fallbackUsed, false);
  assertEquals(r.outcome, "ok");
  assertEquals(modelCalls(), 1);
  assertEquals(records.length, 1);
  assertEquals(records[0].outcome, "ok");
  assertEquals(records[0].inputTokens, 100);
  assertEquals(records[0].outputTokens, 50);
  assertEquals(records[0].estimatedCostMicros, 100 * 15 + 50 * 75);
  assertEquals(records[0].fallbackUsed, false);
  clearLimitEnv();
});

Deno.test("runGateway: model refusal → fallback text, logs refused with real usage", async () => {
  clearLimitEnv();
  const refusal: ClaudeCallResult = { text: "", model: "claude-opus-4-8", refused: true, usage: { inputTokens: 20, outputTokens: 0 } };
  const { deps, records } = makeDeps({ callModel: () => Promise.resolve(refusal) });
  const r = await runGateway(CTX, { system: "s", messages: [] }, "FB", deps);
  assertEquals(r.refused, true);
  assertEquals(r.text, "FB");
  assert(r.fallbackUsed);
  assertEquals(records[0].outcome, "refused");
  assertEquals(records[0].inputTokens, 20);
  clearLimitEnv();
});

Deno.test("runGateway: timeout → fallback_timeout", async () => {
  clearLimitEnv();
  const hanging = (input: { signal?: AbortSignal }) =>
    new Promise<ClaudeCallResult>((_, reject) => {
      input.signal?.addEventListener("abort", () => {
        const e = new Error("aborted");
        e.name = "AbortError";
        reject(e);
      });
    });
  const { deps, records } = makeDeps({ callModel: hanging, timeoutMs: 5 });
  const r = await runGateway(CTX, { system: "s", messages: [] }, "FB", deps);
  assertEquals(r.outcome, "fallback_timeout");
  assertEquals(r.text, "FB");
  assert(r.fallbackUsed);
  assertEquals(records[0].outcome, "fallback_timeout");
  clearLimitEnv();
});

Deno.test("runGateway: model error → fallback_error", async () => {
  clearLimitEnv();
  const { deps, records } = makeDeps({ callModel: () => Promise.reject(new Error("boom")) });
  const r = await runGateway(CTX, { system: "s", messages: [] }, "FB", deps);
  assertEquals(r.outcome, "fallback_error");
  assertEquals(r.text, "FB");
  assertEquals(records[0].outcome, "fallback_error");
  clearLimitEnv();
});

Deno.test("runGateway: result carries the resolved model on success and denial", async () => {
  clearLimitEnv();
  const ok = await runGateway(CTX, { system: "s", messages: [] }, "FB", makeDeps({}).deps);
  assertEquals(ok.model, "claude-opus-4-8");
  const noKey = await runGateway(CTX, { system: "s", messages: [] }, "FB", makeDeps({ apiKey: null }).deps);
  assertEquals(noKey.model, "claude-opus-4-8"); // configured model even when the key is absent
  clearLimitEnv();
});

Deno.test("runGateway: cache hit → served free (fromCache), no model call, no log", async () => {
  clearLimitEnv();
  const { deps, records, modelCalls } = makeDeps({
    cacheHit: { payload: "cached answer", model: "claude-opus-4-8" },
  });
  const r = await runGateway(CTX, { system: "s", messages: [] }, "FB", deps);
  assertEquals(r.fromCache, true);
  assertEquals(r.ok, true);
  assertEquals(r.text, "cached answer");
  assertEquals(modelCalls(), 0);
  assertEquals(records.length, 0); // no ai_call_log row for a cache hit
  clearLimitEnv();
});

Deno.test("runGateway: cache miss → model called + write-through of the answer", async () => {
  clearLimitEnv();
  const { deps, records, modelCalls, cacheWrites } = makeDeps({ cacheHit: null });
  const r = await runGateway(CTX, { system: "s", messages: [] }, "FB", deps);
  assertEquals(r.fromCache, false);
  assertEquals(r.ok, true);
  assertEquals(r.text, "real answer");
  assertEquals(modelCalls(), 1);
  assertEquals(records[0].outcome, "ok");
  assertEquals(cacheWrites.length, 1);
  assertEquals(cacheWrites[0].payload, "real answer");
  clearLimitEnv();
});

Deno.test("runGateway: telemetry failure never breaks the user path", async () => {
  clearLimitEnv();
  const { deps } = makeDeps({});
  deps.record = () => Promise.reject(new Error("log db down"));
  const r = await runGateway(CTX, { system: "s", messages: [] }, "FB", deps);
  assertEquals(r.ok, true);
  assertEquals(r.text, "real answer");
  clearLimitEnv();
});
