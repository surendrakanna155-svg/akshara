import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { createServiceClient } from "../db.ts";
import {
  correlationIdFromRequest,
  recordMutationAudit,
} from "../audit/audit_repository.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  CommunicationValidationError,
  createNotificationTemplate,
  listBroadcastHistoryEntries,
  listNotificationTemplates,
  listUserMessageThreads,
  listUserNotifications,
  runDueScheduledBroadcasts,
  scheduleBroadcastMessage,
  sendBroadcastMessage,
  sendDirectMessage,
  updateNotificationTemplate,
} from "./communication_service.ts";
import { getNotificationDeliveryMetrics } from "./communication_repository.ts";
import { processDeliveryQueue } from "./notification_service.ts";
import {
  loadCommunicationWebhookConfig,
  verifyCommunicationWebhookSignature,
} from "./communication_webhook_auth.ts";

/** Inline mutation-audit helper for communication writes (module-local style,
 * mirroring communication_service.ts which calls recordMutationAudit directly). */
async function auditComm(
  db: Parameters<typeof recordMutationAudit>[0],
  claims: AccessTokenClaims,
  eventType: string,
  domainEventType: string,
  entityType: string,
  entityId: string,
  metadata: Record<string, unknown>,
  req: Request,
): Promise<void> {
  const correlationId = correlationIdFromRequest(req);
  await recordMutationAudit(
    db,
    claims,
    { eventType, category: "workflow", entityType, entityId, metadata, correlationId },
    {
      eventType: domainEventType,
      payload: { entityId, ...metadata },
      sourceModule: "communication",
      idempotencyKey: `${domainEventType}:${entityId}:${Date.now()}`,
      correlationId,
    },
    req,
  );
}

/** PERF-1: cap on how many delivery batches one async drain pass will process,
 * so a background task can never loop unbounded. Each batch is itself capped by
 * fetchPendingDeliveries' LIMIT. */
const MAX_DRAIN_BATCHES = 200;

/**
 * PERF-1: drain the notification queue OUTSIDE the request/response cycle.
 * `sendBroadcastMessage` now only enqueues ('pending') deliveries; this opens a
 * fresh tenant context (the request's connection is already closed by the time
 * a background task runs) and sends them in bounded batches until the queue is
 * empty. Errors are swallowed — deliveries persist and are retried on the next
 * drain. When the edge runtime exposes `EdgeRuntime.waitUntil` the work runs
 * after the response is returned; otherwise (local/test) the caller awaits it so
 * delivery still happens within the request.
 */
async function drainNotificationQueue(
  config: AppConfig,
  claims: AccessTokenClaims,
): Promise<void> {
  const orgId = organizationIdFromClaims(claims);
  for (let batch = 0; batch < MAX_DRAIN_BATCHES; batch++) {
    const result = await withTenantContext(config, claims, (db) =>
      processDeliveryQueue(db, orgId, claims)
    );
    if (result.processed === 0) break;
  }
}

/** Schedule {@link drainNotificationQueue} off the request path when the edge
 * runtime supports it; otherwise return the promise for the caller to await. */
function scheduleNotificationDrain(
  config: AppConfig,
  claims: AccessTokenClaims,
): Promise<void> {
  const edge = (globalThis as {
    EdgeRuntime?: { waitUntil(promise: Promise<unknown>): void };
  }).EdgeRuntime;
  const task = drainNotificationQueue(config, claims).catch(() => {});
  if (edge?.waitUntil) {
    edge.waitUntil(task);
    return Promise.resolve();
  }
  return task;
}

function snakeStr(body: Record<string, unknown>, key: string): string {
  return String(body[key] ?? "");
}

function optionalSnakeStr(body: Record<string, unknown>, key: string): string | undefined {
  const value = body[key];
  return value == null ? undefined : String(value);
}

export async function handleListTemplates(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewCommunications");
  if (denied) return denied;

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listNotificationTemplates(db, auth.claims)
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load templates", 500);
  }
}

