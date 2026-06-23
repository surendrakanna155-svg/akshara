import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAcknowledgeCompliance,
  handleAdmissions,
  handleCompliance,
  handleDashboard,
  handleExportReport,
  handleGrowth,
  handleMarketing,
  handlePortfolio,
  handleReports,
  handleRevenue,
  handleSchools,
  handleSummary,
} from "./director_handlers.ts";

const GET_ROUTES: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
  "/director/dashboard": handleDashboard,
  "/director/schools": handleSchools,
  "/director/portfolio": handlePortfolio,
  "/director/revenue": handleRevenue,
  "/director/growth": handleGrowth,
  "/director/marketing": handleMarketing,
  "/director/admissions": handleAdmissions,
  "/director/compliance": handleCompliance,
  "/director/reports": handleReports,
};

const ACK_RE = /^\/director\/compliance\/([^/]+)\/acknowledge$/;
const EXPORT_RE = /^\/director\/reports\/([^/]+)\/export$/;

export async function routeDirector(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/director")) return null;

  if (method === "GET") {
    const handler = GET_ROUTES[path];
    return handler ? await handler(req, config) : null;
  }

  if (method === "POST") {
    if (path === "/director/summary") return await handleSummary(req, config);

    const ack = ACK_RE.exec(path);
    if (ack) return await handleAcknowledgeCompliance(req, config, decodeURIComponent(ack[1]));

    const exp = EXPORT_RE.exec(path);
    if (exp) return await handleExportReport(req, config, decodeURIComponent(exp[1]));
  }

  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
