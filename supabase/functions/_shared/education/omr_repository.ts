// Smart OMR — repository: resolve the answer key, persist a scan, EMIT EIP-6
// evidence, and read item-analysis. This is the layer that turns a scanned bubble
// sheet into governed learning evidence + Assessment-Intelligence stats.
//
// Owner decisions #8 (Smart OMR — resolves D1) + #15 (Assessment Intelligence).
//
// Two seams it deliberately reuses rather than reinventing:
//   • recordItemResponse (EIP-6 spine) — OMR does NOT keep a parallel per-item
//     store; every scored MCQ becomes one idempotent evidence row (source:'omr').
//   • getItemResponseAggregate (EIP-6 spine) — item difficulty is read straight
//     off the spine, honest-null when there is no graded evidence.
//
// The frozen marks-grid (exam_mark_entries) and the certified evidence spine are
// untouched: this file only adds a new store (edu_omr_scan_results) and new reads.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  getItemResponseAggregate,
  type ItemResponseAggregate,
  nextAttemptNo,
  recordItemResponse,
} from "./learning_evidence_repository.ts";
import {
  DEFAULT_OMR_POLICY,
  type OmrAnswerKeyEntry,
  type OmrScoreResult,
  OmrScoringError,
  type OmrScoringPolicy,
  type OmrSheetMark,
  scoreOmrSheet,
} from "./omr_scoring.ts";

/** Below this many distinct graded students, a discrimination index is not
 * computed — it would be statistical noise. Returned as null (honest), never a
 * fabricated number. A documented default; downstream may re-weight. */
export const MIN_COHORT_FOR_DISCRIMINATION = 4;

/** The high/low fraction for the classic discrimination index (Kelley 27%). */
const DISCRIMINATION_GROUP_FRACTION = 0.27;

/** Thrown on a malformed OMR ingestion; handlers map it to 422 (not 500). */
export class OmrIngestionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "OmrIngestionError";
  }
}

/** Storage row of edu_omr_scan_results. */
export interface OmrScanResultRow {
  id: string;
  organization_id: string;
  school_id: string;
  exam_id: string;
  paper_id: string;
  student_id: string;
  set_label: string | null;
  marked_options: unknown;
  total_score: number | string;
  max_score: number | string;
  correct_count: number;
  incorrect_count: number;
  blank_count: number;
  ambiguous_count: number;
  unscored_count: number;
  blank_policy: string;
  multi_mark_policy: string;
  scanned_by: string | null;
  scored_at: string | null;
  created_at: string | null;
}

/** A paper item, as needed to resolve the OMR answer key. */
interface PaperItemKeyRow {
  id: string;
  bank_item_id: string | null;
  question_type: string;
  marks: number;
  question_text: string;
  answer_text: string | null;
  options: unknown;
  sort_order: number;
}

/**
 * Resolve a paper's OMR answer key from its APPROVED items, in the printed
 * (canonical / master-set) order. For an MCQ, the correct option is the 1-based
 * index of `answer_text` within `options` (matching the paper-export answer key).
 * A non-MCQ, or an answer that is not a verbatim option, yields `correctOption:
 * null` — the question is UNSCORED, never guessed.
 */
export async function resolvePaperOmrAnswerKey(
  client: TenantQueryClient,
  paperId: string,
): Promise<OmrAnswerKeyEntry[]> {
  const items = await client.queryObject<PaperItemKeyRow>(
    `SELECT id, bank_item_id, question_type, marks, question_text, answer_text, options, sort_order
       FROM edu_question_paper_items
      WHERE paper_id = $1 AND review_status = 'approved'
      ORDER BY sort_order ASC, id ASC`,
    [paperId],
  );
  return items.map((item, index) => ({
    questionNo: index + 1,
    correctOption: resolveCorrectOption(item),
    marks: item.marks,
    bankItemId: item.bank_item_id,
  }));
}

/** 1-based correct option, or null when the item cannot be OMR-keyed. */
function resolveCorrectOption(item: PaperItemKeyRow): number | null {
  if (item.question_type !== "mcq") return null;
  const options = Array.isArray(item.options) ? item.options : [];
  if (options.length < 2) return null;
  if (typeof item.answer_text !== "string") return null;
  const idx = options.findIndex((o) => o === item.answer_text);
  return idx >= 0 ? idx + 1 : null; // null: answer not a verbatim option → unscored
}

