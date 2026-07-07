import { assertSnapshot } from "jsr:@std/testing/snapshot";
import { assertEquals } from "jsr:@std/assert@1";
import {
  planSlots,
  solveBlueprint,
  type SolverSpec,
} from "./education_blueprint_solver.ts";
import type { QuestionBankItemRow } from "./education_types.ts";

// CI-0a — GOLDEN PIN of the CERTIFIED blueprint solver's current behaviour.
//
// The solver is the live production paper-generation engine. Per the
// curriculum-intelligence golden-first HARD RULE (handoff §7 / AT-C1.1), its
// current outputs are pinned BYTE-STABLE here BEFORE any solver edit, so any
// future change to the slot plan / marks distribution / bank-first selection
// must update the golden deliberately — and **template-absent requests must
// remain golden-identical forever** (B1 mitigation).
//
// Goldens live in `__snapshots__/education_blueprint_solver_golden_test.ts.snap`
// (regenerate deliberately with `deno test ... -- --update`). Fixtures are FULLY
// fixed (no crypto.randomUUID / Math.random, fingerprint pinned) and the solver
// is pure (no Date / random / DB / network), so a fixed input → identical output.

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
    fingerprint: "fp",
    review_status: "approved",
    created_by: null,
    created_at: "t",
    updated_at: "t",
    ...o,
  };
}

// The "must remain identical forever" template-absent totals (AT-C1.1).
const ABSENT_TOTALS = [7, 20, 33, 50, 100];

Deno.test(
  "CI-0a golden: template-absent planSlots (mixed) is byte-stable + sums exactly",
  async (t) => {
    for (const totalMarks of ABSENT_TOTALS) {
      const spec: SolverSpec = {
        subjectName: "Mathematics",
        totalMarks,
        difficulty: "mixed",
        chapters: ["Algebra", "Geometry"],
      };
      const plan = planSlots(spec);
      // Core invariant: per-slot marks sum EXACTLY to totalMarks.
      assertEquals(plan.reduce((a, s) => a + s.marks, 0), totalMarks);
      await assertSnapshot(t, plan, { name: `planSlots absent total=${totalMarks}` });
    }
  },
);

Deno.test(
  "CI-0a golden: explicit questionTypeMix planSlots is byte-stable",
  async (t) => {
    const spec: SolverSpec = {
      subjectName: "Mathematics",
      totalMarks: 30,
      difficulty: "medium",
      chapters: ["Algebra"],
      questionTypeMix: { mcq: 3, short_answer: 2 },
    };
    const plan = planSlots(spec);
    assertEquals(plan.length, 5); // explicit count pins the slot count
    assertEquals(plan.reduce((a, s) => a + s.marks, 0), 30);
    await assertSnapshot(t, plan);
  },
);

Deno.test(
  "CI-0a golden: solveBlueprint selection (match/fallback/dedup/gap) is byte-stable",
  async (t) => {
    const spec: SolverSpec = {
      subjectName: "Mathematics",
      totalMarks: 15,
      difficulty: "medium",
      chapters: ["Algebra"],
      questionTypeMix: { mcq: 2, short_answer: 1 },
    };
    const bank: QuestionBankItemRow[] = [
      // a: mcq/5/Algebra → chapter-matches slot 0.
      fixedItem({ id: "a", chapter: "Algebra", question_type: "mcq", marks: 5, fingerprint: "fp-mcq-1", question_text: "A" }),
      // b: shares fingerprint fp-mcq-1 with a → deduped (never selected).
      fixedItem({ id: "b", chapter: "Algebra", question_type: "mcq", marks: 5, fingerprint: "fp-mcq-1", question_text: "B" }),
      // c: mcq/5/Geometry → eligible for slot 1 via fallback (chapter mismatch).
      fixedItem({ id: "c", chapter: "Geometry", question_type: "mcq", marks: 5, fingerprint: "fp-mcq-2", question_text: "C" }),
    ];
    const solution = solveBlueprint(spec, bank);
    // a→slot0 (chapter match) · c→slot1 (fallback to eligible[0]) · b skipped
    // (dedup) · short_answer slot2 → gap (no eligible item).
    assertEquals(solution.selected.map((s) => [s.slot.index, s.bankItem.id]), [[0, "a"], [1, "c"]]);
    assertEquals(solution.gaps.map((g) => g.index), [2]);
    await assertSnapshot(t, solution);
  },
);