/**
 * MJ-C6a: POST /communications/templates — create a notification template.
 * Enforces the same permission/scope gate as {@link handleCreateBroadcast}
 * (the "sendBroadcast" permission; school/organization scope checked in the
 * service), persists into the same `notification_templates` store
 * {@link handleListTemplates} reads from, and audits the write.
 */
export async function handleCreateTemplate(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "sendBroadcast");
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  try {
    const template = await withTenantContext(config, auth.claims, async (db) =>
      await createNotificationTemplate(
        db,
        auth.claims,
        {
          code: snakeStr(body, "code"),
          channel: snakeStr(body, "channel"),
          subjectTemplate: optionalSnakeStr(body, "subject_template"),
          bodyTemplate: snakeStr(body, "body_template"),
          variables: body["variables"],
        },
        req,
      )
    );
    return jsonResponse(envelope(template), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof CommunicationValidationError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to create template", 500);
  }
}

/**
 * MJ-M12: PUT /communications/templates/:id — update a notification template.
 * Closes the client↔router path-parity gap where the Flutter client issued
 * `PUT /communications/templates/{id}` but no route was registered (the call
 * 404'd live while the mock masked it). Same permission/scope gate as
 * {@link handleCreateTemplate}; persists into the same `notification_templates`
 * store; audits the write. The template id is parsed from the request path.
 */
export async function handleUpdateTemplate(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "sendBroadcast");
  if (denied) return denied;

  const pathParts = new URL(req.url).pathname.split("/");
  const templateId = pathParts[pathParts.length - 1] ?? "";
  if (!templateId) {
    return errorEnvelope("VALIDATION_ERROR", "Template id is required", 422);
  }

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  try {
    const template = await withTenantContext(config, auth.claims, async (db) =>
      await updateNotificationTemplate(
        db,
        auth.claims,
        templateId,
        {
          code: "code" in body ? snakeStr(body, "code") : undefined,
          channel: "channel" in body ? snakeStr(body, "channel") : undefined,
          subjectTemplate: "subject_template" in body
            ? optionalSnakeStr(body, "subject_template")
            : undefined,
          bodyTemplate: "body_template" in body
            ? snakeStr(body, "body_template")
            : undefined,
          variables: "variables" in body ? body["variables"] : undefined,
        },
        req,
      )
    );
    return jsonResponse(envelope(template));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof CommunicationValidationError) {
      const status = error.message === "Template not found" ? 404 : 422;
      const code = status === 404 ? "NOT_FOUND" : "VALIDATION_ERROR";
      return errorEnvelope(code, error.message, status);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to update template", 500);
  }
}

/**
 * MJ-C6b: GET /communications/broadcasts/history — list past broadcasts from
 * the same `comm_broadcasts` store {@link handleCreateBroadcast} writes to.
 * Real persisted rows only; an empty list when none exist.
 */
export async function handleBroadcastHistory(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "sendBroadcast");
  if (denied) return denied;

  const { limit, offset } = paginationFromRequest(req);

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listBroadcastHistoryEntries(db, auth.claims, limit, offset)
    );
    return jsonResponse(envelope({ items, limit, offset }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof CommunicationValidationError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load broadcast history", 500);
  }
}

export async function handleCreateBroadcast(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "sendBroadcast");
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  const scheduledAt = optionalSnakeStr(body, "scheduledAt") ??
    optionalSnakeStr(body, "scheduled_at");

  try {
    // XCT-2 / COM-4: when a scheduledAt is supplied, persist the broadcast in the
    // 'scheduled' state instead of sending now — the runner dispatches it when its
    // time arrives (recipients resolved at dispatch, not authoring, time).
    if (scheduledAt && scheduledAt.trim() !== "") {
      const scheduled = await withTenantContext(config, auth.claims, async (db) =>
        await scheduleBroadcastMessage(
          db,
          auth.claims,
          {
            audience: snakeStr(body, "audience"),
            title: snakeStr(body, "title"),
            body: snakeStr(body, "body"),
            scheduledAt,
          },
          req,
        )
      );
      return jsonResponse(envelope(scheduled), { status: 201 });
    }

    const result = await withTenantContext(config, auth.claims, async (db) =>
      await sendBroadcastMessage(
        db,
        auth.claims,
        {
          audience: snakeStr(body, "audience"),
          title: snakeStr(body, "title"),
          body: snakeStr(body, "body"),
        },
        req,
      )
    );
    // PERF-1: send the queued deliveries out of the synchronous request.
    await scheduleNotificationDrain(config, auth.claims);
    return jsonResponse(envelope(result), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof CommunicationValidationError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to send broadcast", 500);
  }
}

