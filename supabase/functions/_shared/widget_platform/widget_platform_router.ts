import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleGetDashboardLayout,
  handleGetWidgetData,
  handleListWidgets,
  handleRefreshWidgetData,
  handleSaveDashboardLayout,
} from "./widget_platform_handlers.ts";

export async function routeWidgetPlatform(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/widgets")) return null;

  if (path === "/widgets/registry" && method === "GET") {
    return handleListWidgets(req, config);
  }
  if (path === "/widgets/dashboard/layout" && method === "GET") {
    return handleGetDashboardLayout(req, config);
  }
  if (path === "/widgets/dashboard/layout" && method === "PUT") {
    return handleSaveDashboardLayout(req, config);
  }
  if (path === "/widgets/data" && method === "GET") {
    return handleGetWidgetData(req, config);
  }
  if (path === "/widgets/data/refresh" && method === "POST") {
    return handleRefreshWidgetData(req, config);
  }

  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
