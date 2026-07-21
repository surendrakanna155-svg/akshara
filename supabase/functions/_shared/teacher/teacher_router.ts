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
  handleTimetable,
} from "./teacher_handlers.ts";
// MJ-C5: the teacher exam workflow reuses the certified exam-administration
// engine (real marks/process/publish logic + its own RBAC + tenant context).
// The teacher app calls these under /teacher/exams/* ; we delegate so we never
// reimplement (or drift from) the published results pipeline.
import {
  handleListExams,
  handleProcessExamResults,
  handlePublishExamResults,
  handleUpdateExamMark,
} from "../academics/exam_administration/exam_administration_handlers.ts";
// MJ-H13: teacher parent-communication + subject-concern writes/reads.
import {
  handleDismissSubjectConcern,
  handleFlagSubjectConcern,
  handleListParentCommunications,
  handleListPendingConcerns,
  handleSendParentCommunication,
} from "./teacher_parent_communication_handlers.ts";

type TeacherHandler = (req: Request, config: AppConfig) => Promise<Response>;

function matchTeacherRoute(method: string, path: string): { handler: TeacherHandler } | null {
  // --- MJ-C5: exam workflow (delegated to the exam-administration engine) ---
  if (method === "GET" && path === "/teacher/exams/marks-entry") {
    // List the exam sessions a teacher can enter marks for; the client wraps
    // each item raw, so the academics list envelope is the right shape.
    return { handler: (req, config) => handleListExams(req, config) };
  }
  const examMarkMatch = path.match(/^\/teacher\/exams\/marks\/([^/]+)$/);
  if (examMarkMatch && method === "PUT") {
    const markEntryId = decodeURIComponent(examMarkMatch[1]!);
    return { handler: (req, config) => handleUpdateExamMark(req, config, markEntryId) };
  }
  const examProcessMatch = path.match(/^\/teacher\/exams\/([^/]+)\/process$/);
  if (examProcessMatch && method === "POST") {
    const examId = decodeURIComponent(examProcessMatch[1]!);
    return { handler: (req, config) => handleProcessExamResults(req, config, examId) };
  }
  const examPublishMatch = path.match(/^\/teacher\/exams\/([^/]+)\/publish$/);
  if (examPublishMatch && method === "POST") {
    const examId = decodeURIComponent(examPublishMatch[1]!);
    return { handler: (req, config) => handlePublishExamResults(req, config, examId) };
  }

  // --- MJ-H13: parent communication + subject concerns ---
  if (path === "/teacher/parent-communication" && method === "POST") {
    return { handler: handleSendParentCommunication };
  }
  if (path === "/teacher/parent-communication" && method === "GET") {
    return { handler: handleListParentCommunications };
  }
  if (path === "/teacher/parent-communication/concerns") {
    if (method === "POST") return { handler: handleFlagSubjectConcern };
    if (method === "GET") return { handler: handleListPendingConcerns };
  }
  const concernDismissMatch = path.match(
    /^\/teacher\/parent-communication\/concerns\/([^/]+)\/dismiss$/,
  );
  if (concernDismissMatch && method === "POST") {
    const concernId = decodeURIComponent(concernDismissMatch[1]!);
    return { handler: (req, config) => handleDismissSubjectConcern(req, config, concernId) };
  }

  // --- existing GET read surfaces ---
  if (method !== "GET") return null;

  const routes: Record<string, TeacherHandler> = {
    "/teacher/dashboard": handleDashboard,
    "/teacher/attendance/classes": handleAttendanceClasses,
    "/teacher/attendance/students": handleAttendanceStudents,
    "/teacher/homework": handleHomework,
    "/teacher/exams/upcoming": handleExamsUpcoming,
    "/teacher/exams/marks": handleExamsMarks,
    "/teacher/timetable": handleTimetable,
    "/teacher/leave": handleLeave,
    "/teacher/leave/balance": handleLeaveBalance,
    // PRA-N-13 (S0/T1a): "/teacher/messages" removed — owned by routeCommunication
    // (dispatched first) via the governed handleTeacherMessageThreads.
  };

  const handler = routes[path] as TeacherHandler | undefined;
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
    return null;
  }

  return await match.handler(req, config);
}
