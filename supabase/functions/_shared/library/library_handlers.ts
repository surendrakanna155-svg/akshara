import type { AppConfig } from "../config.ts";
import { createModuleReadHandlers } from "../entity_read/module_read_handlers.ts";
import { libraryStore } from "./library_read_repository.ts";

const { handleSnapshot, handleList } = createModuleReadHandlers("viewLibrary", libraryStore);

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_dashboard", "Failed to load library dashboard");
}

export async function handleCatalog(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "catalog", "Failed to load library catalog");
}

export async function handleIssues(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "issue", "Failed to load library issues");
}

export async function handleReturns(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "return_record", "Failed to load library returns");
}

export async function handleMembers(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "member", "Failed to load library members");
}

export async function handleFines(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_fines", "Failed to load library fines");
}

export async function handleDigitalResources(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_digital_resources", "Failed to load digital resources");
}

export async function handleReports(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_reports", "Failed to load library reports");
}
