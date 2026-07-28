import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAttendanceConsecutiveAbsence,
  handleAttendanceMonthlyRegister,
  handleAttendancePending,
  handleAttendanceRegister,
  handleAttendanceShortAttendance,
  handleCreateAttendanceCorrection,
  handleGetAttendanceCorrection,
  handleGetAttendanceSession,
  handleListAttendanceCorrections,
  handleListAttendanceSessions,
  handleUpdateAttendanceCorrectionStatus,
} from "./attendance_handlers.ts";

export function matchAttendanceRoute(
  method: string,
  path: string,
): {
  handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>;
  args: string[];
} | null {
  if (path === "/attendance/sessions" && method === "GET") {
    return { handler: handleListAttendanceSessions, args: [] };
  }

  // OFFICE / ADMIN reads (ATT-1, ATT-2, ATT-4, ATT-D1, ATT-D2). Exact-string
  // matches registered before the /attendance/sessions/:id parameterised route
  // so they can never be captured as a session id. All read-only (viewSis).
  // The monthly route is listed before the plain register route for clarity;
  // both are exact-string matches so order between them is not significant.
  if (path === "/attendance/register/monthly" && method === "GET") {
    return { handler: handleAttendanceMonthlyRegister, args: [] };
  }
  if (path === "/attendance/register" && method === "GET") {
    return { handler: handleAttendanceRegister, args: [] };
  }
  if (path === "/attendance/pending" && method === "GET") {
    return { handler: handleAttendancePending, args: [] };
  }
  if (path === "/attendance/alerts/consecutive-absence" && method === "GET") {
    return { handler: handleAttendanceConsecutiveAbsence, args: [] };
  }
  if (path === "/attendance/alerts/short-attendance" && method === "GET") {
    return { handler: handleAttendanceShortAttendance, args: [] };
  }

  if (path === "/attendance/corrections" && method === "GET") {
    return { handler: handleListAttendanceCorrections, args: [] };
  }
  if (path === "/attendance/corrections" && method === "POST") {
    return { handler: handleCreateAttendanceCorrection, args: [] };
  }

  const sessionMatch = path.match(/^\/attendance\/sessions\/([^/]+)$/);
  if (sessionMatch && method === "GET") {
    return { handler: handleGetAttendanceSession, args: [sessionMatch[1]!] };
  }

  const correctionStatusMatch = path.match(
    /^\/attendance\/corrections\/([^/]+)\/status$/,
  );
  if (correctionStatusMatch && method === "PATCH") {
    return {
      handler: handleUpdateAttendanceCorrectionStatus,
      args: [correctionStatusMatch[1]!],
    };
  }

  const correctionMatch = path.match(/^\/attendance\/corrections\/([^/]+)$/);
  if (correctionMatch && method === "GET") {
    return { handler: handleGetAttendanceCorrection, args: [correctionMatch[1]!] };
  }

  return null;
}

export async function routeAttendance(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/attendance")) return null;

  const match = matchAttendanceRoute(method, path);
  if (!match) {
    return null;
  }

  return await match.handler(req, config, ...match.args);
}
