// EIP-6 Learning Evidence spine — repository tests (fake-DB, no network).
//
// Proves the spine contract:
//   • record writes an evidence row with the declared fields;
//   • idempotency per (student, item, attempt, source) — a replay never
//     double-counts; a NEW attempt_no is a distinct row;
//   • per-student history read (filtered, honest-empty);
//   • per-item aggregate for item-analysis (honest-empty ⇒ null rate, not 0%);
//   • per-student per-concept mastery/weakness roll-up SEED (honest-empty);
//   • the EIP-14 contract shape a producer emits into the next layer;
//   • validation refuses malformed evidence.
//
// The fake routes the EXACT SQL the repository issues over an in-memory store —
// mirrors education_correction_repository_test.ts.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { assertRejects } from "https://deno.land/std@0.224.0/assert/assert_rejects.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  getItemResponseAggregate,
  getStudentConceptMastery,
  LearningEvidenceValidationError,
  listStudentItemResponses,
  nextAttemptNo,
  recordItemResponse,
} from "./learning_evidence_repository.ts";
import { toLearningEvidenceContract } from "./learning_evidence_contract.ts";

type Row = Record<string, unknown>;

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STUDENT_A = "a4000000-0000-4000-8000-00000000000a";
const STUDENT_B = "a4000000-0000-4000-8000-00000000000b";
const ITEM_1 = "a5000000-0000-4000-8000-000000000001";
const ITEM_2 = "a5000000-0000-4000-8000-000000000002";
const CONCEPT_FORCE = "a6000000-0000-4000-8000-0000000000f0";

class FakeDb {
  responses: Row[] = [];
  bank: Row[] = [];
  private seq = 0;

  private clone<T>(list: Row[]): Promise<T[]> {
    return Promise.resolve(JSON.parse(JSON.stringify(list)) as T[]);
  }

  /** Parse the (student[, item][, source]) filter args shared by list + count. */
  private studentFilter(s: string, args: unknown[]): Row[] {
    const student = args[0];
    let idx = 1;
    let itemId: unknown;
    let source: unknown;
    if (s.includes("bank_item_id = $")) itemId = args[idx++];
    if (/evidence_source = \$/.test(s)) source = args[idx++];
    return this.responses.filter((r) =>
      r.student_id === student &&
      r.evidence_source != null &&
      (itemId === undefined || r.bank_item_id === itemId) &&
      (source === undefined || r.evidence_source === source)
    );
  }

  queryCount(sql: string, args: unknown[] = []): Promise<number> {
    const s = sql.replace(/\s+/g, " ").trim();
    if (s.includes("count(*)") && s.includes("FROM edu_student_item_responses")) {
      return Promise.resolve(this.studentFilter(s, args).length);
    }
    throw new Error(`unhandled queryCount in fake: ${s.slice(0, 80)}`);
  }

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    const s = sql.replace(/\s+/g, " ").trim();

    // nextAttemptNo
    if (s.startsWith("SELECT COALESCE(MAX(attempt_no), 0) + 1 AS next_attempt")) {
      const [student, item, source] = args;
      const max = this.responses
        .filter((r) =>
          r.student_id === student && r.bank_item_id === item && r.evidence_source === source
        )
        .reduce((m, r) => Math.max(m, r.attempt_no as number), 0);
      return this.clone([{ next_attempt: max + 1 }]);
    }

    // findExistingAttempt (idempotency probe)
    if (s.includes("FROM edu_student_item_responses") && s.includes("attempt_no = $3")) {
      const [student, item, attempt, source] = args;
      const hit = this.responses.filter((r) =>
        r.student_id === student && r.bank_item_id === item &&
        r.attempt_no === attempt && r.evidence_source === source
      ).slice(0, 1);
      return this.clone(hit);
    }

    // per-student history (paginated list)
    if (
      s.startsWith("SELECT * FROM edu_student_item_responses WHERE") &&
      s.includes("ORDER BY occurred_at")
    ) {
      const rows = this.studentFilter(s, args);
      rows.sort((a, b) =>
        String(b.occurred_at ?? "").localeCompare(String(a.occurred_at ?? ""))
      );
      const pageSize = args[args.length - 2] as number;
      const offset = args[args.length - 1] as number;
      return this.clone(rows.slice(offset, offset + pageSize));
    }

