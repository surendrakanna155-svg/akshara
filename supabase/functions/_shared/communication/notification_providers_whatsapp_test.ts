import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { sendViaProvider } from "./notification_providers.ts";
import type { NotificationProviderConfig } from "./notification_provider_config.ts";
import { whatsAppConfigToRuntime } from "../school_completion/whatsapp_repository.ts";

// The env-based provider config is irrelevant to the WhatsApp branch (it uses the
// per-school config threaded through the payload), but sendViaProvider requires it.
const ENV_CONFIG: NotificationProviderConfig = {
  sms: { stubMode: true, accountSid: null, authToken: null, fromNumber: null },
  email: { stubMode: true, apiKey: null, fromEmail: null },
  push: { stubMode: true, configured: false },
};

Deno.test("Batch 6: a 'whatsapp' delivery routes to the WhatsApp provider, not sms/email/push", async () => {
  // An unconfigured school resolves to the 'stub' runtime config (whatsAppConfigToRuntime(null)).
  // The honest result is a NOT-configured failure — never a fabricated 'sent' (GAP-P1-9).
  const result = await sendViaProvider(ENV_CONFIG, {
    channel: "whatsapp",
    recipientUserId: "919000000000",
    subject: null,
    body: "Fee due reminder",
    whatsappConfig: whatsAppConfigToRuntime(null),
    category: "fee",
  });
  assertEquals(result.success, false);
  assertEquals(result.providerRef, null);
  assertStringIncludes(result.error ?? "", "not configured for this school");
});

Deno.test("Batch 6: a 'whatsapp' delivery with no per-school config fails closed", async () => {
  const result = await sendViaProvider(ENV_CONFIG, {
    channel: "whatsapp",
    recipientUserId: "919000000000",
    subject: null,
    body: "Hello",
    // whatsappConfig omitted
    category: "announcement",
  });
  assertEquals(result.success, false);
  assertStringIncludes(result.error ?? "", "config missing");
});

Deno.test("Batch 6: an inactive WhatsApp provider is not sent (fail closed)", async () => {
  const result = await sendViaProvider(ENV_CONFIG, {
    channel: "whatsapp",
    recipientUserId: "919000000000",
    subject: null,
    body: "Hello",
    whatsappConfig: {
      provider: "msg91",
      senderId: "AKSHARA",
      apiKeyRef: "key",
      templateNamespace: null,
      isActive: false,
    },
    category: "announcement",
  });
  assertEquals(result.success, false);
  assertStringIncludes(result.error ?? "", "inactive");
});
