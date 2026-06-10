import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import {
  getGoodsReceiptDetail,
  getReconciliationDashboard,
  listGoodsReceipts,
  listInventoryFinancePostings,
  listInventoryFinanceTimeline,
  listVendorTransactions,
} from "./inventory_finance_repository.ts";

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
    requireSchoolOperationalScope(claims);
}

export async function handleReconciliationDashboard(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  try {
    const dashboard = await withTenantContext(config, auth.claims, async (db) =>
      await getReconciliationDashboard(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
      )
    );
    return jsonResponse(envelope(dashboard));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load reconciliation dashboard", 500);
  }
}

export async function handleInventoryFinanceTimeline(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listInventoryFinanceTimeline(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
      )
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load inventory finance timeline", 500);
  }
}

export async function handleListGoodsReceipts(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  try {
    const receipts = await withTenantContext(config, auth.claims, async (db) =>
      await listGoodsReceipts(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
      )
    );
    return jsonResponse(envelope({
      items: receipts.map((row) => ({
        id: row.id,
        grnNumber: row.grn_number,
        purchaseOrderId: row.purchase_order_id,
        poNumber: row.po_number,
        vendorName: row.vendor_name,
        receivedAt: row.received_at,
        status: row.status,
        lineCount: row.line_count,
      })),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list goods receipts", 500);
  }
}

export async function handleGetGoodsReceipt(
  req: Request,
  config: AppConfig,
  goodsReceiptId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  try {
    const detail = await withTenantContext(config, auth.claims, async (db) =>
      await getGoodsReceiptDetail(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        goodsReceiptId,
      )
    );
    if (!detail) {
      return errorEnvelope("NOT_FOUND", "Goods receipt not found", 404);
    }
    return jsonResponse(envelope({
      ...detail,
      lines: detail.lines.map((line) => ({
        id: line.id,
        sku: line.sku,
        description: line.description,
        quantityReceived: line.quantity_received,
        unitCost: line.unit_cost,
      })),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load goods receipt", 500);
  }
}

export async function handleListInventoryFinancePostings(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  try {
    const postings = await withTenantContext(config, auth.claims, async (db) =>
      await listInventoryFinancePostings(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
      )
    );
    return jsonResponse(envelope({
      items: postings.map((row) => ({
        id: row.id,
        purchaseOrderId: row.purchase_order_id,
        poNumber: row.po_number,
        vendorName: row.vendor_name,
        apCommitmentId: row.ap_commitment_id,
        commitmentNumber: row.commitment_number,
        postingStatus: row.posting_status,
        amount: row.amount,
        postedAt: row.posted_at,
      })),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list inventory finance postings", 500);
  }
}

export async function handleVendorTransactions(
  req: Request,
  config: AppConfig,
  vendorId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  try {
    const transactions = await withTenantContext(config, auth.claims, async (db) =>
      await listVendorTransactions(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        vendorId,
      )
    );
    return jsonResponse(envelope({ items: transactions }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load vendor transactions", 500);
  }
}
