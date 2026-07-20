// Smart OMR — the PURE scoring core (no DB, no IO, no clock, no randomness).
//
// Owner decision #8 (Smart OMR APPROVED — resolves D1). OMR is an ADDITIONAL
// capture path: the frozen Assessment Marks-Grid decision is untouched. This
// module scores a *bubble sheet's* marked options against a paper's answer key;
// the ingestion layer then emits the per-item verdict into the SAME EIP-6
// Learning Evidence spine (source:'omr') as every other lane.
//
// Deliberately pure so every scoring rule — all-correct, all-wrong, blanks,
// ambiguous multi-marks, unscoreable questions, and key/sheet mismatches — is
// exhaustively unit-testable with zero infrastructure.
//
// HONESTY CONTRACT (never fabricate a score):
//   • An unanswered bubble is BLANK — ungraded (isCorrect null, 0 marks), never
//     counted wrong-by-default UNLESS the blank policy explicitly says 'wrong'.
//   • An ambiguous multi-mark is never silently resolved to a guess: it is
//     treated as blank / wrong per policy, or the whole sheet is rejected.
//   • A question with no resolvable answer key is 'unscored' (excluded from the
//     max attainable), never assumed correct or wrong.
//   • The physical mark STATE (outcome) is kept orthogonal to the graded VERDICT
//     (isCorrect / awarded), so a policy can never hide *why* a mark scored 0.

export type OmrBlankPolicy = "blank" | "wrong";
export type OmrMultiMarkPolicy = "blank" | "wrong" | "reject";

export interface OmrScoringPolicy {
  /**
   * A question with no bubble filled.
   *   'blank' (default): ungraded — 0 marks, isCorrect null. NOT counted wrong.
   *   'wrong'          : scored as an incorrect answer — 0 marks, isCorrect false.
   */
  blank: OmrBlankPolicy;
  /**
   * A question with MORE THAN ONE bubble filled (ambiguous).
   *   'blank' (default): treated as unanswered — 0 marks, isCorrect null.
   *   'wrong'          : scored incorrect — 0 marks, isCorrect false.
   *   'reject'         : the whole sheet is refused (throws) — no silent guess.
   */
  multiMark: OmrMultiMarkPolicy;
}

/** Conservative, honest defaults: a blank/ambiguous mark is never a wrong answer. */
export const DEFAULT_OMR_POLICY: OmrScoringPolicy = {
  blank: "blank",
  multiMark: "blank",
};

/** One question as read off the physical sheet. */
export interface OmrSheetMark {
  questionNo: number;
  /**
   * 1-based option bubbles detected as filled for this question.
   *   []          → blank (unanswered)
   *   [x]         → a single clean mark
   *   [x, y, …]   → ambiguous multi-mark
   */
  marked: number[];
}

/** One answer-key entry, resolved from the paper (see omr_repository). */
export interface OmrAnswerKeyEntry {
  questionNo: number;
  /**
   * 1-based correct option, or null when the question has no scoreable key
   * (non-MCQ, or an answer that is not a verbatim option). A null key ⇒ the
   * question is 'unscored' — never guessed, never held against the student.
   */
  correctOption: number | null;
  marks: number;
  /** Durable bank-item identity for EIP-6 evidence emission (null when unlinked). */
  bankItemId?: string | null;
}

/** The physical mark STATE of a question (independent of the grading policy). */
export type OmrOutcome =
  | "correct" // single mark equal to the key
  | "incorrect" // single mark different from the key
  | "blank" // no bubble filled
  | "ambiguous" // more than one bubble filled
  | "unscored"; // no resolvable answer key for the question

export interface OmrQuestionResult {
  questionNo: number;
  marked: number[];
  correctOption: number | null;
  /** The physical mark state (why it scored what it did). */
  outcome: OmrOutcome;
  /** Marks awarded for this question under the active policy. */
  awarded: number;
  /** Max attainable on this question (0 when unscoreable). */
  maxMarks: number;
  /**
   * The graded verdict for EIP-6 evidence: true / false, or null when the
   * question is ungraded (blank-as-blank / ambiguous-as-blank / unscored).
   */
  isCorrect: boolean | null;
  /** Whether the student physically filled at least one bubble. */
  attempted: boolean;
  /** The single chosen option for evidence (null when blank / ambiguous). */
  chosenOption: number | null;
  bankItemId: string | null;
}

export interface OmrScoreResult {
  perQuestion: OmrQuestionResult[];
  totalScore: number;
  /**
   * Max attainable over SCOREABLE questions only (unscored questions are
   * excluded — you cannot hold a question you could not key against a student).
   */
  maxScore: number;
  correctCount: number;
  incorrectCount: number;
  blankCount: number;
  ambiguousCount: number;
  unscoredCount: number;
  /** Questions with at least one bubble filled (single + ambiguous). */
  answeredCount: number;
}

/** Thrown on a malformed sheet / key so a caller maps it to 422 — never a 500
 * and never a silent mis-score. */
export class OmrScoringError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "OmrScoringError";
  }
}

/** Validate + de-duplicate the marked bubbles for one question. */
function normalizeMarked(marked: number[], questionNo: number): number[] {
  if (!Array.isArray(marked)) {
    throw new OmrScoringError(
      `question ${questionNo}: marked must be an array of option numbers`,
    );
  }
  const seen = new Set<number>();
  for (const opt of marked) {
    if (!Number.isInteger(opt) || opt < 1) {
      throw new OmrScoringError(
        `question ${questionNo}: marked option ${
          String(opt)
        } must be a positive integer (1-based)`,
      );
    }
    seen.add(opt); // a doubly-detected same bubble is one mark, not an ambiguity.
  }
  return [...seen].sort((a, b) => a - b);
}