export interface IngestOmrScanInput {
  /** ERP exam context (contextRef in the evidence spine). */
  examId: string;
  /** The paper whose answer key the sheet is scored against. */
  paperId: string;
  studentId: string;
  /** Informational provenance (A/B/C…); scoring targets the canonical order. */
  setLabel?: string | null;
  /** The scanned sheet: per-question marked bubbles. */
  markedOptions: OmrSheetMark[];
  policy?: OmrScoringPolicy;
  /** ISO timestamp the exam happened (distinct from when it was scanned). */
  occurredAt?: string | null;
  /** The staff user who scanned/ingested the sheet. */
  scannedBy?: string | null;
}

export interface IngestOmrScanResult {
  scan: OmrScanResultRow;
  score: OmrScoreResult;
  /** false when a scan for this (exam, paper, student) was already on record. */
  created: boolean;
  /** Count of NEW EIP-6 evidence rows emitted (0 on an idempotent replay). */
  evidenceEmitted: number;
}

function validateIngest(input: IngestOmrScanInput): void {
  const req = (v: string | undefined | null, name: string) => {
    if (!v || !String(v).trim()) {
      throw new OmrIngestionError(`${name} is required to ingest an OMR scan`);
    }
  };
  req(input.examId, "examId");
  req(input.paperId, "paperId");
  req(input.studentId, "studentId");
  if (!Array.isArray(input.markedOptions)) {
    throw new OmrIngestionError(
      "markedOptions must be an array of { questionNo, marked }",
    );
  }
}

async function findExistingScan(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  examId: string,
  paperId: string,
  studentId: string,
): Promise<OmrScanResultRow | null> {
  const rows = await client.queryObject<OmrScanResultRow>(
    `SELECT * FROM edu_omr_scan_results
      WHERE organization_id = $1 AND school_id = $2
        AND exam_id = $3 AND paper_id = $4 AND student_id = $5
      LIMIT 1`,
    [organizationId, schoolId, examId, paperId, studentId],
  );
  return rows[0] ?? null;
}

/** Parse the stored marked_options JSONB back into typed sheet marks. */
function parseStoredMarks(value: unknown): OmrSheetMark[] {
  const raw = typeof value === "string" ? JSON.parse(value) : value;
  if (!Array.isArray(raw)) return [];
  return raw.map((m) => ({
    questionNo: Number((m as OmrSheetMark).questionNo),
    marked: Array.isArray((m as OmrSheetMark).marked)
      ? (m as OmrSheetMark).marked.map(Number)
      : [],
  }));
}

/**
 * Ingest a scanned OMR sheet: score it against the paper's answer key, persist
 * the result snapshot, and EMIT one EIP-6 evidence row per scoreable MCQ item
 * (source:'omr'). Idempotent per (org, school, exam, paper, student): a re-post
 * returns the existing scan (re-scored deterministically from the stored marks)
 * and emits NOTHING — a retried scan never double-counts.
 *
 * Only SCOREABLE (keyed) questions with a bank_item_id become evidence: an
 * unscored question has no verdict, so it is never recorded as a graded OMR
 * response. Blanks ARE recorded (attempted:false, ungraded) so item-analysis
 * sees the full population.
 */
