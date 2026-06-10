import type { AppConfig } from "../config.ts";
import { createModuleReadHandlers } from "../entity_read/module_read_handlers.ts";
import { inventoryStore } from "./inventory_read_repository.ts";

const { handleSnapshot, handleList } = createModuleReadHandlers("viewInventory", inventoryStore);

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_dashboard", "Failed to load inventory dashboard");
}

export async function handleAssets(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "asset", "Failed to load inventory assets");
}

export async function handleCategories(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "category", "Failed to load inventory categories");
}

export async function handleAllocations(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "allocation", "Failed to load inventory allocations");
}

export async function handleMaintenance(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "maintenance", "Failed to load maintenance records");
}

export async function handleProcurement(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "procurement", "Failed to load procurement orders");
}

export async function handleVendors(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "vendor", "Failed to load inventory vendors");
}

export async function handleReports(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_reports", "Failed to load inventory reports");
}
