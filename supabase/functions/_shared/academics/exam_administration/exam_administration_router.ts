import type { AppConfig } from "../../config.ts";
import { errorEnvelope } from "../../http.ts";
import {
  handleCreateExam,
  handleGetExam,
  handleListExamMarks,
  handleListExams,
  handleListPublishedResultsForStudent,
  handleOpenMarksEntry,
  handleProcessExamResults,
  handlePublishExamResults,
  handleScheduleExam,
  handleUpdateExamMark,
  handleVerifyCoordinator,
} from "./exam_administration_handlers.ts";

export function matchExamAdministrationRoute(
  method: string,
  path: string,
): {
  handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>;
  args: string[];
} | null {
  if (path === "/academics/exams" && method === "GET") {
    return { handler: handleListExams, args: [] };
  }
  if (path === "/academics/exams" && method === "POST") {
    return { handler: handleCreateExam, args: [] };
  }

  const publishedStudentMatch = path.match(
    /^\/academics\/exams\/students\/([^/]+)\/published$/,
  );
  if (publishedStudentMatch && method === "GET") {
    return {
      handler: handleListPublishedResultsForStudent,
      args: [publishedStudentMatch[1]!],
    };
  }

  const markMatch = path.match(/^\/academics\/exams\/marks\/([^/]+)$/);
  if (markMatch && method === "PATCH") {
    return { handler: handleUpdateExamMark, args: [markMatch[1]!] };
  }

  const examMatch = path.match(/^\/academics\/exams\/([^/]+)$/);
  if (examMatch && method === "GET") {
    return { handler: handleGetExam, args: [examMatch[1]!] };
  }

  const actionMatchers: Array<{
    suffix: string;
    method: string;
    handler: (req: Request, config: AppConfig, examId: string) => Promise<Response>;
  }> = [
    { suffix: "/schedule", method: "POST", handler: handleScheduleExam },
    { suffix: "/open-marks", method: "POST", handler: handleOpenMarksEntry },
    { suffix: "/marks", method: "GET", handler: handleListExamMarks },
    { suffix: "/process", method: "POST", handler: handleProcessExamResults },
    {
      suffix: "/verify-coordinator",
      method: "POST",
      handler: handleVerifyCoordinator,
    },
    { suffix: "/publish", method: "POST", handler: handlePublishExamResults },
  ];

  for (const { suffix, method: allowed, handler } of actionMatchers) {
    if (!path.endsWith(suffix) || method !== allowed) continue;
    const examId = path.slice("/academics/exams/".length, path.length - suffix.length);
    if (!examId || examId.includes("/")) continue;
    return { handler, args: [examId] };
  }

  return null;
}

export async function routeExamAdministration(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/academics/exams")) return null;

  const match = matchExamAdministrationRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config, ...match.args);
}
