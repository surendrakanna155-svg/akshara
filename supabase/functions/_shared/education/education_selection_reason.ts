// CI-C8 — Selection-reason logging (explainability) for the paper solver.
// ADDITIVE + read-only. Pure, deterministic, ZERO AI, ZERO DB access, ZERO
// side effects. Given a paper the certified solver ALREADY produced, it returns
// a structure explaining, per selected item, WHICH slot / constraint it
// satisfied and WHY it was chosen over the alternatives; and per gap, WHY no
// approved bank item could fill it. It NEVER changes the solved paper — it is a
// second read over the same inputs, so it cannot affect selection (invariant I1).
//
// It reconstructs the reasons by REPLAYING the solver's deterministic bank-first
// walk (same eligibility predicate, same fingerprint dedup, same "chapter-
// preferred else first-eligible" rule, same used-set carried slot to slot). The
// solver is the source of truth; the predicates below MIRROR its private
// `matchesSlot` / `matchesSlotTemplate` / `itemFingerprint` exactly and are
// cross-checked against the real solver in the tests. Both certified paths are
// covered: the legacy flat plan and the CI-C1 template plan.

import { computeQuestionFingerprint } from "./education_fingerprint.ts";
import type {
  BlueprintSlot,
  BlueprintSolution,
  SolverSpec,
  TemplateSlot,
} from "./education_blueprint_solver.ts";
import type {
  EduCognitiveLevel,
  EduDifficulty,
  QuestionBankItemRow,
} from "./education_types.ts";

// ─────────────────────────────────────────────────────────────────────────────
// Result shapes.
// ─────────────────────────────────────────────────────────────────────────────

/** Explanation for one SELECTED item (why this bank item filled this slot). */
export interface ItemSelectionReason {
  slotIndex: number;
  /** Template path only — the section the slot belongs to. */
  sectionCode?: string;
  chapter: string;
  questionType: string;
  marks: number;
  difficulty: string;
  bankItemId: string;
  /** Constraints the chosen item satisfied, as human-readable `key=value` facts. */
  satisfied: string[];
  /** Chapter-preferred pick, or the first-eligible fallback (chapter mismatch). */
  selectionRule: "chapter_preferred" | "first_eligible_fallback";
  /** Other eligible, unused, non-duplicate items that could also have filled the slot. */
  alternativesConsidered: number;
  /** Would-match items skipped purely because a fingerprint-equal item was already used. */
  duplicatesSkipped: number;
}

export type GapReasonCode =
  | "no_type_match" // zero approved+active items of the slot's question type
  | "no_marks_match" // right type exists, none at the slot's marks
  | "no_difficulty_match" // right type+marks exist, none at the slot's difficulty
  | "no_cognitive_match" // template: type+marks+difficulty exist, none meets the cognitive constraint
  | "all_exhausted"; // matches existed but earlier slots consumed / deduped them all

/** Explanation for one GAP (why no approved item could fill this slot). */
export interface GapReason {
  slotIndex: number;
  sectionCode?: string;
  chapter: string;
  questionType: string;
  marks: number;
  difficulty: string;
  code: GapReasonCode;
  message: string;
  detail: Record<string, unknown>;
}

export interface SelectionExplanation {
  mode: "legacy" | "template";
  selected: ItemSelectionReason[];
  gaps: GapReason[];
}

// ─────────────────────────────────────────────────────────────────────────────
// Predicates — MIRROR the solver's private helpers exactly (source of truth:
// education_blueprint_solver.ts). Kept local so the certified solver stays
// untouched; the tests assert these track the real solver's picks.
// ─────────────────────────────────────────────────────────────────────────────

function isSelectable(item: QuestionBankItemRow): boolean {
  return item.status === "active" && item.review_status === "approved";
}

/** Mirror of solver `itemFingerprint`. */
function itemFingerprint(item: QuestionBankItemRow): string {
  return item.fingerprint ?? computeQuestionFingerprint({
    subjectName: item.subject_name,
    chapter: item.chapter,
    questionType: item.question_type,
    questionText: item.question_text,
  });
}

/** Mirror of solver `matchesSlot` (legacy path). */
function matchesSlot(
  item: QuestionBankItemRow,
  slot: BlueprintSlot,
  difficultyMode: EduDifficulty,
): boolean {
  if (!isSelectable(item)) return false;
  if (item.question_type !== slot.questionType) return false;
  if (item.marks !== slot.marks) return false;
  if (difficultyMode !== "mixed" && item.difficulty !== slot.difficulty) return false;
  return true;
}

