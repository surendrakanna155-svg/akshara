import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleParentLeaveSubmit,
  handleStudentHomeworkSubmit,
  handleTeacherAttendanceDraft,
  handleTeacherAttendanceSubmit,
  handleTeacherExamMarkUpdate,
  handleTeacherHomeworkCreate,
  handleTeacherHomeworkReview,
  handleTeacherLeaveSubmit,
} from "./pilot_operations_handlers.ts";

function matchPilotRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method === "POST" && path === "/teacher/attendance/draft") {
    return { handler: handleTeacherAttendanceDraft };
  }
  if (method === "POST" && path === "/teacher/attendance/submit") {
    return { handler: handleTeacherAttendanceSubmit };
  }
  if (method === "POST" && path === "/teacher/leave") {
    return { handler: handleTeacherLeaveSubmit };
  }
  if (method === "POST" && path === "/parent/leave") {
    return { handler: handleParentLeaveSubmit };
  }
  if (method === "POST" && path === "/student/homework/submit") {
    return { handler: handleStudentHomeworkSubmit };
  }
  if (method === "POST" && path === "/teacher/homework") {
    return { handler: handleTeacherHomeworkCreate };
  }

  const reviewMatch = path.match(/^\/teacher\/homework\/submissions\/([^/]+)\/review$/);
  if (method === "POST" && reviewMatch) {
    const submissionId = decodeURIComponent(reviewMatch[1]!);
    return {
      handler: (req, config) => handleTeacherHomeworkReview(req, config, submissionId),
    };
  }

  const markMatch = path.match(/^\/teacher\/exams\/marks\/([^/]+)$/);
  if (method === "PUT" && markMatch) {
    const markEntryId = decodeURIComponent(markMatch[1]!);
    return {
      handler: (req, config) => handleTeacherExamMarkUpdate(req, config, markEntryId),
    };
  }

  return null;
}

export async function routePilotOperations(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  const match = matchPilotRoute(method, path);
  if (!match) {
    return null;
  }
  return await match.handler(req, config);
}
