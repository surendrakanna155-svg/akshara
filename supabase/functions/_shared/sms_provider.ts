// SMS delivery for OTP codes.
//
// Provider abstraction with a concrete Fast2SMS implementation (India bulk SMS).
// Secrets (API key) are read from environment — never hard-coded. The pure
// helpers below are unit-tested in sms_provider_test.ts; the network call in
// `sendOtpSms` is the only impure part.

export interface SmsConfig {
  /** Provider id, e.g. "fast2sms". */
  provider: string;
  /** Provider API key (Fast2SMS `authorization` header). */
  apiKey: string | null;
  /**
   * Fast2SMS route:
   *  - "q"   Quick SMS — custom message, no DLT/website verification (pilot default).
   *  - "otp" Built-in OTP template — requires Fast2SMS website verification.
   *  - "dlt" DLT route — requires approved sender id + template message id.
   */
  fast2smsRoute: string;
  /** DLT-approved sender id (only used for the "dlt" route). */
  fast2smsSenderId: string | null;
  /** DLT message template id (only used for the "dlt" route). */
  fast2smsMessageId: string | null;
}

/** Builds the OTP text for the Quick route. `{otp}` is substituted. */
export function buildOtpMessage(otp: string): string {
  return `Your Akshara OTP is ${otp}. Valid for 5 minutes. Do not share this code with anyone.`;
}

export interface SmsResult {
  ok: boolean;
  /** Provider request id on success, for log correlation. */
  requestId?: string;
  /** Stable error code on failure. */
  code?: string;
  /** Human-readable error detail (provider message). */
  detail?: string;
}

const FAST2SMS_ENDPOINT = "https://www.fast2sms.com/dev/bulkV2";

/**
 * Reduce a stored phone to the 10-digit Indian mobile Fast2SMS expects.
 * Accepts "+919876543210", "919876543210", "09876543210", "9876543210".
 * Returns null when it is not a valid 10-digit Indian mobile (starts 6-9).
 */
export function toIndianMobile(phone: string): string | null {
  const digits = phone.replace(/\D/g, "");
  let local = digits;
  if (local.length === 12 && local.startsWith("91")) local = local.slice(2);
  else if (local.length === 11 && local.startsWith("0")) local = local.slice(1);
  if (/^[6-9]\d{9}$/.test(local)) return local;
  return null;
}

/**
 * Build the Fast2SMS request (url + headers + form body) for an OTP send.
 * Pure so it can be asserted in tests without hitting the network.
 */
