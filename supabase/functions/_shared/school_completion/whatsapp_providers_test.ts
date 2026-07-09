import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { sendWhatsAppMessage } from "./whatsapp_providers.ts";

// GAP-P1-9: "stub" is the fallback for an unconfigured school (see
// whatsAppConfigToRuntime's default). It used to report success:true, which
// fabricated 100% delivery on every dashboard for a school that never sent a
// single real WhatsApp message. It must now fail honestly instead.
Deno.test("stub WhatsApp provider (unconfigured school) reports failure, not fake success", async () => {
  const result = await sendWhatsAppMessage(
    { provider: "stub", senderId: "AKSHARA", apiKeyRef: null, templateNamespace: null, isActive: true },
    { toPhone: "+919999999999", templateId: "test_template" },
  );
  assertEquals(result.success, false);
  assertEquals(result.providerRef, null);
  assertStringIncludes(result.error ?? "", "not configured");
});

Deno.test("inactive WhatsApp provider is rejected", async () => {
  const result = await sendWhatsAppMessage(
    { provider: "stub", senderId: null, apiKeyRef: null, templateNamespace: null, isActive: false },
    { toPhone: "+919999999999", templateId: "test_template" },
  );
  assertEquals(result.success, false);
});

// Real-provider paths are untouched by the stub fix: msg91/gupshup still fail
// their own way (missing credentials) rather than being coerced through the
// stub branch, and a fully-configured real provider is unaffected (only the
// credential-presence guard is exercised here — no network call is made).
Deno.test("msg91 with no credentials still fails on its own (not silently stubbed)", async () => {
  const result = await sendWhatsAppMessage(
    { provider: "msg91", senderId: null, apiKeyRef: null, templateNamespace: null, isActive: true },
    { toPhone: "+919999999999", templateId: "test_template" },
  );
  assertEquals(result.success, false);
  assertStringIncludes(result.error ?? "", "MSG91 not configured");
});

Deno.test("gupshup with no credentials still fails on its own (not silently stubbed)", async () => {
  const result = await sendWhatsAppMessage(
    { provider: "gupshup", senderId: null, apiKeyRef: null, templateNamespace: null, isActive: true },
    { toPhone: "+919999999999", templateId: "test_template" },
  );
  assertEquals(result.success, false);
  assertStringIncludes(result.error ?? "", "Gupshup not configured");
});
