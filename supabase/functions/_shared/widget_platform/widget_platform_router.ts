import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleGetDashboardLayout,
  handleGetWidgetData,
  handleListWidgets,
  handleRefreshWidgetData,
  handleSaveDashboardLayout,
} from "./widget_platform_handlers.ts";
import {
  handleGetRoleLayout,
  handleListDataSources,
  handleListLayoutVersions,
  handleResetRoleLayout,
  handleSaveRoleLayout,
} from "./widget_layout_handlers.ts";

const ROLE_LAYOUT = /^\/widgets\/layouts\/([^/]+)$/;
const ROLE_LAYOUT_RESET = /^\/widgets\/layouts\/([^/]+)\/reset$/;

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

  // B11 — rich role/vertical-pack contract. Static segments are matched BEFORE
  // the ROLE_LAYOUT param regex so "data-sources"/"versions" are never captured
  // as a role.
  if (path === "/widgets/data-sources" && method === "GET") {
    return handleListDataSources(req, config);
  }
  if (path === "/widgets/layouts/versions" && method === "GET") {
    return handleListLayoutVersions(req, config);
  }

  // Role-scoped layout paths used by the Flutter client
  // (EvolutionApiPaths.widgetRoleLayout) — pack default + tenant override.
  const resetMatch = path.match(ROLE_LAYOUT_RESET);
  if (resetMatch && method === "POST") {
    return handleResetRoleLayout(req, config, decodeURIComponent(resetMatch[1]));
  }
  const layoutMatch = path.match(ROLE_LAYOUT);
  if (layoutMatch) {
    const role = decodeURIComponent(layoutMatch[1]);
    if (method === "GET") {
      return handleGetRoleLayout(req, config, role);
    }
    if (method === "PUT") {
      return handleSaveRoleLayout(req, config, role);
    }
  }

  if (path === "/widgets/data" && method === "GET") {
    return handleGetWidgetData(req, config);
  }
  if (path === "/widgets/data/refresh" && method === "POST") {
    return handleRefreshWidgetData(req, config);
  }

  return null;
}
