import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleApproveReplacementRequest,
  handleCreateDistribution,
  handleDistributionDashboard,
  handleDistributionReports,
  handleFulfillReplacementRequest,
  handleListCatalogItems,
  handleListDistributions,
  handleListReplacementRequests,
  handleRejectReplacementRequest,
  handleRequestReplacement,
  handleTransitionDistribution,
} from "./inventory_distribution_handlers.ts";

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function matchInventoryDistributionRoute(
  method: string,
  path: string,
): {
  handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>;
  args: string[];
} | null {
  if (path === "/inventory/distribution/dashboard" && method === "GET") {
    return { handler: handleDistributionDashboard, args: [] };
  }
  if (path === "/inventory/distribution/reports" && method === "GET") {
    return { handler: handleDistributionReports, args: [] };
  }
  if (path === "/inventory/distribution/catalog" && method === "GET") {
    return { handler: handleListCatalogItems, args: [] };
  }
  if (path === "/inventory/distribution/items" && method === "GET") {
    return { handler: handleListDistributions, args: [] };
  }
  if (path === "/inventory/distribution/items" && method === "POST") {
    return { handler: handleCreateDistribution, args: [] };
  }

  const statusMatch = path.match(/^\/inventory\/distribution\/items\/([^/]+)\/status$/);
  if (statusMatch && method === "POST" && UUID.test(statusMatch[1]!)) {
    return { handler: handleTransitionDistribution, args: [statusMatch[1]!] };
  }

  const replaceMatch = path.match(/^\/inventory\/distribution\/items\/([^/]+)\/replacement$/);
  if (replaceMatch && method === "POST" && UUID.test(replaceMatch[1]!)) {
    return { handler: handleRequestReplacement, args: [replaceMatch[1]!] };
  }

  if (path === "/inventory/distribution/replacements" && method === "GET") {
    return { handler: handleListReplacementRequests, args: [] };
  }

  const approveMatch = path.match(/^\/inventory\/distribution\/replacements\/([^/]+)\/approve$/);
  if (approveMatch && method === "POST" && UUID.test(approveMatch[1]!)) {
    return { handler: handleApproveReplacementRequest, args: [approveMatch[1]!] };
  }

  const fulfillMatch = path.match(/^\/inventory\/distribution\/replacements\/([^/]+)\/fulfill$/);
  if (fulfillMatch && method === "POST" && UUID.test(fulfillMatch[1]!)) {
    return { handler: handleFulfillReplacementRequest, args: [fulfillMatch[1]!] };
  }

  const rejectMatch = path.match(/^\/inventory\/distribution\/replacements\/([^/]+)\/reject$/);
  if (rejectMatch && method === "POST" && UUID.test(rejectMatch[1]!)) {
    return { handler: handleRejectReplacementRequest, args: [rejectMatch[1]!] };
  }

  return null;
}

export async function routeInventoryDistribution(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/inventory/distribution")) return null;
  const match = matchInventoryDistributionRoute(method, path);
  if (!match) {
    return null;
  }
  try {
    return await match.handler(req, config, ...match.args);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Inventory distribution route failed";
    return errorEnvelope("INVENTORY_DISTRIBUTION_ROUTE_ERROR", message, 500);
  }
}
