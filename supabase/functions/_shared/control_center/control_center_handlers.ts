import type { AppConfig } from "../config.ts";
import { createControlCenterReadHandlers } from "../entity_read/control_center_read_handlers.ts";
import { controlCenterStore } from "./control_center_read_repository.ts";

const { handleSnapshot, handleList } = createControlCenterReadHandlers(
  "viewControlCenter",
  controlCenterStore,
);

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_dashboard", "Failed to load control center dashboard");
}

export async function handleSchools(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "school", "Failed to load platform schools");
}

export async function handleSubscriptions(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_subscriptions", "Failed to load subscriptions");
}

export async function handleBilling(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_billing", "Failed to load billing");
}

export async function handleCrmPipeline(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_crm", "Failed to load CRM pipeline");
}

export async function handleSupportTickets(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "support_ticket", "Failed to load support tickets");
}

export async function handleCustomerSuccess(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_customer_success", "Failed to load customer success");
}

export async function handleWhiteLabel(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "white_label", "Failed to load white label configs");
}

export async function handleAnalytics(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_analytics", "Failed to load control center analytics");
}

export async function handleMonitoring(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_monitoring", "Failed to load monitoring");
}

export async function handleRoles(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_roles", "Failed to load roles");
}

export async function handleSettings(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_settings", "Failed to load control center settings");
}
