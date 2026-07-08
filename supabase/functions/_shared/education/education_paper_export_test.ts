import { assertSnapshot } from "jsr:@std/testing/snapshot";
import { assertEquals } from "jsr:@std/assert@1";
import {
  buildPaperDocumentV2,
  DEFAULT_SET_LABELS,
  type PaperExportInput,
  paperV2InputFromStored,
} from "./education_paper_export.ts";
import type { QuestionPaperItemRow, QuestionPaperRow } from "./education_types.ts";

// CI-C3 — multi-set papers (A/B/C, per-set keys) + structured JSON export (v2).
//
// ADDITIVE + DORMANT. The certified v1 export (`paperExportDocument`) is covered
// by `education_export_moderation_test.ts` and left untouched. These tests pin
// the NEW v2 path ONLY. Everything is FULLY FIXED (no crypto.randomUUID /
// Math.random; `generatedAt` injected) and the builder is pure + seeded, so a
// fixed input → identical output. The golden lives in
// `__snapshots__/education_paper_export_test.ts.snap`.

const FIXED_AT = "2026-07-08T00:00:00.000Z";

// A GENERIC, board/exam-agnostic solved paper: two sections, a mix of MCQ (with
// options + a verbatim-option answer) and short-answer (no options).
const INPUT: PaperExportInput = {
  title: "Class 10 — Mathematics Unit Test (18 marks)",
  meta: {
    className: "10",
    subjectName: "Mathematics",
    examType: "unit_test",
    totalMarks: 18,
    difficulty: "mixed",
  },
  branding: { schoolName: "Akshara Vidyalaya", logoText: "AV" },
  generalInstructions: [
    "All questions are compulsory.",
    "Marks are indicated against each question.",
  ],
  durationMinutes: 60,
  sections: [
    {
      code: "A",
      title: "Objective",
      instructions: ["Choose the correct option."],
      items: [
        { id: "a1", questionType: "mcq", marks: 1, questionText: "2 + 2 = ?", answerText: "4", options: ["3", "4", "5", "6"] },
        { id: "a2", questionType: "mcq", marks: 1, questionText: "3 × 3 = ?", answerText: "9", options: ["6", "8", "9", "12"] },
        { id: "a3", questionType: "mcq", marks: 1, questionText: "10 / 2 = ?", answerText: "5", options: ["2", "4", "5", "10"] },
        { id: "a4", questionType: "mcq", marks: 1, questionText: "7 - 3 = ?", answerText: "4", options: ["3", "4", "5", "6"] },
      ],
    },
    {
      code: "B",
      title: "Short Answer",
      instructions: ["Attempt any question in 2-3 sentences."],
      items: [
        { id: "b1", questionType: "short_answer", marks: 5, questionText: "Prove the Pythagoras theorem.", answerText: "a^2 + b^2 = c^2 ...", options: [] },
        { id: "b2", questionType: "short_answer", marks: 5, questionText: "Solve x^2 - 5x + 6 = 0.", answerText: "x = 2 or x = 3", options: [] },
        { id: "b3", questionType: "short_answer", marks: 4, questionText: "Define a rational number.", answerText: "p/q, q != 0", options: [] },
      ],
    },
  ],
};

// ── Golden: the full multi-set document is byte-stable ───────────────────────
Deno.test("CI-C3 golden: buildPaperDocumentV2 (A/B/C) is byte-stable", async (t) => {
  const doc = buildPaperDocumentV2(INPUT, {
    sets: [...DEFAULT_SET_LABELS],
    seed: "paper-fixed-seed",
    generatedAt: FIXED_AT,
  });
  await assertSnapshot(t, doc);
});

// ── Determinism (invariant I1) ───────────────────────────────────────────────
Deno.test("CI-C3: multi-set build is deterministic (same input+seed → identical)", () => {
  const a = buildPaperDocumentV2(INPUT, { seed: "s", generatedAt: FIXED_AT });
  const b = buildPaperDocumentV2(INPUT, { seed: "s", generatedAt: FIXED_AT });
  assertEquals(JSON.stringify(a), JSON.stringify(b));
});

// ── Set A is the canonical master (identity order, options untouched) ─────────
Deno.test("CI-C3: the first set is the master — solved order, unscrambled options", () => {
  const doc = buildPaperDocumentV2(INPUT, { seed: "s", generatedAt: FIXED_AT });
  const setA = doc.sets[0]!;
  assertEquals(setA.master, true);
  // Section A questions are in the original solved order.
  assertEquals(
    setA.sections[0]!.questions.map((q) => q.sourceItemId),
    ["a1", "a2", "a3", "a4"],
  );
  // Master options are byte-identical to the input.
  assertEquals(setA.sections[0]!.questions[0]!.options, ["3", "4", "5", "6"]);
});

