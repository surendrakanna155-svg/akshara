import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAcknowledgeNotification,
  handleBroadcastHistory,
  handleBroadcastReport,
  handleCreateAudienceSegment,
  handleCreateBroadcast,
  handleCreateTemplate,
  handleDeleteAudienceSegment,
  handleDeliveryMetrics,
  handleDeliveryWebhook,
  handleGetChannelPolicy,
  handleListAudienceSegments,
  handleListTemplates,
  handleMarkAllNotificationsRead,
  handleMarkNotificationRead,
  handleParentMessageThreads,
  handleParentNotifications,
  handleParentSendMessage,
  handleProcessNotificationQueue,
  handleRegisterDeviceToken,
  handleResendBroadcast,
  handleRunScheduledBroadcasts,
  handleStudentNotifications,
  handleTeacherMessageThreads,
  handleTeacherSendMessage,
  handleUnregisterDeviceToken,
  handleUpdateTemplate,
  handleUpsertChannelPolicy,
} from "./communication_handlers.ts";
// WEB-010 (ERP-WT-010): the comms-analytics summary + parent-adoption reads
// already exist under the /school/communications/analytics/* prefix in the
// school_completion module (contract-tested, Flutter-wired). The web platform
// targets /communications/analytics/*; alias to the SAME certified handlers
// rather than duplicate the aggregation.
import {
  handleGetCommunicationAnalyticsSummary,
  handleGetParentAdoptionAnalytics,
} from "../school_completion/phase15_handlers.ts";

/** MJ-M12: matches `/communications/templates/{id}` — a single non-empty,
 * non-slash segment after the templates collection (excludes the bare
 * collection path and nested paths). */
const TEMPLATE_ITEM_PATH = /^\/communications\/templates\/[^/]+$/;

/** COM-1: matches `/communications/broadcasts/{id}/report` — captures the id. */
const BROADCAST_REPORT_PATH = /^\/communications\/broadcasts\/([^/]+)\/report$/;

/** COM-3: matches `/communications/broadcasts/{id}/resend` — captures the id. */
const BROADCAST_RESEND_PATH = /^\/communications\/broadcasts\/([^/]+)\/resend$/;

/** COM-D1: matches `/communications/notifications/{id}/acknowledge` — captures
 * the delivery id. */
const NOTIFICATION_ACK_PATH = /^\/communications\/notifications\/([^/]+)\/acknowledge$/;

/** COM-2: matches `/communications/audience-segments/{id}` — a single non-empty,
 * non-slash id segment (excludes the bare collection path). */
const AUDIENCE_SEGMENT_ITEM_PATH = /^\/communications\/audience-segments\/([^/]+)$/;

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
  // MJ-M12: edit a notification template (was 404 — the client issues
  // `PUT /communications/templates/{id}` but no route was registered; the mock
  // masked it). The id is parsed from the path inside the handler.
  if (method === "PUT" && TEMPLATE_ITEM_PATH.test(path)) {
    return { handler: handleUpdateTemplate };
  }
  // MJ-C6b: past-broadcast history (was 404). Must precede the create route so
  // the more-specific path matches first.
  if (method === "GET" && path === "/communications/broadcasts/history") {
    return { handler: handleBroadcastHistory };
  }
  // XCT-2: dispatch due scheduled broadcasts (cron/ops entry point). Exact-path
  // match, so order vs the create route is irrelevant, but keep it adjacent.
  if (method === "POST" && path === "/communications/broadcasts/run-scheduled") {
    return { handler: handleRunScheduledBroadcasts };
  }
  // COM-1: per-broadcast delivery & read report. Placed AFTER the static
  // /broadcasts/history + /broadcasts/run-scheduled checks and BEFORE the generic
  // POST /broadcasts create route so the more-specific parametrized path wins.
  const reportMatch = method === "GET" ? BROADCAST_REPORT_PATH.exec(path) : null;
  if (reportMatch) {
    const broadcastId = decodeURIComponent(reportMatch[1]);
    return { handler: (req, config) => handleBroadcastReport(req, config, broadcastId) };
  }
  // COM-3: resend a broadcast to its unread recipients.
  const resendMatch = method === "POST" ? BROADCAST_RESEND_PATH.exec(path) : null;
  if (resendMatch) {
    const broadcastId = decodeURIComponent(resendMatch[1]);
    return { handler: (req, config) => handleResendBroadcast(req, config, broadcastId) };
  }
  if (method === "POST" && path === "/communications/broadcasts") {
    return { handler: handleCreateBroadcast };
  }
  // COM-2: saved audience segments (static collection routes first, then the
  // parametrized DELETE below).
  if (method === "GET" && path === "/communications/audience-segments") {
    return { handler: handleListAudienceSegments };
  }
  if (method === "POST" && path === "/communications/audience-segments") {
    return { handler: handleCreateAudienceSegment };
  }
  const segmentDeleteMatch = method === "DELETE"
    ? AUDIENCE_SEGMENT_ITEM_PATH.exec(path)
    : null;
  if (segmentDeleteMatch) {
    const segmentId = decodeURIComponent(segmentDeleteMatch[1]);
    return { handler: (req, config) => handleDeleteAudienceSegment(req, config, segmentId) };
  }
  // COM-D1: acknowledge one of the caller's own deliveries (the signed receipt).
  // Placed before the static process-queue check since it's a distinct path; the
  // regex is anchored so it can't shadow /notifications/process-queue.
  const ackMatch = method === "POST" ? NOTIFICATION_ACK_PATH.exec(path) : null;
  if (ackMatch) {
    const deliveryId = decodeURIComponent(ackMatch[1]);
    return { handler: (req, config) => handleAcknowledgeNotification(req, config, deliveryId) };
  }
  if (method === "POST" && path === "/communications/notifications/process-queue") {
    return { handler: handleProcessNotificationQueue };
  }
  // Batch 6: per-school channel escalation policy (WhatsApp orchestrator).
  if (method === "GET" && path === "/communications/channel-policy") {
    return { handler: handleGetChannelPolicy };
  }
  if (method === "PUT" && path === "/communications/channel-policy") {
    return { handler: handleUpsertChannelPolicy };
  }
  if (method === "GET" && path === "/communications/delivery/metrics") {
    return { handler: handleDeliveryMetrics };
  }
  // WEB-010: web-platform aliases to the existing school_completion analytics.
  if (method === "GET" && path === "/communications/analytics/summary") {
    return { handler: handleGetCommunicationAnalyticsSummary };
  }
  if (method === "GET" && path === "/communications/analytics/parent-adoption") {
    return { handler: handleGetParentAdoptionAnalytics };
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
  // GAP-P1-7: the client posts to /parent/messages to send a reply (mirrors the
  // GET thread-list alias above); only /parent/messages/send was registered, so
  // a real parent->teacher reply 404'd silently. Alias both paths to the same
  // send handler.
  if (
    method === "POST" &&
    (path === "/parent/messages/send" || path === "/parent/messages")
  ) {
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
    return null;
  }
  return await match.handler(req, config);
}
