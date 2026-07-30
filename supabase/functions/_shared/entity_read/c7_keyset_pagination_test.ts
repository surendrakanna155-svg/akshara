// ICA-C7 — keyset (cursor) pagination on the generic entity read store.
//
// Proves the seek-based path returns correct pages/cursors and never scans an offset:
// page 1 (no cursor) → page N (cursor = previous nextCursor) → last page (nextCursor
// null, hasMore false), plus the pure keysetPageOf helper and the pageSize+1 boundary.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { keysetPageOf } from "../academic/academic_pagination.ts";
import { createEntityReadStore } from "./entity_read_store.ts";

const ORG = "org-1";
const SCHOOL = "school-1";
const TYPE = "widget";

// Mock db implementing ONLY the C7 keyset query:
//   SELECT id, payload … AND ($4::text IS NULL OR id > $4) ORDER BY id LIMIT $5
//   args = [org, school, entityType, cursor|null, limit]
class KeysetMockDb {
  seenLimits: number[] = [];
  constructor(
    private readonly rows: Array<{ entity_type: string; id: string; payload: Record<string, unknown> }>,
  ) {}
  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (!sql.includes("id > $4")) throw new Error(`unexpected sql: ${sql}`);
    const entityType = args[2] as string;
    const cursor = args[3] as string | null;
    const limit = args[4] as number;
    this.seenLimits.push(limit);
    const items = this.rows
      .filter((r) => r.entity_type === entityType && (cursor === null || r.id > cursor))
      .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))
      .slice(0, limit);
    return items.map((r) => ({ id: r.id, payload: r.payload })) as T[];
  }
}

function rows(n: number) {
  return Array.from({ length: n }, (_, i) => ({
    entity_type: TYPE,
    id: `id-${i + 1}`,
    payload: { n: i + 1 },
  }));
}

const store = createEntityReadStore("read_models", "Test");

Deno.test("C7: keyset walks the full set page-by-page via nextCursor, no offset", async () => {
  const db = new KeysetMockDb(rows(5)) as unknown as TenantQueryClient & { seenLimits: number[] };

  const p1 = await store.listEntitiesKeyset(db, ORG, SCHOOL, TYPE, { pageSize: 2 });
  assertEquals(p1.items, [{ n: 1 }, { n: 2 }]);
  assertEquals(p1.hasMore, true);
  assertEquals(p1.nextCursor, "id-2");

  const p2 = await store.listEntitiesKeyset(db, ORG, SCHOOL, TYPE, { cursor: p1.nextCursor, pageSize: 2 });
  assertEquals(p2.items, [{ n: 3 }, { n: 4 }]);
  assertEquals(p2.hasMore, true);
  assertEquals(p2.nextCursor, "id-4");

  const p3 = await store.listEntitiesKeyset(db, ORG, SCHOOL, TYPE, { cursor: p2.nextCursor, pageSize: 2 });
  assertEquals(p3.items, [{ n: 5 }]);
  assertEquals(p3.hasMore, false);
  assertEquals(p3.nextCursor, null);

  // Always fetches pageSize+1 (the has-more probe) — never a COUNT or an OFFSET.
  assertEquals((db as unknown as { seenLimits: number[] }).seenLimits.every((l) => l === 3), true);
});

Deno.test("C7: an exact-fit final page reports hasMore=false / nextCursor=null", async () => {
  const db = new KeysetMockDb(rows(4)) as unknown as TenantQueryClient;
  const p2 = await store.listEntitiesKeyset(db, ORG, SCHOOL, TYPE, { cursor: "id-2", pageSize: 2 });
  assertEquals(p2.items, [{ n: 3 }, { n: 4 }]);
  assertEquals(p2.hasMore, false);
  assertEquals(p2.nextCursor, null);
});

Deno.test("C7: an empty result yields no items, no cursor, no more", async () => {
  const db = new KeysetMockDb([]) as unknown as TenantQueryClient;
  const r = await store.listEntitiesKeyset(db, ORG, SCHOOL, TYPE, { pageSize: 10 });
  assertEquals(r.items, []);
  assertEquals(r.hasMore, false);
  assertEquals(r.nextCursor, null);
});

Deno.test("C7: pageSize is clamped to 1..100", async () => {
  const db = new KeysetMockDb(rows(3)) as unknown as TenantQueryClient;
  const tooBig = await store.listEntitiesKeyset(db, ORG, SCHOOL, TYPE, { pageSize: 9999 });
  assertEquals(tooBig.pageSize, 100);
  const tooSmall = await store.listEntitiesKeyset(db, ORG, SCHOOL, TYPE, { pageSize: 0 });
  assertEquals(tooSmall.pageSize, 1);
});

Deno.test("C7: keysetPageOf helper derives hasMore/nextCursor from a pageSize+1 fetch", () => {
  const idOf = (r: { id: string }) => r.id;
  const more = keysetPageOf([{ id: "a" }, { id: "b" }, { id: "c" }], 2, idOf);
  assertEquals(more.rows.map(idOf), ["a", "b"]);
  assertEquals(more.hasMore, true);
  assertEquals(more.nextCursor, "b");

  const last = keysetPageOf([{ id: "a" }, { id: "b" }], 2, idOf);
  assertEquals(last.rows.map(idOf), ["a", "b"]);
  assertEquals(last.hasMore, false);
  assertEquals(last.nextCursor, null);

  const empty = keysetPageOf([], 2, idOf);
  assertEquals(empty.rows, []);
  assertEquals(empty.hasMore, false);
  assertEquals(empty.nextCursor, null);
});
