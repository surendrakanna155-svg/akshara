import type { TenantQueryClient } from "../tenant_db.ts";
import { upsertPaymentRequest } from "../payment/payment_repository.ts";
// PRA-P1-37 (S1): reuse the store-stock module's typed insufficient-stock error
// so a student distribution refuses (never floors) an over-issue, exactly like
// the typed stock issue path (inventory_stock_repository.issueStock).
import { InsufficientStockError } from "../inventory_finance/inventory_stock_repository.ts";

export interface CatalogItemRow {
  id: string;
  category: string;
  name: string;
  sku_code: string | null;
  unit_price: number;
  stock_on_hand: number;
  status: string;
}

export interface DistributionRow {
  id: string;
  student_id: string;
  catalog_item_id: string;
  quantity: number;
  status: string;
  distributed_at: string | null;
  acknowledged_at: string | null;
  payment_request_id: string | null;
  replacement_of_id: string | null;
  notes: string | null;
  created_at: string;
  /// RMA-style approval sub-state for the replacements workflow (FV-12):
  /// pending -> approved -> fulfilled, or -> rejected. Independent of `status`.
  replacement_status?: string | null;
  replacement_requested_at?: string | null;
  replacement_resolved_at?: string | null;
  replacement_rejection_reason?: string | null;
}

/** A replacement request could not be found (wrong id, or not a replacement at all). */
export class ReplacementRequestNotFoundError extends Error {
  constructor(public readonly id: string) {
    super(`Replacement request not found: ${id}`);
    this.name = "ReplacementRequestNotFoundError";
  }
}

/** The request exists but isn't in the right sub-state for the attempted action. */
export class ReplacementRequestInvalidStateError extends Error {
  constructor(public readonly id: string, public readonly status: string | null | undefined) {
    super(`Replacement request ${id} is not in a valid state for this action (status=${status ?? "none"})`);
    this.name = "ReplacementRequestInvalidStateError";
  }
}

/**
 * Gap-remediation P0-3: an `UPDATE ... RETURNING` on `inv_student_distributions`
 * that should affect exactly one row affected zero. Postgres does NOT raise an
 * error when an RLS policy silently filters an UPDATE down to 0 rows (unlike
 * `INSERT ... RETURNING`, which raises on a WITH CHECK violation) — so a
 * caller that does `rows[0]!` gets `undefined` at runtime with no signal;
 * the `!` is a compile-time-only assertion.
 *
 * That masked exactly this bug: a parent-scope session could pass the
 * RLS-gated SELECT/INSERT steps of a replacement request (the parent read
 * policy + `payment_requests_parent_scope`) and then have the *status* UPDATE
 * on `inv_student_distributions` silently dropped by the school-only FOR ALL
 * policy — while the `payment_request` it had just inserted, in the SAME
 * transaction, still committed.
 *
 * Every call site below now throws this instead of swallowing the empty
 * result. Because every repository call runs inside the single
 * BEGIN/COMMIT-or-ROLLBACK transaction `withTenantContext` opens (see
 * tenant_db.ts), throwing here makes the WHOLE operation roll back — so a
 * blocked/failed status transition can never coexist with a committed
 * payment_request (or a fabricated new distribution row, for `fulfill`) for
 * the same request.
 */
export class DistributionUpdateBlockedError extends Error {
  constructor(public readonly id: string, public readonly action: string) {
    super(
      `${action} affected 0 rows for distribution ${id} — blocked by RLS ` +
        `(wrong scope/ownership) or a concurrent change; rolling back`,
    );
    this.name = "DistributionUpdateBlockedError";
  }
}

/** Fails loudly instead of returning `rows[0]!` (see DistributionUpdateBlockedError). */
function requireUpdatedRow<T>(rows: T[], id: string, action: string): T {
  const row = rows[0];
  if (!row) throw new DistributionUpdateBlockedError(id, action);
  return row;
}

export interface DistributionDashboard {
  pendingDistributions: number;
  replacementRequests: number;
  paymentPending: number;
  distributedToday: number;
  byCategory: Array<{ category: string; count: number }>;
}

