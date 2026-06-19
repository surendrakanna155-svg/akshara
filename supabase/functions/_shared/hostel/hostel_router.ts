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

function matchHostelRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method !== "GET") return null;

  const routes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
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

  const handler = routes[path] as (typeof routes)[string] | undefined;
  return handler ? { handler } : null;
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
