import type { AppConfig } from "../config.ts";
import { enforceEntitlement } from "../entitlements/entitlement_middleware.ts";
import { entitlementEnforcementEnabled } from "../entitlements/entitlement_enforcement.ts";
import {
  handleApprovePurchaseOrder,
  handleCreatePurchaseOrder,
  handleCreateVendor,
  handleGetPurchaseOrder,
  handleListDbPurchaseOrders,
  handleListDbVendors,
  handleListGrns,
  handleReceiveGoods,
  handleStockLevels,
  handleStockValuation,
} from "./inventory_finance_handlers.ts";
import {
  handleAdjustStock,
  handleApproveStockAdjustment,
  handleIssueStock,
  handleListPendingAdjustments,
  handleListStockItems,
  handleLowStock,
  handleRecordStockCount,
  handleRejectStockAdjustment,
  handleStockApprovals,
  handleStockRegister,
  handleUpsertStockItem,
} from "./inventory_stock_handlers.ts";
import {
  handleGetGoodsReceipt,
  handleInventoryFinanceTimeline,
  handleListGoodsReceipts,
  handleListInventoryFinancePostings,
  handleReconciliationDashboard,
  handleVendorTransactions,
} from "./inventory_finance_reconciliation_handlers.ts";

// ICA-F6: the module.inventory plan entitlement that gates the /inventory/*
// procurement + stock surface. Kept identical to the slug this surface inherited
// when it was delegated from `withEntitlement(routeInventory, "/inventory",
// "module.inventory")` — the move must not change the gate.
const INVENTORY_ENTITLEMENT = "module.inventory";

export function matchInventoryFinanceRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  // ── Reconciliation read surface (viewFinance, no entitlement) ──
  // Exposed under /finance/inventory-reconciliation/*. Moved here from
  // finance_router.ts (ICA-F6) so the whole inventory_finance domain lives behind
  // ONE router. The exact/list paths are matched BEFORE the /:id regexes so a
  // literal segment (e.g. "goods-receipts") is never read as an id.
  if (path === "/finance/inventory-reconciliation/dashboard" && method === "GET") {
    return { handler: handleReconciliationDashboard, args: [] };
  }
  if (path === "/finance/inventory-reconciliation/timeline" && method === "GET") {
    return { handler: handleInventoryFinanceTimeline, args: [] };
  }
  if (path === "/finance/inventory-reconciliation/goods-receipts" && method === "GET") {
    return { handler: handleListGoodsReceipts, args: [] };
  }
  if (path === "/finance/inventory-reconciliation/postings" && method === "GET") {
    return { handler: handleListInventoryFinancePostings, args: [] };
  }

  const goodsReceiptMatch = path.match(
    /^\/finance\/inventory-reconciliation\/goods-receipts\/([^/]+)$/,
  );
  if (goodsReceiptMatch && method === "GET") {
    return { handler: handleGetGoodsReceipt, args: [goodsReceiptMatch[1]!] };
  }

  const vendorTxMatch = path.match(
    /^\/finance\/inventory-reconciliation\/vendors\/([^/]+)\/transactions$/,
  );
  if (vendorTxMatch && method === "GET") {
    return { handler: handleVendorTransactions, args: [vendorTxMatch[1]!] };
  }

  // ── Procurement + vendor-catalog surface (view/manageInventory) ──
  if (path === "/inventory/vendors/catalog" && method === "GET") {
    return { handler: handleListDbVendors, args: [] };
  }
  if (path === "/inventory/vendors/catalog" && method === "POST") {
    return { handler: handleCreateVendor, args: [] };
  }
  if (path === "/inventory/procurement/orders" && method === "GET") {
    return { handler: handleListDbPurchaseOrders, args: [] };
  }
  if (path === "/inventory/procurement/orders" && method === "POST") {
    return { handler: handleCreatePurchaseOrder, args: [] };
  }
  // INV-5: GRN (goods received) register, viewInventory-gated.
  if (path === "/inventory/procurement/grns" && method === "GET") {
    return { handler: handleListGrns, args: [] };
  }

  const poDetailMatch = path.match(/^\/inventory\/procurement\/orders\/([^/]+)$/);
  if (poDetailMatch && method === "GET") {
    return { handler: handleGetPurchaseOrder, args: [poDetailMatch[1]!] };
  }

  const approveMatch = path.match(/^\/inventory\/procurement\/orders\/([^/]+)\/approve$/);
  if (approveMatch && method === "POST") {
    return { handler: handleApprovePurchaseOrder, args: [approveMatch[1]!] };
  }

  const receiveMatch = path.match(/^\/inventory\/procurement\/orders\/([^/]+)\/receive$/);
  if (receiveMatch && method === "POST") {
    return { handler: handleReceiveGoods, args: [receiveMatch[1]!] };
  }

  if (path === "/inventory/stock/valuation" && method === "GET") {
    return { handler: handleStockValuation, args: [] };
  }

  // WEB-004: the value-reducing approval register — exact path, before the bare
  // /inventory/stock list so it isn't misread as a stock query.
  if (path === "/inventory/stock/approvals" && method === "GET") {
    return { handler: handleStockApprovals, args: [] };
  }
  // WEB-004: the primary stock ledger (on-hand + reorder + valuation).
  if (path === "/inventory/stock" && method === "GET") {
    return { handler: handleStockLevels, args: [] };
  }

  // ── INV-1..7: Store stock module ──
  if (path === "/inventory/stock/issue" && method === "POST") {
    return { handler: handleIssueStock, args: [] };
  }
  if (path === "/inventory/stock/adjust" && method === "POST") {
    return { handler: handleAdjustStock, args: [] };
  }

  // Maker-checker decisions (match the specific :id sub-paths BEFORE the list).
  const approveAdjMatch = path.match(/^\/inventory\/stock\/adjustments\/([^/]+)\/approve$/);
  if (approveAdjMatch && method === "POST") {
    return { handler: handleApproveStockAdjustment, args: [approveAdjMatch[1]!] };
  }
  const rejectAdjMatch = path.match(/^\/inventory\/stock\/adjustments\/([^/]+)\/reject$/);
  if (rejectAdjMatch && method === "POST") {
    return { handler: handleRejectStockAdjustment, args: [rejectAdjMatch[1]!] };
  }
  if (path === "/inventory/stock/adjustments" && method === "GET") {
    return { handler: handleListPendingAdjustments, args: [] };
  }

  if (path === "/inventory/stock/count" && method === "POST") {
    return { handler: handleRecordStockCount, args: [] };
  }

  if (path === "/inventory/stock/items" && method === "GET") {
    return { handler: handleListStockItems, args: [] };
  }
  if (path === "/inventory/stock/items" && (method === "POST" || method === "PUT")) {
    return { handler: handleUpsertStockItem, args: [] };
  }

  if (path === "/inventory/stock/register" && method === "GET") {
    return { handler: handleStockRegister, args: [] };
  }
  if (path === "/inventory/stock/low-stock" && method === "GET") {
    return { handler: handleLowStock, args: [] };
  }

  return null;
}

