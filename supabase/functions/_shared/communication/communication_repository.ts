import type { TenantQueryClient } from "../tenant_db.ts";

export const NOTIFICATION_DELIVERY_PROBE_SCHOOL_A = "d2000000-0000-4000-8000-000000000001";
export const NOTIFICATION_DELIVERY_PROBE_SCHOOL_B = "d2000000-0000-4000-8000-000000000002";
export const COMM_THREAD_PROBE_SCHOOL_A = "d1000000-0000-4000-8000-000000000001";
export const COMM_THREAD_PROBE_SCHOOL_B = "d1000000-0000-4000-8000-000000000002";

export const NOTIFICATION_DELIVERY_PROBE_DETAIL_SQL = `
  SELECT count(*)::text AS count FROM notification_deliveries WHERE id = $1::uuid
`;

export const COMM_THREAD_PROBE_DETAIL_SQL = `
  SELECT count(*)::text AS count FROM comm_threads WHERE id = $1::uuid
`;

export interface NotificationTemplateRow {
  id: string;
  organization_id: string;
  school_id: string | null;
  code: string;
  channel: string;
  subject_template: string | null;
  body_template: string;
  variables: unknown;
  is_active: boolean;
}

export interface NotificationDeliveryRow {
  id: string;
  organization_id: string;
  school_id: string | null;
  recipient_user_id: string;
  channel: string;
  template_id: string | null;
  category: string;
  rendered_subject: string | null;
  rendered_body: string;
  status: string;
  provider_ref: string | null;
  retry_count: number;
  max_retries: number;
  next_retry_at: string | null;
  last_error: string | null;
  is_read: boolean;
  child_context: string | null;
  route: string | null;
  sent_at: string | null;
  created_at: string;
}

export interface CommThreadRow {
  id: string;
  organization_id: string;
  school_id: string;
  thread_type: string;
  subject: string | null;
  parent_user_id: string | null;
  teacher_user_id: string | null;
  student_id: string | null;
  last_message_preview: string | null;
  unread_parent_count: number;
  unread_teacher_count: number;
  created_at: string;
  updated_at: string;
}

export interface CommMessageRow {
  id: string;
  thread_id: string;
  organization_id: string;
  school_id: string;
  sender_user_id: string;
  sender_role: string;
  body: string;
  locale: string;
  created_at: string;
}

export interface CommBroadcastRow {
  id: string;
  organization_id: string;
  school_id: string | null;
  audience: string;
  /** COM-2: class this broadcast targets when audience is class_parents/class_students. */
  audience_class: string | null;
  /** COM-2: optional section within audience_class (null = whole class). */
  audience_section: string | null;
  title: string;
  body: string;
  status: string;
  /** COM-D1: whether recipients must explicitly acknowledge this broadcast. */
  requires_ack: boolean;
  scheduled_at: string | null;
  sent_at: string | null;
  created_by: string;
  created_at: string;
}

/** COM-2: a saved, reusable named audience (class/section) for a school. */
export interface CommAudienceSegmentRow {
  id: string;
  organization_id: string;
  school_id: string;
  name: string;
  audience_type: string;
  class_name: string | null;
  section_name: string | null;
  created_by: string | null;
  created_at: string;
}

/**
 * COM-1/COM-3: thrown when a broadcast id is not visible in the caller's
 * org+school. Handlers map this to a 404 (never leak whether the id exists in a
 * different tenant/school).
 */
export class BroadcastNotFoundError extends Error {
  constructor(broadcastId: string) {
    super(`Broadcast not found: ${broadcastId}`);
    this.name = "BroadcastNotFoundError";
  }
}

/** COM-1: aggregate delivery/read counters for one broadcast, computed off the
 * authoritative `notification_deliveries` ledger. */
export interface BroadcastDeliveryCounts {
  total: number;
  sent: number;
  failed: number;
  pending: number;
  read: number;
  unread: number;
  /** COM-D1: number of deliveries whose recipient has acknowledged the notice
   * (acknowledged_at IS NOT NULL). Meaningful when requiresAck is true. */
  acknowledged: number;
}

/** COM-1: identity of a recipient who has been delivered a broadcast but has not
 * yet read it. */
export interface UnreadBroadcastRecipient {
  userId: string;
  name: string;
}

/** COM-1: full per-broadcast delivery & read report (broadcast summary +
 * aggregate counts + the unread-recipient roster). */
export interface BroadcastDeliveryReport {
  broadcast: {
    id: string;
    title: string;
    audience: string;
    status: string;
    /** COM-D1: whether this broadcast required recipient acknowledgement. */
    requires_ack: boolean;
    sent_at: string | null;
    scheduled_at: string | null;
  };
  counts: BroadcastDeliveryCounts;
  unreadRecipients: UnreadBroadcastRecipient[];
}

