import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAllocations,
  handleAttendance,
  handleDashboard,
  handleDrivers,
  handleOccupancyMetrics,
  handleReports,
  handleRouteRoster,
  handleRoutes,
  handleSettings,
  handleTracking,
  handleVehicles,
} from "./transport_handlers.ts";
import {
  handleActivateRoute,
  handleAddStop,
  handleAssignRouteVehicle,
  handleAssignStudentTransport,
  handleBulkAllocateTransport,
  handleBulkRaiseTransportDemand,
  handleCreateDriver,
  handleCreateRoute,
  handleCreateVehicle,
  handleDeleteDriver,
  handleDeleteVehicle,
  handleDocumentExpiryReminder,
  handleGenerateAttendanceRoster,
  handleNotifyRouteDelay,
  handleRaiseTransportDemand,
  handleRecordAttendance,
  handleRemoveStop,
  handleRemoveStudentTransport,
  handleReorderStops,
  handleTransferStudentTransport,
  handleUpdateDriver,
  handleUpdateStop,
  handleUpdateVehicle,
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
    if (handler) return { handler };
    // TRN-3: stop-wise roster read.
    if (/^\/transport\/routes\/[^/]+\/roster$/.test(path)) {
      return { handler: handleRouteRoster };
    }
    return null;
  }

  if (method === "POST") {
    if (path === "/transport/routes") {
      return { handler: handleCreateRoute };
    }
    if (path === "/transport/allocations") {
      return { handler: handleAssignStudentTransport };
    }
    // TRN-5: bulk allocation.
    if (path === "/transport/allocations/bulk") {
      return { handler: handleBulkAllocateTransport };
    }
    // PRA-P1-43: generate a route's attendance roster from its allocations
    // (more specific than the collection POST — match first).
    if (path === "/transport/attendance/generate") {
      return { handler: handleGenerateAttendanceRoster };
    }
    // --- A6 writes (AgentC) ---
    if (path === "/transport/attendance") {
      return { handler: handleRecordAttendance };
    }
    // --- end A6 writes (AgentC) ---
    if (path === "/transport/notify-delay") {
      return { handler: handleNotifyRouteDelay };
    }
    // TRN-1: vehicle & driver create.
    if (path === "/transport/vehicles") {
      return { handler: handleCreateVehicle };
    }
    if (path === "/transport/drivers") {
      return { handler: handleCreateDriver };
    }
    // TRN-8: document-expiry reminder.
    if (path === "/transport/reminders/document-expiry") {
      return { handler: handleDocumentExpiryReminder };
    }
    // PRA-P0-20: bulk-raise transport-fee demands (more specific — match first).
    if (path === "/transport/demands/bulk") {
      return { handler: handleBulkRaiseTransportDemand };
    }
    // TRN-9: raise a Finance transport-fee demand.
    if (path === "/transport/demands") {
      return { handler: handleRaiseTransportDemand };
    }
    if (/^\/transport\/routes\/[^/]+\/activate$/.test(path)) {
      return { handler: handleActivateRoute };
    }
    // TRN-4: stop editor (reorder is a fixed sub-path; add is the collection POST).
    if (/^\/transport\/routes\/[^/]+\/stops\/reorder$/.test(path)) {
      return { handler: handleReorderStops };
    }
    if (/^\/transport\/routes\/[^/]+\/stops$/.test(path)) {
      return { handler: handleAddStop };
    }
    if (/^\/transport\/allocations\/[^/]+\/transfer$/.test(path)) {
      return { handler: handleTransferStudentTransport };
    }
    return null;
  }

  if (method === "PUT") {
    // PRA-P0-19: assign a vehicle to a route (more specific than the stop update
    // — but distinct paths; wires the TRN-7 capacity guard live).
    if (/^\/transport\/routes\/[^/]+\/vehicle$/.test(path)) {
      return { handler: handleAssignRouteVehicle };
    }
    // TRN-1: vehicle & driver update.
    if (/^\/transport\/vehicles\/[^/]+$/.test(path)) {
      return { handler: handleUpdateVehicle };
    }
    if (/^\/transport\/drivers\/[^/]+$/.test(path)) {
      return { handler: handleUpdateDriver };
    }
    // TRN-4: update a stop.
    if (/^\/transport\/routes\/[^/]+\/stops\/[^/]+$/.test(path)) {
      return { handler: handleUpdateStop };
    }
    return null;
  }

  if (method === "DELETE") {
    // TRN-4: remove a stop (more specific — match before the allocation delete).
    if (/^\/transport\/routes\/[^/]+\/stops\/[^/]+$/.test(path)) {
      return { handler: handleRemoveStop };
    }
    // TRN-1: vehicle & driver delete.
    if (/^\/transport\/vehicles\/[^/]+$/.test(path)) {
      return { handler: handleDeleteVehicle };
    }
    if (/^\/transport\/drivers\/[^/]+$/.test(path)) {
      return { handler: handleDeleteDriver };
    }
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
