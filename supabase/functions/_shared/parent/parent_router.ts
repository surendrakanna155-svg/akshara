import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleConfirmPayment,
  handleInitiatePayment,
} from "../payment/payment_handlers.ts";
import { handleParentCreateAttendanceCorrection } from "../attendance/attendance_handlers.ts";
import {
  handleParentAcknowledge,
  handleParentExperienceHub,
} from "./parent_experience_handlers.ts";
import {
  handleAttendance,
  handleDashboard,
  handleEvents,
  handleExams,
  handleFeeCertificate,
  handleFees,
  handleHomework,
  handleLeave,
  handleNotices,
  handlePaymentSummary,
  handleProfile,
  handleReceipts,
  handleTimetable,
} from "./parent_handlers.ts";
import {
  handleCommunicationInbox,
  handleCommunicationMessage,
  handleListMeetings,
  handleMeetingRsvp,
} from "./parent_write_handlers.ts";

type ParentHandler = (req: Request, config: AppConfig) => Promise<Response>;

export function matchParentRoute(
  method: string,
  path: string,
): { handler: ParentHandler } | null {
  if (method === "POST") {
    if (path === "/parent/payments/initiate") {
      return { handler: handleInitiatePayment };
    }
    if (path === "/parent/payments/confirm") {
      return { handler: handleConfirmPayment };
    }
    if (path === "/parent/experience/acknowledge") {
      return { handler: handleParentAcknowledge };
    }
    // MJ-H12 — POST /parent/leave is served by routePilotOperations (writes the
    // canonical mobile_leave_requests row that the school/HR approval side reads).
    // We do NOT re-register it here; instead GET /parent/leave now overlays those
    // real rows so the submitted leave is visible to the parent.
    // MJ-C4 — parent RSVPs to a PTM/meeting.
    const rsvpMatch = path.match(/^\/parent\/meetings\/([^/]+)\/rsvp$/);
    if (rsvpMatch) {
      const meetingId = decodeURIComponent(rsvpMatch[1]);
      return { handler: (req, config) => handleMeetingRsvp(req, config, meetingId) };
    }
    // MJ-M11/ATTEN-2 — parent submits an attendance correction for their own
    // child (parent-scoped; RLS restricts to student_guardians-linked children).
    if (path === "/parent/attendance/corrections") {
      return { handler: handleParentCreateAttendanceCorrection };
    }
    return null;
  }

  if (method !== "GET") return null;

  const staticRoutes: Record<string, ParentHandler> = {
    "/parent/dashboard": handleDashboard,
    "/parent/attendance": handleAttendance,
    "/parent/homework": handleHomework,
    "/parent/exams": handleExams,
    "/parent/timetable": handleTimetable,
    "/parent/fees": handleFees,
    "/parent/receipts": handleReceipts,
    // PAR-D3 — annual / 80C fee-payment certificate DATA for the parent's own
    // child (?academicYear=YYYY-YYYY or ?year=). Own-child scoped; PDF is
    // rendered client-side in a later wave.
    "/parent/fee-certificate": handleFeeCertificate,
    "/parent/notices": handleNotices,
    "/parent/events": handleEvents,
    "/parent/leave": handleLeave,
    "/parent/profile": handleProfile,
    "/parent/experience/hub": handleParentExperienceHub,
    // MJ-C3 — parent communication inbox.
    "/parent/communication/inbox": handleCommunicationInbox,
    // MJ-C4 — parent meetings / PTM list.
    "/parent/meetings": handleListMeetings,
  };

  const staticHandler = staticRoutes[path];
  if (staticHandler) {
    return { handler: staticHandler };
  }

  const paymentMatch = path.match(/^\/parent\/payments\/([^/]+)$/);
  if (paymentMatch) {
    const installmentId = decodeURIComponent(paymentMatch[1]);
    return {
      handler: (req, config) => handlePaymentSummary(req, config, installmentId),
    };
  }

  // MJ-C3 — single communication message by id. Kept LAST so it does not
  // shadow /parent/communication/inbox above.
  const commMatch = path.match(/^\/parent\/communication\/([^/]+)$/);
  if (commMatch && commMatch[1] !== "inbox") {
    const communicationId = decodeURIComponent(commMatch[1]);
    return {
      handler: (req, config) => handleCommunicationMessage(req, config, communicationId),
    };
  }

  return null;
}

export async function routeParent(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/parent")) return null;

  const match = matchParentRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