export async function listTemplates(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<NotificationTemplateRow[]> {
  return await db.queryObject<NotificationTemplateRow>(
    `SELECT * FROM notification_templates
     WHERE organization_id = $1
       AND is_active = true
       AND (school_id IS NULL OR school_id = $2)
     ORDER BY code`,
    [orgId, schoolId],
  );
}

/**
 * MJ-C6a: persist a new notification template into the SAME table
 * {@link listTemplates} reads from (`notification_templates`), scoped to the
 * caller's school so it then appears in the list. `variables` is stored as
 * jsonb. Returns the inserted row.
 */
export async function insertTemplate(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    code: string;
    channel: string;
    subjectTemplate: string | null;
    bodyTemplate: string;
    variables: unknown;
  },
): Promise<NotificationTemplateRow> {
  const rows = await db.queryObject<NotificationTemplateRow>(
    `INSERT INTO notification_templates (
       organization_id, school_id, code, channel,
       subject_template, body_template, variables, is_active
     ) VALUES ($1, $2, $3, $4, $5, $6, $7::jsonb, true)
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.code,
      input.channel,
      input.subjectTemplate,
      input.bodyTemplate,
      JSON.stringify(input.variables ?? []),
    ],
  );
  return rows[0]!;
}

/**
 * MJ-M12: update an existing notification template in place, scoped to the
 * caller's school (or org-wide rows). Only the supplied fields change; the rest
 * keep their current values via COALESCE. Returns the updated row, or null when
 * no active template with that id is visible to the caller.
 */
export async function updateTemplate(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    templateId: string;
    code: string | null;
    channel: string | null;
    subjectTemplate: string | null;
    bodyTemplate: string | null;
    variables: unknown | null;
  },
): Promise<NotificationTemplateRow | null> {
  const rows = await db.queryObject<NotificationTemplateRow>(
    `UPDATE notification_templates SET
       code = COALESCE($4, code),
       channel = COALESCE($5, channel),
       subject_template = CASE WHEN $6::text IS NULL THEN subject_template ELSE $6 END,
       body_template = COALESCE($7, body_template),
       variables = COALESCE($8::jsonb, variables)
     WHERE id = $3
       AND organization_id = $1
       AND is_active = true
       AND (school_id IS NULL OR school_id = $2)
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.templateId,
      input.code,
      input.channel,
      input.subjectTemplate,
      input.bodyTemplate,
      input.variables == null ? null : JSON.stringify(input.variables),
    ],
  );
  return rows[0] ?? null;
}

export async function getTemplateByCode(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  code: string,
): Promise<NotificationTemplateRow | null> {
  const rows = await db.queryObject<NotificationTemplateRow>(
    `SELECT * FROM notification_templates
     WHERE organization_id = $1
       AND code = $2
       AND is_active = true
       AND (school_id IS NULL OR school_id = $3)
     ORDER BY school_id NULLS LAST
     LIMIT 1`,
    [orgId, code, schoolId],
  );
  return rows[0] ?? null;
}

/**
 * QA-C-016: resolves a recipient parent's stored language NAME from
 * `parent_language_preferences` (student-specific pref first, then the global
 * per-user pref), or `null` when none is set. Caller maps it to a code via
 * `parentLanguageCodeFromName` and passes it as `recipientLanguage`.
 */
export async function getParentPreferredLanguageName(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  userId: string,
  studentId?: string | null,
): Promise<string | null> {
  const rows = await db.queryObject<{ language: string }>(
    `SELECT language FROM parent_language_preferences
     WHERE organization_id = $1 AND school_id = $2 AND user_id = $3
       AND (student_id = $4 OR student_id IS NULL)
     ORDER BY student_id NULLS LAST
     LIMIT 1`,
    [orgId, schoolId, userId, studentId ?? null],
  );
  return rows[0]?.language ?? null;
}

export async function listDeliveriesForUser(
  db: TenantQueryClient,
  orgId: string,
  userId: string,
  limit = 50,
  offset = 0,
): Promise<NotificationDeliveryRow[]> {
  return await db.queryObject<NotificationDeliveryRow>(
    `SELECT * FROM notification_deliveries
     WHERE organization_id = $1
       AND recipient_user_id = $2
       AND status IN ('sent', 'pending')
     ORDER BY created_at DESC
     LIMIT $3 OFFSET $4`,
    [orgId, userId, limit, offset],
  );
}

