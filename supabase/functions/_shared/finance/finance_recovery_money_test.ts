// ICA-A1 (P0) — fee-recovery money-unit certification.
//
// The recovery lane stores money in BIGINT `_minor` paise columns
// (finance_promises_to_pay.amount_minor, finance_recovery_targets.target_minor)
// and SUMs NUMERIC(12,2) rupees (finance_collections.amount_collected) for the
// dashboard. This suite pins the full rupee → paise → rupee round-trip through
// the REAL product functions so the "100× understatement" defect cannot return:
//
//   * the WRITER (amountMinor) scales rupees → integer paise,
//   * the aggregate SQL scales collected rupees → integer paise for the `_minor`
//     aliases, and
//   * the DISPLAY mapper (minorToRupees) scales paise → rupees.
//
// Run: deno test --allow-read supabase/functions/_shared/finance/finance_recovery_money_test.ts

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { amountMinor, minorToRupees } from "./finance_recovery_handlers.ts";
import {
  collectorPerformanceForMonth,
  recoveryAggregates,
} from "./finance_recovery_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

// ── WRITER: rupees → integer paise (was a no-op that stored rupee-scale) ──────

Deno.test("ICA-A1 writer: ₹1500 → 150000 paise, ₹4200 → 420000 paise", () => {
  assertEquals(amountMinor({ amount: "1500" }, "amount"), 150000);
  assertEquals(amountMinor({ target: "4200" }, "target"), 420000);
});

Deno.test("ICA-A1 writer: paise are preserved exactly (₹1500.50 → 150050)", () => {
  assertEquals(amountMinor({ amount: "1500.50" }, "amount"), 150050);
  assertEquals(amountMinor({ amount: "₹2,500.25" }, "amount"), 250025);
});

Deno.test("ICA-A1 writer: empty / non-numeric input is 0 (rejected upstream)", () => {
  assertEquals(amountMinor({}, "amount"), 0);
  assertEquals(amountMinor({ amount: "" }, "amount"), 0);
  assertEquals(amountMinor({ amount: "abc" }, "amount"), 0);
});

// ── DISPLAY: integer paise → rupee string ────────────────────────────────────

Deno.test("ICA-A1 display: 420000 paise → \"4200.00\", 150000 → \"1500.00\"", () => {
  assertEquals(minorToRupees("420000"), "4200.00");
  assertEquals(minorToRupees("150000"), "1500.00");
  assertEquals(minorToRupees("150050"), "1500.50");
});

// ── ROUND-TRIP: a ₹1500 promise-to-pay input → stored paise → displayed ──────

Deno.test("ICA-A1 round-trip: ₹1500 PTP input → 150000 paise stored → \"1500.00\" displayed", () => {
  const storedPaise = amountMinor({ amount: "1500" }, "amount");
  assertEquals(storedPaise, 150000);
  assertEquals(minorToRupees(String(storedPaise)), "1500.00");
});

// ── AGGREGATE SQL: collected rupees are scaled ×100 to paise for `_minor` ─────

function captureDb(rows: Record<string, unknown>[]): {
  db: TenantQueryClient;
  calls: { sql: string; args: unknown[] }[];
} {
  const calls: { sql: string; args: unknown[] }[] = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, args: unknown[] = []): Promise<any[]> {
      calls.push({ sql, args });
      return Promise.resolve(rows);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

Deno.test("ICA-A1 aggregate: recoveryAggregates scales amount_collected ×100 → bigint paise", async () => {
  // The fake returns what the FIXED SQL yields for a ₹4,200 completed-collection
  // sum: 420000 paise. The dashboard mapper (minorToRupees) must recover ₹4200.00.
  const { db, calls } = captureDb([{
    ptp_pending: "0",
    ptp_due_today: "0",
    ptp_overdue: "0",
    ptp_kept: "0",
    ptp_broken: "0",
    contacts_this_month: "0",
    recovered_this_month_minor: "420000",
  }]);

  const agg = await recoveryAggregates(db, "org-1", "school-1", "2026-07-01");

  const { sql } = calls[0];
  assert(
    /ROUND\(\s*COALESCE\(sum\(amount_collected\), 0\) \* 100\)/i.test(sql),
    "recoveredThisMonth SUM must scale rupees ×100 to paise",
  );
  assert(/::bigint::text AS recovered_this_month_minor/i.test(sql), "must cast to bigint paise");
  // Seeded ₹4,200 sum → displayed as ₹4200.00 (not ₹42.00).
  assertEquals(minorToRupees(agg.recovered_this_month_minor), "4200.00");
});

Deno.test("ICA-A1 aggregate: collectorPerformanceForMonth scales recovered ×100 → bigint paise", async () => {
  const { db, calls } = captureDb([{
    collector_id: "u-1",
    collector_name: "Asha",
    contacts_made: "3",
    promises_obtained: "2",
    amount_recovered_minor: "420000", // paise the fixed SQL emits for a ₹4,200 sum
    collections_count: "5",
  }]);

  const rows = await collectorPerformanceForMonth(db, "org-1", "school-1", "2026-07-01");

  const { sql } = calls[0];
  assert(
    /ROUND\(COALESCE\(sum\(amount_collected\), 0\) \* 100\)::bigint::text AS amt/i.test(sql),
    "per-collector recovered SUM must scale rupees ×100 to bigint paise",
  );
  // Per-collector amountRecovered maps paise → ₹4200.00 (the dashboard value).
  assertEquals(minorToRupees(rows[0].amount_recovered_minor), "4200.00");
});
