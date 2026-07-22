// Program D · M4.1 — exposure write-path tests. FakeDb routes the exact SQL recordItemExposures issues.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { recordItemExposures } from "./education_repository.ts";

const ORG = "org-1";
const SCHOOL = "school-1";

class FakeDb {
  exposures: Array<{ exam_id: string | null; bank_item_id: string }> = [];
  ownBank = new Map<string, number>(); // id -> times_used
  constructor(ownIds: string[]) {
    for (const id of ownIds) this.ownBank.set(id, 0);
  }
  // deno-lint-ignore no-explicit-any
  queryCount(sql: string, args: any[] = []): Promise<number> {
    const s = sql.replace(/\s+/g, " ").trim();
    if (s.startsWith("SELECT count(*)::text AS count FROM edu_item_exposures")) {
      const [, , examId, itemId] = args;
      return Promise.resolve(
        this.exposures.filter((e) => e.exam_id === examId && e.bank_item_id === itemId).length,
      );
    }
    throw new Error(`unrouted count SQL: ${s}`);
  }
  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    const s = sql.replace(/\s+/g, " ").trim();
    if (s.startsWith("INSERT INTO edu_item_exposures")) {
      this.exposures.push({ exam_id: args[4] ?? null, bank_item_id: args[2] });
      return Promise.resolve([] as T[]);
    }
    if (s.startsWith("UPDATE edu_question_bank_items SET times_used")) {
      const id = args[0];
      if (this.ownBank.has(id)) {
        this.ownBank.set(id, (this.ownBank.get(id) ?? 0) + 1);
        return Promise.resolve([{ id }] as unknown as T[]);
      }
      return Promise.resolve([] as T[]); // platform item ⇒ no own-bank row
    }
    throw new Error(`unrouted SQL: ${s}`);
  }
}

Deno.test("M4.1: logs one exposure per item and increments own-bank counters", async () => {
  const db = new FakeDb(["own-a", "own-b"]);
  const res = await recordItemExposures(db as unknown as TenantQueryClient, ORG, SCHOOL, {
    items: [{ bankItemId: "own-a" }, { bankItemId: "own-b" }],
    examId: "exam-1",
  });
  assertEquals(res.logged, 2);
  assertEquals(res.incremented, 2);
  assertEquals(db.exposures.length, 2);
  assertEquals(db.ownBank.get("own-a"), 1);
});

Deno.test("M4.1: idempotent per (exam, item) — re-record does not double-log or double-increment", async () => {
  const db = new FakeDb(["own-a"]);
  const opts = { items: [{ bankItemId: "own-a" }], examId: "exam-1" };
  await recordItemExposures(db as unknown as TenantQueryClient, ORG, SCHOOL, opts);
  const again = await recordItemExposures(db as unknown as TenantQueryClient, ORG, SCHOOL, opts);
  assertEquals(again.logged, 0);
  assertEquals(again.incremented, 0);
  assertEquals(db.exposures.length, 1);
  assertEquals(db.ownBank.get("own-a"), 1);
});

Deno.test("M4.1: a certified-platform item is logged but never increments a shared platform row", async () => {
  const db = new FakeDb(["own-a"]); // 'plat-x' is NOT an own-bank row
  const res = await recordItemExposures(db as unknown as TenantQueryClient, ORG, SCHOOL, {
    items: [{ bankItemId: "plat-x" }],
    examId: "exam-2",
  });
  assertEquals(res.logged, 1);
  assertEquals(res.incremented, 0); // no own-bank counter touched (platform exposure is per-school log only)
  assert(db.exposures.some((e) => e.bank_item_id === "plat-x"));
});