/**
 * Score a scanned OMR sheet against a paper's answer key. PURE + deterministic:
 * identical inputs → identical output. The answer key defines the exam — the
 * sheet is scored question-by-question over the key, in questionNo order.
 *
 * Guards (each throws OmrScoringError, never a silent mis-score):
 *   • empty answer key;
 *   • an invalid / duplicate questionNo in the key or the sheet;
 *   • non-positive marks or an invalid correctOption in the key;
 *   • a sheet marking a question that is NOT in the key (key/sheet mismatch);
 *   • a non-integer / non-positive marked bubble;
 *   • an ambiguous multi-mark when multiMark policy is 'reject'.
 */
export function scoreOmrSheet(
  sheet: OmrSheetMark[],
  answerKey: OmrAnswerKeyEntry[],
  policy: OmrScoringPolicy = DEFAULT_OMR_POLICY,
): OmrScoreResult {
  if (answerKey.length === 0) {
    throw new OmrScoringError("answer key is empty — nothing to score against");
  }

  // ── Index + validate the answer key ──────────────────────────────────────
  const keyByQ = new Map<number, OmrAnswerKeyEntry>();
  for (const k of answerKey) {
    if (!Number.isInteger(k.questionNo) || k.questionNo < 1) {
      throw new OmrScoringError(
        `answer key has an invalid questionNo: ${String(k.questionNo)}`,
      );
    }
    if (keyByQ.has(k.questionNo)) {
      throw new OmrScoringError(
        `answer key has a duplicate entry for question ${k.questionNo}`,
      );
    }
    if (!Number.isFinite(k.marks) || k.marks <= 0) {
      throw new OmrScoringError(
        `answer key question ${k.questionNo} has non-positive marks`,
      );
    }
    if (
      k.correctOption !== null &&
      (!Number.isInteger(k.correctOption) || k.correctOption < 1)
    ) {
      throw new OmrScoringError(
        `answer key question ${k.questionNo} has an invalid correctOption`,
      );
    }
    keyByQ.set(k.questionNo, k);
  }

  // ── Index the sheet; enforce the KEY/SHEET MISMATCH guard ─────────────────
  const sheetByQ = new Map<number, number[]>();
  for (const m of sheet) {
    if (!Number.isInteger(m.questionNo) || m.questionNo < 1) {
      throw new OmrScoringError(
        `sheet has an invalid questionNo: ${String(m.questionNo)}`,
      );
    }
    if (sheetByQ.has(m.questionNo)) {
      throw new OmrScoringError(
        `sheet has a duplicate marked entry for question ${m.questionNo}`,
      );
    }
    if (!keyByQ.has(m.questionNo)) {
      throw new OmrScoringError(
        `sheet marks question ${m.questionNo}, which is not in the answer key (key/sheet mismatch)`,
      );
    }
    sheetByQ.set(m.questionNo, normalizeMarked(m.marked, m.questionNo));
  }

  const perQuestion: OmrQuestionResult[] = [];
  let totalScore = 0;
  let maxScore = 0;
  let correctCount = 0;
  let incorrectCount = 0;
  let blankCount = 0;
  let ambiguousCount = 0;
  let unscoredCount = 0;
  let answeredCount = 0;

  // Iterate the KEY in questionNo order — the key, not the sheet, defines the exam.
  const orderedQs = [...keyByQ.keys()].sort((a, b) => a - b);
  for (const q of orderedQs) {
    const key = keyByQ.get(q)!;
    const marked = sheetByQ.get(q) ?? [];
    const attempted = marked.length > 0;
    if (attempted) answeredCount += 1;

    const scoreable = key.correctOption !== null;
    if (scoreable) maxScore += key.marks;

    let outcome: OmrOutcome;
    let awarded = 0;
    let isCorrect: boolean | null;
    let chosenOption: number | null;

    if (!scoreable) {
      // No key for this question — we cannot grade it. Never guess.
      outcome = "unscored";
      isCorrect = null;
      chosenOption = marked.length === 1 ? marked[0]! : null;
      unscoredCount += 1;
    } else if (marked.length === 0) {
      // BLANK — the state is 'blank'; the verdict follows the blank policy.
      outcome = "blank";
      blankCount += 1;
      chosenOption = null;
      isCorrect = policy.blank === "wrong" ? false : null;
    } else if (marked.length > 1) {
      // AMBIGUOUS — never silently resolved to a guess.
      if (policy.multiMark === "reject") {
        throw new OmrScoringError(
          `question ${q} has ${marked.length} bubbles filled (ambiguous); multiMark policy is 'reject'`,
        );
      }
      outcome = "ambiguous";
      ambiguousCount += 1;
      chosenOption = null;
      isCorrect = policy.multiMark === "wrong" ? false : null;
    } else {
      // A single clean mark — the only path that can award marks.
      chosenOption = marked[0]!;
      if (chosenOption === key.correctOption) {
        outcome = "correct";
        isCorrect = true;
        awarded = key.marks;
        correctCount += 1;
      } else {
        outcome = "incorrect";
        isCorrect = false;
        incorrectCount += 1;
      }
    }

    totalScore += awarded;
    perQuestion.push({
      questionNo: q,
      marked,
      correctOption: key.correctOption,
      outcome,
      awarded,
      maxMarks: scoreable ? key.marks : 0,
      isCorrect,
      attempted,
      chosenOption,
      bankItemId: key.bankItemId ?? null,
    });
  }

  return {
    perQuestion,
    totalScore,
    maxScore,
    correctCount,
    incorrectCount,
    blankCount,
    ambiguousCount,
    unscoredCount,
    answeredCount,
  };
}
