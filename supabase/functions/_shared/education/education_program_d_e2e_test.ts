// Program D — END-TO-END fixture integration. Chains the REAL code paths through one FakeDb that models
// both the platform bank (written by the importer) and the union view (read by the paper service):
//
//   golden export artifact  →  importPlatformBatch  →  edu_platform_question_bank (adopted)
//        →  edu_bank_items_union  →  generateQuestionPaper (certified pool, near-dup, prefer-unseen)
//
// Proves certified content flows offline→online→assembly deterministically, with NO real DB and NO model
// call. (A DB-backed run of the actual migrations/RLS is owner-gated on the VPS — this is the local proof.)

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { type ExportArtifact, importPlatformBatch } from "./education_platform_import.ts";
import { generateQuestionPaper } from "./education_question_paper_service.ts";
import type { GenerateQuestionPaperInput, QuestionBankItemRow } from "./education_types.ts";
import artifactJson from "./__tests__/fixtures/export_artifact.json" with { type: "json" };

const GOLDEN = artifactJson as unknown as ExportArtifact;

interface PlatformStored {
  content_hash: string;
  status: string;
  subject_name: string;
  chapter: string;
  difficulty: string;
  question_type: string;
  marks: number;
  question_text: string;
  answer_text: string;
  options: unknown;
  cognitive_level: string | null;
  program_track: string;
  concept_uuid: string;
  near_dup_embedding: number[];
}

/** One FakeDb modelling: (1) the platform bank the importer writes, and (2) the union view + vector fetch
 * the paper service reads. A school is assumed to have adopted every active platform item. */
class E2EDb {
  platform = new Map<string, PlatformStored>();

  // deno-lint-ignore no-explicit-any
  queryCount(sql: string, _args: any[] = []): Promise<number> {
    const s = sql.replace(/\s+/g, " ").trim();
    if (s.includes("FROM edu_bank_items_union")) {
      return Promise.resolve([...this.platform.values()].filter((r) => r.status === "active").length);
    }
    throw new Error(`unrouted count SQL: ${s}`);
  }

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    const s = sql.replace(/\s+/g, " ").trim();

    // ── importer writes ──
    if (s.startsWith("SELECT content_hash, status FROM edu_platform_question_bank")) {
      return Promise.resolve(
        [...this.platform.values()].map((r) => ({ content_hash: r.content_hash, status: r.status })) as unknown as T[],
      );
    }
    if (s.startsWith("INSERT INTO edu_platform_question_bank")) {
      this.platform.set(args[0], {
        content_hash: args[0], status: "active", subject_name: args[2], chapter: args[3],
        difficulty: args[5], question_type: args[7], marks: Number(args[8]), question_text: args[9],
        answer_text: args[10], options: JSON.parse(args[11]), cognitive_level: args[13],
        program_track: args[14], concept_uuid: args[16], near_dup_embedding: JSON.parse(args[17]),
      });
      return Promise.resolve([] as T[]);
    }
    if (s.startsWith("UPDATE edu_platform_question_bank SET")) {
      const row = this.platform.get(args[0]);
      if (row && s.includes("status = 'tombstoned'")) row.status = "tombstoned";
      else if (row) row.status = "active";
      return Promise.resolve([] as T[]);
    }

    // ── paper-service reads: the union view projected to QuestionBankItemRow ──
    if (s.startsWith("SELECT * FROM edu_bank_items_union")) {
      const rows = [...this.platform.values()]
        .filter((r) => r.status === "active")
        .map((r) => this.toUnionRow(r));
      return Promise.resolve(rows as unknown as T[]);
    }
    // ── near-dup vectors ──
    if (s.startsWith("SELECT content_hash, near_dup_embedding FROM edu_platform_question_bank")) {
      const want: string[] = args[0] ?? [];
      return Promise.resolve(
        want.filter((h) => this.platform.has(h)).map((h) => ({
          content_hash: h, near_dup_embedding: this.platform.get(h)!.near_dup_embedding,
        })) as unknown as T[],
      );
    }
    throw new Error(`unrouted SQL: ${s}`);
  }

  private toUnionRow(r: PlatformStored): QuestionBankItemRow {
    return {
      id: r.content_hash, organization_id: "org", school_id: "school", subject_name: r.subject_name,
      chapter: r.chapter, topic: "", difficulty: r.difficulty, question_type: r.question_type,
      marks: r.marks, question_text: r.question_text, answer_text: r.answer_text, options: r.options,
      status: "active", source: "certified_platform", source_reference: null, program_track: r.program_track,
      jee_question_type: null, cognitive_level: r.cognitive_level, syllabus_chapter_id: null,
      syllabus_topic_id: null, learning_outcome: null, fingerprint: r.content_hash, review_status: "approved",
      created_by: null, created_at: "2026-07-23T00:00:00Z", updated_at: "2026-07-23T00:00:00Z",
      times_used: 0, last_used_at: null,
    } as QuestionBankItemRow;
  }

  chapters(): string[] {
    return [...new Set([...this.platform.values()].map((r) => r.chapter))];
  }
}