    // concept-mastery evidence read
    if (
      s.includes("FROM edu_student_item_responses") &&
      s.includes("bank_item_id IS NOT NULL")
    ) {
      const [student, source] = args;
      const rows = this.responses.filter((r) =>
        r.student_id === student && r.evidence_source != null && r.bank_item_id != null &&
        (source === undefined || r.evidence_source === source)
      );
      return this.clone(rows);
    }

    // per-item aggregate read
    if (
      s.startsWith("SELECT * FROM edu_student_item_responses WHERE bank_item_id = $1")
    ) {
      const [item, source] = args;
      const rows = this.responses.filter((r) =>
        r.bank_item_id === item && r.evidence_source != null &&
        (source === undefined || r.evidence_source === source)
      );
      return this.clone(rows);
    }

    // bank rows for concept roll-up
    if (s.includes("FROM edu_question_bank_items") && s.includes("id = ANY")) {
      const ids = args[0] as string[];
      return this.clone(this.bank.filter((b) => ids.includes(b.id as string)));
    }

    // INSERT evidence row
    if (s.startsWith("INSERT INTO edu_student_item_responses")) {
      const row: Row = {
        id: `resp_${++this.seq}`,
        organization_id: args[0],
        school_id: args[1],
        exam_id: args[2],
        paper_id: null,
        paper_item_id: null,
        bank_item_id: args[3],
        item_version: args[4],
        student_id: args[5],
        max_marks: args[6],
        marks_awarded: args[7],
        is_correct: args[8],
        attempted: args[9],
        chosen_option: args[10],
        time_spent_ms: args[11],
        capture_source: args[12],
        captured_by: args[13],
        captured_at: "2026-07-20T10:00:00Z",
        attempt_no: args[14],
        confidence: args[15],
        hints_used: args[16],
        evidence_source: args[17],
        occurred_at: args[18] ?? "2026-07-20T10:00:00Z",
      };
      this.responses.push(row);
      return this.clone([row]);
    }

    throw new Error(`unhandled queryObject in fake: ${s.slice(0, 90)}`);
  }

  asClient(): TenantQueryClient {
    return this as unknown as TenantQueryClient;
  }
}

function baseInput(over: Record<string, unknown> = {}) {
  return {
    studentId: STUDENT_A,
    itemId: ITEM_1,
    source: "practice" as const,
    contextRef: "practice-session-1",
    maxMarks: 1,
    isCorrect: true,
    marksAwarded: 1,
    timeTakenMs: 4200,
    confidence: 80,
    hintsUsed: 0,
    occurredAt: "2026-07-20T09:00:00Z",
    capturedBy: STUDENT_A,
    ...over,
  };
}

Deno.test("record: writes an evidence row carrying the declared fields", async () => {
  const db = new FakeDb();
  const res = await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput());
  assertEquals(res.created, true);
  assertEquals(db.responses.length, 1);
  const r = db.responses[0]!;
  assertEquals(r.student_id, STUDENT_A);
  assertEquals(r.bank_item_id, ITEM_1);
  assertEquals(r.evidence_source, "practice");
  assertEquals(r.attempt_no, 1);
  assertEquals(r.is_correct, true);
  assertEquals(r.marks_awarded, 1);
  assertEquals(r.time_spent_ms, 4200);
  assertEquals(r.confidence, 80);
  assertEquals(r.hints_used, 0);
  // OMR/exam vs digital capture-source derivation.
  assertEquals(r.capture_source, "digital_attempt");
  assertEquals(r.paper_item_id, null); // evidence keys on the durable bank item
});

Deno.test("record: idempotent per (student,item,attempt,source) — no double count", async () => {
  const db = new FakeDb();
  const first = await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput());
  assertEquals(first.created, true);

  // Exact same attempt replayed (a retried submit) — must be an idempotent no-op.
  const replay = await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput());
  assertEquals(replay.created, false);
  assertEquals(replay.row.id, first.row.id);
  assertEquals(db.responses.length, 1); // NOT double-counted
});

Deno.test("record: a new attempt_no is a distinct evidence row", async () => {
  const db = new FakeDb();
  await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ attemptNo: 1, isCorrect: false, marksAwarded: 0 }));
  await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ attemptNo: 2, isCorrect: true, marksAwarded: 1 }));
  assertEquals(db.responses.length, 2);
  // nextAttemptNo now points at 3.
  const next = await nextAttemptNo(db.asClient(), STUDENT_A, ITEM_1, "practice");
  assertEquals(next, 3);
});

