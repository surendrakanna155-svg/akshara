// CI-C3 — Multi-set papers (A/B/C, per-set keys) + structured JSON export (v2).
//
// Given a SOLVED paper (template or legacy), this module deterministically
// produces N ordered "sets" (default A/B/C). Each set is a variant ORDER of the
// SAME questions — reordered WITHIN each section (section boundaries are never
// crossed), with MCQ option order scrambled per set — and carries its OWN answer
// key, aligned to that set's question order (KEY SEPARATION). The first requested
// set (Set "A") is the canonical master: identity order, options untouched — so a
// single-set v2 export prints the paper exactly as solved.
//
// Determinism (invariant I1): the ordering + option scramble come from a pure,
// seeded PRNG — NO Date / Math.random / DB / network. Same input + same seed →
// byte-identical output. Bank-first, ZERO runtime AI (I3/I4): this module never
// authors or mutates question content; it only reorders already-approved items.
//
// ADDITIVE + DORMANT (like CI-C1): the legacy JSON export (`paperExportDocument`,
// format `akshara-education-pdf-v1`) is left byte-identical. v2 activates only
// when a caller opts in (e.g. `?format=v2` / `?sets=A,B,C` on the export route).
//
// Governance (I5): only human-approved items ever reach a set — `paperV2InputFrom
// Stored` filters to `review_status === "approved"` exactly as the certified v1
// export does (the AI-1 moderation gate). The pure `buildPaperDocumentV2` builder
// trusts its input, so it stays testable with any hand-authored fixture.

import type {
  QuestionPaperItemRow,
  QuestionPaperRow,
} from "./education_types.ts";

// ── Input shape (a normalized, section-aware solved paper) ───────────────────

/** One printable item fed into the v2 export (decoupled from any DB row). */
export interface PaperExportItem {
  /** Stable id linking back to the paper item (for cross-set traceability). */
  id?: string;
  questionType: string;
  marks: number;
  questionText: string;
  /** Free-form answer text (unchanged across sets — never invented here). */
  answerText: string;
  /** Choices, if any. Only MCQ options are scrambled per set. */
  options: string[];
}

/** One section of the solved paper (template sections, or a single flat group). */
export interface PaperExportSectionInput {
  code?: string;
  title?: string;
  /** Section-level rubric lines (e.g. "Attempt any 4 of the 6 questions."). */
  instructions?: string[];
  items: PaperExportItem[];
}

/** A normalized, board/exam-agnostic solved paper ready for multi-set export. */
export interface PaperExportInput {
  title: string;
  /** className / subjectName / examType / totalMarks / difficulty … (opaque). */
  meta: Record<string, unknown>;
  /** White-label branding surfaced on the printed sheet (PDF v2). */
  branding?: { schoolName?: string; logoText?: string };
  generalInstructions?: string[];
  durationMinutes?: number;
  sections: PaperExportSectionInput[];
}

// ── Output shape (the structured v2 document) ────────────────────────────────

/** A single printed question in a set. Note: NO answer here (key separation). */
export interface PaperSetQuestion {
  questionNumber: number;
  sectionCode?: string;
  /** Link back to the source paper item id (stable across sets). */
  sourceItemId?: string;
  questionType: string;
  marks: number;
  questionText: string;
  /** Options in THIS set's order (scrambled per set for MCQs). */
  options: string[];
}

/** One printed section in a set (questions in this set's within-section order). */
export interface PaperSetSection {
  code?: string;
  title?: string;
  instructions: string[];
  questions: PaperSetQuestion[];
}

/** One answer-key entry, aligned 1..N to THIS set's question order. */
export interface PaperSetAnswer {
  questionNumber: number;
  sectionCode?: string;
  answer: string;
  marks: number;
  /**
   * For an MCQ whose answer text is one of the (scrambled) options, the option
   * LETTER within this set's order ("A".."Z"). Absent when the answer is not a
   * verbatim option (e.g. short/long answer) — the `answer` text still stands.
   */
  answerOption?: string;
}

/** A complete paper set: printed sections + its SEPARATE answer key. */
export interface PaperSet {
  label: string;
  /** true only for the canonical master (Set "A"): identity order, no scramble. */
  master: boolean;
  sections: PaperSetSection[];
  /** The answer key — a distinct structure, never interleaved with questions. */
  answerKey: PaperSetAnswer[];
  /** Sum of marks over every printed question in the set. */
  totalMarks: number;
}

