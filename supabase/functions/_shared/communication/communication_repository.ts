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
  title: string;
  body: string;
  status: string;
  scheduled_at: string | null;
  sent_at: string | null;
  created_by: string;
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
  },
): Promise<NotificationDeliveryRow> {
  const rows = await db.queryObject<NotificationDeliveryRow>(
    `INSERT INTO notification_deliveries (
       organization_id, school_id, recipient_user_id, channel, template_id,
       category, rendered_subject, rendered_body, child_context, status
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending')
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
  ];
  const values = input.recipientUserIds.map((userId, i) => {
    params.push(userId);
    return `($1, $2, $${i + 7}, $3, $4, $5, $6, 'pending')`;
  });
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO notification_deliveries (
       organization_id, school_id, recipient_user_id, channel,
       category, rendered_subject, rendered_body, status
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
    title: string;
    body: string;
    createdBy: string;
  },
): Promise<CommBroadcastRow> {
  const rows = await db.queryObject<CommBroadcastRow>(
    `INSERT INTO comm_broadcasts (
       organization_id, school_id, audience, title, body, status, created_by
     ) VALUES ($1, $2, $3, $4, $5, 'sending', $6)
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.audience,
      input.title,
      input.body,
      input.createdBy,
    ],
  );
  return rows[0]!;
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
): Promise<string[]> {
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
