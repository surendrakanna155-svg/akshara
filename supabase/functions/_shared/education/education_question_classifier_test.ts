// CI-C4-schema — tests for the Tier-1 rule-first classification assist
// (education_question_classifier.ts). Hand-authored fixtures only; no network,
// no DB, no AI. Confirms: deterministic output, the three named rule signals
// (cognitive_level / keyword / chapter+topic) each drive a suggestion, the
// "never certain" confidence contract, and that the function is a pure
// suggestion (it has no DB access at all — there is nothing to assert it
// "didn't write", the type signature itself proves it).

import { assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { suggestClassification } from "./education_question_classifier.ts";

Deno.test("CI-C4-schema: explicit cognitive_level is preferred over keyword inference", () => {
  const suggestion = suggestClassification({
    subjectName: "Science",
    chapter: "Photosynthesis",
    topic: "Light Reaction",
    questionText: "Compare and contrast the two stages.", // would infer 'analyze' if used
    cognitiveLevel: "remember",
  });
  assertEquals(suggestion.inferredCognitiveLevel, "remember");
  assertEquals(suggestion.confidence, "medium");
  assertEquals(suggestion.signals.includes("cognitive_level=remember"), true);
  assertEquals(suggestion.suggestedCompetency, "Recall and identify Light Reaction (Photosynthesis)");
  assertEquals(
    suggestion.suggestedLearningOutcome,
    "Student is able to recall Light Reaction within Photosynthesis (Science).",
  );
});

Deno.test("CI-C4-schema: keyword scan infers Bloom level when no cognitive_level is set", () => {
  const cases: Array<{ text: string; expected: string; keyword: string }> = [
    { text: "Define the term osmosis.", expected: "remember", keyword: "define" },
    { text: "Explain why plants need sunlight.", expected: "understand", keyword: "explain" },
    { text: "Calculate the area of the triangle.", expected: "apply", keyword: "calculate" },
    { text: "Compare the structures of plant and animal cells.", expected: "analyze", keyword: "compare" },
    { text: "Justify the design choice made by the engineer.", expected: "hots", keyword: "justify" },
  ];

  for (const c of cases) {
    const suggestion = suggestClassification({
      subjectName: "Science",
      chapter: "Cell Structure",
      questionText: c.text,
    });
    assertEquals(suggestion.inferredCognitiveLevel, c.expected, `text: "${c.text}"`);
    assertEquals(suggestion.confidence, "medium");
    assertEquals(suggestion.signals.some((s) => s === `keyword_match=${c.keyword}`), true);
  }
});

Deno.test("CI-C4-schema: higher-order keywords win over a co-occurring lower-order keyword", () => {
  // Contains both 'justify' (hots) and 'compare' (analyze) — hots must win
  // because the scan is ordered highest-Bloom-first.
  const suggestion = suggestClassification({
    subjectName: "Social Studies",
    chapter: "Federalism",
    questionText: "Compare the two systems and justify which is more effective.",
  });
  assertEquals(suggestion.inferredCognitiveLevel, "hots");
  assertEquals(suggestion.signals.some((s) => s === "keyword_match=justify"), true);
});

Deno.test("CI-C4-schema: no signal at all still returns a suggestion, pinned to low confidence", () => {
  const suggestion = suggestClassification({
    subjectName: "Mathematics",
    chapter: "Trigonometry",
    questionText: "A ladder leans against a wall.",
  });
  assertEquals(suggestion.inferredCognitiveLevel, "understand");
  assertEquals(suggestion.confidence, "low");
  assertEquals(suggestion.signals.includes("no_signal_default=understand"), true);
});

Deno.test("CI-C4-schema: inflected words do not false-positive the keyword scan (word-boundary match)", () => {
  // "identifying" contains "identify" as a substring but is not the whole word.
  const suggestion = suggestClassification({
    subjectName: "Biology",
    chapter: "Taxonomy",
    questionText: "We are identifying the parts of the flower in this diagram-based activity.",
  });
  // No exact-word Bloom keyword present → falls back to the no-signal default.
  assertEquals(suggestion.confidence, "low");
  assertEquals(suggestion.signals.includes("no_signal_default=understand"), true);
});

Deno.test("CI-C4-schema: topic (when present) is used over chapter in the phrase text", () => {
  const withTopic = suggestClassification({
    subjectName: "Mathematics",
    chapter: "Algebra",
    topic: "Quadratic Equations",
    questionText: "Solve for x.",
  });
  assertEquals(withTopic.suggestedCompetency.includes("Quadratic Equations"), true);
  assertEquals(withTopic.signals.includes("topic=Quadratic Equations"), true);

  const withoutTopic = suggestClassification({
    subjectName: "Mathematics",
    chapter: "Algebra",
    questionText: "Solve for x.",
  });
  assertEquals(withoutTopic.suggestedCompetency.includes("Algebra"), true);
  assertEquals(withoutTopic.signals.some((s) => s.startsWith("topic=")), false);
});

Deno.test("CI-C4-schema: pure function — identical input always yields identical output", () => {
  const input = {
    subjectName: "Physics",
    chapter: "Optics",
    topic: "Refraction",
    questionText: "Derive the lens formula.",
  };
  const first = suggestClassification(input);
  const second = suggestClassification(input);
  assertEquals(first, second);
});

Deno.test("CI-C4-schema: chapter/topic text is carried through verbatim, never invented", () => {
  const suggestion = suggestClassification({
    subjectName: "History",
    chapter: "The Mauryan Empire",
    topic: "Ashoka's Edicts",
    questionText: "Describe the significance of the edicts.",
  });
  assertEquals(suggestion.suggestedCompetency.includes("Ashoka's Edicts"), true);
  assertEquals(suggestion.suggestedCompetency.includes("The Mauryan Empire"), true);
  assertEquals(suggestion.suggestedLearningOutcome.includes("Ashoka's Edicts"), true);
  assertEquals(suggestion.suggestedLearningOutcome.includes("The Mauryan Empire"), true);
  assertEquals(suggestion.suggestedLearningOutcome.includes("History"), true);
});

Deno.test("CI-C4-schema: confidence is never anything but low/medium (never 'certain'/'high')", () => {
  const withLevel = suggestClassification({
    subjectName: "Science",
    chapter: "Motion",
    questionText: "irrelevant",
    cognitiveLevel: "apply",
  });
  const withoutSignal = suggestClassification({
    subjectName: "Science",
    chapter: "Motion",
    questionText: "irrelevant",
  });
  assertEquals(["low", "medium"].includes(withLevel.confidence), true);
  assertEquals(["low", "medium"].includes(withoutSignal.confidence), true);
  assertNotEquals(withLevel.confidence, withoutSignal.confidence);
});
