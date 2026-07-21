import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleGenerateParentInsights,
  handleGetParentLanguagePreference,
  handleListParentInsights,
  handleSaveParentLanguagePreference,
} from "./parent_insights_handlers.ts";

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function routeParentInsights(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/parent-insights")) return null;

  if (path === "/parent-insights/generate" && method === "POST") {
    return handleGenerateParentInsights(req, config);
  }
  if (path === "/parent-insights/language-preference" && method === "GET") {
    return handleGetParentLanguagePreference(req, config);
  }
  if (path === "/parent-insights/language-preference" && method === "PUT") {
    return handleSaveParentLanguagePreference(req, config);
  }

  const listMatch = path.match(/^\/parent-insights\/students\/([^/]+)$/);
  if (listMatch && method === "GET" && UUID.test(listMatch[1]!)) {
    return handleListParentInsights(req, config, listMatch[1]!);
  }

  return null;
}
