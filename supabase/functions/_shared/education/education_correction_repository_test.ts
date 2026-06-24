// Tests for the question-paper correction surface (Features A / C / E):
//   A — updatePaperItem: edit one question; editing an approved paper resets it
//       to draft and rebuilds the stored answer key.
//   C — updateQuestionBankItem: edit a saved bank question; fingerprint recomputed.
//   E — promotePaperItemToBank: only an approved AI candidate may enter the bank;
//       a fingerprint duplicate is reused, not re-inserted.
//
// Uses a tiny in-memory fake that routes the exact SQL these functions issue —
// no network, mirrors the existing repository-test pattern.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  promotePaperItemToBank,
  updatePaperItem,
  updateQuestionBankItem,
} from "./education_repository.ts";
import { computeQuestionFingerprint } from "./education_fingerprint.ts";

type Row = Record<string, unknown>;
const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const USER = "a3000000-0000-4000-8000-000000000001";

class FakeDb {
  bank: Row[] = [];
  papers: Row[] = [];
  items: Row[] = [];
  private seq = 0;

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    const s = sql.replace(/\s+/g, " ").trim();

    // ── bank ──
    if (s.startsWith("SELECT * FROM edu_question_bank_items WHERE id =")) {
      return this.rows(this.bank.filter((r) => r.id === args[0]));
    }
    if (s.includes("FROM edu_question_bank_items") && s.includes("fingerprint = $1")) {
      return this.rows(
        this.bank.filter((r) => r.fingerprint === args[0] && r.status === "active").slice(0, 1),
      );
    }
    if (s.startsWith("UPDATE edu_question_bank_items SET")) {
      const row = this.bank.find((r) => r.id === args[0]);
      if (!row) return this.rows([]);
      // mirror the SET list order in updateQuestionBankItem
      row.subject_name = args[1]; // $2
      row.chapter = args[2]; // $3
      row.question_type = args[5]; // $6
      if (args[6] != null) row.marks = args[6]; // $7
      row.question_text = args[7]; // $8
      row.answer_text = args[8]; // $9
      row.fingerprint = args[16]; // $17
      return this.rows([row]);
    }
    if (s.startsWith("INSERT INTO edu_question_bank_items")) {
      const row: Row = {
        id: `bank_${++this.seq}`,
        organization_id: args[0],
        school_id: args[1],
        subject_name: args[2],
        chapter: args[3],
        topic: args[4],
        difficulty: args[5],
        question_type: args[6],
        marks: args[7],
        question_text: args[8],
        answer_text: args[9],
        options: JSON.parse(args[10] as string),
        source: args[11],
        program_track: args[13],
        fingerprint: args[19],
        review_status: args[20],
        status: "active",
      };
      this.bank.push(row);
      return this.rows([row]);
    }

    // ── papers ──
    if (s.startsWith("SELECT * FROM edu_question_papers WHERE id =")) {
      return this.rows(this.papers.filter((r) => r.id === args[0]));
    }
    if (s.startsWith("UPDATE edu_question_papers SET answer_key")) {
      const p = this.papers.find((r) => r.id === args[0]);
      if (p) p.answer_key = JSON.parse(args[1] as string);
      return this.rows([]);
    }
    if (s.startsWith("UPDATE edu_question_papers SET review_status = 'draft'")) {
      const p = this.papers.find((r) => r.id === args[0]);
      if (p) {
        p.review_status = "draft";
        p.approved_by = null;
        p.approved_at = null;
      }
      return this.rows([]);
    }

    // ── paper items ──
    if (s.includes("FROM edu_question_paper_items") && s.includes("ORDER BY sort_order")) {
      const list = this.items
        .filter((r) => r.paper_id === args[0])
        .sort((a, b) => (a.sort_order as number) - (b.sort_order as number));
      return this.rows(list);
    }
    if (s.startsWith("SELECT * FROM edu_question_paper_items WHERE id =")) {
      return this.rows(this.items.filter((r) => r.id === args[0] && r.paper_id === args[1]));
    }
    if (s.startsWith("UPDATE edu_question_paper_items SET question_type = COALESCE")) {
      const row = this.items.find((r) => r.id === args[0] && r.paper_id === args[1]);
      if (!row) return this.rows([]);
      if (args[2] != null) row.question_type = args[2];
      if (args[3] != null) row.marks = args[3];
      if (args[4] != null) row.question_text = args[4];
      row.answer_text = args[5];
      return this.rows([row]);
    }

    throw new Error(`unhandled SQL in fake: ${s.slice(0, 80)}`);
  }

  private rows<T>(list: Row[]): Promise<T[]> {
    return Promise.resolve(JSON.parse(JSON.stringify(list)) as T[]);
  }

  asClient(): TenantQueryClient {
    return this as unknown as TenantQueryClient;
  }
}

