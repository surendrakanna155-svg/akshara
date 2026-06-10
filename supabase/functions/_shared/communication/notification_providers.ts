import type { NotificationChannel, NotificationProviderConfig } from "./notification_provider_config.ts";

export interface DeliveryPayload {
  channel: NotificationChannel;
  recipientUserId: string;
  subject: string | null;
  body: string;
  deviceToken?: string | null;
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
  }
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
  if (!config.push.serverKey || !payload.deviceToken) {
    return { success: false, providerRef: null, error: "Push provider or device token missing" };
  }
  const response = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      Authorization: `key=${config.push.serverKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      to: payload.deviceToken,
      notification: {
        title: payload.subject ?? "Akshara ERP",
        body: payload.body,
      },
    }),
  });
  if (!response.ok) {
    return { success: false, providerRef: null, error: await response.text() };
  }
  const data = await response.json() as { message_id?: number; multicast_id?: number };
  return {
    success: true,
    providerRef: String(data.message_id ?? data.multicast_id ?? ""),
    error: null,
  };
}
