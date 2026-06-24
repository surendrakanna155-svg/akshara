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
import {
  handleActivateRoute,
  handleAssignStudentTransport,
  handleCreateRoute,
  handleRecordAttendance,
  handleRemoveStudentTransport,
  handleTransferStudentTransport,
} from "./transport_write_handlers.ts";

type RouteHandler = (req: Request, config: AppConfig) => Promise<Response>;

function matchTransportRoute(method: string, path: string): { handler: RouteHandler } | null {
  if (method === "GET") {
    const routes: Record<string, RouteHandler> = {
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
    const handler = routes[path] as RouteHandler | undefined;
    return handler ? { handler } : null;
  }

  if (method === "POST") {
    if (path === "/transport/routes") {
      return { handler: handleCreateRoute };
    }
    if (path === "/transport/allocations") {
      return { handler: handleAssignStudentTransport };
    }
    // --- A6 writes (AgentC) ---
    if (path === "/transport/attendance") {
      return { handler: handleRecordAttendance };
    }
    // --- end A6 writes (AgentC) ---
    if (/^\/transport\/routes\/[^/]+\/activate$/.test(path)) {
      return { handler: handleActivateRoute };
    }
    if (/^\/transport\/allocations\/[^/]+\/transfer$/.test(path)) {
      return { handler: handleTransferStudentTransport };
    }
    return null;
  }

  if (method === "DELETE") {
    if (/^\/transport\/allocations\/[^/]+$/.test(path)) {
      return { handler: handleRemoveStudentTransport };
    }
    return null;
  }

  return null;
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
