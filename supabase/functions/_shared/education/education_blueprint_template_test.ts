import { assertSnapshot } from "jsr:@std/testing/snapshot";
import { assertEquals } from "jsr:@std/assert@1";
import {
  type BlueprintTemplate,
  planTemplateSlots,
  solveBlueprint,
  solveTemplateBlueprint,
  type SolverSpec,
} from "./education_blueprint_solver.ts";
import type { QuestionBankItemRow } from "./education_types.ts";

// CI-C1 — template-aware solver (v3.0 §9.1/§9.2). ADDITIVE + template-gated.
//
// These tests pin the NEW template path ONLY. The certified no-template golden
// (`education_blueprint_solver_golden_test.ts`) is left untouched and stays green
// — template-absent behaviour is byte-identical (mitigation B1 / invariant I1).
//
// Everything is FULLY FIXED (no crypto.randomUUID / Math.random; fingerprints
// pinned) and the solver is pure, so a fixed input → identical output. The new
// golden lives in `__snapshots__/education_blueprint_template_test.ts.snap`.

/** Fully-fixed bank item — nothing random; fingerprint pinned explicitly. */
function fixedItem(o: Partial<QuestionBankItemRow>): QuestionBankItemRow {
  return {
    id: "item",
    organization_id: "org",
    school_id: "school",
    subject_name: "Mathematics",
    chapter: "Algebra",
    topic: "",
    difficulty: "medium",
    question_type: "mcq",
    marks: 1,
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
    fingerprint: "fp",
    review_status: "approved",
    created_by: null,
    created_at: "t",
    updated_at: "t",
    ...o,
  };
}

function item(id: string, o: Partial<QuestionBankItemRow>): QuestionBankItemRow {
  return fixedItem({ id, fingerprint: `fp-${id}`, question_text: id, ...o });
}

// A GENERIC, board/exam-agnostic representative template. Grounded in real board
// SQP structure (subject/type sections, per-question marks, internal-choice
// pools "any X of Y", chapter/unit weightage, framework-level competency +
// difficulty distributions — see the local CBSE Class X blueprints) but carries
// no board/exam identity of its own.
//
// scoredMarks = A(6×1) + B(4×3) + C(4×5) = 6 + 12 + 20 = 38 = totalMarks.
const FIXTURE: BlueprintTemplate = {
  totalMarks: 38,
  durationMinutes: 90,
  generalInstructions: ["All questions are compulsory unless a choice is indicated."],
  sections: [
    // Section A — objective, easy; at most 50% of the 6 answers may be R/U (cap = 3).
    {
      code: "A",
      title: "Objective",
      questionType: "mcq",
      marksPerQuestion: 1,
      count: 6,
      difficulty: "easy",
      cognitiveQuota: { remember_understand_max_pct: 50 },
    },
    // Section B — short answer, medium; internal choice "any 4 of 6".
    {
      code: "B",
      title: "Short Answer",
      questionType: "short_answer",
      marksPerQuestion: 3,
      count: 4,
      difficulty: "medium",
      internalChoice: { pool: 6, answer: 4 },
    },
    // Section C — long answer, hard; at least 2 of the 4 answers must be HOTS.
    {
      code: "C",
      title: "Long Answer",
      questionType: "long_answer",
      marksPerQuestion: 5,
      count: 4,
      difficulty: "hard",
      cognitiveQuota: { hots_min_count: 2 },
    },
  ],
  chapterWeightage: { mode: "explicit", marks: { Algebra: 19, Geometry: 19 } },
  difficultyCurve: { easy: 0.3, medium: 0.5, hard: 0.2 },
  competencyQuota: { competency_based_min_pct: 40 },
};

const CHAPTERS = ["Algebra", "Geometry"];

function spec(template?: BlueprintTemplate): SolverSpec {
  return {
    subjectName: "Mathematics",
    totalMarks: template?.totalMarks ?? 38,
    difficulty: "mixed",
    chapters: CHAPTERS,
    template,
  };
}

