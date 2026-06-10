export type NotificationChannel = "sms" | "email" | "push";

export interface NotificationProviderConfig {
  sms: { stubMode: boolean; accountSid: string | null; authToken: string | null; fromNumber: string | null };
  email: { stubMode: boolean; apiKey: string | null; fromEmail: string | null };
  push: { stubMode: boolean; serverKey: string | null };
}

export function loadNotificationProviderConfig(): NotificationProviderConfig {
  const smsStub = (Deno.env.get("SMS_STUB_MODE") ?? "true").toLowerCase() === "true";
  const emailStub = (Deno.env.get("EMAIL_STUB_MODE") ?? "true").toLowerCase() === "true";
  const pushStub = (Deno.env.get("FCM_STUB_MODE") ?? "true").toLowerCase() === "true";

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
      stubMode: pushStub || !Deno.env.get("FCM_SERVER_KEY"),
      serverKey: Deno.env.get("FCM_SERVER_KEY") ?? null,
    },
  };
}
