// EIP-6 Learning Evidence spine — repository (the LIVE writer + readers).
//
// Turns the dormant `edu_student_item_responses` table into a governed,
// APPEND-ONLY evidence-capture spine:
//   • recordItemResponse  — the writer. Idempotent per (student, item, attempt,
//     source): a replay of the same attempt is a no-op, never a double count.
//   • listStudentItemResponses — per-student item-response history.
//   • getItemResponseAggregate — per-item aggregate for item-analysis.
//   • getStudentConceptMastery — per-student, per-concept mastery/weakness roll-up
//     SEED (the contract W5 / EIP-7 consumes).
//   • nextAttemptNo — helper for a producer that wants server-assigned attempts.
//
// Tenant/school scoping is enforced by RLS on the `erp_tenant` connection (the
// established education-repository style — business columns only in WHERE); the
// student-self RLS policy (migration 20260900000031) additionally fences a
// student-scope session to its own rows.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type ConceptMasterySeed,
  CONCEPT_WEAKNESS_THRESHOLD,
  type EduEvidenceSource,
  isEvidenceSource,
  type ItemResponseAggregate,
  type LearningEvidenceRecord,
  toLearningEvidenceContract,
} from "./learning_evidence_contract.ts";

export type {
  ConceptMasterySeed,
  EduEvidenceSource,
  ItemResponseAggregate,
  LearningEvidenceRecord,
};

/** Thrown on a malformed evidence write; handlers map it to 422 (not 500). */
export class LearningEvidenceValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "LearningEvidenceValidationError";
  }
}

/** Raw storage row of the evidence spine (superset of the E1a seed columns). */
export interface EvidenceResponseRow {
  id: string;
  organization_id: string;
  school_id: string;
  exam_id: string;
  paper_id: string | null;
  paper_item_id: string | null;
  bank_item_id: string | null;
  item_version: number;
  student_id: string;
  max_marks: number | string;
  marks_awarded: number | string | null;
  is_correct: boolean | null;
  attempted: boolean;
  chosen_option: number | null;
  time_spent_ms: number | null;
  capture_source: string;
  captured_by: string | null;
  captured_at: string | null;
  attempt_no: number;
  confidence: number | null;
  hints_used: number | null;
  evidence_source: string | null;
  occurred_at: string | null;
}

/** How the row was physically captured (existing NOT NULL column CHECK set). */
export type EduCaptureSource =
  | "marks_grid_ocr"
  | "marks_grid_manual"
  | "digital_attempt"
  | "import";

export interface RecordItemResponseInput {
  studentId: string;
  /** Durable, concept-linked item identity (edu_question_bank_items.id). */
  itemId: string;
  source: EduEvidenceSource;
  /** Context id stored in exam_id: exam / homework / practice-session id. */
  contextRef: string;
  maxMarks: number;
  /** Defaults to 1. Monotonic per (student, item, source). */
  attemptNo?: number;
  attempted?: boolean;
  isCorrect?: boolean | null;
  /** Marks awarded (score). Null when ungraded/skipped. */
  marksAwarded?: number | null;
  timeTakenMs?: number | null;
  /** Self-reported confidence 0..100. */
  confidence?: number | null;
  hintsUsed?: number;
  chosenOption?: number | null;
  itemVersion?: number;
  /** ISO timestamp the interaction happened; defaults to now() server-side. */
  occurredAt?: string | null;
  /** User who captured (teacher for omr/exam marks-grid; the student for self). */
  capturedBy?: string | null;
  /** Override the derived physical capture mechanism. */
  captureSource?: EduCaptureSource;
}

export type RecordItemResponseResult = {
  row: EvidenceResponseRow;
  /** false when the attempt was already on record — an idempotent no-op. */
  created: boolean;
};

export interface PaginationResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}

function clampPageSize(pageSize: number): number {
  return Math.min(100, Math.max(1, pageSize));
}

function deriveCaptureSource(
  source: EduEvidenceSource,
  override?: EduCaptureSource,
): EduCaptureSource {
  if (override) return override;
  // OMR marks come off a scanned grid; everything else is a digital attempt.
  return source === "omr" ? "marks_grid_ocr" : "digital_attempt";
}