/** Mirror of solver `matchesSlotTemplate` (CI-C1 template path). */
function matchesSlotTemplate(item: QuestionBankItemRow, slot: TemplateSlot): boolean {
  if (!isSelectable(item)) return false;
  if (item.question_type !== slot.questionType) return false;
  if (item.marks !== slot.marks) return false;
  if (slot.difficulty !== "mixed" && item.difficulty !== slot.difficulty) return false;
  if (slot.cognitiveRequire && item.cognitive_level !== slot.cognitiveRequire) return false;
  if (
    slot.cognitiveExclude &&
    item.cognitive_level !== null &&
    slot.cognitiveExclude.includes(item.cognitive_level as EduCognitiveLevel)
  ) {
    return false;
  }
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Reason builders.
// ─────────────────────────────────────────────────────────────────────────────

/** One slot to explain, with its eligibility predicate + metadata. */
interface WalkSlot {
  slot: BlueprintSlot;
  sectionCode?: string;
  /** The slot's FULL eligibility predicate (all constraints) — mirrors the solver. */
  matches: (item: QuestionBankItemRow) => boolean;
  /** Difficulty mode governing whether difficulty is a hard constraint for this slot. */
  difficultyMode: EduDifficulty;
  /** True when the slot carries a cognitive require/exclude (template path). */
  hasCognitiveConstraint: boolean;
  /** The satisfied cognitive fact for a chosen item, or null when unconstrained. */
  cognitiveFact: (item: QuestionBankItemRow) => string | null;
}

function satisfiedFacts(item: QuestionBankItemRow, w: WalkSlot): string[] {
  const { slot } = w;
  const facts = [`question_type=${slot.questionType}`, `marks=${slot.marks}`];
  if (w.difficultyMode !== "mixed") facts.push(`difficulty=${slot.difficulty}`);
  const cog = w.cognitiveFact(item);
  if (cog) facts.push(cog);
  return facts;
}

/** Progressive-narrowing diagnosis of WHY a slot became a gap. Pure. */
function diagnoseGap(
  w: WalkSlot,
  bank: QuestionBankItemRow[],
  usedIds: Set<string>,
  usedFingerprints: Set<string>,
): GapReason {
  const { slot } = w;
  const base = {
    slotIndex: slot.index,
    ...(w.sectionCode !== undefined ? { sectionCode: w.sectionCode } : {}),
    chapter: slot.chapter,
    questionType: slot.questionType,
    marks: slot.marks,
    difficulty: slot.difficulty,
  };

  const typeMatches = bank.filter((i) => isSelectable(i) && i.question_type === slot.questionType);
  if (typeMatches.length === 0) {
    return {
      ...base,
      code: "no_type_match",
      message: `No approved '${slot.questionType}' item exists in the bank.`,
      detail: { questionType: slot.questionType },
    };
  }

  const marksMatches = typeMatches.filter((i) => i.marks === slot.marks);
  if (marksMatches.length === 0) {
    return {
      ...base,
      code: "no_marks_match",
      message: `Approved '${slot.questionType}' items exist, but none at ${slot.marks} mark(s).`,
      detail: { questionType: slot.questionType, marks: slot.marks, typeMatchCount: typeMatches.length },
    };
  }

  const diffMatches = marksMatches.filter(
    (i) => w.difficultyMode === "mixed" || i.difficulty === slot.difficulty,
  );
  if (diffMatches.length === 0) {
    return {
      ...base,
      code: "no_difficulty_match",
      message:
        `Approved ${slot.marks}-mark '${slot.questionType}' items exist, but none at ` +
        `'${slot.difficulty}' difficulty.`,
      detail: { questionType: slot.questionType, marks: slot.marks, difficulty: slot.difficulty, marksMatchCount: marksMatches.length },
    };
  }

  // Template only: the cognitive constraint may be the last thing that empties it.
  // `w.matches` re-checks type/marks/difficulty too, but those already passed for
  // every item in diffMatches, so filtering by it isolates the cognitive step.
  const constraintMatches = w.hasCognitiveConstraint
    ? diffMatches.filter((i) => w.matches(i))
    : diffMatches;
  if (w.hasCognitiveConstraint && constraintMatches.length === 0) {
    return {
      ...base,
      code: "no_cognitive_match",
      message:
        `Approved ${slot.marks}-mark '${slot.questionType}' items at '${slot.difficulty}' ` +
        `exist, but none meets the section's cognitive constraint.`,
      detail: { questionType: slot.questionType, marks: slot.marks, difficulty: slot.difficulty, difficultyMatchCount: diffMatches.length },
    };
  }

  // Matches exist in the bank but every one was already used / deduped upstream.
  const freeRemaining = constraintMatches.filter(
    (i) => !usedIds.has(i.id) && !usedFingerprints.has(itemFingerprint(i)),
  ).length;
  return {
    ...base,
    code: "all_exhausted",
    message:
      `Matching items exist but all were already placed in earlier slots or ` +
      `removed as duplicates (${freeRemaining} free at this point).`,
    detail: { questionType: slot.questionType, marks: slot.marks, difficulty: slot.difficulty, freeRemaining },
  };
}

/**
 * Shared replay: walk the slots in plan order, carrying the solver's used-set,
 * and emit a reason per selected slot / gap. `selectedByIndex` is the
 * authoritative "what was chosen" from the already-solved paper; the walk
 * re-derives the eligibility counts around it. Pure.
 */
function walk(
  walkSlots: WalkSlot[],
  selectedByIndex: Map<number, QuestionBankItemRow>,
  bank: QuestionBankItemRow[],
): { selected: ItemSelectionReason[]; gaps: GapReason[] } {
  const usedIds = new Set<string>();
  const usedFingerprints = new Set<string>();
  const selected: ItemSelectionReason[] = [];
  const gaps: GapReason[] = [];

  for (const w of walkSlots) {
    const { slot } = w;
    const chosen = selectedByIndex.get(slot.index);

    if (chosen) {
      // Count the alternatives the solver had at pick time: eligible, unused,
      // non-duplicate items OTHER than the one it chose.
      let alternatives = 0;
      let duplicatesSkipped = 0;
      for (const item of bank) {
        if (item.id === chosen.id) continue;
        if (!w.matches(item)) continue;
        if (usedIds.has(item.id)) continue;
        if (usedFingerprints.has(itemFingerprint(item))) {
          duplicatesSkipped++;
          continue;
        }
        alternatives++;
      }

      selected.push({
        slotIndex: slot.index,
        ...(w.sectionCode !== undefined ? { sectionCode: w.sectionCode } : {}),
        chapter: slot.chapter,
        questionType: slot.questionType,
        marks: slot.marks,
        difficulty: slot.difficulty,
        bankItemId: chosen.id,
        satisfied: satisfiedFacts(chosen, w),
        selectionRule: chosen.chapter === slot.chapter
          ? "chapter_preferred"
          : "first_eligible_fallback",
        alternativesConsidered: alternatives,
        duplicatesSkipped,
      });

      usedIds.add(chosen.id);
      usedFingerprints.add(itemFingerprint(chosen));
    } else {
      gaps.push(diagnoseGap(w, bank, usedIds, usedFingerprints));
    }
  }

  return { selected, gaps };
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Explain a solved paper: per-selected-item reasons + per-gap diagnoses. Accepts
 * the SAME `spec` + `bank` handed to `solveBlueprint`, plus the `solution` it
 * returned. Deterministic and side-effect free — it re-reads, never re-selects.
 * Covers both the legacy flat plan and the CI-C1 template plan.
 */
export function explainSelection(
  spec: SolverSpec,
  bank: QuestionBankItemRow[],
  solution: BlueprintSolution,
): SelectionExplanation {
  if (solution.template) {
    const tpl = solution.template;
    const selectedByIndex = new Map<number, QuestionBankItemRow>(
      tpl.selected.map((s) => [s.slot.index, s.bankItem]),
    );
    const walkSlots: WalkSlot[] = tpl.slots.map((slot) => ({
      slot,
      sectionCode: slot.sectionCode,
      matches: (item: QuestionBankItemRow) => matchesSlotTemplate(item, slot),
      difficultyMode: slot.difficulty,
      hasCognitiveConstraint: Boolean(slot.cognitiveRequire || slot.cognitiveExclude),
      cognitiveFact: (item: QuestionBankItemRow) =>
        slot.cognitiveRequire
          ? `cognitive=${item.cognitive_level}`
          : slot.cognitiveExclude
          ? `cognitive_not_in=[${slot.cognitiveExclude.join(",")}]`
          : null,
    }));
    const { selected, gaps } = walk(walkSlots, selectedByIndex, bank);
    return { mode: "template", selected, gaps };
  }

  const selectedByIndex = new Map<number, QuestionBankItemRow>(
    solution.selected.map((s) => [s.slot.index, s.bankItem]),
  );
  const walkSlots: WalkSlot[] = solution.slots.map((slot) => ({
    slot,
    matches: (item: QuestionBankItemRow) => matchesSlot(item, slot, spec.difficulty),
    difficultyMode: spec.difficulty,
    hasCognitiveConstraint: false,
    cognitiveFact: () => null,
  }));
  const { selected, gaps } = walk(walkSlots, selectedByIndex, bank);
  return { mode: "legacy", selected, gaps };
}
