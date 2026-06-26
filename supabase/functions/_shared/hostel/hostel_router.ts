import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAttendance,
  handleDashboard,
  handleLeave,
  handleMess,
  handleOccupancyMetrics,
  handleReports,
  handleRooms,
  handleStudents,
  handleVisitors,
} from "./hostel_handlers.ts";
import {
  handleAdmitStudent,
  handleAssignRoom,
  handleCheckoutStudent,
  handleCreateRoom,
  handleLogVisitor,
  handleRecordHostelAttendance,
  handleRecordMess,
} from "./hostel_write_handlers.ts";

type RouteHandler = (req: Request, config: AppConfig) => Promise<Response>;

function matchHostelRoute(method: string, path: string): { handler: RouteHandler } | null {
  if (method === "GET") {
    const routes: Record<string, RouteHandler> = {
      "/hostel/dashboard": handleDashboard,
      "/hostel/students": handleStudents,
      "/hostel/rooms": handleRooms,
      "/hostel/attendance": handleAttendance,
      "/hostel/leave": handleLeave,
      "/hostel/mess": handleMess,
      "/hostel/visitors": handleVisitors,
      "/hostel/reports": handleReports,
      "/hostel/occupancy-metrics": handleOccupancyMetrics,
    };
    const handler = routes[path] as RouteHandler | undefined;
    return handler ? { handler } : null;
  }

  if (method === "POST") {
    const staticRoutes: Record<string, RouteHandler> = {
      "/hostel/students": handleAdmitStudent,
      "/hostel/rooms": handleCreateRoom,
      "/hostel/attendance": handleRecordHostelAttendance,
      "/hostel/mess": handleRecordMess,
      "/hostel/visitors": handleLogVisitor,
    };
    const staticHandler = staticRoutes[path] as RouteHandler | undefined;
    if (staticHandler) return { handler: staticHandler };

    const roomMatch = path.match(/^\/hostel\/students\/([^/]+)\/room$/);
    if (roomMatch) {
      return { handler: handleAssignRoom(roomMatch[1]!) };
    }

    const checkoutMatch = path.match(/^\/hostel\/students\/([^/]+)\/checkout$/);
    if (checkoutMatch) {
      return { handler: handleCheckoutStudent(checkoutMatch[1]!) };
    }

    return null;
  }

  return null;
}

export async function routeHostel(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/hostel")) return null;

  const match = matchHostelRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
