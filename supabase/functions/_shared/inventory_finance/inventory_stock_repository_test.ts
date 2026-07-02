// INV-1..7 — stock repository unit coverage (DB-free stateful fake).
//
// Proves the owner-decision invariants without a live Postgres:
//   • negative-stock hard block on issue and on adjust-out approval (422),
//   • issue decrement writes an immutable movement with qty_before → qty_after,
//   • issue idempotency (re-post of the same slip number does not re-decrement),
//   • maker-checker: adjust_out is pending (no stock move), self-approve blocked,
//     approve decrements exactly once, reject is a no-op on stock,
//   • negative count variance → pending adjustment (variance recorded, not silently
//     overwritten); positive variance applies immediately,
//   • weighted-average valuation on inbound adjust_in.

import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  adjustStock,
  approveStockAdjustment,
  InsufficientStockError,
  issueStock,
  recordStockCount,
  rejectStockAdjustment,
  StockSelfApproveDeniedError,
} from "./inventory_stock_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const MAKER = "a3000000-0000-4000-8000-000000000001";
const CHECKER = "a3000000-0000-4000-8000-000000000002";

interface MovementRow {
  sku: string;
  movement_type: string;
  quantity_delta: number;
  qty_before: number;
  qty_after: number;
}

interface AdjustmentRow {
  id: string;
  sku: string;
  qty: number;
  movement_type: string;
  reason: string;
  status: string;
  reference_type: string | null;
  reference_id: string | null;
  maker_id: string | null;
  checker_id: string | null;
  decision_comment: string | null;
  decided_at: string | null;
  created_at: string;
}

/**
 * Stateful in-memory model of the four stock tables. FOR UPDATE selects behave as
 * plain selects here (single-threaded test), which is sufficient to prove the
 * read-modify-write and maker-checker logic.
 */
class FakeStockDb {
  stock = new Map<string, { quantity_on_hand: number; weighted_avg_cost: number }>();
  movements: MovementRow[] = [];
  adjustments = new Map<string, AdjustmentRow>();
  issues = new Map<string, { id: string; posted: boolean }>();
  countSessions = new Map<string, { id: string; posted: boolean }>();
  private seq = 0;

  setStock(sku: string, qty: number, cost = 100): void {
    this.stock.set(sku, { quantity_on_hand: qty, weighted_avg_cost: cost });
  }

  private id(prefix: string): string {
    this.seq += 1;
    return `${prefix}-${this.seq}`;
  }

  // deno-lint-ignore no-explicit-any
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    const q = sql.replace(/\s+/g, " ").trim();

    // Lock/read a valuation row.
    if (q.startsWith("SELECT quantity_on_hand, weighted_avg_cost FROM inventory_stock_valuations")) {
      const sku = args[2] as string;
      const row = this.stock.get(sku);
      return (row ? [row] : []) as unknown as T[];
    }

    // Issue slip idempotency probe.
    if (q.startsWith("SELECT id, posted FROM stock_issues")) {
      const num = args[2] as string;
      const existing = this.issues.get(num);
      return (existing ? [existing] : []) as unknown as T[];
    }

    // Count session idempotency probe.
    if (q.startsWith("SELECT id, posted FROM stock_count_sessions")) {
      const num = args[2] as string;
      const existing = this.countSessions.get(num);
      return (existing ? [existing] : []) as unknown as T[];
    }

    // Insert issue slip.
    if (q.startsWith("INSERT INTO stock_issues")) {
      const num = args[2] as string;
      const id = this.id("issue");
      this.issues.set(num, { id, posted: true });
      return [{ id }] as unknown as T[];
    }

    // Insert count session.
    if (q.startsWith("INSERT INTO stock_count_sessions")) {
      const num = args[2] as string;
      const id = this.id("count");
      this.countSessions.set(num, { id, posted: true });
      return [{ id }] as unknown as T[];
    }

    // Issue line / count line inserts (no return needed).
    if (q.startsWith("INSERT INTO stock_issue_lines") || q.startsWith("INSERT INTO stock_count_lines")) {
      return [] as unknown as T[];
    }

    // Insert stock movement.
    if (q.startsWith("INSERT INTO stock_movements")) {
      this.movements.push({
        sku: args[2] as string,
        movement_type: args[3] as string,
        quantity_delta: args[4] as number,
        qty_before: args[5] as number,
        qty_after: args[6] as number,
      });
      return [{ id: this.id("mov") }] as unknown as T[];
    }

