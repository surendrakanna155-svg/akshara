// PRC-A Batch 3 — AI credit wallet: balance projection, grant rules, health.
//
// ⚠ Scope of what these prove. The fake DB pattern-matches SQL strings and
// evaluates neither JOINs, arithmetic, nor concurrency. So these tests prove the
// CODE-level contracts (sign rules, truncation, projection arithmetic, health
// thresholds) — they CANNOT prove that the balance SQL is correct against real
// Postgres, nor that two concurrent calls cannot double-spend. Those are live
// probes; see the Batch 3 live-cert suite. Nothing here justifies calling the
// wallet certified.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type AiWalletBalance,
  grantCredits,
  InvalidCreditGrantError,
  readWalletBalance,
  walletHealth,
} from "./ai_wallet_repository.ts";

const SCOPE = { organizationId: "org-1", schoolId: "sch-1" };

interface Call {
  sql: string;
  params?: unknown[];
}

function fakeDb(rows: Record<string, unknown>[]): { db: TenantQueryClient; calls: Call[] } {
  const calls: Call[] = [];
  const db = {
    // deno-lint-ignore require-await
    async queryObject<T>(sql: string, params?: unknown[]): Promise<T[]> {
      calls.push({ sql, params });
      return rows as T[];
    },
    // deno-lint-ignore require-await
    async queryCount(): Promise<number> {
      return 0;
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

// ─── balance projection ──────────────────────────────────────────────────────

Deno.test("readWalletBalance: available = granted - debited - reserved", async () => {
  const { db } = fakeDb([{ granted: 1000, debited: 250, reserved: 50 }]);
  const b = await readWalletBalance(db, SCOPE);
  assertEquals(b.grantedUnits, 1000);
  assertEquals(b.debitedUnits, 250);
  assertEquals(b.reservedUnits, 50);
  assertEquals(b.availableUnits, 700);
});

Deno.test("readWalletBalance: in-flight reservations are subtracted, not ignored", async () => {
  // This is the double-spend guard expressed as arithmetic: 100 granted with 100
  // already held in flight leaves NOTHING available, even though nothing has been
  // debited yet. Ignoring the pending term would let a concurrent call spend the
  // same 100 credits twice.
  const { db } = fakeDb([{ granted: 100, debited: 0, reserved: 100 }]);
  const b = await readWalletBalance(db, SCOPE);
  assertEquals(b.availableUnits, 0);
});

Deno.test("readWalletBalance: Postgres BIGINT comes back as a STRING and must not become NaN", async () => {
  // node-postgres/deno-postgres return bigint as string. `Number.parseInt` is
  // deliberate: a naive `+row.granted` on a bigint string works, but any
  // non-numeric would silently yield NaN and poison every downstream comparison
  // (NaN >= x is always false → the wallet would deny everything forever).
  const { db } = fakeDb([{ granted: "5000", debited: "1200", reserved: "300" }]);
  const b = await readWalletBalance(db, SCOPE);
  assertEquals(b.availableUnits, 3500);
});

Deno.test("readWalletBalance: an empty result set reads as a zero balance, never NaN", async () => {
  const { db } = fakeDb([]);
  const b = await readWalletBalance(db, SCOPE);
  assertEquals(b.grantedUnits, 0);
  assertEquals(b.availableUnits, 0);
});

Deno.test("readWalletBalance: a NEGATIVE balance is reported honestly, not clamped", async () => {
  // An admin correction (cap 43) can legitimately exceed what is left. Clamping
  // to 0 would silently forgive the debt and let the next top-up start from a
  // false zero — the ledger must stay arithmetically honest. The GATE refuses at
  // available < required, which is where enforcement belongs.
  const { db } = fakeDb([{ granted: 100, debited: 500, reserved: 0 }]);
  const b = await readWalletBalance(db, SCOPE);
  assertEquals(b.availableUnits, -400);
});

Deno.test("readWalletBalance is ORG-scoped, never school-scoped", async () => {
  // Credits are bought by the org, and org-scoped surfaces (director /
  // org-builder / onboarding) legitimately call with school_id NULL. A
  // school-filtered balance could not account for those calls at all.
  const { db, calls } = fakeDb([{ granted: 0, debited: 0, reserved: 0 }]);
  await readWalletBalance(db, SCOPE);
  assertEquals(calls[0].params, ["org-1"]);
  assertEquals(calls[0].sql.includes("school_id"), false);
});

// ─── grant rules ─────────────────────────────────────────────────────────────

Deno.test("grantCredits: a top_up must ADD credit", async () => {
  const { db } = fakeDb([{ id: "e-1" }]);
  await assertRejects(
    () => grantCredits(db, SCOPE, { entryType: "top_up", units: -5, reason: "x", actorId: null }),
    InvalidCreditGrantError,
  );
});

Deno.test("grantCredits: an expiry must REMOVE credit", async () => {
  const { db } = fakeDb([{ id: "e-1" }]);
  await assertRejects(
    () => grantCredits(db, SCOPE, { entryType: "expiry", units: 5, reason: "x", actorId: null }),
    InvalidCreditGrantError,
  );
});

Deno.test("grantCredits: a zero-unit entry is rejected (a no-op ledger row is noise)", async () => {
  const { db } = fakeDb([{ id: "e-1" }]);
  await assertRejects(
    () => grantCredits(db, SCOPE, { entryType: "adjustment", units: 0, reason: "x", actorId: null }),
    InvalidCreditGrantError,
  );
});

Deno.test("grantCredits: a fractional grant is truncated, never rounded up", async () => {
  const { db, calls } = fakeDb([{ id: "e-1" }]);
  const r = await grantCredits(db, SCOPE, {
    entryType: "top_up",
    units: 99.9,
    reason: "invoice 42",
    actorId: "admin-1",
  });
  assertEquals(r.units, 99);
  assertEquals(calls[0].params?.[2], 99);
});

Deno.test("grantCredits: an adjustment may be negative (that is its purpose)", async () => {
  const { db, calls } = fakeDb([{ id: "e-1" }]);
  const r = await grantCredits(db, SCOPE, {
    entryType: "adjustment",
    units: -250,
    reason: "billing correction",
    actorId: "admin-1",
  });
  assertEquals(r.units, -250);
  assertEquals(calls[0].params?.[1], "adjustment");
});

Deno.test("grantCredits: NaN/Infinity are rejected before they can poison the ledger", async () => {
  const { db } = fakeDb([{ id: "e-1" }]);
  for (const bad of [Number.NaN, Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY]) {
    await assertRejects(
      () => grantCredits(db, SCOPE, { entryType: "top_up", units: bad, reason: "x", actorId: null }),
      InvalidCreditGrantError,
    );
  }
});

Deno.test("grantCredits records provenance (actor + external ref) — cap 43 audit", async () => {
  const { db, calls } = fakeDb([{ id: "e-1" }]);
  await grantCredits(db, SCOPE, {
    entryType: "top_up",
    units: 500,
    reason: "PO-9",
    actorId: "admin-7",
    externalRef: "INV-2026-001",
  });
  assertEquals(calls[0].params?.[4], "admin-7");
  assertEquals(calls[0].params?.[5], "INV-2026-001");
});

// ─── health (cap 40) ─────────────────────────────────────────────────────────

function bal(
  granted: number,
  debited: number,
  reserved = 0,
  lastTopUp = granted,
): AiWalletBalance {
  return {
    grantedUnits: granted,
    debitedUnits: debited,
    reservedUnits: reserved,
    availableUnits: granted - debited - reserved,
    lastTopUpUnits: lastTopUp,
  };
}

Deno.test("walletHealth: empty at or below zero", () => {
  assertEquals(walletHealth(bal(100, 100)), "empty");
  assertEquals(walletHealth(bal(100, 150)), "empty");
});

Deno.test("walletHealth: low within the last 10% of the last top-up", () => {
  assertEquals(walletHealth(bal(1000, 950)), "low"); // 50 left of a 1000 top-up = 5%
  assertEquals(walletHealth(bal(1000, 900)), "low"); // 100 = exactly 10%
  assertEquals(walletHealth(bal(1000, 899)), "healthy"); // 101 → over the line
});

Deno.test("walletHealth is a RATIO, so it scales with what the school actually bought", () => {
  // 50 credits left is "low" for an org whose last purchase was 1000, but
  // perfectly healthy for one whose last purchase was 100. No single absolute
  // threshold is right for both.
  assertEquals(walletHealth(bal(1000, 950)), "low");
  assertEquals(walletHealth(bal(100, 50)), "healthy");
});

Deno.test("walletHealth: a loyal org that just topped up is HEALTHY, not permanently low", () => {
  // The regression that made me abandon lifetime-grants as the denominator: an
  // org topping up 500/month for 10 years has granted=60000. Against lifetime,
  // the "low" threshold would be 6000 — so the instant after paying (available
  // 500) it would still read "low", forever, and the alert would be pure noise.
  // Against the LAST top-up (500), 500 > 50 → healthy, which is the truth.
  assertEquals(walletHealth(bal(60_000, 59_500, 0, 500)), "healthy");
  // ...and it correctly becomes low once that purchase is nearly spent.
  assertEquals(walletHealth(bal(60_000, 59_960, 0, 500)), "low");
});

Deno.test("walletHealth: an org credited only by adjustment (never topped up) still gets a signal", () => {
  // lastTopUp = 0 → fall back to lifetime grants rather than reporting nothing.
  assertEquals(walletHealth(bal(1000, 950, 0, 0)), "low");
  assertEquals(walletHealth(bal(1000, 100, 0, 0)), "healthy");
});

Deno.test("walletHealth: a never-funded wallet is empty, not healthy", () => {
  assertEquals(walletHealth(bal(0, 0)), "empty");
});

Deno.test("walletHealth: the low threshold is NOT degenerate (regression)", () => {
  // The formula this replaces used `granted - debited` as the denominator, which
  // with no reservations IS `available` — so it asked `available <= available*0.1`
  // and could only ever be true at zero. The cap-40 alert would have been dead
  // code that never fired. Any denominator change must keep this passing.
  assertEquals(walletHealth(bal(1000, 950)), "low");
});
