// A5 — atomic gateway quota reservations: transaction-body unit tests (DB-free).

import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  PENDING_TTL_MS,
  type ReservationExec,
  type ReserveArgs,
  runReservation,
} from "./ai_call_reservations_repository.ts";

const NOW = new Date("2026-07-10T10:00:00.000Z");

function args(overrides: Partial<ReserveArgs> = {}): ReserveArgs {
  return {
    scope: { organizationId: "org-1", schoolId: "sch-1" },
    userId: "u-1",
    surface: "copilot",
    estimatedCostMicros: 5_000,
    limits: { userCallsPerHour: 30, schoolCallsPerDay: 500, monthlySpendCapMicros: 1_000_000 },
    now: NOW,
    ...overrides,
  };
}

/** Fake exec: answers queries by first matching substring, records every call. */
function fakeExec(
  responders: Array<{ match: string; rows: unknown[] }>,
): { exec: ReservationExec; calls: Array<{ sql: string; args: unknown[] }> } {
  const calls: Array<{ sql: string; args: unknown[] }> = [];
  return {
    calls,
    exec: {
      // deno-lint-ignore no-explicit-any
      queryObject: <T>(sql: string, sqlArgs: unknown[] = []): Promise<T[]> => {
        calls.push({ sql, args: sqlArgs });
        const hit = responders.find((r) => sql.includes(r.match));
        return Promise.resolve((hit?.rows ?? []) as T[]);
      },
    },
  };
}

Deno.test("reservation: admitted → returns the inserted id; sweep runs first", async () => {
  const { exec, calls } = fakeExec([
    { match: "INSERT INTO ai_call_reservations", rows: [{ id: "res-1" }] },
  ]);
  const result = await runReservation(exec, args());
  assertEquals(result, { allow: true, reservationId: "res-1" });
  assert(calls[0]!.sql.includes("DELETE FROM ai_call_reservations"), "sweep first");
  assert(calls[1]!.sql.includes("INSERT INTO ai_call_reservations"));
  // The admit statement carries every window boundary, incl. the pending TTL.
  const insertArgs = calls[1]!.args;
  assertEquals(insertArgs[0], "org-1");
  assertEquals(insertArgs[11], new Date(NOW.getTime() - PENDING_TTL_MS).toISOString());
});

Deno.test("reservation: denied → names the gate in decide order (user first)", async () => {
  const { exec } = fakeExec([
    { match: "INSERT INTO ai_call_reservations", rows: [] },
    { match: "AS user_calls", rows: [{ user_calls: 30, school_calls: 40, month_spend: 999_999_999 }] },
  ]);
  const result = await runReservation(exec, args());
  assertEquals(result, { allow: false, reason: "rate_user" });
});

Deno.test("reservation: denied at school rate when user gate passes", async () => {
  const { exec } = fakeExec([
    { match: "INSERT INTO ai_call_reservations", rows: [] },
    { match: "AS user_calls", rows: [{ user_calls: 3, school_calls: 500, month_spend: 0 }] },
  ]);
  assertEquals(await runReservation(exec, args()), { allow: false, reason: "rate_school" });
});

Deno.test("reservation: denied at spend cap as the final gate", async () => {
  const { exec } = fakeExec([
    { match: "INSERT INTO ai_call_reservations", rows: [] },
    { match: "AS user_calls", rows: [{ user_calls: 3, school_calls: 40, month_spend: 999_000 }] },
  ]);
  assertEquals(await runReservation(exec, args()), { allow: false, reason: "spend_cap" });
});

Deno.test("reservation: a null user never denies on the user gate", async () => {
  const { exec } = fakeExec([
    { match: "INSERT INTO ai_call_reservations", rows: [] },
    // user_calls large but userId null → gate skipped → falls to spend.
    { match: "AS user_calls", rows: [{ user_calls: 99, school_calls: 1, month_spend: 999_999 }] },
  ]);
  assertEquals(
    await runReservation(exec, args({ userId: null })),
    { allow: false, reason: "spend_cap" },
  );
});

Deno.test("reservation: org bucket (null school) flows through as a real bucket", async () => {
  const { exec, calls } = fakeExec([
    { match: "INSERT INTO ai_call_reservations", rows: [{ id: "res-2" }] },
  ]);
  const result = await runReservation(
    exec,
    args({ scope: { organizationId: "org-1", schoolId: null } }),
  );
  assertEquals(result, { allow: true, reservationId: "res-2" });
  assertEquals(calls[1]!.args[1], null);
  assert(calls[1]!.sql.includes("IS NOT DISTINCT FROM"), "NULL must be a bucket, not false");
});
