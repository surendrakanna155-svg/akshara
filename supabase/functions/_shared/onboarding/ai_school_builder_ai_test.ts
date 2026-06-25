import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildSchoolBlueprint } from "./ai_school_builder_service.ts";
import { enrichSchoolBlueprintWithClaude } from "./ai_school_builder_ai.ts";

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

Deno.test("enrichment is a no-op without an api key", async () => {
  const baseline = buildSchoolBlueprint(brief);
  const result = await enrichSchoolBlueprintWithClaude(baseline, brief, undefined);
  assertEquals(result, baseline);
  assertEquals(result.source, "deterministic");
});

Deno.test("enrichment applies a valid refined proposal", async () => {
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
    const result = await enrichSchoolBlueprintWithClaude(baseline, brief, "sk-ant-test");
    assertEquals(result.source, "ai");
    assertEquals(result.proposal.classes!.length, 6);
    assertEquals(result.proposal.sections, ["A", "B", "C"]);
    assertEquals(result.proposal.feeModel, "quarterly");
    assertEquals(result.proposal.defaultLanguage, "en");
    assert(result.proposal.modulesEnabled!.includes("library"));
    assertEquals(result.rationale, "Tailored for a CBSE primary school.");
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("invalid fee model and non-grade classes fall back to baseline", async () => {
  const baseline = buildSchoolBlueprint(brief);
  const original = globalThis.fetch;
  stubFetch(JSON.stringify({
    classes: ["Quidditch", "Potions"],
    feeModel: "barter",
  }));
  try {
    const result = await enrichSchoolBlueprintWithClaude(baseline, brief, "sk-ant-test");
    assertEquals(result.proposal.classes, baseline.proposal.classes);
    assertEquals(result.proposal.feeModel, baseline.proposal.feeModel);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("junk (non-JSON) response falls back to baseline", async () => {
  const baseline = buildSchoolBlueprint(brief);
  const original = globalThis.fetch;
  stubFetch("I'm not going to answer in JSON, sorry.");
  try {
    const result = await enrichSchoolBlueprintWithClaude(baseline, brief, "sk-ant-test");
    assertEquals(result, baseline);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("refusal falls back to baseline", async () => {
  const baseline = buildSchoolBlueprint(brief);
  const original = globalThis.fetch;
  stubFetch("{}", "refusal");
  try {
    const result = await enrichSchoolBlueprintWithClaude(baseline, brief, "sk-ant-test");
    assertEquals(result, baseline);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("transport error falls back to baseline", async () => {
  const baseline = buildSchoolBlueprint(brief);
  const original = globalThis.fetch;
  globalThis.fetch = (() => Promise.reject(new Error("network down"))) as typeof fetch;
  try {
    const result = await enrichSchoolBlueprintWithClaude(baseline, brief, "sk-ant-test");
    assertEquals(result, baseline);
  } finally {
    globalThis.fetch = original;
  }
});
