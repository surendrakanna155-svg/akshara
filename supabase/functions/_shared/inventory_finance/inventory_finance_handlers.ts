import type { AppConfig } from "../config.ts";
import { recordMutationAudit } from "../audit/audit_repository.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
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
  approvePurchaseOrder,
  createPurchaseOrder,
  createVendor,
  getPurchaseOrderDetail,
  InvalidPurchaseOrderStateError,
  listGoodsReceipts,
  listPurchaseOrders,
  listStockLevels,
  listStockValuations,
  listVendors,
  PurchaseOrderNotFoundError,
  PurchaseOrderSelfApproveDeniedError,
  receiveGoods,
} from "./inventory_finance_repository.ts";
// W4: project an approved purchase order into the canonical Expense Ledger
// (category 'procurement') ADDITIVELY alongside the existing AP-commitment / finance
// posting sink. Idempotent (per PO id) and savepoint-fenced, so a failed projection
// can never roll back the approval.
import { wireInventoryPurchaseToLedger } from "../expense_ledger/expense_ledger_wiring.ts";

function requireInventoryWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageInventory") ??
    requireSchoolOperationalScope(claims);
}

function requireInventoryRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewInventory") ??
    requireSchoolOperationalScope(claims);
}

function vendorToApi(row: Awaited<ReturnType<typeof listVendors>>[number]) {
  return {
    id: row.id,
    vendorCode: row.vendor_code,
    displayName: row.display_name,
    contactPhone: row.contact_phone,
    contactEmail: row.contact_email,
    gstin: row.gstin,
    status: row.status,
  };
}

function poToApi(row: Awaited<ReturnType<typeof listPurchaseOrders>>[number]) {
  return {
    id: row.id,
    poNumber: row.po_number,
    vendorId: row.vendor_id,
    status: row.status,
    totalAmount: row.total_amount,
    currency: row.currency,
    createdAt: row.created_at,
  };
}

