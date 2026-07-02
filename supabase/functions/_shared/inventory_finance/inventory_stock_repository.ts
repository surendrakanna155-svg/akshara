// INV-1..7 — Store stock module repository.
//
// Stock qty is the typed column inventory_stock_valuations.quantity_on_hand
// (per org/school/sku). Every stock-changing path here first takes a
//   SELECT quantity_on_hand ... FOR UPDATE
// on the valuation row INSIDE withTenantContext's open transaction, so two
// concurrent issues/adjustments serialize on that row and can never race the
// read-modify-write. Negative stock is hard-blocked (422 in the repo + a DB
// CHECK). Value-reducing movements (damage/wastage adjust_out, negative count
// variance) are RECORDED as pending stock_adjustments and only decrement stock
// when a DIFFERENT user approves (checker_id <> maker_id). Every applied movement
// writes exactly one immutable stock_movements ledger row (qty_before → qty_after).

import type { TenantQueryClient } from "../tenant_db.ts";

export type StockMovementType =
  | "grn"
  | "issue"
  | "adjust_in"
  | "adjust_out"
  | "count_variance"
  | "opening";

/** adjust_in / opening apply immediately; adjust_out is maker-checker. */
export type AdjustMovementType = "adjust_in" | "adjust_out" | "opening";

// ── Typed errors (mapped to HTTP status by the handlers) ──

export class InsufficientStockError extends Error {
  constructor(
    public readonly sku: string,
    public readonly requested: number,
    public readonly onHand: number,
  ) {
    super(`Insufficient stock for SKU ${sku}: requested ${requested}, on hand ${onHand}`);
    this.name = "InsufficientStockError";
  }
}

export class StockValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "StockValidationError";
  }
}

export class StockAdjustmentNotFoundError extends Error {
  constructor(public readonly id: string) {
    super(`Stock adjustment not found: ${id}`);
    this.name = "StockAdjustmentNotFoundError";
  }
}

export class StockAdjustmentInvalidStateError extends Error {
  constructor(public readonly id: string, public readonly status: string) {
    super(`Stock adjustment ${id} is not pending (status=${status})`);
    this.name = "StockAdjustmentInvalidStateError";
  }
}

/** Separation of duties: a value-reducing adjustment cannot be self-approved. */
export class StockSelfApproveDeniedError extends Error {
  constructor(public readonly id: string) {
    super(`Adjustment maker cannot approve their own request: ${id}`);
    this.name = "StockSelfApproveDeniedError";
  }
}

// ── Row shapes ──

interface StockRow {
  quantity_on_hand: number;
  weighted_avg_cost: number;
}

