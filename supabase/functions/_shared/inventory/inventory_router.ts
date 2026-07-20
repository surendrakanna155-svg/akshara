import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import { routeDeviceManagement } from "../device_management/device_management_router.ts";
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
import {
  handleAdvanceProcurementWorkflow,
  handleAssetLifecycle,
  handleInventoryCopilot,
  handleProcurementWorkflow,
  handleRecordAssetLifecycleEvent,
} from "./inventory_intelligence_handlers.ts";
import {
  handleCreateAllocation,
  handleCreateAsset,
  handleCreateCategory,
  handleRecordMaintenance,
  handleUpdateAsset,
} from "./inventory_write_handlers.ts";
import { routeInventoryFinanceWrite } from "../inventory_finance/inventory_finance_router.ts";

function matchInventoryIntelligenceRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/inventory/intelligence/copilot" && method === "GET") {
    return { handler: handleInventoryCopilot, args: [] };
  }
  if (path === "/inventory/intelligence/lifecycle" && method === "GET") {
    return { handler: handleAssetLifecycle, args: [] };
  }
  if (path === "/inventory/intelligence/lifecycle/events" && method === "POST") {
    return { handler: handleRecordAssetLifecycleEvent, args: [] };
  }
  if (path === "/inventory/intelligence/procurement-workflow" && method === "GET") {
    return { handler: handleProcurementWorkflow, args: [] };
  }

  const advanceMatch = path.match(/^\/inventory\/intelligence\/procurement-workflow\/([^/]+)\/advance$/);
  if (advanceMatch && method === "POST") {
    return { handler: handleAdvanceProcurementWorkflow, args: [advanceMatch[1]!] };
  }

  return null;
}

// PRA-P1-39: the inventory register's write surface (create/update asset,
// create category, allocate asset, record maintenance). Kept separate from the
// GET table below (which hard-rejects every non-GET method) and delegated from
// routeInventory before the base match, mirroring routeInventoryFinanceWrite.
function matchInventoryWriteRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method === "POST") {
    if (path === "/inventory/assets") return { handler: handleCreateAsset };
    if (path === "/inventory/categories") return { handler: handleCreateCategory };
    if (path === "/inventory/allocations") return { handler: handleCreateAllocation };
    if (path === "/inventory/maintenance") return { handler: handleRecordMaintenance };
    return null;
  }
  if (method === "PUT") {
    if (/^\/inventory\/assets\/[^/]+$/.test(path)) return { handler: handleUpdateAsset };
    return null;
  }
  return null;
}

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

  const handler = routes[path] as (typeof routes)[string] | undefined;
  return handler ? { handler } : null;
}

export async function routeInventory(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/inventory")) return null;

  // W4 device/asset management (owner #12): /inventory/devices/* — instance-level
  // asset register + custody lifecycle. Delegated FIRST so the generic inventory
  // register matching below never swallows a /inventory/devices path. Returns null
  // outside the /inventory/devices sub-prefix.
  const deviceResponse = await routeDeviceManagement(req, config, method, path);
  if (deviceResponse) return deviceResponse;

  const writeResponse = await routeInventoryFinanceWrite(req, config, method, path);
  if (writeResponse) return writeResponse;

  const intelligenceMatch = matchInventoryIntelligenceRoute(method, path);
  if (intelligenceMatch) {
    return await intelligenceMatch.handler(req, config, ...intelligenceMatch.args);
  }

  // PRA-P1-39: the register's own POST/PUT writes, before the GET-only base
  // table (which 404s every non-GET). These collide with none of the routes
  // above (finance-write owns /inventory/procurement|vendors/catalog|stock/*,
  // intelligence owns /inventory/intelligence/*).
  const writeMatch = matchInventoryWriteRoute(method, path);
  if (writeMatch) {
    return await writeMatch.handler(req, config);
  }

  const match = matchInventoryRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
