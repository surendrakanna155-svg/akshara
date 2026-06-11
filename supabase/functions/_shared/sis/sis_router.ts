import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import { handleDashboard } from "./sis_dashboard_handlers.ts";
import { handleAdmissionsConversion } from "./sis_conversion_handlers.ts";
import {
  handleCreateEnrollment,
  handleListEnrollments,
  handleUpdateEnrollment,
} from "./sis_enrollment_handlers.ts";
import {
  handleCreateStudent,
  handleGetStudent,
  handleListStudents,
  handleUpdateStudent,
  handleUpdateStudentStatus,
} from "./sis_handlers.ts";
import {
  handleGetStudent360Profile,
  handleGetStudentTimeline,
} from "./sis_student_360_handlers.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function matchSisRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/sis/dashboard" && method === "GET") {
    return { handler: handleDashboard, args: [] };
  }

  if (path === "/sis/students" && method === "GET") {
    return { handler: handleListStudents, args: [] };
  }
  if (path === "/sis/students" && method === "POST") {
    return { handler: handleCreateStudent, args: [] };
  }

  if (path === "/sis/enrollments" && method === "GET") {
    return { handler: handleListEnrollments, args: [] };
  }
  if (path === "/sis/enrollments" && method === "POST") {
    return { handler: handleCreateEnrollment, args: [] };
  }

  if (path === "/sis/admissions-conversion" && method === "POST") {
    return { handler: handleAdmissionsConversion, args: [] };
  }

  const enrollmentMatch = path.match(/^\/sis\/enrollments\/([^/]+)$/);
  if (enrollmentMatch && method === "PUT") {
    return { handler: handleUpdateEnrollment, args: [enrollmentMatch[1]!] };
  }

  const statusMatch = path.match(/^\/sis\/students\/([^/]+)\/status$/);
  if (statusMatch && method === "PATCH") {
    return { handler: handleUpdateStudentStatus, args: [statusMatch[1]!] };
  }

  const profile360Match = path.match(/^\/sis\/students\/([^/]+)\/360$/);
  if (profile360Match && method === "GET" && UUID_SEGMENT.test(profile360Match[1]!)) {
    return { handler: handleGetStudent360Profile, args: [profile360Match[1]!] };
  }

  const timelineMatch = path.match(/^\/sis\/students\/([^/]+)\/timeline$/);
  if (timelineMatch && method === "GET" && UUID_SEGMENT.test(timelineMatch[1]!)) {
    return { handler: handleGetStudentTimeline, args: [timelineMatch[1]!] };
  }

  const studentMatch = path.match(/^\/sis\/students\/([^/]+)$/);
  if (studentMatch) {
    const studentId = studentMatch[1]!;
    if (method === "GET") {
      return { handler: handleGetStudent, args: [studentId] };
    }
    if (method === "PUT") {
      return { handler: handleUpdateStudent, args: [studentId] };
    }
  }

  return null;
}

export async function routeSis(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/sis")) return null;

  const match = matchSisRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  for (const arg of match.args) {
    if (arg.includes("-") && !UUID_SEGMENT.test(arg)) {
      // Allow non-UUID legacy mock ids in path for compatibility
    }
  }

  return await match.handler(req, config, ...match.args);
}