/** A curated, fully-fixed bank that fills the whole FIXTURE cleanly. */
function fixtureBank(): QuestionBankItemRow[] {
  const A = ["Algebra", "Geometry"];
  return [
    // Section A — 6× mcq/1/easy, cognitive 'apply' (non-R/U, so the R/U cap is
    // trivially met and every slot fills — the cap itself is proven separately).
    ...Array.from({ length: 6 }, (_, i) =>
      item(`a${i}`, {
        question_type: "mcq",
        marks: 1,
        difficulty: "easy",
        chapter: A[i % 2]!,
        cognitive_level: "apply",
      })),
    // Section B — 6× short_answer/3/medium (fills the 4 scored + 2 choice-pool slots).
    ...Array.from({ length: 6 }, (_, i) =>
      item(`b${i}`, {
        question_type: "short_answer",
        marks: 3,
        difficulty: "medium",
        chapter: A[i % 2]!,
        cognitive_level: null,
      })),
    // Section C — 2× HOTS + 2× analyze long_answer/5/hard.
    item("c0", { question_type: "long_answer", marks: 5, difficulty: "hard", chapter: "Algebra", cognitive_level: "hots" }),
    item("c1", { question_type: "long_answer", marks: 5, difficulty: "hard", chapter: "Geometry", cognitive_level: "hots" }),
    item("c2", { question_type: "long_answer", marks: 5, difficulty: "hard", chapter: "Algebra", cognitive_level: "analyze" }),
    item("c3", { question_type: "long_answer", marks: 5, difficulty: "hard", chapter: "Geometry", cognitive_level: "analyze" }),
  ];
}

// ── Golden: the template PLAN is byte-stable ────────────────────────────────
Deno.test("CI-C1 golden: planTemplateSlots is byte-stable (sections, choice pools, weightage, quotas)", async (t) => {
  const planned = planTemplateSlots(FIXTURE, CHAPTERS);
  // Sanity that also documents the plan for the reviewer.
  assertEquals(planned.slots.length, 6 + 6 + 4); // A:6, B:6(pool), C:4
  await assertSnapshot(t, planned.slots);
});

// ── Golden: the solved selection + constraint report is byte-stable ─────────
Deno.test("CI-C1 golden: solveTemplateBlueprint selection + report is byte-stable", async (t) => {
  const solution = solveTemplateBlueprint(FIXTURE, spec(FIXTURE), fixtureBank());
  const projection = {
    totalMarks: solution.totalMarks,
    durationMinutes: solution.durationMinutes,
    generalInstructions: solution.generalInstructions,
    sections: solution.sections.map((s) => ({
      code: s.code,
      questionType: s.questionType,
      answerCount: s.answerCount,
      poolCount: s.poolCount,
      scoredMarks: s.scoredMarks,
      selected: s.selected.map((x) => [x.slot.index, x.bankItem.id]),
      gaps: s.gaps.map((g) => g.index),
    })),
    report: solution.report,
  };
  await assertSnapshot(t, projection);
});

// ── Sections honoured ───────────────────────────────────────────────────────
Deno.test("CI-C1: sections are honoured (codes, types, per-question marks, counts)", () => {
  const solution = solveTemplateBlueprint(FIXTURE, spec(FIXTURE), fixtureBank());
  assertEquals(solution.sections.map((s) => s.code), ["A", "B", "C"]);
  assertEquals(solution.sections.map((s) => s.questionType), ["mcq", "short_answer", "long_answer"]);
  assertEquals(solution.sections.map((s) => s.marksPerQuestion), [1, 3, 5]);
  // Every slot in a section carries that section's type + marks.
  for (const s of solution.sections) {
    for (const slot of s.slots) {
      assertEquals(slot.questionType, s.questionType);
      assertEquals(slot.marks, s.marksPerQuestion);
      assertEquals(slot.sectionCode, s.code);
    }
  }
});

// ── Marks balance ───────────────────────────────────────────────────────────
Deno.test("CI-C1: scored marks balance exactly to the template total", () => {
  const solution = solveTemplateBlueprint(FIXTURE, spec(FIXTURE), fixtureBank());
  assertEquals(solution.report.scoredMarks, 38);
  assertEquals(solution.report.templateTotalMarks, 38);
  assertEquals(solution.report.marksBalanced, true);
});

// ── Internal-choice pools ───────────────────────────────────────────────────
Deno.test("CI-C1: internal choice prints the pool but scores only the answer count", () => {
  const solution = solveTemplateBlueprint(FIXTURE, spec(FIXTURE), fixtureBank());
  const b = solution.sections.find((s) => s.code === "B")!;
  assertEquals(b.answerCount, 4);
  assertEquals(b.poolCount, 6); // "any 4 of 6" → 6 questions printed
  assertEquals(b.slots.length, 6);
  assertEquals(b.slots.filter((s) => s.scored).length, 4);
  assertEquals(b.slots.filter((s) => !s.scored).length, 2);
  assertEquals(b.scoredMarks, 12); // 4 × 3, NOT 6 × 3
  assertEquals(b.selected.length, 6); // bank fills all 6 printed slots
});

