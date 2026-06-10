import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAnalytics,
  handleBilling,
  handleCrmPipeline,
  handleCustomerSuccess,
  handleDashboard,
  handleMonitoring,
  handleRoles,
  handleSchools,
  handleSettings,
  handleSubscriptions,
  handleSupportTickets,
  handleWhiteLabel,
} from "./control_center_handlers.ts";

function matchControlCenterRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method !== "GET") return null;

  const routes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
    "/control-center/dashboard": handleDashboard,
    "/control-center/schools": handleSchools,
    "/control-center/subscriptions": handleSubscriptions,
    "/control-center/billing": handleBilling,
    "/control-center/crm-pipeline": handleCrmPipeline,
    "/control-center/support-tickets": handleSupportTickets,
    "/control-center/customer-success": handleCustomerSuccess,
    "/control-center/white-label": handleWhiteLabel,
    "/control-center/analytics": handleAnalytics,
    "/control-center/monitoring": handleMonitoring,
    "/control-center/roles": handleRoles,
    "/control-center/settings": handleSettings,
  };

  const handler = routes[path];
  return handler ? { handler } : null;
}

export async function routeControlCenter(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/control-center")) return null;

  const match = matchControlCenterRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
