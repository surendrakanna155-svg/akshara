import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { correlationIdFromRequest, recordMutationAudit } from "../audit/audit_repository.ts";
import {
  createBroadcast,
  createThread,
  enqueueDeliveriesBatch,
  finalizeBroadcast,
  getThread,
  insertBroadcastRecipientsBatch,
  insertMessage,
  listMessagesForThread,
  listThreadsForUser,
  resolveBroadcastRecipients,
  type CommMessageRow,
  type CommThreadRow,
} from "./communication_repository.ts";
import { enqueueNotificationRequested, processDeliveryQueue } from "./notification_service.ts";

/**
 * PERF-1: hard cap on the recipients fanned out in a single broadcast so a
 * runaway audience can't blow the request/transaction budget. Anything beyond
 * the cap is dropped from this broadcast (and surfaced in the audit metadata);
 * the bound is generous enough to cover a whole school.
 */
const MAX_BROADCAST_RECIPIENTS = 5000;

export class CommunicationValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CommunicationValidationError";
  }
}

function requireSchool(claims: AccessTokenClaims): string {
  if (!claims.school_id) {
    throw new CommunicationValidationError("School context required");
  }
  return claims.school_id;
}

/** Map shorthand audience labels to comm_broadcasts CHECK constraint values. */
export function normalizeBroadcastAudience(audience: string): string {
  const aliases: Record<string, string> = {
    parents: "all_parents",
    parent: "all_parents",
    teachers: "all_teachers",
    teacher: "all_teachers",
    students: "all_students",
    student: "all_students",
    school: "school_wide",
  };
  return aliases[audience] ?? audience;
}

function formatTimeLabel(iso: string): string {
  const date = new Date(iso);
  const now = new Date();
  if (now.getTime() - date.getTime() < 86400000) {
    return date.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" });
  }
  return "Yesterday";
}

export function threadToApi(
  thread: CommThreadRow,
  messages: CommMessageRow[],
  viewerScope: "parent" | "school",
): Record<string, unknown> {
  const parentName = viewerScope === "school" ? "Parent" : "You";
  const studentName = thread.subject ?? "Student";
  return {
    id: thread.id,
    parentName,
    studentName,
    preview: thread.last_message_preview ?? "",
    timeLabel: formatTimeLabel(thread.updated_at),
    unreadCount: viewerScope === "parent"
      ? thread.unread_parent_count
      : thread.unread_teacher_count,
    messages: messages.map((m) => ({
      id: m.id,
      body: m.body,
      senderLabel: m.sender_role === "teacher" ? "Teacher" : "Parent",
      timeLabel: formatTimeLabel(m.created_at),
      isTeacher: m.sender_role === "teacher",
    })),
  };
}

export function deliveryToNotificationApi(row: {
  id: string;
  rendered_subject: string | null;
  rendered_body: string;
  category: string;
  is_read: boolean;
  child_context: string | null;
  created_at: string;
}): Record<string, unknown> {
  return {
    id: row.id,
    title: row.rendered_subject ?? "Notification",
    preview: row.rendered_body,
    timestamp: row.created_at,
    category: row.category,
    isRead: row.is_read,
    isUrgent: row.category === "fee",
    childContext: row.child_context,
  };
}

export async function listUserNotifications(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  limit = 50,
  offset = 0,
): Promise<Record<string, unknown>[]> {
  const { listDeliveriesForUser } = await import("./communication_repository.ts");
  const rows = await listDeliveriesForUser(db, claims.tenant_id, claims.sub, limit, offset);
  return rows.map(deliveryToNotificationApi);
}

export async function listUserMessageThreads(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  scope: "parent" | "school",
): Promise<Record<string, unknown>[]> {
  const schoolId = requireSchool(claims);
  const threads = await listThreadsForUser(db, claims.tenant_id, schoolId, claims.sub, scope);
  const result: Record<string, unknown>[] = [];
  for (const thread of threads) {
    const messages = await listMessagesForThread(db, thread.id);
    result.push(threadToApi(thread, messages, scope));
  }
  return result;
}

