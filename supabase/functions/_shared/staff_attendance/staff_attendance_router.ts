// Staff Face ID attendance router. Single write route: a staff member records
// their own biometric-gated check-in/out.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import { handleRecordStaffCheckIn } from "./staff_attendance_handlers.ts";

export function matchStaffAttendanceRoute(
  method: string,
  path: string,
): {
  handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>;
  args: string[];
} | null {
  if (path === "/staff-attendance/check" && method === "POST") {
    return { handler: handleRecordStaffCheckIn, args: [] };
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
