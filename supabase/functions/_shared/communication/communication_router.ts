import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleBroadcastHistory,
  handleCreateBroadcast,
  handleCreateTemplate,
  handleDeliveryMetrics,
  handleDeliveryWebhook,
  handleListTemplates,
  handleMarkAllNotificationsRead,
  handleMarkNotificationRead,
  handleParentMessageThreads,
  handleParentNotifications,
  handleParentSendMessage,
  handleProcessNotificationQueue,
  handleRegisterDeviceToken,
  handleStudentNotifications,
  handleTeacherMessageThreads,
  handleTeacherSendMessage,
  handleUnregisterDeviceToken,
} from "./communication_handlers.ts";

/** Exported for path-parity tests: pure method+path → handler resolution with
 * no auth/DB side effects. */
export function matchCommunicationRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method === "GET" && path === "/communications/templates") {
    return { handler: handleListTemplates };
  }
  // MJ-C6a: create a notification template (was 404 — only GET existed).
  if (method === "POST" && path === "/communications/templates") {
    return { handler: handleCreateTemplate };
  }
  // MJ-C6b: past-broadcast history (was 404). Must precede the create route so
  // the more-specific path matches first.
  if (method === "GET" && path === "/communications/broadcasts/history") {
    return { handler: handleBroadcastHistory };
  }
  if (method === "POST" && path === "/communications/broadcasts") {
    return { handler: handleCreateBroadcast };
  }
  if (method === "POST" && path === "/communications/notifications/process-queue") {
    return { handler: handleProcessNotificationQueue };
  }
  if (method === "GET" && path === "/communications/delivery/metrics") {
    return { handler: handleDeliveryMetrics };
  }
  if (method === "POST" && path === "/communications/delivery/webhook") {
    return { handler: handleDeliveryWebhook };
  }
  if (method === "GET" && path === "/parent/notifications") {
    return { handler: handleParentNotifications };
  }
  if (method === "POST" && path === "/parent/notifications/mark-read") {
    return { handler: handleMarkNotificationRead };
  }
  if (method === "POST" && path === "/parent/notifications/mark-all-read") {
    return { handler: handleMarkAllNotificationsRead };
  }
  if (method === "POST" && path === "/parent/device-tokens/register") {
    return { handler: handleRegisterDeviceToken };
  }
  if (method === "POST" && path === "/parent/device-tokens/unregister") {
    return { handler: handleUnregisterDeviceToken };
  }
  // MJ-C3: the client calls /parent/messages; alias it to the thread list so it
  // no longer 404s (only /parent/messages/threads was registered).
  if (
    method === "GET" &&
    (path === "/parent/messages/threads" || path === "/parent/messages")
  ) {
    return { handler: handleParentMessageThreads };
  }
  if (method === "POST" && path === "/parent/messages/send") {
    return { handler: handleParentSendMessage };
  }
  if (method === "GET" && path === "/student/notifications") {
    return { handler: handleStudentNotifications };
  }
  if (method === "POST" && path === "/student/notifications/mark-read") {
    return { handler: handleMarkNotificationRead };
  }
  if (method === "POST" && path === "/student/notifications/mark-all-read") {
    return { handler: handleMarkAllNotificationsRead };
  }
  if (method === "POST" && path === "/student/device-tokens/register") {
    return { handler: handleRegisterDeviceToken };
  }
  if (method === "POST" && path === "/student/device-tokens/unregister") {
    return { handler: handleUnregisterDeviceToken };
  }
  if (method === "GET" && (path === "/teacher/messages/threads" || path === "/teacher/messages")) {
    return { handler: handleTeacherMessageThreads };
  }
  if (method === "POST" && (path === "/teacher/messages/send" || path === "/teacher/messages")) {
    return { handler: handleTeacherSendMessage };
  }
  return null;
}

export async function routeCommunication(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  const commPaths = [
    "/communications/",
    "/parent/notifications",
    "/parent/device-tokens/",
    "/parent/messages/",
    "/student/notifications",
    "/student/device-tokens/",
    "/teacher/messages",
  ];
  if (!commPaths.some((prefix) => path.startsWith(prefix) || path === prefix.replace(/\/$/, ""))) {
    return null;
  }

  const match = matchCommunicationRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }
  return await match.handler(req, config);
}
