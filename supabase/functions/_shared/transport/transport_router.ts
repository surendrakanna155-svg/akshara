import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAllocations,
  handleAttendance,
  handleDashboard,
  handleDrivers,
  handleOccupancyMetrics,
  handleReports,
  handleRoutes,
  handleSettings,
  handleTracking,
  handleVehicles,
} from "./transport_handlers.ts";

function matchTransportRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method !== "GET") return null;

  const routes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
    "/transport/dashboard": handleDashboard,
    "/transport/routes": handleRoutes,
    "/transport/vehicles": handleVehicles,
    "/transport/drivers": handleDrivers,
    "/transport/allocations": handleAllocations,
    "/transport/attendance": handleAttendance,
    "/transport/tracking": handleTracking,
    "/transport/reports": handleReports,
    "/transport/settings": handleSettings,
    "/transport/occupancy-metrics": handleOccupancyMetrics,
  };

  const handler = routes[path] as (typeof routes)[string] | undefined;
  return handler ? { handler } : null;
}

export async function routeTransport(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/transport")) return null;

  const match = matchTransportRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
