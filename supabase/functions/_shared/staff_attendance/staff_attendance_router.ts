// B4 — staff attendance (RE-IMPLEMENTED) router. Routes:
//   POST /staff-attendance/check                     record a geofence+face-matched check-in/out
//   POST /staff-attendance/enroll-face               enrol/replace own reference face
//   GET  /staff-attendance/geofence                  read the school geofence config
//   PUT  /staff-attendance/geofence                  set the school geofence config (admin)
//   POST /staff-attendance/manual-request            raise an audited manual attendance request
//   GET  /staff-attendance/manual-requests            SLICE 4: own requests (?mine=true) / pending queue (approver)
//   POST /staff-attendance/manual-request/decide     approve/reject a manual request (approver)
//   GET  /staff-attendance/my-history                TCH-9: read-only OWN attendance history

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleCreateManualRequest,
  handleDecideManualRequest,
  handleListManualRequests,
  handleEnrollFace,
  handleGetGeofence,
  handleMyAttendanceHistory,
  handleRecordStaffCheckIn,
  handleSetGeofence,
} from "./staff_attendance_handlers.ts";

type Handler = (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>;

export function matchStaffAttendanceRoute(
  method: string,
  path: string,
): { handler: Handler; args: string[] } | null {
  if (path === "/staff-attendance/check" && method === "POST") {
    return { handler: handleRecordStaffCheckIn, args: [] };
  }
  if (path === "/staff-attendance/enroll-face" && method === "POST") {
    return { handler: handleEnrollFace, args: [] };
  }
  if (path === "/staff-attendance/geofence" && method === "GET") {
    return { handler: handleGetGeofence, args: [] };
  }
  if (path === "/staff-attendance/geofence" && method === "PUT") {
    return { handler: handleSetGeofence, args: [] };
  }
  if (path === "/staff-attendance/manual-request" && method === "POST") {
    return { handler: handleCreateManualRequest, args: [] };
  }
  if (path === "/staff-attendance/manual-requests" && method === "GET") {
    return { handler: handleListManualRequests, args: [] };
  }
  if (path === "/staff-attendance/manual-request/decide" && method === "POST") {
    return { handler: handleDecideManualRequest, args: [] };
  }
  if (path === "/staff-attendance/my-history" && method === "GET") {
    return { handler: handleMyAttendanceHistory, args: [] };
  }
  return null;
}

export async function routeStaffAttendance(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/staff-attendance")) return null;

  const match = matchStaffAttendanceRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }
  return await match.handler(req, config, ...match.args);
}