Deno.test("history: per-student, filtered, honest-empty when none", async () => {
  const db = new FakeDb();
  // empty first — honest-empty.
  const empty = await listStudentItemResponses(db.asClient(), { studentId: STUDENT_A });
  assertEquals(empty.total, 0);
  assertEquals(empty.items, []);

  await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ itemId: ITEM_1, attemptNo: 1, occurredAt: "2026-07-20T09:00:00Z" }));
  await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ itemId: ITEM_2, attemptNo: 1, source: "homework", contextRef: "hw-1", occurredAt: "2026-07-20T11:00:00Z" }));
  await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ studentId: STUDENT_B, itemId: ITEM_1, attemptNo: 1, contextRef: "practice-b" }));

  const all = await listStudentItemResponses(db.asClient(), { studentId: STUDENT_A });
  assertEquals(all.total, 2);
  // newest occurred_at first
  assertEquals(all.items[0]!.itemId, ITEM_2);
  assertEquals(all.items[0]!.source, "homework");

  const byItem = await listStudentItemResponses(db.asClient(), { studentId: STUDENT_A, itemId: ITEM_1 });
  assertEquals(byItem.total, 1);
  assertEquals(byItem.items[0]!.itemId, ITEM_1);

  const bySource = await listStudentItemResponses(db.asClient(), { studentId: STUDENT_A, source: "homework" });
  assertEquals(bySource.total, 1);
  assertEquals(bySource.items[0]!.source, "homework");
});

Deno.test("item aggregate: computes correctness/counts; honest-empty ⇒ null rate", async () => {
  const db = new FakeDb();
  // honest-empty for an item nobody has answered.
  const empty = await getItemResponseAggregate(db.asClient(), ITEM_1);
  assertEquals(empty.responseCount, 0);
  assertEquals(empty.correctnessRate, null); // NOT 0% — no signal
  assertEquals(empty.avgTimeTakenMs, null);
  assertEquals(empty.distinctStudents, 0);

  // student A correct, student B wrong, on the same item.
  await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ studentId: STUDENT_A, isCorrect: true, marksAwarded: 1, timeTakenMs: 3000, confidence: 90 }));
  await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ studentId: STUDENT_B, contextRef: "practice-b", isCorrect: false, marksAwarded: 0, timeTakenMs: 5000, confidence: 40 }));

  const agg = await getItemResponseAggregate(db.asClient(), ITEM_1);
  assertEquals(agg.responseCount, 2);
  assertEquals(agg.distinctStudents, 2);
  assertEquals(agg.correctCount, 1);
  assertEquals(agg.incorrectCount, 1);
  assertEquals(agg.correctnessRate, 0.5);
  assertEquals(agg.avgTimeTakenMs, 4000);
  assertEquals(agg.avgScore, 0.5);
  assertEquals(agg.avgConfidence, 65);
});

Deno.test("concept mastery seed: rolls up per concept, flags weakness; honest-empty", async () => {
  const db = new FakeDb();
  // honest-empty
  assertEquals(await getStudentConceptMastery(db.asClient(), STUDENT_A), []);

  // ITEM_1 → canonical concept (Force); ITEM_2 → topic fallback (concept dormant/null).
  db.bank.push(
    { id: ITEM_1, subject_name: "Physics", chapter: "Laws of Motion", topic: "Force", concept_id: CONCEPT_FORCE, competency: null },
    { id: ITEM_2, subject_name: "Physics", chapter: "Gravitation", topic: "Weight", concept_id: null, competency: null },
  );

  // On the Force concept: 1 correct, 2 wrong → mastery 1/3 ≈ 0.33 → weakness.
  await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ itemId: ITEM_1, attemptNo: 1, isCorrect: true, marksAwarded: 1, confidence: 70 }));
  await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ itemId: ITEM_1, attemptNo: 2, isCorrect: false, marksAwarded: 0, confidence: 50 }));
  await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ itemId: ITEM_1, attemptNo: 3, isCorrect: false, marksAwarded: 0, confidence: 30 }));
  // On the Weight topic: 1 correct → mastery 1.0 → not a weakness.
  await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ itemId: ITEM_2, attemptNo: 1, source: "homework", contextRef: "hw-1", isCorrect: true, marksAwarded: 1 }));

  const seeds = await getStudentConceptMastery(db.asClient(), STUDENT_A);
  assertEquals(seeds.length, 2);
  // weakest-first ordering
  const force = seeds[0]!;
  assertEquals(force.conceptId, CONCEPT_FORCE);
  assertEquals(force.topic, "Force");
  assertEquals(force.responseCount, 3);
  assertEquals(force.itemsAttempted, 1);
  assertEquals(force.correctCount, 1);
  assertEquals(Math.round((force.masteryRate ?? 0) * 100), 33);
  assertEquals(force.isWeakness, true);

  const weight = seeds[1]!;
  assertEquals(weight.conceptId, null); // topic-fallback bucket while concept graph dormant
  assertEquals(weight.topic, "Weight");
  assertEquals(weight.masteryRate, 1);
  assertEquals(weight.isWeakness, false);
});

