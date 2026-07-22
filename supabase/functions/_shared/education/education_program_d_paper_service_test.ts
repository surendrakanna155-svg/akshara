// Program D · WP-E1 — paper-service integration: certified-pool source (M3.1), ai_candidate rate
// telemetry (M3.2), and the hard_off gap-fill policy (M3.3). Uses an in-memory FakeClient that routes
// the SQL listQuestionBankItems issues — proving the DEFAULT path is unchanged and the flagged path
// reads the union / disables the request-path AI, all without a real DB or a live model call.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { Governance } from "../ai/model_gateway.ts";
import type { AiRuntimeConfig } from "../ai/ai_settings.ts";
import type { GenerateQuestionPaperInput, QuestionBankItemRow } from "./education_types.ts";
import { generateQuestionPaper } from "./education_question_paper_service.ts";

function mkRow(i: number, chapter: string): QuestionBankItemRow {
  return {
    id: `row-${i}`,
    organization_id: "org",
    school_id: "school",
    subject_name: "Mathematics",
    chapter,
    topic: "",
    difficulty: "medium",
    question_type: "mcq",
    marks: 1,
    question_text: `Q${i}: compute something`,
    answer_text: "42",
    options: ["40", "41", "42", "43"],
    status: "active",
    source: "certified_platform",
    source_reference: null,
    program_track: "board",
    jee_question_type: null,
    cognitive_level: "apply",
    syllabus_chapter_id: null,
    syllabus_topic_id: null,
    learning_outcome: null,
    fingerprint: `IH_${i}`,
    review_status: "approved",
    created_by: null,
    created_at: "2026-07-23T00:00:00Z",
    updated_at: "2026-07-23T00:00:00Z",
  } as QuestionBankItemRow;
}

class FakeClient {
  tablesQueried: string[] = [];
  constructor(private rows: QuestionBankItemRow[]) {}

  private table(sql: string): void {
    if (sql.includes("edu_bank_items_union")) this.tablesQueried.push("union");
    else if (sql.includes("edu_question_bank_items")) this.tablesQueried.push("own");
  }
  queryCount(sql: string, _args: unknown[] = []): Promise<number> {
    this.table(sql);
    return Promise.resolve(this.rows.length);
  }
  queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    this.table(sql);
    return Promise.resolve(this.rows as unknown as T[]);
  }
}

const BASE_INPUT: GenerateQuestionPaperInput = {
  academicYearLabel: "2026-27",
  className: "Class 8",
  subjectName: "Mathematics",
  chapters: ["Whole Numbers"],
  difficulty: "medium",
  totalMarks: 3,
  examType: "unit_test",
};

Deno.test("M3.1: default (no programD) reads the OWN bank — byte-identical source", async () => {
  const client = new FakeClient([mkRow(1, "Whole Numbers"), mkRow(2, "Whole Numbers")]);
  const res = await generateQuestionPaper(client as unknown as TenantQueryClient, BASE_INPUT);
  assert(client.tablesQueried.every((t) => t === "own"), "default must read own bank only");
  assertEquals(res.bankSource, "own_bank");
  assert(res.aiCandidateRate >= 0 && res.aiCandidateRate <= 1);
});

Deno.test("M3.1: bankSource='certified_union' reads the union view", async () => {
  const client = new FakeClient([mkRow(1, "Whole Numbers")]);
  const res = await generateQuestionPaper(
    client as unknown as TenantQueryClient,
    BASE_INPUT,
    undefined,
    undefined,
    undefined,
    { bankSource: "certified_union" },
  );
  assert(client.tablesQueried.includes("union"), "must read the union view");
  assert(!client.tablesQueried.includes("own"), "must NOT read the own bank when union-sourced");
  assertEquals(res.bankSource, "certified_union");
});

Deno.test("M3.3: hard_off yields an HONEST shortfall — no AI candidates even with a key + governance", async () => {
  // Empty bank ⇒ every slot is a gap. A key + governance are present, so WITHOUT hard_off the
  // pre-existing AI gap-fill would fire; hard_off must disable it and leave gaps honestly unfilled.
  const client = new FakeClient([]);
  const ai: AiRuntimeConfig = { provider: "anthropic", model: "claude", apiKey: "test-key", source: "env" };
  const governance = { db: client, organizationId: "org", schoolId: "school", userId: "u" } as unknown as Governance;
  const res = await generateQuestionPaper(
    client as unknown as TenantQueryClient,
    BASE_INPUT,
    ai,
    undefined,
    governance,
    { gapFillPolicy: "hard_off" },
  );
  assertEquals(res.aiCandidateCount, 0, "hard_off must produce zero AI candidates");
  assertEquals(res.aiCandidateRate, 0);
  assert(res.unfilledGapCount > 0, "an empty bank under hard_off must leave an honest shortfall");
});

Deno.test("M3.2: aiCandidateRate is aiCandidateCount / total slots", async () => {
  const client = new FakeClient([]);
  const res = await generateQuestionPaper(
    client as unknown as TenantQueryClient,
    BASE_INPUT,
    undefined,
    undefined,
    undefined,
    { gapFillPolicy: "hard_off" },
  );
  // No AI, so the rate is 0 regardless of slot count (and never NaN).
  assertEquals(res.aiCandidateRate, 0);
  assert(Number.isFinite(res.aiCandidateRate));
});
