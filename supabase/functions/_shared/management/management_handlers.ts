import type { AppConfig } from "../config.ts";
import { createManagementReadHandlers } from "../entity_read/management_read_handlers.ts";
import { managementStore } from "./management_read_repository.ts";

const { handleSnapshot } = createManagementReadHandlers("viewManagement", managementStore);

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_dashboard", "Failed to load management dashboard");
}

export async function handleAnalytics(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_analytics", "Failed to load management analytics");
}

export async function handleAdmissionsFunnel(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_admissions_funnel", "Failed to load admissions funnel");
}

export async function handleFinancialHealth(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_financial_health", "Failed to load financial health");
}

export async function handleAcademicHealth(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_academic_health", "Failed to load academic health");
}

export async function handleSchoolPerformance(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_school_performance", "Failed to load school performance");
}

export async function handleTasks(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_tasks", "Failed to load tasks and approvals");
}

export async function handleSettings(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_settings", "Failed to load management settings");
}
