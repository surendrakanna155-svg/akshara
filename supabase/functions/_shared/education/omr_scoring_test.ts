// Smart OMR — pure scorer tests. No DB, no IO. Exhaustive over the scoring rules:
// all-correct, all-wrong, blanks (both policies), ambiguous multi-marks (all three
// policies), unscoreable questions, and every key/sheet mismatch guard.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { assertThrows } from "https://deno.land/std@0.224.0/assert/assert_throws.ts";
import {
  DEFAULT_OMR_POLICY,
  type OmrAnswerKeyEntry,
  OmrScoringError,
  scoreOmrSheet,
} from "./omr_scoring.ts";

const ITEM = (n: number) => `a5000000-0000-4000-8000-00000000000${n}`;

/** A clean 4-question MCQ key: correct options 1,2,3,4; 1 mark each. */
function key4(): OmrAnswerKeyEntry[] {
  return [
    { questionNo: 1, correctOption: 1, marks: 1, bankItemId: ITEM(1) },
    { questionNo: 2, correctOption: 2, marks: 1, bankItemId: ITEM(2) },
    { questionNo: 3, correctOption: 3, marks: 1, bankItemId: ITEM(3) },
    { questionNo: 4, correctOption: 4, marks: 1, bankItemId: ITEM(4) },
  ];
}

Deno.test("scoreOmrSheet: all-correct → full marks, every outcome 'correct'", () => {
  const res = scoreOmrSheet(
    [
      { questionNo: 1, marked: [1] },
      { questionNo: 2, marked: [2] },
      { questionNo: 3, marked: [3] },
      { questionNo: 4, marked: [4] },
    ],
    key4(),
  );
  assertEquals(res.totalScore, 4);
  assertEquals(res.maxScore, 4);
  assertEquals(res.correctCount, 4);
  assertEquals(res.incorrectCount, 0);
  assertEquals(res.blankCount, 0);
  assertEquals(res.answeredCount, 4);
  assertEquals(res.perQuestion.every((q) => q.outcome === "correct"), true);
  assertEquals(res.perQuestion.every((q) => q.isCorrect === true), true);
  // evidence fields carry through
  assertEquals(res.perQuestion[0]!.chosenOption, 1);
  assertEquals(res.perQuestion[0]!.bankItemId, ITEM(1));
});

Deno.test("scoreOmrSheet: all-wrong → zero marks, every outcome 'incorrect', isCorrect false", () => {
  const res = scoreOmrSheet(
    [
      { questionNo: 1, marked: [2] },
      { questionNo: 2, marked: [3] },
      { questionNo: 3, marked: [4] },
      { questionNo: 4, marked: [1] },
    ],
    key4(),
  );
  assertEquals(res.totalScore, 0);
  assertEquals(res.maxScore, 4);
  assertEquals(res.correctCount, 0);
  assertEquals(res.incorrectCount, 4);
  assertEquals(res.perQuestion.every((q) => q.outcome === "incorrect"), true);
  assertEquals(res.perQuestion.every((q) => q.isCorrect === false), true);
});

Deno.test("scoreOmrSheet: blanks default 'blank' → ungraded (isCorrect null), NOT wrong", () => {
  // Q1 correct, Q2 & Q3 blank (no marks entry at all / empty), Q4 wrong.
  const res = scoreOmrSheet(
    [
      { questionNo: 1, marked: [1] },
      { questionNo: 3, marked: [] },
      { questionNo: 4, marked: [1] },
    ],
    key4(),
  );
  assertEquals(res.totalScore, 1);
  assertEquals(res.maxScore, 4);
  assertEquals(res.correctCount, 1);
  assertEquals(res.incorrectCount, 1); // only Q4
  assertEquals(res.blankCount, 2); // Q2 (absent) + Q3 (empty)
  assertEquals(res.answeredCount, 2); // Q1 + Q4
  const q2 = res.perQuestion.find((q) => q.questionNo === 2)!;
  assertEquals(q2.outcome, "blank");
  assertEquals(q2.isCorrect, null); // honest: unanswered is NOT wrong
  assertEquals(q2.attempted, false);
  assertEquals(q2.chosenOption, null);
});

Deno.test("scoreOmrSheet: blank policy 'wrong' → blank state, but graded false / 0 marks", () => {
  const res = scoreOmrSheet(
    [{ questionNo: 1, marked: [1] }],
    key4(),
    { blank: "wrong", multiMark: "blank" },
  );
  assertEquals(res.correctCount, 1);
  assertEquals(res.blankCount, 3); // Q2..Q4 physically blank
  assertEquals(res.totalScore, 1); // blanks still award 0
  const q2 = res.perQuestion.find((q) => q.questionNo === 2)!;
  assertEquals(q2.outcome, "blank"); // physical state unchanged
  assertEquals(q2.isCorrect, false); // policy grades it wrong
  assertEquals(q2.awarded, 0);
});

Deno.test("scoreOmrSheet: multi-mark default 'blank' → ambiguous, ungraded, 0 marks", () => {
  const res = scoreOmrSheet(
    [
      { questionNo: 1, marked: [1, 2] }, // two bubbles → ambiguous
      { questionNo: 2, marked: [2] },
    ],
    key4(),
  );
  assertEquals(res.ambiguousCount, 1);
  assertEquals(res.correctCount, 1); // only Q2
  assertEquals(res.totalScore, 1);
  const q1 = res.perQuestion.find((q) => q.questionNo === 1)!;
  assertEquals(q1.outcome, "ambiguous");
  assertEquals(q1.isCorrect, null);
  assertEquals(q1.chosenOption, null); // never guessed
  assertEquals(q1.attempted, true); // they did fill bubbles
});