export async function enqueueDelivery(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string | null;
    recipientUserId: string;
    channel: string;
    templateId?: string | null;
    category: string;
    renderedSubject: string | null;
    renderedBody: string;
    childContext?: string | null;
    route?: string | null;
  },
): Promise<NotificationDeliveryRow> {
  const rows = await db.queryObject<NotificationDeliveryRow>(
    `INSERT INTO notification_deliveries (
       organization_id, school_id, recipient_user_id, channel, template_id,
       category, rendered_subject, rendered_body, child_context, route, status
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'pending')
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.recipientUserId,
      input.channel,
      input.templateId ?? null,
      input.category,
      input.renderedSubject,
      input.renderedBody,
      input.childContext ?? null,
      input.route ?? null,
    ],
  );
  return rows[0]!;
}

/**
 * PERF-1: enqueue one push delivery per recipient in a single multi-row INSERT.
 * Mirrors {@link enqueueDelivery} (template_id / child_context default to NULL,
 * status defaults to 'pending') but for a whole broadcast cohort at once.
 * Returns the number of rows queued.
 */
export async function enqueueDeliveriesBatch(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string | null;
    recipientUserIds: string[];
    channel: string;
    category: string;
    renderedSubject: string | null;
    renderedBody: string;
    route?: string | null;
    /**
     * COM-1: when set, stamps every enqueued delivery with the originating
     * broadcast so per-broadcast delivery/read reports (see
     * {@link getBroadcastDeliveryReport}) can tie the ledger back to the
     * broadcast. Left NULL for direct-message / absence-alert enqueues.
     */
    broadcastId?: string | null;
    /**
     * COM-D1: when true, every enqueued delivery is flagged
     * `requires_ack = true` so the recipient's app renders the acknowledge
     * affordance and the delivery can be counted toward the acknowledgement
     * total in the report. Defaults false (direct messages / absence alerts).
     */
    requiresAck?: boolean;
  },
): Promise<number> {
  if (input.recipientUserIds.length === 0) return 0;
  const params: unknown[] = [
    input.organizationId,
    input.schoolId,
    input.channel,
    input.category,
    input.renderedSubject,
    input.renderedBody,
    input.route ?? null,
    input.broadcastId ?? null,
    input.requiresAck ?? false,
  ];
  const values = input.recipientUserIds.map((userId, i) => {
    params.push(userId);
    return `($1, $2, $${i + 10}, $3, $4, $5, $6, $7, $8, $9, 'pending')`;
  });
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO notification_deliveries (
       organization_id, school_id, recipient_user_id, channel,
       category, rendered_subject, rendered_body, route, broadcast_id,
       requires_ack, status
     ) VALUES ${values.join(", ")}
     RETURNING id`,
    params,
  );
  return rows.length;
}

export async function fetchPendingDeliveries(
  db: TenantQueryClient,
  orgId: string,
  limit = 50,
): Promise<NotificationDeliveryRow[]> {
  return await db.queryObject<NotificationDeliveryRow>(
    `SELECT * FROM notification_deliveries
     WHERE organization_id = $1
       AND status = 'pending'
       AND (next_retry_at IS NULL OR next_retry_at <= timezone('utc', now()))
     ORDER BY created_at
     LIMIT $2`,
    [orgId, limit],
  );
}

export async function markDeliverySent(
  db: TenantQueryClient,
  deliveryId: string,
  providerRef: string | null,
): Promise<void> {
  await db.queryObject(
    `UPDATE notification_deliveries
     SET status = 'sent', provider_ref = $2, sent_at = timezone('utc', now()),
         updated_at = timezone('utc', now())
     WHERE id = $1`,
    [deliveryId, providerRef],
  );
}

export async function markDeliveryFailed(
  db: TenantQueryClient,
  delivery: NotificationDeliveryRow,
  error: string,
): Promise<void> {
  const nextRetry = delivery.retry_count + 1;
  if (nextRetry >= delivery.max_retries) {
    await db.queryObject(
      `UPDATE notification_deliveries
       SET status = 'failed', retry_count = $2, last_error = $3,
           updated_at = timezone('utc', now())
       WHERE id = $1`,
      [delivery.id, nextRetry, error],
    );
    return;
  }
  const backoffMinutes = Math.pow(2, nextRetry);
  await db.queryObject(
    `UPDATE notification_deliveries
     SET retry_count = $2, last_error = $3,
         next_retry_at = timezone('utc', now()) + ($4 || ' minutes')::interval,
         updated_at = timezone('utc', now())
     WHERE id = $1`,
    [delivery.id, nextRetry, error, String(backoffMinutes)],
  );
}

export async function listThreadsForUser(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  userId: string,
  scope: "parent" | "school",
): Promise<CommThreadRow[]> {
  if (scope === "parent") {
    return await db.queryObject<CommThreadRow>(
      `SELECT * FROM comm_threads
       WHERE organization_id = $1 AND school_id = $2 AND parent_user_id = $3
       ORDER BY updated_at DESC`,
      [orgId, schoolId, userId],
    );
  }
  return await db.queryObject<CommThreadRow>(
    `SELECT * FROM comm_threads
     WHERE organization_id = $1 AND school_id = $2 AND teacher_user_id = $3
     ORDER BY updated_at DESC`,
    [orgId, schoolId, userId],
  );
}

