import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleConvertGrowthInquiry,
  handleCreateGrowthCampaign,
  handleCreateGrowthInquiry,
  handleGrowthDashboard,
  handleGrowthFunnel,
  handleListGrowthCampaigns,
  handleListGrowthInquiries,
} from "./growth_handlers.ts";

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function routeGrowth(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/growth")) return null;

  if (path === "/growth/dashboard" && method === "GET") {
    return handleGrowthDashboard(req, config);
  }
  if (path === "/growth/funnel" && method === "GET") {
    return handleGrowthFunnel(req, config);
  }
  if (path === "/growth/campaigns" && method === "GET") {
    return handleListGrowthCampaigns(req, config);
  }
  if (path === "/growth/campaigns" && method === "POST") {
    return handleCreateGrowthCampaign(req, config);
  }
  if (path === "/growth/inquiries" && method === "GET") {
    return handleListGrowthInquiries(req, config);
  }
  if (path === "/growth/inquiries" && method === "POST") {
    return handleCreateGrowthInquiry(req, config);
  }

  const convertMatch = path.match(/^\/growth\/inquiries\/([^/]+)\/convert$/);
  if (convertMatch && method === "POST" && UUID.test(convertMatch[1]!)) {
    return handleConvertGrowthInquiry(req, config, convertMatch[1]!);
  }

  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
