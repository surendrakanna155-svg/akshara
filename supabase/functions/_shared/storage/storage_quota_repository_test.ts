// PRC-A Batch 4 — storage quota: usage projection, record rules, quota math, health.
//
// ⚠ Scope. The fake DB pattern-matches SQL and evaluates neither the SUM nor RLS
// nor concurrency. So these prove the CODE-level contracts (projection shape,
// zero-delta drop, quota arithmetic incl. grace, health thresholds). They do NOT
// prove the usage SQL is correct on real Postgres, nor RLS isolation — those are
// live probes (see the Batch 4 live-cert suite). Nothing here justifies "certified".

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  readStorageUsage,
  recordStorageUsage,
  storageQuotaHealth,
  withinStorageQuota,
} from "./storage_quota_repository.ts";

const SCOPE = { organizationId: "org-1", schoolId: "sch-1" };

function fakeDb(rows: Record<string, unknown>[]): { db: TenantQueryClient; calls: { sql: string; params?: unknown[] }[] } {
  const calls: { sql: string; params?: unknown[] }[] = [];
  const db = {
    // deno-lint-ignore require-await
    async queryObject<T>(sql: string, params?: unknown[]): Promise<T[]> {
      calls.push({ sql, params });
      return rows as T[];
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

// ── usage projection ─────────────────────────────────────────────────────────
Deno.test("readStorageUsage sums delta_bytes for the org", async () => {
  const { db, calls } = fakeDb([{ used: 4096 }]);
  const { usedBytes } = await readStorageUsage(db, SCOPE);
  assertEquals(usedBytes, 4096);
  assertEquals(calls[0].sql.includes("sum(delta_bytes)"), true);
  assertEquals(calls[0].sql.includes("storage_usage_entries"), true);
  assertEquals(calls[0].params, ["org-1"]);
});

Deno.test("readStorageUsage: Postgres BIGINT comes back as a STRING and must not become NaN", async () => {
  const { db } = fakeDb([{ used: "9007199254740000" }]);
  const { usedBytes } = await readStorageUsage(db, SCOPE);
  assertEquals(usedBytes, 9007199254740000);
});

Deno.test("readStorageUsage: an empty result reads as zero, never NaN", async () => {
  const { db } = fakeDb([]);
  assertEquals((await readStorageUsage(db, SCOPE)).usedBytes, 0);
});

// ── record ───────────────────────────────────────────────────────────────────
Deno.test("recordStorageUsage appends a positive delta on upload", async () => {
  const { db, calls } = fakeDb([{ id: "e1" }]);
  const res = await recordStorageUsage(db, SCOPE, {
    deltaBytes: 1048576,
    category: "memories",
    objectKey: "org/sch/x.jpg",
    actorId: "u1",
  });
  assertEquals(res, { id: "e1" });
  assertEquals(calls[0].sql.includes("INSERT INTO storage_usage_entries"), true);
  assertEquals(calls[0].params?.[2], 1048576);
});

Deno.test("recordStorageUsage: a zero delta is a no-op (no INSERT, returns null)", async () => {
  const { db, calls } = fakeDb([{ id: "e1" }]);
  const res = await recordStorageUsage(db, SCOPE, {
    deltaBytes: 0,
    category: "memories",
    objectKey: "x",
    actorId: null,
  });
  assertEquals(res, null);
  assertEquals(calls.length, 0);
});

Deno.test("recordStorageUsage truncates a fractional delta, never rounds", async () => {
  const { db, calls } = fakeDb([{ id: "e1" }]);
  await recordStorageUsage(db, SCOPE, { deltaBytes: 999.9, category: "c", objectKey: "k", actorId: null });
  assertEquals(calls[0].params?.[2], 999);
});

Deno.test("recordStorageUsage records a NEGATIVE delta (a delete frees bytes)", async () => {
  const { db, calls } = fakeDb([{ id: "e1" }]);
  await recordStorageUsage(db, SCOPE, { deltaBytes: -2048, category: "c", objectKey: "k", actorId: null });
  assertEquals(calls[0].params?.[2], -2048);
});

// ── quota arithmetic (pure) ──────────────────────────────────────────────────
Deno.test("withinStorageQuota: null limit is unlimited", () => {
  assertEquals(withinStorageQuota(1e12, 1e9, null, 0), true);
});

Deno.test("withinStorageQuota: within the cap passes, over the cap+grace fails", () => {
  // limit 1000, no grace: used 900 + 100 = 1000 <= 1000 → ok; +101 → over.
  assertEquals(withinStorageQuota(900, 100, 1000, 0), true);
  assertEquals(withinStorageQuota(900, 101, 1000, 0), false);
});

Deno.test("withinStorageQuota: the grace buffer is honoured", () => {
  // limit 1000, grace 10% → ceiling 1100. used 1000 + 100 = 1100 → ok; +101 → over.
  assertEquals(withinStorageQuota(1000, 100, 1000, 10), true);
  assertEquals(withinStorageQuota(1000, 101, 1000, 10), false);
});

// ── health ───────────────────────────────────────────────────────────────────
Deno.test("storageQuotaHealth: unlimited plan is always 'unlimited'", () => {
  assertEquals(storageQuotaHealth(1e15, null), "unlimited");
});

Deno.test("storageQuotaHealth: healthy well below the cap", () => {
  assertEquals(storageQuotaHealth(100, 1000), "healthy");
});

Deno.test("storageQuotaHealth: low within the last 10% of the cap", () => {
  assertEquals(storageQuotaHealth(950, 1000), "low");
});

Deno.test("storageQuotaHealth: full at or over the cap", () => {
  assertEquals(storageQuotaHealth(1000, 1000), "full");
  assertEquals(storageQuotaHealth(1200, 1000), "full");
});

Deno.test("storageQuotaHealth: a zero-byte plan is full, not healthy", () => {
  assertEquals(storageQuotaHealth(0, 0), "full");
});