export async function listMessagesForThread(
  db: TenantQueryClient,
  threadId: string,
): Promise<CommMessageRow[]> {
  return await db.queryObject<CommMessageRow>(
    `SELECT * FROM comm_messages WHERE thread_id = $1 ORDER BY created_at`,
    [threadId],
  );
}

export async function createThread(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    subject: string | null;
    parentUserId: string | null;
    teacherUserId: string | null;
    studentId: string | null;
    preview: string;
  },
): Promise<CommThreadRow> {
  const rows = await db.queryObject<CommThreadRow>(
    `INSERT INTO comm_threads (
       organization_id, school_id, thread_type, subject,
       parent_user_id, teacher_user_id, student_id, last_message_preview
     ) VALUES ($1, $2, 'direct', $3, $4, $5, $6, $7)
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.subject,
      input.parentUserId,
      input.teacherUserId,
      input.studentId,
      input.preview,
    ],
  );
  return rows[0]!;
}

export async function getThread(
  db: TenantQueryClient,
  orgId: string,
  threadId: string,
): Promise<CommThreadRow | null> {
  const rows = await db.queryObject<CommThreadRow>(
    `SELECT * FROM comm_threads WHERE organization_id = $1 AND id = $2`,
    [orgId, threadId],
  );
  return rows[0] ?? null;
}

export async function insertMessage(
  db: TenantQueryClient,
  input: {
    threadId: string;
    organizationId: string;
    schoolId: string;
    senderUserId: string;
    senderRole: string;
    body: string;
  },
): Promise<CommMessageRow> {
  const rows = await db.queryObject<CommMessageRow>(
    `INSERT INTO comm_messages (
       thread_id, organization_id, school_id, sender_user_id, sender_role, body
     ) VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [
      input.threadId,
      input.organizationId,
      input.schoolId,
      input.senderUserId,
      input.senderRole,
      input.body,
    ],
  );
  const unreadParent = input.senderRole === "teacher" ? 1 : 0;
  const unreadTeacher = input.senderRole === "parent" ? 1 : 0;
  await db.queryObject(
    `UPDATE comm_threads
     SET last_message_preview = $2,
         unread_parent_count = unread_parent_count + $3,
         unread_teacher_count = unread_teacher_count + $4,
         updated_at = timezone('utc', now())
     WHERE id = $1`,
    [input.threadId, input.body.slice(0, 200), unreadParent, unreadTeacher],
  );
  return rows[0]!;
}

