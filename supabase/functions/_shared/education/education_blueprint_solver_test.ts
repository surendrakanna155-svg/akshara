import { assertEquals } from "jsr:@std/assert@1";
import { planSlots, solveBlueprint } from "./education_blueprint_solver.ts";
import { computeQuestionFingerprint } from "./education_fingerprint.ts";
import type { QuestionBankItemRow } from "./education_types.ts";

function bankItem(overrides: Partial<QuestionBankItemRow>): QuestionBankItemRow {
  const base: QuestionBankItemRow = {
    id: crypto.randomUUID(),
    organization_id: "org",
    school_id: "school",
    subject_name: "Mathematics",
    chapter: "Algebra",
    topic: "",
    difficulty: "medium",
    question_type: "mcq",
    marks: 5,
    question_text: "Default question " + Math.random(),
    answer_text: "Answer",
    options: ["A", "B", "C", "D"],
    status: "active",
    source: "teacher",
    source_reference: null,
    program_track: "board",
    jee_question_type: null,
    cognitive_level: null,
    syllabus_chapter_id: null,
    syllabus_topic_id: null,
    learning_outcome: null,
    fingerprint: null,
    review_status: "approved",
    created_by: null,
    created_at: "now",
    updated_at: "now",
  };
  const merged = { ...base, ...overrides };
  merged.fingerprint = merged.fingerprint ?? computeQuestionFingerprint({
    subjectName: merged.subject_name,
    chapter: merged.chapter,
    questionType: merged.question_type,
    questionText: merged.question_text,
  });
  return merged;
}

Deno.test("plan slot marks always sum exactly to totalMarks", () => {
  for (const total of [20, 33, 50, 7, 100]) {
    const slots = planSlots({
      subjectName: "Mathematics",
      totalMarks: total,
      difficulty: "mixed",
      chapters: ["Algebra", "Geometry"],
    });
    const sum = slots.reduce((s, slot) => s + slot.marks, 0);
    assertEquals(sum, total, `total ${total}`);
  }
});

Deno.test("explicit question-type mix pins the slot count and types", () => {
  const slots = planSlots({
    subjectName: "Mathematics",
    totalMarks: 30,
    difficulty: "easy",
    chapters: ["Algebra"],
    questionTypeMix: { mcq: 4, short_answer: 2 },
  });
  assertEquals(slots.length, 6);
  assertEquals(slots.filter((s) => s.questionType === "mcq").length, 4);
  assertEquals(slots.filter((s) => s.questionType === "short_answer").length, 2);
});

Deno.test("solver is deterministic and bank-first", () => {
  const bank = [
    bankItem({ question_type: "mcq", marks: 5, difficulty: "easy", question_text: "Q1" }),
    bankItem({ question_type: "mcq", marks: 5, difficulty: "easy", question_text: "Q2" }),
  ];
  const spec = {
    subjectName: "Mathematics",
    totalMarks: 10,
    difficulty: "easy" as const,
    chapters: ["Algebra"],
    questionTypeMix: { mcq: 2 },
  };
  const a = solveBlueprint(spec, bank);
  const b = solveBlueprint(spec, bank);
  assertEquals(a.selected.length, 2);
  assertEquals(a.gaps.length, 0);
  // Same inputs → same selected ids in the same order.
  assertEquals(a.selected.map((s) => s.bankItem.id), b.selected.map((s) => s.bankItem.id));
});

Deno.test("solver reports gaps the bank cannot fill", () => {
  const bank = [
    bankItem({ question_type: "mcq", marks: 5, difficulty: "easy", question_text: "Only one" }),
  ];
  const solution = solveBlueprint(
    {
      subjectName: "Mathematics",
      totalMarks: 15,
      difficulty: "easy",
      chapters: ["Algebra"],
      questionTypeMix: { mcq: 3 },
    },
    bank,
  );
  assertEquals(solution.selected.length, 1);
  assertEquals(solution.gaps.length, 2);
  // Gaps carry exact marks/type for the AI step.
  assertEquals(solution.gaps[0]!.questionType, "mcq");
  assertEquals(solution.gaps[0]!.marks, 5);
});

Deno.test("solver never selects pending or archived bank items", () => {
  const bank = [
    bankItem({ question_type: "mcq", marks: 5, review_status: "pending", question_text: "Pending" }),
    bankItem({ question_type: "mcq", marks: 5, status: "archived", question_text: "Archived" }),
  ];
  const solution = solveBlueprint(
    {
      subjectName: "Mathematics",
      totalMarks: 5,
      difficulty: "easy",
      chapters: ["Algebra"],
      questionTypeMix: { mcq: 1 },
    },
    bank,
  );
  assertEquals(solution.selected.length, 0);
  assertEquals(solution.gaps.length, 1);
});

Deno.test("solver dedups identical questions by fingerprint", () => {
  const shared = computeQuestionFingerprint({
    subjectName: "Mathematics",
    chapter: "Algebra",
    questionType: "mcq",
    questionText: "Duplicate question",
  });
  const bank = [
    bankItem({ question_type: "mcq", marks: 5, difficulty: "easy", fingerprint: shared, question_text: "Duplicate question" }),
    bankItem({ question_type: "mcq", marks: 5, difficulty: "easy", fingerprint: shared, question_text: "Duplicate question" }),
  ];
  const solution = solveBlueprint(
    {
      subjectName: "Mathematics",
      totalMarks: 10,
      difficulty: "easy",
      chapters: ["Algebra"],
      questionTypeMix: { mcq: 2 },
    },
    bank,
  );
  // Second copy is skipped — only one placed, the other slot is a gap.
  assertEquals(solution.selected.length, 1);
  assertEquals(solution.gaps.length, 1);
});
