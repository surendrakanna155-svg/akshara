// INV-1..7 — Store stock module HTTP handlers.
//
// Writes gate manageInventory + school scope; reads gate viewInventory.
// recordMutationAudit fires on every write. Value-reducing movements go through
// the maker-checker endpoints (approve/reject); the repo enforces the FOR-UPDATE
// lock, the negative-stock 422 block, and the checker <> maker (409) SoD rule.

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
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { scheduleReminder } from "../reminders/reminders_service.ts";
import {
  adjustStock,
  approveStockAdjustment,
  InsufficientStockError,
  issueStock,
  listLowStock,
  listPendingAdjustments,
  listStockAdjustments,
  listStockItems,
  listStockRegister,
  recordStockCount,
  rejectStockAdjustment,
  StockAdjustmentInvalidStateError,
  StockAdjustmentNotFoundError,
  StockSelfApproveDeniedError,
  StockValidationError,
  upsertStockItem,
} from "./inventory_stock_repository.ts";

function requireInventoryWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageInventory") ??
    requireSchoolOperationalScope(claims);
}

function requireInventoryRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewInventory") ??
    requireSchoolOperationalScope(claims);
}

/** Maps repository errors to their HTTP envelope. Returns null for unrecognised errors. */
function mapStockError(error: unknown): Response | null {
  if (error instanceof StockValidationError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  if (error instanceof InsufficientStockError) {
    return errorEnvelope("INSUFFICIENT_STOCK", error.message, 422);
  }
  if (error instanceof StockAdjustmentNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof StockAdjustmentInvalidStateError) {
    return errorEnvelope("INVALID_STATE", error.message, 409);
  }
  if (error instanceof StockSelfApproveDeniedError) {
    return errorEnvelope("SELF_APPROVE_DENIED", error.message, 409);
  }
  if (error instanceof TenantDbNotConfiguredError) {
    return tenantDbNotConfiguredResponse(error);
  }
  return null;
}

// ── INV-7: low-stock alert on the shared XCT-2 reminder rail ──

/** Fixed title of the low-stock reminder; also the idempotency discriminator. */
export const LOW_STOCK_REMINDER_TITLE = "Inventory — low stock alert";

/**
 * INV-7 — schedule ONE in-app low-stock reminder for the school's storekeepers
 * on the shared XCT-2 rail (fires via the scheduled-broadcast runner; the
 * `storekeepers` audience resolves at dispatch time and falls back to all staff
 * when no storekeeper membership exists).
 *
 * Idempotent: skips scheduling when a low-stock reminder is already pending
 * (`status='scheduled'`, same audience+title, this org/school) so repeated
 * issues don't pile up duplicate alerts before the runner fires.
 *
 * NEVER fails the stock issue: the whole thing runs inside a SAVEPOINT and any
 * error rolls back only the reminder work (the posted issue + its movements
 * commit untouched). Returns whether a reminder was scheduled.
 */
export async function scheduleLowStockReminderIfNeeded(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: { issueId: string; lowStockCount: number },
  req?: Request,
): Promise<{ scheduled: boolean }> {
  if (input.lowStockCount <= 0) return { scheduled: false };
  await db.queryObject("SAVEPOINT inv7_low_stock_reminder");
  try {
    const orgId = organizationIdFromClaims(claims);
    const schoolId = schoolIdFromClaims(claims);
    const pending = await db.queryObject<{ id: string }>(
      `SELECT id FROM comm_broadcasts
        WHERE organization_id = $1
          AND school_id = $2
          AND audience = 'storekeepers'
          AND status = 'scheduled'
          AND title = $3
        LIMIT 1`,
      [orgId, schoolId, LOW_STOCK_REMINDER_TITLE],
    );
    if (pending.length > 0) {
      await db.queryObject("RELEASE SAVEPOINT inv7_low_stock_reminder");
      return { scheduled: false };
    }
    await scheduleReminder(db, claims, {
      audience: "storekeepers",
      title: LOW_STOCK_REMINDER_TITLE,
      body:
        `${input.lowStockCount} item(s) are at or below their reorder level. Review the low-stock list and raise purchase orders.`,
      // Fire on the next scheduled-broadcast runner pass (i.e. promptly).
      remindAt: new Date().toISOString(),
    }, req);
    await recordMutationAudit(db, claims, {
      eventType: "lowStockAlerted",
      category: "workflow",
      entityType: "stock_low_stock_alert",
      entityId: input.issueId,
      metadata: { count: input.lowStockCount },
    }, {
      eventType: "inventory.low_stock.alerted",
      sourceModule: "inventory",
      payload: { count: input.lowStockCount, trigger: "issue", issueId: input.issueId },
      idempotencyKey: `inventory.low_stock.alerted:${input.issueId}`,
    }, req);
    await db.queryObject("RELEASE SAVEPOINT inv7_low_stock_reminder");
    return { scheduled: true };
  } catch (error) {
    // Alerting is best-effort — roll back ONLY the reminder work and keep the
    // issue transaction healthy. The issue itself must never fail here.
    await db.queryObject("ROLLBACK TO SAVEPOINT inv7_low_stock_reminder");
    console.error("INV-7 low-stock reminder scheduling failed", error);
    return { scheduled: false };
  }
}

// ── INV-1: POST /inventory/stock/issue ──

export async function handleIssueStock(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    issueNumber?: string;
    issuedTo?: string;
    reason?: string;
    lines?: Array<Record<string, unknown>>;
  }>(req);
  if (!body?.issueNumber || !body?.lines?.length) {
    return errorEnvelope("VALIDATION_ERROR", "issueNumber and lines required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const { result, lowStock } = await withTenantContext(config, auth.claims, async (db) => {
      const issued = await issueStock(db, orgId, schoolId, auth.claims.sub, {
        issueNumber: String(body.issueNumber),
        issuedTo: body.issuedTo ? String(body.issuedTo) : undefined,
        reason: body.reason ? String(body.reason) : undefined,
        lines: body.lines!.map((l) => ({
          sku: String(l.sku ?? ""),
          quantity: Number(l.quantity ?? l.qty ?? 0),
        })),
      });
      await recordMutationAudit(db, auth.claims, {
        eventType: "stockIssued",
        category: "workflow",
        entityType: "stock_issue",
        entityId: issued.issueId,
        metadata: { issueNumber: issued.issueNumber, lineCount: body.lines!.length },
      }, {
        eventType: "inventory.stock.issued",
        sourceModule: "inventory",
        payload: { issueId: issued.issueId, issueNumber: issued.issueNumber },
        idempotencyKey: `inventory.stock.issued:${issued.issueId}`,
      }, req);

      // INV-7: after an issue, remind the storekeepers about any SKU now below
      // reorder — via the shared XCT-2 rail (scheduleReminder), never a direct
      // broadcast. Best-effort + idempotent; can never fail the posted issue.
      const low = issued.posted ? await listLowStock(db, orgId, schoolId) : [];
      if (low.length > 0) {
        await scheduleLowStockReminderIfNeeded(db, auth.claims, {
          issueId: issued.issueId,
          lowStockCount: low.length,
        }, req);
      }
      return { result: issued, lowStock: low };
    });
    return jsonResponse(
      envelope({
        issueId: result.issueId,
        issueNumber: result.issueNumber,
        posted: result.posted,
        movementIds: result.movementIds,
        lowStockCount: lowStock.length,
      }),
      { status: 201 },
    );
  } catch (error) {
    const mapped = mapStockError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to issue stock", 500);
  }
}