/**
 * XCT-2: POST /communications/broadcasts/run-scheduled — dispatch every
 * scheduled broadcast whose time has arrived for the caller's org. Gated by the
 * `manageCommunications` ops permission (same as the delivery-queue processor).
 * Idempotent; the periodic trigger (cron) that calls it is a deployment concern.
 */
export async function handleRunScheduledBroadcasts(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageCommunications");
  if (denied) return denied;

  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await runDueScheduledBroadcasts(db, auth.claims, req)
    );
    // Push the freshly-enqueued deliveries out of the synchronous request.
    await scheduleNotificationDrain(config, auth.claims);
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof CommunicationValidationError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to run scheduled broadcasts", 500);
  }
}

export async function handleProcessNotificationQueue(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageCommunications");
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await processDeliveryQueue(db, orgId, auth.claims, req)
    );
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to process queue", 500);
  }
}

function paginationFromRequest(req: Request): { limit: number; offset: number } {
  const url = new URL(req.url);
  const limit = Math.min(Math.max(parseInt(url.searchParams.get("limit") ?? "50", 10) || 50, 1), 100);
  const offset = Math.max(parseInt(url.searchParams.get("offset") ?? "0", 10) || 0, 0);
  return { limit, offset };
}

export async function handleParentNotifications(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "parent") {
    return errorEnvelope("FORBIDDEN", "Parent scope required", 403);
  }

  const { limit, offset } = paginationFromRequest(req);

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listUserNotifications(db, auth.claims, limit, offset)
    );
    return jsonResponse(envelope({ items, limit, offset }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load notifications", 500);
  }
}

export async function handleStudentNotifications(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "student") {
    return errorEnvelope("FORBIDDEN", "Student scope required", 403);
  }

  const { limit, offset } = paginationFromRequest(req);

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listUserNotifications(db, auth.claims, limit, offset)
    );
    return jsonResponse(envelope({ items, limit, offset }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load notifications", 500);
  }
}

export async function handleParentMessageThreads(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "parent") {
    return errorEnvelope("FORBIDDEN", "Parent scope required", 403);
  }

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listUserMessageThreads(db, auth.claims, "parent")
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load message threads", 500);
  }
}

export async function handleParentSendMessage(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "parent") {
    return errorEnvelope("FORBIDDEN", "Parent scope required", 403);
  }

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  try {
    const thread = await withTenantContext(config, auth.claims, async (db) =>
      await sendDirectMessage(
        db,
        auth.claims,
        {
          threadId: optionalSnakeStr(body, "thread_id"),
          subject: optionalSnakeStr(body, "subject"),
          body: snakeStr(body, "body"),
          senderRole: "parent",
          counterpartyUserId: optionalSnakeStr(body, "teacher_user_id"),
        },
        req,
      )
    );
    return jsonResponse(envelope(thread), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof CommunicationValidationError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to send message", 500);
  }
}

export async function handleTeacherSendMessage(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school") {
    return errorEnvelope("FORBIDDEN", "Teacher/school scope required", 403);
  }

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  try {
    const thread = await withTenantContext(config, auth.claims, async (db) =>
      await sendDirectMessage(
        db,
        auth.claims,
        {
          threadId: optionalSnakeStr(body, "thread_id"),
          recipient: optionalSnakeStr(body, "recipient"),
          subject: optionalSnakeStr(body, "subject"),
          body: snakeStr(body, "body"),
          senderRole: "teacher",
          counterpartyUserId: optionalSnakeStr(body, "parent_user_id"),
        },
        req,
      )
    );
    return jsonResponse(envelope(thread), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof CommunicationValidationError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to send message", 500);
  }
}