/** The structured v2 paper document (single- or multi-set). */
export interface PaperDocumentV2 {
  format: "akshara-education-paper-v2";
  title: string;
  meta: Record<string, unknown>;
  branding?: { schoolName?: string; logoText?: string };
  generalInstructions: string[];
  durationMinutes?: number;
  /** Section metadata (order + rubric), independent of any single set. */
  sections: Array<{
    code?: string;
    title?: string;
    instructions: string[];
    questionCount: number;
  }>;
  sets: PaperSet[];
  generatedAt: string;
}

/** Default set labels for a multi-set paper (A/B/C). */
export const DEFAULT_SET_LABELS = ["A", "B", "C"] as const;

const LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

// ── Deterministic PRNG (pure; no Date / Math.random) ─────────────────────────

/** FNV-1a 32-bit hash of a string — stable seed derivation. */
function fnv1a(input: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < input.length; i++) {
    hash ^= input.charCodeAt(i);
    // 32-bit FNV prime multiply via shifts (keeps everything in uint32).
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

/** mulberry32 — a tiny, well-distributed deterministic PRNG seeded by a uint32. */
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** Deterministic Fisher-Yates permutation of `0..n-1` from a string seed. */
function seededPermutation(n: number, seed: string): number[] {
  const order = Array.from({ length: n }, (_, i) => i);
  const rand = mulberry32(fnv1a(seed));
  for (let i = n - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    const tmp = order[i]!;
    order[i] = order[j]!;
    order[j] = tmp;
  }
  return order;
}

// ── The builder ──────────────────────────────────────────────────────────────

export interface BuildPaperDocumentV2Options {
  /** Set labels to emit (in order). First label is the master. Default A/B/C. */
  sets?: string[];
  /** Stable seed for the deterministic scramble (e.g. the paper id). */
  seed?: string;
  /** Injected timestamp so callers/tests control document determinism. */
  generatedAt?: string;
  /** Scramble MCQ option order on non-master sets (default true). */
  scrambleOptions?: boolean;
}

/**
 * Build the structured v2 document. Pure + deterministic: identical `input`,
 * `sets`, `seed` and `generatedAt` → byte-identical output. Set 0 is the master
 * (identity order); every later set gets a deterministic within-section shuffle
 * (+ MCQ option scramble) and its own realigned answer key.
 */
export function buildPaperDocumentV2(
  input: PaperExportInput,
  opts: BuildPaperDocumentV2Options = {},
): PaperDocumentV2 {
  const labels = (opts.sets && opts.sets.length > 0)
    ? opts.sets
    : [...DEFAULT_SET_LABELS];
  const seed = opts.seed ?? input.title;
  const scrambleOptions = opts.scrambleOptions !== false;
  const generatedAt = opts.generatedAt ?? new Date().toISOString();

  const sets: PaperSet[] = labels.map((label, setIndex) =>
    buildSet(input, {
      label,
      master: setIndex === 0,
      seed,
      scrambleOptions,
    })
  );

  return {
    format: "akshara-education-paper-v2",
    title: input.title,
    meta: input.meta,
    ...(input.branding ? { branding: input.branding } : {}),
    generalInstructions: input.generalInstructions ?? [],
    ...(input.durationMinutes !== undefined
      ? { durationMinutes: input.durationMinutes }
      : {}),
    sections: input.sections.map((s) => ({
      ...(s.code !== undefined ? { code: s.code } : {}),
      ...(s.title !== undefined ? { title: s.title } : {}),
      instructions: s.instructions ?? [],
      questionCount: s.items.length,
    })),
    sets,
    generatedAt,
  };
}

function buildSet(
  input: PaperExportInput,
  ctx: { label: string; master: boolean; seed: string; scrambleOptions: boolean },
): PaperSet {
  const sections: PaperSetSection[] = [];
  const answerKey: PaperSetAnswer[] = [];
  let questionNumber = 0;
  let totalMarks = 0;

  input.sections.forEach((section, sectionIndex) => {
    const sectionSeedBase = `${ctx.seed}|set:${ctx.label}|sec:${
      section.code ?? sectionIndex
    }`;
    // Master keeps the solved order; other sets shuffle WITHIN the section only.
    const order = ctx.master
      ? section.items.map((_, i) => i)
      : seededPermutation(section.items.length, sectionSeedBase);

    const questions: PaperSetQuestion[] = [];
    for (const srcIndex of order) {
      const item = section.items[srcIndex]!;
      questionNumber++;
      totalMarks += item.marks;

      const { options, answerOption } = arrangeOptions(item, {
        master: ctx.master,
        scramble: ctx.scrambleOptions,
        seed: `${sectionSeedBase}|q:${item.id ?? srcIndex}|opts`,
      });

      questions.push({
        questionNumber,
        ...(section.code !== undefined ? { sectionCode: section.code } : {}),
        ...(item.id !== undefined ? { sourceItemId: item.id } : {}),
        questionType: item.questionType,
        marks: item.marks,
        questionText: item.questionText,
        options,
      });

      answerKey.push({
        questionNumber,
        ...(section.code !== undefined ? { sectionCode: section.code } : {}),
        answer: item.answerText,
        marks: item.marks,
        ...(answerOption !== undefined ? { answerOption } : {}),
      });
    }

    sections.push({
      ...(section.code !== undefined ? { code: section.code } : {}),
      ...(section.title !== undefined ? { title: section.title } : {}),
      instructions: section.instructions ?? [],
      questions,
    });
  });

  return {
    label: ctx.label,
    master: ctx.master,
    sections,
    answerKey,
    totalMarks,
  };
}

/**
 * Arrange an item's options for a set and, for an MCQ whose answer text is a
 * verbatim option, compute the answer's LETTER in the arranged order. Only MCQ
 * options are scrambled (other types keep their order — e.g. match pairs). The
 * answer TEXT is never altered; the letter is derived purely for the key.
 */
function arrangeOptions(
  item: PaperExportItem,
  ctx: { master: boolean; scramble: boolean; seed: string },
): { options: string[]; answerOption?: string } {
  const options = item.options ?? [];
  const isMcq = item.questionType === "mcq" && options.length >= 2;

  const order = (isMcq && ctx.scramble && !ctx.master)
    ? seededPermutation(options.length, ctx.seed)
    : options.map((_, i) => i);
  const arranged = order.map((i) => options[i]!);

  let answerOption: string | undefined;
  if (isMcq) {
    const pos = arranged.indexOf(item.answerText);
    if (pos >= 0 && pos < LETTERS.length) answerOption = LETTERS[pos];
  }
  return { options: arranged, answerOption };
}

// ── Adapter: normalize a stored paper into the v2 input (dormant handler path) ─

/**
 * Build the v2 input from a stored paper + items. Enforces the AI-1 moderation
 * gate (approved items only) exactly like the certified `paperExportDocument`,
 * then emits ONE flat section (stored items carry no section metadata yet —
 * template-solved sections are a forward path). Instructions + duration are read
 * from the stored blueprint when present.
 */
export function paperV2InputFromStored(
  paper: QuestionPaperRow,
  items: QuestionPaperItemRow[],
  branding?: { schoolName?: string; logoText?: string },
): PaperExportInput {
  const printable = items.filter((item) => item.review_status === "approved");
  const blueprint = (paper.blueprint ?? {}) as Record<string, unknown>;
  const generalInstructions = Array.isArray(blueprint.generalInstructions)
    ? (blueprint.generalInstructions as unknown[]).filter(
      (x): x is string => typeof x === "string",
    )
    : [];
  const durationMinutes = typeof blueprint.durationMinutes === "number"
    ? blueprint.durationMinutes
    : undefined;

  return {
    title: paper.title,
    meta: {
      className: paper.class_name,
      sectionName: paper.section_name,
      subjectName: paper.subject_name,
      examType: paper.exam_type,
      totalMarks: paper.total_marks,
      difficulty: paper.difficulty,
    },
    ...(branding ? { branding } : {}),
    generalInstructions,
    ...(durationMinutes !== undefined ? { durationMinutes } : {}),
    sections: [
      {
        items: printable.map((item) => ({
          id: item.id,
          questionType: item.question_type,
          marks: item.marks,
          questionText: item.question_text,
          answerText: item.answer_text ?? "",
          options: Array.isArray(item.options) ? item.options as string[] : [],
        })),
      },
    ],
  };
}