export function buildFast2SmsRequest(
  config: SmsConfig,
  mobile: string,
  otp: string,
): { url: string; headers: Record<string, string>; body: string } {
  const params = new URLSearchParams();
  if (config.fast2smsRoute === "dlt") {
    params.set("route", "dlt");
    if (config.fast2smsSenderId) params.set("sender_id", config.fast2smsSenderId);
    if (config.fast2smsMessageId) params.set("message", config.fast2smsMessageId);
    params.set("variables_values", otp);
    params.set("numbers", mobile);
  } else if (config.fast2smsRoute === "otp") {
    // Built-in OTP route: delivers "Your OTP: <otp>". Needs website verification.
    params.set("route", "otp");
    params.set("variables_values", otp);
    params.set("numbers", mobile);
  } else {
    // Quick route (default): custom message, no DLT/verification required.
    params.set("route", "q");
    params.set("message", buildOtpMessage(otp));
    params.set("numbers", mobile);
    params.set("flash", "0");
  }
  return {
    url: FAST2SMS_ENDPOINT,
    headers: {
      "authorization": config.apiKey ?? "",
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  };
}

/**
 * Interpret a Fast2SMS HTTP response. Pure; takes the parsed JSON (or null).
 * Fast2SMS returns `{"return":true,"request_id":"...","message":[...]}` on
 * success and `{"return":false,"status_code":..,"message":"..."}` on failure.
 */
export function parseFast2SmsResponse(
  httpStatus: number,
  json: unknown,
): SmsResult {
  const body = (json ?? {}) as Record<string, unknown>;
  if (httpStatus >= 200 && httpStatus < 300 && body.return === true) {
    return { ok: true, requestId: String(body.request_id ?? "") };
  }
  const msg = Array.isArray(body.message)
    ? body.message.join("; ")
    : typeof body.message === "string"
    ? body.message
    : `HTTP ${httpStatus}`;
  return { ok: false, code: "SMS_SEND_FAILED", detail: msg };
}

/** True when a provider is selected and an API key is present. */
export function isSmsConfigured(config: SmsConfig): boolean {
  return Boolean(config.apiKey && config.provider);
}

/**
 * Build a Fast2SMS request for a transactional (non-OTP) free-text message.
 * Uses the quick ("q") route — custom message, no DLT/template requirement
 * (the same route the pilot already uses). Pure.
 */
export function buildTransactionalRequest(
  config: SmsConfig,
  mobile: string,
  message: string,
): { url: string; headers: Record<string, string>; body: string } {
  const params = new URLSearchParams();
  params.set("route", "q");
  params.set("message", message);
  params.set("numbers", mobile);
  params.set("flash", "0");
  return {
    url: FAST2SMS_ENDPOINT,
    headers: {
      "authorization": config.apiKey ?? "",
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  };
}

/**
 * Send a transactional SMS (fee receipt, results published, …) to a parent.
 * Same provider/HTTP shape as `sendOtpSms`; the caller owns the
 * `transactionalSmsEnabled` gate. The only impure part is `fetch`.
 */
export async function sendTransactionalSms(
  config: SmsConfig,
  phone: string,
  message: string,
): Promise<SmsResult> {
  if (!isSmsConfigured(config)) {
    return { ok: false, code: "SMS_NOT_CONFIGURED", detail: "No SMS provider/API key" };
  }
  if (config.provider !== "fast2sms") {
    return { ok: false, code: "SMS_PROVIDER_UNSUPPORTED", detail: `Unsupported SMS provider: ${config.provider}` };
  }
  const mobile = toIndianMobile(phone);
  if (!mobile) {
    return { ok: false, code: "SMS_INVALID_NUMBER", detail: `Not an Indian mobile: ${phone}` };
  }
  const { url, headers, body } = buildTransactionalRequest(config, mobile, message);
  try {
    const resp = await fetch(url, { method: "POST", headers, body });
    let json: unknown = null;
    try {
      json = await resp.json();
    } catch {
      json = null;
    }
    return parseFast2SmsResponse(resp.status, json);
  } catch (error) {
    return {
      ok: false,
      code: "SMS_SEND_FAILED",
      detail: error instanceof Error ? error.message : "network error",
    };
  }
}

/** Send an OTP SMS via the configured provider. Network call. */
export async function sendOtpSms(
  config: SmsConfig,
  phone: string,
  otp: string,
): Promise<SmsResult> {
  if (!isSmsConfigured(config)) {
    return { ok: false, code: "SMS_NOT_CONFIGURED", detail: "No SMS provider/API key" };
  }
  if (config.provider !== "fast2sms") {
    return {
      ok: false,
      code: "SMS_PROVIDER_UNSUPPORTED",
      detail: `Unsupported SMS provider: ${config.provider}`,
    };
  }

  const mobile = toIndianMobile(phone);
  if (!mobile) {
    return { ok: false, code: "SMS_INVALID_NUMBER", detail: `Not an Indian mobile: ${phone}` };
  }

  const { url, headers, body } = buildFast2SmsRequest(config, mobile, otp);
  try {
    const resp = await fetch(url, { method: "POST", headers, body });
    let json: unknown = null;
    try {
      json = await resp.json();
    } catch {
      json = null;
    }
    return parseFast2SmsResponse(resp.status, json);
  } catch (error) {
    return {
      ok: false,
      code: "SMS_SEND_FAILED",
      detail: error instanceof Error ? error.message : "network error",
    };
  }
}
