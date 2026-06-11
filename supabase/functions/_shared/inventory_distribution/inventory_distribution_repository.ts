import type { TenantQueryClient } from "../tenant_db.ts";
import { upsertPaymentRequest } from "../payment/payment_repository.ts";

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
  },
): Promise<DistributionRow> {
  const rows = await client.queryObject<DistributionRow>(
    `INSERT INTO inv_student_distributions (
       organization_id, school_id, student_id, catalog_item_id,
       quantity, status, created_by
     ) VALUES ($1, $2, $3, $4, $5, 'available', $6)
     RETURNING *`,
    [
      organizationId,
      schoolId,
      input.studentId,
      input.catalogItemId,
      input.quantity,
      input.createdBy,
    ],
  );
  await client.queryObject(
    `UPDATE inv_catalog_items
     SET stock_on_hand = greatest(0, stock_on_hand - $1)
     WHERE id = $2`,
    [input.quantity, input.catalogItemId],
  );
  return rows[0]!;
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
     SET status = $1, payment_request_id = $2, notes = coalesce($3, notes)
     WHERE id = $4
     RETURNING *`,
    [
      paymentRequestId ? "payment_pending" : "replacement_requested",
      paymentRequestId,
      notes ?? null,
      distributionId,
    ],
  );

  return { distribution: updated[0]!, paymentRequestId };
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
