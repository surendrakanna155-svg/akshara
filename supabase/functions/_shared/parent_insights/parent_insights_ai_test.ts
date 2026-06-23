import { assertEquals } from "jsr:@std/assert@1";
import { enrichParentInsightWithClaude } from "./parent_insights_ai.ts";
import type { ParentInsightSnapshot } from "./parent_insights_service.ts";

const baseSnapshot: ParentInsightSnapshot = {
  period: "weekly",
  language: "telugu",
  progressSummary: "weekly summary for your child: marks 70%, attendance 85%, homework 80%.",
  strengths: ["Consistent class participation"],
  weaknesses: ["Time management during assessments"],
  attendanceInsights: ["Attendance is 85% — on track"],
  homeworkInsights: ["Homework completion is 80% — good consistency"],
  improvementSuggestions: ["Allocate 30 minutes daily for revision"],
  teacherRemarksSummary: "Teachers note steady effort.",
  voiceReady: true,
  printable: true,
};

Deno.test("parent insight enrichment is a no-op without an api key", async () => {
  const result = await enrichParentInsightWithClaude(baseSnapshot, undefined);
  assertEquals(result, baseSnapshot);
});

Deno.test("parent insight enrichment rewrites prose, preserving structure", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          model: "claude-opus-4-8",
          stop_reason: "end_turn",
          content: [{
            type: "text",
            text: JSON.stringify({
              progressSummary: "మీ పిల్లల వారపు సారాంశం: మార్కులు 70%.",
              strengths: ["తరగతిలో చురుకుగా పాల్గొంటారు"],
              weaknesses: ["పరీక్షల్లో సమయ నిర్వహణ"],
              attendanceInsights: ["హాజరు 85% — బాగుంది"],
              homeworkInsights: ["హోంవర్క్ 80%"],
              improvementSuggestions: ["రోజూ 30 నిమిషాలు చదవండి"],
              teacherRemarksSummary: "ఉపాధ్యాయులు స్థిరమైన కృషిని గమనించారు.",
            }),
          }],
        }),
        { status: 200 },
      ),
    )) as typeof fetch;
  try {
    const result = await enrichParentInsightWithClaude(baseSnapshot, "sk-ant-test");
    assertEquals(result.progressSummary, "మీ పిల్లల వారపు సారాంశం: మార్కులు 70%.");
    assertEquals(result.strengths[0], "తరగతిలో చురుకుగా పాల్గొంటారు");
    // Structural fields untouched.
    assertEquals(result.period, "weekly");
    assertEquals(result.language, "telugu");
    assertEquals(result.voiceReady, true);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("parent insight enrichment falls back when the model returns junk", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          model: "claude-opus-4-8",
          stop_reason: "end_turn",
          content: [{ type: "text", text: "sorry, no JSON here" }],
        }),
        { status: 200 },
      ),
    )) as typeof fetch;
  try {
    const result = await enrichParentInsightWithClaude(baseSnapshot, "sk-ant-test");
    assertEquals(result, baseSnapshot);
  } finally {
    globalThis.fetch = original;
  }
});

Deno.test("parent insight enrichment falls back on refusal", async () => {
  const original = globalThis.fetch;
  globalThis.fetch = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify({ model: "claude-opus-4-8", stop_reason: "refusal", content: [] }),
        { status: 200 },
      ),
    )) as typeof fetch;
  try {
    const result = await enrichParentInsightWithClaude(baseSnapshot, "sk-ant-test");
    assertEquals(result, baseSnapshot);
  } finally {
    globalThis.fetch = original;
  }
});
