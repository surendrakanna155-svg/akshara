import type { AppConfig } from "../../config.ts";
import { errorEnvelope } from "../../http.ts";
import {
  handleBulkUpdateExamMarks,
  handleCreateExam,
  handleGetExam,
  handleListExamMarks,
  handleListExamRemarks,
  handleListExams,
  handleListPublishedResultsForStudent,
  handleMarksEntryProgress,
  handleOpenMarksEntry,
  handleProcessExamResults,
  handlePublishExamResults,
  handleScheduleExam,
  handleUpdateExamMark,
  handleUpsertExamRemark,
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

  // EXM-2 — marks-entry progress board. Matched BEFORE the generic
  // /academics/exams/{examId} GET so "progress" is not mistaken for an examId.
  if (path === "/academics/exams/progress" && method === "GET") {
    return { handler: handleMarksEntryProgress, args: [] };
  }

  // EXM-1 — fast bulk marks save for one exam.
  const bulkMarksMatch = path.match(
    /^\/academics\/exams\/([^/]+)\/marks\/batch$/,
  );
  if (bulkMarksMatch && method === "POST") {
    return { handler: handleBulkUpdateExamMarks, args: [bulkMarksMatch[1]!] };
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

  const remarkMatch = path.match(
    /^\/academics\/exams\/([^/]+)\/remarks\/([^/]+)$/,
  );
  if (remarkMatch && method === "PUT") {
    return {
      handler: handleUpsertExamRemark,
      args: [remarkMatch[1]!, remarkMatch[2]!],
    };
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
    { suffix: "/remarks", method: "GET", handler: handleListExamRemarks },
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
