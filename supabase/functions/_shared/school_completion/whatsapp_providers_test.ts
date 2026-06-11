import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { sendWhatsAppMessage } from "./whatsapp_providers.ts";

Deno.test("stub WhatsApp provider returns success", async () => {
  const result = await sendWhatsAppMessage(
    { provider: "stub", senderId: "AKSHARA", apiKeyRef: null, templateNamespace: null, isActive: true },
    { toPhone: "+919999999999", templateId: "test_template" },
  );
  assertEquals(result.success, true);
  assertEquals(result.error, null);
});

Deno.test("inactive WhatsApp provider is rejected", async () => {
  const result = await sendWhatsAppMessage(
    { provider: "stub", senderId: null, apiKeyRef: null, templateNamespace: null, isActive: false },
    { toPhone: "+919999999999", templateId: "test_template" },
  );
  assertEquals(result.success, false);
});