// ── Each set is a PERMUTATION of the same questions, within section bounds ─────
Deno.test("CI-C3: every set contains exactly the same questions, per section", () => {
  const doc = buildPaperDocumentV2(INPUT, { seed: "s", generatedAt: FIXED_AT });
  const masterA = INPUT.sections[0]!.items.map((i) => i.id).sort();
  const masterB = INPUT.sections[1]!.items.map((i) => i.id).sort();
  for (const set of doc.sets) {
    // No cross-section leakage: Section A keeps only Section-A items.
    assertEquals(set.sections[0]!.questions.map((q) => q.sourceItemId).sort(), masterA);
    assertEquals(set.sections[1]!.questions.map((q) => q.sourceItemId).sort(), masterB);
    // Continuous 1..N numbering across sections.
    const nums = set.sections.flatMap((s) => s.questions.map((q) => q.questionNumber));
    assertEquals(nums, [1, 2, 3, 4, 5, 6, 7]);
  }
});

// ── Non-master sets actually reorder (anti-copying value) ─────────────────────
Deno.test("CI-C3: non-master sets reorder questions vs the master", () => {
  const doc = buildPaperDocumentV2(INPUT, { seed: "s", generatedAt: FIXED_AT });
  const orderA = doc.sets[0]!.sections.flatMap((s) => s.questions.map((q) => q.sourceItemId));
  const orderB = doc.sets[1]!.sections.flatMap((s) => s.questions.map((q) => q.sourceItemId));
  const orderC = doc.sets[2]!.sections.flatMap((s) => s.questions.map((q) => q.sourceItemId));
  assertEquals(orderA === orderB, false);
  // At least one of B/C differs from A in printed order.
  const differs = JSON.stringify(orderA) !== JSON.stringify(orderB) ||
    JSON.stringify(orderA) !== JSON.stringify(orderC);
  assertEquals(differs, true);
});

// ── Per-set answer key correctness ───────────────────────────────────────────
Deno.test("CI-C3: each set's key aligns 1..N to THAT set's question order", () => {
  const doc = buildPaperDocumentV2(INPUT, { seed: "s", generatedAt: FIXED_AT });
  for (const set of doc.sets) {
    const questions = set.sections.flatMap((s) => s.questions);
    assertEquals(set.answerKey.length, questions.length);
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i]!;
      const key = set.answerKey[i]!;
      // Key entry i corresponds to printed question i (same number + section).
      assertEquals(key.questionNumber, q.questionNumber);
      assertEquals(key.sectionCode, q.sectionCode);
      assertEquals(key.marks, q.marks);
      // For an MCQ, the answer LETTER points at the correct option in THIS set.
      if (q.questionType === "mcq" && key.answerOption !== undefined) {
        const idx = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".indexOf(key.answerOption);
        assertEquals(q.options[idx], key.answer);
      }
    }
  }
});

// ── Option scramble stays answer-correct across sets ─────────────────────────
Deno.test("CI-C3: scrambled MCQ options never break the answer mapping", () => {
  const doc = buildPaperDocumentV2(INPUT, { seed: "s", generatedAt: FIXED_AT });
  for (const set of doc.sets) {
    for (const q of set.sections.flatMap((s) => s.questions)) {
      if (q.questionType !== "mcq") continue;
      // The answer text is always still present among the options.
      const key = set.answerKey.find((k) => k.questionNumber === q.questionNumber)!;
      assertEquals(q.options.includes(key.answer), true);
      // And the recorded letter resolves to that exact option.
      const idx = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".indexOf(key.answerOption!);
      assertEquals(q.options[idx], key.answer);
    }
  }
});

// ── KEY SEPARATION: questions carry no answers; the key is a separate array ────
Deno.test("CI-C3: key separation — printed questions never embed the answer", () => {
  const doc = buildPaperDocumentV2(INPUT, { seed: "s", generatedAt: FIXED_AT });
  for (const set of doc.sets) {
    for (const q of set.sections.flatMap((s) => s.questions)) {
      // The question object structurally has no answer field.
      assertEquals("answer" in q, false);
      assertEquals("answerText" in q, false);
    }
    // The key is a distinct, complete structure.
    const printed = set.sections.reduce((n, s) => n + s.questions.length, 0);
    assertEquals(set.answerKey.length, printed);
  }
});

