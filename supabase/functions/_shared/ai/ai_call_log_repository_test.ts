import { assert, assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type AiCallLogEntry,
  countSchoolCallsSince,
  countUserCallsSince,
  recordAiCall,
  sumSchoolCostMicrosSince,
} from "./ai_call_log_repository.ts";

interface Captured {
  sql: string;
  params?: unknown[];
}

function fakeDb(rows: unknown[]): { db: TenantQueryClient; calls: Captured[] } {
  const calls: Captured[] = [];
  const db = {
    queryObject: (sql: string, params?: unknown[]) => {
      calls.push({ sql, params });
      // deno-lint-ignore no-explicit-any
      return Promise.resolve(rows as any);
    },
    // deno-lint-ignore no-explicit-any
  } as any as TenantQueryClient;
  return { db, calls };
}

const SCOPE = { organizationId: "org-1", schoolId: "sch-1" };

Deno.test("recordAiCall inserts one row with 14 params and truncated integers", async () => {
  const { db, calls } = fakeDb([]);
  const entry: AiCallLogEntry = {
    organizationId: "org-1",
    schoolId: "sch-1",
    userId: "u-1",
    surface: "copilot",
    provider: "anthropic",
    model: "claude-opus-4-8",
    outcome: "ok",
    inputTokens: 100.9,
    outputTokens: 50.4,
    estimatedCostMicros: 1234.7,
    latencyMs: 42.9,
    cacheWritten: false,
    fallbackUsed: false,
  };
  await recordAiCall(db, entry);
  assertEquals(calls.length, 1);
  assert(calls[0].sql.includes("INSERT INTO ai_call_log"));
  // 14 since PRC-A Batch 3: credits_debited rides this same INSERT so the wallet
  // debit and the call it pays for are atomically inseparable.
  assertEquals(calls[0].params?.length, 14);
  assertEquals(calls[0].params?.[7], 100); // input_tokens truncated
  assertEquals(calls[0].params?.[8], 50); // output_tokens truncated
  assertEquals(calls[0].params?.[9], 1234); // cost truncated
  assertEquals(calls[0].params?.[10], 42); // latency truncated
  // `entry` above deliberately omits creditsDebited — the overwhelmingly common
  // case, since the wallet ships disabled. It MUST default to 0, never NULL or
  // NaN: a null would violate the NOT NULL column, and a NaN would poison every
  // balance projection for that org forever.
  assertEquals(calls[0].params?.[13], 0);
});

Deno.test("recordAiCall debits the wallet when credits are supplied, truncated + floored at 0", async () => {
  const base: AiCallLogEntry = {
    organizationId: "org-1",
    schoolId: "sch-1",
    userId: "u-1",
    surface: "copilot",
    provider: "anthropic",
    model: "claude-opus-4-8",
    outcome: "ok",
    inputTokens: 10,
    outputTokens: 5,
    estimatedCostMicros: 100,
    latencyMs: 10,
    cacheWritten: false,
    fallbackUsed: false,
  };

  const a = fakeDb([]);
  await recordAiCall(a.db, { ...base, creditsDebited: 15.9 });
  assertEquals(a.calls[0].params?.[13], 15); // truncated, never rounded up

  // A negative debit would CREATE credit out of nothing — the balance projection
  // subtracts this column, so a negative value would silently top the org up.
  // Floored at 0 rather than trusted.
  const b = fakeDb([]);
  await recordAiCall(b.db, { ...base, creditsDebited: -50 });
  assertEquals(b.calls[0].params?.[13], 0);
});

Deno.test("recordAiCall coalesces a missing userId to null", async () => {
  const { db, calls } = fakeDb([]);
  await recordAiCall(db, {
    organizationId: "org-1",
    schoolId: "sch-1",
    surface: "director_summary",
    provider: "openrouter",
    model: "anthropic/claude-sonnet-4-6",
    outcome: "fallback_no_key",
    inputTokens: 0,
    outputTokens: 0,
    estimatedCostMicros: 0,
    latencyMs: 0,
    cacheWritten: false,
    fallbackUsed: true,
  });
  assertEquals(calls[0].params?.[2], null); // user_id
});

Deno.test("countUserCallsSince returns a number and excludes no-key fallbacks", async () => {
  const { db, calls } = fakeDb([{ n: 3 }]);
  const n = await countUserCallsSince(db, SCOPE, "u-1", "2026-07-10T00:00:00Z");
  assertEquals(n, 3);
  assert(calls[0].sql.includes("count(*)"));
  assert(calls[0].sql.includes("fallback_no_key")); // excluded from the bucket
  assertEquals(calls[0].params, ["org-1", "sch-1", "u-1", "2026-07-10T00:00:00Z"]);
});

Deno.test("countSchoolCallsSince returns a number", async () => {
  const { db } = fakeDb([{ n: 12 }]);
  assertEquals(await countSchoolCallsSince(db, SCOPE, "2026-07-10T00:00:00Z"), 12);
});

Deno.test("countSchoolCallsSince defaults to 0 with no rows", async () => {
  const { db } = fakeDb([]);
  assertEquals(await countSchoolCallsSince(db, SCOPE, "2026-07-10T00:00:00Z"), 0);
});

Deno.test("sumSchoolCostMicrosSince coerces a bigint-as-string sum", async () => {
  const { db } = fakeDb([{ total: "12345678" }]);
  assertEquals(await sumSchoolCostMicrosSince(db, SCOPE, "2026-07-01T00:00:00Z"), 12345678);
});

Deno.test("sumSchoolCostMicrosSince handles a numeric sum and empty result", async () => {
  assertEquals(await sumSchoolCostMicrosSince(fakeDb([{ total: 999 }]).db, SCOPE, "x"), 999);
  assertEquals(await sumSchoolCostMicrosSince(fakeDb([]).db, SCOPE, "x"), 0);
});
