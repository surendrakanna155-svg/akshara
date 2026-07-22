// Program D · M4.3/M4.4 integration — certified-pool builder + vector fetch tests. Deterministic, offline.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { QuestionBankItemRow } from "./education_types.ts";
import { buildCertifiedPool } from "./education_certified_pool.ts";
import { getNearDupVectors } from "./education_repository.ts";

function row(id: string, fp: string, extra: Partial<QuestionBankItemRow> = {}): QuestionBankItemRow {
  return {
    id,
    organization_id: "org",
    school_id: "school",
    subject_name: "Mathematics",
    chapter: "Whole Numbers",
    topic: "",
    difficulty: "medium",
    question_type: "mcq",
    marks: 1,
    question_text: `Q ${id}`,
    answer_text: "42",
    options: [],
    status: "active",
    source: "certified_platform",
    source_reference: null,
    program_track: "board",
    jee_question_type: null,
    cognitive_level: "apply",
    syllabus_chapter_id: null,
    syllabus_topic_id: null,
    learning_outcome: null,
    fingerprint: fp,
    review_status: "approved",
    created_by: null,
    created_at: "2026-07-23T00:00:00Z",
    updated_at: "2026-07-23T00:00:00Z",
    times_used: 0,
    last_used_at: null,
    ...extra,
  } as QuestionBankItemRow;
}

const A = row("a", "IH_a");
const B = row("b", "IH_b");
const C = row("c", "IH_c");

Deno.test("buildCertifiedPool: no options ⇒ pool returned untouched (byte-identical)", () => {
  const res = buildCertifiedPool([A, B, C], new Map());
  assertEquals(res.pool.map((r) => r.id), ["a", "b", "c"]);
  assertEquals(res.dropped.length, 0);
  assertEquals(res.order.length, 0);
});

Deno.test("buildCertifiedPool: near-dup filter drops a paraphrase (vector) clone, preserving order", () => {
  const vectors = new Map<string, number[]>([
    ["IH_a", [1, 0, 0]],
    ["IH_b", [0.999, 0.044, 0]], // ~parallel to A ⇒ cosine ≥ 0.82 ⇒ dup of A
    ["IH_c", [0, 0, 1]], // orthogonal ⇒ kept
  ]);
  const res = buildCertifiedPool([A, B, C], vectors, { nearDupFilter: true });
  assertEquals(res.pool.map((r) => r.id), ["a", "c"]); // b dropped, order preserved
  assertEquals(res.dropped.length, 1);
  assertEquals(res.dropped[0].id, "b");
  assertEquals(res.dropped[0].similarTo, "a");
  assert(res.dropped[0].score >= 0.82);
});

Deno.test("buildCertifiedPool: no vector ⇒ exact-fingerprint fallback dedup", () => {
  const dupFp = row("b2", "IH_a"); // same fingerprint as A, no vectors provided
  const res = buildCertifiedPool([A, dupFp, C], new Map(), { nearDupFilter: true });
  assertEquals(res.pool.map((r) => r.id).sort(), ["a", "c"]);
  assertEquals(res.dropped[0].id, "b2");
});

Deno.test("buildCertifiedPool: ranking prefers the unseen item", () => {
  const used = row("used", "IH_used", { times_used: 9, last_used_at: "2026-07-01T00:00:00Z" });
  const unseen = row("unseen", "IH_unseen", { times_used: 0, last_used_at: null });
  const res = buildCertifiedPool([used, unseen], new Map(), { rank: true, nowMs: 1_800_000_000_000 });
  assertEquals(res.pool[0].id, "unseen"); // prefer-unseen ranks the never-used item first
  assertEquals(res.order.length, 2);
  assert(res.order[0].score >= res.order[1].score);
});

Deno.test("buildCertifiedPool: deterministic — identical inputs give identical output", () => {
  const v = new Map<string, number[]>([["IH_a", [1, 0]], ["IH_b", [0, 1]]]);
  const r1 = buildCertifiedPool([A, B], v, { nearDupFilter: true, rank: true, nowMs: 1 });
  const r2 = buildCertifiedPool([A, B], v, { nearDupFilter: true, rank: true, nowMs: 1 });
  assertEquals(JSON.stringify(r1), JSON.stringify(r2));
});

// ── getNearDupVectors ─────────────────────────────────────────────────────────────────────────────

class VecFakeDb {
  constructor(private store: Record<string, number[]>) {}
  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    const s = sql.replace(/\s+/g, " ").trim();
    if (s.startsWith("SELECT content_hash, near_dup_embedding FROM edu_platform_question_bank")) {
      const want: string[] = args[0] ?? [];
      const rows = want
        .filter((h) => this.store[h])
        .map((h) => ({ content_hash: h, near_dup_embedding: this.store[h] }));
      return Promise.resolve(rows as unknown as T[]);
    }
    throw new Error(`unrouted SQL: ${s}`);
  }
}

Deno.test("getNearDupVectors: maps content_hash → vector; empty input ⇒ empty map", async () => {
  const db = new VecFakeDb({ "IH_a": [1, 2, 3], "IH_b": [4, 5, 6] });
  const empty = await getNearDupVectors(db as unknown as TenantQueryClient, []);
  assertEquals(empty.size, 0);
  const got = await getNearDupVectors(db as unknown as TenantQueryClient, ["IH_a", "IH_missing"]);
  assertEquals(got.size, 1);
  assertEquals(got.get("IH_a"), [1, 2, 3]);
});