export async function createBroadcast(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string | null;
    audience: string;
    audienceClass?: string | null;
    audienceSection?: string | null;
    requiresAck?: boolean;
    title: string;
    body: string;
    createdBy: string;
  },
): Promise<CommBroadcastRow> {
  const rows = await db.queryObject<CommBroadcastRow>(
    `INSERT INTO comm_broadcasts (
       organization_id, school_id, audience, audience_class, audience_section,
       requires_ack, title, body, status, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'sending', $9)
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.audience,
      input.audienceClass ?? null,
      input.audienceSection ?? null,
      input.requiresAck ?? false,
      input.title,
      input.body,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

/**
 * XCT-2: create a broadcast in the `scheduled` state (status='scheduled',
 * `scheduled_at` set) WITHOUT resolving recipients or enqueuing deliveries yet.
 * Recipient resolution is deferred to dispatch time (see
 * {@link claimDueScheduledBroadcasts}) so audience membership is current when the
 * message actually goes out, not when it was authored.
 */
export async function createScheduledBroadcast(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string | null;
    audience: string;
    audienceClass?: string | null;
    audienceSection?: string | null;
    requiresAck?: boolean;
    title: string;
    body: string;
    createdBy: string;
    scheduledAt: string;
  },
): Promise<CommBroadcastRow> {
  const rows = await db.queryObject<CommBroadcastRow>(
    `INSERT INTO comm_broadcasts (
       organization_id, school_id, audience, audience_class, audience_section,
       requires_ack, title, body, status, scheduled_at, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'scheduled', $9, $10)
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.audience,
      input.audienceClass ?? null,
      input.audienceSection ?? null,
      input.requiresAck ?? false,
      input.title,
      input.body,
      input.scheduledAt,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

/**
 * XCT-2 scheduled-job runner core: atomically CLAIM the due scheduled broadcasts
 * for one org and flip them `scheduled` → `sending` in a single statement.
 * `FOR UPDATE SKIP LOCKED` makes it safe to run concurrently / re-entrantly — a
 * broadcast is claimed by exactly one runner pass, so it can never be
 * double-sent. Only rows whose `scheduled_at` has arrived are returned.
 */
export async function claimDueScheduledBroadcasts(
  db: TenantQueryClient,
  orgId: string,
  limit = 50,
): Promise<CommBroadcastRow[]> {
  return await db.queryObject<CommBroadcastRow>(
    `UPDATE comm_broadcasts
        SET status = 'sending', updated_at = timezone('utc', now())
      WHERE id IN (
        SELECT id FROM comm_broadcasts
         WHERE organization_id = $1
           AND status = 'scheduled'
           AND scheduled_at IS NOT NULL
           AND scheduled_at <= timezone('utc', now())
         ORDER BY scheduled_at ASC
         LIMIT $2
         FOR UPDATE SKIP LOCKED
      )
      RETURNING *`,
    [orgId, limit],
  );
}

/**
 * MJ-C6b: list past broadcasts from the SAME table {@link createBroadcast}
 * writes to (`comm_broadcasts`), scoped to the caller's org (and school when
 * present). Each row carries its real recipient count from `comm_recipients`.
 * Returns an empty list when none exist — never fabricated.
 */
export async function listBroadcastHistory(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string | null,
  limit = 50,
  offset = 0,
): Promise<(CommBroadcastRow & { recipient_count: number })[]> {
  return await db.queryObject<CommBroadcastRow & { recipient_count: number }>(
    `SELECT b.*,
            (SELECT count(*)::int FROM comm_recipients r WHERE r.broadcast_id = b.id)
              AS recipient_count
       FROM comm_broadcasts b
      WHERE b.organization_id = $1
        AND ($2::uuid IS NULL OR b.school_id IS NULL OR b.school_id = $2::uuid)
      ORDER BY COALESCE(b.sent_at, b.created_at) DESC
      LIMIT $3 OFFSET $4`,
    [orgId, schoolId, limit, offset],
  );
}

/**
 * COM-1: per-broadcast delivery & read report. The broadcast is first verified
 * to exist in the caller's org+school (org-wide broadcasts have school_id NULL)
 * — a miss throws {@link BroadcastNotFoundError} so the handler returns 404
 * without leaking cross-tenant existence. Counts are aggregated from the
 * authoritative `notification_deliveries` ledger (status flipped by the drain,
 * is_read flipped by the mark-read handlers); `comm_recipients.delivery_status`
 * is deliberately NOT consulted (it is the intended-audience record and stays
 * 'pending'). The unread roster joins delivered-but-unread rows to the canonical
 * `users.display_name`.
 */
export async function getBroadcastDeliveryReport(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  broadcastId: string,
): Promise<BroadcastDeliveryReport> {
  const broadcastRows = await db.queryObject<{
    id: string;
    title: string;
    audience: string;
    status: string;
    requires_ack: boolean;
    sent_at: string | null;
    scheduled_at: string | null;
  }>(
    `SELECT id, title, audience, status, requires_ack, sent_at, scheduled_at
       FROM comm_broadcasts
      WHERE id = $1
        AND organization_id = $2
        AND (school_id = $3 OR school_id IS NULL)`,
    [broadcastId, orgId, schoolId],
  );
  const broadcast = broadcastRows[0];
  if (!broadcast) throw new BroadcastNotFoundError(broadcastId);

  const countRows = await db.queryObject<{
    total: string;
    sent: string;
    failed: string;
    pending: string;
    read: string;
    unread: string;
    acknowledged: string;
  }>(
    `SELECT
        count(*)::text AS total,
        count(*) FILTER (WHERE status = 'sent')::text AS sent,
        count(*) FILTER (WHERE status = 'failed')::text AS failed,
        count(*) FILTER (WHERE status = 'pending')::text AS pending,
        count(*) FILTER (WHERE is_read = true)::text AS read,
        count(*) FILTER (WHERE status = 'sent' AND is_read = false)::text AS unread,
        count(*) FILTER (WHERE acknowledged_at IS NOT NULL)::text AS acknowledged
       FROM notification_deliveries
      WHERE broadcast_id = $1`,
    [broadcastId],
  );
  const c = countRows[0];
  const counts: BroadcastDeliveryCounts = {
    total: Number(c?.total ?? 0),
    sent: Number(c?.sent ?? 0),
    failed: Number(c?.failed ?? 0),
    pending: Number(c?.pending ?? 0),
    read: Number(c?.read ?? 0),
    unread: Number(c?.unread ?? 0),
    acknowledged: Number(c?.acknowledged ?? 0),
  };

  const unreadRows = await db.queryObject<{ user_id: string; name: string }>(
    `SELECT nd.recipient_user_id AS user_id,
            COALESCE(u.display_name, '') AS name
       FROM notification_deliveries nd
       LEFT JOIN users u ON u.id = nd.recipient_user_id
      WHERE nd.broadcast_id = $1
        AND nd.status = 'sent'
        AND nd.is_read = false
      ORDER BY name
      LIMIT 500`,
    [broadcastId],
  );

  return {
    broadcast: {
      id: broadcast.id,
      title: broadcast.title,
      audience: broadcast.audience,
      status: broadcast.status,
      requires_ack: broadcast.requires_ack ?? false,
      sent_at: broadcast.sent_at,
      scheduled_at: broadcast.scheduled_at,
    },
    counts,
    unreadRecipients: unreadRows.map((r) => ({ userId: r.user_id, name: r.name })),
  };
}

/**
 * COM-3: distinct recipient ids that were delivered a broadcast ('sent') but
 * have not read it yet, from the authoritative `notification_deliveries` ledger.
 * These are the re-send targets for {@link resendBroadcastToUnread}.
 */
export async function listUnreadBroadcastRecipientIds(
  db: TenantQueryClient,
  orgId: string,
  broadcastId: string,
): Promise<string[]> {
  const rows = await db.queryObject<{ recipient_user_id: string }>(
    `SELECT DISTINCT recipient_user_id
       FROM notification_deliveries
      WHERE broadcast_id = $1
        AND organization_id = $2
        AND status = 'sent'
        AND is_read = false`,
    [broadcastId, orgId],
  );
  return rows.map((r) => r.recipient_user_id);
}

/** COM-3: load a broadcast scoped to the caller's org+school (org-wide rows have
 * school_id NULL) for the resend path; throws {@link BroadcastNotFoundError}
 * (→ 404) when not visible. */
export async function getBroadcastInScope(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  broadcastId: string,
): Promise<CommBroadcastRow> {
  const rows = await db.queryObject<CommBroadcastRow>(
    `SELECT * FROM comm_broadcasts
      WHERE id = $1
        AND organization_id = $2
        AND (school_id = $3 OR school_id IS NULL)`,
    [broadcastId, orgId, schoolId],
  );
  const row = rows[0];
  if (!row) throw new BroadcastNotFoundError(broadcastId);
  return row;
}

export async function finalizeBroadcast(
  db: TenantQueryClient,
  broadcastId: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE comm_broadcasts
     SET status = 'sent', sent_at = timezone('utc', now()), updated_at = timezone('utc', now())
     WHERE id = $1`,
    [broadcastId],
  );
}

export async function insertBroadcastRecipient(
  db: TenantQueryClient,
  broadcastId: string,
  orgId: string,
  userId: string,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO comm_recipients (broadcast_id, organization_id, user_id, delivery_status)
     VALUES ($1, $2, $3, 'pending')
     ON CONFLICT (broadcast_id, user_id) DO NOTHING`,
    [broadcastId, orgId, userId],
  );
}

/**
 * PERF-1: write every broadcast recipient in a single multi-row INSERT instead
 * of one round-trip per recipient. A no-op for an empty list.
 */
export async function insertBroadcastRecipientsBatch(
  db: TenantQueryClient,
  broadcastId: string,
  orgId: string,
  userIds: string[],
): Promise<void> {
  if (userIds.length === 0) return;
  const params: unknown[] = [broadcastId, orgId];
  const values = userIds.map((userId, i) => {
    params.push(userId);
    return `($1, $2, $${i + 3}, 'pending')`;
  });
  await db.queryObject(
    `INSERT INTO comm_recipients (broadcast_id, organization_id, user_id, delivery_status)
     VALUES ${values.join(", ")}
     ON CONFLICT (broadcast_id, user_id) DO NOTHING`,
    params,
  );
}

export async function fetchActiveDeviceToken(
  db: TenantQueryClient,
  orgId: string,
  userId: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ token: string }>(
    `SELECT token FROM comm_device_tokens
     WHERE organization_id = $1 AND user_id = $2 AND is_active = true
     ORDER BY updated_at DESC LIMIT 1`,
    [orgId, userId],
  );
  return rows[0]?.token ?? null;
}

