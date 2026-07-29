import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { whatsAppConfigToApi, whatsAppConfigToRuntime } from "./whatsapp_repository.ts";

// GAP-P1-9: an unconfigured school (no whatsapp_provider_configs row) must
// never be reported as an active, working WhatsApp integration.

Deno.test("whatsAppConfigToApi reports an unconfigured school as inactive (admin status honesty)", () => {
  const api = whatsAppConfigToApi(null);
  assertEquals(api.provider, "stub");
  assertEquals(api.isActive, false);
});

Deno.test("whatsAppConfigToRuntime still routes an unconfigured school through the stub branch", () => {
  // Deliberately isActive:true here (unlike the API-facing default above) so
  // sendWhatsAppMessage reaches its "stub" case and returns the specific
  // "not configured" error rather than the generic "inactive" guard — either
  // way sendWhatsAppMessage now reports success:false (see whatsapp_providers_test.ts).
  const runtime = whatsAppConfigToRuntime(null);
  assertEquals(runtime.provider, "stub");
  assertEquals(runtime.isActive, true);
});

Deno.test("whatsAppConfigToApi passes through a real configured row unchanged", () => {
  const api = whatsAppConfigToApi({
    id: "cfg-1",
    organization_id: "org-1",
    school_id: "school-1",
    provider: "msg91",
    sender_id: "NIKSHA",
    api_key_ref: "secret-key",
    template_namespace: "akshara_ns",
    is_active: true,
  });
  assertEquals(api.provider, "msg91");
  assertEquals(api.isActive, true);
  // API-facing DTO redacts the raw key.
  assertEquals(api.apiKeyRef, "***");
});