export async function listCatalogItems(
  client: TenantQueryClient,
  category?: string,
): Promise<CatalogItemRow[]> {
  const conditions = ["status = 'active'"];
  const params: unknown[] = [];
  if (category) {
    conditions.push(`category = $1`);
    params.push(category);
  }
  return await client.queryObject<CatalogItemRow>(
    `SELECT id, category, name, sku_code, unit_price, stock_on_hand, status
     FROM inv_catalog_items
     WHERE ${conditions.join(" AND ")}
     ORDER BY category, name`,
    params,
  );
}

export async function listStudentDistributions(
  client: TenantQueryClient,
  filters: { studentId?: string; status?: string },
): Promise<Array<DistributionRow & { itemName: string; category: string }>> {
  const conditions = ["1=1"];
  const params: unknown[] = [];
  let idx = 1;
  if (filters.studentId) {
    conditions.push(`d.student_id = $${idx}`);
    params.push(filters.studentId);
    idx += 1;
  }
  if (filters.status) {
    conditions.push(`d.status = $${idx}`);
    params.push(filters.status);
    idx += 1;
  }
  return await client.queryObject<DistributionRow & { itemName: string; category: string }>(
    `SELECT d.*, c.name AS "itemName", c.category
     FROM inv_student_distributions d
     JOIN inv_catalog_items c ON c.id = d.catalog_item_id
     WHERE ${conditions.join(" AND ")}
     ORDER BY d.created_at DESC`,
    params,
  );
}

