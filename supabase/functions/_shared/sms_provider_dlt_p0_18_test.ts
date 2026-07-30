// PRA-P0-18 (S5): transactional SMS must honour the DLT (TRAI) route.
//
// `buildTransactionalRequest` previously HARD-CODED the Quick ("q") route and
// ignored the DLT config entirely, so fee-receipt and exam-result SMS were sent
// on the unregistered Quick route, which Indian carriers block to DND numbers
// (most parent mobiles). These pin the two branches: the pilot's Quick route is
// unchanged, and a `fast2smsRoute === 'dlt'` config now emits a proper DLT
// request (sender_id + template message id + variables_values), with an optional
// per-message-type `templateId` overriding the global message id. The final test
// stubs fetch to prove `sendTransactionalSms` threads `templateId` all the way
// to the wire.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildTransactionalRequest,
  sendTransactionalSms,
  type SmsConfig,
} from "./sms_provider.ts";

const quickConfig: SmsConfig = {
  provider: "fast2sms",
  apiKey: "FAST2SMS_KEY",
  fast2smsRoute: "q",
  fast2smsSenderId: null,
  fast2smsMessageId: null,
};

const dltConfig: SmsConfig = {
  provider: "fast2sms",
  apiKey: "FAST2SMS_KEY",
  fast2smsRoute: "dlt",
  fast2smsSenderId: "AKSHRA",
  fast2smsMessageId: "GLOBAL_TMPL_1",
};

const MSG = "NIKSHA: Results for Term 2 are published for Asha.";

Deno.test("P0-18 Quick route is unchanged (pilot default)", () => {
  const params = new URLSearchParams(
    buildTransactionalRequest(quickConfig, "9550055155", MSG).body,
  );
  assertEquals(params.get("route"), "q");
  assertEquals(params.get("message"), MSG);
  assertEquals(params.get("numbers"), "9550055155");
  assertEquals(params.get("flash"), "0");
  // No DLT params leak onto the Quick route.
  assertEquals(params.get("sender_id"), null);
  assertEquals(params.get("variables_values"), null);
});

Deno.test("P0-18 DLT route emits sender_id + template message id + variables_values", () => {
  const params = new URLSearchParams(
    buildTransactionalRequest(dltConfig, "9550055155", MSG).body,
  );
  assertEquals(params.get("route"), "dlt");
  assertEquals(params.get("sender_id"), "AKSHRA");
  // With no per-call templateId, the global message id is used.
  assertEquals(params.get("message"), "GLOBAL_TMPL_1");
  // The rendered text rides as the template variable, not the `message`.
  assertEquals(params.get("variables_values"), MSG);
  assertEquals(params.get("numbers"), "9550055155");
});

Deno.test("P0-18 a per-message-type templateId overrides the global message id on DLT", () => {
  const params = new URLSearchParams(
    buildTransactionalRequest(dltConfig, "9550055155", MSG, "RESULT_TMPL_42").body,
  );
  assertEquals(params.get("route"), "dlt");
  assertEquals(params.get("message"), "RESULT_TMPL_42"); // caller-supplied template wins
  assertEquals(params.get("variables_values"), MSG);
});

Deno.test("P0-18 templateId is ignored on the Quick route (free-text still delivered verbatim)", () => {
  const params = new URLSearchParams(
    buildTransactionalRequest(quickConfig, "9550055155", MSG, "RESULT_TMPL_42").body,
  );
  assertEquals(params.get("route"), "q");
  assertEquals(params.get("message"), MSG); // not the template id
});

Deno.test("P0-18 sendTransactionalSms threads templateId to the DLT wire", async () => {
  const originalFetch = globalThis.fetch;
  let capturedBody = "";
  // deno-lint-ignore no-explicit-any
  globalThis.fetch = ((_url: string | URL | Request, init?: RequestInit): Promise<Response> => {
    capturedBody = String(init?.body ?? "");
    return Promise.resolve(
      new Response(JSON.stringify({ return: true, request_id: "r1" }), { status: 200 }),
    );
  }) as typeof fetch;
  try {
    const res = await sendTransactionalSms(dltConfig, "9550055155", MSG, "RESULT_TMPL_42");
    assert(res.ok, `expected ok, got ${JSON.stringify(res)}`);
    const params = new URLSearchParams(capturedBody);
    assertEquals(params.get("route"), "dlt");
    assertEquals(params.get("message"), "RESULT_TMPL_42");
    assertEquals(params.get("variables_values"), MSG);
  } finally {
    globalThis.fetch = originalFetch;
  }
});