Deno.test("scoreOmrSheet: multi-mark policy 'wrong' → graded false, 0 marks", () => {
  const res = scoreOmrSheet(
    [{ questionNo: 1, marked: [1, 2] }],
    key4(),
    { blank: "blank", multiMark: "wrong" },
  );
  const q1 = res.perQuestion.find((q) => q.questionNo === 1)!;
  assertEquals(q1.outcome, "ambiguous");
  assertEquals(q1.isCorrect, false);
  assertEquals(q1.awarded, 0);
});

Deno.test("scoreOmrSheet: multi-mark policy 'reject' → whole sheet refused", () => {
  assertThrows(
    () =>
      scoreOmrSheet(
        [{ questionNo: 1, marked: [1, 2] }],
        key4(),
        { blank: "blank", multiMark: "reject" },
      ),
    OmrScoringError,
    "ambiguous",
  );
});

Deno.test("scoreOmrSheet: duplicate detected bubble is one mark, not an ambiguity", () => {
  // Scanner double-reported the same bubble; de-dupes to a single clean mark.
  const res = scoreOmrSheet([{ questionNo: 1, marked: [1, 1] }], key4());
  const q1 = res.perQuestion.find((q) => q.questionNo === 1)!;
  assertEquals(q1.outcome, "correct");
  assertEquals(q1.marked, [1]);
  assertEquals(res.ambiguousCount, 0);
});

Deno.test("scoreOmrSheet: unscoreable question (null key) → 'unscored', excluded from maxScore", () => {
  const key: OmrAnswerKeyEntry[] = [
    { questionNo: 1, correctOption: 1, marks: 2, bankItemId: ITEM(1) },
    { questionNo: 2, correctOption: null, marks: 5, bankItemId: ITEM(2) }, // e.g. a long-answer
  ];
  const res = scoreOmrSheet(
    [
      { questionNo: 1, marked: [1] },
      { questionNo: 2, marked: [3] },
    ],
    key,
  );
  assertEquals(res.totalScore, 2);
  assertEquals(res.maxScore, 2); // Q2's 5 marks excluded — cannot be keyed
  assertEquals(res.unscoredCount, 1);
  const q2 = res.perQuestion.find((q) => q.questionNo === 2)!;
  assertEquals(q2.outcome, "unscored");
  assertEquals(q2.isCorrect, null); // never assumed correct or wrong
  assertEquals(q2.maxMarks, 0);
  assertEquals(q2.chosenOption, 3); // still recorded for evidence
});

Deno.test("scoreOmrSheet: honors per-question marks weighting", () => {
  const key: OmrAnswerKeyEntry[] = [
    { questionNo: 1, correctOption: 1, marks: 4, bankItemId: ITEM(1) },
    { questionNo: 2, correctOption: 2, marks: 1, bankItemId: ITEM(2) },
  ];
  const res = scoreOmrSheet(
    [
      { questionNo: 1, marked: [1] }, // +4
      { questionNo: 2, marked: [3] }, // 0
    ],
    key,
  );
  assertEquals(res.totalScore, 4);
  assertEquals(res.maxScore, 5);
});

// ── Guards ───────────────────────────────────────────────────────────────────

Deno.test("guard: empty answer key is refused", () => {
  assertThrows(
    () => scoreOmrSheet([], []),
    OmrScoringError,
    "answer key is empty",
  );
});

Deno.test("guard: sheet marks a question absent from the key (key/sheet mismatch)", () => {
  assertThrows(
    () => scoreOmrSheet([{ questionNo: 99, marked: [1] }], key4()),
    OmrScoringError,
    "key/sheet mismatch",
  );
});

Deno.test("guard: duplicate questionNo on the sheet is refused", () => {
  assertThrows(
    () =>
      scoreOmrSheet(
        [
          { questionNo: 1, marked: [1] },
          { questionNo: 1, marked: [2] },
        ],
        key4(),
      ),
    OmrScoringError,
    "duplicate marked entry",
  );
});

Deno.test("guard: duplicate questionNo in the key is refused", () => {
  assertThrows(
    () =>
      scoreOmrSheet([{ questionNo: 1, marked: [1] }], [
        { questionNo: 1, correctOption: 1, marks: 1 },
        { questionNo: 1, correctOption: 2, marks: 1 },
      ]),
    OmrScoringError,
    "duplicate entry for question 1",
  );
});

Deno.test("guard: non-positive marked bubble is refused", () => {
  assertThrows(
    () => scoreOmrSheet([{ questionNo: 1, marked: [0] }], key4()),
    OmrScoringError,
    "positive integer",
  );
});

Deno.test("guard: non-positive marks in the key is refused", () => {
  assertThrows(
    () =>
      scoreOmrSheet([{ questionNo: 1, marked: [1] }], [
        { questionNo: 1, correctOption: 1, marks: 0 },
      ]),
    OmrScoringError,
    "non-positive marks",
  );
});

Deno.test("scoreOmrSheet: an all-blank sheet (default) scores 0 but grades nothing wrong", () => {
  const res = scoreOmrSheet([], key4()); // no marks at all
  assertEquals(res.totalScore, 0);
  assertEquals(res.maxScore, 4);
  assertEquals(res.blankCount, 4);
  assertEquals(res.incorrectCount, 0); // honest: absent ≠ wrong
  assertEquals(res.answeredCount, 0);
  assertEquals(res.perQuestion.every((q) => q.isCorrect === null), true);
  assertEquals(DEFAULT_OMR_POLICY.blank, "blank");
});
