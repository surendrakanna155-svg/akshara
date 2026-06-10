import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAttendanceClasses,
  handleAttendanceStudents,
  handleDashboard,
  handleExamsMarks,
  handleExamsUpcoming,
  handleHomework,
  handleLeave,
  handleLeaveBalance,
  handleMessages,
  handleTimetable,
} from "./teacher_handlers.ts";

function matchTeacherRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method !== "GET") return null;

  const routes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
    "/teacher/dashboard": handleDashboard,
    "/teacher/attendance/classes": handleAttendanceClasses,
    "/teacher/attendance/students": handleAttendanceStudents,
    "/teacher/homework": handleHomework,
    "/teacher/exams/upcoming": handleExamsUpcoming,
    "/teacher/exams/marks": handleExamsMarks,
    "/teacher/timetable": handleTimetable,
    "/teacher/leave": handleLeave,
    "/teacher/leave/balance": handleLeaveBalance,
    "/teacher/messages": handleMessages,
  };

  const handler = routes[path];
  return handler ? { handler } : null;
}

export async function routeTeacher(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/teacher")) return null;

  const match = matchTeacherRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
