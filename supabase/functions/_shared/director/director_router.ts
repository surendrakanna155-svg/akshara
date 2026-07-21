import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAcknowledgeCompliance,
  handleAdmissions,
  handleCollections,
  handleCompliance,
  handleDashboard,
  handleExportReport,
  handleGrowth,
  handleMarketing,
  handleMetricInputs,
  handlePortfolio,
  handleReports,
  handleRevenue,
  handleSaveMetricInput,
  handleSchools,
  handleSchoolSnapshot,
  handleSummary,
} from "./director_handlers.ts";

const GET_ROUTES: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
  "/director/dashboard": handleDashboard,
  "/director/schools": handleSchools,
  "/director/collections": handleCollections,
  "/director/portfolio": handlePortfolio,
  "/director/revenue": handleRevenue,
  "/director/growth": handleGrowth,
  "/director/marketing": handleMarketing,
  "/director/admissions": handleAdmissions,
  "/director/compliance": handleCompliance,
  "/director/reports": handleReports,
  "/director/metric-inputs": handleMetricInputs,
};

// DIR-D1 — per-school drill-down snapshot (parameterized GET; matched before the
// static GET table so `:schoolId` is captured, not treated as a literal key).
const SNAPSHOT_RE = /^\/director\/schools\/([^/]+)\/snapshot$/;

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
    const snapshot = SNAPSHOT_RE.exec(path);
    if (snapshot) {
      return await handleSchoolSnapshot(req, config, decodeURIComponent(snapshot[1]));
    }
    const handler = GET_ROUTES[path];
    return handler ? await handler(req, config) : null;
  }

  if (method === "POST") {
    if (path === "/director/summary") return await handleSummary(req, config);
    if (path === "/director/metric-inputs") return await handleSaveMetricInput(req, config);

    const ack = ACK_RE.exec(path);
    if (ack) return await handleAcknowledgeCompliance(req, config, decodeURIComponent(ack[1]));

    const exp = EXPORT_RE.exec(path);
    if (exp) return await handleExportReport(req, config, decodeURIComponent(exp[1]));
  }

  return null;
}
