// Smart OMR — repository tests (fake-DB, no network). Proves the ingestion path
// EMITS EIP-6 evidence (not a parallel store), is idempotent, and that
// item-analysis is HONEST (null, never a fabricated stat, when there is no signal).
//
// The fake routes the EXACT SQL the repository + the reused EIP-6 spine issue over
// an in-memory store — mirrors learning_evidence_repository_test.ts.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { assertRejects } from "https://deno.land/std@0.224.0/assert/assert_rejects.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  getPaperItemAnalysis,
  ingestOmrScan,
  OmrIngestionError,
  resolvePaperOmrAnswerKey,
} from "./omr_repository.ts";

type Row = Record<string, unknown>;

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const PAPER = "a3000000-0000-4000-8000-000000000001";
const EXAM = "exam-term1-physics";
const ITEM_1 = "a5000000-0000-4000-8000-000000000001";
const ITEM_2 = "a5000000-0000-4000-8000-000000000002";
const ITEM_3 = "a5000000-0000-4000-8000-000000000003";
const student = (n: number) =>
  `a4000000-0000-4000-8000-0000000000${n.toString().padStart(2, "0")}`;

class FakeDb {
  responses: Row[] = [];
  scans: Row[] = [];
  paperItems: Row[] = [];
  private seq = 0;

  private clone<T>(list: Row[]): Promise<T[]> {
    return Promise.resolve(JSON.parse(JSON.stringify(list)) as T[]);
  }

  queryCount(): Promise<number> {
    return Promise.resolve(0);
  }

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    const s = sql.replace(/\s+/g, " ").trim();

    // ── edu_question_paper_items (answer-key + item-analysis reads) ──
    if (s.startsWith("SELECT id, bank_item_id, question_type, marks")) {
      const paperId = args[0];
      const rows = this.paperItems
        .filter((r) => r.paper_id === paperId && r.review_status === "approved")
        .sort((a, b) => (a.sort_order as number) - (b.sort_order as number));
      return this.clone(rows);
    }

    // ── edu_omr_scan_results ──
    if (s.startsWith("SELECT * FROM edu_omr_scan_results")) {
      const [org, school, exam, paper, stu] = args;
      const hit = this.scans.filter((r) =>
        r.organization_id === org && r.school_id === school &&
        r.exam_id === exam && r.paper_id === paper && r.student_id === stu
      ).slice(0, 1);
      return this.clone(hit);
    }
    if (s.startsWith("INSERT INTO edu_omr_scan_results")) {
      const row: Row = {
        id: `scan_${++this.seq}`,
        organization_id: args[0],
        school_id: args[1],
        exam_id: args[2],
        paper_id: args[3],
        student_id: args[4],
        set_label: args[5],
        marked_options: JSON.parse(args[6] as string),
        total_score: args[7],
        max_score: args[8],
        correct_count: args[9],
        incorrect_count: args[10],
        blank_count: args[11],
        ambiguous_count: args[12],
        unscored_count: args[13],
        blank_policy: args[14],
        multi_mark_policy: args[15],
        scanned_by: args[16],
        scored_at: "2026-07-20T10:00:00Z",
        created_at: "2026-07-20T10:00:00Z",
      };
      this.scans.push(row);
      return this.clone([row]);
    }