function validate(input: RecordItemResponseInput): void {
  if (!input.itemId || !input.itemId.trim()) {
    throw new LearningEvidenceValidationError("itemId is required to record evidence");
  }
  if (!input.studentId || !input.studentId.trim()) {
    throw new LearningEvidenceValidationError("studentId is required to record evidence");
  }
  if (!input.contextRef || !input.contextRef.trim()) {
    throw new LearningEvidenceValidationError("contextRef is required to record evidence");
  }
  if (!isEvidenceSource(input.source)) {
    throw new LearningEvidenceValidationError(
      "source must be one of practice | homework | exam | omr",
    );
  }
  if (!Number.isFinite(input.maxMarks) || input.maxMarks < 0) {
    throw new LearningEvidenceValidationError("maxMarks must be a non-negative number");
  }
  const attempt = input.attemptNo ?? 1;
  if (!Number.isInteger(attempt) || attempt < 1) {
    throw new LearningEvidenceValidationError("attemptNo must be an integer >= 1");
  }
  if (
    input.confidence != null &&
    (!Number.isFinite(input.confidence) || input.confidence < 0 || input.confidence > 100)
  ) {
    throw new LearningEvidenceValidationError("confidence must be between 0 and 100");
  }
  if (input.hintsUsed != null && (!Number.isInteger(input.hintsUsed) || input.hintsUsed < 0)) {
    throw new LearningEvidenceValidationError("hintsUsed must be a non-negative integer");
  }
  if (
    input.marksAwarded != null &&
    (!Number.isFinite(input.marksAwarded) || input.marksAwarded < 0)
  ) {
    throw new LearningEvidenceValidationError("marksAwarded must be a non-negative number");
  }
}

/** Existing evidence row for this exact attempt, if already on record. */
async function findExistingAttempt(
  client: TenantQueryClient,
  studentId: string,
  itemId: string,
  attemptNo: number,
  source: EduEvidenceSource,
): Promise<EvidenceResponseRow | null> {
  const rows = await client.queryObject<EvidenceResponseRow>(
    `SELECT * FROM edu_student_item_responses
      WHERE student_id = $1 AND bank_item_id = $2
        AND attempt_no = $3 AND evidence_source = $4
      LIMIT 1`,
    [studentId, itemId, attemptNo, source],
  );
  return rows[0] ?? null;
}

/**
 * Record ONE item interaction as APPEND-ONLY evidence. Idempotent per
 * (student, item, attempt, source): if that attempt is already on record the
 * stored row is returned unchanged (`created: false`) — a replay never
 * double-counts. The partial UNIQUE index `edu_student_item_responses_evidence_idem`
 * is the hard DB backstop behind this application-level check.
 */
