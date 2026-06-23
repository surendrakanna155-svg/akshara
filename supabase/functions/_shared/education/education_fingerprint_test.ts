import { assertEquals, assertNotEquals } from "jsr:@std/assert@1";
import { computeQuestionFingerprint } from "./education_fingerprint.ts";

Deno.test("fingerprint is stable for identical content", () => {
  const a = computeQuestionFingerprint({
    subjectName: "Mathematics",
    chapter: "Quadratic Equations",
    questionType: "mcq",
    questionText: "What is the sum of roots of x^2 - 5x + 6 = 0?",
  });
  const b = computeQuestionFingerprint({
    subjectName: "Mathematics",
    chapter: "Quadratic Equations",
    questionType: "mcq",
    questionText: "What is the sum of roots of x^2 - 5x + 6 = 0?",
  });
  assertEquals(a, b);
});

Deno.test("fingerprint normalizes whitespace, case and punctuation", () => {
  const a = computeQuestionFingerprint({
    subjectName: "Mathematics",
    chapter: "Algebra",
    questionType: "mcq",
    questionText: "Solve:  2x + 3 = 7.",
  });
  const b = computeQuestionFingerprint({
    subjectName: "mathematics",
    chapter: "ALGEBRA",
    questionType: "mcq",
    questionText: "solve 2x + 3 = 7",
  });
  assertEquals(a, b);
});

Deno.test("fingerprint differs for different questions", () => {
  const a = computeQuestionFingerprint({
    subjectName: "Mathematics",
    chapter: "Algebra",
    questionType: "mcq",
    questionText: "Solve 2x + 3 = 7",
  });
  const b = computeQuestionFingerprint({
    subjectName: "Mathematics",
    chapter: "Algebra",
    questionType: "mcq",
    questionText: "Solve 3x + 2 = 8",
  });
  assertNotEquals(a, b);
});