export async function sendDirectMessage(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: {
    threadId?: string;
    recipient?: string;
    subject?: string;
    body: string;
    senderRole: "parent" | "teacher";
    counterpartyUserId?: string;
  },
  req?: Request,
): Promise<Record<string, unknown>> {
  const schoolId = requireSchool(claims);
  if (!input.body.trim()) {
    throw new CommunicationValidationError("Message body is required");
  }

  let thread: CommThreadRow;
  if (input.threadId) {
    const existing = await getThread(db, claims.tenant_id, input.threadId);
    if (!existing) {
      throw new CommunicationValidationError("Thread not found");
    }
    thread = existing;
  } else {
    const isTeacher = input.senderRole === "teacher";
    thread = await createThread(db, {
      organizationId: claims.tenant_id,
      schoolId,
      subject: input.subject ?? null,
      parentUserId: isTeacher ? input.counterpartyUserId ?? null : claims.sub,
      teacherUserId: isTeacher ? claims.sub : input.counterpartyUserId ?? null,
      studentId: claims.child_ids[0] ?? null,
      preview: input.body.trim(),
    });
  }

  await insertMessage(db, {
    threadId: thread.id,
    organizationId: claims.tenant_id,
    schoolId,
    senderUserId: claims.sub,
    senderRole: input.senderRole,
    body: input.body.trim(),
  });

  const recipientId = input.senderRole === "teacher"
    ? thread.parent_user_id
    : thread.teacher_user_id;
  if (recipientId) {
    await enqueueNotificationRequested(
      db,
      claims.tenant_id,
      schoolId,
      recipientId,
      input.subject ?? "New message",
      input.body.trim(),
      "announcement",
    );
    await processDeliveryQueue(db, claims.tenant_id);
  }

  const messages = await listMessagesForThread(db, thread.id);
  const scope = input.senderRole === "parent" ? "parent" : "school";

  await recordMutationAudit(
    db,
    claims,
    {
      eventType: "messageSent",
      category: "workflow",
      entityType: "comm_message",
      entityId: thread.id,
      metadata: { senderRole: input.senderRole },
      correlationId: req ? correlationIdFromRequest(req) : undefined,
    },
    {
      eventType: "message.sent",
      payload: { threadId: thread.id, senderRole: input.senderRole },
      sourceModule: "communication",
      idempotencyKey: `message.sent:${thread.id}:${Date.now()}`,
    },
    req,
  );

  return threadToApi(thread, messages, scope);
}

export async function sendBroadcastMessage(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: { audience: string; title: string; body: string },
  req?: Request,
): Promise<Record<string, unknown>> {
  if (claims.scope !== "school" && claims.scope !== "organization") {
    throw new CommunicationValidationError("Broadcast requires school or organization scope");
  }
  const schoolId = claims.school_id;
  const audience = normalizeBroadcastAudience(input.audience);
  const broadcast = await createBroadcast(db, {
    organizationId: claims.tenant_id,
    schoolId,
    audience,
    title: input.title,
    body: input.body,
    createdBy: claims.sub,
  });

  const resolved = await resolveBroadcastRecipients(
    db,
    claims.tenant_id,
    schoolId,
    audience,
  );
  // PERF-1: bound the cohort, then write recipients + push deliveries in two
  // multi-row INSERTs instead of 2 round-trips per recipient. The actual
  // per-recipient send is NOT done here — deliveries are queued ('pending') and
  // drained out of the request/response cycle (see handleCreateBroadcast), so a
  // large-cohort broadcast can never block or time out the HTTP request.
  const recipients = resolved.slice(0, MAX_BROADCAST_RECIPIENTS);
  const dropped = resolved.length - recipients.length;

  await insertBroadcastRecipientsBatch(db, broadcast.id, claims.tenant_id, recipients);
  await enqueueDeliveriesBatch(db, {
    organizationId: claims.tenant_id,
    schoolId: schoolId ?? "a2000000-0000-4000-8000-000000000001",
    recipientUserIds: recipients,
    channel: "push",
    category: "announcement",
    renderedSubject: input.title,
    renderedBody: input.body,
  });
  await finalizeBroadcast(db, broadcast.id);

  await recordMutationAudit(
    db,
    claims,
    {
      eventType: "broadcastSent",
      category: "workflow",
      entityType: "comm_broadcast",
      entityId: broadcast.id,
      metadata: {
        audience: input.audience,
        recipientCount: recipients.length,
        resolvedCount: resolved.length,
        droppedOverCap: dropped,
      },
      correlationId: req ? correlationIdFromRequest(req) : undefined,
    },
    {
      eventType: "broadcast.sent",
      payload: { broadcastId: broadcast.id, audience: input.audience },
      sourceModule: "communication",
      idempotencyKey: `broadcast.sent:${broadcast.id}`,
    },
    req,
  );

  return {
    broadcastId: broadcast.id,
    audience: broadcast.audience,
    title: broadcast.title,
    recipientCount: recipients.length,
    droppedOverCap: dropped,
    status: "queued",
  };
}

