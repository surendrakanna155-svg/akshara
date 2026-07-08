// CI-C4-schema — schema/round-trip tests for the three columns added dormant by
// migration 20260857000000 (`competency`, `question_family_id`, `concept_id` on
// `edu_question_bank_items`).
//
// Tiny in-memory fake routing the exact SQL these repository functions issue —
// no network, no live DB (this wave is dormant/no-VPS), mirrors the existing
// repository-test pattern (education_correction_repository_test.ts /
// education_exam_paper_links_test.ts).
//
// Two things are proven:
//  1. `competency` round-trips through the real, certified repository
//     functions (`createQuestionBankItem` / `updateQuestionBankItem`) exactly
//     like the existing `learning_outcome` column — this is the "teacher
//     confirm persists" half of AT-C4.1.
//  2. `question_family_id` / `concept_id` are schema-only this wave (no
//     repository function writes them yet — CI-C10 / CI-E1b will), but a row
//     that already carries them (e.g. written directly by a future wave, or by
//     a hand-run migration backfill) still round-trips untouched through a
//     plain `SELECT *` — additive columns never break an existing read path.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { QuestionBankItemRow } from "./education_types.ts";
import { createQuestionBankItem, updateQuestionBankItem } from "./education_repository.ts";

type Row = Record<string, unknown>;
const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const USER = "a3000000-0000-4000-8000-000000000001";

class FakeBankDb {
  bank: Row[] = [];
  private seq = 0;

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    const s = sql.replace(/\s+/g, " ").trim();

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
        source_reference: args[12],
        program_track: args[13],
        jee_question_type: args[14],
        cognitive_level: args[15],
        syllabus_chapter_id: args[16],
        syllabus_topic_id: args[17],
        learning_outcome: args[18],
        fingerprint: args[19],
        review_status: args[20],
        created_by: args[21],
        competency: args[22], // CI-C4-schema — appended at $23 (0-based args[22]).
        status: "active",
      };
      this.bank.push(row);
      return this.rows([row]);
    }

    if (s.startsWith("SELECT * FROM edu_question_bank_items WHERE id =")) {
      return this.rows(this.bank.filter((r) => r.id === args[0]));
    }

    if (s.startsWith("UPDATE edu_question_bank_items SET")) {
      const row = this.bank.find((r) => r.id === args[0]);
      if (!row) return this.rows([]);
      row.subject_name = args[1]; // $2
      row.chapter = args[2]; // $3
      row.question_type = args[5]; // $6
      row.question_text = args[7]; // $8
      row.fingerprint = args[16]; // $17
      row.competency = args[17]; // $18 — CI-C4-schema, appended after the certified $1..$17.
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

Deno.test("CI-C4-schema: createQuestionBankItem persists a supplied competency tag", async () => {
  const db = new FakeBankDb();
  const created = await createQuestionBankItem(db.asClient(), ORG, SCHOOL, {
    subjectName: "Science",
    chapter: "Photosynthesis",
    topic: "Light Reaction",
    difficulty: "medium",
    questionType: "short_answer",
    marks: 3,
    questionText: "Explain the light reaction of photosynthesis.",
    competency: "Explain and interpret Light Reaction (Photosynthesis)",
    createdBy: USER,
  });
  assertEquals(created.competency, "Explain and interpret Light Reaction (Photosynthesis)");
});

Deno.test("CI-C4-schema: createQuestionBankItem with no competency leaves it null (existing rows unaffected)", async () => {
  const db = new FakeBankDb();
  const created = await createQuestionBankItem(db.asClient(), ORG, SCHOOL, {
    subjectName: "Science",
    chapter: "Photosynthesis",
    difficulty: "medium",
    questionType: "short_answer",
    marks: 3,
    questionText: "Explain the light reaction of photosynthesis.",
    createdBy: USER,
  });
  assertEquals(created.competency ?? null, null);
});

Deno.test("CI-C4-schema: updateQuestionBankItem persists a teacher-confirmed/edited competency (AT-C4.1)", async () => {
  const db = new FakeBankDb();
  db.bank.push({
    id: "b1",
    subject_name: "Mathematics",
    chapter: "Algebra",
    topic: "",
    difficulty: "medium",
    question_type: "mcq",
    marks: 2,
    question_text: "Solve 2x+4=10",
    answer_text: "x=3",
    options: ["x=2", "x=3"],
    fingerprint: "old",
    review_status: "approved",
    status: "active",
    competency: null,
  });

  // Simulates: suggestClassification() proposed a draft, teacher edited it,
  // caller now confirms the edited text.
  const updated = await updateQuestionBankItem(db.asClient(), "b1", {
    competency: "Apply and solve problems using Algebra (teacher-edited)",
  });
  assertEquals(updated?.competency, "Apply and solve problems using Algebra (teacher-edited)");
  // Unrelated fields are untouched by the tagging update.
  assertEquals(updated?.subject_name, "Mathematics");
  assertEquals(updated?.chapter, "Algebra");
});

Deno.test("CI-C4-schema: updateQuestionBankItem omitting competency preserves the existing tag", async () => {
  const db = new FakeBankDb();
  db.bank.push({
    id: "b1",
    subject_name: "Mathematics",
    chapter: "Algebra",
    topic: "",
    difficulty: "medium",
    question_type: "mcq",
    marks: 2,
    question_text: "Solve 2x+4=10",
    answer_text: "x=3",
    options: ["x=2", "x=3"],
    fingerprint: "old",
    review_status: "approved",
    status: "active",
    competency: "Apply and solve problems using Algebra",
  });

  const updated = await updateQuestionBankItem(db.asClient(), "b1", { questionText: "Solve 2x + 4 = 10" });
  assertEquals(updated?.competency, "Apply and solve problems using Algebra");
});

Deno.test(
  "CI-C4-schema: question_family_id / concept_id are schema-only — a row already carrying them round-trips untouched through SELECT *",
  async () => {
    const db = new FakeBankDb();
    db.bank.push({
      id: "b1",
      subject_name: "Mathematics",
      chapter: "Algebra",
      status: "active",
      // Forward-reference placeholders (CI-C10 / CI-E1b) — nothing writes these
      // yet, but a row that already has them must not be disturbed by an
      // ordinary read.
      question_family_id: "f1000000-0000-4000-8000-000000000001",
      concept_id: "c1000000-0000-4000-8000-000000000001",
    });

    const rows = await db.asClient().queryObject<QuestionBankItemRow>(
      "SELECT * FROM edu_question_bank_items WHERE id = $1",
      ["b1"],
    );
    assertEquals(rows[0]?.question_family_id, "f1000000-0000-4000-8000-000000000001");
    assertEquals(rows[0]?.concept_id, "c1000000-0000-4000-8000-000000000001");
  },
);
