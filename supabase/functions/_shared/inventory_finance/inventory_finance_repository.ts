import type { TenantQueryClient } from "../tenant_db.ts";
import { recordGrnMovement } from "./inventory_stock_repository.ts";

export const INVENTORY_VENDOR_PROBE_SCHOOL_A = "d8000000-0000-4000-8000-000000000001";
export const INVENTORY_VENDOR_PROBE_SCHOOL_B = "d8000000-0000-4000-8000-000000000002";
export const INVENTORY_VENDOR_PROBE_SQL = `
  SELECT count(*)::text AS count FROM inventory_vendors WHERE id = $1::uuid
`;

export const PURCHASE_ORDER_PROBE_SCHOOL_A = "d8100000-0000-4000-8000-000000000001";
export const PURCHASE_ORDER_PROBE_SCHOOL_B = "d8100000-0000-4000-8000-000000000002";
export const PURCHASE_ORDER_PROBE_SQL = `
  SELECT count(*)::text AS count FROM purchase_orders WHERE id = $1::uuid
`;

export const AP_COMMITMENT_PROBE_SCHOOL_A = "d8200000-0000-4000-8000-000000000001";
export const AP_COMMITMENT_PROBE_SCHOOL_B = "d8200000-0000-4000-8000-000000000002";
export const AP_COMMITMENT_PROBE_SQL = `
  SELECT count(*)::text AS count FROM finance_ap_commitments WHERE id = $1::uuid
`;

export interface PurchaseOrderLineInput {
  sku: string;
  description: string;
  quantity: number;
  unitCost: number;
}

export interface VendorRow {
  id: string;
  vendor_code: string;
  display_name: string;
  contact_phone: string | null;
  contact_email: string | null;
  gstin: string | null;
  status: string;
}

export interface PurchaseOrderRow {
  id: string;
  po_number: string;
  vendor_id: string;
  status: string;
  total_amount: number;
  currency: string;
  created_at: string;
}

export class PurchaseOrderNotFoundError extends Error {
  constructor(id: string) {
    super(`Purchase order not found: ${id}`);
    this.name = "PurchaseOrderNotFoundError";
  }
}

export class InvalidPurchaseOrderStateError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvalidPurchaseOrderStateError";
  }
}