Deno.test("C: updateQuestionBankItem changes text and recomputes fingerprint", async () => {
  const db = new FakeDb();
  db.bank.push({
    id: "b1",
    subject_name: "Mathematics",
    chapter: "Algebra",
    topic: "",
    difficulty: "medium",
    question_type: "mcq",
    marks: 2,
    question_text: "Solve 2x+4=10 (typo)",
    answer_text: "x=3",
    options: ["x=2", "x=3"],
    fingerprint: "old",
    review_status: "approved",
    status: "active",
  });
  const before = db.bank[0]!.fingerprint;

  const updated = await updateQuestionBankItem(db.asClient(), "b1", {
    questionText: "Solve 2x + 4 = 10",
  });
  assertEquals(updated?.question_text, "Solve 2x + 4 = 10");
  assertEquals(
    updated?.fingerprint,
    computeQuestionFingerprint({
      subjectName: "Mathematics",
      chapter: "Algebra",
      questionType: "mcq",
      questionText: "Solve 2x + 4 = 10",
    }),
  );
  assertEquals(updated?.fingerprint === before, false);
});

Deno.test("A: editing an approved paper resets it to draft and rebuilds answer key", async () => {
  const db = new FakeDb();
  db.papers.push({
    id: "p1",
    review_status: "approved",
    approved_by: USER,
    approved_at: "2026-06-24T00:00:00Z",
    chapters: ["Real Numbers"],
    difficulty: "medium",
    subject_name: "Mathematics",
  });
  db.items.push(
    {
      id: "i1",
      paper_id: "p1",
      sort_order: 0,
      question_type: "mcq",
      marks: 2,
      question_text: "Q1",
      answer_text: "A1",
      options: [],
    },
    {
      id: "i2",
      paper_id: "p1",
      sort_order: 1,
      question_type: "short_answer",
      marks: 3,
      question_text: "Q2",
      answer_text: "A2",
      options: [],
    },
  );

  const res = await updatePaperItem(db.asClient(), "p1", "i1", {
    questionText: "Q1 corrected",
    answerText: "A1 corrected",
  });
  assertEquals(res.ok, true);
  if (res.ok) assertEquals(res.approvalReset, true);
  assertEquals(db.papers[0]!.review_status, "draft");
  assertEquals(db.papers[0]!.approved_by, null);
  // answer key rebuilt from both items, in order
  assertEquals((db.papers[0]!.answer_key as Array<Row>).length, 2);
  assertEquals((db.papers[0]!.answer_key as Array<Row>)[0]!.answer, "A1 corrected");
});

Deno.test("A: a published paper is locked (not_editable)", async () => {
  const db = new FakeDb();
  db.papers.push({ id: "p1", review_status: "published", chapters: [], difficulty: "easy" });
  db.items.push({ id: "i1", paper_id: "p1", sort_order: 0, question_type: "mcq", marks: 1, question_text: "Q", answer_text: "A", options: [] });

  const res = await updatePaperItem(db.asClient(), "p1", "i1", { questionText: "x" });
  assertEquals(res.ok, false);
  if (!res.ok) assertEquals(res.reason, "not_editable");
});

Deno.test("E: only an approved AI candidate can be promoted; a pending one is rejected", async () => {
  const db = new FakeDb();
  db.papers.push({
    id: "p1", review_status: "draft", chapters: ["Real Numbers"], difficulty: "medium",
    subject_name: "Mathematics", program_track: "board",
  });
  db.items.push({
    id: "i1", paper_id: "p1", sort_order: 0, question_type: "mcq", marks: 2,
    question_text: "Pending AI Q", answer_text: "A", options: ["A", "B"],
    source: "ai_candidate", review_status: "pending",
  });

  const rejected = await promotePaperItemToBank(db.asClient(), ORG, SCHOOL, "p1", "i1", {}, USER);
  assertEquals(rejected.ok, false);
  if (!rejected.ok) assertEquals(rejected.reason, "not_approved");
  assertEquals(db.bank.length, 0);
});

Deno.test("E: approved AI candidate promotes into the bank, then de-dupes", async () => {
  const db = new FakeDb();
  db.papers.push({
    id: "p1", review_status: "draft", chapters: ["Real Numbers"], difficulty: "medium",
    subject_name: "Mathematics", program_track: "board",
  });
  db.items.push({
    id: "i1", paper_id: "p1", sort_order: 0, question_type: "mcq", marks: 2,
    question_text: "Approved AI Q", answer_text: "A", options: ["A", "B"],
    source: "ai_candidate", review_status: "approved",
  });

  const first = await promotePaperItemToBank(db.asClient(), ORG, SCHOOL, "p1", "i1", {}, USER);
  assertEquals(first.ok, true);
  if (first.ok) {
    assertEquals(first.duplicate, false);
    assertEquals(first.item.source, "ai_candidate");
    assertEquals(first.item.review_status, "approved");
    assertEquals(first.item.chapter, "Real Numbers");
  }
  assertEquals(db.bank.length, 1);

  // Promote the same item again → fingerprint match → reused, not duplicated.
  const second = await promotePaperItemToBank(db.asClient(), ORG, SCHOOL, "p1", "i1", {}, USER);
  assertEquals(second.ok, true);
  if (second.ok) assertEquals(second.duplicate, true);
  assertEquals(db.bank.length, 1);
});