// ── INV-3: POST /inventory/stock/adjust ──

export async function handleAdjustStock(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    sku?: string;
    quantity?: number;
    movementType?: string;
    reason?: string;
    unitCost?: number;
  }>(req);
  const movementType = String(body?.movementType ?? "").trim();
  if (!body?.sku || !movementType || !body?.reason) {
    return errorEnvelope("VALIDATION_ERROR", "sku, movementType and reason required", 422);
  }
  if (!["adjust_in", "adjust_out", "opening"].includes(movementType)) {
    return errorEnvelope("VALIDATION_ERROR", `Unsupported movementType: ${movementType}`, 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const adjusted = await adjustStock(db, orgId, schoolId, auth.claims.sub, {
        sku: String(body.sku),
        quantity: Number(body.quantity ?? 0),
        movementType: movementType as "adjust_in" | "adjust_out" | "opening",
        reason: String(body.reason),
        unitCost: body.unitCost !== undefined ? Number(body.unitCost) : undefined,
      });
      await recordMutationAudit(db, auth.claims, {
        eventType: adjusted.applied ? "stockAdjusted" : "stockAdjustmentRequested",
        category: "workflow",
        entityType: adjusted.applied ? "stock_movement" : "stock_adjustment",
        entityId: adjusted.applied ? (adjusted.movementId ?? "") : (adjusted.adjustmentId ?? ""),
        metadata: { sku: String(body.sku), movementType, status: adjusted.status },
      }, {
        eventType: adjusted.applied ? "inventory.stock.adjusted" : "inventory.stock.adjustment_requested",
        sourceModule: "inventory",
        payload: { sku: String(body.sku), movementType, status: adjusted.status },
        idempotencyKey: `inventory.stock.adjust:${adjusted.movementId ?? adjusted.adjustmentId}`,
      }, req);
      return adjusted;
    });
    return jsonResponse(envelope(result), { status: 201 });
  } catch (error) {
    const mapped = mapStockError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to adjust stock", 500);
  }
}