/**
 * ICA-F6 — the single router for the inventory_finance domain, registered once in
 * `api/app.ts`. It owns two disjoint path prefixes:
 *
 *   /inventory/{vendors/catalog, procurement/*, stock/*}   — procurement + stock
 *   /finance/inventory-reconciliation/*                    — reconciliation reads
 *
 * Previously the reconciliation reads were inlined in `finance_router.ts` and the
 * procurement/stock surface was delegated from `routeInventory` — one domain split
 * across two parent routers, with no direct entry in `app.ts`. This unifies both.
 *
 * Because a single `withEntitlement(...)` wrapper matches only one prefix, and only
 * the /inventory/* surface is plan-gated (the /finance reconciliation reads never
 * were), the `module.inventory` entitlement is self-enforced HERE for the
 * /inventory/* matches only — the same org-builder pattern used by
 * `routeOrganizationBuilder`, and behaviourally identical to the wrapper the
 * procurement/stock routes inherited from `withEntitlement(routeInventory,
 * "/inventory", "module.inventory")`.
 *
 * Returns null for any path it does not own (or any owned prefix path that matches
 * no route) so the sibling routers (`routeInventory`, `routeFinance`, registered
 * after it) still own the rest of their prefixes.
 */
export async function routeInventoryFinance(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  const isInventoryPath = path.startsWith("/inventory/");
  const isReconciliationPath = path.startsWith("/finance/inventory-reconciliation");
  if (!isInventoryPath && !isReconciliationPath) return null;

  const match = matchInventoryFinanceRoute(method, path);
  if (!match) return null;

  // Plan-entitlement gate for the /inventory/* procurement+stock surface only —
  // runs BEFORE the handler's RBAC, exactly as the withEntitlement wrapper did.
  // The /finance/inventory-reconciliation/* reads carry no plan entitlement.
  if (isInventoryPath && entitlementEnforcementEnabled()) {
    const denied = await enforceEntitlement(req, config, INVENTORY_ENTITLEMENT);
    if (denied) return denied;
  }

  return await match.handler(req, config, ...match.args);
}