export async function createDistribution(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: {
    studentId: string;
    catalogItemId: string;
    quantity: number;
    createdBy: string | null;
    /// Set when this distribution is the physical item reissued to fulfil a
    /// replacement request — links back to the original row.
    replacementOfId?: string | null;
    /// Who the first-time issuance charge (PRA-P1-38) is raised against. Defaults
    /// to `createdBy` (the staff who issued) when the caller supplies no distinct
    /// payer; only used for a priced, non-replacement issue.
    payerUserId?: string | null;
  },
): Promise<DistributionRow> {
  // PRA-P1-37 (S1): lock the catalog row and hard-block a negative-stock issue.
  // Under READ COMMITTED two concurrent issues could each read the same
  // stock_on_hand and both slip past a naive check; the FOR UPDATE serializes
  // them on the row (mirrors the stock module's lockStockRow discipline). The
  // old `greatest(0, stock_on_hand - qty)` clamp SILENTLY masked an over-issue by
  // flooring at 0 — it is removed: stock is validated here and decremented
  // WITHOUT a clamp, so it can never go negative and an over-issue is refused
  // (InsufficientStockError) instead of hidden.
  const catalog = await client.queryObject<{
    sku_code: string | null;
    unit_price: number;
    stock_on_hand: number;
  }>(
    `SELECT sku_code, unit_price, stock_on_hand
       FROM inv_catalog_items
      WHERE id = $1
      FOR UPDATE`,
    [input.catalogItemId],
  );
  const item = catalog[0];
  if (!item) throw new Error("Catalog item not found");
  if (input.quantity > item.stock_on_hand) {
    throw new InsufficientStockError(
      item.sku_code ?? input.catalogItemId,
      input.quantity,
      item.stock_on_hand,
    );
  }

  const rows = await client.queryObject<DistributionRow>(
    `INSERT INTO inv_student_distributions (
       organization_id, school_id, student_id, catalog_item_id,
       quantity, status, created_by, replacement_of_id
     ) VALUES ($1, $2, $3, $4, $5, 'available', $6, $7)
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.studentId,
      input.catalogItemId,
      input.quantity,
      input.createdBy,
      input.replacementOfId ?? null,
    ],
  );
  const distribution = rows[0]!;

  // PRA-P1-37 (S1): decrement WITHOUT the greatest() clamp — the FOR UPDATE read
  // above already proved quantity <= stock_on_hand, and the DB CHECK backstops.
  await client.queryObject(
    `UPDATE inv_catalog_items
        SET stock_on_hand = stock_on_hand - $1
      WHERE id = $2`,
    [input.quantity, input.catalogItemId],
  );

  // PRA-P1-38 (S1): bill a first-time issuance of a PRICED item — previously
  // issuance was never billed (only requestReplacement charged). Single-charge
  // reconciliation: a REPLACEMENT re-issue (replacement_of_id set) is NOT billed
  // here because the replacement is already charged once at REQUEST time in
  // requestReplacement (sourceType 'inventory_replacement'); billing on fulfil
  // too would double-charge the same event. So the one charge point per event is
  //   first issue        -> here            (sourceType 'inventory_issue')
  //   replacement request -> requestReplacement ('inventory_replacement')
  // Mirrors requestReplacement's billing (upsertPaymentRequest, amount = price*qty).
  const payerUserId = input.payerUserId ?? input.createdBy;
  if (input.replacementOfId == null && item.unit_price > 0 && payerUserId) {
    const request = await upsertPaymentRequest(client, {
      organizationId,
      schoolId,
      studentId: input.studentId,
      payerUserId,
      sourceType: "inventory_issue",
      sourceId: distribution.id,
      invoiceId: null,
      amount: item.unit_price * input.quantity,
      idempotencyKey: `inv-issue-${distribution.id}`,
    });
    await client.queryObject(
      `UPDATE inv_student_distributions
          SET payment_request_id = $1
        WHERE id = $2`,
      [request.id, distribution.id],
    );
    distribution.payment_request_id = request.id;
  }

  return distribution;
}

export async function transitionDistributionStatus(
  client: TenantQueryClient,
  distributionId: string,
  status: string,
  notes?: string,
): Promise<DistributionRow> {
  const extra = status === "distributed"
    ? ", distributed_at = timezone('utc', now())"
    : status === "parent_acknowledged"
    ? ", acknowledged_at = timezone('utc', now())"
    : "";
  const rows = await client.queryObject<DistributionRow>(
    `UPDATE inv_student_distributions
     SET status = $1, notes = coalesce($2, notes)${extra}
     WHERE id = $3
     RETURNING *`,
    [status, notes ?? null, distributionId],
  );
  if (!rows[0]) throw new Error("Distribution not found");
  return rows[0];
}

export async function requestReplacement(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  distributionId: string,
  payerUserId: string,
  notes?: string,
): Promise<{ distribution: DistributionRow; paymentRequestId: string | null }> {
  const current = await client.queryObject<DistributionRow & { unit_price: number }>(
    `SELECT d.*, c.unit_price
     FROM inv_student_distributions d
     JOIN inv_catalog_items c ON c.id = d.catalog_item_id
     WHERE d.id = $1`,
    [distributionId],
  );
  const row = current[0];
  if (!row) throw new Error("Distribution not found");

  let paymentRequestId: string | null = null;
  if (row.unit_price > 0) {
    const request = await upsertPaymentRequest(client, {
      organizationId,
      schoolId,
      studentId: row.student_id,
      payerUserId,
      sourceType: "inventory_replacement",
      sourceId: distributionId,
      invoiceId: null,
      amount: row.unit_price * row.quantity,
      idempotencyKey: `inv-replacement-${distributionId}`,
    });
    paymentRequestId = request.id;
  }

  const updated = await client.queryObject<DistributionRow>(
    `UPDATE inv_student_distributions
     SET status = $1, payment_request_id = $2, notes = coalesce($3, notes),
         replacement_status = 'pending', replacement_requested_at = timezone('utc', now())
     WHERE id = $4
     RETURNING *`,
    [
      paymentRequestId ? "payment_pending" : "replacement_requested",
      paymentRequestId,
      notes ?? null,
      distributionId,
    ],
  );

  const distribution = requireUpdatedRow(updated, distributionId, "requestReplacement");
  return { distribution, paymentRequestId };
}

/**
 * FV-12 replacement workflow — lists distributions currently carrying an open
 * (or resolved) replacement sub-state, optionally filtered by that sub-state.
 * Reuses `inv_student_distributions`/`requestReplacement` rather than a
 * parallel "replacement requests" table: the distribution row IS the request.
 */
export async function listReplacementRequests(
  client: TenantQueryClient,
  status?: string,
): Promise<Array<DistributionRow & { itemName: string; category: string }>> {
  const conditions = ["d.replacement_status IS NOT NULL"];
  const params: unknown[] = [];
  if (status) {
    conditions.push("d.replacement_status = $1");
    params.push(status);
  }
  return await client.queryObject<DistributionRow & { itemName: string; category: string }>(
    `SELECT d.*, c.name AS "itemName", c.category
     FROM inv_student_distributions d
     JOIN inv_catalog_items c ON c.id = d.catalog_item_id
     WHERE ${conditions.join(" AND ")}
     ORDER BY d.replacement_requested_at DESC NULLS LAST, d.created_at DESC`,
    params,
  );
}

async function loadReplacementRequest(
  client: TenantQueryClient,
  requestId: string,
): Promise<DistributionRow> {
  // PRA-M-1 (S1): lock the row FOR UPDATE so concurrent approve/reject/fulfill
  // calls on the same request serialize on it (mirrors finance_fee_reductions'
  // getReductionForUpdate + the stock module's getPendingAdjustment). Combined
  // with the pre-state predicate added to each terminal UPDATE below, a lost
  // race can only ever match 0 rows → requireUpdatedRow throws (rolling the txn
  // back) instead of double-applying: double-issuing stock on a second fulfil or
  // re-billing on a second request/approve.
  const rows = await client.queryObject<DistributionRow>(
    `SELECT * FROM inv_student_distributions
      WHERE id = $1 AND replacement_status IS NOT NULL
      FOR UPDATE`,
    [requestId],
  );
  const row = rows[0];
  if (!row) throw new ReplacementRequestNotFoundError(requestId);
  return row;
}

export async function approveReplacementRequest(
  client: TenantQueryClient,
  requestId: string,
): Promise<DistributionRow & { itemName: string; category: string }> {
  const current = await loadReplacementRequest(client, requestId);
  if (current.replacement_status !== "pending") {
    throw new ReplacementRequestInvalidStateError(requestId, current.replacement_status);
  }
  const rows = await client.queryObject<DistributionRow & { itemName: string; category: string }>(
    // PRA-M-1 (S1): guard the pre-state in the terminal write. If a concurrent
    // call already moved it off 'pending', this matches 0 rows and
    // requireUpdatedRow throws instead of a lost-update double-approve.
    `UPDATE inv_student_distributions d
     SET replacement_status = 'approved'
     FROM inv_catalog_items c
     WHERE d.id = $1 AND c.id = d.catalog_item_id
       AND d.replacement_status = 'pending'
     RETURNING d.*, c.name AS "itemName", c.category`,
    [requestId],
  );
  return requireUpdatedRow(rows, requestId, "approveReplacementRequest");
}

export async function rejectReplacementRequest(
  client: TenantQueryClient,
  requestId: string,
  reason?: string,
): Promise<DistributionRow & { itemName: string; category: string }> {
  const current = await loadReplacementRequest(client, requestId);
  if (current.replacement_status !== "pending" && current.replacement_status !== "approved") {
    throw new ReplacementRequestInvalidStateError(requestId, current.replacement_status);
  }
  const rows = await client.queryObject<DistributionRow & { itemName: string; category: string }>(
    // PRA-M-1 (S1): guard the pre-state — reject is valid only from
    // 'pending'/'approved'. A concurrent transition off those states matches 0
    // rows so requireUpdatedRow throws rather than clobbering a resolved request.
    `UPDATE inv_student_distributions d
     SET replacement_status = 'rejected',
         replacement_resolved_at = timezone('utc', now()),
         replacement_rejection_reason = $2
     FROM inv_catalog_items c
     WHERE d.id = $1 AND c.id = d.catalog_item_id
       AND d.replacement_status IN ('pending', 'approved')
     RETURNING d.*, c.name AS "itemName", c.category`,
    [requestId, reason ?? null],
  );
  return requireUpdatedRow(rows, requestId, "rejectReplacementRequest");
}

/**
 * Fulfils an approved replacement: issues a brand-new physical item via the
 * same `createDistribution` path used for any other distribution (so stock
 * is decremented exactly once, the same as every other issuance), linked
 * back with `replacement_of_id`. The original row is marked `fulfilled` and
 * its overall lifecycle `status` moves to `reissued` — a bucket the
 * dashboard/reports already count (see buildDistributionReports) but that,
 * before this workflow, no code path ever produced.
 */
export async function fulfillReplacementRequest(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  requestId: string,
  createdBy: string | null,
): Promise<DistributionRow & { itemName: string; category: string }> {
  const current = await loadReplacementRequest(client, requestId);
  if (current.replacement_status !== "approved") {
    throw new ReplacementRequestInvalidStateError(requestId, current.replacement_status);
  }

  await createDistribution(client, organizationId, schoolId, {
    studentId: current.student_id,
    catalogItemId: current.catalog_item_id,
    quantity: current.quantity,
    createdBy,
    replacementOfId: current.id,
  });

  const rows = await client.queryObject<DistributionRow & { itemName: string; category: string }>(
    // PRA-M-1 (S1): guard the pre-state 'approved'. This is the write that
    // matters most — createDistribution above already issued (and decremented
    // stock for) the replacement item. If a second concurrent fulfil reaches
    // here after the first flipped the row off 'approved', it matches 0 rows and
    // requireUpdatedRow throws, rolling back its duplicate stock issue.
    `UPDATE inv_student_distributions d
     SET replacement_status = 'fulfilled',
         replacement_resolved_at = timezone('utc', now()),
         status = 'reissued'
     FROM inv_catalog_items c
     WHERE d.id = $1 AND c.id = d.catalog_item_id
       AND d.replacement_status = 'approved'
     RETURNING d.*, c.name AS "itemName", c.category`,
    [requestId],
  );
  return requireUpdatedRow(rows, requestId, "fulfillReplacementRequest");
}

export async function buildDistributionDashboard(
  client: TenantQueryClient,
): Promise<DistributionDashboard> {
  const counts = await client.queryObject<{
    pending: number;
    replacements: number;
    payment_pending: number;
    distributed_today: number;
  }>(
    `SELECT
       count(*) FILTER (WHERE status IN ('available', 'received'))::int AS pending,
       count(*) FILTER (WHERE status = 'replacement_requested')::int AS replacements,
       count(*) FILTER (WHERE status = 'payment_pending')::int AS payment_pending,
       count(*) FILTER (
         WHERE status = 'distributed'
           AND distributed_at::date = CURRENT_DATE
       )::int AS distributed_today
     FROM inv_student_distributions`,
  );

  const byCategory = await client.queryObject<{ category: string; count: number }>(
    `SELECT c.category, count(*)::int AS count
     FROM inv_student_distributions d
     JOIN inv_catalog_items c ON c.id = d.catalog_item_id
     GROUP BY c.category
     ORDER BY count DESC`,
  );

  return {
    pendingDistributions: counts[0]?.pending ?? 0,
    replacementRequests: counts[0]?.replacements ?? 0,
    paymentPending: counts[0]?.payment_pending ?? 0,
    distributedToday: counts[0]?.distributed_today ?? 0,
    byCategory: byCategory.map((c) => ({ category: c.category, count: c.count })),
  };
}

export interface DistributionReports {
  pending: number;
  issued: number;
  replacement: number;
  lost: number;
  damaged: number;
  byKitCategory: Array<{ category: string; pending: number; issued: number }>;
}

export async function buildDistributionReports(
  client: TenantQueryClient,
): Promise<DistributionReports> {
  const counts = await client.queryObject<{
    pending: number;
    issued: number;
    replacement: number;
    lost: number;
    damaged: number;
  }>(
    `SELECT
       count(*) FILTER (WHERE status IN ('available', 'received', 'distributed'))::int AS pending,
       count(*) FILTER (WHERE status IN ('parent_acknowledged', 'reissued'))::int AS issued,
       count(*) FILTER (WHERE status IN ('replacement_requested', 'payment_pending', 'paid'))::int AS replacement,
       count(*) FILTER (WHERE status = 'lost')::int AS lost,
       count(*) FILTER (WHERE status = 'damaged')::int AS damaged
     FROM inv_student_distributions`,
  );

  const byKit = await client.queryObject<{ category: string; pending: number; issued: number }>(
    `SELECT c.category,
       count(*) FILTER (WHERE d.status IN ('available', 'received', 'distributed'))::int AS pending,
       count(*) FILTER (WHERE d.status IN ('parent_acknowledged', 'reissued'))::int AS issued
     FROM inv_student_distributions d
     JOIN inv_catalog_items c ON c.id = d.catalog_item_id
     GROUP BY c.category
     ORDER BY c.category`,
  );

  const row = counts[0];
  return {
    pending: row?.pending ?? 0,
    issued: row?.issued ?? 0,
    replacement: row?.replacement ?? 0,
    lost: row?.lost ?? 0,
    damaged: row?.damaged ?? 0,
    byKitCategory: byKit.map((k) => ({
      category: k.category,
      pending: k.pending,
      issued: k.issued,
    })),
  };
}