export async function registerDeviceToken(
  db: TenantQueryClient,
  orgId: string,
  userId: string,
  platform: string,
  token: string,
): Promise<void> {
  await db.queryObject(
    `INSERT INTO comm_device_tokens (organization_id, user_id, platform, token, is_active)
     VALUES ($1, $2, $3, $4, true)
     ON CONFLICT (organization_id, user_id, platform, token)
     DO UPDATE SET is_active = true, updated_at = timezone('utc', now())`,
    [orgId, userId, platform, token],
  );
}

export async function unregisterDeviceToken(
  db: TenantQueryClient,
  orgId: string,
  userId: string,
  token: string,
): Promise<void> {
  await db.queryObject(
    `UPDATE comm_device_tokens SET is_active = false, updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND user_id = $2 AND token = $3`,
    [orgId, userId, token],
  );
}

export async function markNotificationRead(
  db: TenantQueryClient,
  orgId: string,
  userId: string,
  notificationId: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `UPDATE notification_deliveries SET is_read = true, updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND recipient_user_id = $2 AND id = $3::uuid
     RETURNING id`,
    [orgId, userId, notificationId],
  );
  return rows.length > 0;
}

export async function markAllNotificationsRead(
  db: TenantQueryClient,
  orgId: string,
  userId: string,
): Promise<number> {
  const rows = await db.queryObject<{ id: string }>(
    `UPDATE notification_deliveries SET is_read = true, updated_at = timezone('utc', now())
     WHERE organization_id = $1 AND recipient_user_id = $2 AND is_read = false
     RETURNING id`,
    [orgId, userId],
  );
  return rows.length;
}