function templateToApi(t: {
  id: string;
  code: string;
  channel: string;
  subject_template: string | null;
  body_template: string;
  variables: unknown;
}): Record<string, unknown> {
  return {
    id: t.id,
    code: t.code,
    channel: t.channel,
    subjectTemplate: t.subject_template,
    bodyTemplate: t.body_template,
    variables: t.variables,
  };
}

export async function listNotificationTemplates(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
): Promise<Record<string, unknown>[]> {
  const schoolId = requireSchool(claims);
  const { listTemplates } = await import("./communication_repository.ts");
  const rows = await listTemplates(db, claims.tenant_id, schoolId);
  return rows.map(templateToApi);
}

/**
 * MJ-C6a: create a notification template and persist it into the SAME
 * `notification_templates` store {@link listNotificationTemplates} reads from,
 * scoped to the caller's school. Validates the channel against the table's
 * CHECK constraint and the required code/body up front, and audits the write.
 * Returns the created template in the same shape as the list endpoint.
 */
export async function createNotificationTemplate(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: {
    code: string;
    channel: string;
    subjectTemplate?: string;
    bodyTemplate: string;
    variables?: unknown;
  },
  req?: Request,
): Promise<Record<string, unknown>> {
  if (claims.scope !== "school" && claims.scope !== "organization") {
    throw new CommunicationValidationError(
      "Template management requires school or organization scope",
    );
  }
  const schoolId = requireSchool(claims);
  const code = input.code.trim();
  if (!code) {
    throw new CommunicationValidationError("Template code is required");
  }
  const channel = input.channel.trim();
  if (!["sms", "email", "push"].includes(channel)) {
    throw new CommunicationValidationError(
      "channel must be one of sms, email, push",
    );
  }
  const bodyTemplate = input.bodyTemplate.trim();
  if (!bodyTemplate) {
    throw new CommunicationValidationError("body_template is required");
  }
  const variables = Array.isArray(input.variables)
    ? input.variables.map((v) => String(v))
    : [];

  const { insertTemplate } = await import("./communication_repository.ts");
  const row = await insertTemplate(db, {
    organizationId: claims.tenant_id,
    schoolId,
    code,
    channel,
    subjectTemplate: input.subjectTemplate?.trim() || null,
    bodyTemplate,
    variables,
  });

  await recordMutationAudit(
    db,
    claims,
    {
      eventType: "templateCreated",
      category: "workflow",
      entityType: "notification_template",
      entityId: row.id,
      metadata: { code: row.code, channel: row.channel },
      correlationId: req ? correlationIdFromRequest(req) : undefined,
    },
    {
      eventType: "communication.template.created",
      payload: { templateId: row.id, code: row.code },
      sourceModule: "communication",
      idempotencyKey: `communication.template.created:${row.id}`,
    },
    req,
  );

  return templateToApi(row);
}

/**
 * MJ-C6b: list past broadcasts from the SAME `comm_broadcasts` store
 * {@link sendBroadcastMessage} writes to, scoped to the caller's org/school.
 * Empty list when none — never fabricated.
 */
export async function listBroadcastHistoryEntries(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  limit = 50,
  offset = 0,
): Promise<Record<string, unknown>[]> {
  if (claims.scope !== "school" && claims.scope !== "organization") {
    throw new CommunicationValidationError(
      "Broadcast history requires school or organization scope",
    );
  }
  const { listBroadcastHistory } = await import("./communication_repository.ts");
  const rows = await listBroadcastHistory(
    db,
    claims.tenant_id,
    claims.school_id ?? null,
    limit,
    offset,
  );
  return rows.map((b) => ({
    id: b.id,
    title: b.title,
    audience: b.audience,
    status: b.status,
    recipientCount: b.recipient_count,
    sentAt: b.sent_at ?? b.created_at,
  }));
}
