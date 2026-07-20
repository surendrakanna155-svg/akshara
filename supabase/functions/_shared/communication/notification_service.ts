import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { correlationIdFromRequest, recordMutationAudit } from "../audit/audit_repository.ts";
import { loadNotificationProviderConfig } from "./notification_provider_config.ts";
import type { NotificationChannel } from "./notification_provider_config.ts";
import { sendViaProvider } from "./notification_providers.ts";
import { renderTemplate } from "./template_renderer.ts";
import { localizeNotification, normalizeParentLanguage } from "./parent_comms_localization.ts";
import { computeEscalationTarget } from "./communication_escalation.ts";
import {
  type ChannelPolicyRow,
  claimPendingDeliveries,
  enqueueDelivery,
  fetchActiveDeviceToken,
  getChannelPolicy,
  getTemplateByCode,
  markDeliveryFailed,
  markDeliverySent,
  type NotificationDeliveryRow,
} from "./communication_repository.ts";
import type { WhatsAppProviderConfig } from "../school_completion/whatsapp_providers.ts";
import { getWhatsAppProviderConfig, whatsAppConfigToRuntime } from "../school_completion/whatsapp_repository.ts";

export interface EnqueueFromTemplateInput {
  templateCode: string;
  variables: Record<string, string>;
  recipientUserId: string;
  category?: string;
  childContext?: string | null;
  route?: string | null;
  /**
   * QA-C-016: the recipient PARENT's preferred language (e.g. "te"). When set to
   * a non-English supported language AND the template has a catalog variant, the
   * subject/body are rendered from the deterministic parent-comms catalog (no
   * LLM). Omitted / "en" / non-parent recipients keep the English DB template.
   */
  recipientLanguage?: string | null;
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
  // QA-C-016: deterministic, catalog-based parent-language localization. Only a
  // non-English supported parent language with a catalogued template is localized;
  // every other case keeps the existing English DB-template render (no regression,
  // no LLM).
  const language = normalizeParentLanguage(input.recipientLanguage);
  const localized = language === "en"
    ? null
    : localizeNotification(input.templateCode, language, input.variables);
  const subject = localized
    ? localized.subject
    : template.subject_template
    ? renderTemplate(template.subject_template, input.variables)
    : null;
  const body = localized
    ? localized.body
    : renderTemplate(template.body_template, input.variables);
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
    route: input.route ?? null,
  });
}

export async function processDeliveryQueue(
  db: TenantQueryClient,
  orgId: string,
  claims?: AccessTokenClaims,
  req?: Request,
): Promise<{ processed: number; sent: number; failed: number; escalated: number }> {
  const config = loadNotificationProviderConfig();
  // P5 (red-team #1): CLAIM the due deliveries (pending → sending) instead of a
  // plain read, so two concurrent drains for this org get disjoint sets and no
  // message/escalation is duplicated.
  const pending = await claimPendingDeliveries(db, orgId);
  let sent = 0;
  let failed = 0;
  let escalated = 0;
  // Per-school caches: WhatsApp provider config and escalation policy are
  // school-scoped, but one org's pending batch can span several schools.
  const whatsappCache = new Map<string, WhatsAppProviderConfig>();
  const policyCache = new Map<string, ChannelPolicyRow | null>();

  for (const delivery of pending) {
    const deviceToken = delivery.channel === "push"
      ? await fetchActiveDeviceToken(db, orgId, delivery.recipient_user_id)
      : null;
    const whatsappConfig = delivery.channel === "whatsapp"
      ? await resolveWhatsappConfig(db, orgId, delivery.school_id, whatsappCache)
      : null;
    const result = await sendViaProvider(config, {
      channel: delivery.channel as NotificationChannel,
      recipientUserId: delivery.recipient_user_id,
      subject: delivery.rendered_subject,
      body: delivery.rendered_body,
      deviceToken,
      whatsappConfig,
      notificationId: delivery.id,
      category: delivery.category,
      childContext: delivery.child_context ?? null,
      route: delivery.route ?? null,
    });
    if (result.success) {
      await markDeliverySent(db, delivery.id, result.providerRef);
      sent += 1;
    } else {
      const { terminal } = await markDeliveryFailed(db, delivery, result.error ?? "delivery failed");
      failed += 1;
      // Batch 6: only a TERMINAL failure (retries exhausted) escalates — the
      // primary channel has genuinely given up. A school with no active policy
      // never escalates, so existing behaviour is unchanged.
      if (terminal && delivery.school_id) {
        const didEscalate = await maybeEscalate(db, orgId, delivery, policyCache);
        if (didEscalate) escalated += 1;
      }
    }
  }

  if (claims && (sent > 0 || escalated > 0)) {
    await recordMutationAudit(
      db,
      claims,
      {
        eventType: "notificationBatchProcessed",
        category: "workflow",
        entityType: "notification_delivery",
        metadata: { processed: pending.length, sent, failed, escalated },
        correlationId: req ? correlationIdFromRequest(req) : undefined,
      },
      {
        eventType: "notification.batch_processed",
        payload: { processed: pending.length, sent, failed, escalated },
        sourceModule: "communication",
        idempotencyKey: `notification.batch:${orgId}:${Date.now()}`,
      },
      req,
    );
  }

  return { processed: pending.length, sent, failed, escalated };
}

/** Batch 6: load (and cache) the school's WhatsApp runtime config. An
 * unconfigured school resolves to the 'stub' config whose send returns an honest
 * "not configured" failure — never a fabricated success. */
async function resolveWhatsappConfig(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string | null,
  cache: Map<string, WhatsAppProviderConfig>,
): Promise<WhatsAppProviderConfig> {
  if (!schoolId) return whatsAppConfigToRuntime(null);
  const cached = cache.get(schoolId);
  if (cached) return cached;
  const row = await getWhatsAppProviderConfig(db, orgId, schoolId);
  const runtime = whatsAppConfigToRuntime(row);
  cache.set(schoolId, runtime);
  return runtime;
}

/** Batch 6: on a terminally-failed delivery, consult the school's escalation
 * policy and enqueue a fresh delivery on the next channel in the chain. Returns
 * whether an escalation was enqueued. The new delivery is picked up by the next
 * drain pass (it is not in this pass's snapshot), so there is no re-entrancy. */
async function maybeEscalate(
  db: TenantQueryClient,
  orgId: string,
  delivery: NotificationDeliveryRow,
  policyCache: Map<string, ChannelPolicyRow | null>,
): Promise<boolean> {
  const schoolId = delivery.school_id!;
  let policy = policyCache.get(schoolId);
  if (policy === undefined) {
    policy = await getChannelPolicy(db, orgId, schoolId);
    policyCache.set(schoolId, policy);
  }
  const target = computeEscalationTarget(
    policy ? { escalationChain: policy.escalation_chain, isActive: policy.is_active } : null,
    delivery.channel,
    delivery.escalation_depth,
  );
  if (!target) return false;
  await enqueueDelivery(db, {
    organizationId: orgId,
    schoolId,
    recipientUserId: delivery.recipient_user_id,
    channel: target,
    templateId: delivery.template_id,
    category: delivery.category,
    renderedSubject: delivery.rendered_subject,
    renderedBody: delivery.rendered_body,
    childContext: delivery.child_context,
    route: delivery.route,
    escalatedFrom: delivery.id,
    escalationDepth: delivery.escalation_depth + 1,
  });
  return true;
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
