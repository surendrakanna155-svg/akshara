export interface AppConfig {
  environment: string;
  jwtSecret: string;
  accessTokenTtlSeconds: number;
  refreshTokenTtlSeconds: number;
  otpTtlSeconds: number;
  otpMaxAttempts: number;
  otpDevMode: boolean;
  supabaseUrl: string;
  supabaseServiceRoleKey: string;
  /** Non-bypass Postgres URL for `erp_tenant` role (TD-P0-01). */
  erpTenantDatabaseUrl: string | null;
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
    supabaseUrl,
    supabaseServiceRoleKey,
    erpTenantDatabaseUrl: Deno.env.get("ERP_TENANT_DATABASE_URL") ?? null,
  };
}
