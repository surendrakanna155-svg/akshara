export interface AppConfig {
  environment: string;
  jwtSecret: string;
  accessTokenTtlSeconds: number;
  refreshTokenTtlSeconds: number;
  otpTtlSeconds: number;
  otpMaxAttempts: number;
  otpDevMode: boolean;
  /**
   * Phones (E.164, e.g. +919550055155) allowed to receive the OTP in the login
   * response instead of by SMS — lets owner/testers log in without spending SMS
   * or needing dev mode on in production. Empty = nobody.
   */
  otpPilotPhones: string[];
  /** Sliding window (seconds) for counting OTP requests per phone / per IP. */
  otpRateWindowSeconds: number;
  /** Max OTP requests allowed per phone within the window. */
  otpMaxRequestsPerPhone: number;
  /** Max OTP requests allowed per source IP within the window. */
  otpMaxRequestsPerIp: number;
  /** Minimum seconds between two OTP requests for the same phone. */
  otpResendCooldownSeconds: number;
  /** SMS provider id, e.g. "fast2sms". */
  smsProvider: string;
  /** SMS provider API key. */
  smsApiKey: string | null;
  /** Fast2SMS route: "q" (quick, default), "otp", or "dlt". */
  smsFast2smsRoute: string;
  /** DLT sender id (only for the "dlt" route). */
  smsFast2smsSenderId: string | null;
  /** DLT message template id (only for the "dlt" route). */
  smsFast2smsMessageId: string | null;
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  /** Non-bypass Postgres URL for `erp_tenant` role (TD-P0-01). */
  erpTenantDatabaseUrl: string | null;
  /** Token for `/health/tenant-access` and `/health/operations` (v7.7). */
  internalHealthToken: string | null;
}

/** Parse a comma/space separated phone allowlist into normalized E.164-ish strings. */
export function parsePilotPhones(raw: string | undefined): string[] {
  if (!raw) return [];
  return raw
    .split(/[,\s]+/)
    .map((p) => p.trim())
    .filter((p) => p.length > 0);
}

export function loadConfig(): AppConfig {
  const jwtSecret = Deno.env.get("JWT_SECRET");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!jwtSecret || jwtSecret.length < 32) {
    throw new Error("JWT_SECRET must be set (min 32 chars) via environment");
  }
  if (!supabaseUrl) {
    throw new Error("SUPABASE_URL must be set via environment");
  }
  if (!supabaseServiceRoleKey) {
    throw new Error("SUPABASE_SERVICE_ROLE_KEY must be set via environment");
  }

  return {
    environment: Deno.env.get("APP_ENV") ?? "development",
    jwtSecret,
    accessTokenTtlSeconds: parseInt(
      Deno.env.get("ACCESS_TOKEN_TTL_SECONDS") ?? "900",
      10,
    ),
    refreshTokenTtlSeconds: parseInt(
      Deno.env.get("REFRESH_TOKEN_TTL_SECONDS") ?? "2592000",
      10,
    ),
    otpTtlSeconds: parseInt(Deno.env.get("OTP_TTL_SECONDS") ?? "300", 10),
    otpMaxAttempts: parseInt(Deno.env.get("OTP_MAX_ATTEMPTS") ?? "3", 10),
    otpDevMode: (Deno.env.get("AUTH_OTP_DEV_MODE") ?? "false").toLowerCase() ===
      "true",
    otpPilotPhones: parsePilotPhones(Deno.env.get("AUTH_OTP_PILOT_PHONES")),
    otpRateWindowSeconds: parseInt(
      Deno.env.get("OTP_RATE_WINDOW_SECONDS") ?? "3600",
      10,
    ),
    otpMaxRequestsPerPhone: parseInt(
      Deno.env.get("OTP_MAX_REQUESTS_PER_PHONE") ?? "5",
      10,
    ),
    otpMaxRequestsPerIp: parseInt(
      Deno.env.get("OTP_MAX_REQUESTS_PER_IP") ?? "20",
      10,
    ),
    otpResendCooldownSeconds: parseInt(
      Deno.env.get("OTP_RESEND_COOLDOWN_SECONDS") ?? "60",
      10,
    ),
    smsProvider: Deno.env.get("SMS_PROVIDER") ?? "fast2sms",
    smsApiKey: Deno.env.get("SMS_PROVIDER_API_KEY") ?? null,
    smsFast2smsRoute: Deno.env.get("FAST2SMS_ROUTE") ?? "q",
    smsFast2smsSenderId: Deno.env.get("FAST2SMS_SENDER_ID") ?? null,
    smsFast2smsMessageId: Deno.env.get("FAST2SMS_MESSAGE_ID") ?? null,
    supabaseUrl,
    supabaseServiceRoleKey,
    erpTenantDatabaseUrl: Deno.env.get("ERP_TENANT_DATABASE_URL") ?? null,
    internalHealthToken: Deno.env.get("INTERNAL_HEALTH_TOKEN") ?? null,
  };
}
