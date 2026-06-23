import {
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildFast2SmsRequest,
  buildOtpMessage,
  isSmsConfigured,
  parseFast2SmsResponse,
  type SmsConfig,
  toIndianMobile,
} from "./sms_provider.ts";

const baseConfig: SmsConfig = {
  provider: "fast2sms",
  apiKey: "KEY",
  fast2smsRoute: "q",
  fast2smsSenderId: null,
  fast2smsMessageId: null,
};

Deno.test("toIndianMobile normalizes common formats", () => {
  assertEquals(toIndianMobile("+919550055155"), "9550055155");
  assertEquals(toIndianMobile("919550055155"), "9550055155");
  assertEquals(toIndianMobile("09550055155"), "9550055155");
  assertEquals(toIndianMobile("9550055155"), "9550055155");
  assertEquals(toIndianMobile("95500 55155"), "9550055155");
});

Deno.test("toIndianMobile rejects non-Indian-mobile", () => {
  assertEquals(toIndianMobile("1234567890"), null); // starts with 1
  assertEquals(toIndianMobile("+14155550123"), null); // US
  assertEquals(toIndianMobile("12345"), null);
});

Deno.test("buildFast2SmsRequest quick route carries custom message", () => {
  const { url, headers, body } = buildFast2SmsRequest(baseConfig, "9550055155", "123456");
  assertEquals(url, "https://www.fast2sms.com/dev/bulkV2");
  assertEquals(headers.authorization, "KEY");
  const params = new URLSearchParams(body);
  assertEquals(params.get("route"), "q");
  assertEquals(params.get("numbers"), "9550055155");
  assertEquals(params.get("message"), buildOtpMessage("123456"));
});

Deno.test("buildFast2SmsRequest otp route uses variables_values", () => {
  const cfg = { ...baseConfig, fast2smsRoute: "otp" };
  const params = new URLSearchParams(buildFast2SmsRequest(cfg, "9550055155", "123456").body);
  assertEquals(params.get("route"), "otp");
  assertEquals(params.get("variables_values"), "123456");
});

Deno.test("buildFast2SmsRequest dlt route includes sender + template", () => {
  const cfg = {
    ...baseConfig,
    fast2smsRoute: "dlt",
    fast2smsSenderId: "AKSHRA",
    fast2smsMessageId: "55512",
  };
  const params = new URLSearchParams(buildFast2SmsRequest(cfg, "9550055155", "123456").body);
  assertEquals(params.get("route"), "dlt");
  assertEquals(params.get("sender_id"), "AKSHRA");
  assertEquals(params.get("message"), "55512");
  assertEquals(params.get("variables_values"), "123456");
});

Deno.test("parseFast2SmsResponse success", () => {
  const r = parseFast2SmsResponse(200, { return: true, request_id: "abc", message: ["ok"] });
  assertEquals(r.ok, true);
  assertEquals(r.requestId, "abc");
});

Deno.test("parseFast2SmsResponse failure surfaces message", () => {
  const r = parseFast2SmsResponse(400, { return: false, status_code: 996, message: "verify first" });
  assertEquals(r.ok, false);
  assertEquals(r.code, "SMS_SEND_FAILED");
  assertEquals(r.detail, "verify first");
});

Deno.test("isSmsConfigured requires key and provider", () => {
  assertEquals(isSmsConfigured(baseConfig), true);
  assertEquals(isSmsConfigured({ ...baseConfig, apiKey: null }), false);
  assertEquals(isSmsConfigured({ ...baseConfig, provider: "" }), false);
});
