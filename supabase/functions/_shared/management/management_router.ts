import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAcademicHealth,
  handleAdmissionsFunnel,
  handleAnalytics,
  handleDashboard,
  handleFinancialHealth,
  handleSchoolPerformance,
  handleSettings,
  handleTasks,
} from "./management_handlers.ts";
import { handleUpdateSettings } from "./management_write_handlers.ts";

type ManagementHandler = (req: Request, config: AppConfig) => Promise<Response>;

function matchManagementRoute(
  method: string,
  path: string,
): { handler: ManagementHandler } | null {
  if (method === "GET") {
    const readRoutes: Record<string, ManagementHandler> = {
      "/management/dashboard": handleDashboard,
      "/management/analytics": handleAnalytics,
      "/management/admissions-funnel": handleAdmissionsFunnel,
      "/management/financial-health": handleFinancialHealth,
      "/management/academic-health": handleAcademicHealth,
      "/management/school-performance": handleSchoolPerformance,
      "/management/tasks": handleTasks,
      "/management/settings": handleSettings,
    };
    const handler = readRoutes[path] as ManagementHandler | undefined;
    return handler ? { handler } : null;
  }

  if (method === "PUT") {
    const writeRoutes: Record<string, ManagementHandler> = {
      "/management/settings": handleUpdateSettings,
    };
    const handler = writeRoutes[path] as ManagementHandler | undefined;
    return handler ? { handler } : null;
  }

  return null;
}

export async function routeManagement(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/management")) return null;

  const match = matchManagementRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
