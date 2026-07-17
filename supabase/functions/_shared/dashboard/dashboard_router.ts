// WEB-001 (ERP-WT-001) — top-level dashboard router. Owns the /dashboard prefix.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import { handleDashboardOverview } from "./dashboard_handlers.ts";

export async function routeDashboard(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/dashboard")) return null;

  if (method === "GET" && path === "/dashboard/overview") {
    return await handleDashboardOverview(req, config);
  }

  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
