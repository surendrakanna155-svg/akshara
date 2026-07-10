import { assertEquals } from "jsr:@std/assert@1";
import { generateAiCandidatesForGaps, type GapFillScope } from "./education_ai_question_gapfill.ts";
import type { BlueprintSlot } from "./education_blueprint_solver.ts";
import type { Governance } from "../ai/model_gateway.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

const scope: GapFillScope = {
  subjectName: "Mathematics",
  className: "Class 9",
  programTrack: "jee_foundation",
  examType: "monthly_test",
  chapters: ["Quadratic Equations"],
};

const gaps: BlueprintSlot[] = [
  { index: 0, questionType: "mcq", difficulty: "medium", marks: 4, chapter: "Quadratic Equations" },
  { index: 1, questionType: "short_answer", difficulty: "hard", marks: 6, chapter: "Quadratic Equations" },
];

function stubFetch(payloadText: string, stopReason = "end_turn"): typeof fetch {
  return (() =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          model: "claude-opus-4-8",
          stop_reason: stopReason,
          content: [{ type: "text", text: payloadText }],
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

Deno.test("gap-fill is a no-op without an api key", async () => {
  clearAiKeyEnv();
  const result = await generateAiCandidatesForGaps(gaps, scope, governance());
  assertEquals(result, []);
});

Deno.test("gap-fill validates and returns well-formed candidates", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const original = globalThis.fetch;
  globalThis.fetch = stubFetch(JSON.stringify({
    questions: [
      {
        slotIndex: 0,
        questionType: "mcq",
        marks: 4,
        difficulty: "medium",
        chapter: "Quadratic Equations",
        questionText: "Sum of roots of x^2 - 5x + 6 = 0?",
        answerText: "5",
        options: ["5", "6", "-5", "1"],
      },
      {
        slotIndex: 1,
        questionType: "short_answer",
        marks: 6,
        difficulty: "hard",
        chapter: "Quadratic Equations",
        questionText: "Derive the quadratic formula.",
        answerText: "x = (-b ± √(b²-4ac)) / 2a",
        options: [],
      },
    ],
  }));
  try {
    const result = await generateAiCandidatesForGaps(gaps, scope, governance());
    assertEquals(result.length, 2);
    assertEquals(result[0]!.slotIndex, 0);
    assertEquals(result[0]!.questionType, "mcq");
    assertEquals(result[0]!.marks, 4);
    assertEquals(result[1]!.questionType, "short_answer");
    assertEquals(result[1]!.options, []);
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("gap-fill drops an mcq whose answer is not among the options", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const original = globalThis.fetch;
  globalThis.fetch = stubFetch(JSON.stringify({
    questions: [{
      slotIndex: 0,
      questionType: "mcq",
      marks: 4,
      difficulty: "medium",
      chapter: "Quadratic Equations",
      questionText: "Sum of roots?",
      answerText: "999", // not in options
      options: ["5", "6", "-5", "1"],
    }],
  }));
  try {
    const result = await generateAiCandidatesForGaps(gaps, scope, governance());
    assertEquals(result.length, 0);
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("gap-fill drops candidates with a mismatched type or unknown slot", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const original = globalThis.fetch;
  globalThis.fetch = stubFetch(JSON.stringify({
    questions: [
      // wrong type for slot 0 (expected mcq)
      { slotIndex: 0, questionType: "long_answer", marks: 4, questionText: "x", answerText: "y", options: [] },
      // unknown slot index
      { slotIndex: 99, questionType: "mcq", marks: 4, questionText: "x", answerText: "A", options: ["A", "B"] },
    ],
  }));
  try {
    const result = await generateAiCandidatesForGaps(gaps, scope, governance());
    assertEquals(result.length, 0);
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("gap-fill returns empty on refusal", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const original = globalThis.fetch;
  globalThis.fetch = stubFetch("", "refusal");
  try {
    const result = await generateAiCandidatesForGaps(gaps, scope, governance());
    assertEquals(result, []);
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("gap-fill returns empty when the model emits junk", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const original = globalThis.fetch;
  globalThis.fetch = stubFetch("no json here");
  try {
    const result = await generateAiCandidatesForGaps(gaps, scope, governance());
    assertEquals(result, []);
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});

Deno.test("gap-fill swallows transport errors and returns empty", async () => {
  clearAiKeyEnv();
  Deno.env.set("ANTHROPIC_API_KEY", "sk-ant-test");
  const original = globalThis.fetch;
  globalThis.fetch = (() => Promise.reject(new Error("network down"))) as typeof fetch;
  try {
    const result = await generateAiCandidatesForGaps(gaps, scope, governance());
    assertEquals(result, []);
  } finally {
    globalThis.fetch = original;
    clearAiKeyEnv();
  }
});
