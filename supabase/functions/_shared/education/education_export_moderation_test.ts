// AI-1 (Wave 4): the exported student paper must contain only human-approved
// items — never a rejected (disapproved) or still-pending AI candidate — and the
// answer key must stay aligned to the surviving, renumbered questions.

import { assertEquals } from "jsr:@std/assert@1";
import { paperExportDocument } from "./education_mapper.ts";
import type { QuestionPaperItemRow, QuestionPaperRow } from "./education_types.ts";

function paper(overrides: Partial<QuestionPaperRow> = {}): QuestionPaperRow {
  return {
    id: "paper-1",
    organization_id: "org",
    school_id: "school",
    academic_year_id: null,
    academic_year_label: "2026-27",
    class_name: "10",
    section_name: "A",
    subject_name: "Mathematics",
    chapters: [],
    difficulty: "mixed",
    total_marks: 20,
    exam_type: "unit_test",
    title: "Unit Test 1",
    status: "published",
    program_track: "board",
    review_status: "published",
    blueprint: {},
    answer_key: [{ questionNumber: 99, answer: "stale", marks: 5 }],
    created_by: null,
    submitted_by: null,
    submitted_at: null,
    approved_by: null,
    approved_at: null,
    published_at: "now",
    created_at: "now",
    updated_at: "now",
    ...overrides,
  };
}

function item(
  reviewStatus: string,
  text: string,
  answer: string,
  marks = 5,
): QuestionPaperItemRow {
  return {
    id: crypto.randomUUID(),
    paper_id: "paper-1",
    organization_id: "org",
    school_id: "school",
    sort_order: 0,
    bank_item_id: null,
    question_type: "mcq",
    marks,
    question_text: text,
    answer_text: answer,
    options: [],
    source: reviewStatus === "approved" ? "bank" : "ai_candidate",
    review_status: reviewStatus,
  };
}

Deno.test("paperExportDocument drops rejected and pending items", () => {
  const items = [
    item("approved", "Q approved one", "A1"),
    item("rejected", "Q rejected", "BAD"),
    item("approved", "Q approved two", "A2"),
    item("pending", "Q unmoderated", "PENDING"),
  ];

  const doc = paperExportDocument(paper(), items);
  const questions = doc.questions as Array<Record<string, unknown>>;

  assertEquals(questions.length, 2);
  const texts = questions.map((q) => q.questionText);
  assertEquals(texts, ["Q approved one", "Q approved two"]);
  // Disapproved / unmoderated text never appears.
  assertEquals(texts.includes("Q rejected"), false);
  assertEquals(texts.includes("Q unmoderated"), false);
});

Deno.test("paperExportDocument renumbers and realigns the answer key", () => {
  const items = [
    item("rejected", "Q rejected first", "BAD"),
    item("approved", "Q kept A", "ANS-A"),
    item("approved", "Q kept B", "ANS-B"),
  ];

  const doc = paperExportDocument(paper(), items);
  const answerKey = doc.answerKey as Array<Record<string, unknown>>;

  // Rebuilt from surviving items (the stale stored answer_key is ignored), and
  // numbered 1..N so questions and answers line up.
  assertEquals(answerKey, [
    { questionNumber: 1, answer: "ANS-A", marks: 5 },
    { questionNumber: 2, answer: "ANS-B", marks: 5 },
  ]);
});

Deno.test("paperExportDocument keeps a 100%-bank paper intact", () => {
  const items = [
    item("approved", "Bank Q1", "A1"),
    item("approved", "Bank Q2", "A2"),
    item("approved", "Bank Q3", "A3"),
  ];
  const doc = paperExportDocument(paper(), items);
  assertEquals((doc.questions as unknown[]).length, 3);
});