export interface StockAdjustmentRow {
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

// ── Shared helpers ──

/**
 * FOR UPDATE lock on the valuation row. Returns null when the SKU has no
 * valuation yet (nothing on hand — treat as 0). The lock is held until the
 * surrounding withTenantContext transaction commits/rolls back.
 */
async function lockStockRow(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  sku: string,
): Promise<StockRow | null> {
  const rows = await db.queryObject<StockRow>(
    `SELECT quantity_on_hand, weighted_avg_cost
       FROM inventory_stock_valuations
      WHERE organization_id = $1 AND school_id = $2 AND sku = $3
      FOR UPDATE`,
    [orgId, schoolId, sku],
  );
  return rows[0] ?? null;
}

/** Inserts one immutable ledger row. Costing is weighted-average (unit_cost carried on the row's valuation). */
async function insertMovement(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: {
    sku: string;
    movementType: StockMovementType;
    quantityDelta: number;
    qtyBefore: number;
    qtyAfter: number;
    reason: string;
    referenceType?: string | null;
    referenceId?: string | null;
    createdBy: string | null;
  },
): Promise<string> {
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO stock_movements (
       organization_id, school_id, sku, movement_type,
       quantity_delta, qty_before, qty_after, reason,
       reference_type, reference_id, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
     RETURNING id`,
    [
      orgId,
      schoolId,
      input.sku,
      input.movementType,
      input.quantityDelta,
      input.qtyBefore,
      input.qtyAfter,
      input.reason,
      input.referenceType ?? null,
      input.referenceId ?? null,
      input.createdBy,
    ],
  );
  return rows[0]!.id;
}

/** Weighted-average recompute for an inbound quantity (mirrors GRN's formula). */
function weightedAvg(oldQty: number, oldCost: number, addQty: number, addCost: number): number {
  const newQty = oldQty + addQty;
  return newQty > 0 ? Math.round((oldQty * oldCost + addQty * addCost) / newQty) : addCost;
}

// ── INV-1: issue stock (immediate decrement, hard negative-block) ──

export interface IssueLineInput {
  sku: string;
  quantity: number;
}

export interface IssueStockResult {
  issueId: string;
  issueNumber: string;
  posted: boolean;
  movementIds: string[];
}

/**
 * INV-1 — post an issue slip. Under the FOR-UPDATE lock per SKU: reject when the
 * requested quantity exceeds on-hand (422, never goes negative), else decrement
 * and write an immutable `issue` movement. The slip is `posted` (immutable) once
 * written; a slip id collision is idempotent (returns the existing slip, no
 * second decrement).
 */
export async function issueStock(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  userId: string | null,
  input: {
    issueNumber: string;
    issuedTo?: string;
    reason?: string;
    lines: IssueLineInput[];
  },
): Promise<IssueStockResult> {
  const issueNumber = input.issueNumber.trim();
  if (!issueNumber) throw new StockValidationError("issueNumber is required");
  const lines = (input.lines ?? []).filter((l) => l.sku?.trim() && Number(l.quantity) > 0);
  if (!lines.length) throw new StockValidationError("At least one issue line with quantity > 0 is required");

  // Idempotency: an already-posted slip with this number short-circuits (no
  // re-decrement). The unique (org, school, issue_number) index also backstops.
  const existing = await db.queryObject<{ id: string; posted: boolean }>(
    `SELECT id, posted FROM stock_issues
      WHERE organization_id = $1 AND school_id = $2 AND issue_number = $3`,
    [orgId, schoolId, issueNumber],
  );
  if (existing[0]) {
    return { issueId: existing[0].id, issueNumber, posted: existing[0].posted, movementIds: [] };
  }

  // Lock + validate every line BEFORE mutating anything (all-or-nothing within the txn).
  const locked: Array<{ sku: string; quantity: number; before: number; cost: number }> = [];
  for (const line of lines) {
    const sku = line.sku.trim();
    const quantity = Math.trunc(Number(line.quantity));
    const row = await lockStockRow(db, orgId, schoolId, sku);
    const onHand = row?.quantity_on_hand ?? 0;
    if (quantity > onHand) {
      throw new InsufficientStockError(sku, quantity, onHand);
    }
    locked.push({ sku, quantity, before: onHand, cost: row?.weighted_avg_cost ?? 0 });
  }

  const slipRows = await db.queryObject<{ id: string }>(
    `INSERT INTO stock_issues (
       organization_id, school_id, issue_number, issued_to, reason, status, posted, created_by
     ) VALUES ($1, $2, $3, $4, $5, 'posted', TRUE, $6)
     RETURNING id`,
    [orgId, schoolId, issueNumber, input.issuedTo ?? "", input.reason ?? "", userId],
  );
  const issueId = slipRows[0]!.id;

  const movementIds: string[] = [];
  for (const l of locked) {
    const after = l.before - l.quantity;
    await db.queryObject(
      `INSERT INTO stock_issue_lines (
         stock_issue_id, organization_id, school_id, sku, quantity, unit_cost
       ) VALUES ($1, $2, $3, $4, $5, $6)`,
      [issueId, orgId, schoolId, l.sku, l.quantity, l.cost],
    );
    await db.queryObject(
      `UPDATE inventory_stock_valuations
          SET quantity_on_hand = $4, last_valued_at = timezone('utc', now()),
              updated_at = timezone('utc', now())
        WHERE organization_id = $1 AND school_id = $2 AND sku = $3`,
      [orgId, schoolId, l.sku, after],
    );
    const movementId = await insertMovement(db, orgId, schoolId, {
      sku: l.sku,
      movementType: "issue",
      quantityDelta: -l.quantity,
      qtyBefore: l.before,
      qtyAfter: after,
      reason: input.reason ?? "",
      referenceType: "stock_issue",
      referenceId: issueId,
      createdBy: userId,
    });
    movementIds.push(movementId);
  }

  return { issueId, issueNumber, posted: true, movementIds };
}

// ── INV-3: adjust stock (in/opening = immediate; out = maker-checker) ──

export interface AdjustStockResult {
  applied: boolean; // true = stock changed now; false = pending maker-checker
  movementId: string | null;
  adjustmentId: string | null;
  qtyBefore: number;
  qtyAfter: number;
  status: "applied" | "pending";
}

/**
 * INV-3 — record a manual stock adjustment. `adjust_in` and `opening` (and any
 * positive movement) apply immediately under the row lock and write a movement.
 * `adjust_out` (damage/wastage) is VALUE-REDUCING → recorded as a `pending`
 * stock_adjustment (maker_id set, stock untouched) that a DIFFERENT user must
 * approve. A reason is mandatory on every adjustment.
 */
export async function adjustStock(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  userId: string | null,
  input: {
    sku: string;
    quantity: number;
    movementType: AdjustMovementType;
    reason: string;
    unitCost?: number;
  },
): Promise<AdjustStockResult> {
  const sku = input.sku?.trim();
  const quantity = Math.trunc(Number(input.quantity));
  const reason = input.reason?.trim() ?? "";
  if (!sku) throw new StockValidationError("sku is required");
  if (!(quantity > 0)) throw new StockValidationError("quantity must be greater than 0");
  if (!reason) throw new StockValidationError("reason is mandatory on adjustments");
  if (!["adjust_in", "adjust_out", "opening"].includes(input.movementType)) {
    throw new StockValidationError(`Unsupported adjustment type: ${input.movementType}`);
  }

  // Value-reducing → maker-checker: RECORD pending, do NOT touch qty.
  if (input.movementType === "adjust_out") {
    const rows = await db.queryObject<{ id: string }>(
      `INSERT INTO stock_adjustments (
         organization_id, school_id, sku, qty, movement_type, reason, status,
         reference_type, maker_id
       ) VALUES ($1, $2, $3, $4, 'adjust_out', $5, 'pending', 'manual_adjustment', $6)
       RETURNING id`,
      [orgId, schoolId, sku, quantity, reason, userId],
    );
    return {
      applied: false,
      movementId: null,
      adjustmentId: rows[0]!.id,
      qtyBefore: 0,
      qtyAfter: 0,
      status: "pending",
    };
  }

  // adjust_in / opening → apply immediately under the lock (weighted-avg on cost).
  const row = await lockStockRow(db, orgId, schoolId, sku);
  const before = row?.quantity_on_hand ?? 0;
  const after = before + quantity;
  const addCost = Number.isFinite(input.unitCost) ? Math.trunc(Number(input.unitCost)) : (row?.weighted_avg_cost ?? 0);

  if (!row) {
    const newAvg = weightedAvg(0, 0, quantity, addCost);
    await db.queryObject(
      `INSERT INTO inventory_stock_valuations (
         organization_id, school_id, sku, quantity_on_hand, weighted_avg_cost
       ) VALUES ($1, $2, $3, $4, $5)`,
      [orgId, schoolId, sku, after, newAvg],
    );
  } else {
    const newAvg = weightedAvg(before, row.weighted_avg_cost, quantity, addCost);
    await db.queryObject(
      `UPDATE inventory_stock_valuations
          SET quantity_on_hand = $4, weighted_avg_cost = $5,
              last_valued_at = timezone('utc', now()), updated_at = timezone('utc', now())
        WHERE organization_id = $1 AND school_id = $2 AND sku = $3`,
      [orgId, schoolId, sku, after, newAvg],
    );
  }

  const movementId = await insertMovement(db, orgId, schoolId, {
    sku,
    movementType: input.movementType,
    quantityDelta: quantity,
    qtyBefore: before,
    qtyAfter: after,
    reason,
    referenceType: "manual_adjustment",
    createdBy: userId,
  });

  return { applied: true, movementId, adjustmentId: null, qtyBefore: before, qtyAfter: after, status: "applied" };
}

// ── Maker-checker decisions for value-reducing adjustments ──

async function getPendingAdjustment(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  adjustmentId: string,
): Promise<StockAdjustmentRow> {
  // FOR UPDATE locks the adjustment row for the duration of the tenant txn, so
  // two checkers approving/rejecting the SAME adjustment concurrently serialize:
  // the second blocks here, then (post-commit) re-reads status='approved'/'rejected'
  // and is rejected by the guard below — no double-decrement of stock.
  const rows = await db.queryObject<StockAdjustmentRow>(
    `SELECT id, sku, qty, movement_type, reason, status, reference_type, reference_id,
            maker_id::text AS maker_id, checker_id::text AS checker_id,
            decision_comment, decided_at::text AS decided_at, created_at::text AS created_at
       FROM stock_adjustments
      WHERE id = $1 AND organization_id = $2 AND school_id = $3
      FOR UPDATE`,
    [adjustmentId, orgId, schoolId],
  );
  const row = rows[0];
  if (!row) throw new StockAdjustmentNotFoundError(adjustmentId);
  if (row.status !== "pending") throw new StockAdjustmentInvalidStateError(adjustmentId, row.status);
  return row;
}

export interface AdjustmentDecisionResult {
  adjustmentId: string;
  sku: string;
  status: "approved" | "rejected";
  movementId: string | null;
  qtyBefore: number;
  qtyAfter: number;
}

/**
 * Maker-checker APPROVE. The checker MUST differ from the maker (409 on
 * self-approve). On approve: FOR-UPDATE lock, hard-block if the decrement would
 * go negative (422), decrement, write an immutable movement, and flip the
 * adjustment to approved with checker_id + decided_at.
 */
export async function approveStockAdjustment(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  checkerId: string,
  adjustmentId: string,
  comment?: string | null,
): Promise<AdjustmentDecisionResult> {
  const adj = await getPendingAdjustment(db, orgId, schoolId, adjustmentId);
  if (adj.maker_id && adj.maker_id === checkerId) {
    throw new StockSelfApproveDeniedError(adjustmentId);
  }

  const row = await lockStockRow(db, orgId, schoolId, adj.sku);
  const before = row?.quantity_on_hand ?? 0;
  if (adj.qty > before) {
    throw new InsufficientStockError(adj.sku, adj.qty, before);
  }
  const after = before - adj.qty;

  await db.queryObject(
    `UPDATE inventory_stock_valuations
        SET quantity_on_hand = $4, last_valued_at = timezone('utc', now()),
            updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND sku = $3`,
    [orgId, schoolId, adj.sku, after],
  );

  const movementId = await insertMovement(db, orgId, schoolId, {
    sku: adj.sku,
    movementType: adj.movement_type === "count_variance" ? "count_variance" : "adjust_out",
    quantityDelta: -adj.qty,
    qtyBefore: before,
    qtyAfter: after,
    reason: adj.reason,
    referenceType: "stock_adjustment",
    referenceId: adjustmentId,
    createdBy: checkerId,
  });

  await db.queryObject(
    `UPDATE stock_adjustments
        SET status = 'approved', checker_id = $4, decision_comment = $5,
            decided_at = timezone('utc', now()), updated_at = timezone('utc', now())
      WHERE id = $1 AND organization_id = $2 AND school_id = $3 AND status = 'pending'`,
    [adjustmentId, orgId, schoolId, checkerId, comment?.trim() ?? null],
  );

  return { adjustmentId, sku: adj.sku, status: "approved", movementId, qtyBefore: before, qtyAfter: after };
}

/** Maker-checker REJECT. No stock change; the adjustment moves to rejected. */
export async function rejectStockAdjustment(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  checkerId: string,
  adjustmentId: string,
  comment?: string | null,
): Promise<AdjustmentDecisionResult> {
  const adj = await getPendingAdjustment(db, orgId, schoolId, adjustmentId);
  if (adj.maker_id && adj.maker_id === checkerId) {
    throw new StockSelfApproveDeniedError(adjustmentId);
  }
  await db.queryObject(
    `UPDATE stock_adjustments
        SET status = 'rejected', checker_id = $4, decision_comment = $5,
            decided_at = timezone('utc', now()), updated_at = timezone('utc', now())
      WHERE id = $1 AND organization_id = $2 AND school_id = $3 AND status = 'pending'`,
    [adjustmentId, orgId, schoolId, checkerId, comment?.trim() ?? null],
  );
  return { adjustmentId, sku: adj.sku, status: "rejected", movementId: null, qtyBefore: 0, qtyAfter: 0 };
}

export async function listPendingAdjustments(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<StockAdjustmentRow[]> {
  return await db.queryObject<StockAdjustmentRow>(
    `SELECT id, sku, qty, movement_type, reason, status, reference_type, reference_id,
            maker_id::text AS maker_id, checker_id::text AS checker_id,
            decision_comment, decided_at::text AS decided_at, created_at::text AS created_at
       FROM stock_adjustments
      WHERE organization_id = $1 AND school_id = $2 AND status = 'pending'
      ORDER BY created_at ASC
      LIMIT 200`,
    [orgId, schoolId],
  );
}

// ── INV-6: physical stock count ──

export interface CountLineInput {
  sku: string;
  countedQty: number;
}

export interface CountLineResult {
  sku: string;
  countedQty: number;
  systemQty: number;
  variance: number;
  outcome: "no_change" | "applied_in" | "pending_adjustment";
  movementId: string | null;
  adjustmentId: string | null;
}

export interface RecordCountResult {
  sessionId: string;
  sessionNumber: string;
  posted: boolean;
  lines: CountLineResult[];
}

/**
 * INV-6 — post a physical count session (immutable once posted). Per line, under
 * the FOR-UPDATE lock: variance = counted − system.
 *   variance > 0  → apply immediately as an `adjust_in`-style count_variance movement.
 *   variance < 0  → the negative variance is RECORDED as a pending maker-checker
 *                   stock_adjustment (not silently overwritten); stock is untouched
 *                   until a different user approves.
 *   variance == 0 → no change (still recorded on the count line for the audit).
 * An existing session with this number is idempotent (no re-apply).
 */
export async function recordStockCount(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  userId: string | null,
  input: {
    sessionNumber: string;
    notes?: string;
    lines: CountLineInput[];
  },
): Promise<RecordCountResult> {
  const sessionNumber = input.sessionNumber.trim();
  if (!sessionNumber) throw new StockValidationError("sessionNumber is required");
  const lines = (input.lines ?? []).filter((l) => l.sku?.trim() && Number.isFinite(Number(l.countedQty)) && Number(l.countedQty) >= 0);
  if (!lines.length) throw new StockValidationError("At least one count line is required");

  const existing = await db.queryObject<{ id: string; posted: boolean }>(
    `SELECT id, posted FROM stock_count_sessions
      WHERE organization_id = $1 AND school_id = $2 AND session_number = $3`,
    [orgId, schoolId, sessionNumber],
  );
  if (existing[0]) {
    return { sessionId: existing[0].id, sessionNumber, posted: existing[0].posted, lines: [] };
  }

  const sessionRows = await db.queryObject<{ id: string }>(
    `INSERT INTO stock_count_sessions (
       organization_id, school_id, session_number, notes, status, posted, created_by
     ) VALUES ($1, $2, $3, $4, 'posted', TRUE, $5)
     RETURNING id`,
    [orgId, schoolId, sessionNumber, input.notes ?? "", userId],
  );
  const sessionId = sessionRows[0]!.id;

  const results: CountLineResult[] = [];
  for (const line of lines) {
    const sku = line.sku.trim();
    const countedQty = Math.trunc(Number(line.countedQty));
    const row = await lockStockRow(db, orgId, schoolId, sku);
    const systemQty = row?.quantity_on_hand ?? 0;
    const variance = countedQty - systemQty;

    let outcome: CountLineResult["outcome"] = "no_change";
    let movementId: string | null = null;
    let adjustmentId: string | null = null;

    if (variance > 0) {
      // Positive variance applies immediately (found stock).
      outcome = "applied_in";
      if (!row) {
        await db.queryObject(
          `INSERT INTO inventory_stock_valuations (
             organization_id, school_id, sku, quantity_on_hand, weighted_avg_cost
           ) VALUES ($1, $2, $3, $4, 0)`,
          [orgId, schoolId, sku, countedQty],
        );
      } else {
        await db.queryObject(
          `UPDATE inventory_stock_valuations
              SET quantity_on_hand = $4, last_valued_at = timezone('utc', now()),
                  updated_at = timezone('utc', now())
            WHERE organization_id = $1 AND school_id = $2 AND sku = $3`,
          [orgId, schoolId, sku, countedQty],
        );
      }
      movementId = await insertMovement(db, orgId, schoolId, {
        sku,
        movementType: "count_variance",
        quantityDelta: variance,
        qtyBefore: systemQty,
        qtyAfter: countedQty,
        reason: `Stock count ${sessionNumber}: positive variance`,
        referenceType: "stock_count_session",
        referenceId: sessionId,
        createdBy: userId,
      });
    } else if (variance < 0) {
      // Negative variance → maker-checker pending (do NOT silently write down).
      outcome = "pending_adjustment";
      const adjRows = await db.queryObject<{ id: string }>(
        `INSERT INTO stock_adjustments (
           organization_id, school_id, sku, qty, movement_type, reason, status,
           reference_type, reference_id, maker_id
         ) VALUES ($1, $2, $3, $4, 'count_variance', $5, 'pending', 'stock_count_session', $6, $7)
         RETURNING id`,
        [orgId, schoolId, sku, Math.abs(variance), `Stock count ${sessionNumber}: negative variance`, sessionId, userId],
      );
      adjustmentId = adjRows[0]!.id;
    }

    await db.queryObject(
      `INSERT INTO stock_count_lines (
         stock_count_session_id, organization_id, school_id, sku,
         counted_qty, system_qty, variance, outcome, adjustment_id
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
      [sessionId, orgId, schoolId, sku, countedQty, systemQty, variance, outcome, adjustmentId],
    );

    results.push({ sku, countedQty, systemQty, variance, outcome, movementId, adjustmentId });
  }

  return { sessionId, sessionNumber, posted: true, lines: results };
}

// ── INV-2: consumable + reorder-level CRUD ──

export interface StockItemRow {
  sku: string;
  item_name: string | null;
  item_type: string;
  reorder_level: number;
  quantity_on_hand: number;
  weighted_avg_cost: number;
}

/**
 * INV-2 — upsert a consumable/asset stock item and its reorder level. Does NOT
 * change quantity_on_hand (stock only moves through movements); this manages the
 * catalog metadata for a SKU. Creates the valuation row at qty 0 if new.
 */
export async function upsertStockItem(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: {
    sku: string;
    itemName?: string | null;
    itemType?: "asset" | "consumable";
    reorderLevel?: number;
    unitCost?: number;
  },
): Promise<StockItemRow> {
  const sku = input.sku?.trim();
  if (!sku) throw new StockValidationError("sku is required");
  const itemType = input.itemType === "consumable" ? "consumable" : (input.itemType === "asset" ? "asset" : "consumable");
  const reorderLevel = Number.isFinite(Number(input.reorderLevel)) ? Math.max(0, Math.trunc(Number(input.reorderLevel))) : 0;
  const unitCost = Number.isFinite(Number(input.unitCost)) ? Math.max(0, Math.trunc(Number(input.unitCost))) : 0;

  const rows = await db.queryObject<StockItemRow>(
    `INSERT INTO inventory_stock_valuations (
       organization_id, school_id, sku, quantity_on_hand, weighted_avg_cost,
       item_type, reorder_level, item_name
     ) VALUES ($1, $2, $3, 0, $7, $4, $5, $6)
     ON CONFLICT (organization_id, school_id, sku) DO UPDATE
       SET item_type = EXCLUDED.item_type,
           reorder_level = EXCLUDED.reorder_level,
           item_name = COALESCE(EXCLUDED.item_name, inventory_stock_valuations.item_name),
           updated_at = timezone('utc', now())
     RETURNING sku, item_name, item_type, reorder_level, quantity_on_hand, weighted_avg_cost`,
    [orgId, schoolId, sku, itemType, reorderLevel, input.itemName ?? null, unitCost],
  );
  return rows[0]!;
}

export async function listStockItems(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<StockItemRow[]> {
  return await db.queryObject<StockItemRow>(
    `SELECT sku, item_name, item_type, reorder_level, quantity_on_hand, weighted_avg_cost
       FROM inventory_stock_valuations
      WHERE organization_id = $1 AND school_id = $2
      ORDER BY sku ASC
      LIMIT 500`,
    [orgId, schoolId],
  );
}

// ── INV-4/5: low-stock list + stock register (ledger) ──

export interface LowStockRow {
  sku: string;
  itemName: string;
  quantityOnHand: number;
  reorderLevel: number;
  recommendedQuantity: number;
  vendorId: string | null;
}

/**
 * INV-4/5 — SKUs at or below their reorder level. Each row carries a
 * recommendedQuantity (top up to 2× reorder level, min 1) and a default vendorId
 * (most recent PO vendor for the SKU) so the client can raise a PO against the
 * EXISTING POST /inventory/procurement/orders — no PO logic lives here.
 */
export async function listLowStock(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<LowStockRow[]> {
  const rows = await db.queryObject<{
    sku: string;
    item_name: string | null;
    quantity_on_hand: number;
    reorder_level: number;
    vendor_id: string | null;
  }>(
    `SELECT v.sku, v.item_name, v.quantity_on_hand, v.reorder_level,
            (SELECT po.vendor_id::text
               FROM purchase_order_lines pol
               JOIN purchase_orders po ON po.id = pol.purchase_order_id
              WHERE pol.organization_id = v.organization_id
                AND pol.school_id = v.school_id
                AND pol.sku = v.sku
              ORDER BY po.created_at DESC
              LIMIT 1) AS vendor_id
       FROM inventory_stock_valuations v
      WHERE v.organization_id = $1 AND v.school_id = $2
        AND v.reorder_level > 0
        AND v.quantity_on_hand < v.reorder_level
      ORDER BY (v.reorder_level - v.quantity_on_hand) DESC
      LIMIT 200`,
    [orgId, schoolId],
  );
  return rows.map((r) => {
    const reorder = r.reorder_level;
    const onHand = r.quantity_on_hand;
    const recommended = Math.max(1, reorder * 2 - onHand);
    return {
      sku: r.sku,
      itemName: r.item_name ?? r.sku,
      quantityOnHand: onHand,
      reorderLevel: reorder,
      recommendedQuantity: recommended,
      vendorId: r.vendor_id,
    };
  });
}

export interface StockRegisterRow {
  id: string;
  sku: string;
  movementType: string;
  quantityDelta: number;
  qtyBefore: number;
  qtyAfter: number;
  reason: string;
  referenceType: string | null;
  referenceId: string | null;
  createdBy: string | null;
  createdAt: string;
}

/** INV-5 — the immutable stock register (ledger) for the school, newest first. */
export async function listStockRegister(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  sku?: string | null,
): Promise<StockRegisterRow[]> {
  const args: unknown[] = [orgId, schoolId];
  let filter = "";
  if (sku?.trim()) {
    filter = " AND sku = $3";
    args.push(sku.trim());
  }
  const rows = await db.queryObject<{
    id: string;
    sku: string;
    movement_type: string;
    quantity_delta: number;
    qty_before: number;
    qty_after: number;
    reason: string;
    reference_type: string | null;
    reference_id: string | null;
    created_by: string | null;
    created_at: string;
  }>(
    `SELECT id, sku, movement_type, quantity_delta, qty_before, qty_after, reason,
            reference_type, reference_id, created_by::text AS created_by, created_at::text AS created_at
       FROM stock_movements
      WHERE organization_id = $1 AND school_id = $2${filter}
      ORDER BY created_at DESC
      LIMIT 300`,
    args,
  );
  return rows.map((r) => ({
    id: r.id,
    sku: r.sku,
    movementType: r.movement_type,
    quantityDelta: r.quantity_delta,
    qtyBefore: r.qty_before,
    qtyAfter: r.qty_after,
    reason: r.reason,
    referenceType: r.reference_type,
    referenceId: r.reference_id,
    createdBy: r.created_by,
    createdAt: r.created_at,
  }));
}

/**
 * Retrofit hook for GRN: appends a `grn` movement row so goods receipts join the
 * ledger. Called from inventory_finance_repository.upsertStockValuation after the
 * qty write, using the before/after it already computed.
 */
export async function recordGrnMovement(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: {
    sku: string;
    qtyReceived: number;
    qtyBefore: number;
    qtyAfter: number;
    createdBy: string | null;
    referenceId?: string | null;
  },
): Promise<string> {
  return await insertMovement(db, orgId, schoolId, {
    sku: input.sku,
    movementType: "grn",
    quantityDelta: input.qtyReceived,
    qtyBefore: input.qtyBefore,
    qtyAfter: input.qtyAfter,
    reason: "Goods receipt",
    referenceType: "goods_receipt",
    referenceId: input.referenceId ?? null,
    createdBy: input.createdBy,
  });
}