export async function listVendors(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<VendorRow[]> {
  return await db.queryObject<VendorRow>(
    `SELECT id, vendor_code, display_name, contact_phone, contact_email, gstin, status
     FROM inventory_vendors
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY display_name ASC`,
    [organizationId, schoolId],
  );
}

export async function createVendor(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: {
    vendorCode: string;
    displayName: string;
    contactPhone?: string;
    contactEmail?: string;
    gstin?: string;
  },
): Promise<VendorRow> {
  const rows = await db.queryObject<VendorRow>(
    `INSERT INTO inventory_vendors (
       organization_id, school_id, vendor_code, display_name,
       contact_phone, contact_email, gstin
     ) VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, vendor_code, display_name, contact_phone, contact_email, gstin, status`,
    [
      organizationId,
      schoolId,
      input.vendorCode.trim(),
      input.displayName.trim(),
      input.contactPhone ?? null,
      input.contactEmail ?? null,
      input.gstin ?? null,
    ],
  );
  return rows[0]!;
}

export async function createPurchaseOrder(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  requestedBy: string,
  input: {
    vendorId: string;
    poNumber: string;
    notes?: string;
    lines: PurchaseOrderLineInput[];
  },
): Promise<PurchaseOrderRow> {
  if (!input.lines.length) throw new Error("PO_LINES_REQUIRED");

  const total = input.lines.reduce(
    (sum, line) => sum + line.quantity * line.unitCost,
    0,
  );

  const poRows = await db.queryObject<PurchaseOrderRow>(
    `INSERT INTO purchase_orders (
       organization_id, school_id, vendor_id, po_number, total_amount,
       requested_by, notes
     ) VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, po_number, vendor_id, status, total_amount, currency, created_at`,
    [
      organizationId,
      schoolId,
      input.vendorId,
      input.poNumber.trim(),
      total,
      requestedBy,
      input.notes ?? "",
    ],
  );
  const po = poRows[0]!;

  for (const line of input.lines) {
    const lineTotal = line.quantity * line.unitCost;
    await db.queryObject(
      `INSERT INTO purchase_order_lines (
         purchase_order_id, organization_id, school_id, sku, description,
         quantity, unit_cost, line_total
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        po.id,
        organizationId,
        schoolId,
        line.sku.trim(),
        line.description.trim(),
        line.quantity,
        line.unitCost,
        lineTotal,
      ],
    );
  }

  return po;
}

export async function getPurchaseOrder(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  purchaseOrderId: string,
): Promise<PurchaseOrderRow | null> {
  const rows = await db.queryObject<PurchaseOrderRow>(
    `SELECT id, po_number, vendor_id, status, total_amount, currency, created_at
     FROM purchase_orders
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [purchaseOrderId, organizationId, schoolId],
  );
  return rows[0] ?? null;
}

export async function approvePurchaseOrder(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  purchaseOrderId: string,
  approvedBy: string,
): Promise<{
  purchaseOrder: PurchaseOrderRow;
  apCommitmentId: string;
  financePostingId: string;
}> {
  const po = await getPurchaseOrder(db, organizationId, schoolId, purchaseOrderId);
  if (!po) throw new PurchaseOrderNotFoundError(purchaseOrderId);
  if (po.status !== "draft") {
    throw new InvalidPurchaseOrderStateError(`Cannot approve PO in status ${po.status}`);
  }

  await db.queryObject(
    `UPDATE purchase_orders
     SET status = 'approved', approved_by = $2, approved_at = timezone('utc', now()),
         updated_at = timezone('utc', now())
     WHERE id = $1`,
    [purchaseOrderId, approvedBy],
  );

  const commitmentNumber = `AP-${po.po_number}`;
  const commitmentRows = await db.queryObject<{ id: string }>(
    `INSERT INTO finance_ap_commitments (
       organization_id, school_id, vendor_id, purchase_order_id,
       commitment_number, amount, status
     ) VALUES ($1, $2, $3, $4, $5, $6, 'open')
     RETURNING id`,
    [organizationId, schoolId, po.vendor_id, purchaseOrderId, commitmentNumber, po.total_amount],
  );
  const apCommitmentId = commitmentRows[0]!.id;

  const postingRows = await db.queryObject<{ id: string }>(
    `INSERT INTO inventory_finance_postings (
       organization_id, school_id, purchase_order_id, ap_commitment_id,
       posting_status, ledger_refs, posted_at
     ) VALUES ($1, $2, $3, $4, 'posted', $5::jsonb, timezone('utc', now()))
     RETURNING id`,
    [
      organizationId,
      schoolId,
      purchaseOrderId,
      apCommitmentId,
      JSON.stringify([{ type: "ap_commitment", id: apCommitmentId, amount: po.total_amount }]),
    ],
  );
  const financePostingId = postingRows[0]!.id;

  await db.queryObject(
    `INSERT INTO procurement_finance_links (
       organization_id, school_id, purchase_order_id, ap_commitment_id, finance_posting_id
     ) VALUES ($1, $2, $3, $4, $5)`,
    [organizationId, schoolId, purchaseOrderId, apCommitmentId, financePostingId],
  );

  const updated = await getPurchaseOrder(db, organizationId, schoolId, purchaseOrderId);
  return {
    purchaseOrder: updated!,
    apCommitmentId,
    financePostingId,
  };
}

/**
 * Rejects a draft purchase order (approval-center reject path). No finance
 * commitment/posting is created — the PO simply moves to `rejected`. Returns the
 * PO row, or null when absent; a no-op (returns the row) when it is not a draft.
 */
export async function rejectPurchaseOrder(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  purchaseOrderId: string,
): Promise<PurchaseOrderRow | null> {
  const po = await getPurchaseOrder(db, organizationId, schoolId, purchaseOrderId);
  if (!po) return null;
  if (po.status !== "draft") return po;
  await db.queryObject(
    `UPDATE purchase_orders
        SET status = 'rejected', updated_at = timezone('utc', now())
      WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [purchaseOrderId, organizationId, schoolId],
  );
  return await getPurchaseOrder(db, organizationId, schoolId, purchaseOrderId);
}

export async function receiveGoods(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  purchaseOrderId: string,
  receivedBy: string,
  lines: Array<{ purchaseOrderLineId: string; quantityReceived: number }>,
): Promise<{ grnId: string; grnNumber: string }> {
  const po = await getPurchaseOrder(db, organizationId, schoolId, purchaseOrderId);
  if (!po) throw new PurchaseOrderNotFoundError(purchaseOrderId);
  if (!["approved", "partially_received"].includes(po.status)) {
    throw new InvalidPurchaseOrderStateError(`Cannot receive goods for PO in status ${po.status}`);
  }
  if (!lines.length) throw new Error("GRN_LINES_REQUIRED");

  const grnNumber = `GRN-${po.po_number}-${Date.now().toString().slice(-6)}`;
  const grnRows = await db.queryObject<{ id: string }>(
    `INSERT INTO goods_receipts (
       organization_id, school_id, purchase_order_id, grn_number, received_by
     ) VALUES ($1, $2, $3, $4, $5)
     RETURNING id`,
    [organizationId, schoolId, purchaseOrderId, grnNumber, receivedBy],
  );
  const grnId = grnRows[0]!.id;

  for (const line of lines) {
    const poLineRows = await db.queryObject<{
      sku: string;
      quantity: number;
      quantity_received: number;
      unit_cost: number;
    }>(
      `SELECT sku, quantity, quantity_received, unit_cost
       FROM purchase_order_lines
       WHERE id = $1 AND purchase_order_id = $2`,
      [line.purchaseOrderLineId, purchaseOrderId],
    );
    const poLine = poLineRows[0];
    if (!poLine) throw new Error(`PO line not found: ${line.purchaseOrderLineId}`);
    if (poLine.quantity_received + line.quantityReceived > poLine.quantity) {
      throw new Error(`Over-receipt on SKU ${poLine.sku}`);
    }

    await db.queryObject(
      `INSERT INTO goods_receipt_lines (
         goods_receipt_id, purchase_order_line_id, organization_id, school_id, quantity_received
       ) VALUES ($1, $2, $3, $4, $5)`,
      [grnId, line.purchaseOrderLineId, organizationId, schoolId, line.quantityReceived],
    );

    await db.queryObject(
      `UPDATE purchase_order_lines
       SET quantity_received = quantity_received + $2
       WHERE id = $1`,
      [line.purchaseOrderLineId, line.quantityReceived],
    );

    await upsertStockValuation(
      db,
      organizationId,
      schoolId,
      poLine.sku,
      line.quantityReceived,
      poLine.unit_cost,
      receivedBy,
      grnId,
    );
  }

  const openLines = await db.queryCount(
    `SELECT count(*)::text AS count FROM purchase_order_lines
     WHERE purchase_order_id = $1 AND quantity_received < quantity`,
    [purchaseOrderId],
  );
  const newStatus = openLines === 0 ? "received" : "partially_received";
  await db.queryObject(
    `UPDATE purchase_orders SET status = $2, updated_at = timezone('utc', now()) WHERE id = $1`,
    [purchaseOrderId, newStatus],
  );

  return { grnId, grnNumber };
}

async function upsertStockValuation(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sku: string,
  qtyReceived: number,
  unitCost: number,
  receivedBy: string | null = null,
  grnId: string | null = null,
): Promise<void> {
  // Typed-table read-modify-write → hold the row lock across the GRN increment so
  // two concurrent receipts on the same SKU serialize (mirrors the stock module's
  // FOR UPDATE discipline; the JSONB mutateEntity lock does not cover this table).
  const existing = await db.queryObject<{
    quantity_on_hand: number;
    weighted_avg_cost: number;
  }>(
    `SELECT quantity_on_hand, weighted_avg_cost FROM inventory_stock_valuations
     WHERE organization_id = $1 AND school_id = $2 AND sku = $3
     FOR UPDATE`,
    [organizationId, schoolId, sku],
  );

  if (!existing[0]) {
    await db.queryObject(
      `INSERT INTO inventory_stock_valuations (
         organization_id, school_id, sku, quantity_on_hand, weighted_avg_cost
       ) VALUES ($1, $2, $3, $4, $5)`,
      [organizationId, schoolId, sku, qtyReceived, unitCost],
    );
    // GRN joins the immutable ledger: qty_before 0 → qty_after qtyReceived.
    await recordGrnMovement(db, organizationId, schoolId, {
      sku,
      qtyReceived,
      qtyBefore: 0,
      qtyAfter: qtyReceived,
      createdBy: receivedBy,
      referenceId: grnId,
    });
    return;
  }

  const oldQty = existing[0].quantity_on_hand;
  const oldCost = existing[0].weighted_avg_cost;
  const newQty = oldQty + qtyReceived;
  const newAvg = newQty > 0
    ? Math.round((oldQty * oldCost + qtyReceived * unitCost) / newQty)
    : unitCost;

  await db.queryObject(
    `UPDATE inventory_stock_valuations
     SET quantity_on_hand = $4, weighted_avg_cost = $5,
         last_valued_at = timezone('utc', now()), updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND school_id = $2 AND sku = $3`,
    [organizationId, schoolId, sku, newQty, newAvg],
  );

  await recordGrnMovement(db, organizationId, schoolId, {
    sku,
    qtyReceived,
    qtyBefore: oldQty,
    qtyAfter: newQty,
    createdBy: receivedBy,
    referenceId: grnId,
  });
}

export async function listStockValuations(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<Array<{
  sku: string;
  quantityOnHand: number;
  weightedAvgCost: number;
  inventoryValue: number;
}>> {
  const rows = await db.queryObject<{
    sku: string;
    quantity_on_hand: number;
    weighted_avg_cost: number;
  }>(
    `SELECT sku, quantity_on_hand, weighted_avg_cost
     FROM inventory_stock_valuations
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY sku ASC`,
    [organizationId, schoolId],
  );
  return rows.map((row) => ({
    sku: row.sku,
    quantityOnHand: row.quantity_on_hand,
    weightedAvgCost: row.weighted_avg_cost,
    inventoryValue: row.quantity_on_hand * row.weighted_avg_cost,
  }));
}

export async function listPurchaseOrders(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<PurchaseOrderRow[]> {
  return await db.queryObject<PurchaseOrderRow>(
    `SELECT id, po_number, vendor_id, status, total_amount, currency, created_at
     FROM purchase_orders
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY created_at DESC LIMIT 100`,
    [organizationId, schoolId],
  );
}

export interface PurchaseOrderLineRow {
  id: string;
  sku: string;
  description: string;
  quantity: number;
  unit_cost: number;
  line_total: number;
  quantity_received: number;
}

export async function getPurchaseOrderDetail(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  purchaseOrderId: string,
): Promise<{ purchaseOrder: PurchaseOrderRow; lines: PurchaseOrderLineRow[] } | null> {
  const po = await getPurchaseOrder(db, organizationId, schoolId, purchaseOrderId);
  if (!po) return null;
  const lines = await db.queryObject<PurchaseOrderLineRow>(
    `SELECT id, sku, description, quantity, unit_cost, line_total, quantity_received
     FROM purchase_order_lines
     WHERE purchase_order_id = $1 AND organization_id = $2 AND school_id = $3
     ORDER BY created_at ASC`,
    [purchaseOrderId, organizationId, schoolId],
  );
  return { purchaseOrder: po, lines };
}

export interface ReconciliationDashboardData {
  vendorCount: number;
  purchaseOrderCount: number;
  draftPurchaseOrders: number;
  openApCommitments: number;
  openApAmount: number;
  postedFinancePostings: number;
  goodsReceiptCount: number;
  inventoryValue: number;
}

export async function getReconciliationDashboard(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<ReconciliationDashboardData> {
  const rows = await db.queryObject<{
    vendor_count: number;
    purchase_order_count: number;
    draft_purchase_orders: number;
    open_ap_commitments: number;
    open_ap_amount: number;
    posted_finance_postings: number;
    goods_receipt_count: number;
    inventory_value: number;
  }>(
    `SELECT
       (SELECT count(*)::int FROM inventory_vendors WHERE organization_id = $1 AND school_id = $2) AS vendor_count,
       (SELECT count(*)::int FROM purchase_orders WHERE organization_id = $1 AND school_id = $2) AS purchase_order_count,
       (SELECT count(*)::int FROM purchase_orders WHERE organization_id = $1 AND school_id = $2 AND status = 'draft') AS draft_purchase_orders,
       (SELECT count(*)::int FROM finance_ap_commitments WHERE organization_id = $1 AND school_id = $2 AND status = 'open') AS open_ap_commitments,
       (SELECT coalesce(sum(amount), 0)::int FROM finance_ap_commitments WHERE organization_id = $1 AND school_id = $2 AND status = 'open') AS open_ap_amount,
       (SELECT count(*)::int FROM inventory_finance_postings WHERE organization_id = $1 AND school_id = $2 AND posting_status = 'posted') AS posted_finance_postings,
       (SELECT count(*)::int FROM goods_receipts WHERE organization_id = $1 AND school_id = $2) AS goods_receipt_count,
       (SELECT coalesce(sum(quantity_on_hand * weighted_avg_cost), 0)::int FROM inventory_stock_valuations WHERE organization_id = $1 AND school_id = $2) AS inventory_value`,
    [organizationId, schoolId],
  );
  const row = rows[0]!;
  return {
    vendorCount: row.vendor_count,
    purchaseOrderCount: row.purchase_order_count,
    draftPurchaseOrders: row.draft_purchase_orders,
    openApCommitments: row.open_ap_commitments,
    openApAmount: row.open_ap_amount,
    postedFinancePostings: row.posted_finance_postings,
    goodsReceiptCount: row.goods_receipt_count,
    inventoryValue: row.inventory_value,
  };
}

export interface InventoryFinanceTimelineEntry {
  id: string;
  eventType: string;
  entityType: string;
  entityId: string;
  label: string;
  amount: number | null;
  occurredAt: string;
  referenceId: string | null;
}

export async function listInventoryFinanceTimeline(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<InventoryFinanceTimelineEntry[]> {
  const rows = await db.queryObject<InventoryFinanceTimelineEntry>(
    `SELECT * FROM (
       SELECT po.id AS id,
              'purchase_order_created' AS event_type,
              'purchase_order' AS entity_type,
              po.id AS entity_id,
              po.po_number AS label,
              po.total_amount AS amount,
              po.created_at AS occurred_at,
              po.vendor_id AS reference_id
         FROM purchase_orders po
        WHERE po.organization_id = $1 AND po.school_id = $2
       UNION ALL
       SELECT po.id,
              'purchase_order_approved',
              'purchase_order',
              po.id,
              po.po_number,
              po.total_amount,
              po.approved_at,
              po.vendor_id
         FROM purchase_orders po
        WHERE po.organization_id = $1 AND po.school_id = $2
          AND po.approved_at IS NOT NULL
       UNION ALL
       SELECT gr.id,
              'goods_received',
              'goods_receipt',
              gr.id,
              gr.grn_number,
              po.total_amount,
              gr.received_at,
              gr.purchase_order_id
         FROM goods_receipts gr
         JOIN purchase_orders po ON po.id = gr.purchase_order_id
        WHERE gr.organization_id = $1 AND gr.school_id = $2
       UNION ALL
       SELECT ifp.id,
              'finance_posting',
              'inventory_finance_posting',
              ifp.id,
              po.po_number,
              po.total_amount,
              coalesce(ifp.posted_at, ifp.created_at),
              ifp.purchase_order_id
         FROM inventory_finance_postings ifp
         JOIN purchase_orders po ON po.id = ifp.purchase_order_id
        WHERE ifp.organization_id = $1 AND ifp.school_id = $2
     ) timeline
     ORDER BY occurred_at DESC
     LIMIT 200`,
    [organizationId, schoolId],
  );
  return rows;
}

export interface GoodsReceiptSummaryRow {
  id: string;
  grn_number: string;
  purchase_order_id: string;
  po_number: string;
  vendor_name: string;
  received_at: string;
  status: string;
  line_count: number;
}

export async function listGoodsReceipts(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<GoodsReceiptSummaryRow[]> {
  return await db.queryObject<GoodsReceiptSummaryRow>(
    `SELECT gr.id,
            gr.grn_number,
            gr.purchase_order_id,
            po.po_number,
            v.display_name AS vendor_name,
            gr.received_at,
            gr.status,
            (SELECT count(*)::int FROM goods_receipt_lines grl WHERE grl.goods_receipt_id = gr.id) AS line_count
       FROM goods_receipts gr
       JOIN purchase_orders po ON po.id = gr.purchase_order_id
       JOIN inventory_vendors v ON v.id = po.vendor_id
      WHERE gr.organization_id = $1 AND gr.school_id = $2
      ORDER BY gr.received_at DESC
      LIMIT 100`,
    [organizationId, schoolId],
  );
}

export interface GoodsReceiptLineDetailRow {
  id: string;
  sku: string;
  description: string;
  quantity_received: number;
  unit_cost: number;
}

export async function getGoodsReceiptDetail(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  goodsReceiptId: string,
): Promise<{
  id: string;
  grnNumber: string;
  purchaseOrderId: string;
  poNumber: string;
  vendorName: string;
  receivedAt: string;
  status: string;
  lines: GoodsReceiptLineDetailRow[];
} | null> {
  const headerRows = await db.queryObject<{
    id: string;
    grn_number: string;
    purchase_order_id: string;
    po_number: string;
    vendor_name: string;
    received_at: string;
    status: string;
  }>(
    `SELECT gr.id, gr.grn_number, gr.purchase_order_id, po.po_number, v.display_name AS vendor_name,
            gr.received_at, gr.status
       FROM goods_receipts gr
       JOIN purchase_orders po ON po.id = gr.purchase_order_id
       JOIN inventory_vendors v ON v.id = po.vendor_id
      WHERE gr.id = $1 AND gr.organization_id = $2 AND gr.school_id = $3`,
    [goodsReceiptId, organizationId, schoolId],
  );
  const header = headerRows[0];
  if (!header) return null;

  const lines = await db.queryObject<GoodsReceiptLineDetailRow>(
    `SELECT grl.id, pol.sku, pol.description, grl.quantity_received, pol.unit_cost
       FROM goods_receipt_lines grl
       JOIN purchase_order_lines pol ON pol.id = grl.purchase_order_line_id
      WHERE grl.goods_receipt_id = $1
      ORDER BY grl.created_at ASC`,
    [goodsReceiptId],
  );

  return {
    id: header.id,
    grnNumber: header.grn_number,
    purchaseOrderId: header.purchase_order_id,
    poNumber: header.po_number,
    vendorName: header.vendor_name,
    receivedAt: header.received_at,
    status: header.status,
    lines,
  };
}

export interface InventoryFinancePostingRow {
  id: string;
  purchase_order_id: string;
  po_number: string;
  vendor_name: string;
  ap_commitment_id: string;
  commitment_number: string;
  posting_status: string;
  amount: number;
  posted_at: string | null;
}

export async function listInventoryFinancePostings(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<InventoryFinancePostingRow[]> {
  return await db.queryObject<InventoryFinancePostingRow>(
    `SELECT ifp.id,
            ifp.purchase_order_id,
            po.po_number,
            v.display_name AS vendor_name,
            ifp.ap_commitment_id,
            fac.commitment_number,
            ifp.posting_status,
            fac.amount,
            ifp.posted_at
       FROM inventory_finance_postings ifp
       JOIN purchase_orders po ON po.id = ifp.purchase_order_id
       JOIN inventory_vendors v ON v.id = po.vendor_id
       JOIN finance_ap_commitments fac ON fac.id = ifp.ap_commitment_id
      WHERE ifp.organization_id = $1 AND ifp.school_id = $2
      ORDER BY coalesce(ifp.posted_at, ifp.created_at) DESC
      LIMIT 100`,
    [organizationId, schoolId],
  );
}

export interface VendorTransactionRow {
  id: string;
  transactionType: string;
  referenceNumber: string;
  amount: number;
  status: string;
  occurredAt: string;
}

export async function listVendorTransactions(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  vendorId: string,
): Promise<VendorTransactionRow[]> {
  const vendorRows = await db.queryObject<{ id: string }>(
    `SELECT id FROM inventory_vendors
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [vendorId, organizationId, schoolId],
  );
  if (!vendorRows[0]) return [];

  const rows = await db.queryObject<{
    id: string;
    transaction_type: string;
    reference_number: string;
    amount: number;
    status: string;
    occurred_at: string;
  }>(
    `SELECT * FROM (
       SELECT po.id,
              'purchase_order' AS transaction_type,
              po.po_number AS reference_number,
              po.total_amount AS amount,
              po.status,
              po.created_at AS occurred_at
         FROM purchase_orders po
        WHERE po.vendor_id = $1 AND po.organization_id = $2 AND po.school_id = $3
       UNION ALL
       SELECT fac.id,
              'ap_commitment',
              fac.commitment_number,
              fac.amount,
              fac.status,
              fac.created_at
         FROM finance_ap_commitments fac
        WHERE fac.vendor_id = $1 AND fac.organization_id = $2 AND fac.school_id = $3
     ) vendor_tx
     ORDER BY occurred_at DESC
     LIMIT 100`,
    [vendorId, organizationId, schoolId],
  );

  return rows.map((row) => ({
    id: row.id,
    transactionType: row.transaction_type,
    referenceNumber: row.reference_number,
    amount: row.amount,
    status: row.status,
    occurredAt: row.occurred_at,
  }));
}
