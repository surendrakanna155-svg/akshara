import { fcmV1Configured } from "./fcm_v1_client.ts";

export type NotificationChannel = "sms" | "email" | "push" | "whatsapp";

export interface NotificationProviderConfig {
  sms: { stubMode: boolean; accountSid: string | null; authToken: string | null; fromNumber: string | null };
  email: { stubMode: boolean; apiKey: string | null; fromEmail: string | null };
  // Push uses FCM HTTP v1 (service-account auth). `configured` is true when a
  // valid service account is present; otherwise push runs in stub mode.
  push: { stubMode: boolean; configured: boolean };
}

export function loadNotificationProviderConfig(): NotificationProviderConfig {
  const smsStub = (Deno.env.get("SMS_STUB_MODE") ?? "true").toLowerCase() === "true";
  const emailStub = (Deno.env.get("EMAIL_STUB_MODE") ?? "true").toLowerCase() === "true";
  const pushStub = (Deno.env.get("FCM_STUB_MODE") ?? "true").toLowerCase() === "true";
  const pushConfigured = fcmV1Configured();

  return {
    sms: {
      stubMode: smsStub || !Deno.env.get("TWILIO_ACCOUNT_SID"),
      accountSid: Deno.env.get("TWILIO_ACCOUNT_SID") ?? null,
      authToken: Deno.env.get("TWILIO_AUTH_TOKEN") ?? null,
      fromNumber: Deno.env.get("TWILIO_FROM_NUMBER") ?? null,
    },
    email: {
      stubMode: emailStub || !Deno.env.get("SENDGRID_API_KEY"),
      apiKey: Deno.env.get("SENDGRID_API_KEY") ?? null,
      fromEmail: Deno.env.get("SENDGRID_FROM_EMAIL") ?? null,
    },
    push: {
      stubMode: pushStub || !pushConfigured,
      configured: pushConfigured,
    },
  };
}
