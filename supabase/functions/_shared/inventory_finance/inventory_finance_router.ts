import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleApprovePurchaseOrder,
  handleCreatePurchaseOrder,
  handleCreateVendor,
  handleGetPurchaseOrder,
  handleListDbPurchaseOrders,
  handleListDbVendors,
  handleReceiveGoods,
  handleStockValuation,
} from "./inventory_finance_handlers.ts";

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