    // Update valuation qty (issue / count / approve).
    if (q.startsWith("UPDATE inventory_stock_valuations SET quantity_on_hand = $4, last_valued_at")) {
      const sku = args[2] as string;
      const newQty = args[3] as number;
      const row = this.stock.get(sku)!;
      this.stock.set(sku, { ...row, quantity_on_hand: newQty });
      return [] as unknown as T[];
    }

    // Update valuation qty + cost (adjust_in weighted avg).
    if (q.startsWith("UPDATE inventory_stock_valuations SET quantity_on_hand = $4, weighted_avg_cost = $5")) {
      const sku = args[2] as string;
      this.stock.set(sku, { quantity_on_hand: args[3] as number, weighted_avg_cost: args[4] as number });
      return [] as unknown as T[];
    }

    // Insert valuation row (new SKU on adjust_in / count).
    if (q.startsWith("INSERT INTO inventory_stock_valuations")) {
      const sku = args[2] as string;
      const qty = args[3] as number;
      const cost = (args[4] as number) ?? 0;
      this.stock.set(sku, { quantity_on_hand: qty, weighted_avg_cost: cost });
      return [] as unknown as T[];
    }

    // Insert stock adjustment (pending). movement_type + reference_type are SQL
    // literals in both variants; only the placeholder args differ:
    //   manual adjust_out: [org, school, sku, qty, reason, maker]
    //   count variance:    [org, school, sku, qty, reason, sessionId, maker]
    if (q.startsWith("INSERT INTO stock_adjustments")) {
      const id = this.id("adj");
      const isCount = q.includes("'stock_count_session'");
      const row: AdjustmentRow = {
        id,
        sku: args[2] as string,
        qty: args[3] as number,
        movement_type: isCount ? "count_variance" : "adjust_out",
        reason: args[4] as string,
        status: "pending",
        reference_type: isCount ? "stock_count_session" : "manual_adjustment",
        reference_id: isCount ? (args[5] as string) ?? null : null,
        maker_id: (isCount ? args[6] : args[5]) as string ?? null,
        checker_id: null,
        decision_comment: null,
        decided_at: null,
        created_at: new Date().toISOString(),
      };
      this.adjustments.set(id, row);
      return [{ id }] as unknown as T[];
    }

    // Get pending adjustment by id.
    if (q.startsWith("SELECT id, sku, qty, movement_type, reason, status, reference_type, reference_id")) {
      // list-pending vs get-by-id: get-by-id filters on id = $1.
      if (q.includes("WHERE id = $1")) {
        const row = this.adjustments.get(args[0] as string);
        return (row ? [row] : []) as unknown as T[];
      }
      const pending = [...this.adjustments.values()].filter((a) => a.status === "pending");
      return pending as unknown as T[];
    }

    // Decision UPDATE on the adjustment.
    if (q.startsWith("UPDATE stock_adjustments SET status")) {
      const id = args[0] as string;
      const checker = args[3] as string;
      const row = this.adjustments.get(id);
      if (row && row.status === "pending") {
        row.status = q.includes("'approved'") ? "approved" : "rejected";
        row.checker_id = checker;
        row.decided_at = new Date().toISOString();
      }
      return [] as unknown as T[];
    }

    return [] as unknown as T[];
  }
}

function db(fake: FakeStockDb): TenantQueryClient {
  return fake as unknown as TenantQueryClient;
}

Deno.test("INV-1: issue decrements stock and writes a before→after movement", async () => {
  const fake = new FakeStockDb();
  fake.setStock("PEN-001", 50);
  const res = await issueStock(db(fake), ORG, SCHOOL, MAKER, {
    issueNumber: "ISS-1",
    lines: [{ sku: "PEN-001", quantity: 20 }],
  });
  assertEquals(res.posted, true);
  assertEquals(fake.stock.get("PEN-001")!.quantity_on_hand, 30);
  const mv = fake.movements.at(-1)!;
  assertEquals(mv.movement_type, "issue");
  assertEquals(mv.qty_before, 50);
  assertEquals(mv.qty_after, 30);
  assertEquals(mv.quantity_delta, -20);
});

