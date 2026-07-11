// W2.8 Stage-2 semantic cache — pure/DB-free unit tests.

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  findNearestCachedResponse,
  questionHash,
  semanticCacheAvailable,
  semanticMaxDistance,
  vectorLiteral,
} from "./ai_semantic_cache_repository.ts";
import { embedText } from "./embeddings_client.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

function mockDb(
  responders: Array<{ match: string; rows: unknown[] }>,
): { db: TenantQueryClient; calls: Array<{ sql: string; args: unknown[] }> } {
  const calls: Array<{ sql: string; args: unknown[] }> = [];
  return {
    calls,
    db: {
      queryObject: <T>(sql: string, args: unknown[] = []): Promise<T[]> => {
        calls.push({ sql, args });
        const hit = responders.find((r) => sql.includes(r.match));
        return Promise.resolve((hit?.rows ?? []) as T[]);
      },
      // deno-lint-ignore no-explicit-any
    } as any as TenantQueryClient,
  };
}

const SCOPE = { organizationId: "org-1", schoolId: "sch-1" };

Deno.test("questionHash: normalized (case/whitespace) → identical hashes", async () => {
  const a = await questionHash("When is  Aarav's fee due?");
  const b = await questionHash("  when is aarav's fee due?  ");
  assertEquals(a, b);
  assert(a.length === 64);
  const c = await questionHash("when is Diya's fee due?");
  assert(a !== c);
});

Deno.test("vectorLiteral: pgvector shape, non-finite values zeroed", () => {
  assertEquals(vectorLiteral([0.1, -0.2, NaN]), "[0.1,-0.2,0]");
});

Deno.test("semanticMaxDistance: env-tunable with a safe default", () => {
  Deno.env.delete("AI_SEMANTIC_CACHE_MAX_DISTANCE");
  assertEquals(semanticMaxDistance(), 0.12);
  Deno.env.set("AI_SEMANTIC_CACHE_MAX_DISTANCE", "0.2");
  assertEquals(semanticMaxDistance(), 0.2);
  Deno.env.set("AI_SEMANTIC_CACHE_MAX_DISTANCE", "9");
  assertEquals(semanticMaxDistance(), 0.12, "out-of-range falls to default");
  Deno.env.delete("AI_SEMANTIC_CACHE_MAX_DISTANCE");
});

Deno.test("availability probe: absent table (or error) → dormant, never throws", async () => {
  const absent = mockDb([{ match: "to_regclass", rows: [{ reg: null }] }]);
  assertEquals(await semanticCacheAvailable(absent.db), false);
  const present = mockDb([
    { match: "to_regclass", rows: [{ reg: "ai_semantic_cache_embeddings" }] },
  ]);
  assertEquals(await semanticCacheAvailable(present.db), true);
  const broken = mockDb([]);
  // deno-lint-ignore no-explicit-any
  (broken.db as any).queryObject = () => Promise.reject(new Error("db down"));
  assertEquals(await semanticCacheAvailable(broken.db), false);
});

Deno.test("nearest: hit within threshold serves the joined LIVE cache entry and bumps hit_count", async () => {
  const { db, calls } = mockDb([
    {
      match: "FROM ai_semantic_cache_embeddings e",
      rows: [{ id: "c-1", payload: "cached answer", model: "m", distance: 0.05 }],
    },
  ]);
  const hit = await findNearestCachedResponse(db, SCOPE, {
    surface: "copilot",
    language: "english",
    embedding: "[0.1,0.2]",
    maxDistance: 0.12,
  });
  assertEquals(hit, { payload: "cached answer", model: "m", distance: 0.05 });
  assert(calls.some((c) => c.sql.includes("hit_count = hit_count + 1")));
  assert(calls[0]!.sql.includes("expires_at IS NULL OR c.expires_at >"), "expired entries never serve");
});

Deno.test("nearest: beyond the distance ceiling → miss, no hit_count bump", async () => {
  const { db, calls } = mockDb([
    {
      match: "FROM ai_semantic_cache_embeddings e",
      rows: [{ id: "c-1", payload: "far answer", model: "m", distance: 0.4 }],
    },
  ]);
  const hit = await findNearestCachedResponse(db, SCOPE, {
    surface: "copilot",
    language: "english",
    embedding: "[0.1,0.2]",
    maxDistance: 0.12,
  });
  assertEquals(hit, null);
  assert(!calls.some((c) => c.sql.includes("hit_count")));
});

// ─── Embeddings client gating ────────────────────────────────────────────────

Deno.test("embedText: unconfigured → null (Stage-2 dormant), no fetch attempted", async () => {
  Deno.env.delete("AI_EMBEDDINGS_API_KEY");
  let fetched = 0;
  const result = await embedText("hello", (() => {
    fetched++;
    return Promise.resolve(new Response("{}"));
  }) as typeof fetch);
  assertEquals(result, null);
  assertEquals(fetched, 0);
});

Deno.test("embedText: happy path returns the 1024-dim vector; wrong dims → null", async () => {
  Deno.env.set("AI_EMBEDDINGS_API_KEY", "test-key");
  try {
    const good = Array.from({ length: 1024 }, (_, i) => i / 1024);
    const ok = await embedText("hello", (() =>
      Promise.resolve(
        new Response(JSON.stringify({ data: [{ embedding: good }] }), { status: 200 }),
      )) as typeof fetch);
    assertEquals(ok?.length, 1024);

    const short = await embedText("hello", (() =>
      Promise.resolve(
        new Response(JSON.stringify({ data: [{ embedding: [1, 2, 3] }] }), { status: 200 }),
      )) as typeof fetch);
    assertEquals(short, null);

    const failed = await embedText("hello", (() =>
      Promise.resolve(new Response("nope", { status: 500 }))) as typeof fetch);
    assertEquals(failed, null);
  } finally {
    Deno.env.delete("AI_EMBEDDINGS_API_KEY");
  }
});
