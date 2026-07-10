import { assert, assertEquals } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import { getFactSignal, upsertFactSignal } from "./ai_fact_signals_repository.ts";

interface Captured {
  sql: string;
  params?: unknown[];
}

function fakeDb(select: unknown[] = []): { db: TenantQueryClient; calls: Captured[] } {
  const calls: Captured[] = [];
  const db = {
    queryObject: (sql: string, params?: unknown[]) => {
      calls.push({ sql, params });
      // deno-lint-ignore no-explicit-any
      return Promise.resolve((sql.trimStart().startsWith("SELECT") ? select : []) as any);
    },
    // deno-lint-ignore no-explicit-any
  } as any as TenantQueryClient;
  return { db, calls };
}

const SCOPE = { organizationId: "org-1", schoolId: "sch-1" };

Deno.test("upsertFactSignal issues an idempotent upsert with a JSON payload", async () => {
  const { db, calls } = fakeDb();
  await upsertFactSignal(db, SCOPE, {
    signalType: "fees_activity",
    scopeKey: "student:stu-1",
    payload: { lastEventType: "fee_collected" },
  });
  assert(calls[0].sql.includes("INSERT INTO ai_fact_signals"));
  assert(calls[0].sql.includes("ON CONFLICT"));
  assertEquals(calls[0].params?.length, 5);
  assertEquals(calls[0].params?.[2], "fees_activity");
  assertEquals(calls[0].params?.[3], "student:stu-1");
  assertEquals(calls[0].params?.[4], JSON.stringify({ lastEventType: "fee_collected" }));
});

Deno.test("getFactSignal maps a row and returns null on miss", async () => {
  const hit = await getFactSignal(
    fakeDb([{ signal_type: "fees_activity", scope_key: "school", payload: { a: 1 }, computed_at: "2026-07-10T00:00:00Z" }]).db,
    SCOPE,
    "fees_activity",
    "school",
  );
  assertEquals(hit, {
    signalType: "fees_activity",
    scopeKey: "school",
    payload: { a: 1 },
    computedAt: "2026-07-10T00:00:00Z",
  });
  assertEquals(await getFactSignal(fakeDb([]).db, SCOPE, "fees_activity", "school"), null);
});
