import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleParentLeaveAttachment,
  handleParentLeaveCancel,
  handleParentLeaveSubmit,
  handleStudentHomeworkSubmit,
  handleTeacherAttendanceDraft,
  handleTeacherAttendanceSubmit,
  handleTeacherHomeworkBulkReview,
  handleTeacherHomeworkCreate,
  handleTeacherHomeworkHistory,
  handleTeacherHomeworkNonSubmitters,
  handleTeacherHomeworkNotifyNonSubmitters,
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
  // PAR-D1 — parent withdraws a PENDING leave for their own child. Matched
  // BEFORE the generic leave path is exhausted; the :id segment is url-decoded.
  const parentLeaveCancelMatch = path.match(/^\/parent\/leave\/([^/]+)\/cancel$/);
  if (method === "POST" && parentLeaveCancelMatch) {
    const leaveId = decodeURIComponent(parentLeaveCancelMatch[1]!);
    return { handler: (req, config) => handleParentLeaveCancel(req, config, leaveId) };
  }
  // PAR-3 — parent attaches a medical-certificate reference to a PENDING leave.
  const parentLeaveAttachmentMatch = path.match(
    /^\/parent\/leave\/([^/]+)\/attachment$/,
  );
  if (method === "POST" && parentLeaveAttachmentMatch) {
    const leaveId = decodeURIComponent(parentLeaveAttachmentMatch[1]!);
    return {
      handler: (req, config) => handleParentLeaveAttachment(req, config, leaveId),
    };
  }
  if (method === "POST" && path === "/student/homework/submit") {
    return { handler: handleStudentHomeworkSubmit };
  }
  if (method === "POST" && path === "/teacher/homework") {
    return { handler: handleTeacherHomeworkCreate };
  }

  // HWK-5 — homework history (static path; matched BEFORE the {homeworkId}
  // sub-routes so "history" is never mistaken for a homework id).
  if (method === "GET" && path === "/teacher/homework/history") {
    return { handler: handleTeacherHomeworkHistory };
  }
  // HWK-6 — bulk mark-reviewed (static path; before the review-by-submission
  // matcher, which requires a /submissions/ segment anyway).
  if (method === "POST" && path === "/teacher/homework/bulk-review") {
    return { handler: handleTeacherHomeworkBulkReview };
  }

  const reviewMatch = path.match(/^\/teacher\/homework\/submissions\/([^/]+)\/review$/);
  if (method === "POST" && reviewMatch) {
    const submissionId = decodeURIComponent(reviewMatch[1]!);
    return {
      handler: (req, config) => handleTeacherHomeworkReview(req, config, submissionId),
    };
  }

  // HWK-2 — not-submitted list for an assignment.
  const nonSubmittersMatch = path.match(
    /^\/teacher\/homework\/([^/]+)\/non-submitters$/,
  );
  if (method === "GET" && nonSubmittersMatch) {
    const homeworkId = decodeURIComponent(nonSubmittersMatch[1]!);
    return {
      handler: (req, config) =>
        handleTeacherHomeworkNonSubmitters(req, config, homeworkId),
    };
  }

  // HWK-D1 — manual teacher-triggered no-submit nudge to parents.
  const notifyMatch = path.match(
    /^\/teacher\/homework\/([^/]+)\/notify-non-submitters$/,
  );
  if (method === "POST" && notifyMatch) {
    const homeworkId = decodeURIComponent(notifyMatch[1]!);
    return {
      handler: (req, config) =>
        handleTeacherHomeworkNotifyNonSubmitters(req, config, homeworkId),
    };
  }

  // PRA-P0-12 (S0/T1a): the duplicate `PUT /teacher/exams/marks/:id` was removed
  // here. It shadowed the identical route in `teacher_router` (which app.ts
  // dispatches later) and reached an UNSCOPED handler — bypassing the certified
  // `isSubjectTeacherScoped`/`teacherTeachesExamSession` check. With this gone,
  // dispatch falls through to teacher_router → the governed `applyMarkUpdate`.
  // See `dispatch_uniqueness_test.ts` (S0/T1b) which now guards against reintroduction.

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
