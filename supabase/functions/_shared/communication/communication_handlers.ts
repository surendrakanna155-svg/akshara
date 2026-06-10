import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import {
  CommunicationValidationError,
  listNotificationTemplates,
  listUserMessageThreads,
  listUserNotifications,
  sendBroadcastMessage,
  sendDirectMessage,
} from "./communication_service.ts";
import { getNotificationDeliveryMetrics } from "./communication_repository.ts";
import { processDeliveryQueue } from "./notification_service.ts";

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

  try {
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
    const updated = await withTenantContext(config, auth.claims, async (db) =>
      await markNotificationRead(db, auth.claims.tenant_id, auth.claims.sub, notificationId)
    );
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
    const count = await withTenantContext(config, auth.claims, async (db) =>
      await markAllNotificationsRead(db, auth.claims.tenant_id, auth.claims.sub)
    );
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
    await withTenantContext(config, auth.claims, async (db) =>
      await registerDeviceToken(db, auth.claims.tenant_id, auth.claims.sub, platform, token)
    );
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
    await withTenantContext(config, auth.claims, async (db) =>
      await unregisterDeviceToken(db, auth.claims.tenant_id, auth.claims.sub, token)
    );
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
