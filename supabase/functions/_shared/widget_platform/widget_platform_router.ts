import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleGetDashboardLayout,
  handleGetWidgetData,
  handleListWidgets,
  handleRefreshWidgetData,
  handleResetRoleLayout,
  handleSaveDashboardLayout,
} from "./widget_platform_handlers.ts";

const ROLE_LAYOUT = /^\/widgets\/layouts\/([^/]+)$/;
const ROLE_LAYOUT_RESET = /^\/widgets\/layouts\/([^/]+)\/reset$/;

/**
 * Rewrites a request so the existing dashboard-layout handlers (which key on a
 * `dashboardKey` query param) honour the role from the `/widgets/layouts/:role`
 * path. Keeps a single layout storage path while serving the role-scoped client.
 */
function withDashboardKey(req: Request, role: string): Request {
  const url = new URL(req.url);
  if (!url.searchParams.has("dashboardKey")) {
    url.searchParams.set("dashboardKey", role);
  }
  return new Request(url.toString(), req);
}

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

  // Role-scoped layout paths used by the Flutter client
  // (EvolutionApiPaths.widgetRoleLayout). The role becomes the dashboardKey.
  const resetMatch = path.match(ROLE_LAYOUT_RESET);
  if (resetMatch && method === "POST") {
    return handleResetRoleLayout(req, config, decodeURIComponent(resetMatch[1]));
  }
  const layoutMatch = path.match(ROLE_LAYOUT);
  if (layoutMatch) {
    const role = decodeURIComponent(layoutMatch[1]);
    if (method === "GET") {
      return handleGetDashboardLayout(withDashboardKey(req, role), config);
    }
    if (method === "PUT") {
      return handleSaveDashboardLayout(withDashboardKey(req, role), config);
    }
  }

  if (path === "/widgets/data" && method === "GET") {
    return handleGetWidgetData(req, config);
  }
  if (path === "/widgets/data/refresh" && method === "POST") {
    return handleRefreshWidgetData(req, config);
  }

  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