Deno.test("E2E: export artifact → importer → union → deterministic certified paper", async () => {
  const db = new E2EDb();

  // 1. Import the golden certified artifact into the platform bank.
  const imp = await importPlatformBatch(db as unknown as TenantQueryClient, GOLDEN);
  assertEquals(imp.inserted, 12);
  assertEquals(db.platform.size, 12);

  // 2. A teacher request served from the CERTIFIED union pool, with near-dup + prefer-unseen enabled.
  const input: GenerateQuestionPaperInput = {
    academicYearLabel: "2026-27",
    className: "Class 8",
    subjectName: "Mathematics",
    chapters: db.chapters(),
    difficulty: "mixed",
    totalMarks: 4,
    examType: "unit_test",
    questionTypeMix: { mcq: 4 },
  };
  const programD = {
    bankSource: "certified_union" as const,
    nearDupFilter: true,
    preferUnseen: true,
    rankPool: true,
    referenceAt: "2026-07-23T00:00:00Z",
    gapFillPolicy: "hard_off" as const, // no request-path AI — an under-fill is an honest shortfall
  };

  const paper = await generateQuestionPaper(
    db as unknown as TenantQueryClient, input, undefined, undefined, undefined, programD,
  );

  // 3. It came from the certified union, filled from certified content, with ZERO live-AI.
  assertEquals(paper.bankSource, "certified_union");
  assertEquals(paper.aiCandidateCount, 0); // hard_off ⇒ no request-path AI
  assert(paper.bankReuseCount > 0, "the paper should be filled from certified content");
  for (const item of paper.items) {
    assertEquals(item.source, "bank"); // every placed item is a real certified bank item, never ai_candidate
  }

  // 4. Determinism: same request + same bank ⇒ byte-identical paper.
  const again = await generateQuestionPaper(
    db as unknown as TenantQueryClient, input, undefined, undefined, undefined, programD,
  );
  assertEquals(
    again.items.map((i) => i.bankItemId),
    paper.items.map((i) => i.bankItemId),
  );
});

Deno.test("E2E: a recall (tombstone) at re-import drops the item from the served pool", async () => {
  const db = new E2EDb();
  await importPlatformBatch(db as unknown as TenantQueryClient, GOLDEN);

  // Re-export drops one certified item → importer tombstones it.
  const reduced = JSON.parse(JSON.stringify(GOLDEN)) as ExportArtifact;
  const dropped = reduced.rows[0].content_hash;
  reduced.rows = reduced.rows.slice(1);
  reduced.manifest.row_count = reduced.rows.length;
  // recompute the freeze fingerprint for the reduced set (import refuses a stale one)
  const { recomputeContentFp } = await import("./education_platform_import.ts");
  reduced.manifest.content_fp = await recomputeContentFp(reduced.rows);
  const res = await importPlatformBatch(db as unknown as TenantQueryClient, reduced);
  assertEquals(res.tombstoned, 1);

  const paper = await generateQuestionPaper(
    db as unknown as TenantQueryClient,
    {
      academicYearLabel: "2026-27", className: "Class 8", subjectName: "Mathematics",
      chapters: db.chapters(), difficulty: "mixed", totalMarks: 12, examType: "unit_test",
      questionTypeMix: { mcq: 12 },
    },
    undefined, undefined, undefined,
    { bankSource: "certified_union", gapFillPolicy: "hard_off" },
  );
  // The tombstoned item can never be placed.
  assert(!paper.items.some((i) => i.bankItemId === dropped), "a recalled item must not appear in a paper");
});
