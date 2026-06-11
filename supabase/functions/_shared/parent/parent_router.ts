import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleConfirmPayment,
  handleInitiatePayment,
} from "../payment/payment_handlers.ts";
import {
  handleParentAcknowledge,
  handleParentExperienceHub,
} from "./parent_experience_handlers.ts";
import {
  handleAttendance,
  handleDashboard,
  handleEvents,
  handleExams,
  handleFees,
  handleHomework,
  handleLeave,
  handleNotices,
  handlePaymentSummary,
  handleProfile,
  handleReceipts,
  handleTimetable,
} from "./parent_handlers.ts";

function matchParentRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
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
    return null;
  }

  if (method !== "GET") return null;

  const staticRoutes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
    "/parent/dashboard": handleDashboard,
    "/parent/attendance": handleAttendance,
    "/parent/homework": handleHomework,
    "/parent/exams": handleExams,
    "/parent/timetable": handleTimetable,
    "/parent/fees": handleFees,
    "/parent/receipts": handleReceipts,
    "/parent/notices": handleNotices,
    "/parent/events": handleEvents,
    "/parent/leave": handleLeave,
    "/parent/profile": handleProfile,
    "/parent/experience/hub": handleParentExperienceHub,
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