// ── Maker-checker: POST /inventory/stock/adjustments/:id/approve|reject ──

export async function handleApproveStockAdjustment(
  req: Request,
  config: AppConfig,
  adjustmentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ comment?: string }>(req) ?? {};
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const decided = await approveStockAdjustment(
        db,
        orgId,
        schoolId,
        auth.claims.sub,
        adjustmentId,
        body.comment ?? null,
      );
      await recordMutationAudit(db, auth.claims, {
        eventType: "stockAdjustmentApproved",
        category: "workflow",
        entityType: "stock_adjustment",
        entityId: adjustmentId,
        metadata: { sku: decided.sku, movementId: decided.movementId },
      }, {
        eventType: "inventory.stock.adjustment_approved",
        sourceModule: "inventory",
        payload: { adjustmentId, sku: decided.sku, qtyAfter: decided.qtyAfter },
        idempotencyKey: `inventory.stock.adjustment_approved:${adjustmentId}`,
      }, req);
      return decided;
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    const mapped = mapStockError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to approve stock adjustment", 500);
  }
}

export async function handleRejectStockAdjustment(
  req: Request,
  config: AppConfig,
  adjustmentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ comment?: string }>(req) ?? {};
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const decided = await rejectStockAdjustment(
        db,
        orgId,
        schoolId,
        auth.claims.sub,
        adjustmentId,
        body.comment ?? null,
      );
      await recordMutationAudit(db, auth.claims, {
        eventType: "stockAdjustmentRejected",
        category: "workflow",
        entityType: "stock_adjustment",
        entityId: adjustmentId,
        metadata: { sku: decided.sku },
      }, {
        eventType: "inventory.stock.adjustment_rejected",
        sourceModule: "inventory",
        payload: { adjustmentId, sku: decided.sku },
        idempotencyKey: `inventory.stock.adjustment_rejected:${adjustmentId}`,
      }, req);
      return decided;
    });
    return jsonResponse(envelope(result));
  } catch (error) {
    const mapped = mapStockError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to reject stock adjustment", 500);
  }
}

// ── GET /inventory/stock/adjustments (pending list) ──

export async function handleListPendingAdjustments(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryRead(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listPendingAdjustments(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
      )
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    const mapped = mapStockError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to list pending adjustments", 500);
  }
}

/**
 * WEB-004 (ERP-WT-004) — GET /inventory/stock/approvals. The full maker-checker
 * value-reducing stock register (pending + decided, newest first), for the web
 * Stock-Approvals page. Optional ?status=pending|approved|rejected. Read gate.
 */
export async function handleStockApprovals(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const status = url.searchParams.get("status") ?? undefined;
  if (status && !["pending", "approved", "rejected"].includes(status)) {
    return errorEnvelope("VALIDATION_ERROR", "status must be pending|approved|rejected", 422);
  }

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listStockAdjustments(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        { status: status || undefined },
      )
    );
    return jsonResponse(envelope({ items, count: items.length }));
  } catch (error) {
    const mapped = mapStockError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to list stock approvals", 500);
  }
}

