import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAnalyticsDashboard,
  handleAnalyticsHealth,
  handleAnalyticsRecommendations,
  handleAnalyticsRisks,
  handleAnalyticsTrends,
  handlePrincipalSummary,
  handleWeeklyBriefing,
} from "./analytics_handlers.ts";

export function matchAnalyticsRoute(
  method: string,
  path: string,
): {
  handler: (req: Request, config: AppConfig) => Promise<Response>;
} | null {
  if (method !== "GET") return null;
  if (path === "/analytics/dashboard") {
    return { handler: handleAnalyticsDashboard };
  }
  if (path === "/analytics/trends") {
    return { handler: handleAnalyticsTrends };
  }
  if (path === "/analytics/risks") {
    return { handler: handleAnalyticsRisks };
  }
  if (path === "/analytics/health") {
    return { handler: handleAnalyticsHealth };
  }
  if (path === "/analytics/recommendations") {
    return { handler: handleAnalyticsRecommendations };
  }
  if (path === "/analytics/principal-summary") {
    return { handler: handlePrincipalSummary };
  }
  if (path === "/analytics/weekly-briefing") {
    return { handler: handleWeeklyBriefing };
  }
  return null;
}

export async function routeAnalytics(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/analytics")) return null;
  const match = matchAnalyticsRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }
  return await match.handler(req, config);
}
