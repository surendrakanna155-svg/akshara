import { assertEquals } from "jsr:@std/assert@1";
import {
  type BlueprintTemplate,
  solveBlueprint,
  type SolverSpec,
} from "./education_blueprint_solver.ts";
import { explainSelection } from "./education_selection_reason.ts";
import type { QuestionBankItemRow } from "./education_types.ts";

// CI-C8 — selection-reason (explainability). The explanation is derived by
// REPLAYING the real solver, so each test solves with the CERTIFIED solver first
// and then asserts the reasons match — which also cross-checks that the mirrored
// predicates track the solver's actual picks. Fully-fixed fixtures.

function item(o: Partial<QuestionBankItemRow>): QuestionBankItemRow {
  return {
    id: "item",
    organization_id: "org",
    school_id: "school",
    subject_name: "Mathematics",
    chapter: "Algebra",
    topic: "",
    difficulty: "medium",
    question_type: "mcq",
    marks: 5,
    question_text: "Q",
    answer_text: "A",
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
    created_at: "t",
    updated_at: "t",
    ...o,
  };
}

// ── Legacy path ──────────────────────────────────────────────────────────────

Deno.test("CI-C8 reason: chapter-preferred pick, fallback pick, dedup skip, and a gap are all explained", () => {
  // The certified golden scenario (education_blueprint_solver_golden_test.ts).
  const spec: SolverSpec = {
    subjectName: "Mathematics",
    totalMarks: 15,
    difficulty: "medium",
    chapters: ["Algebra"],
    questionTypeMix: { mcq: 2, short_answer: 1 },
  };
  const bank = [
    item({ id: "a", chapter: "Algebra", marks: 5, fingerprint: "fp-mcq-1", question_text: "A" }),
    item({ id: "b", chapter: "Algebra", marks: 5, fingerprint: "fp-mcq-1", question_text: "B" }), // dup of a
    item({ id: "c", chapter: "Geometry", marks: 5, fingerprint: "fp-mcq-2", question_text: "C" }),
  ];
  const solution = solveBlueprint(spec, bank);
  // Sanity: cross-check the explanation against what the solver actually did.
  assertEquals(solution.selected.map((s) => s.bankItem.id), ["a", "c"]);

  const explained = explainSelection(spec, bank, solution);
  assertEquals(explained.mode, "legacy");
  // The explained selections mirror the solution 1:1.
  assertEquals(explained.selected.map((s) => s.bankItemId), ["a", "c"]);

  const [s0, s1] = explained.selected;
  // slot 0: a matches its chapter (Algebra) → chapter_preferred. At pick time b + c
  // were also eligible (b not yet deduped) → 2 alternatives, 0 dedup-skips.
  assertEquals(s0!.slotIndex, 0);
  assertEquals(s0!.selectionRule, "chapter_preferred");
  assertEquals(s0!.alternativesConsidered, 2);
  assertEquals(s0!.duplicatesSkipped, 0);
  assertEquals(s0!.satisfied, ["question_type=mcq", "marks=5", "difficulty=medium"]);
  // slot 1: c is Geometry ≠ slot chapter (Algebra) → first-eligible fallback. b now
  // shares a's used fingerprint → skipped as a duplicate; no other alternatives.
  assertEquals(s1!.slotIndex, 1);
  assertEquals(s1!.selectionRule, "first_eligible_fallback");
  assertEquals(s1!.alternativesConsidered, 0);
  assertEquals(s1!.duplicatesSkipped, 1);

  // slot 2 (short_answer) is a gap — no approved short_answer item exists at all.
  assertEquals(explained.gaps.length, 1);
  assertEquals(explained.gaps[0]!.slotIndex, 2);
  assertEquals(explained.gaps[0]!.code, "no_type_match");
  // Gap slot indexes agree with the solver's own gap list.
  assertEquals(explained.gaps.map((g) => g.slotIndex), solution.gaps.map((g) => g.index));
});

Deno.test("CI-C8 reason: gap code 'no_marks_match' — right type, wrong marks", () => {
  const spec: SolverSpec = {
    subjectName: "Mathematics",
    totalMarks: 5,
    difficulty: "medium",
    chapters: ["Algebra"],
    questionTypeMix: { mcq: 1 },
  };
  const bank = [item({ id: "m3", question_type: "mcq", marks: 3 })]; // slot needs 5 marks
  const solution = solveBlueprint(spec, bank);
  const explained = explainSelection(spec, bank, solution);
  assertEquals(explained.selected, []);
  assertEquals(explained.gaps[0]!.code, "no_marks_match");
  assertEquals(explained.gaps[0]!.detail.typeMatchCount, 1);
});

Deno.test("CI-C8 reason: gap code 'no_difficulty_match' — right type+marks, wrong difficulty", () => {
  const spec: SolverSpec = {
    subjectName: "Mathematics",
    totalMarks: 5,
    difficulty: "medium", // concrete → difficulty is a hard constraint
    chapters: ["Algebra"],
    questionTypeMix: { mcq: 1 },
  };
  const bank = [item({ id: "hard", question_type: "mcq", marks: 5, difficulty: "hard" })];
  const solution = solveBlueprint(spec, bank);
  const explained = explainSelection(spec, bank, solution);
  assertEquals(explained.gaps[0]!.code, "no_difficulty_match");
  assertEquals(explained.gaps[0]!.detail.marksMatchCount, 1);
});

