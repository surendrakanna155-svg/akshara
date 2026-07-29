// QA-C-011 — SMS / Fast2SMS channel BEHAVIOUR certification (transactional leg).
//
// The existing sms_provider_test.ts pins the OTP route + the pure
// normalize/parse helpers. This cert certifies the TRANSACTIONAL (non-OTP)
// channel behaviour a school actually uses for fee-receipt / results-published
// SMS to a parent:
//
//   recipient   → stored phone numbers in any common Indian format normalize to
//                 the bare 10-digit mobile Fast2SMS addresses,
//   template    → a rendered free-text message is delivered verbatim on the
//                 quick ("q") route (custom message, no DLT/template approval —
//                 the pilot's chosen route),
//   placeholder → a `{{var}}`-rendered body survives unchanged into the request
//                 body (the channel does not re-template),
//   stub/contract→ the configured/unconfigured + provider/number gates return
//                 stable error codes BEFORE any network call (fail-closed).
//
// INFRA-BLOCKED (honestly marked): the live Fast2SMS HTTP POST to
// fast2sms.com/dev/bulkV2 (real API key, real delivery receipt) cannot run in
// this lane. `sendTransactionalSms`'s pre-network guards ARE certified below;
// the network leg is exercised on the live SMS lane.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildTransactionalRequest,
  isSmsConfigured,
  sendTransactionalSms,
  type SmsConfig,
  toIndianMobile,
} from "./sms_provider.ts";

const config: SmsConfig = {
  provider: "fast2sms",
  apiKey: "FAST2SMS_KEY",
  fast2smsRoute: "q",
  fast2smsSenderId: null,
  fast2smsMessageId: null,
};

const FEE_RECEIPT_SMS =
  "NIKSHA: Payment of Rs 4,200 received for Asha (Class 3A). Receipt available in the app.";

// --- recipient normalization across stored formats ---------------------------

Deno.test("QA-C-011 transactional SMS normalizes the recipient to a 10-digit Indian mobile", () => {
  // every common stored shape collapses to the same dialable mobile.
  for (
    const stored of [
      "+919550055155",
      "919550055155",
      "09550055155",
      "9550055155",
      "95500 55155",
    ]
  ) {
    assertEquals(toIndianMobile(stored), "9550055155");
    const { body } = buildTransactionalRequest(config, toIndianMobile(stored)!, "hi");
    assertEquals(new URLSearchParams(body).get("numbers"), "9550055155");
  }
});

// --- template / placeholder body delivered verbatim on the quick route -------

Deno.test("QA-C-011 transactional SMS sends the rendered body verbatim on the 'q' route", () => {
  const { url, headers, body } = buildTransactionalRequest(config, "9550055155", FEE_RECEIPT_SMS);
  assertEquals(url, "https://www.fast2sms.com/dev/bulkV2");
  assertEquals(headers.authorization, "FAST2SMS_KEY");
  const params = new URLSearchParams(body);
  assertEquals(params.get("route"), "q"); // custom-message route (no DLT/template id)
  assertEquals(params.get("numbers"), "9550055155");
  assertEquals(params.get("flash"), "0");
  // body is delivered exactly as rendered — the channel does not re-template it.
  assertEquals(params.get("message"), FEE_RECEIPT_SMS);
});

Deno.test("QA-C-011 a pre-rendered {{var}} body reaches the wire unchanged (no double templating)", () => {
  // upstream (template_renderer) substitutes vars; the SMS channel forwards the result.
  const rendered = "NIKSHA: Results for Term 2 are published for Asha. Open the app to view.";
  const params = new URLSearchParams(
    buildTransactionalRequest(config, "9550055155", rendered).body,
  );
  assertEquals(params.get("message"), rendered);
  assert(!params.get("message")!.includes("{{")); // fully rendered, no leftover placeholder
});

// --- stub / fail-closed contract before any network call ---------------------

Deno.test("QA-C-011 isSmsConfigured gates the channel on provider + key", () => {
  assertEquals(isSmsConfigured(config), true);
  assertEquals(isSmsConfigured({ ...config, apiKey: null }), false);
  assertEquals(isSmsConfigured({ ...config, provider: "" }), false);
});

Deno.test("QA-C-011 sendTransactionalSms fails closed when unconfigured (no network)", async () => {
  const res = await sendTransactionalSms({ ...config, apiKey: null }, "9550055155", FEE_RECEIPT_SMS);
  assertEquals(res.ok, false);
  assertEquals(res.code, "SMS_NOT_CONFIGURED");
});

Deno.test("QA-C-011 sendTransactionalSms rejects an unsupported provider before sending", async () => {
  const res = await sendTransactionalSms(
    { ...config, provider: "twilio" },
    "9550055155",
    FEE_RECEIPT_SMS,
  );
  assertEquals(res.ok, false);
  assertEquals(res.code, "SMS_PROVIDER_UNSUPPORTED");
});

Deno.test("QA-C-011 sendTransactionalSms rejects a non-Indian recipient before sending", async () => {
  const res = await sendTransactionalSms(config, "+14155550123", FEE_RECEIPT_SMS);
  assertEquals(res.ok, false);
  assertEquals(res.code, "SMS_INVALID_NUMBER");
  // INFRA-BLOCKED: a VALID number takes the live Fast2SMS network path, which is
  // not exercisable in this lane — certified on the live SMS lane instead.
});
