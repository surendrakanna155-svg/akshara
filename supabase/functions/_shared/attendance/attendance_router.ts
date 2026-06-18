import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
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
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config, ...match.args);
}
