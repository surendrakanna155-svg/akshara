// Deterministic blueprint solver (Batch 8b).
//
// Replaces the old greedy "pick whatever fits then stub-fill the rest" path.
// Given a paper specification, it builds a fixed, reproducible slot plan whose
// marks sum EXACTLY to totalMarks, then fills each slot bank-first. Slots it
// cannot satisfy from the approved bank are reported as precise gaps (exact
// type / difficulty / marks / chapter) for the constrained AI step to offer as
// moderation candidates — never silently faked.
//
// Pure and side-effect free: no DB, no network, no randomness. Same inputs →
// same output, which is what makes it testable and auditable.

import { balanceDifficultyMix } from "./education_generator.ts";
import { computeQuestionFingerprint } from "./education_fingerprint.ts";
import type {
  EduDifficulty,
  EduQuestionType,
  QuestionBankItemRow,
} from "./education_types.ts";

export interface BlueprintSlot {
  index: number;
  questionType: EduQuestionType;
  difficulty: EduDifficulty;
  marks: number;
  chapter: string;
}

export interface SolverSpec {
  subjectName: string;
  totalMarks: number;
  difficulty: EduDifficulty;
  chapters: string[];
  questionTypeMix?: Partial<Record<EduQuestionType, number>>;
}

export interface SolvedSlot {
  slot: BlueprintSlot;
  bankItem: QuestionBankItemRow;
}

export interface BlueprintSolution {
  slots: BlueprintSlot[];
  selected: SolvedSlot[];
  gaps: BlueprintSlot[];
}

const DEFAULT_TYPE_MIX: EduQuestionType[] = [
  "mcq",
  "fill_blank",
  "short_answer",
  "long_answer",
];

function clamp(value: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, value));
}

/** Expand a question-type mix into a per-slot type sequence of `count` entries. */
function expandTypeSequence(
  count: number,
  mix?: Partial<Record<EduQuestionType, number>>,
): EduQuestionType[] {
  const entries = mix
    ? (Object.entries(mix) as Array<[EduQuestionType, number]>)
        .filter(([, n]) => typeof n === "number" && n > 0)
    : [];

  // Explicit counts provided → honour them (in declaration order), padded or
  // truncated to the slot count so the plan stays exactly `count` long.
  if (entries.length > 0) {
    const sequence: EduQuestionType[] = [];
    for (const [type, n] of entries) {
      for (let i = 0; i < n; i++) sequence.push(type);
    }
    if (sequence.length >= count) return sequence.slice(0, count);
    let i = 0;
    while (sequence.length < count) {
      sequence.push(entries[i % entries.length]![0]);
      i++;
    }
    return sequence;
  }

  // No mix → round-robin the default catalogue.
  return Array.from({ length: count }, (_, i) => DEFAULT_TYPE_MIX[i % DEFAULT_TYPE_MIX.length]!);
}

/** Distribute totalMarks across `count` slots so the per-slot marks sum exactly. */
function distributeMarks(totalMarks: number, count: number): number[] {
  const base = Math.floor(totalMarks / count);
  let remainder = totalMarks - base * count;
  const marks: number[] = [];
  for (let i = 0; i < count; i++) {
    const extra = remainder > 0 ? 1 : 0;
    marks.push(Math.max(1, base + extra));
    if (remainder > 0) remainder--;
  }
  // base could be 0 when count > totalMarks; the Math.max(1,...) above then
  // overshoots. Trim from the tail so the sum lands back on totalMarks.
  let sum = marks.reduce((a, b) => a + b, 0);
  for (let i = marks.length - 1; i >= 0 && sum > totalMarks; i--) {
    while (marks[i]! > 1 && sum > totalMarks) {
      marks[i]!--;
      sum--;
    }
  }
  return marks;
}

/**
 * Build the deterministic slot plan. The number of questions scales with
 * totalMarks (≈ one question per 5 marks, bounded 4–30) unless an explicit mix
 * pins the count.
 */
export function planSlots(spec: SolverSpec): BlueprintSlot[] {
  const explicitCount = spec.questionTypeMix
    ? (Object.values(spec.questionTypeMix) as number[])
        .filter((n) => typeof n === "number" && n > 0)
        .reduce((a, b) => a + b, 0)
    : 0;

  const count = explicitCount > 0
    ? clamp(explicitCount, 1, 60)
    : clamp(Math.ceil(spec.totalMarks / 5), 4, 30);

  const types = expandTypeSequence(count, spec.questionTypeMix);
  const marks = distributeMarks(spec.totalMarks, count);
  const difficulties = spec.difficulty === "mixed"
    ? balanceDifficultyMix(count)
    : Array.from({ length: count }, () => spec.difficulty);
  const chapters = spec.chapters.length > 0 ? spec.chapters : ["General"];

  return Array.from({ length: count }, (_, i) => ({
    index: i,
    questionType: types[i]!,
    difficulty: (difficulties[i] ?? "medium") as EduDifficulty,
    marks: marks[i]!,
    chapter: chapters[i % chapters.length]!,
  }));
}

/** True when a bank item is eligible: active, approved, exact type+marks match. */
function matchesSlot(
  item: QuestionBankItemRow,
  slot: BlueprintSlot,
  difficultyMode: EduDifficulty,
): boolean {
  if (item.status !== "active") return false;
  if (item.review_status !== "approved") return false;
  if (item.question_type !== slot.questionType) return false;
  if (item.marks !== slot.marks) return false;
  if (difficultyMode !== "mixed" && item.difficulty !== slot.difficulty) return false;
  return true;
}

function itemFingerprint(item: QuestionBankItemRow): string {
  return item.fingerprint ?? computeQuestionFingerprint({
    subjectName: item.subject_name,
    chapter: item.chapter,
    questionType: item.question_type,
    questionText: item.question_text,
  });
}

/**
 * Fill the plan bank-first. For each slot, the first eligible, not-yet-used,
 * non-duplicate bank item wins (preferring one whose chapter matches the slot's
 * assigned chapter). Unfilled slots become gaps. Deterministic given a stable
 * bankItems order (caller sorts).
 */
export function solveBlueprint(
  spec: SolverSpec,
  bankItems: QuestionBankItemRow[],
): BlueprintSolution {
  const slots = planSlots(spec);
  const usedIds = new Set<string>();
  const usedFingerprints = new Set<string>();
  const selected: SolvedSlot[] = [];
  const gaps: BlueprintSlot[] = [];

  for (const slot of slots) {
    const eligible = bankItems.filter((item) =>
      !usedIds.has(item.id) &&
      !usedFingerprints.has(itemFingerprint(item)) &&
      matchesSlot(item, slot, spec.difficulty)
    );

    const chosen = eligible.find((item) => item.chapter === slot.chapter) ?? eligible[0];

    if (chosen) {
      usedIds.add(chosen.id);
      usedFingerprints.add(itemFingerprint(chosen));
      selected.push({ slot, bankItem: chosen });
    } else {
      gaps.push(slot);
    }
  }

  return { slots, selected, gaps };
}
