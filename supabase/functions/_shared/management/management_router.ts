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

function matchManagementRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method !== "GET") return null;

  const routes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
    "/management/dashboard": handleDashboard,
    "/management/analytics": handleAnalytics,
    "/management/admissions-funnel": handleAdmissionsFunnel,
    "/management/financial-health": handleFinancialHealth,
    "/management/academic-health": handleAcademicHealth,
    "/management/school-performance": handleSchoolPerformance,
    "/management/tasks": handleTasks,
    "/management/settings": handleSettings,
  };

  const handler = routes[path] as (typeof routes)[string] | undefined;
  return handler ? { handler } : null;
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