// ── Marks total per set ──────────────────────────────────────────────────────
Deno.test("CI-C3: every set totals the same marks as the solved paper", () => {
  const doc = buildPaperDocumentV2(INPUT, { seed: "s", generatedAt: FIXED_AT });
  for (const set of doc.sets) {
    assertEquals(set.totalMarks, 18); // 4×1 + (5+5+4)
  }
});

// ── Single-set (dormant default) export ──────────────────────────────────────
Deno.test("CI-C3: a single-set export yields exactly the master paper", () => {
  const doc = buildPaperDocumentV2(INPUT, { sets: ["A"], seed: "s", generatedAt: FIXED_AT });
  assertEquals(doc.sets.length, 1);
  assertEquals(doc.sets[0]!.master, true);
  assertEquals(
    doc.sets[0]!.sections[0]!.questions.map((q) => q.sourceItemId),
    ["a1", "a2", "a3", "a4"],
  );
});

// ── Document structure carries branding + instructions + section metadata ─────
Deno.test("CI-C3: v2 document surfaces branding, instructions, and section meta", () => {
  const doc = buildPaperDocumentV2(INPUT, { seed: "s", generatedAt: FIXED_AT });
  assertEquals(doc.format, "akshara-education-paper-v2");
  assertEquals(doc.branding, { schoolName: "Akshara Vidyalaya", logoText: "AV" });
  assertEquals(doc.generalInstructions.length, 2);
  assertEquals(doc.durationMinutes, 60);
  assertEquals(doc.sections.map((s) => [s.code, s.questionCount]), [["A", 4], ["B", 3]]);
  assertEquals(doc.generatedAt, FIXED_AT);
});

// ── The stored-paper adapter enforces the AI-1 moderation gate ────────────────
function storedPaper(overrides: Partial<QuestionPaperRow> = {}): QuestionPaperRow {
  return {
    id: "paper-1",
    organization_id: "org",
    school_id: "school",
    academic_year_id: null,
    academic_year_label: "2026-27",
    class_name: "10",
    section_name: "A",
    subject_name: "Mathematics",
    chapters: [],
    difficulty: "mixed",
    total_marks: 10,
    exam_type: "unit_test",
    title: "Unit Test 1",
    status: "published",
    program_track: "board",
    review_status: "published",
    blueprint: { generalInstructions: ["Read carefully."], durationMinutes: 45 },
    answer_key: [],
    created_by: null,
    submitted_by: null,
    submitted_at: null,
    approved_by: null,
    approved_at: null,
    published_at: "now",
    created_at: "now",
    updated_at: "now",
    ...overrides,
  };
}

function storedItem(
  id: string,
  reviewStatus: string,
  text: string,
  answer: string,
): QuestionPaperItemRow {
  return {
    id,
    paper_id: "paper-1",
    organization_id: "org",
    school_id: "school",
    sort_order: 0,
    bank_item_id: null,
    question_type: "short_answer",
    marks: 5,
    question_text: text,
    answer_text: answer,
    options: [],
    source: reviewStatus === "approved" ? "bank" : "ai_candidate",
    review_status: reviewStatus,
  };
}

Deno.test("CI-C3: paperV2InputFromStored drops non-approved items (AI-1 gate)", () => {
  const items = [
    storedItem("q1", "approved", "Kept one", "A1"),
    storedItem("q2", "pending", "Unmoderated", "PENDING"),
    storedItem("q3", "rejected", "Disapproved", "BAD"),
    storedItem("q4", "approved", "Kept two", "A2"),
  ];
  const input = paperV2InputFromStored(storedPaper(), items);
  assertEquals(input.sections.length, 1);
  assertEquals(
    input.sections[0]!.items.map((i) => i.id),
    ["q1", "q4"],
  );
  // Instructions + duration flow through from the stored blueprint.
  assertEquals(input.generalInstructions, ["Read carefully."]);
  assertEquals(input.durationMinutes, 45);

  // And the built document only ever prints the approved questions.
  const doc = buildPaperDocumentV2(input, { sets: ["A", "B"], seed: "paper-1", generatedAt: FIXED_AT });
  for (const set of doc.sets) {
    const texts = set.sections.flatMap((s) => s.questions.map((q) => q.questionText));
    assertEquals(texts.sort(), ["Kept one", "Kept two"]);
    assertEquals(texts.includes("Unmoderated"), false);
    assertEquals(texts.includes("Disapproved"), false);
  }
});