export async function resolveBroadcastRecipients(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string | null,
  audience: string,
  opts?: { className?: string | null; sectionName?: string | null },
): Promise<string[]> {
  const className = (opts?.className ?? "").trim();
  const sectionName = (opts?.sectionName ?? "").trim() || null;

  // COM-2: guardians of one class (optionally one section). A null/empty section
  // means "every section of the class". Empty class → [] (the handler validates
  // 422 up front, but resolve defensively too so a bad row never fans out to the
  // whole school).
  if (audience === "class_parents") {
    if (!className || !schoolId) return [];
    const rows = await db.queryObject<{ guardian_user_id: string }>(
      `SELECT DISTINCT sg.guardian_user_id
         FROM sis_student_enrollments e
         JOIN student_guardians sg ON sg.student_id = e.student_id
        WHERE e.school_id = $1
          AND e.is_current = true
          AND e.class_name = $2
          AND ($3::text IS NULL OR e.section_name = $3)
          AND sg.status = 'active'
          AND sg.organization_id = $4`,
      [schoolId, className, sectionName, orgId],
    );
    return rows.map((r) => r.guardian_user_id);
  }

  // COM-2: the students of one class (optionally one section). students.id ==
  // users.id, so the enrollment's student_id is the recipient user id.
  if (audience === "class_students") {
    if (!className || !schoolId) return [];
    const rows = await db.queryObject<{ user_id: string }>(
      `SELECT DISTINCT e.student_id AS user_id
         FROM sis_student_enrollments e
        WHERE e.school_id = $1
          AND e.is_current = true
          AND e.class_name = $2
          AND ($3::text IS NULL OR e.section_name = $3)`,
      [schoolId, className, sectionName],
    );
    return rows.map((r) => r.user_id);
  }

  if (!schoolId) {
    const rows = await db.queryObject<{ user_id: string }>(
      `SELECT DISTINCT user_id FROM school_memberships sm
       JOIN schools s ON s.id = sm.school_id
       WHERE s.organization_id = $1 AND sm.status = 'active'`,
      [orgId],
    );
    return rows.map((r) => r.user_id);
  }

  if (audience === "all_parents") {
    const rows = await db.queryObject<{ guardian_user_id: string }>(
      `SELECT DISTINCT guardian_user_id FROM student_guardians
       WHERE organization_id = $1 AND school_id = $2 AND status = 'active'`,
      [orgId, schoolId],
    );
    if (rows.length > 0) return rows.map((r) => r.guardian_user_id);
  }

  if (audience === "all_teachers" || audience === "school_wide") {
    const rows = await db.queryObject<{ user_id: string }>(
      `SELECT DISTINCT user_id FROM school_memberships
       WHERE school_id = $1 AND role IN ('teacher', 'principal', 'schoolAdmin')
         AND status = 'active'`,
      [schoolId],
    );
    if (audience === "all_teachers") {
      return rows.map((r) => r.user_id);
    }
    const parents = await db.queryObject<{ guardian_user_id: string }>(
      `SELECT DISTINCT guardian_user_id FROM student_guardians
       WHERE organization_id = $1 AND school_id = $2 AND status = 'active'`,
      [orgId, schoolId],
    );
    return [...new Set([
      ...rows.map((r) => r.user_id),
      ...parents.map((r) => r.guardian_user_id),
    ])];
  }

  if (audience === "all_students") {
    const rows = await db.queryObject<{ user_id: string }>(
      `SELECT DISTINCT u.id AS user_id
       FROM users u
       JOIN students st ON st.id = u.id
       WHERE st.organization_id = $1 AND st.school_id = $2`,
      [orgId, schoolId],
    );
    if (rows.length > 0) return rows.map((r) => r.user_id);
  }

  // All active staff of the school (teaching + non-teaching), unlike all_teachers
  // which is limited to teacher/principal/schoolAdmin.
  if (audience === "all_staff") {
    const rows = await db.queryObject<{ user_id: string }>(
      `SELECT DISTINCT user_id FROM school_memberships
       WHERE school_id = $1 AND status = 'active'`,
      [schoolId],
    );
    return rows.map((r) => r.user_id);
  }

  // INV-7: the school's storekeeper users (role seeded by migration 20260851).
  // Same org/school scoping as the all_staff branch. When the school has no
  // active storekeeper membership yet, fall back to the all-staff recipient set
  // so a low-stock alert is never silently dropped.
  if (audience === "storekeepers") {
    const rows = await db.queryObject<{ user_id: string }>(
      `SELECT DISTINCT user_id FROM school_memberships
       WHERE school_id = $1 AND role = 'storekeeper' AND status = 'active'`,
      [schoolId],
    );
    if (rows.length > 0) return rows.map((r) => r.user_id);
    const staff = await db.queryObject<{ user_id: string }>(
      `SELECT DISTINCT user_id FROM school_memberships
       WHERE school_id = $1 AND status = 'active'`,
      [schoolId],
    );
    return staff.map((r) => r.user_id);
  }

  return [];
}

