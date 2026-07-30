// EIP-6 Learning Evidence spine — the EIP-14 INTEGRATION CONTRACT.
//
// These are the stable, typed shapes the *next* layer (W5 Assessment
// Intelligence / EIP-7 concept mastery) consumes. The DB row shape
// (`EvidenceResponseRow`) is an implementation detail of the spine; this file is
// the seam every downstream consumer imports so a storage change never ripples
// past here. Pure types + pure mappers — no DB, no IO — so both the spine and
// its consumers can depend on it without a cycle.

/**
 * The learning-evidence lane. DISTINCT from the physical `capture_source`
 * (marks_grid_ocr / marks_grid_manual / digital_attempt / import): this is *what
 * kind of learning interaction* produced the evidence.
 */
export const EDU_EVIDENCE_SOURCES = ["practice", "homework", "exam", "omr"] as const;
export type EduEvidenceSource = typeof EDU_EVIDENCE_SOURCES[number];

export function isEvidenceSource(value: unknown): value is EduEvidenceSource {
  return typeof value === "string" &&
    (EDU_EVIDENCE_SOURCES as readonly string[]).includes(value);
}

/**
 * One recorded item interaction — the atomic unit of learning evidence.
 * APPEND-ONLY: once emitted it is never mutated. This is the contract W5/EIP-7
 * reads; field names are deliberately storage-independent.
 */
export interface LearningEvidenceRecord {
  id: string;
  studentId: string;
  /** The durable, concept-linked item identity (bank item). */
  itemId: string | null;
  /** Context the attempt happened in: exam id / homework id / practice session id. */
  contextRef: string;
  source: EduEvidenceSource;
  /** Monotonic per (student, item, source); attempt 1 = first try. */
  attemptNo: number;
  attempted: boolean;
  isCorrect: boolean | null;
  /** Marks awarded on this item (null when ungraded / skipped). */
  score: number | null;
  maxMarks: number;
  timeTakenMs: number | null;
  /** Self-reported confidence 0..100 (null when not collected). */
  confidence: number | null;
  hintsUsed: number;
  chosenOption: number | null;
  /** When the interaction happened (may precede when it was captured). */
  occurredAt: string | null;
  capturedAt: string | null;
}

/**
 * Per-item response aggregate — the item-analysis contract. Honest-empty:
 * `responseCount === 0` (all-zero) when the item has no evidence yet; consumers
 * must treat a zero-count aggregate as "no signal", never as "0% correct".
 */
export interface ItemResponseAggregate {
  itemId: string;
  responseCount: number;
  distinctStudents: number;
  attemptedCount: number;
  correctCount: number;
  incorrectCount: number;
  /** null (not 0) when there is no graded evidence — honest-empty. */
  correctnessRate: number | null;
  avgTimeTakenMs: number | null;
  avgScore: number | null;
  avgConfidence: number | null;
}

/**
 * Per-student, per-concept mastery/weakness roll-up SEED — the EIP-7 / W5
 * contract. A deterministic first-cut: mastery is the correctness rate over the
 * student's graded evidence for the concept. `conceptId` is nullable because the
 * canonical concept graph (20260859000000) is dormant today — until it is
 * populated the roll-up groups by the item's (subject, chapter, topic) so the
 * seam is useful NOW and gains concept precision for free once concepts land.
 */
export interface ConceptMasterySeed {
  conceptId: string | null;
  subjectName: string;
  chapter: string;
  topic: string;
  itemsAttempted: number;
  responseCount: number;
  correctCount: number;
  /** null (not 0) when no graded evidence exists for the concept — honest-empty. */
  masteryRate: number | null;
  avgConfidence: number | null;
  /** true only when there IS graded evidence and mastery is below the weakness line. */
  isWeakness: boolean;
}

/** Below this correctness rate, and with at least one graded response, a concept
 * is flagged a weakness by the seed roll-up. A deterministic, documented default;
 * W5 may re-weight downstream — this is a seed, not the final mastery model. */
export const CONCEPT_WEAKNESS_THRESHOLD = 0.5;

/**
 * Map a raw evidence row (storage shape) to the LearningEvidenceRecord contract.
 * The single place storage-column names cross into the downstream vocabulary.
 */
export function toLearningEvidenceContract(
  row: {
    id: string;
    student_id: string;
    bank_item_id: string | null;
    exam_id: string;
    evidence_source: string | null;
    attempt_no: number;
    attempted: boolean;
    is_correct: boolean | null;
    marks_awarded: number | string | null;
    max_marks: number | string;
    time_spent_ms: number | null;
    confidence: number | null;
    hints_used: number | null;
    chosen_option: number | null;
    occurred_at: string | null;
    captured_at: string | null;
  },
): LearningEvidenceRecord {
  return {
    id: row.id,
    studentId: row.student_id,
    itemId: row.bank_item_id,
    contextRef: row.exam_id,
    // A row read through this mapper is always an evidence-lane row (the reads
    // filter `evidence_source IS NOT NULL`); default defensively to 'practice'.
    source: isEvidenceSource(row.evidence_source) ? row.evidence_source : "practice",
    attemptNo: row.attempt_no,
    attempted: row.attempted,
    isCorrect: row.is_correct,
    score: row.marks_awarded == null ? null : Number(row.marks_awarded),
    maxMarks: Number(row.max_marks),
    timeTakenMs: row.time_spent_ms,
    confidence: row.confidence,
    hintsUsed: row.hints_used ?? 0,
    chosenOption: row.chosen_option,
    occurredAt: row.occurred_at,
    capturedAt: row.captured_at,
  };
}