export async function recordItemResponse(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: RecordItemResponseInput,
): Promise<RecordItemResponseResult> {
  validate(input);
  const attemptNo = input.attemptNo ?? 1;

  const existing = await findExistingAttempt(
    client,
    input.studentId,
    input.itemId,
    attemptNo,
    input.source,
  );
  if (existing) return { row: existing, created: false };

  const rows = await client.queryObject<EvidenceResponseRow>(
    `INSERT INTO edu_student_item_responses (
       organization_id, school_id, exam_id, bank_item_id, item_version,
       student_id, max_marks, marks_awarded, is_correct, attempted,
       chosen_option, time_spent_ms, capture_source, captured_by, captured_at,
       attempt_no, confidence, hints_used, evidence_source, occurred_at
     ) VALUES (
       $1, $2, $3, $4, $5,
       $6, $7, $8, $9, $10,
       $11, $12, $13, $14, now(),
       $15, $16, $17, $18, COALESCE($19::timestamptz, now())
     )
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.contextRef,
      input.itemId,
      input.itemVersion ?? 1,
      input.studentId,
      input.maxMarks,
      input.marksAwarded ?? null,
      input.isCorrect ?? null,
      input.attempted ?? true,
      input.chosenOption ?? null,
      input.timeTakenMs ?? null,
      deriveCaptureSource(input.source, input.captureSource),
      input.capturedBy ?? null,
      attemptNo,
      input.confidence ?? null,
      input.hintsUsed ?? 0,
      input.source,
      input.occurredAt ?? null,
    ],
  );
  return { row: rows[0]!, created: true };
}

/** Next attempt number for a producer that wants server-assigned attempts. */
export async function nextAttemptNo(
  client: TenantQueryClient,
  studentId: string,
  itemId: string,
  source: EduEvidenceSource,
): Promise<number> {
  const rows = await client.queryObject<{ next_attempt: number }>(
    `SELECT COALESCE(MAX(attempt_no), 0) + 1 AS next_attempt
       FROM edu_student_item_responses
      WHERE student_id = $1 AND bank_item_id = $2 AND evidence_source = $3`,
    [studentId, itemId, source],
  );
  return Number(rows[0]?.next_attempt ?? 1);
}

export interface StudentResponseFilters {
  studentId: string;
  itemId?: string;
  source?: EduEvidenceSource;
  page?: number;
  pageSize?: number;
}

/** Per-student item-response history (newest interaction first). Honest-empty. */
export async function listStudentItemResponses(
  client: TenantQueryClient,
  filters: StudentResponseFilters,
): Promise<PaginationResult<LearningEvidenceRecord>> {
  const page = Math.max(1, filters.page ?? 1);
  const pageSize = clampPageSize(filters.pageSize ?? 20);
  const offset = (page - 1) * pageSize;

  const conditions = ["student_id = $1", "evidence_source IS NOT NULL"];
  const params: unknown[] = [filters.studentId];
  let i = 2;
  if (filters.itemId) {
    conditions.push(`bank_item_id = $${i}`);
    params.push(filters.itemId);
    i += 1;
  }
  if (filters.source) {
    conditions.push(`evidence_source = $${i}`);
    params.push(filters.source);
    i += 1;
  }
  const where = conditions.join(" AND ");

  const total = await client.queryCount(
    `SELECT count(*)::text AS count FROM edu_student_item_responses WHERE ${where}`,
    params,
  );
  const rows = await client.queryObject<EvidenceResponseRow>(
    `SELECT * FROM edu_student_item_responses
      WHERE ${where}
      ORDER BY occurred_at DESC NULLS LAST, captured_at DESC NULLS LAST
      LIMIT $${i} OFFSET $${i + 1}`,
    [...params, pageSize, offset],
  );

  return {
    items: rows.map(toLearningEvidenceContract),
    total,
    page,
    pageSize,
  };
}

function num(value: number | string | null): number | null {
  if (value == null) return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function avg(values: number[]): number | null {
  if (values.length === 0) return null;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

/**
 * Per-item response aggregate for item-analysis. Computed in TS from the raw
 * evidence rows (deterministic, no DB-dialect AVG rounding surprises). HONEST-
 * EMPTY: an item with no evidence returns an all-zero aggregate with
 * `correctnessRate: null` — never a fabricated 0%.
 */
export async function getItemResponseAggregate(
  client: TenantQueryClient,
  itemId: string,
  opts: { source?: EduEvidenceSource } = {},
): Promise<ItemResponseAggregate> {
  const conditions = ["bank_item_id = $1", "evidence_source IS NOT NULL"];
  const params: unknown[] = [itemId];
  if (opts.source) {
    conditions.push("evidence_source = $2");
    params.push(opts.source);
  }
  const rows = await client.queryObject<EvidenceResponseRow>(
    `SELECT * FROM edu_student_item_responses WHERE ${conditions.join(" AND ")}`,
    params,
  );

  const graded = rows.filter((r) => r.is_correct !== null);
  const correctCount = graded.filter((r) => r.is_correct === true).length;
  const times = rows.map((r) => r.time_spent_ms).filter((t): t is number => t != null);
  const scores = rows.map((r) => num(r.marks_awarded)).filter((s): s is number => s != null);
  const confidences = rows.map((r) => r.confidence).filter((c): c is number => c != null);

  return {
    itemId,
    responseCount: rows.length,
    distinctStudents: new Set(rows.map((r) => r.student_id)).size,
    attemptedCount: rows.filter((r) => r.attempted).length,
    correctCount,
    incorrectCount: graded.length - correctCount,
    correctnessRate: graded.length === 0 ? null : correctCount / graded.length,
    avgTimeTakenMs: avg(times),
    avgScore: avg(scores),
    avgConfidence: avg(confidences),
  };
}

interface BankConceptRow {
  id: string;
  subject_name: string;
  chapter: string;
  topic: string;
  concept_id: string | null;
  competency: string | null;
}

/**
 * Per-student, per-concept mastery/weakness roll-up SEED — the EIP-7 / W5
 * contract. Reads the student's evidence, joins each item to its concept (or, while
 * the canonical concept graph is dormant, to its subject/chapter/topic), and rolls
 * up mastery = correct / graded per concept. HONEST-EMPTY: no evidence ⇒ `[]`; a
 * concept with no GRADED evidence ⇒ `masteryRate: null`, `isWeakness: false`.
 */
export async function getStudentConceptMastery(
  client: TenantQueryClient,
  studentId: string,
  opts: { subjectName?: string; source?: EduEvidenceSource } = {},
): Promise<ConceptMasterySeed[]> {
  const conditions = [
    "student_id = $1",
    "evidence_source IS NOT NULL",
    "bank_item_id IS NOT NULL",
  ];
  const params: unknown[] = [studentId];
  if (opts.source) {
    conditions.push("evidence_source = $2");
    params.push(opts.source);
  }
  const evidence = await client.queryObject<EvidenceResponseRow>(
    `SELECT * FROM edu_student_item_responses WHERE ${conditions.join(" AND ")}`,
    params,
  );
  if (evidence.length === 0) return [];

  const itemIds = [...new Set(evidence.map((r) => r.bank_item_id).filter((x): x is string => !!x))];
  if (itemIds.length === 0) return [];

  const bankRows = await client.queryObject<BankConceptRow>(
    `SELECT id, subject_name, chapter, topic, concept_id, competency
       FROM edu_question_bank_items
      WHERE id = ANY($1::uuid[])`,
    [itemIds],
  );
  const bankById = new Map(bankRows.map((b) => [b.id, b]));

  interface Bucket {
    conceptId: string | null;
    subjectName: string;
    chapter: string;
    topic: string;
    items: Set<string>;
    responseCount: number;
    correctCount: number;
    gradedCount: number;
    confidences: number[];
  }
  const buckets = new Map<string, Bucket>();

  for (const row of evidence) {
    const bank = row.bank_item_id ? bankById.get(row.bank_item_id) : undefined;
    if (!bank) continue; // item not readable (RLS) or archived — skip, never invent.
    if (opts.subjectName && bank.subject_name !== opts.subjectName) continue;

    // Group by canonical concept when present; else by (subject, chapter, topic)
    // so the seed is useful before the concept graph is populated.
    const key = bank.concept_id ??
      `topic:${bank.subject_name}|${bank.chapter}|${bank.topic}`;
    let bucket = buckets.get(key);
    if (!bucket) {
      bucket = {
        conceptId: bank.concept_id,
        subjectName: bank.subject_name,
        chapter: bank.chapter,
        topic: bank.topic,
        items: new Set(),
        responseCount: 0,
        correctCount: 0,
        gradedCount: 0,
        confidences: [],
      };
      buckets.set(key, bucket);
    }
    bucket.items.add(bank.id);
    bucket.responseCount += 1;
    if (row.is_correct !== null) {
      bucket.gradedCount += 1;
      if (row.is_correct === true) bucket.correctCount += 1;
    }
    if (row.confidence != null) bucket.confidences.push(row.confidence);
  }

  const seeds: ConceptMasterySeed[] = [];
  for (const b of buckets.values()) {
    const masteryRate = b.gradedCount === 0 ? null : b.correctCount / b.gradedCount;
    seeds.push({
      conceptId: b.conceptId,
      subjectName: b.subjectName,
      chapter: b.chapter,
      topic: b.topic,
      itemsAttempted: b.items.size,
      responseCount: b.responseCount,
      correctCount: b.correctCount,
      masteryRate,
      avgConfidence: avg(b.confidences),
      isWeakness: masteryRate !== null && masteryRate < CONCEPT_WEAKNESS_THRESHOLD,
    });
  }
  // Weakest first (weaknesses surface at the top), null-mastery last.
  seeds.sort((a, b) => {
    if (a.masteryRate === null) return 1;
    if (b.masteryRate === null) return -1;
    return a.masteryRate - b.masteryRate;
  });
  return seeds;
}
