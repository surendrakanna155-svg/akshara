import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { correlationIdFromRequest, recordMutationAudit } from "../audit/audit_repository.ts";
import { loadNotificationProviderConfig } from "./notification_provider_config.ts";
import { sendViaProvider } from "./notification_providers.ts";
import { renderTemplate } from "./template_renderer.ts";
import {
  enqueueDelivery,
  fetchActiveDeviceToken,
  fetchPendingDeliveries,
  getTemplateByCode,
  markDeliveryFailed,
  markDeliverySent,
  type NotificationDeliveryRow,
} from "./communication_repository.ts";

export interface EnqueueFromTemplateInput {
  templateCode: string;
  variables: Record<string, string>;
  recipientUserId: string;
  category?: string;
  childContext?: string | null;
}

export async function enqueueFromTemplate(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: EnqueueFromTemplateInput,
): Promise<NotificationDeliveryRow> {
  const schoolId = claims.school_id;
  if (!schoolId) {
    throw new Error("School context required for notification enqueue");
  }
  const template = await getTemplateByCode(db, claims.tenant_id, schoolId, input.templateCode);
  if (!template) {
    throw new Error(`Template not found: ${input.templateCode}`);
  }
  const subject = template.subject_template
    ? renderTemplate(template.subject_template, input.variables)
    : null;
  const body = renderTemplate(template.body_template, input.variables);
  return await enqueueDelivery(db, {
    organizationId: claims.tenant_id,
    schoolId,
    recipientUserId: input.recipientUserId,
    channel: template.channel,
    templateId: template.id,
    category: input.category ?? "announcement",
    renderedSubject: subject,
    renderedBody: body,
    childContext: input.childContext,
  });
}

export async function processDeliveryQueue(
  db: TenantQueryClient,
  orgId: string,
  claims?: AccessTokenClaims,
  req?: Request,
): Promise<{ processed: number; sent: number; failed: number }> {
  const config = loadNotificationProviderConfig();
  const pending = await fetchPendingDeliveries(db, orgId);
  let sent = 0;
  let failed = 0;

  for (const delivery of pending) {
    const deviceToken = delivery.channel === "push"
      ? await fetchActiveDeviceToken(db, orgId, delivery.recipient_user_id)
      : null;
    const result = await sendViaProvider(config, {
      channel: delivery.channel as "sms" | "email" | "push",
      recipientUserId: delivery.recipient_user_id,
      subject: delivery.rendered_subject,
      body: delivery.rendered_body,
      deviceToken,
      notificationId: delivery.id,
      category: delivery.category,
      childContext: delivery.child_context ?? null,
    });
    if (result.success) {
      await markDeliverySent(db, delivery.id, result.providerRef);
      sent += 1;
    } else {
      await markDeliveryFailed(db, delivery, result.error ?? "delivery failed");
      failed += 1;
    }
  }

  if (claims && sent > 0) {
    await recordMutationAudit(
      db,
      claims,
      {
        eventType: "notificationBatchProcessed",
        category: "workflow",
        entityType: "notification_delivery",
        metadata: { processed: pending.length, sent, failed },
        correlationId: req ? correlationIdFromRequest(req) : undefined,
      },
      {
        eventType: "notification.batch_processed",
        payload: { processed: pending.length, sent, failed },
        sourceModule: "communication",
        idempotencyKey: `notification.batch:${orgId}:${Date.now()}`,
      },
      req,
    );
  }

  return { processed: pending.length, sent, failed };
}

export async function enqueueNotificationRequested(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  recipientUserId: string,
  title: string,
  body: string,
  category = "announcement",
): Promise<NotificationDeliveryRow> {
  return await enqueueDelivery(db, {
    organizationId: orgId,
    schoolId,
    recipientUserId,
    channel: "push",
    category,
    renderedSubject: title,
    renderedBody: body,
  });
}
