import { assertEquals } from "jsr:@std/assert@1";
import { generateAiCandidatesForGaps, type GapFillScope } from "./education_ai_question_gapfill.ts";
import type { BlueprintSlot } from "./education_blueprint_solver.ts";

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

Deno.test("gap-fill is a no-op without an api key", async () => {
  const result = await generateAiCandidatesForGaps(gaps, scope, undefined);
  assertEquals(result, []);
});

Deno.test("gap-fill validates and returns well-formed candidates", async () => {
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
    const result = await generateAiCandidatesForGaps(gaps, scope, "sk-ant-test");
    assertEquals(result.length, 2);
    assertEquals(result[0]!.slotIndex, 0);
    assertEquals(result[0]!.questionType, "mcq");
    assertEquals(result[0]!.marks, 4);
    assertEquals(result[1]!.questionType, "short_answer");
    assertEquals(result[1]!.options, []);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("gap-fill drops an mcq whose answer is not among the options", async () => {
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
    const result = await generateAiCandidatesForGaps(gaps, scope, "sk-ant-test");
    assertEquals(result.length, 0);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("gap-fill drops candidates with a mismatched type or unknown slot", async () => {
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
    const result = await generateAiCandidatesForGaps(gaps, scope, "sk-ant-test");
    assertEquals(result.length, 0);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("gap-fill returns empty on refusal", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = stubFetch("", "refusal");
  try {
    const result = await generateAiCandidatesForGaps(gaps, scope, "sk-ant-test");
    assertEquals(result, []);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("gap-fill returns empty when the model emits junk", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = stubFetch("no json here");
  try {
    const result = await generateAiCandidatesForGaps(gaps, scope, "sk-ant-test");
    assertEquals(result, []);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("gap-fill swallows transport errors and returns empty", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (() => Promise.reject(new Error("network down"))) as typeof fetch;
  try {
    const result = await generateAiCandidatesForGaps(gaps, scope, "sk-ant-test");
    assertEquals(result, []);
  } finally {
    globalThis.fetch = original;
  }
});
