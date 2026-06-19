import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAttendance,
  handleDashboard,
  handleExams,
  handleHomework,
  handleNotices,
  handleProfile,
  handleTimetable,
} from "./student_handlers.ts";

function matchStudentRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method !== "GET") return null;

  const routes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
    "/student/dashboard": handleDashboard,
    "/student/attendance": handleAttendance,
    "/student/homework": handleHomework,
    "/student/exams": handleExams,
    "/student/timetable": handleTimetable,
    "/student/notices": handleNotices,
    "/student/profile": handleProfile,
  };

  const handler = routes[path] as (typeof routes)[string] | undefined;
  return handler ? { handler } : null;
}

export async function routeStudent(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/student")) return null;

  const match = matchStudentRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