// ── INV-6: POST /inventory/stock/count ──

export async function handleRecordStockCount(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    sessionNumber?: string;
    notes?: string;
    lines?: Array<Record<string, unknown>>;
  }>(req);
  if (!body?.sessionNumber || !body?.lines?.length) {
    return errorEnvelope("VALIDATION_ERROR", "sessionNumber and lines required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const counted = await recordStockCount(db, orgId, schoolId, auth.claims.sub, {
        sessionNumber: String(body.sessionNumber),
        notes: body.notes ? String(body.notes) : undefined,
        lines: body.lines!.map((l) => ({
          sku: String(l.sku ?? ""),
          countedQty: Number(l.countedQty ?? l.counted_qty ?? 0),
        })),
      });
      await recordMutationAudit(db, auth.claims, {
        eventType: "stockCountPosted",
        category: "workflow",
        entityType: "stock_count_session",
        entityId: counted.sessionId,
        metadata: {
          sessionNumber: counted.sessionNumber,
          pendingAdjustments: counted.lines.filter((l) => l.outcome === "pending_adjustment").length,
        },
      }, {
        eventType: "inventory.stock.count_posted",
        sourceModule: "inventory",
        payload: { sessionId: counted.sessionId, sessionNumber: counted.sessionNumber },
        idempotencyKey: `inventory.stock.count_posted:${counted.sessionId}`,
      }, req);
      return counted;
    });
    return jsonResponse(envelope(result), { status: 201 });
  } catch (error) {
    const mapped = mapStockError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to record stock count", 500);
  }
}

// ── INV-2: GET/POST/PUT /inventory/stock/items ──

export async function handleListStockItems(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryRead(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listStockItems(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
      )
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    const mapped = mapStockError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to list stock items", 500);
  }
}

export async function handleUpsertStockItem(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{
    sku?: string;
    itemName?: string;
    itemType?: string;
    reorderLevel?: number;
    unitCost?: number;
  }>(req);
  if (!body?.sku) {
    return errorEnvelope("VALIDATION_ERROR", "sku required", 422);
  }
  const itemType = body.itemType === "asset" ? "asset" : "consumable";

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;

  try {
    const item = await withTenantContext(config, auth.claims, async (db) => {
      const saved = await upsertStockItem(db, orgId, schoolId, {
        sku: String(body.sku),
        itemName: body.itemName ? String(body.itemName) : null,
        itemType,
        reorderLevel: body.reorderLevel !== undefined ? Number(body.reorderLevel) : undefined,
        unitCost: body.unitCost !== undefined ? Number(body.unitCost) : undefined,
      });
      await recordMutationAudit(db, auth.claims, {
        eventType: "stockItemUpserted",
        category: "workflow",
        entityType: "inventory_stock_item",
        entityId: saved.sku,
        metadata: { itemType: saved.item_type, reorderLevel: saved.reorder_level },
      }, {
        eventType: "inventory.stock.item_upserted",
        sourceModule: "inventory",
        payload: { sku: saved.sku, reorderLevel: saved.reorder_level },
        idempotencyKey: `inventory.stock.item_upserted:${saved.sku}:${Date.now()}`,
      }, req);
      return saved;
    });
    return jsonResponse(envelope(item), { status: 201 });
  } catch (error) {
    const mapped = mapStockError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to save stock item", 500);
  }
}

// ── INV-5: GET /inventory/stock/register ──

export async function handleStockRegister(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryRead(auth.claims);
  if (denied) return denied;

  const sku = new URL(req.url).searchParams.get("sku");

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listStockRegister(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        sku,
      )
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    const mapped = mapStockError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to load stock register", 500);
  }
}

// ── INV-4: GET /inventory/stock/low-stock ──

export async function handleLowStock(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireInventoryRead(auth.claims);
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listLowStock(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
      )
    );
    // Each row carries sku + recommendedQuantity + vendorId so the client raises a
    // PO against the EXISTING POST /inventory/procurement/orders — no PO logic here.
    return jsonResponse(envelope({ items, count: items.length }));
  } catch (error) {
    const mapped = mapStockError(error);
    if (mapped) return mapped;
    return errorEnvelope("INTERNAL_ERROR", "Failed to load low stock", 500);
  }
}