export async function ingestOmrScan(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: IngestOmrScanInput,
): Promise<IngestOmrScanResult> {
  validateIngest(input);
  const policy = input.policy ?? DEFAULT_OMR_POLICY;

  const answerKey = await resolvePaperOmrAnswerKey(client, input.paperId);
  if (answerKey.length === 0) {
    throw new OmrIngestionError(
      `paper ${input.paperId} has no approved questions to score against`,
    );
  }

  // Pure scoring — a malformed sheet/key throws OmrScoringError; surface it as 422.
  const scoreSheet = (
    marks: OmrSheetMark[],
    pol: OmrScoringPolicy,
  ): OmrScoreResult => {
    try {
      return scoreOmrSheet(marks, answerKey, pol);
    } catch (err) {
      if (err instanceof OmrScoringError) {
        throw new OmrIngestionError(err.message);
      }
      throw err;
    }
  };

  // Idempotency: a scan already on record wins — re-score the STORED marks so the
  // returned result reflects what was persisted, and emit nothing.
  const existing = await findExistingScan(
    client,
    organizationId,
    schoolId,
    input.examId,
    input.paperId,
    input.studentId,
  );
  if (existing) {
    const storedPolicy: OmrScoringPolicy = {
      blank: existing.blank_policy === "wrong" ? "wrong" : "blank",
      multiMark: existing.multi_mark_policy === "wrong"
        ? "wrong"
        : existing.multi_mark_policy === "reject"
        ? "reject"
        : "blank",
    };
    const score = scoreSheet(
      parseStoredMarks(existing.marked_options),
      storedPolicy,
    );
    return { scan: existing, score, created: false, evidenceEmitted: 0 };
  }

  const score = scoreSheet(input.markedOptions, policy);

  const scanRows = await client.queryObject<OmrScanResultRow>(
    `INSERT INTO edu_omr_scan_results (
       organization_id, school_id, exam_id, paper_id, student_id, set_label,
       marked_options, total_score, max_score, correct_count, incorrect_count,
       blank_count, ambiguous_count, unscored_count, blank_policy, multi_mark_policy,
       scanned_by, scored_at
     ) VALUES (
       $1, $2, $3, $4, $5, $6,
       $7::jsonb, $8, $9, $10, $11,
       $12, $13, $14, $15, $16,
       $17, now()
     )
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.examId,
      input.paperId,
      input.studentId,
      input.setLabel ?? null,
      JSON.stringify(input.markedOptions),
      score.totalScore,
      score.maxScore,
      score.correctCount,
      score.incorrectCount,
      score.blankCount,
      score.ambiguousCount,
      score.unscoredCount,
      policy.blank,
      policy.multiMark,
      input.scannedBy ?? null,
    ],
  );
  const scan = scanRows[0]!;

  // Emit EIP-6 evidence: one idempotent row per scoreable, bank-linked question.
  let evidenceEmitted = 0;
  for (const q of score.perQuestion) {
    if (!q.bankItemId) continue; // no durable item identity → cannot land in the spine
    if (q.correctOption === null) continue; // unscored — no verdict to record

    // A monotonic attempt per (student, item, 'omr'): re-answering the SAME bank
    // item in a DIFFERENT exam is a NEW attempt, not an idempotent collision (the
    // spine's idempotency key does not include exam context). The scan-level
    // idempotency above guarantees this loop runs at most once per scan.
    const attemptNo = await nextAttemptNo(
      client,
      input.studentId,
      q.bankItemId,
      "omr",
    );

    const result = await recordItemResponse(client, organizationId, schoolId, {
      studentId: input.studentId,
      itemId: q.bankItemId,
      source: "omr",
      contextRef: input.examId,
      maxMarks: q.maxMarks,
      attemptNo,
      attempted: q.attempted,
      isCorrect: q.isCorrect,
      // Ungraded (blank) rows carry no score; graded rows carry the awarded marks.
      marksAwarded: q.isCorrect === null ? null : q.awarded,
      chosenOption: q.chosenOption,
      occurredAt: input.occurredAt,
      capturedBy: input.scannedBy,
      // captureSource derives to 'marks_grid_ocr' for the 'omr' lane.
    });
    if (result.created) evidenceEmitted += 1;
  }

  return { scan, score, created: true, evidenceEmitted };
}

// ── Item analysis (Assessment Intelligence, owner #15) ───────────────────────

export interface OmrItemStat {
  questionNo: number;
  bankItemId: string | null;
  questionText: string;
  marks: number;
  responseCount: number;
  distinctStudents: number;
  correctCount: number;
  incorrectCount: number;
  /** Proportion correct (item difficulty). null = no graded evidence — honest. */
  difficulty: number | null;
  /** Classic high/low discrimination index in [-1, 1]. null when the cohort is
   * below MIN_COHORT_FOR_DISCRIMINATION (not enough signal) — never fabricated. */
  discrimination: number | null;
}

export interface OmrPaperItemAnalysis {
  paperId: string;
  itemCount: number;
  /** Items that have at least one graded response. */
  itemsWithEvidence: number;
  /** Distinct students with graded evidence on this paper. */
  cohortSize: number;
  /** false when cohortSize < MIN_COHORT_FOR_DISCRIMINATION (discrimination all-null). */
  discriminationComputed: boolean;
  /** Mean difficulty over items that HAVE a difficulty; null when none do. */
  avgDifficulty: number | null;
  /** The per-question heatmap (paper order). */
  items: OmrItemStat[];
}

interface GradedEvidenceRow {
  student_id: string;
  bank_item_id: string;
  is_correct: boolean | null;
}

/**
 * Per-item difficulty + discrimination + question heatmap for a paper — the
 * Assessment-Intelligence read over EIP-6 evidence. Difficulty is read via the
 * spine's own getItemResponseAggregate (reused, not reimplemented); discrimination
 * is the classic top/bottom-27% index over this paper's cohort.
 *
 * HONESTY: difficulty is null for an item with no graded evidence; discrimination
 * is null for the whole paper when the cohort is too small to be meaningful. An
 * empty paper (no evidence) returns real zeros + all-null stats — never invented.
 */
export async function getPaperItemAnalysis(
  client: TenantQueryClient,
  paperId: string,
  opts: { source?: "omr" | "exam" | "homework" | "practice" } = {},
): Promise<OmrPaperItemAnalysis> {
  const source = opts.source ?? "omr";

  const itemRows = await client.queryObject<PaperItemKeyRow>(
    `SELECT id, bank_item_id, question_type, marks, question_text, answer_text, options, sort_order
       FROM edu_question_paper_items
      WHERE paper_id = $1 AND review_status = 'approved'
      ORDER BY sort_order ASC, id ASC`,
    [paperId],
  );

  const bankItemIds = itemRows
    .map((r) => r.bank_item_id)
    .filter((x): x is string => !!x);

  // ── Discrimination cohort: all graded evidence for this paper's items ──
  const graded: GradedEvidenceRow[] = bankItemIds.length === 0 ? [] : (
    await client.queryObject<GradedEvidenceRow>(
      `SELECT student_id, bank_item_id, is_correct
         FROM edu_student_item_responses
        WHERE bank_item_id = ANY($1::uuid[])
          AND evidence_source = $2
          AND is_correct IS NOT NULL`,
      [bankItemIds, source],
    )
  );

  const discrimination = computeDiscrimination(graded, bankItemIds);

  // ── Per-item difficulty via the spine's reused aggregate ──
  const aggregates = new Map<string, ItemResponseAggregate>();
  for (const id of new Set(bankItemIds)) {
    aggregates.set(id, await getItemResponseAggregate(client, id, { source }));
  }

  const items: OmrItemStat[] = itemRows.map((row, index) => {
    const bankItemId = row.bank_item_id;
    const agg = bankItemId ? aggregates.get(bankItemId) : undefined;
    return {
      questionNo: index + 1,
      bankItemId,
      questionText: row.question_text,
      marks: row.marks,
      responseCount: agg?.responseCount ?? 0,
      distinctStudents: agg?.distinctStudents ?? 0,
      correctCount: agg?.correctCount ?? 0,
      incorrectCount: agg?.incorrectCount ?? 0,
      difficulty: agg?.correctnessRate ?? null,
      discrimination: bankItemId
        ? (discrimination.byItem.get(bankItemId) ?? null)
        : null,
    };
  });

  const difficulties = items
    .map((i) => i.difficulty)
    .filter((d): d is number => d !== null);

  return {
    paperId,
    itemCount: items.length,
    itemsWithEvidence: items.filter((i) => i.responseCount > 0).length,
    cohortSize: discrimination.cohortSize,
    discriminationComputed: discrimination.computed,
    avgDifficulty: difficulties.length === 0
      ? null
      : difficulties.reduce((a, b) => a + b, 0) / difficulties.length,
    items,
  };
}

/**
 * Classic discrimination index D per item: (proportion correct in the top group)
 * minus (proportion correct in the bottom group), with high/low groups of the top
 * and bottom 27% of students by total correct. Deterministic tie-break by student
 * id. Returns all-null (computed:false) when the cohort is below the minimum.
 */
function computeDiscrimination(
  graded: GradedEvidenceRow[],
  bankItemIds: string[],
): { byItem: Map<string, number>; cohortSize: number; computed: boolean } {
  const byItem = new Map<string, number>();

  // Per (student, item): correct if ANY graded response for that item is correct.
  const studentItems = new Map<string, Map<string, boolean>>();
  for (const row of graded) {
    let items = studentItems.get(row.student_id);
    if (!items) {
      items = new Map<string, boolean>();
      studentItems.set(row.student_id, items);
    }
    const prev = items.get(row.bank_item_id) ?? false;
    items.set(row.bank_item_id, prev || row.is_correct === true);
  }

  const students = [...studentItems.keys()];
  const cohortSize = students.length;
  if (cohortSize < MIN_COHORT_FOR_DISCRIMINATION) {
    return { byItem, cohortSize, computed: false };
  }

  // Rank by total correct desc; deterministic tie-break on student id.
  const totalCorrect = (s: string) => {
    let n = 0;
    for (const ok of studentItems.get(s)!.values()) if (ok) n += 1;
    return n;
  };
  const ranked = [...students].sort((a, b) => {
    const d = totalCorrect(b) - totalCorrect(a);
    return d !== 0 ? d : a.localeCompare(b);
  });

  const groupSize = Math.max(
    1,
    Math.floor(DISCRIMINATION_GROUP_FRACTION * cohortSize),
  );
  const top = ranked.slice(0, groupSize);
  const bottom = ranked.slice(cohortSize - groupSize);

  const proportionCorrect = (group: string[], item: string): number => {
    let c = 0;
    for (const s of group) if (studentItems.get(s)!.get(item) === true) c += 1;
    return c / group.length;
  };

  for (const item of new Set(bankItemIds)) {
    byItem.set(
      item,
      proportionCorrect(top, item) - proportionCorrect(bottom, item),
    );
  }

  return { byItem, cohortSize, computed: true };
}
