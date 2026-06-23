// Pure decision logic for OTP-request throttling. No DB / no clock access here
// so it can be unit-tested deterministically; callers pass the recent request
// timestamps (ms), the per-IP count, the limits, and "now".

export interface OtpRateLimits {
  windowSeconds: number;
  maxPerPhone: number;
  maxPerIp: number;
  resendCooldownSeconds: number;
}

export interface RateLimitDecision {
  allowed: boolean;
  /** Stable error code when blocked. */
  code?: string;
  /** Suggested wait before retrying, seconds. */
  retryAfterSeconds?: number;
}

/**
 * Decide whether a new OTP request is allowed.
 * @param phoneRequestTimesMs timestamps (ms) of prior requests for this phone, within the window
 * @param ipRequestCount count of prior requests from this IP, within the window
 */
export function evaluateOtpRateLimit(
  phoneRequestTimesMs: number[],
  ipRequestCount: number,
  limits: OtpRateLimits,
  nowMs: number,
): RateLimitDecision {
  // Per-phone cooldown — block rapid re-sends to the same number.
  const lastMs = phoneRequestTimesMs.length
    ? Math.max(...phoneRequestTimesMs)
    : null;
  if (lastMs !== null) {
    const elapsed = (nowMs - lastMs) / 1000;
    if (elapsed < limits.resendCooldownSeconds) {
      return {
        allowed: false,
        code: "OTP_COOLDOWN",
        retryAfterSeconds: Math.ceil(limits.resendCooldownSeconds - elapsed),
      };
    }
  }

  // Per-phone window cap — caps cost / SMS-bombing of one number.
  if (phoneRequestTimesMs.length >= limits.maxPerPhone) {
    return {
      allowed: false,
      code: "OTP_RATE_LIMITED",
      retryAfterSeconds: limits.windowSeconds,
    };
  }

  // Per-IP window cap — caps enumeration across many numbers from one source.
  if (ipRequestCount >= limits.maxPerIp) {
    return {
      allowed: false,
      code: "OTP_IP_RATE_LIMITED",
      retryAfterSeconds: limits.windowSeconds,
    };
  }

  return { allowed: true };
}
