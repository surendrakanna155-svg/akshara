import { assertEquals } from "jsr:@std/assert@1";
import {
  applyRotation,
  itemExposure,
  orderBankForRotation,
  type RotationPolicy,
  rotationExclusion,
  rotationExclusions,
} from "./education_item_rotation.ts";
import { solveBlueprint, type SolverSpec } from "./education_blueprint_solver.ts";
import type { QuestionBankItemRow } from "./education_types.ts";

// CI-C8 — item exposure / rotation helper. Fully-fixed fixtures (no Date.now / no
// randomness); the reference instant is passed IN, so every assertion is
// deterministic. The overriding contract: with no policy / no exposure the bank
// order (and therefore the certified solver's pick) is BYTE-IDENTICAL.

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

const REF = "2026-07-08T00:00:00.000Z";

// ── Exposure reading ─────────────────────────────────────────────────────────

Deno.test("CI-C8 rotation: itemExposure reads counters, absent ⇒ never used", () => {
  assertEquals(itemExposure(item({})), { timesUsed: 0, lastUsedAt: null });
  assertEquals(
    itemExposure(item({ times_used: 3, last_used_at: REF })),
    { timesUsed: 3, lastUsedAt: REF },
  );
  // Defensive: negative / empty are normalised to the never-used defaults.
  assertEquals(itemExposure(item({ times_used: -2, last_used_at: "" })), {
    timesUsed: 0,
    lastUsedAt: null,
  });
});

// ── Byte-identity guarantees (invariant I1) ──────────────────────────────────

Deno.test("CI-C8 rotation: an EMPTY policy with no exposure reproduces the canonical order", () => {
  const bank = [
    item({ id: "b", chapter: "Geometry", marks: 5 }),
    item({ id: "a", chapter: "Algebra", marks: 5 }),
    item({ id: "c", chapter: "Algebra", marks: 3 }),
  ];
  // Canonical order = chapter, then marks, then id: Algebra/3/c, Algebra/5/a, Geometry/5/b.
  const ordered = orderBankForRotation({}, bank, { referenceAt: REF });
  assertEquals(ordered.map((i) => i.id), ["c", "a", "b"]);
  // Pure — input untouched.
  assertEquals(bank.map((i) => i.id), ["b", "a", "c"]);
});

Deno.test("CI-C8 rotation: empty policy excludes NOTHING", () => {
  const bank = [item({ id: "a", times_used: 99, last_used_at: REF })];
  assertEquals(rotationExclusions({}, bank, { referenceAt: REF }), []);
  assertEquals(orderBankForRotation({}, bank, { referenceAt: REF }).map((i) => i.id), ["a"]);
});

Deno.test("CI-C8 rotation: no exposure ⇒ solver picks IDENTICALLY to the certified path", () => {
  const spec: SolverSpec = {
    subjectName: "Mathematics",
    totalMarks: 10,
    difficulty: "medium",
    chapters: ["Algebra"],
    questionTypeMix: { mcq: 2 },
  };
  const bank = [
    item({ id: "a", chapter: "Algebra", fingerprint: "fp-a", question_text: "A" }),
    item({ id: "b", chapter: "Algebra", fingerprint: "fp-b", question_text: "B" }),
  ];
  const certified = solveBlueprint(spec, bank);
  const rotated = solveBlueprint(spec, orderBankForRotation({ deprioritizeRecent: true }, bank, { referenceAt: REF }));
  assertEquals(
    rotated.selected.map((s) => [s.slot.index, s.bankItem.id]),
    certified.selected.map((s) => [s.slot.index, s.bankItem.id]),
  );
});

// ── Hard cooldowns ───────────────────────────────────────────────────────────

Deno.test("CI-C8 rotation: cooldown_days hard-excludes an item used within the window", () => {
  const policy: RotationPolicy = { cooldownDays: 30 };
  // used 10 days before REF → within a 30-day cooldown → excluded.
  const recent = item({ id: "recent", last_used_at: "2026-06-28T00:00:00.000Z" });
  // used 60 days before REF → outside the window → kept.
  const old = item({ id: "old", last_used_at: "2026-05-09T00:00:00.000Z" });
  const never = item({ id: "never" });

  const ex = rotationExclusion(policy, recent, { referenceAt: REF });
  assertEquals(ex?.reason, "cooldown_days");
  assertEquals(rotationExclusion(policy, old, { referenceAt: REF }), null);
  assertEquals(rotationExclusion(policy, never, { referenceAt: REF }), null);

  const kept = orderBankForRotation(policy, [recent, old, never], { referenceAt: REF });
  assertEquals(kept.map((i) => i.id).sort(), ["never", "old"]);
});

Deno.test("CI-C8 rotation: cooldown_days is inert without a reference instant", () => {
  const policy: RotationPolicy = { cooldownDays: 30 };
  const recent = item({ id: "recent", last_used_at: "2026-06-28T00:00:00.000Z" });
  // No referenceAt supplied → nothing can be "within N days" → not excluded.
  assertEquals(rotationExclusion(policy, recent, {}), null);
});

