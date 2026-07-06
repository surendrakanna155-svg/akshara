import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleApprovePurchaseOrder,
  handleCreatePurchaseOrder,
  handleCreateVendor,
  handleGetPurchaseOrder,
  handleListDbPurchaseOrders,
  handleListDbVendors,
  handleListGrns,
  handleReceiveGoods,
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
  handleStockRegister,
  handleUpsertStockItem,
} from "./inventory_stock_handlers.ts";

export function matchInventoryFinanceRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
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

export async function routeInventoryFinanceWrite(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/inventory")) return null;
  const match = matchInventoryFinanceRoute(method, path);
  if (!match) return null;
  return await match.handler(req, config, ...match.args);
}