export async function handleGetPurchaseOrder(
  req: Request,
  config: AppConfig,
  purchaseOrderId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryRead(auth.claims);
  if (denied) return denied;

  try {
    const detail = await withTenantContext(config, auth.claims, async (db) =>
      await getPurchaseOrderDetail(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        purchaseOrderId,
      )
    );
    if (!detail) {
      return errorEnvelope("NOT_FOUND", "Purchase order not found", 404);
    }
    return jsonResponse(envelope({
      purchaseOrder: poToApi(detail.purchaseOrder),
      lines: detail.lines.map((line) => ({
        id: line.id,
        sku: line.sku,
        description: line.description,
        quantity: line.quantity,
        unitCost: line.unit_cost,
        lineTotal: line.line_total,
        quantityReceived: line.quantity_received,
      })),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load purchase order", 500);
  }
}

export async function handleListDbVendors(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryRead(auth.claims);
  if (denied) return denied;

  try {
    const vendors = await withTenantContext(config, auth.claims, async (db) =>
      await listVendors(db, organizationIdFromClaims(auth.claims), schoolIdFromClaims(auth.claims)!)
    );
    return jsonResponse(envelope({ items: vendors.map(vendorToApi) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list vendors", 500);
  }
}

export async function handleCreateVendor(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }
  const vendorCode = String(body.vendorCode ?? body.vendor_code ?? "").trim();
  const displayName = String(body.displayName ?? body.display_name ?? "").trim();
  if (!vendorCode || !displayName) {
    return errorEnvelope("VALIDATION_ERROR", "vendorCode and displayName required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const vendor = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createVendor(db, orgId, schoolId, {
        vendorCode,
        displayName,
        contactPhone: String(body.contactPhone ?? body.contact_phone ?? "") || undefined,
        contactEmail: String(body.contactEmail ?? body.contact_email ?? "") || undefined,
        gstin: String(body.gstin ?? "") || undefined,
      });
      await recordMutationAudit(db, auth.claims, {
        eventType: "vendorCreated",
        category: "workflow",
        entityType: "inventory_vendor",
        entityId: created.id,
        metadata: { vendorCode },
      }, {
        eventType: "inventory.vendor.created",
        sourceModule: "inventory",
        payload: { vendorId: created.id, vendorCode },
        idempotencyKey: `inventory.vendor:${created.id}`,
      }, req);
      return created;
    });
    return jsonResponse(envelope(vendorToApi(vendor)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to create vendor", 500);
  }
}

export async function handleListDbPurchaseOrders(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryRead(auth.claims);
  if (denied) return denied;

  try {
    const orders = await withTenantContext(config, auth.claims, async (db) =>
      await listPurchaseOrders(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
      )
    );
    return jsonResponse(envelope({ items: orders.map(poToApi) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list purchase orders", 500);
  }
}

export async function handleCreatePurchaseOrder(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    vendorId?: string;
    poNumber?: string;
    notes?: string;
    lines?: Array<Record<string, unknown>>;
  }>(req);
  if (!body?.vendorId || !body?.poNumber || !body?.lines?.length) {
    return errorEnvelope("VALIDATION_ERROR", "vendorId, poNumber, lines required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const po = await withTenantContext(config, auth.claims, async (db) => {
      const created = await createPurchaseOrder(db, orgId, schoolId, auth.claims.sub, {
        vendorId: body.vendorId!,
        poNumber: body.poNumber!,
        notes: body.notes,
        lines: body.lines!.map((line) => ({
          sku: String(line.sku ?? ""),
          description: String(line.description ?? ""),
          quantity: Number(line.quantity ?? 0),
          unitCost: Number(line.unitCost ?? line.unit_cost ?? 0),
        })),
      });
      await recordMutationAudit(db, auth.claims, {
        eventType: "purchaseOrderCreated",
        category: "workflow",
        entityType: "purchase_order",
        entityId: created.id,
        metadata: { poNumber: created.po_number },
      }, {
        eventType: "inventory.procurement.created",
        sourceModule: "inventory",
        payload: { purchaseOrderId: created.id },
        idempotencyKey: `inventory.po:${created.id}`,
      }, req);
      return created;
    });
    return jsonResponse(envelope(poToApi(po)), { status: 201 });
  } catch (error) {
    if (error instanceof Error && error.message === "PO_LINES_REQUIRED") {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to create purchase order", 500);
  }
}

export async function handleApprovePurchaseOrder(
  req: Request,
  config: AppConfig,
  purchaseOrderId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryWrite(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const approved = await approvePurchaseOrder(
        db,
        orgId,
        schoolId,
        purchaseOrderId,
        auth.claims.sub,
      );
      await recordMutationAudit(db, auth.claims, {
        eventType: "procurementFinancePosted",
        category: "workflow",
        entityType: "purchase_order",
        entityId: purchaseOrderId,
        metadata: {
          apCommitmentId: approved.apCommitmentId,
          financePostingId: approved.financePostingId,
        },
      }, {
        eventType: "procurement.approved",
        sourceModule: "inventory",
        payload: {
          purchaseOrderId,
          apCommitmentId: approved.apCommitmentId,
          amount: approved.purchaseOrder.total_amount,
        },
        idempotencyKey: `procurement.approved:${purchaseOrderId}`,
      }, req);
      // W4: additively project the approved PO's committed cost into the canonical
      // Expense Ledger (a reporting projection separate from the AP-commitment sink
      // above — no double count). Same tenant transaction, savepoint-fenced, so a
      // projection failure rolls back only itself, never the approval.
      await wireInventoryPurchaseToLedger(db, orgId, schoolId, approved.purchaseOrder);
      return approved;
    });
    return jsonResponse(envelope({
      purchaseOrder: poToApi(result.purchaseOrder),
      apCommitmentId: result.apCommitmentId,
      financePostingId: result.financePostingId,
    }));
  } catch (error) {
    if (error instanceof PurchaseOrderNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof InvalidPurchaseOrderStateError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    if (error instanceof PurchaseOrderSelfApproveDeniedError) {
      return errorEnvelope("SELF_APPROVE_DENIED", error.message, 409);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to approve purchase order", 500);
  }
}

export async function handleReceiveGoods(
  req: Request,
  config: AppConfig,
  purchaseOrderId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ lines?: Array<Record<string, unknown>> }>(req);
  if (!body?.lines?.length) {
    return errorEnvelope("VALIDATION_ERROR", "lines required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const grn = await withTenantContext(config, auth.claims, async (db) => {
      const received = await receiveGoods(
        db,
        orgId,
        schoolId,
        purchaseOrderId,
        auth.claims.sub,
        body.lines!.map((line) => ({
          purchaseOrderLineId: String(line.purchaseOrderLineId ?? line.purchase_order_line_id ?? ""),
          quantityReceived: Number(line.quantityReceived ?? line.quantity_received ?? 0),
        })),
      );
      await recordMutationAudit(db, auth.claims, {
        eventType: "goodsReceived",
        category: "workflow",
        entityType: "goods_receipt",
        entityId: received.grnId,
        metadata: { purchaseOrderId, grnNumber: received.grnNumber },
      }, {
        eventType: "procurement.received",
        sourceModule: "inventory",
        payload: { purchaseOrderId, grnId: received.grnId },
        idempotencyKey: `procurement.received:${received.grnId}`,
      }, req);
      return received;
    });
    return jsonResponse(envelope(grn));
  } catch (error) {
    if (error instanceof PurchaseOrderNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof InvalidPurchaseOrderStateError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to receive goods", 500);
  }
}

/**
 * INV-5 — GET /inventory/procurement/grns: the goods-received (GRN) register for
 * the caller's school. Same rows as the finance reconciliation surface
 * ({@link listGoodsReceipts}: vendor + PO reference + line summary) but gated on
 * viewInventory so store staff can list/export GRNs without a finance grant.
 */
export async function handleListGrns(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryRead(auth.claims);
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

export async function handleStockValuation(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryRead(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listStockValuations(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
      )
    );
    const totalValue = items.reduce((sum, item) => sum + item.inventoryValue, 0);
    return jsonResponse(envelope({ items, totalValue }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load stock valuation", 500);
  }
}

/**
 * WEB-004 (ERP-WT-004) — GET /inventory/stock. The web Stock page's primary
 * ledger: per-item on-hand + reorder level + valuation, with the below-reorder
 * flag pre-computed. Optional ?itemType=asset|consumable. Read gate (viewInventory).
 */
export async function handleStockLevels(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const itemType = url.searchParams.get("itemType") ?? undefined;
  if (itemType && itemType !== "asset" && itemType !== "consumable") {
    return errorEnvelope("VALIDATION_ERROR", "itemType must be asset|consumable", 422);
  }

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listStockLevels(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        { itemType: itemType || undefined },
      )
    );
    const totalValue = items.reduce((sum, item) => sum + item.inventoryValue, 0);
    const belowReorderCount = items.filter((item) => item.belowReorder).length;
    return jsonResponse(
      envelope({ items, totalValue, belowReorderCount, count: items.length }),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load stock", 500);
  }
}