Deno.test("INV-1: issue over on-hand is hard-blocked (never negative)", async () => {
  const fake = new FakeStockDb();
  fake.setStock("PEN-001", 5);
  await assertRejects(
    () => issueStock(db(fake), ORG, SCHOOL, MAKER, {
      issueNumber: "ISS-2",
      lines: [{ sku: "PEN-001", quantity: 10 }],
    }),
    InsufficientStockError,
  );
  // Stock untouched, no movement written.
  assertEquals(fake.stock.get("PEN-001")!.quantity_on_hand, 5);
  assertEquals(fake.movements.length, 0);
});

Deno.test("INV-1: re-posting the same issue slip number is idempotent (no double-decrement)", async () => {
  const fake = new FakeStockDb();
  fake.setStock("PEN-001", 50);
  await issueStock(db(fake), ORG, SCHOOL, MAKER, {
    issueNumber: "ISS-3",
    lines: [{ sku: "PEN-001", quantity: 20 }],
  });
  const again = await issueStock(db(fake), ORG, SCHOOL, MAKER, {
    issueNumber: "ISS-3",
    lines: [{ sku: "PEN-001", quantity: 20 }],
  });
  assertEquals(again.movementIds.length, 0, "re-post writes no new movements");
  assertEquals(fake.stock.get("PEN-001")!.quantity_on_hand, 30, "stock decremented only once");
});

Deno.test("INV-3: adjust_out is value-reducing → pending, stock NOT touched", async () => {
  const fake = new FakeStockDb();
  fake.setStock("PEN-001", 40);
  const res = await adjustStock(db(fake), ORG, SCHOOL, MAKER, {
    sku: "PEN-001",
    quantity: 10,
    movementType: "adjust_out",
    reason: "Damaged in storage",
  });
  assertEquals(res.applied, false);
  assertEquals(res.status, "pending");
  assertEquals(fake.stock.get("PEN-001")!.quantity_on_hand, 40, "pending adjust_out must not move stock");
  assertEquals(fake.movements.length, 0, "no movement until approved");
});

Deno.test("INV-3: adjust_in applies immediately with weighted-average cost", async () => {
  const fake = new FakeStockDb();
  fake.setStock("PEN-001", 10, 100);
  const res = await adjustStock(db(fake), ORG, SCHOOL, MAKER, {
    sku: "PEN-001",
    quantity: 5,
    movementType: "adjust_in",
    reason: "Return to store",
    unitCost: 130,
  });
  assertEquals(res.applied, true);
  assertEquals(fake.stock.get("PEN-001")!.quantity_on_hand, 15);
  // Weighted avg: (10*100 + 5*130)/15 = 110.
  assertEquals(fake.stock.get("PEN-001")!.weighted_avg_cost, 110);
  assertEquals(fake.movements.at(-1)!.movement_type, "adjust_in");
});

Deno.test("INV-3: adjustments require a mandatory reason", async () => {
  const fake = new FakeStockDb();
  fake.setStock("PEN-001", 40);
  await assertRejects(
    () => adjustStock(db(fake), ORG, SCHOOL, MAKER, {
      sku: "PEN-001",
      quantity: 10,
      movementType: "adjust_out",
      reason: "   ",
    }),
    Error,
    "reason is mandatory",
  );
});

Deno.test("maker-checker: self-approve is blocked (409)", async () => {
  const fake = new FakeStockDb();
  fake.setStock("PEN-001", 40);
  const { adjustmentId } = await adjustStock(db(fake), ORG, SCHOOL, MAKER, {
    sku: "PEN-001",
    quantity: 10,
    movementType: "adjust_out",
    reason: "Wastage",
  });
  await assertRejects(
    () => approveStockAdjustment(db(fake), ORG, SCHOOL, MAKER, adjustmentId!),
    StockSelfApproveDeniedError,
  );
  assertEquals(fake.stock.get("PEN-001")!.quantity_on_hand, 40, "stock unchanged on blocked self-approve");
});

Deno.test("maker-checker: approve by a different user decrements once + writes movement", async () => {
  const fake = new FakeStockDb();
  fake.setStock("PEN-001", 40);
  const { adjustmentId } = await adjustStock(db(fake), ORG, SCHOOL, MAKER, {
    sku: "PEN-001",
    quantity: 10,
    movementType: "adjust_out",
    reason: "Wastage",
  });
  const res = await approveStockAdjustment(db(fake), ORG, SCHOOL, CHECKER, adjustmentId!);
  assertEquals(res.status, "approved");
  assertEquals(res.qtyBefore, 40);
  assertEquals(res.qtyAfter, 30);
  assertEquals(fake.stock.get("PEN-001")!.quantity_on_hand, 30);
  const mv = fake.movements.at(-1)!;
  assertEquals(mv.movement_type, "adjust_out");
  assertEquals(mv.quantity_delta, -10);
  assertEquals(fake.adjustments.get(adjustmentId!)!.status, "approved");
  assertEquals(fake.adjustments.get(adjustmentId!)!.checker_id, CHECKER);
});