export async function handleTeacherMessageThreads(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (auth.claims.scope !== "school") {
    return errorEnvelope("FORBIDDEN", "Teacher/school scope required", 403);
  }

  try {
    const items = await withTenantContext(config, auth.claims, async (db) =>
      await listUserMessageThreads(db, auth.claims, "school")
    );
    return jsonResponse(envelope({ items }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load message threads", 500);
  }
}

export async function handleMarkNotificationRead(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (!["parent", "student", "school"].includes(auth.claims.scope)) {
    return errorEnvelope("FORBIDDEN", "Mobile scope required", 403);
  }

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  const notificationId = snakeStr(body, "notification_id") || snakeStr(body, "notificationId");
  if (!notificationId) {
    return errorEnvelope("VALIDATION_ERROR", "notification_id is required", 422);
  }

  try {
    const { markNotificationRead } = await import("./communication_repository.ts");
    const updated = await withTenantContext(config, auth.claims, async (db) => {
      const ok = await markNotificationRead(db, auth.claims.tenant_id, auth.claims.sub, notificationId);
      if (ok) {
        await auditComm(db, auth.claims, "notificationRead", "communication.notification.read",
          "notification_delivery", notificationId, {}, req);
      }
      return ok;
    });
    if (!updated) {
      return errorEnvelope("NOT_FOUND", "Notification not found", 404);
    }
    return jsonResponse(envelope({ notificationId, isRead: true }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to mark notification read", 500);
  }
}

export async function handleMarkAllNotificationsRead(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (!["parent", "student", "school"].includes(auth.claims.scope)) {
    return errorEnvelope("FORBIDDEN", "Mobile scope required", 403);
  }

  try {
    const { markAllNotificationsRead } = await import("./communication_repository.ts");
    const count = await withTenantContext(config, auth.claims, async (db) => {
      const c = await markAllNotificationsRead(db, auth.claims.tenant_id, auth.claims.sub);
      if (c > 0) {
        await auditComm(db, auth.claims, "notificationsAllRead", "communication.notification.all_read",
          "notification_delivery", auth.claims.sub, { markedCount: c }, req);
      }
      return c;
    });
    return jsonResponse(envelope({ markedCount: count }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to mark notifications read", 500);
  }
}

export async function handleRegisterDeviceToken(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (!["parent", "student", "school"].includes(auth.claims.scope)) {
    return errorEnvelope("FORBIDDEN", "Mobile scope required", 403);
  }

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  const token = snakeStr(body, "token");
  const platform = snakeStr(body, "platform") || "android";
  if (!token) {
    return errorEnvelope("VALIDATION_ERROR", "token is required", 422);
  }

  try {
    const { registerDeviceToken } = await import("./communication_repository.ts");
    await withTenantContext(config, auth.claims, async (db) => {
      await registerDeviceToken(db, auth.claims.tenant_id, auth.claims.sub, platform, token);
      await auditComm(db, auth.claims, "deviceTokenRegistered", "communication.device_token.registered",
        "comm_device_token", auth.claims.sub, { platform }, req);
    });
    return jsonResponse(envelope({ registered: true, platform }), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to register device token", 500);
  }
}

export async function handleUnregisterDeviceToken(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  if (!["parent", "student", "school"].includes(auth.claims.scope)) {
    return errorEnvelope("FORBIDDEN", "Mobile scope required", 403);
  }

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  const token = snakeStr(body, "token");
  if (!token) {
    return errorEnvelope("VALIDATION_ERROR", "token is required", 422);
  }

  try {
    const { unregisterDeviceToken } = await import("./communication_repository.ts");
    await withTenantContext(config, auth.claims, async (db) => {
      await unregisterDeviceToken(db, auth.claims.tenant_id, auth.claims.sub, token);
      await auditComm(db, auth.claims, "deviceTokenUnregistered", "communication.device_token.unregistered",
        "comm_device_token", auth.claims.sub, {}, req);
    });
    return jsonResponse(envelope({ unregistered: true }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to unregister device token", 500);
  }
}

export async function handleDeliveryMetrics(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewAdminHub");
  if (denied) return denied;

  const schoolId = auth.claims.school_id;
  if (!schoolId) {
    return errorEnvelope("VALIDATION_ERROR", "School scope required", 422);
  }

  try {
    const metrics = await withTenantContext(config, auth.claims, async (db) =>
      await getNotificationDeliveryMetrics(db, organizationIdFromClaims(auth.claims), schoolId)
    );
    return jsonResponse(envelope(metrics));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load delivery metrics", 500);
  }
}

/**
 * External provider webhook — confirms delivery status (v15.6).
 *
 * SEC-1 (Wave 3): authenticated with a shared-secret HMAC over the raw body
 * (`x-akshara-signature`). The tenant is derived from the matched delivery row
 * via the service client (never from the payload, never hardcoded), then the
 * status update runs under that row's own school scope so RLS still applies.
 */
export async function handleDeliveryWebhook(req: Request, config: AppConfig): Promise<Response> {
  const rawBody = await req.text();

  const webhookConfig = loadCommunicationWebhookConfig();
  const signature = req.headers.get("x-akshara-signature");
  const valid = await verifyCommunicationWebhookSignature(webhookConfig, rawBody, signature);
  if (!valid) {
    return errorEnvelope("UNAUTHORIZED", "Invalid webhook signature", 401);
  }

  let body: { deliveryId?: string; status?: string; externalId?: string };
  try {
    body = rawBody ? JSON.parse(rawBody) : {};
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid webhook JSON", 422);
  }
  if (!body.deliveryId && !body.externalId) {
    return errorEnvelope("VALIDATION_ERROR", "deliveryId or externalId required", 422);
  }

  const status = (body.status ?? "delivered").toLowerCase();
  if (!["delivered", "failed", "pending"].includes(status)) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid status", 422);
  }

  try {
    // Derive the tenant from the delivery row (service client bypasses RLS for
    // this read only — the actual write below runs under the row's school scope).
    const serviceClient = createServiceClient(config);
    const lookup = body.deliveryId
      ? await serviceClient
        .from("notification_deliveries")
        .select("id,organization_id,school_id")
        .eq("id", body.deliveryId)
        .maybeSingle()
      : await serviceClient
        .from("notification_deliveries")
        .select("id,organization_id,school_id")
        .eq("external_id", body.externalId!)
        .maybeSingle();

    const row = lookup.data as
      | { id: string; organization_id: string; school_id: string | null }
      | null;
    if (!row?.organization_id || !row?.school_id) {
      return errorEnvelope("NOT_FOUND", "Delivery record not found", 404);
    }

    const tenantClaims: AccessTokenClaims = {
      sub: "00000000-0000-4000-8000-000000000000",
      tenant_id: row.organization_id,
      organization_id: row.organization_id,
      school_id: row.school_id,
      role: "schoolAdmin",
      role_slugs: ["schoolAdmin"],
      primary_role: "schoolAdmin",
      permissions: ["viewCommunications"],
      permissions_version: 1,
      scope: "school",
      school_group_id: null,
      student_id: null,
      child_ids: [],
      session_id: "delivery-webhook",
    };

    const updated = await withTenantContext(config, tenantClaims, async (db) => {
      const rows = await db.queryObject<{ id: string }>(
        `UPDATE notification_deliveries
            SET status = $2,
                delivered_at = CASE WHEN $2 = 'delivered' THEN now() ELSE delivered_at END,
                updated_at = now()
          WHERE id = $1::uuid
          RETURNING id`,
        [row.id, status],
      );
      const id = rows[0]?.id ?? null;
      if (id) {
        await auditComm(db, tenantClaims, "deliveryConfirmed", "communication.delivery.confirmed",
          "notification_delivery", id, { status }, req);
      }
      return id;
    });
    if (!updated) return errorEnvelope("NOT_FOUND", "Delivery record not found", 404);
    return jsonResponse(envelope({ deliveryId: updated, status, confirmed: true }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Webhook processing failed", 500);
  }
}