Deno.test("CI-C8 rotation: max_times_used hard-excludes an over-reused item", () => {
  const policy: RotationPolicy = { maxTimesUsed: 3 };
  assertEquals(rotationExclusion(policy, item({ id: "x", times_used: 3 }), {})?.reason, "max_times_used");
  assertEquals(rotationExclusion(policy, item({ id: "y", times_used: 4 }), {})?.reason, "max_times_used");
  assertEquals(rotationExclusion(policy, item({ id: "z", times_used: 2 }), {}), null);
});

Deno.test("CI-C8 rotation: applyRotation returns the filtered bank AND the exclusion report", () => {
  const policy: RotationPolicy = { maxTimesUsed: 2 };
  const bank = [
    item({ id: "used", times_used: 5 }),
    item({ id: "fresh", times_used: 0 }),
  ];
  const { bank: out, excluded } = applyRotation(policy, bank, { referenceAt: REF });
  assertEquals(out.map((i) => i.id), ["fresh"]);
  assertEquals(excluded.length, 1);
  assertEquals(excluded[0]!.itemId, "used");
  assertEquals(excluded[0]!.reason, "max_times_used");
});

// ── Soft rotation ordering ───────────────────────────────────────────────────

Deno.test("CI-C8 rotation: deprioritizeRecent orders least-used first, then least-recently-used", () => {
  const policy: RotationPolicy = { deprioritizeRecent: true };
  const bank = [
    item({ id: "heavy", times_used: 5, last_used_at: "2026-01-01T00:00:00.000Z" }),
    item({ id: "light-recent", times_used: 1, last_used_at: "2026-07-01T00:00:00.000Z" }),
    item({ id: "light-old", times_used: 1, last_used_at: "2026-02-01T00:00:00.000Z" }),
    item({ id: "never", times_used: 0 }),
  ];
  // never (0) → light-old (1, older) → light-recent (1, newer) → heavy (5).
  assertEquals(
    orderBankForRotation(policy, bank, { referenceAt: REF }).map((i) => i.id),
    ["never", "light-old", "light-recent", "heavy"],
  );
});

Deno.test("CI-C8 rotation: deprioritizeRecent=false keeps canonical order (only hard cooldowns apply)", () => {
  const policy: RotationPolicy = { deprioritizeRecent: false, maxTimesUsed: 10 };
  const bank = [
    item({ id: "b", chapter: "Geometry", marks: 5, times_used: 9 }),
    item({ id: "a", chapter: "Algebra", marks: 5, times_used: 1 }),
  ];
  // Heavily-used 'b' is NOT reordered (soft off) but still under the hard cap → kept.
  // Canonical: Algebra before Geometry.
  assertEquals(orderBankForRotation(policy, bank, { referenceAt: REF }).map((i) => i.id), ["a", "b"]);
});

Deno.test("CI-C8 rotation: rotation biases the REAL solver AWAY from a rested item", () => {
  const spec: SolverSpec = {
    subjectName: "Mathematics",
    totalMarks: 5,
    difficulty: "medium",
    chapters: ["Algebra"],
    questionTypeMix: { mcq: 1 },
  };
  // Two eligible items contest ONE slot. Canonically 'a' (id) would win; but 'a'
  // is heavily used, so rotation surfaces the fresh 'z' first and the solver
  // picks it — WITHOUT any change to the solver.
  const bank = [
    item({ id: "a", chapter: "Algebra", times_used: 9, last_used_at: REF, fingerprint: "fp-a", question_text: "A" }),
    item({ id: "z", chapter: "Algebra", times_used: 0, fingerprint: "fp-z", question_text: "Z" }),
  ];
  const certified = solveBlueprint(spec, bank);
  assertEquals(certified.selected[0]!.bankItem.id, "a"); // canonical winner

  const rotated = solveBlueprint(
    spec,
    orderBankForRotation({ deprioritizeRecent: true }, bank, { referenceAt: REF }),
  );
  assertEquals(rotated.selected[0]!.bankItem.id, "z"); // rested 'a', chose fresh 'z'
});

Deno.test("CI-C8 rotation: determinism — same inputs yield identical output twice", () => {
  const policy: RotationPolicy = { cooldownDays: 15, maxTimesUsed: 4, deprioritizeRecent: true };
  const bank = [
    item({ id: "a", times_used: 2, last_used_at: "2026-06-01T00:00:00.000Z" }),
    item({ id: "b", times_used: 4, last_used_at: "2026-07-05T00:00:00.000Z" }),
    item({ id: "c", times_used: 0 }),
  ];
  const first = applyRotation(policy, bank, { referenceAt: REF });
  const second = applyRotation(policy, bank, { referenceAt: REF });
  assertEquals(JSON.stringify(first), JSON.stringify(second));
});
