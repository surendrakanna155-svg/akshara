import { assertEquals } from "jsr:@std/assert@1";
import {
  type ExamProfile,
  isExamProfileAllowed,
  orderBankForProfile,
  profileScopeWidening,
  resolveExamProfileGating,
  scoreItemForProfile,
  validateProfileCompatibility,
} from "./education_exam_profile.ts";
import { solveBlueprint, type SolverSpec } from "./education_blueprint_solver.ts";
import type { QuestionBankItemRow } from "./education_types.ts";

// CI-C7 — Exam Profile Engine. Hand-authored fixtures only; every function under
// test is PURE + DETERMINISTIC (no Date / random / DB / network), so a fixed
// input → identical output. These tests pin the NEW profile capability ONLY —
// the certified solver / template / export goldens are untouched and stay green.

/** Fully-fixed bank item — nothing random; fingerprint pinned explicitly. */
function fixedItem(o: Partial<QuestionBankItemRow>): QuestionBankItemRow {
  return {
    id: "item",
    organization_id: "org",
    school_id: "school",
    subject_name: "Science",
    chapter: "Force",
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

// ════════════════════════════════════════════════════════════════════════════
// (3) Profile-driven selection weighting — deterministic + biases selection.
// ════════════════════════════════════════════════════════════════════════════

Deno.test("CI-C7 weighting: scoreItemForProfile sums chapter/difficulty/cognitive emphasis", () => {
  const profile: ExamProfile = {
    code: "foundation",
    weighting: {
      chapterEmphasis: { Force: 10 },
      difficultyEmphasis: { hard: 5 },
      cognitiveEmphasis: { hots: 3 },
    },
  };
  // Force + hard + hots → 10 + 5 + 3 = 18.
  assertEquals(
    scoreItemForProfile(profile, item("x", { chapter: "Force", difficulty: "hard", cognitive_level: "hots" })),
    18,
  );
  // Different chapter, easy, remember → 0.
  assertEquals(
    scoreItemForProfile(profile, item("y", { chapter: "Motion", difficulty: "easy", cognitive_level: "remember" })),
    0,
  );
});

Deno.test("CI-C7 weighting: orderBankForProfile sorts by emphasis, canonical tiebreak, and is deterministic", () => {
  const profile: ExamProfile = {
    code: "foundation",
    weighting: { cognitiveEmphasis: { hots: 10, analyze: 5 } },
  };
  const bank = [
    item("a", { cognitive_level: "remember" }),
    item("b", { cognitive_level: "hots" }),
    item("c", { cognitive_level: "analyze" }),
    item("d", { cognitive_level: "hots" }),
  ];
  const ordered = orderBankForProfile(profile, bank);
  // hots first (b,d — canonical id tiebreak), then analyze (c), then remember (a).
  assertEquals(ordered.map((i) => i.id), ["b", "d", "c", "a"]);
  // Pure: input is not mutated.
  assertEquals(bank.map((i) => i.id), ["a", "b", "c", "d"]);
  // Deterministic: same input → same order.
  assertEquals(orderBankForProfile(profile, bank).map((i) => i.id), ["b", "d", "c", "a"]);
});

Deno.test("CI-C7 weighting: an EMPTY profile reproduces the certified canonical bank order", () => {
  const profile: ExamProfile = { code: "standard_board" }; // no weighting
  const bank = [
    item("z", { chapter: "Motion", marks: 3 }),
    item("a", { chapter: "Force", marks: 5 }),
    item("m", { chapter: "Force", marks: 1 }),
  ];
  // With no emphasis every score is 0 → canonical (chapter, marks, id) order:
  // Force/1(m), Force/5(a), Motion/3(z).
  assertEquals(orderBankForProfile(profile, bank).map((i) => i.id), ["m", "a", "z"]);
});

Deno.test("CI-C7 seam: profile weighting biases the REAL solver's pick into a contested slot", () => {
  // One MCQ/1 slot; two eligible items differ only by cognitive level. The
  // certified bank-first solver takes whichever the bank presents first, so the
  // profile's re-ordering decides the pick — proving the bias is real, with the
  // solver itself untouched.
  const spec: SolverSpec = {
    subjectName: "Science",
    totalMarks: 1,
    difficulty: "easy",
    chapters: ["Force"],
    questionTypeMix: { mcq: 1 },
  };
  const bank = [
    item("shallow", { question_type: "mcq", marks: 1, difficulty: "easy", cognitive_level: "remember" }),
    item("deep", { question_type: "mcq", marks: 1, difficulty: "easy", cognitive_level: "hots" }),
  ];

  // No profile → solver takes bank order (shallow first).
  assertEquals(solveBlueprint(spec, bank).selected[0]!.bankItem.id, "shallow");

  // Foundation profile emphasising HOTS → the re-ordered bank puts 'deep' first.
  const foundation: ExamProfile = { code: "foundation", weighting: { cognitiveEmphasis: { hots: 10 } } };
  const ordered = orderBankForProfile(foundation, bank);
  assertEquals(solveBlueprint(spec, ordered).selected[0]!.bankItem.id, "deep");
});

// ════════════════════════════════════════════════════════════════════════════
// (4) Compatibility validation — compatible + explicit incompatibilities.
// ════════════════════════════════════════════════════════════════════════════

const SYLLABUS = { syllabusChapters: ["Force", "Motion"] };

/** A bank rich enough to satisfy a demanding foundation profile. */
function richBank(): QuestionBankItemRow[] {
  return [
    item("h1", { cognitive_level: "hots", difficulty: "hard" }),
    item("h2", { cognitive_level: "hots", difficulty: "hard" }),
    item("an1", { cognitive_level: "analyze" }),
    item("dg1", { question_type: "diagram", marks: 3 }),
    item("dg2", { question_type: "diagram", marks: 3 }),
    item("sa1", { question_type: "short_answer", marks: 3 }),
    item("sa2", { question_type: "short_answer", marks: 3 }),
  ];
}

Deno.test("CI-C7 compat: a well-matched profile validates as compatible", () => {
  const profile: ExamProfile = {
    code: "foundation",
    foundation: true,
    reasoningDepth: { minLevel: "hots", minCount: 2 },
    diagramRequirement: { minCount: 2 },
    questionFamilyDistribution: { short_answer: 2 },
  };
  const result = validateProfileCompatibility(profile, SYLLABUS, richBank());
  assertEquals(result.compatible, true);
  assertEquals(result.incompatibilities, []);
});

Deno.test("CI-C7 compat: insufficient reasoning depth is surfaced EXPLICITLY (never silently downgraded)", () => {
  const profile: ExamProfile = {
    code: "foundation",
    foundation: true,
    reasoningDepth: { minLevel: "hots", minCount: 4 }, // needs 4 HOTS
  };
  // Bank has only 2 HOTS.
  const result = validateProfileCompatibility(profile, SYLLABUS, richBank());
  assertEquals(result.compatible, false);
  const inc = result.incompatibilities.find((i) => i.code === "INSUFFICIENT_REASONING_DEPTH")!;
  assertEquals(inc.detail, { minLevel: "hots", required: 4, available: 2 });
});

Deno.test("CI-C7 compat: reasoning depth counts items AT OR ABOVE the required level", () => {
  const profile: ExamProfile = { code: "advanced_board", reasoningDepth: { minLevel: "analyze", minCount: 3 } };
  // analyze-or-above = h1,h2 (hots) + an1 (analyze) = 3 → compatible.
  assertEquals(validateProfileCompatibility(profile, SYLLABUS, richBank()).compatible, true);
});

Deno.test("CI-C7 compat: pending/archived items don't count toward requirements", () => {
  const profile: ExamProfile = { code: "foundation", reasoningDepth: { minLevel: "hots", minCount: 1 } };
  const bank = [
    item("p", { cognitive_level: "hots", review_status: "pending" }),
    item("z", { cognitive_level: "hots", status: "archived" }),
  ];
  const result = validateProfileCompatibility(profile, SYLLABUS, bank);
  assertEquals(result.compatible, false);
  assertEquals(
    result.incompatibilities[0]!.detail,
    { minLevel: "hots", required: 1, available: 0 },
  );
});

Deno.test("CI-C7 compat: insufficient diagram items surfaced explicitly", () => {
  const profile: ExamProfile = { code: "foundation", diagramRequirement: { minCount: 3 } };
  const result = validateProfileCompatibility(profile, SYLLABUS, richBank()); // only 2 diagrams
  const inc = result.incompatibilities.find((i) => i.code === "INSUFFICIENT_DIAGRAM_ITEMS")!;
  assertEquals(inc.detail, { required: 3, available: 2 });
});

Deno.test("CI-C7 compat: insufficient question family surfaced explicitly", () => {
  const profile: ExamProfile = { code: "foundation", questionFamilyDistribution: { long_answer: 2, short_answer: 1 } };
  const result = validateProfileCompatibility(profile, SYLLABUS, richBank());
  // long_answer has 0 in the bank → incompatible; short_answer (2) is fine.
  const codes = result.incompatibilities.map((i) => i.detail?.questionType);
  assertEquals(codes, ["long_answer"]);
});

// ════════════════════════════════════════════════════════════════════════════
// (A1-3) Foundation depth-not-scope — raises depth ✓ / rejects scope-widening ✗.
// ════════════════════════════════════════════════════════════════════════════

Deno.test("CI-C7 A1-3: a foundation profile may RAISE reasoning depth (in-scope) — compatible", () => {
  const profile: ExamProfile = {
    code: "foundation",
    foundation: true,
    // Depth raised: demands HOTS. NO additionalChapters → no scope change.
    reasoningDepth: { minLevel: "hots", minCount: 2 },
    weighting: { cognitiveEmphasis: { hots: 10, analyze: 5 } },
  };
  const result = validateProfileCompatibility(profile, SYLLABUS, richBank());
  assertEquals(result.compatible, true);
  assertEquals(profileScopeWidening(profile, SYLLABUS.syllabusChapters), []);
});

Deno.test("CI-C7 A1-3: a foundation profile that WIDENS scope is rejected (depth-not-scope)", () => {
  const profile: ExamProfile = {
    code: "foundation",
    foundation: true,
    additionalChapters: ["Thermodynamics", "Optics"], // outside the class syllabus
    // allowScopeExtension defaults false → forbidden.
  };
  assertEquals(profileScopeWidening(profile, SYLLABUS.syllabusChapters), ["Thermodynamics", "Optics"]);
  const result = validateProfileCompatibility(profile, SYLLABUS, richBank());
  assertEquals(result.compatible, false);
  const inc = result.incompatibilities.find((i) => i.code === "SCOPE_WIDENING_FORBIDDEN")!;
  assertEquals(inc.detail, { addedChapters: ["Thermodynamics", "Optics"], allowScopeExtension: false });
});

Deno.test("CI-C7 A1-3: scope widening is ALLOWED only when explicitly configured", () => {
  const profile: ExamProfile = {
    code: "foundation",
    foundation: true,
    additionalChapters: ["Thermodynamics"],
    allowScopeExtension: true, // explicit escape hatch
  };
  const result = validateProfileCompatibility(profile, SYLLABUS, richBank());
  assertEquals(result.incompatibilities.some((i) => i.code === "SCOPE_WIDENING_FORBIDDEN"), false);
});

Deno.test("CI-C7 A1-3: re-listing an in-scope chapter is not scope widening", () => {
  const profile: ExamProfile = { code: "foundation", foundation: true, additionalChapters: ["force", "  Motion "] };
  // Both normalise to in-scope chapters → no widening.
  assertEquals(profileScopeWidening(profile, SYLLABUS.syllabusChapters), []);
});

// ════════════════════════════════════════════════════════════════════════════
// (5) Capability gating — DEFAULT-ALLOW (invariant B7).
// ════════════════════════════════════════════════════════════════════════════

Deno.test("CI-C7 gating: an ungated profile (no slug) is always allowed", () => {
  const profile: ExamProfile = { code: "standard_board" };
  const r = resolveExamProfileGating(profile, { deniedEntitlements: ["exam_profile.foundation"] });
  assertEquals(r.allowed, true);
  assertEquals(r.reason, "no_entitlement_required");
});

Deno.test("CI-C7 gating: DEFAULT-ALLOW — a gated profile with no grant and no deny is allowed (B7)", () => {
  const profile: ExamProfile = { code: "foundation", entitlementSlug: "exam_profile.foundation" };
  // Empty entitlement state — nothing granted, nothing denied.
  const r = resolveExamProfileGating(profile, {});
  assertEquals(r.allowed, true);
  assertEquals(r.reason, "default_allow");
  assertEquals(r.entitlementSlug, "exam_profile.foundation");
});

Deno.test("CI-C7 gating: an explicit grant is allowed and reported as such", () => {
  const profile: ExamProfile = { code: "foundation", entitlementSlug: "exam_profile.foundation" };
  const r = resolveExamProfileGating(profile, { grantedEntitlements: ["exam_profile.foundation"] });
  assertEquals(r.allowed, true);
  assertEquals(r.reason, "explicitly_granted");
});

Deno.test("CI-C7 gating: ONLY an explicit deny blocks the profile", () => {
  const profile: ExamProfile = { code: "foundation", entitlementSlug: "exam_profile.foundation" };
  const r = resolveExamProfileGating(profile, { deniedEntitlements: ["exam_profile.foundation"] });
  assertEquals(r.allowed, false);
  assertEquals(r.reason, "explicitly_denied");
  assertEquals(isExamProfileAllowed(profile, { deniedEntitlements: ["exam_profile.foundation"] }), false);
});

Deno.test("CI-C7 gating: a deny of a DIFFERENT slug does not block (never over-block)", () => {
  const profile: ExamProfile = { code: "foundation", entitlementSlug: "exam_profile.foundation" };
  assertEquals(
    isExamProfileAllowed(profile, { deniedEntitlements: ["exam_profile.olympiad"] }),
    true,
  );
});