Deno.test("maker-checker: approve is hard-blocked if it would go negative (422)", async () => {
  const fake = new FakeStockDb();
  fake.setStock("PEN-001", 40);
  const { adjustmentId } = await adjustStock(db(fake), ORG, SCHOOL, MAKER, {
    sku: "PEN-001",
    quantity: 10,
    movementType: "adjust_out",
    reason: "Wastage",
  });
  // Someone issues the stock down below the pending write-off before approval.
  fake.setStock("PEN-001", 3);
  await assertRejects(
    () => approveStockAdjustment(db(fake), ORG, SCHOOL, CHECKER, adjustmentId!),
    InsufficientStockError,
  );
  assertEquals(fake.stock.get("PEN-001")!.quantity_on_hand, 3, "stock unchanged when approval would go negative");
});

Deno.test("maker-checker: reject is a no-op on stock", async () => {
  const fake = new FakeStockDb();
  fake.setStock("PEN-001", 40);
  const { adjustmentId } = await adjustStock(db(fake), ORG, SCHOOL, MAKER, {
    sku: "PEN-001",
    quantity: 10,
    movementType: "adjust_out",
    reason: "Wastage",
  });
  const res = await rejectStockAdjustment(db(fake), ORG, SCHOOL, CHECKER, adjustmentId!, "Not damaged");
  assertEquals(res.status, "rejected");
  assertEquals(fake.stock.get("PEN-001")!.quantity_on_hand, 40);
  assertEquals(fake.movements.length, 0);
  assertEquals(fake.adjustments.get(adjustmentId!)!.status, "rejected");
});

Deno.test("INV-6: positive count variance applies immediately; negative → pending adjustment", async () => {
  const fake = new FakeStockDb();
  fake.setStock("PEN-001", 30); // system says 30, counted 35 → +5 applies
  fake.setStock("PEN-002", 20); // system says 20, counted 12 → -8 pending

  const res = await recordStockCount(db(fake), ORG, SCHOOL, MAKER, {
    sessionNumber: "CNT-1",
    lines: [
      { sku: "PEN-001", countedQty: 35 },
      { sku: "PEN-002", countedQty: 12 },
    ],
  });

  const pos = res.lines.find((l) => l.sku === "PEN-001")!;
  assertEquals(pos.outcome, "applied_in");
  assertEquals(pos.variance, 5);
  assertEquals(fake.stock.get("PEN-001")!.quantity_on_hand, 35);

  const neg = res.lines.find((l) => l.sku === "PEN-002")!;
  assertEquals(neg.outcome, "pending_adjustment");
  assertEquals(neg.variance, -8);
  // Negative variance recorded, NOT silently overwritten: stock stays at 20.
  assertEquals(fake.stock.get("PEN-002")!.quantity_on_hand, 20);
  assertEquals(neg.adjustmentId !== null, true);
  const adj = fake.adjustments.get(neg.adjustmentId!)!;
  assertEquals(adj.movement_type, "count_variance");
  assertEquals(adj.qty, 8);
  assertEquals(adj.status, "pending");
});

Deno.test("INV-6: approving a negative count variance decrements once via maker-checker", async () => {
  const fake = new FakeStockDb();
  fake.setStock("PEN-002", 20);
  const res = await recordStockCount(db(fake), ORG, SCHOOL, MAKER, {
    sessionNumber: "CNT-2",
    lines: [{ sku: "PEN-002", countedQty: 12 }],
  });
  const adjustmentId = res.lines[0].adjustmentId!;
  const decided = await approveStockAdjustment(db(fake), ORG, SCHOOL, CHECKER, adjustmentId);
  assertEquals(decided.qtyAfter, 12);
  assertEquals(fake.stock.get("PEN-002")!.quantity_on_hand, 12);
  assertEquals(fake.movements.at(-1)!.movement_type, "count_variance");
});
