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
  EduCognitiveLevel,
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
  /**
   * CI-C1 (v3.0 §9.1): a governed blueprint template. When present, the request
   * CONFORMS to the template (sections / internal-choice pools / chapter-weightage
   * + cognitive & difficulty quotas as HARD constraints) instead of the flat,
   * request-computed plan. ADDITIVE + gated: when ABSENT the solver is
   * byte-identical to the certified path (invariant I1 / mitigation B1). Legacy
   * callers never set this. See `BlueprintTemplate` + `solveTemplateBlueprint`.
   */
  template?: BlueprintTemplate;
}

export interface SolvedSlot {
  slot: BlueprintSlot;
  bankItem: QuestionBankItemRow;
}

export interface BlueprintSolution {
  slots: BlueprintSlot[];
  selected: SolvedSlot[];
  gaps: BlueprintSlot[];
  /**
   * Present ONLY on the template path (CI-C1) — the section-aware solution +
   * constraint report. Undefined (absent key) on the legacy path, so the
   * certified `{ slots, selected, gaps }` shape is byte-unchanged (golden-stable).
   */
  template?: TemplateBlueprintSolution;
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
  // ── CI-C1 template seam (ADDITIVE, gated) ──────────────────────────────────
  // A governed blueprint template inverts the flow: the request CONFORMS to the
  // template — sections, internal-choice pools, chapter-weightage + cognitive &
  // difficulty quotas as HARD constraints — drawn from the FULL eligible bank
  // (no 100-item cap). Activates ONLY when `spec.template` is present. Every
  // legacy caller — and the golden — leaves it undefined and falls straight
  // through to the certified path below, BYTE-IDENTICALLY (invariant I1 / B1).
  if (spec.template) {
    const solved = solveTemplateBlueprint(spec.template, spec, bankItems);
    return {
      slots: solved.slots,
      selected: solved.selected,
      gaps: solved.gaps,
      template: solved,
    };
  }

