import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { correlationIdFromRequest, recordMutationAudit } from "../audit/audit_repository.ts";
import {
  acknowledgeDelivery,
  type BroadcastDeliveryReport,
  claimDueScheduledBroadcasts,
  createAudienceSegment,
  createBroadcast,
  createScheduledBroadcast,
  createThread,
  deleteAudienceSegment,
  enqueueDeliveriesBatch,
  finalizeBroadcast,
  getBroadcastDeliveryReport,
  getBroadcastInScope,
  getThread,
  insertBroadcastRecipientsBatch,
  insertMessage,
  listAudienceSegments,
  listMessagesForThread,
  listThreadsForUser,
  listUnreadBroadcastRecipientIds,
  resolveBroadcastRecipients,
  type CommAudienceSegmentRow,
  type CommBroadcastRow,
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

/**
 * COM-D1: thrown when the acknowledged notification is not visible to the caller
 * (wrong recipient / wrong tenant / missing). Handlers map this to a 404 so we
 * never leak whether the delivery exists for another recipient.
 */
export class NotificationNotFoundError extends Error {
  constructor(deliveryId: string) {
    super(`Notification not found: ${deliveryId}`);
    this.name = "NotificationNotFoundError";
  }
}

/**
 * COM-2: audiences whose recipients are one specific class (optionally one
 * section). Authoring one of these REQUIRES an audience_class.
 */
const CLASS_AUDIENCES = new Set(["class_parents", "class_students"]);

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
  requires_ack?: boolean;
  acknowledged_at?: string | null;
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
    // COM-D1 — the recipient app renders an "Acknowledge" affordance when the
    // notice requires acknowledgement and hasn't been acknowledged yet.
    requiresAck: row.requires_ack ?? false,
    acknowledgedAt: row.acknowledged_at ?? null,
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
    // Integrity: a NEW thread must name its counterparty so every thread has
    // BOTH participants. Without this a parent/teacher could open a
    // half-populated thread that, under the now participant-only RLS (migration
    // 20260837000000), nobody but the author could ever see — an orphaned,
    // unreachable conversation. Replies (with a threadId) are unaffected.
    const counterparty = (input.counterpartyUserId ?? "").trim();
    if (!counterparty) {
      throw new CommunicationValidationError(
        isTeacher
          ? "A recipient parent is required to start a conversation"
          : "A recipient teacher is required to start a conversation",
      );
    }
    thread = await createThread(db, {
      organizationId: claims.tenant_id,
      schoolId,
      subject: input.subject ?? null,
      parentUserId: isTeacher ? counterparty : claims.sub,
      teacherUserId: isTeacher ? claims.sub : counterparty,
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
  input: {
    audience: string;
    title: string;
    body: string;
    audienceClass?: string | null;
    audienceSection?: string | null;
    requiresAck?: boolean;
  },
  req?: Request,
): Promise<Record<string, unknown>> {
  if (claims.scope !== "school" && claims.scope !== "organization") {
    throw new CommunicationValidationError("Broadcast requires school or organization scope");
  }
  const schoolId = claims.school_id;
  const audience = normalizeBroadcastAudience(input.audience);
  // COM-2: a class_* audience is meaningless without a class — reject up front
  // (422) rather than silently fanning out to nobody.
  const audienceClass = (input.audienceClass ?? "").trim() || null;
  const audienceSection = (input.audienceSection ?? "").trim() || null;
  if (CLASS_AUDIENCES.has(audience) && !audienceClass) {
    throw new CommunicationValidationError(
      "audience_class is required for a class broadcast",
    );
  }
  const requiresAck = input.requiresAck === true;
  const broadcast = await createBroadcast(db, {
    organizationId: claims.tenant_id,
    schoolId,
    audience,
    audienceClass,
    audienceSection,
    requiresAck,
    title: input.title,
    body: input.body,
    createdBy: claims.sub,
  });

  const resolved = await resolveBroadcastRecipients(
    db,
    claims.tenant_id,
    schoolId,
    audience,
    { className: audienceClass, sectionName: audienceSection },
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
    broadcastId: broadcast.id, // COM-1: tie the delivery ledger to this broadcast
    requiresAck, // COM-D1: flag each delivery when the notice must be acknowledged
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
        audienceClass,
        audienceSection,
        requiresAck,
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
    audienceClass: broadcast.audience_class,
    audienceSection: broadcast.audience_section,
    requiresAck: broadcast.requires_ack,
    title: broadcast.title,
    recipientCount: recipients.length,
    droppedOverCap: dropped,
    status: "queued",
  };
}

// --- XCT-2: scheduled broadcasts (foundation for every module reminder) -------

/**
 * XCT-2: validate + normalize a client-supplied scheduled-send timestamp to a
 * UTC ISO string. Rejects empty / unparseable values so a bad payload fails
 * loud (422) instead of silently inserting a NULL/garbage `scheduled_at` that
 * the runner would never pick up.
 */
export function parseScheduledAt(value: string | undefined | null): string {
  const raw = (value ?? "").trim();
  if (raw === "") {
    throw new CommunicationValidationError("scheduledAt is required to schedule a broadcast");
  }
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) {
    throw new CommunicationValidationError(`Invalid scheduledAt timestamp: ${raw}`);
  }
  return date.toISOString();
}

/**
 * XCT-2: author a broadcast for later delivery. Persists a `scheduled` row and
 * audits it; recipients are NOT resolved yet (that happens when
 * {@link runDueScheduledBroadcasts} dispatches it, so the audience is current).
 */
export async function scheduleBroadcastMessage(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: {
    audience: string;
    title: string;
    body: string;
    scheduledAt: string;
    audienceClass?: string | null;
    audienceSection?: string | null;
    requiresAck?: boolean;
  },
  req?: Request,
): Promise<Record<string, unknown>> {
  if (claims.scope !== "school" && claims.scope !== "organization") {
    throw new CommunicationValidationError("Broadcast requires school or organization scope");
  }
  const audience = normalizeBroadcastAudience(input.audience);
  const scheduledAt = parseScheduledAt(input.scheduledAt);
  if (input.title.trim() === "" || input.body.trim() === "") {
    throw new CommunicationValidationError("Broadcast title and body are required");
  }
  // COM-2: same class-audience guard as the immediate path — a scheduled
  // class_* broadcast must carry the class it targets.
  const audienceClass = (input.audienceClass ?? "").trim() || null;
  const audienceSection = (input.audienceSection ?? "").trim() || null;
  if (CLASS_AUDIENCES.has(audience) && !audienceClass) {
    throw new CommunicationValidationError(
      "audience_class is required for a class broadcast",
    );
  }
  const requiresAck = input.requiresAck === true;

  const broadcast = await createScheduledBroadcast(db, {
    organizationId: claims.tenant_id,
    schoolId: claims.school_id ?? null,
    audience,
    audienceClass,
    audienceSection,
    requiresAck,
    title: input.title,
    body: input.body,
    createdBy: claims.sub,
    scheduledAt,
  });

  await recordMutationAudit(
    db,
    claims,
    {
      eventType: "broadcastScheduled",
      category: "workflow",
      entityType: "comm_broadcast",
      entityId: broadcast.id,
      metadata: { audience: input.audience, audienceClass, audienceSection, requiresAck, scheduledAt },
      correlationId: req ? correlationIdFromRequest(req) : undefined,
    },
    {
      eventType: "broadcast.scheduled",
      payload: { broadcastId: broadcast.id, audience: input.audience, scheduledAt },
      sourceModule: "communication",
      idempotencyKey: `broadcast.scheduled:${broadcast.id}`,
    },
    req,
  );

  return {
    broadcastId: broadcast.id,
    audience: broadcast.audience,
    audienceClass: broadcast.audience_class,
    audienceSection: broadcast.audience_section,
    requiresAck: broadcast.requires_ack,
    title: broadcast.title,
    scheduledAt,
    status: "scheduled",
  };
}

/**
 * Shared fan-out for an already-persisted broadcast row (used by the scheduled
 * runner). Resolves the audience NOW, writes recipients + queues 'pending'
 * deliveries in two batch INSERTs, then marks the broadcast 'sent'. The queue is
 * drained out-of-band by the caller (same as the immediate path).
 */
async function fanOutExistingBroadcast(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  broadcast: CommBroadcastRow,
): Promise<{ recipientCount: number; droppedOverCap: number; resolvedCount: number }> {
  const schoolId = broadcast.school_id ?? claims.school_id ?? null;
  // COM-2 / COM-D1: the class/section + ack flag are read off the persisted
  // broadcast row so the scheduled dispatch honours what was authored (audience
  // membership is still resolved NOW, at dispatch time, not at authoring time).
  const resolved = await resolveBroadcastRecipients(
    db,
    claims.tenant_id,
    schoolId,
    broadcast.audience,
    { className: broadcast.audience_class, sectionName: broadcast.audience_section },
  );
  const recipients = resolved.slice(0, MAX_BROADCAST_RECIPIENTS);
  const dropped = resolved.length - recipients.length;

  await insertBroadcastRecipientsBatch(db, broadcast.id, claims.tenant_id, recipients);
  await enqueueDeliveriesBatch(db, {
    organizationId: claims.tenant_id,
    schoolId: schoolId ?? "a2000000-0000-4000-8000-000000000001",
    recipientUserIds: recipients,
    channel: "push",
    category: "announcement",
    renderedSubject: broadcast.title,
    renderedBody: broadcast.body,
    broadcastId: broadcast.id, // COM-1: tie the delivery ledger to this broadcast
    requiresAck: broadcast.requires_ack === true, // COM-D1: carry the ack flag
  });
  await finalizeBroadcast(db, broadcast.id);

  return {
    recipientCount: recipients.length,
    droppedOverCap: dropped,
    resolvedCount: resolved.length,
  };
}

/**
 * XCT-2 scheduled-job runner: dispatch every scheduled broadcast whose time has
 * arrived for the caller's org. Claims them atomically (no double-send), fans
 * each out to its current audience, and audits each dispatch. Idempotent and
 * re-entrant — safe to invoke on a cron/timer OR on demand. The periodic trigger
 * itself (pg_cron / VPS cron hitting the endpoint) is a deployment concern.
 */
export async function runDueScheduledBroadcasts(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  req?: Request,
  limit = 50,
): Promise<Record<string, unknown>> {
  const claimed = await claimDueScheduledBroadcasts(db, claims.tenant_id, limit);
  const dispatched: string[] = [];
  let totalRecipients = 0;

  for (const broadcast of claimed) {
    const result = await fanOutExistingBroadcast(db, claims, broadcast);
    totalRecipients += result.recipientCount;
    dispatched.push(broadcast.id);

    await recordMutationAudit(
      db,
      claims,
      {
        eventType: "scheduledBroadcastSent",
        category: "workflow",
        entityType: "comm_broadcast",
        entityId: broadcast.id,
        metadata: {
          audience: broadcast.audience,
          recipientCount: result.recipientCount,
          droppedOverCap: result.droppedOverCap,
          scheduledAt: broadcast.scheduled_at,
        },
        correlationId: req ? correlationIdFromRequest(req) : undefined,
      },
      {
        eventType: "broadcast.sent",
        payload: { broadcastId: broadcast.id, audience: broadcast.audience, scheduled: true },
        sourceModule: "communication",
        idempotencyKey: `broadcast.sent:${broadcast.id}`,
      },
      req,
    );
  }

  return {
    processed: dispatched.length,
    broadcastIds: dispatched,
    totalRecipients,
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
 * MJ-M12: update an existing notification template in the SAME
 * `notification_templates` store {@link listNotificationTemplates} reads from,
 * scoped to the caller's school. Only the supplied fields change. Validates the
 * channel (when supplied) against the table's CHECK constraint and audits the
 * write. Throws {@link CommunicationValidationError} when the template is not
 * visible to the caller, so the handler can map it to a 404.
 */
export async function updateNotificationTemplate(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  templateId: string,
  input: {
    code?: string;
    channel?: string;
    subjectTemplate?: string;
    bodyTemplate?: string;
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
  const id = templateId.trim();
  if (!id) {
    throw new CommunicationValidationError("Template id is required");
  }
  const code = input.code?.trim();
  if (input.code !== undefined && !code) {
    throw new CommunicationValidationError("Template code cannot be empty");
  }
  const channel = input.channel?.trim();
  if (channel !== undefined && !["sms", "email", "push"].includes(channel)) {
    throw new CommunicationValidationError(
      "channel must be one of sms, email, push",
    );
  }
  const bodyTemplate = input.bodyTemplate?.trim();
  if (input.bodyTemplate !== undefined && !bodyTemplate) {
    throw new CommunicationValidationError("body_template cannot be empty");
  }
  const variables = input.variables === undefined
    ? null
    : (Array.isArray(input.variables)
      ? input.variables.map((v) => String(v))
      : []);

  const { updateTemplate } = await import("./communication_repository.ts");
  const row = await updateTemplate(db, {
    organizationId: claims.tenant_id,
    schoolId,
    templateId: id,
    code: code ?? null,
    channel: channel ?? null,
    subjectTemplate: input.subjectTemplate?.trim() ?? null,
    bodyTemplate: bodyTemplate ?? null,
    variables,
  });
  if (!row) {
    throw new CommunicationValidationError("Template not found");
  }

  await recordMutationAudit(
    db,
    claims,
    {
      eventType: "templateUpdated",
      category: "workflow",
      entityType: "notification_template",
      entityId: row.id,
      metadata: { code: row.code, channel: row.channel },
      correlationId: req ? correlationIdFromRequest(req) : undefined,
    },
    {
      eventType: "communication.template.updated",
      payload: { templateId: row.id, code: row.code },
      sourceModule: "communication",
      idempotencyKey: `communication.template.updated:${row.id}:${Date.now()}`,
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

/**
 * COM-1: per-broadcast delivery & read report for the caller's org+school. Reads
 * the authoritative `notification_deliveries` ledger via
 * {@link getBroadcastDeliveryReport}; a broadcast that isn't visible in scope
 * throws {@link BroadcastNotFoundError} (→ 404 in the handler). Returns the
 * broadcast summary, aggregate counts, and the unread-recipient roster in the
 * API's camelCase shape.
 */
export async function getBroadcastReport(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  broadcastId: string,
): Promise<Record<string, unknown>> {
  const schoolId = requireSchool(claims);
  const report: BroadcastDeliveryReport = await getBroadcastDeliveryReport(
    db,
    claims.tenant_id,
    schoolId,
    broadcastId,
  );
  return {
    broadcast: {
      id: report.broadcast.id,
      title: report.broadcast.title,
      audience: report.broadcast.audience,
      status: report.broadcast.status,
      requiresAck: report.broadcast.requires_ack,
      sentAt: report.broadcast.sent_at,
      scheduledAt: report.broadcast.scheduled_at,
    },
    // COM-D1: counts now include `acknowledged` (deliveries with a receipt) so
    // the UI can show progress against `requiresAck`.
    counts: report.counts,
    unreadRecipients: report.unreadRecipients,
  };
}

/**
 * COM-3: re-enqueue a broadcast's push delivery to every recipient who was
 * delivered it ('sent') but has not read it yet. Reads the unread set from the
 * authoritative `notification_deliveries` ledger and re-enqueues 'pending'
 * deliveries (same channel/category/subject/body/route) STAMPED with the same
 * broadcast_id, so the resend is itself tracked in the report. A resend is
 * intentionally repeatable, so the audit event carries a fresh nonce rather than
 * a deterministic idempotency key. Returns the number of recipients re-targeted
 * (0 when everyone has read it). The freshly-queued deliveries are drained
 * out-of-band by the handler (same as the immediate broadcast path).
 */
export async function resendBroadcastToUnread(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  broadcastId: string,
  req?: Request,
): Promise<{ resent: number }> {
  const schoolId = requireSchool(claims);
  const broadcast = await getBroadcastInScope(
    db,
    claims.tenant_id,
    schoolId,
    broadcastId,
  );

  const unreadIds = await listUnreadBroadcastRecipientIds(
    db,
    claims.tenant_id,
    broadcast.id,
  );
  if (unreadIds.length === 0) {
    return { resent: 0 };
  }

  await enqueueDeliveriesBatch(db, {
    organizationId: claims.tenant_id,
    schoolId: broadcast.school_id ?? schoolId,
    recipientUserIds: unreadIds,
    channel: "push",
    category: "announcement",
    renderedSubject: broadcast.title,
    renderedBody: broadcast.body,
    broadcastId: broadcast.id, // COM-3: keep the resend tracked under the same broadcast
  });

  await recordMutationAudit(
    db,
    claims,
    {
      eventType: "broadcastResent",
      category: "workflow",
      entityType: "comm_broadcast",
      entityId: broadcast.id,
      metadata: { broadcastId: broadcast.id, resent: unreadIds.length },
      correlationId: req ? correlationIdFromRequest(req) : undefined,
    },
    {
      eventType: "broadcast.resent",
      payload: { broadcastId: broadcast.id, resent: unreadIds.length },
      sourceModule: "communication",
      // Resend is intentionally repeatable → unique nonce, not a deterministic key.
      idempotencyKey: `broadcast.resent:${broadcast.id}:${crypto.randomUUID()}`,
    },
    req,
  );

  return { resent: unreadIds.length };
}

// --- COM-D1: acknowledgement (signed-receipt) ---------------------------------

/**
 * COM-D1: record the caller's acknowledgement of one of THEIR OWN notification
 * deliveries. Scoped to (tenant, recipient=self); a delivery not visible to the
 * caller throws {@link NotificationNotFoundError} (→ 404). The mutation-audit
 * event `notification.acknowledged` (actor=self, target=deliveryId, timestamp)
 * IS the authoritative, immutable signed-receipt log; `acknowledged_at` on the
 * delivery row is the queryable projection the per-broadcast report counts.
 */
export async function acknowledgeNotification(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  deliveryId: string,
  req?: Request,
): Promise<{ deliveryId: string; acknowledgedAt: string }> {
  const id = (deliveryId ?? "").trim();
  if (!id) {
    throw new CommunicationValidationError("notification id is required");
  }
  const row = await acknowledgeDelivery(db, claims.tenant_id, claims.sub, id);
  if (!row) {
    throw new NotificationNotFoundError(id);
  }

  await recordMutationAudit(
    db,
    claims,
    {
      eventType: "notificationAcknowledged",
      category: "workflow",
      entityType: "notification_delivery",
      entityId: row.id,
      metadata: { deliveryId: row.id, acknowledgedAt: row.acknowledged_at },
      correlationId: req ? correlationIdFromRequest(req) : undefined,
    },
    {
      // This domain event is the signed receipt: actor=claims.sub (in the audit
      // row's user context), target=deliveryId, timestamp=acknowledged_at.
      eventType: "notification.acknowledged",
      payload: { deliveryId: row.id, acknowledgedAt: row.acknowledged_at },
      sourceModule: "communication",
      idempotencyKey: `notification.acknowledged:${row.id}`,
    },
    req,
  );

  return { deliveryId: row.id, acknowledgedAt: row.acknowledged_at };
}

// --- COM-2: saved audience segments -------------------------------------------

function segmentToApi(s: CommAudienceSegmentRow): Record<string, unknown> {
  return {
    id: s.id,
    name: s.name,
    audienceType: s.audience_type,
    className: s.class_name,
    sectionName: s.section_name,
    createdAt: s.created_at,
  };
}

/** COM-2: list the saved audience segments for the caller's school. */
export async function listAudienceSegmentEntries(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
): Promise<Record<string, unknown>[]> {
  const schoolId = requireSchool(claims);
  const rows = await listAudienceSegments(db, claims.tenant_id, schoolId);
  return rows.map(segmentToApi);
}

/**
 * COM-2: create a saved audience segment for the caller's school, validating the
 * name + audience type and (for class audiences) the class. Audits the write.
 */
export async function createAudienceSegmentEntry(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: {
    name: string;
    audienceType: string;
    className?: string | null;
    sectionName?: string | null;
  },
  req?: Request,
): Promise<Record<string, unknown>> {
  const schoolId = requireSchool(claims);
  const name = (input.name ?? "").trim();
  if (!name) {
    throw new CommunicationValidationError("Segment name is required");
  }
  const audienceType = normalizeBroadcastAudience((input.audienceType ?? "").trim());
  if (!audienceType) {
    throw new CommunicationValidationError("audience_type is required");
  }
  const className = (input.className ?? "").trim() || null;
  const sectionName = (input.sectionName ?? "").trim() || null;
  if (CLASS_AUDIENCES.has(audienceType) && !className) {
    throw new CommunicationValidationError(
      "class_name is required for a class segment",
    );
  }

  const row = await createAudienceSegment(db, {
    organizationId: claims.tenant_id,
    schoolId,
    name,
    audienceType,
    className,
    sectionName,
    createdBy: claims.sub,
  });

  await recordMutationAudit(
    db,
    claims,
    {
      eventType: "audienceSegmentCreated",
      category: "workflow",
      entityType: "comm_audience_segment",
      entityId: row.id,
      metadata: { name: row.name, audienceType: row.audience_type },
      correlationId: req ? correlationIdFromRequest(req) : undefined,
    },
    {
      eventType: "communication.audience_segment.created",
      payload: { segmentId: row.id, name: row.name },
      sourceModule: "communication",
      idempotencyKey: `communication.audience_segment.created:${row.id}`,
    },
    req,
  );

  return segmentToApi(row);
}

/**
 * COM-2: delete a saved audience segment scoped to the caller's school. Throws
 * {@link NotificationNotFoundError} (→ 404) when no matching segment exists.
 * Audits the delete.
 */
export async function deleteAudienceSegmentEntry(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  segmentId: string,
  req?: Request,
): Promise<{ id: string }> {
  const schoolId = requireSchool(claims);
  const id = (segmentId ?? "").trim();
  if (!id) {
    throw new CommunicationValidationError("Segment id is required");
  }
  const deleted = await deleteAudienceSegment(db, claims.tenant_id, schoolId, id);
  if (!deleted) {
    throw new NotificationNotFoundError(id);
  }

  await recordMutationAudit(
    db,
    claims,
    {
      eventType: "audienceSegmentDeleted",
      category: "workflow",
      entityType: "comm_audience_segment",
      entityId: deleted,
      metadata: { segmentId: deleted },
      correlationId: req ? correlationIdFromRequest(req) : undefined,
    },
    {
      eventType: "communication.audience_segment.deleted",
      payload: { segmentId: deleted },
      sourceModule: "communication",
      idempotencyKey: `communication.audience_segment.deleted:${deleted}:${Date.now()}`,
    },
    req,
  );

  return { id: deleted };
}
