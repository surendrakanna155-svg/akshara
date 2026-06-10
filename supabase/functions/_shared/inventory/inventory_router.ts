import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAllocations,
  handleAssets,
  handleCategories,
  handleDashboard,
  handleMaintenance,
  handleProcurement,
  handleReports,
  handleVendors,
} from "./inventory_handlers.ts";
import { routeInventoryFinanceWrite } from "../inventory_finance/inventory_finance_router.ts";

function matchInventoryRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method !== "GET") return null;

  const routes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
    "/inventory/dashboard": handleDashboard,
    "/inventory/assets": handleAssets,
    "/inventory/categories": handleCategories,
    "/inventory/allocations": handleAllocations,
    "/inventory/maintenance": handleMaintenance,
    "/inventory/procurement": handleProcurement,
    "/inventory/vendors": handleVendors,
    "/inventory/reports": handleReports,
  };

  const handler = routes[path];
  return handler ? { handler } : null;
}

export async function routeInventory(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/inventory")) return null;

  const writeResponse = await routeInventoryFinanceWrite(req, config, method, path);
  if (writeResponse) return writeResponse;

  const match = matchInventoryRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