  // ── Legacy certified path (UNCHANGED) ──────────────────────────────────────
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

// ═════════════════════════════════════════════════════════════════════════════
// CI-C1 — Template-aware solver (v3.0 §9.1 / §9.2), ADDITIVE + template-gated.
//
// A governed blueprint template makes a paper request CONFORM to a versioned
// structure instead of a flat, request-computed plan. The solver stays PURE and
// DETERMINISTIC (no Date / random / DB / network) — templates are INPUTS, never
// side effects (invariant I1). It activates only through `spec.template`; with no
// template the certified path above runs byte-identically (mitigation B1).
//
// Honoured as HARD constraints — a slot that cannot be filled WITHOUT violating
// the template fails HONESTLY into a gap (for the constrained-AI step to offer as
// a moderation candidate; never silently violated, invariants I3/I4):
//   • slot groups / sections (per-section question type + marks-per-question)
//   • internal-choice pools ("any {answer} of {pool}" — print pool, score answer)
//   • chapter weightage (explicit per-chapter scored-marks target)
//   • cognitive quotas (remember/understand cap, HOTS minimum)
//   • per-section / difficulty-curve difficulty
// Selection draws from the FULL eligible bank (removes the legacy 100-item cap —
// the caller passes the whole approved bank; the solver imposes no cap).
// ═════════════════════════════════════════════════════════════════════════════

/** One section of a governed blueprint template (v3.0 §9.1 `structure.sections`). */
export interface BlueprintTemplateSection {
  code: string;
  title?: string;
  questionType: EduQuestionType;
  marksPerQuestion: number;
  /** Number of questions the student must ANSWER (contributes to scored marks). */
  count: number;
  /** Fixed section difficulty; omit to derive from the template difficultyCurve. */
  difficulty?: Exclude<EduDifficulty, "mixed">;
  /** "any {answer} of {pool}" — pool ≥ answer questions printed, answer scored. */
  internalChoice?: { pool: number; answer: number };
  /** Cognitive-level quota, enforced as a hard constraint at selection. */
  cognitiveQuota?: {
    /** At most this % of the section's answered questions may be remember/understand. */
    remember_understand_max_pct?: number;
    /** At least this many answered questions must be HOTS. */
    hots_min_count?: number;
  };
}

/** A governed blueprint template (v3.0 §9.1 `structure` JSONB). */
export interface BlueprintTemplate {
  totalMarks: number;
  durationMinutes?: number;
  generalInstructions?: string[];
  sections: BlueprintTemplateSection[];
  /** Explicit per-chapter scored-marks target (hard constraint). */
  chapterWeightage?: { mode: "explicit"; marks: Record<string, number> };
  /** Whole-paper difficulty weights, applied when a section omits `difficulty`. */
  difficultyCurve?: Partial<Record<Exclude<EduDifficulty, "mixed">, number>>;
  /** CBSE-style competency mandate — carried through for reporting (Phase-2 enforces). */
  competencyQuota?: { competency_based_min_pct?: number };
}

/** A planned template slot: a BlueprintSlot plus section + choice/cognitive metadata. */
export interface TemplateSlot extends BlueprintSlot {
  sectionCode: string;
  /** true = scored slot (counts toward marks); false = extra internal-choice option. */
  scored: boolean;
  /** Slot must be filled by an item of exactly this cognitive level (hard). */
  cognitiveRequire?: EduCognitiveLevel;
  /** Slot must NOT be filled by an item of any of these cognitive levels (hard). */
  cognitiveExclude?: EduCognitiveLevel[];
}

export interface TemplateSolvedSlot {
  slot: TemplateSlot;
  bankItem: QuestionBankItemRow;
}

export interface TemplateSolvedSection {
  code: string;
  title?: string;
  questionType: EduQuestionType;
  marksPerQuestion: number;
  /** Questions to answer (scored). */
  answerCount: number;
  /** Questions to print (pool ≥ answerCount when internal choice is offered). */
  poolCount: number;
  /** answerCount × marksPerQuestion. */
  scoredMarks: number;
  slots: TemplateSlot[];
  selected: TemplateSolvedSlot[];
  gaps: TemplateSlot[];
}

export interface TemplateBlueprintSolution {
  totalMarks: number;
  durationMinutes?: number;
  generalInstructions: string[];
  sections: TemplateSolvedSection[];
  /** Flattened, in section + slot order. */
  slots: TemplateSlot[];
  selected: TemplateSolvedSlot[];
  gaps: TemplateSlot[];
  report: {
    scoredMarks: number;
    templateTotalMarks: number;
    /** scoredMarks === template.totalMarks (a well-formed template balances). */
    marksBalanced: boolean;
    chapterWeightage?: {
      target: Record<string, number>;
      planned: Record<string, number>;
      satisfied: boolean;
    };
    cognitive: Array<{
      sectionCode: string;
      hotsMin?: number;
      hotsSelected: number;
      rememberUnderstandMax?: number;
      rememberUnderstandSelected: number;
      satisfied: boolean;
    }>;
  };
}

const DIFFICULTY_ORDER: Array<Exclude<EduDifficulty, "mixed">> = ["easy", "medium", "hard"];
const RU_LEVELS: EduCognitiveLevel[] = ["remember", "understand"];

/** Split `count` items into buckets by non-negative weights (largest-remainder, deterministic). */
function allocateCount(count: number, weights: number[]): number[] {
  if (count <= 0) return weights.map(() => 0);
  const total = weights.reduce((a, b) => a + b, 0);
  if (total <= 0) {
    // No curve → put everything on 'medium' (index 1) to match the neutral default.
    return weights.map((_, i) => (i === 1 ? count : 0));
  }
  const raw = weights.map((w) => (w / total) * count);
  const result = raw.map((r) => Math.floor(r));
  let used = result.reduce((a, b) => a + b, 0);
  const order = raw
    .map((r, i) => ({ i, frac: r - Math.floor(r) }))
    .sort((a, b) => (b.frac - a.frac) || (a.i - b.i));
  let k = 0;
  while (used < count) {
    result[order[k % order.length]!.i]!++;
    used++;
    k++;
  }
  return result;
}

/** Deterministic per-section difficulty sequence for the scored slots. */
function sectionDifficulties(
  section: BlueprintTemplateSection,
  answerCount: number,
  curve?: BlueprintTemplate["difficultyCurve"],
): EduDifficulty[] {
  if (section.difficulty) {
    return Array.from({ length: answerCount }, () => section.difficulty!);
  }
  if (curve) {
    const weights = DIFFICULTY_ORDER.map((d) => curve[d] ?? 0);
    const alloc = allocateCount(answerCount, weights);
    const sequence: EduDifficulty[] = [];
    DIFFICULTY_ORDER.forEach((d, i) => {
      for (let j = 0; j < alloc[i]!; j++) sequence.push(d);
    });
    return sequence;
  }
  return Array.from({ length: answerCount }, () => "medium" as EduDifficulty);
}

interface PlannedSection {
  code: string;
  title?: string;
  questionType: EduQuestionType;
  marksPerQuestion: number;
  answerCount: number;
  poolCount: number;
  scoredMarks: number;
  slots: TemplateSlot[];
}

/**
 * Build the deterministic slot plan for a template: one PlannedSection per
 * template section with `poolCount` slots (the first `answerCount` scored), each
 * carrying its type, marks, difficulty and cognitive constraints. Chapters are
 * assigned across the whole plan to honour chapter weightage. Pure.
 */
export function planTemplateSlots(
  template: BlueprintTemplate,
  fallbackChapters: string[],
): { sections: PlannedSection[]; slots: TemplateSlot[] } {
  const sections: PlannedSection[] = [];
  let index = 0;

  for (const section of template.sections) {
    const answerCount = Math.max(0, section.internalChoice?.answer ?? section.count);
    const poolCount = Math.max(answerCount, section.internalChoice?.pool ?? answerCount);
    const mpq = section.marksPerQuestion;
    const difficulties = sectionDifficulties(section, answerCount, template.difficultyCurve);

    const cq = section.cognitiveQuota;
    const hotsMin = cq?.hots_min_count ?? 0;
    const ruMax = cq?.remember_understand_max_pct !== undefined
      ? Math.floor((answerCount * cq.remember_understand_max_pct) / 100)
      : undefined;
    const ruExcludeCount = ruMax !== undefined ? Math.max(0, answerCount - ruMax) : 0;

    const slots: TemplateSlot[] = [];
    for (let p = 0; p < poolCount; p++) {
      const scored = p < answerCount;
      const slot: TemplateSlot = {
        index: index++,
        sectionCode: section.code,
        questionType: section.questionType,
        marks: mpq,
        difficulty: scored ? (difficulties[p] ?? "medium") : (section.difficulty ?? "medium"),
        chapter: "General",
        scored,
      };
      if (scored) {
        // HOTS minimum → the first `hotsMin` scored slots MUST be HOTS.
        // Remember/Understand cap → the last `ruExcludeCount` scored slots MUST
        // NOT be R/U, so at most `ruMax` scored slots can be R/U. A HOTS-required
        // slot already satisfies the R/U exclusion, so the two never conflict.
        if (p < hotsMin) {
          slot.cognitiveRequire = "hots";
        } else if (p >= answerCount - ruExcludeCount) {
          slot.cognitiveExclude = [...RU_LEVELS];
        }
      }
      slots.push(slot);
    }

    sections.push({
      code: section.code,
      title: section.title,
      questionType: section.questionType,
      marksPerQuestion: mpq,
      answerCount,
      poolCount,
      scoredMarks: answerCount * mpq,
      slots,
    });
  }

  const allSlots = sections.flatMap((s) => s.slots);
  assignTemplateChapters(allSlots, template.chapterWeightage, fallbackChapters);
  return { sections, slots: allSlots };
}

/** Deterministically assign a chapter to every slot, honouring explicit weightage. */
function assignTemplateChapters(
  slots: TemplateSlot[],
  weightage: BlueprintTemplate["chapterWeightage"],
  fallbackChapters: string[],
): void {
  const fallback = fallbackChapters.length > 0 ? fallbackChapters : ["General"];

  if (!weightage || weightage.mode !== "explicit") {
    slots.forEach((slot, i) => {
      slot.chapter = fallback[i % fallback.length]!;
    });
    return;
  }

  const chapters = Object.keys(weightage.marks).sort();
  if (chapters.length === 0) {
    slots.forEach((slot, i) => {
      slot.chapter = fallback[i % fallback.length]!;
    });
    return;
  }

  const remaining: Record<string, number> = { ...weightage.marks };
  // Scored slots consume the weightage budget (largest-remaining-first, exact for
  // a well-formed template). Extra internal-choice slots don't count toward
  // weightage — assign them round-robin so they still carry a valid chapter.
  for (const slot of slots) {
    if (!slot.scored) continue;
    let best: string | null = null;
    for (const ch of chapters) {
      if ((remaining[ch] ?? 0) >= slot.marks) {
        if (best === null || remaining[ch]! > remaining[best]!) best = ch;
      }
    }
    if (best === null) {
      best = chapters.reduce(
        (a, b) => ((remaining[b] ?? 0) > (remaining[a] ?? 0) ? b : a),
        chapters[0]!,
      );
    }
    slot.chapter = best;
    remaining[best] = (remaining[best] ?? 0) - slot.marks;
  }
  let extra = 0;
  for (const slot of slots) {
    if (slot.scored) continue;
    slot.chapter = chapters[extra % chapters.length]!;
    extra++;
  }
}

/** Template-mode eligibility: the certified match + cognitive-quota constraints. */
function matchesSlotTemplate(item: QuestionBankItemRow, slot: TemplateSlot): boolean {
  if (item.status !== "active") return false;
  if (item.review_status !== "approved") return false;
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

/**
 * Solve a governed blueprint template bank-first over the FULL eligible bank.
 * Pure + deterministic given a stable `bankItems` order (caller sorts). For each
 * slot the first eligible, unused, non-duplicate item wins (preferring a chapter
 * match). Slots no such item can fill WITHOUT breaking the template become honest
 * gaps — never silently violated.
 */
export function solveTemplateBlueprint(
  template: BlueprintTemplate,
  spec: SolverSpec,
  bankItems: QuestionBankItemRow[],
): TemplateBlueprintSolution {
  const fallbackChapters = spec.chapters.length > 0 ? spec.chapters : ["General"];
  const planned = planTemplateSlots(template, fallbackChapters);

  const usedIds = new Set<string>();
  const usedFingerprints = new Set<string>();
  const sectionsOut: TemplateSolvedSection[] = [];
  const selectedAll: TemplateSolvedSlot[] = [];
  const gapsAll: TemplateSlot[] = [];

  for (const psec of planned.sections) {
    const selected: TemplateSolvedSlot[] = [];
    const gaps: TemplateSlot[] = [];
    for (const slot of psec.slots) {
      const eligible = bankItems.filter((item) =>
        !usedIds.has(item.id) &&
        !usedFingerprints.has(itemFingerprint(item)) &&
        matchesSlotTemplate(item, slot)
      );
      const chosen = eligible.find((item) => item.chapter === slot.chapter) ?? eligible[0];
      if (chosen) {
        usedIds.add(chosen.id);
        usedFingerprints.add(itemFingerprint(chosen));
        const solvedSlot: TemplateSolvedSlot = { slot, bankItem: chosen };
        selected.push(solvedSlot);
        selectedAll.push(solvedSlot);
      } else {
        gaps.push(slot);
        gapsAll.push(slot);
      }
    }
    sectionsOut.push({
      code: psec.code,
      title: psec.title,
      questionType: psec.questionType,
      marksPerQuestion: psec.marksPerQuestion,
      answerCount: psec.answerCount,
      poolCount: psec.poolCount,
      scoredMarks: psec.scoredMarks,
      slots: psec.slots,
      selected,
      gaps,
    });
  }

  // ── Constraint report ──────────────────────────────────────────────────────
  const scoredMarks = planned.slots
    .filter((s) => s.scored)
    .reduce((sum, s) => sum + s.marks, 0);

  let chapterWeightageReport: TemplateBlueprintSolution["report"]["chapterWeightage"];
  if (template.chapterWeightage?.mode === "explicit") {
    const target = template.chapterWeightage.marks;
    const planning: Record<string, number> = {};
    for (const ch of Object.keys(target)) planning[ch] = 0;
    for (const slot of planned.slots) {
      if (!slot.scored) continue;
      planning[slot.chapter] = (planning[slot.chapter] ?? 0) + slot.marks;
    }
    const keys = new Set([...Object.keys(target), ...Object.keys(planning)]);
    let satisfied = true;
    for (const k of keys) {
      if ((target[k] ?? 0) !== (planning[k] ?? 0)) satisfied = false;
    }
    chapterWeightageReport = { target: { ...target }, planned: planning, satisfied };
  }

  const cognitive = sectionsOut.map((sec) => {
    const templateSection = template.sections.find((s) => s.code === sec.code);
    const cq = templateSection?.cognitiveQuota;
    const hotsMin = cq?.hots_min_count;
    const ruMax = cq?.remember_understand_max_pct !== undefined
      ? Math.floor((sec.answerCount * cq.remember_understand_max_pct) / 100)
      : undefined;
    let hotsSelected = 0;
    let ruSelected = 0;
    for (const { slot, bankItem } of sec.selected) {
      if (!slot.scored) continue;
      if (bankItem.cognitive_level === "hots") hotsSelected++;
      if (bankItem.cognitive_level === "remember" || bankItem.cognitive_level === "understand") {
        ruSelected++;
      }
    }
    const satisfied = (hotsMin === undefined || hotsSelected >= hotsMin) &&
      (ruMax === undefined || ruSelected <= ruMax);
    return {
      sectionCode: sec.code,
      hotsMin,
      hotsSelected,
      rememberUnderstandMax: ruMax,
      rememberUnderstandSelected: ruSelected,
      satisfied,
    };
  });

  return {
    totalMarks: template.totalMarks,
    durationMinutes: template.durationMinutes,
    generalInstructions: template.generalInstructions ?? [],
    sections: sectionsOut,
    slots: planned.slots,
    selected: selectedAll,
    gaps: gapsAll,
    report: {
      scoredMarks,
      templateTotalMarks: template.totalMarks,
      marksBalanced: scoredMarks === template.totalMarks,
      chapterWeightage: chapterWeightageReport,
      cognitive,
    },
  };
}