Deno.test("CI-C8 reason: gap code 'all_exhausted' — matches existed but earlier slots used them", () => {
  const spec: SolverSpec = {
    subjectName: "Mathematics",
    totalMarks: 10,
    difficulty: "medium",
    chapters: ["Algebra"],
    questionTypeMix: { mcq: 2 }, // two mcq/5 slots
  };
  const bank = [item({ id: "only", question_type: "mcq", marks: 5, fingerprint: "fp-only" })];
  const solution = solveBlueprint(spec, bank);
  const explained = explainSelection(spec, bank, solution);
  assertEquals(explained.selected.map((s) => s.bankItemId), ["only"]);
  assertEquals(explained.gaps.length, 1);
  assertEquals(explained.gaps[0]!.slotIndex, 1);
  assertEquals(explained.gaps[0]!.code, "all_exhausted");
  assertEquals(explained.gaps[0]!.detail.freeRemaining, 0);
});

Deno.test("CI-C8 reason: explanation is deterministic (identical across two runs)", () => {
  const spec: SolverSpec = {
    subjectName: "Mathematics",
    totalMarks: 15,
    difficulty: "medium",
    chapters: ["Algebra"],
    questionTypeMix: { mcq: 2, short_answer: 1 },
  };
  const bank = [
    item({ id: "a", marks: 5, fingerprint: "fp-a", question_text: "A" }),
    item({ id: "c", chapter: "Geometry", marks: 5, fingerprint: "fp-c", question_text: "C" }),
  ];
  const solution = solveBlueprint(spec, bank);
  assertEquals(
    JSON.stringify(explainSelection(spec, bank, solution)),
    JSON.stringify(explainSelection(spec, bank, solution)),
  );
});

// ── Template path (CI-C1) ────────────────────────────────────────────────────

const HOTS_TEMPLATE: BlueprintTemplate = {
  totalMarks: 10,
  sections: [
    {
      code: "A",
      questionType: "mcq",
      marksPerQuestion: 5,
      count: 2,
      difficulty: "medium",
      cognitiveQuota: { hots_min_count: 1 }, // slot 0 becomes cognitiveRequire=hots
    },
  ],
};

Deno.test("CI-C8 reason: template path explains section + satisfied cognitive constraint", () => {
  const spec: SolverSpec = {
    subjectName: "Mathematics",
    totalMarks: 10,
    difficulty: "medium",
    chapters: ["Algebra"],
    template: HOTS_TEMPLATE,
  };
  const bank = [
    item({ id: "h", marks: 5, difficulty: "medium", cognitive_level: "hots", fingerprint: "fp-h", question_text: "H" }),
    item({ id: "m", marks: 5, difficulty: "medium", cognitive_level: "apply", fingerprint: "fp-m", question_text: "M" }),
  ];
  const solution = solveBlueprint(spec, bank);
  // The template solver fills slot 0 (needs hots) with h, slot 1 (free) with m.
  assertEquals(solution.template?.selected.map((s) => s.bankItem.id), ["h", "m"]);

  const explained = explainSelection(spec, bank, solution);
  assertEquals(explained.mode, "template");
  assertEquals(explained.selected.map((s) => s.bankItemId), ["h", "m"]);
  // slot 0 carried a hots requirement → the satisfied facts record it + the section.
  const s0 = explained.selected[0]!;
  assertEquals(s0!.sectionCode, "A");
  assertEquals(s0!.satisfied.includes("cognitive=hots"), true);
  // slot 1 is unconstrained → no cognitive fact.
  assertEquals(explained.selected[1]!.satisfied.some((f) => f.startsWith("cognitive")), false);
  assertEquals(explained.gaps, []);
});

Deno.test("CI-C8 reason: template gap code 'no_cognitive_match' — type+marks+difficulty ok, cognitive fails", () => {
  const spec: SolverSpec = {
    subjectName: "Mathematics",
    totalMarks: 10,
    difficulty: "medium",
    chapters: ["Algebra"],
    template: HOTS_TEMPLATE,
  };
  // Both items are 'apply' — right type/marks/difficulty but neither is HOTS, so the
  // hots-required slot 0 becomes a gap; slot 1 (free) still gets one.
  const bank = [
    item({ id: "p1", marks: 5, difficulty: "medium", cognitive_level: "apply", fingerprint: "fp-1", question_text: "P1" }),
    item({ id: "p2", marks: 5, difficulty: "medium", cognitive_level: "apply", fingerprint: "fp-2", question_text: "P2" }),
  ];
  const solution = solveBlueprint(spec, bank);
  const explained = explainSelection(spec, bank, solution);
  assertEquals(explained.mode, "template");
  // Exactly one gap: the hots-required slot 0.
  const hotsGap = explained.gaps.find((g) => g.slotIndex === 0);
  assertEquals(hotsGap?.code, "no_cognitive_match");
  assertEquals(hotsGap?.sectionCode, "A");
  // Gap slot indexes agree with the template solver's own gap list.
  assertEquals(
    explained.gaps.map((g) => g.slotIndex).sort(),
    (solution.template?.gaps ?? []).map((g) => g.index).sort(),
  );
});
