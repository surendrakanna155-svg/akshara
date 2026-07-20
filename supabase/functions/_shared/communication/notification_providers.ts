import type { NotificationChannel, NotificationProviderConfig } from "./notification_provider_config.ts";
import { sendFcmV1 } from "./fcm_v1_client.ts";
import type { WhatsAppProviderConfig } from "../school_completion/whatsapp_providers.ts";
import { sendWhatsAppMessage } from "../school_completion/whatsapp_providers.ts";

export interface DeliveryPayload {
  channel: NotificationChannel;
  recipientUserId: string;
  subject: string | null;
  body: string;
  deviceToken?: string | null;
  // Optional metadata forwarded to the FCM `data` payload so the app can route
  // the tap and refresh the right inbox entry.
  notificationId?: string | null;
  category?: string | null;
  childContext?: string | null;
  route?: string | null;
  // Batch 6: the recipient's WhatsApp destination (phone). When the channel is
  // 'whatsapp' the drain resolves the delivery to a phone number and passes the
  // per-school provider config below.
  recipientPhone?: string | null;
  // Batch 6: per-school WhatsApp provider config, loaded by the drain from
  // whatsapp_provider_configs. Absent/unconfigured schools resolve to a 'stub'
  // config whose send honestly returns success:false ("not configured").
  whatsappConfig?: WhatsAppProviderConfig | null;
}

export interface DeliveryResult {
  success: boolean;
  providerRef: string | null;
  error: string | null;
}

export async function sendViaProvider(
  config: NotificationProviderConfig,
  payload: DeliveryPayload,
): Promise<DeliveryResult> {
  switch (payload.channel) {
    case "sms":
      return await sendSms(config, payload);
    case "email":
      return await sendEmail(config, payload);
    case "push":
      return await sendPush(config, payload);
    case "whatsapp":
      return await sendWhatsApp(payload);
  }
}

async function sendWhatsApp(payload: DeliveryPayload): Promise<DeliveryResult> {
  // Batch 6: route WhatsApp through the EXISTING school_completion provider
  // (msg91/gupshup). The per-school config is threaded in by the drain; an
  // unconfigured school arrives here with a 'stub' config, and
  // sendWhatsAppMessage returns its honest "not configured" failure — never a
  // fabricated success. The template body is the already-rendered delivery body.
  if (!payload.whatsappConfig) {
    return { success: false, providerRef: null, error: "WhatsApp provider config missing" };
  }
  return await sendWhatsAppMessage(payload.whatsappConfig, {
    toPhone: payload.recipientPhone ?? payload.recipientUserId,
    templateId: payload.category ?? "notification",
    body: payload.body,
  });
}

async function sendSms(
  config: NotificationProviderConfig,
  payload: DeliveryPayload,
): Promise<DeliveryResult> {
  if (config.sms.stubMode) {
    return {
      success: true,
      providerRef: `sms_stub_${crypto.randomUUID().slice(0, 8)}`,
      error: null,
    };
  }
  if (!config.sms.accountSid || !config.sms.authToken || !config.sms.fromNumber) {
    return { success: false, providerRef: null, error: "SMS provider not configured" };
  }
  const auth = btoa(`${config.sms.accountSid}:${config.sms.authToken}`);
  const response = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${config.sms.accountSid}/Messages.json`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${auth}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        To: payload.recipientUserId,
        From: config.sms.fromNumber,
        Body: payload.body,
      }),
    },
  );
  if (!response.ok) {
    return { success: false, providerRef: null, error: await response.text() };
  }
  const data = await response.json() as { sid?: string };
  return { success: true, providerRef: data.sid ?? null, error: null };
}

async function sendEmail(
  config: NotificationProviderConfig,
  payload: DeliveryPayload,
): Promise<DeliveryResult> {
  if (config.email.stubMode) {
    return {
      success: true,
      providerRef: `email_stub_${crypto.randomUUID().slice(0, 8)}`,
      error: null,
    };
  }
  if (!config.email.apiKey || !config.email.fromEmail) {
    return { success: false, providerRef: null, error: "Email provider not configured" };
  }
  const response = await fetch("https://api.sendgrid.com/v3/mail/send", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${config.email.apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      personalizations: [{ to: [{ email: payload.recipientUserId }] }],
      from: { email: config.email.fromEmail },
      subject: payload.subject ?? "Akshara ERP",
      content: [{ type: "text/plain", value: payload.body }],
    }),
  });
  if (!response.ok) {
    return { success: false, providerRef: null, error: await response.text() };
  }
  return {
    success: true,
    providerRef: response.headers.get("x-message-id"),
    error: null,
  };
}

async function sendPush(
  config: NotificationProviderConfig,
  payload: DeliveryPayload,
): Promise<DeliveryResult> {
  if (config.push.stubMode) {
    return {
      success: true,
      providerRef: `push_stub_${crypto.randomUUID().slice(0, 8)}`,
      error: null,
    };
  }
  if (!config.push.configured || !payload.deviceToken) {
    return { success: false, providerRef: null, error: "Push provider or device token missing" };
  }
  // Modern FCM HTTP v1 (service-account auth) — the legacy server-key API is
  // retired. `data` values must be strings; nulls are dropped.
  const data: Record<string, string> = {};
  if (payload.notificationId) data.notification_id = payload.notificationId;
  if (payload.category) data.category = payload.category;
  if (payload.childContext) data.child_context = payload.childContext;
  if (payload.route) data.route = payload.route;

  const result = await sendFcmV1({
    token: payload.deviceToken,
    title: payload.subject ?? "Akshara ERP",
    body: payload.body,
    data,
  });
  if (!result.success) {
    return { success: false, providerRef: null, error: result.error };
  }
  return { success: true, providerRef: result.messageId, error: null };
}
