import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { enqueueFromTemplate } from "../communication/notification_service.ts";
import { getWhatsAppProviderConfig, whatsAppConfigToRuntime } from "./whatsapp_repository.ts";
import { sendWhatsAppMessage } from "./whatsapp_providers.ts";

export interface DeliveryEventRow {
  id: string;
  channel: string;
  template_code: string | null;
  recipient_label: string;
  status: string;
  provider_ref: string | null;
  error_message: string | null;
  created_at: string;
}

export interface DeliveryAnalytics {
  totalSent: number;
  totalFailed: number;
  totalPending: number;
  deliveryRate: number;
  byChannel: Record<string, { sent: number; failed: number; pending: number }>;
  recentEvents: DeliveryEventRow[];
}

export async function recordDeliveryEvent(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: {
    channel: string;
    templateCode?: string;
    recipientLabel: string;
    status: string;
    providerRef?: string;
    errorMessage?: string;
  },
): Promise<DeliveryEventRow> {
  const rows = await db.queryObject<DeliveryEventRow>(
    `INSERT INTO communication_delivery_events (
       organization_id, school_id, channel, template_code, recipient_label,
       status, provider_ref, error_message
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id, channel, template_code, recipient_label, status, provider_ref, error_message, created_at::text`,
    [
      orgId,
      schoolId,
      input.channel,
      input.templateCode ?? null,
      input.recipientLabel,
      input.status,
      input.providerRef ?? null,
      input.errorMessage ?? null,
    ],
  );
  return rows[0]!;
}

export async function getDeliveryAnalytics(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<DeliveryAnalytics> {
  const stats = await db.queryObject<{ channel: string; status: string; count: string }>(
    `SELECT channel, status, count(*)::text AS count
     FROM communication_delivery_events
     WHERE organization_id = $1 AND school_id = $2
     GROUP BY channel, status`,
    [orgId, schoolId],
  );

  const recent = await db.queryObject<DeliveryEventRow>(
    `SELECT id, channel, template_code, recipient_label, status, provider_ref, error_message, created_at::text
     FROM communication_delivery_events
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY created_at DESC LIMIT 20`,
    [orgId, schoolId],
  );

  let totalSent = 0;
  let totalFailed = 0;
  let totalPending = 0;
  const byChannel: DeliveryAnalytics["byChannel"] = {};

  for (const row of stats) {
    const count = Number(row.count);
    const ch = byChannel[row.channel] ?? { sent: 0, failed: 0, pending: 0 };
    if (row.status === "sent" || row.status === "delivered") {
      ch.sent += count;
      totalSent += count;
    } else if (row.status === "failed") {
      ch.failed += count;
      totalFailed += count;
    } else {
      ch.pending += count;
      totalPending += count;
    }
    byChannel[row.channel] = ch;
  }

  const total = totalSent + totalFailed + totalPending;
  const deliveryRate = total > 0 ? Math.round((totalSent / total) * 100) : 100;

  return {
    totalSent,
    totalFailed,
    totalPending,
    deliveryRate,
    byChannel,
    recentEvents: recent,
  };
}

export async function sendSchoolTemplateMessage(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: {
    templateCode: string;
    recipientUserId: string;
    variables: Record<string, string>;
    channel?: string;
  },
): Promise<{ deliveryId: string; channel: string; status: string }> {
  const orgId = claims.tenant_id;
  const schoolId = claims.school_id!;
  const channel = input.channel ?? "in_app";

  if (channel === "whatsapp") {
    const config = await getWhatsAppProviderConfig(db, orgId, schoolId);
    const runtime = whatsAppConfigToRuntime(config);
    const body = Object.entries(input.variables)
      .map(([k, v]) => `${k}: ${v}`)
      .join("\n");
    const result = await sendWhatsAppMessage(runtime, {
      toPhone: input.variables.phone ?? input.recipientUserId,
      templateId: input.templateCode,
      body,
    });
    const event = await recordDeliveryEvent(db, orgId, schoolId, {
      channel: "whatsapp",
      templateCode: input.templateCode,
      recipientLabel: input.variables.phone ?? input.recipientUserId,
      status: result.success ? "sent" : "failed",
      providerRef: result.providerRef ?? undefined,
      errorMessage: result.error ?? undefined,
    });
    return { deliveryId: event.id, channel: "whatsapp", status: event.status };
  }

  const delivery = await enqueueFromTemplate(db, claims, {
    templateCode: input.templateCode,
    recipientUserId: input.recipientUserId,
    variables: input.variables,
  });
  const event = await recordDeliveryEvent(db, orgId, schoolId, {
    channel: delivery.channel,
    templateCode: input.templateCode,
    recipientLabel: input.recipientUserId,
    status: delivery.status,
  });
  return { deliveryId: event.id, channel: delivery.channel, status: event.status };
}

export function deliveryAnalyticsToApi(analytics: DeliveryAnalytics) {
  return {
    totalSent: analytics.totalSent,
    totalFailed: analytics.totalFailed,
    totalPending: analytics.totalPending,
    deliveryRate: analytics.deliveryRate,
    byChannel: analytics.byChannel,
    recentEvents: analytics.recentEvents.map((e) => ({
      id: e.id,
      channel: e.channel,
      templateCode: e.template_code,
      recipientLabel: e.recipient_label,
      status: e.status,
      providerRef: e.provider_ref,
      errorMessage: e.error_message,
      createdAt: e.created_at,
    })),
  };
}