// ── Chapter weightage as a hard constraint ──────────────────────────────────
Deno.test("CI-C1: chapter weightage is honoured exactly (hard constraint)", () => {
  const solution = solveTemplateBlueprint(FIXTURE, spec(FIXTURE), fixtureBank());
  const cw = solution.report.chapterWeightage!;
  assertEquals(cw.target, { Algebra: 19, Geometry: 19 });
  assertEquals(cw.planned, { Algebra: 19, Geometry: 19 });
  assertEquals(cw.satisfied, true);
});

Deno.test("CI-C1: a chapter weightage that cannot balance is reported unsatisfied (never silently violated)", () => {
  const bad: BlueprintTemplate = {
    ...FIXTURE,
    chapterWeightage: { mode: "explicit", marks: { Algebra: 30, Geometry: 8 } }, // impossible split
  };
  const solution = solveTemplateBlueprint(bad, spec(bad), fixtureBank());
  assertEquals(solution.report.chapterWeightage!.satisfied, false);
});

// ── Cognitive HOTS minimum as a hard constraint ─────────────────────────────
Deno.test("CI-C1: HOTS minimum is met when the bank has HOTS items", () => {
  const solution = solveTemplateBlueprint(FIXTURE, spec(FIXTURE), fixtureBank());
  const c = solution.report.cognitive.find((x) => x.sectionCode === "C")!;
  assertEquals(c.hotsMin, 2);
  assertEquals(c.hotsSelected, 2);
  assertEquals(c.satisfied, true);
});

Deno.test("CI-C1: HOTS minimum fails HONESTLY into gaps when the bank has no HOTS items", () => {
  const template: BlueprintTemplate = {
    totalMarks: 20,
    sections: [{
      code: "C",
      questionType: "long_answer",
      marksPerQuestion: 5,
      count: 4,
      difficulty: "hard",
      cognitiveQuota: { hots_min_count: 2 },
    }],
  };
  // 4 eligible long/5/hard items but ZERO HOTS — the 2 HOTS-required slots cannot
  // be filled without violating the quota, so they become gaps (never faked).
  const bank = Array.from({ length: 4 }, (_, i) =>
    item(`x${i}`, { question_type: "long_answer", marks: 5, difficulty: "hard", cognitive_level: "analyze" }));
  const solution = solveTemplateBlueprint(template, spec(template), bank);
  const sec = solution.sections[0]!;
  assertEquals(sec.gaps.length, 2); // the 2 HOTS-required slots
  assertEquals(sec.selected.length, 2); // the 2 unconstrained slots fill
  assertEquals(solution.report.cognitive[0]!.satisfied, false);
  // Gaps carry exact type/marks for the constrained-AI step (invariant I3).
  assertEquals(sec.gaps.every((g) => g.questionType === "long_answer" && g.marks === 5), true);
});

// ── Remember/Understand cap as a hard constraint ────────────────────────────
Deno.test("CI-C1: remember/understand cap is a HARD constraint — excess R/U slots gap, never overfill", () => {
  const template: BlueprintTemplate = {
    totalMarks: 6,
    sections: [{
      code: "A",
      questionType: "mcq",
      marksPerQuestion: 1,
      count: 6,
      difficulty: "easy",
      cognitiveQuota: { remember_understand_max_pct: 50 }, // cap = 3 of 6
    }],
  };
  // Bank is ALL 'remember' — only the ≤3 non-capped slots may take them; the
  // R/U-excluded slots gap rather than blow the cap.
  const bank = Array.from({ length: 6 }, (_, i) =>
    item(`r${i}`, { question_type: "mcq", marks: 1, difficulty: "easy", cognitive_level: "remember" }));
  const solution = solveTemplateBlueprint(template, spec(template), bank);
  const c = solution.report.cognitive[0]!;
  assertEquals(c.rememberUnderstandMax, 3);
  assertEquals(c.rememberUnderstandSelected <= 3, true);
  assertEquals(c.satisfied, true); // cap respected
  assertEquals(solution.sections[0]!.gaps.length, 3); // the 3 excess slots gap honestly
});

