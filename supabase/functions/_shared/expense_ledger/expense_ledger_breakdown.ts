// W4 — pure expense breakdown builder.
//
// Turns ledger entries (or pre-aggregated category totals) into the category
// breakdown array the management dashboard's `expenseBreakdown` consumes. This is
// PURE (no DB) so the aggregation + percentage maths is unit-testable DB-free.
//
// The output objects carry BOTH the Flutter chart contract keys and explicit
// aliases:
//   * `label`  / `value`  / `percent` — the exact keys the Flutter
//     `_mapSegments` reader consumes (ManagementSegment: label, value, percent),
//     so management can drop this array straight into `expenseBreakdown` when it
//     wires the ledger (that wiring is a deliberate follow-up — this module does
//     NOT edit management_payload_builders.ts).
//   * `category` / `amount` — the same figures under self-describing names for any
//     non-chart consumer.

/** Minimal entry shape — accepts a raw ledger row or a pre-aggregated total. */
export interface ExpenseBreakdownEntry {
  category: string;
  /** Rupees. Accepts a number or a NUMERIC-as-string (as the DB returns it). */
  amount: number | string;
}

export interface ExpenseBreakdownItem {
  /** Chart label (== category). */
  label: string;
  /** Chart value: the category's total rupees, 2 dp. */
  value: number;
  /** Share of the grand total, percent, 2 dp (0 when the total is 0). */
  percent: number;
  /** Self-describing alias of `label`. */
  category: string;
  /** Self-describing alias of `value`. */
  amount: number;
}

function toAmount(value: number | string): number {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? n : 0;
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

/**
 * Aggregate entries into a category breakdown, sorted by amount descending then
 * category ascending (stable, deterministic). Entries sharing a category are
 * summed; negative/non-finite amounts are coerced to 0 (a ledger CHECK forbids
 * negatives, but the pure builder stays defensive). Percentages are each category's
 * share of the grand total and sum to ~100 (subject to 2-dp rounding).
 */
export function buildExpenseBreakdown(
  entries: ReadonlyArray<ExpenseBreakdownEntry>,
): ExpenseBreakdownItem[] {
  const totals = new Map<string, number>();
  for (const e of entries) {
    const category = (e.category ?? "").trim() || "other";
    const amount = Math.max(0, toAmount(e.amount));
    totals.set(category, (totals.get(category) ?? 0) + amount);
  }

  const grandTotal = [...totals.values()].reduce((sum, n) => sum + n, 0);

  const items: ExpenseBreakdownItem[] = [...totals.entries()].map(
    ([category, amount]) => {
      const value = round2(amount);
      return {
        label: category,
        value,
        percent: grandTotal > 0 ? round2((amount / grandTotal) * 100) : 0,
        category,
        amount: value,
      };
    },
  );

  items.sort((a, b) => b.amount - a.amount || a.category.localeCompare(b.category));
  return items;
}