export async function getNotificationDeliveryMetrics(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<{ sent: number; pending: number; failed: number; total: number }> {
  const rows = await db.queryObject<{ status: string; count: string }>(
    `SELECT status, count(*)::text AS count
     FROM notification_deliveries
     WHERE organization_id = $1 AND school_id = $2
     GROUP BY status`,
    [orgId, schoolId],
  );
  let sent = 0;
  let pending = 0;
  let failed = 0;
  for (const row of rows) {
    const count = Number(row.count);
    if (row.status === "sent") sent += count;
    else if (row.status === "pending") pending += count;
    else if (row.status === "failed") failed += count;
  }
  return { sent, pending, failed, total: sent + pending + failed };
}

/**
 * COM-D1: record a recipient's acknowledgement of one delivery. Sets
 * `acknowledged_at` (the receipt timestamp) and marks it read, scoped to the
 * caller's own delivery row (org + recipient). The recipient RLS policy already
 * enforces ownership; the explicit `recipient_user_id = $2` predicate is
 * defense-in-depth so even a service-role caller can only ack the owner's row.
 * Returns the acked id, or null when no such delivery is visible → the handler
 * maps that to a 404 (never leaks whether the id exists for another recipient).
 */
export async function acknowledgeDelivery(
  db: TenantQueryClient,
  orgId: string,
  userId: string,
  deliveryId: string,
): Promise<{ id: string; acknowledged_at: string } | null> {
  const rows = await db.queryObject<{ id: string; acknowledged_at: string }>(
    `UPDATE notification_deliveries
        SET acknowledged_at = timezone('utc', now()),
            is_read = true,
            updated_at = timezone('utc', now())
      WHERE id = $1::uuid
        AND recipient_user_id = $2
        AND organization_id = $3
      RETURNING id, acknowledged_at`,
    [deliveryId, userId, orgId],
  );
  return rows[0] ?? null;
}

/** COM-2: list the saved audience segments for the caller's school. */
export async function listAudienceSegments(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<CommAudienceSegmentRow[]> {
  return await db.queryObject<CommAudienceSegmentRow>(
    `SELECT * FROM comm_audience_segments
      WHERE organization_id = $1 AND school_id = $2
      ORDER BY name`,
    [orgId, schoolId],
  );
}

/** COM-2: persist a new saved audience segment for the caller's school. */
export async function createAudienceSegment(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    name: string;
    audienceType: string;
    className: string | null;
    sectionName: string | null;
    createdBy: string;
  },
): Promise<CommAudienceSegmentRow> {
  const rows = await db.queryObject<CommAudienceSegmentRow>(
    `INSERT INTO comm_audience_segments (
       organization_id, school_id, name, audience_type,
       class_name, section_name, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.name,
      input.audienceType,
      input.className,
      input.sectionName,
      input.createdBy,
    ],
  );
  return rows[0]!;
}

/**
 * COM-2: delete a saved audience segment scoped to the caller's school. Returns
 * the deleted id, or null when no matching segment is visible → the handler maps
 * that to a 404.
 */
export async function deleteAudienceSegment(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  id: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ id: string }>(
    `DELETE FROM comm_audience_segments
      WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3
      RETURNING id`,
    [id, orgId, schoolId],
  );
  return rows[0]?.id ?? null;
}