    // ── edu_student_item_responses (EIP-6 spine, reused) ──
    // nextAttemptNo
    if (
      s.startsWith("SELECT COALESCE(MAX(attempt_no), 0) + 1 AS next_attempt")
    ) {
      const [stu, item, source] = args;
      const max = this.responses
        .filter((r) =>
          r.student_id === stu && r.bank_item_id === item &&
          r.evidence_source === source
        )
        .reduce((m, r) => Math.max(m, r.attempt_no as number), 0);
      return this.clone([{ next_attempt: max + 1 }]);
    }
    // findExistingAttempt (idempotency probe)
    if (
      s.includes("FROM edu_student_item_responses") &&
      s.includes("attempt_no = $3")
    ) {
      const [stu, item, attempt, source] = args;
      const hit = this.responses.filter((r) =>
        r.student_id === stu && r.bank_item_id === item &&
        r.attempt_no === attempt && r.evidence_source === source
      ).slice(0, 1);
      return this.clone(hit);
    }
    // discrimination cohort read
    if (s.startsWith("SELECT student_id, bank_item_id, is_correct")) {
      const [ids, source] = args as [string[], string];
      const rows = this.responses.filter((r) =>
        ids.includes(r.bank_item_id as string) &&
        r.evidence_source === source && r.is_correct !== null
      );
      return this.clone(rows);
    }
    // per-item aggregate read
    if (
      s.startsWith(
        "SELECT * FROM edu_student_item_responses WHERE bank_item_id = $1",
      )
    ) {
      const [item, source] = args;
      const rows = this.responses.filter((r) =>
        r.bank_item_id === item && r.evidence_source != null &&
        (source === undefined || r.evidence_source === source)
      );
      return this.clone(rows);
    }
    // INSERT evidence row (identical column order to the spine writer)
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

/** Seed a 3-question MCQ paper: Q1/Q2/Q3 correct option = A (index 0 → 1-based 1). */
function seedMcqPaper(db: FakeDb) {
  db.paperItems.push(
    mcqItem(ITEM_1, 0, "What is 2+2?", ["4", "3", "5"], "4"), // correct option 1
    mcqItem(ITEM_2, 1, "Capital of France?", ["Paris", "Rome"], "Paris"), // correct option 1
    mcqItem(ITEM_3, 2, "H2O is?", ["Water", "Air", "Oil"], "Water"), // correct option 1
  );
}

function mcqItem(
  id: string,
  sortOrder: number,
  q: string,
  options: string[],
  answer: string,
): Row {
  return {
    id,
    paper_id: PAPER,
    bank_item_id: id, // bank id == item id for the test
    question_type: "mcq",
    marks: 1,
    question_text: q,
    answer_text: answer,
    options,
    sort_order: sortOrder,
    review_status: "approved",
  };
}

// ── resolvePaperOmrAnswerKey ─────────────────────────────────────────────────

Deno.test("resolvePaperOmrAnswerKey: 1-based correct option from answer_text index", async () => {
  const db = new FakeDb();
  db.paperItems.push(
    mcqItem(ITEM_1, 0, "q1", ["a", "b", "c"], "c"), // correct option 3
    mcqItem(ITEM_2, 1, "q2", ["x", "y"], "x"), // correct option 1
    // long-answer → unscoreable
    {
      id: ITEM_3,
      paper_id: PAPER,
      bank_item_id: ITEM_3,
      question_type: "long_answer",
      marks: 5,
      question_text: "essay",
      answer_text: "…",
      options: [],
      sort_order: 2,
      review_status: "approved",
    },
    // mcq whose answer is NOT a verbatim option → unscoreable (never guessed)
    {
      id: "a5000000-0000-4000-8000-000000000004",
      paper_id: PAPER,
      bank_item_id: "a5000000-0000-4000-8000-000000000004",
      question_type: "mcq",
      marks: 1,
      question_text: "q4",
      answer_text: "zzz",
      options: ["p", "q"],
      sort_order: 3,
      review_status: "approved",
    },
  );
  const key = await resolvePaperOmrAnswerKey(db.asClient(), PAPER);
  assertEquals(key.length, 4);
  assertEquals(key[0]!.correctOption, 3);
  assertEquals(key[1]!.correctOption, 1);
  assertEquals(key[2]!.correctOption, null); // long-answer
  assertEquals(key[3]!.correctOption, null); // answer not a verbatim option
  assertEquals(key[0]!.bankItemId, ITEM_1);
});

// ── Ingestion → EIP-6 evidence ───────────────────────────────────────────────

Deno.test("ingest: scores a sheet, persists the scan, and EMITS one EIP-6 row per scoreable item", async () => {
  const db = new FakeDb();
  seedMcqPaper(db);

  // Q1 correct (opt 1), Q2 wrong (opt 2), Q3 blank (absent).
  const out = await ingestOmrScan(db.asClient(), ORG, SCHOOL, {
    examId: EXAM,
    paperId: PAPER,
    studentId: student(1),
    markedOptions: [
      { questionNo: 1, marked: [1] },
      { questionNo: 2, marked: [2] },
    ],
    scannedBy: "teacher-1",
  });

  assertEquals(out.created, true);
  assertEquals(out.score.totalScore, 1);
  assertEquals(out.score.maxScore, 3);
  assertEquals(out.score.correctCount, 1);
  assertEquals(out.score.incorrectCount, 1);
  assertEquals(out.score.blankCount, 1);

  // scan persisted
  assertEquals(db.scans.length, 1);
  assertEquals(db.scans[0]!.total_score, 1);
  assertEquals(db.scans[0]!.correct_count, 1);

  // ONE evidence row per scoreable item (all 3), all in the OMR lane — NOT a
  // parallel store: this is the same edu_student_item_responses spine.
  assertEquals(out.evidenceEmitted, 3);
  assertEquals(db.responses.length, 3);
  assertEquals(db.responses.every((r) => r.evidence_source === "omr"), true);
  assertEquals(
    db.responses.every((r) => r.capture_source === "marks_grid_ocr"),
    true,
  );
  assertEquals(db.responses.every((r) => r.exam_id === EXAM), true);

  const r1 = db.responses.find((r) => r.bank_item_id === ITEM_1)!;
  assertEquals(r1.is_correct, true);
  assertEquals(r1.marks_awarded, 1);
  assertEquals(r1.chosen_option, 1);
  const r2 = db.responses.find((r) => r.bank_item_id === ITEM_2)!;
  assertEquals(r2.is_correct, false);
  assertEquals(r2.marks_awarded, 0);
  const r3 = db.responses.find((r) => r.bank_item_id === ITEM_3)!;
  assertEquals(r3.is_correct, null); // blank → ungraded, NOT wrong
  assertEquals(r3.marks_awarded, null);
  assertEquals(r3.attempted, false);
});

Deno.test("ingest: idempotent per (exam, paper, student) — replay emits nothing", async () => {
  const db = new FakeDb();
  seedMcqPaper(db);
  const input = {
    examId: EXAM,
    paperId: PAPER,
    studentId: student(1),
    markedOptions: [{ questionNo: 1, marked: [1] }, {
      questionNo: 2,
      marked: [2],
    }],
  };
  const first = await ingestOmrScan(db.asClient(), ORG, SCHOOL, input);
  assertEquals(first.created, true);
  assertEquals(first.evidenceEmitted, 3);

  const replay = await ingestOmrScan(db.asClient(), ORG, SCHOOL, input);
  assertEquals(replay.created, false);
  assertEquals(replay.evidenceEmitted, 0);
  assertEquals(db.scans.length, 1); // NOT a second scan
  assertEquals(db.responses.length, 3); // NOT double-counted
  // the replay still returns a faithful (re-scored-from-stored) result
  assertEquals(replay.score.totalScore, 1);
});

Deno.test("ingest: same bank item in a DIFFERENT exam is a NEW attempt (no cross-exam collision)", async () => {
  const db = new FakeDb();
  seedMcqPaper(db);
  await ingestOmrScan(db.asClient(), ORG, SCHOOL, {
    examId: "exam-A",
    paperId: PAPER,
    studentId: student(1),
    markedOptions: [{ questionNo: 1, marked: [1] }],
  });
  await ingestOmrScan(db.asClient(), ORG, SCHOOL, {
    examId: "exam-B",
    paperId: PAPER,
    studentId: student(1),
    markedOptions: [{ questionNo: 1, marked: [1] }],
  });
  const item1Rows = db.responses.filter((r) => r.bank_item_id === ITEM_1);
  assertEquals(item1Rows.length, 2); // both recorded — attempt 1 and attempt 2
  assertEquals(item1Rows.map((r) => r.attempt_no).sort(), [1, 2]);
});

Deno.test("ingest: multi-mark default → ambiguous, ungraded, not double counted", async () => {
  const db = new FakeDb();
  seedMcqPaper(db);
  const out = await ingestOmrScan(db.asClient(), ORG, SCHOOL, {
    examId: EXAM,
    paperId: PAPER,
    studentId: student(1),
    markedOptions: [{ questionNo: 1, marked: [1, 2] }], // ambiguous
  });
  assertEquals(out.score.ambiguousCount, 1);
  const r1 = db.responses.find((r) => r.bank_item_id === ITEM_1)!;
  assertEquals(r1.is_correct, null); // never guessed
  assertEquals(r1.chosen_option, null);
});

Deno.test("ingest: unscoreable question yields NO OMR evidence (no verdict to record)", async () => {
  const db = new FakeDb();
  db.paperItems.push(
    mcqItem(ITEM_1, 0, "q1", ["4", "3"], "4"), // scoreable
    {
      id: ITEM_2,
      paper_id: PAPER,
      bank_item_id: ITEM_2,
      question_type: "long_answer",
      marks: 5,
      question_text: "essay",
      answer_text: "x",
      options: [],
      sort_order: 1,
      review_status: "approved",
    },
  );
  const out = await ingestOmrScan(db.asClient(), ORG, SCHOOL, {
    examId: EXAM,
    paperId: PAPER,
    studentId: student(1),
    markedOptions: [{ questionNo: 1, marked: [1] }],
  });
  assertEquals(out.score.unscoredCount, 1);
  assertEquals(out.evidenceEmitted, 1); // only the scoreable MCQ
  assertEquals(db.responses.length, 1);
  assertEquals(db.responses[0]!.bank_item_id, ITEM_1);
});

Deno.test("ingest: a paper with no approved questions is refused (422-shaped error)", async () => {
  const db = new FakeDb(); // no paper items
  await assertRejects(
    () =>
      ingestOmrScan(db.asClient(), ORG, SCHOOL, {
        examId: EXAM,
        paperId: PAPER,
        studentId: student(1),
        markedOptions: [{ questionNo: 1, marked: [1] }],
      }),
    OmrIngestionError,
    "no approved questions",
  );
});

Deno.test("ingest: a key/sheet mismatch is surfaced as an ingestion error (not a 500)", async () => {
  const db = new FakeDb();
  seedMcqPaper(db);
  await assertRejects(
    () =>
      ingestOmrScan(db.asClient(), ORG, SCHOOL, {
        examId: EXAM,
        paperId: PAPER,
        studentId: student(1),
        markedOptions: [{ questionNo: 99, marked: [1] }], // no such question
      }),
    OmrIngestionError,
    "key/sheet mismatch",
  );
  assertEquals(db.scans.length, 0); // nothing persisted on a bad sheet
  assertEquals(db.responses.length, 0);
});

// ── Item analysis (Assessment Intelligence) — HONESTY ────────────────────────

Deno.test("item-analysis: honest-empty — no evidence ⇒ null difficulty & discrimination, real zeros", async () => {
  const db = new FakeDb();
  seedMcqPaper(db);
  const analysis = await getPaperItemAnalysis(db.asClient(), PAPER);
  assertEquals(analysis.itemCount, 3);
  assertEquals(analysis.itemsWithEvidence, 0);
  assertEquals(analysis.cohortSize, 0);
  assertEquals(analysis.discriminationComputed, false);
  assertEquals(analysis.avgDifficulty, null); // NOT 0% — no signal
  assertEquals(analysis.items.every((i) => i.difficulty === null), true);
  assertEquals(analysis.items.every((i) => i.discrimination === null), true);
  assertEquals(analysis.items.every((i) => i.responseCount === 0), true);
});

Deno.test("item-analysis: difficulty computed; discrimination null while cohort < minimum", async () => {
  const db = new FakeDb();
  seedMcqPaper(db);
  // 3 students (< MIN_COHORT_FOR_DISCRIMINATION = 4) all answer Q1.
  for (const n of [1, 2, 3]) {
    await ingestOmrScan(db.asClient(), ORG, SCHOOL, {
      examId: EXAM,
      paperId: PAPER,
      studentId: student(n),
      markedOptions: [{ questionNo: 1, marked: [n === 3 ? 2 : 1] }], // S1,S2 correct; S3 wrong
    });
  }
  const analysis = await getPaperItemAnalysis(db.asClient(), PAPER);
  const q1 = analysis.items[0]!;
  assertEquals(q1.difficulty, 2 / 3); // 2 of 3 correct — real proportion
  assertEquals(analysis.discriminationComputed, false);
  assertEquals(q1.discrimination, null); // too small a cohort to be meaningful
  assertEquals(analysis.cohortSize, 3);
});

Deno.test("item-analysis: with an adequate cohort, difficulty + discrimination are computed", async () => {
  const db = new FakeDb();
  db.paperItems.push(
    mcqItem(ITEM_1, 0, "q1", ["A", "B"], "A"), // correct option 1
    mcqItem(ITEM_2, 1, "q2", ["A", "B"], "A"), // correct option 1
  );
  // 5 students. Q1 correct: S1,S2,S3 (3/5=0.6). Q2 correct: S1,S5 (2/5=0.4).
  const answers: Record<number, [number, number]> = {
    1: [1, 1], // total 2 (top)
    2: [1, 2], // total 1
    3: [1, 2], // total 1
    4: [2, 2], // total 0 (bottom)
    5: [2, 1], // total 1
  };
  for (const n of [1, 2, 3, 4, 5]) {
    const [a1, a2] = answers[n]!;
    await ingestOmrScan(db.asClient(), ORG, SCHOOL, {
      examId: EXAM,
      paperId: PAPER,
      studentId: student(n),
      markedOptions: [{ questionNo: 1, marked: [a1] }, {
        questionNo: 2,
        marked: [a2],
      }],
    });
  }
  const analysis = await getPaperItemAnalysis(db.asClient(), PAPER);
  assertEquals(analysis.cohortSize, 5);
  assertEquals(analysis.discriminationComputed, true);
  assertEquals(analysis.items[0]!.difficulty, 0.6);
  assertEquals(analysis.items[1]!.difficulty, 0.4);
  // group size = floor(0.27*5)=1: top=S1 (both correct), bottom=S4 (both wrong) → D=1.
  assertEquals(analysis.items[0]!.discrimination, 1);
  assertEquals(analysis.items[1]!.discrimination, 1);
  assertEquals(analysis.avgDifficulty, 0.5);
  assertEquals(analysis.itemsWithEvidence, 2);
});
