import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildSchoolBlueprint } from "./ai_school_builder_service.ts";
import { enrichSchoolBlueprintWithClaude } from "./ai_school_builder_ai.ts";
import type { Governance } from "../ai/model_gateway.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

const brief = { schoolName: "Akshara Public School", board: "CBSE", lowestGrade: "Grade 1", highestGrade: "Grade 5" };

function stubFetch(text: string, stopReason = "end_turn") {
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          model: "claude-opus-4-8",
          stop_reason: stopReason,
          content: [{ type: "text", text }],
          usage: { input_tokens: 10, output_tokens: 5 },
        }),
        { status: 200 },
      ),
    )) as typeof fetch;
}

/** Fake tenant client for the gateway path (mirrors copilot_llm_client_test.ts):
 * no provider-config row (falls to env), zero usage counters, INSERTs accepted. */
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

function governance(): Governance {
  return { db: fakeGatewayDb(), organizationId: "org-1", schoolId: "school-1", userId: "user-1" };
}

function clearAiKeyEnv() {
  for (
    const k of [
      "AI_PROVIDER",
      "ANTHROPIC_API_KEY",
      "OPENROUTER_API_KEY",
      "AI_RATE_USER_PER_HOUR",
      "AI_RATE_SCHOOL_PER_DAY",
      "AI_MONTHLY_SPEND_CAP_MICROS",
    ]
  ) {
    Deno.env.delete(k);
  }
}

Deno.test("enrichment is a no-op without an api key", async () => {
  clearAiKeyEnv();
  const baseline = buildSchoolBlueprint(brief);
  const result = await enrichSchoolBlueprintWithClaude(baseline, brief, governance());
  assertEquals(result, baseline);
  assertEquals(result.source, "deterministic");
});

Deno.test("enrichment applies a valid refined proposal", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const baseline = buildSchoolBlueprint(brief);
  const original = globalThis.fetch;
  stubFetch(JSON.stringify({
    classes: ["Grade 1", "Grade 2", "Grade 3", "Grade 4", "Grade 5", "Grade 6"],
    sections: ["A", "B", "C"],
    feeModel: "quarterly",
    feeCategories: ["Tuition", "Lab", "Sports"],
    modulesEnabled: ["sis", "finance", "attendance", "library"],
    defaultLanguage: "EN",
    rationale: "Tailored for a CBSE primary school.",
  }));
  try {
    const result = await enrichSchoolBlueprintWithClaude(baseline, brief, governance());
    assertEquals(result.source, "ai");
    assertEquals(result.proposal.classes!.length, 6);
    assertEquals(result.proposal.sections, ["A", "B", "C"]);
    assertEquals(result.proposal.feeModel, "quarterly");
    assertEquals(result.proposal.defaultLanguage, "en");
    assert(result.proposal.modulesEnabled!.includes("library"));
    assertEquals(result.rationale, "Tailored for a CBSE primary school.");
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("invalid fee model and non-grade classes fall back to baseline", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const baseline = buildSchoolBlueprint(brief);
  const original = globalThis.fetch;
  stubFetch(JSON.stringify({
    classes: ["Quidditch", "Potions"],
    feeModel: "barter",
  }));
  try {
    const result = await enrichSchoolBlueprintWithClaude(baseline, brief, governance());
    assertEquals(result.proposal.classes, baseline.proposal.classes);
    assertEquals(result.proposal.feeModel, baseline.proposal.feeModel);
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("junk (non-JSON) response falls back to baseline", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const baseline = buildSchoolBlueprint(brief);
  const original = globalThis.fetch;
  stubFetch("I'm not going to answer in JSON, sorry.");
  try {
    const result = await enrichSchoolBlueprintWithClaude(baseline, brief, governance());
    assertEquals(result, baseline);
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("refusal falls back to baseline", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const baseline = buildSchoolBlueprint(brief);
  const original = globalThis.fetch;
  stubFetch("{}", "refusal");
  try {
    const result = await enrichSchoolBlueprintWithClaude(baseline, brief, governance());
    assertEquals(result, baseline);
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("transport error falls back to baseline", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const baseline = buildSchoolBlueprint(brief);
  const original = globalThis.fetch;
  globalThis.fetch = (() => Promise.reject(new Error("network down"))) as typeof fetch;
  try {
    const result = await enrichSchoolBlueprintWithClaude(baseline, brief, governance());
    assertEquals(result, baseline);
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});