// ── Full-bank pagination (no 100-item cap) ──────────────────────────────────
Deno.test("CI-C1: solver scans the FULL bank — no 100-item cap", () => {
  const template: BlueprintTemplate = {
    totalMarks: 5,
    sections: [{ code: "S", questionType: "long_answer", marksPerQuestion: 5, count: 1, difficulty: "hard" }],
  };
  // 149 non-matching filler items, then the ONLY matching item at index 149.
  const filler = Array.from({ length: 149 }, (_, i) =>
    item(`f${i}`, { question_type: "mcq", marks: 1, difficulty: "easy" }));
  const target = item("deep", { question_type: "long_answer", marks: 5, difficulty: "hard" });
  const solution = solveTemplateBlueprint(template, spec(template), [...filler, target]);
  assertEquals(solution.selected.length, 1);
  assertEquals(solution.selected[0]!.bankItem.id, "deep"); // found past the old 100 cap
  assertEquals(solution.gaps.length, 0);
});

// ── Determinism ─────────────────────────────────────────────────────────────
Deno.test("CI-C1: template solve is deterministic (same inputs → same picks in order)", () => {
  const a = solveTemplateBlueprint(FIXTURE, spec(FIXTURE), fixtureBank());
  const b = solveTemplateBlueprint(FIXTURE, spec(FIXTURE), fixtureBank());
  assertEquals(
    a.selected.map((s) => [s.slot.index, s.bankItem.id]),
    b.selected.map((s) => [s.slot.index, s.bankItem.id]),
  );
});

// ── De-dup carries over to the template path ────────────────────────────────
Deno.test("CI-C1: identical questions are de-duped by fingerprint on the template path", () => {
  const template: BlueprintTemplate = {
    totalMarks: 2,
    sections: [{ code: "A", questionType: "mcq", marksPerQuestion: 1, count: 2, difficulty: "easy" }],
  };
  const shared = "fp-dup";
  const bank = [
    item("d1", { question_type: "mcq", marks: 1, difficulty: "easy", fingerprint: shared }),
    item("d2", { question_type: "mcq", marks: 1, difficulty: "easy", fingerprint: shared }),
  ];
  const solution = solveTemplateBlueprint(template, spec(template), bank);
  assertEquals(solution.selected.length, 1); // second copy skipped
  assertEquals(solution.gaps.length, 1);
});

// ── Template path still refuses pending / archived items (invariant B5) ──────
Deno.test("CI-C1: template path never selects pending or archived bank items", () => {
  const template: BlueprintTemplate = {
    totalMarks: 2,
    sections: [{ code: "A", questionType: "mcq", marksPerQuestion: 1, count: 2, difficulty: "easy" }],
  };
  const bank = [
    item("p", { question_type: "mcq", marks: 1, difficulty: "easy", review_status: "pending" }),
    item("z", { question_type: "mcq", marks: 1, difficulty: "easy", status: "archived" }),
  ];
  const solution = solveTemplateBlueprint(template, spec(template), bank);
  assertEquals(solution.selected.length, 0);
  assertEquals(solution.gaps.length, 2);
});

// ── The seam: no template ⇒ legacy path, byte-identical (no `template` field) ─
Deno.test("CI-C1 seam: solveBlueprint WITHOUT a template returns the legacy shape (no template field)", () => {
  const legacySpec: SolverSpec = {
    subjectName: "Mathematics",
    totalMarks: 15,
    difficulty: "medium",
    chapters: ["Algebra"],
    questionTypeMix: { mcq: 2, short_answer: 1 },
  };
  const solution = solveBlueprint(legacySpec, fixtureBank());
  assertEquals(solution.template, undefined); // legacy path attaches nothing
  assertEquals("template" in solution, false); // the key is absent, not just undefined
});

Deno.test("CI-C1 seam: solveBlueprint WITH a template routes to the template path", () => {
  const solution = solveBlueprint(spec(FIXTURE), fixtureBank());
  assertEquals(solution.template !== undefined, true);
  assertEquals(solution.template!.sections.map((s) => s.code), ["A", "B", "C"]);
  // Flattened slots/selected/gaps mirror the rich solution.
  assertEquals(solution.slots.length, solution.template!.slots.length);
  assertEquals(solution.selected.length, solution.template!.selected.length);
});
