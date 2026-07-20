import type { AppConfig } from "../../config.ts";
import { errorEnvelope } from "../../http.ts";
import {
  handleBulkUpdateExamMarks,
  handleCreateExam,
  handleDatesheet,
  handleExamDistribution,
  handleExamToppers,
  handleGenerateSeating,
  handleGetExam,
  handleGetSeating,
  handleGraceMark,
  handleHallTickets,
  handleListAdjustments,
  handleListExamMarks,
  handleListExamRemarks,
  handleListExams,
  handleListPublishedResultsForStudent,
  handleMarksEntryProgress,
  handleMeritList,
  handleOpenMarksEntry,
  handleRemindPendingMarks,
  handleProcessExamResults,
  handlePublishExamResults,
  handleUnpublishExamResults,
  handleReportCards,
  handleScheduleExam,
  handleTabulationRegister,
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
  // EXM-6 — remind teachers about marks-entry past deadline. Specific literal
  // before the generic /academics/exams/marks/{id} PATCH matcher (different verb).
  if (path === "/academics/exams/marks/remind" && method === "POST") {
    return { handler: handleRemindPendingMarks, args: [] };
  }

  // EXM-3/4b/7 — class + term scoped read reports. Matched BEFORE the generic
  // /academics/exams/{examId} GET so "class" is never mistaken for an examId.
  // The class label segment may contain a hyphen (e.g. "8-A") but not a slash.
  const tabulationMatch = path.match(
    /^\/academics\/exams\/class\/([^/]+)\/tabulation$/,
  );
  if (tabulationMatch && method === "GET") {
    return { handler: handleTabulationRegister, args: [tabulationMatch[1]!] };
  }
  const meritMatch = path.match(
    /^\/academics\/exams\/class\/([^/]+)\/merit$/,
  );
  if (meritMatch && method === "GET") {
    return { handler: handleMeritList, args: [meritMatch[1]!] };
  }
  const datesheetMatch = path.match(
    /^\/academics\/exams\/class\/([^/]+)\/datesheet$/,
  );
  if (datesheetMatch && method === "GET") {
    return { handler: handleDatesheet, args: [datesheetMatch[1]!] };
  }
  // EXM-D1 — batch report cards for a class + term (published results).
  const reportCardsMatch = path.match(
    /^\/academics\/exams\/class\/([^/]+)\/report-cards$/,
  );
  if (reportCardsMatch && method === "GET") {
    return { handler: handleReportCards, args: [reportCardsMatch[1]!] };
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

  // EXM-D2 — grace / moderation for one (exam, student).
  const graceMatch = path.match(
    /^\/academics\/exams\/([^/]+)\/students\/([^/]+)\/grace$/,
  );
  if (graceMatch && method === "POST") {
    return {
      handler: handleGraceMark,
      args: [graceMatch[1]!, graceMatch[2]!],
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
    // EXM-4a / EXM-5 — exam-scoped read reports.
    { suffix: "/toppers", method: "GET", handler: handleExamToppers },
    { suffix: "/distribution", method: "GET", handler: handleExamDistribution },
    // EXM-D2 — grace / moderation breakdown (coordinator-only read).
    { suffix: "/adjustments", method: "GET", handler: handleListAdjustments },
    // EXM-D4 — hall tickets (admit cards).
    { suffix: "/hall-tickets", method: "GET", handler: handleHallTickets },
    // EXM-D5 — seating: (re)generate + read. `/seating/generate` is a distinct
    // suffix from `/seating`, so both are matched unambiguously here.
    { suffix: "/seating/generate", method: "POST", handler: handleGenerateSeating },
    { suffix: "/seating", method: "GET", handler: handleGetSeating },
    { suffix: "/process", method: "POST", handler: handleProcessExamResults },
    {
      suffix: "/verify-coordinator",
      method: "POST",
      handler: handleVerifyCoordinator,
    },
    { suffix: "/publish", method: "POST", handler: handlePublishExamResults },
    // PRA-P1-12 — reopen a published exam for correction / re-evaluation.
    { suffix: "/unpublish", method: "POST", handler: handleUnpublishExamResults },
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