Deno.test("concept mastery: ungraded evidence ⇒ null mastery, never a weakness", async () => {
  const db = new FakeDb();
  db.bank.push({ id: ITEM_1, subject_name: "Physics", chapter: "Laws of Motion", topic: "Force", concept_id: CONCEPT_FORCE, competency: null });
  // attempted but ungraded (is_correct null) — evidence exists, no verdict yet.
  await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ itemId: ITEM_1, isCorrect: null, marksAwarded: null }));
  const seeds = await getStudentConceptMastery(db.asClient(), STUDENT_A);
  assertEquals(seeds.length, 1);
  assertEquals(seeds[0]!.responseCount, 1);
  assertEquals(seeds[0]!.masteryRate, null);
  assertEquals(seeds[0]!.isWeakness, false);
});

Deno.test("EIP-14 contract: toLearningEvidenceContract emits the downstream shape", async () => {
  const db = new FakeDb();
  const { row } = await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({
    source: "exam",
    contextRef: "exam-term1",
    maxMarks: 4,
    marksAwarded: 3,
    isCorrect: true,
    chosenOption: 2,
    confidence: 75,
    hintsUsed: 1,
  }));
  const contract = toLearningEvidenceContract(row as never);
  assertEquals(contract.studentId, STUDENT_A);
  assertEquals(contract.itemId, ITEM_1);
  assertEquals(contract.contextRef, "exam-term1");
  assertEquals(contract.source, "exam");
  assertEquals(contract.attemptNo, 1);
  assertEquals(contract.score, 3);
  assertEquals(contract.maxMarks, 4);
  assertEquals(contract.isCorrect, true);
  assertEquals(contract.chosenOption, 2);
  assertEquals(contract.confidence, 75);
  assertEquals(contract.hintsUsed, 1);
});

Deno.test("validation: malformed evidence is refused (never silently stored)", async () => {
  const db = new FakeDb();
  await assertRejects(
    () => recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ itemId: "" })),
    LearningEvidenceValidationError,
    "itemId is required",
  );
  await assertRejects(
    () => recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ confidence: 150 })),
    LearningEvidenceValidationError,
    "confidence",
  );
  await assertRejects(
    () => recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({ source: "quiz" as never })),
    LearningEvidenceValidationError,
    "source must be one of",
  );
  assertEquals(db.responses.length, 0); // nothing written
});

Deno.test("producer end-to-end: an exam producer records → history + item aggregate reflect it", async () => {
  const db = new FakeDb();
  db.bank.push({ id: ITEM_1, subject_name: "Maths", chapter: "Algebra", topic: "Linear Equations", concept_id: null, competency: null });

  // Simulate a producer (e.g. graded-exam marks capture) emitting one evidence row.
  const emitted = await recordItemResponse(db.asClient(), ORG, SCHOOL, baseInput({
    source: "exam",
    contextRef: "exam-unit-3",
    maxMarks: 5,
    marksAwarded: 4,
    isCorrect: true,
    capturedBy: "teacher-1",
  }));
  assertEquals(emitted.created, true);

  const history = await listStudentItemResponses(db.asClient(), { studentId: STUDENT_A });
  assertEquals(history.total, 1);
  assertEquals(history.items[0]!.source, "exam");
  assertEquals(history.items[0]!.score, 4);

  const agg = await getItemResponseAggregate(db.asClient(), ITEM_1);
  assertEquals(agg.responseCount, 1);
  assertEquals(agg.correctnessRate, 1);

  const seeds = await getStudentConceptMastery(db.asClient(), STUDENT_A);
  assertEquals(seeds.length, 1);
  assertEquals(seeds[0]!.topic, "Linear Equations");
  assertEquals(seeds[0]!.masteryRate, 1);
});
