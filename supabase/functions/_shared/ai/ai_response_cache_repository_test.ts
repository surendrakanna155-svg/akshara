import { assert, assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type CacheKeyParts,
  invalidateCacheByEntityTags,
  lookupResponseCache,
  mintCacheKey,
  writeResponseCache,
} from "./ai_response_cache_repository.ts";

interface Captured {
  sql: string;
  params?: unknown[];
}

function fakeDb(opts: { select?: unknown[]; del?: unknown[] } = {}): {
  db: TenantQueryClient;
  calls: Captured[];
} {
  const calls: Captured[] = [];
  const db = {
    queryObject: (sql: string, params?: unknown[]) => {
      calls.push({ sql, params });
      const s = sql.trimStart();
      if (s.startsWith("SELECT")) return Promise.resolve((opts.select ?? []) as unknown[]);
      if (s.startsWith("DELETE")) return Promise.resolve((opts.del ?? []) as unknown[]);
      return Promise.resolve([] as unknown[]);
    },
    // deno-lint-ignore no-explicit-any
  } as any as TenantQueryClient;
  return { db, calls };
}

const SCOPE = { organizationId: "org-1", schoolId: "sch-1" };
const PARTS: CacheKeyParts = {
  surface: "copilot",
  schoolId: "sch-1",
  language: "english",
  model: "claude-opus-4-8",
  system: "read-only policy + facts",
  messages: [{ role: "user", content: "how many fees are due?" }],
};

Deno.test("mintCacheKey is deterministic, 64-hex, and sensitive to inputs", async () => {
  const k1 = await mintCacheKey(PARTS);
  const k2 = await mintCacheKey(PARTS);
  assertEquals(k1, k2);
  assertEquals(k1.length, 64);
  assert(/^[0-9a-f]{64}$/.test(k1));
  const changed = await mintCacheKey({
    ...PARTS,
    messages: [{ role: "user", content: "different question" }],
  });
  assert(k1 !== changed);
  // a different school must not collide even with the same question
  const otherSchool = await mintCacheKey({ ...PARTS, schoolId: "sch-2" });
  assert(k1 !== otherSchool);
});

Deno.test("lookupResponseCache returns a hit and increments hit_count", async () => {
  const { db, calls } = fakeDb({ select: [{ id: "c1", payload: "answer", model: "m" }] });
  const hit = await lookupResponseCache(db, SCOPE, "key-1");
  assertEquals(hit, { payload: "answer", model: "m" });
  assert(calls[0].sql.includes("SELECT"));
  assert(calls.some((c) => c.sql.includes("UPDATE ai_response_cache SET hit_count = hit_count + 1")));
});

Deno.test("lookupResponseCache returns null on a miss and does not update", async () => {
  const { db, calls } = fakeDb({ select: [] });
  assertEquals(await lookupResponseCache(db, SCOPE, "key-1"), null);
  assertEquals(calls.length, 1); // SELECT only, no UPDATE
});

Deno.test("writeResponseCache upserts with 10 params incl. ttl", async () => {
  const { db, calls } = fakeDb();
  await writeResponseCache(db, SCOPE, {
    cacheKey: "k",
    surface: "copilot",
    language: "english",
    payload: "p",
    entityTags: ["student:1:fees"],
    model: "claude-opus-4-8",
    tokensSaved: 12,
    ttlSeconds: 86_400,
  });
  assert(calls[0].sql.includes("INSERT INTO ai_response_cache"));
  assert(calls[0].sql.includes("ON CONFLICT"));
  assertEquals(calls[0].params?.length, 10);
  assertEquals(calls[0].params?.[6], ["student:1:fees"]); // entity_tags
  assertEquals(calls[0].params?.[9], 86_400); // ttl seconds
});

Deno.test("invalidateCacheByEntityTags is a no-op on empty tags", async () => {
  const { db, calls } = fakeDb();
  assertEquals(await invalidateCacheByEntityTags(db, SCOPE, []), 0);
  assertEquals(calls.length, 0);
});

Deno.test("invalidateCacheByEntityTags deletes tagged rows and returns the count", async () => {
  const { db, calls } = fakeDb({ del: [{ id: "a" }, { id: "b" }] });
  const n = await invalidateCacheByEntityTags(db, SCOPE, ["student:1:fees", "student:1:attendance"]);
  assertEquals(n, 2);
  assert(calls[0].sql.includes("DELETE FROM ai_response_cache"));
  assert(calls[0].sql.includes("entity_tags &&"));
});
