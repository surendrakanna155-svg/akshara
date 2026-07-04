import { assertEquals } from "jsr:@std/assert@1";
import { requireInternalHealthAccess } from "./internal_health_auth.ts";
import type { AppConfig } from "./config.ts";

const baseConfig: AppConfig = {
  environment: "staging",
  jwtSecret: "x".repeat(32),
  accessTokenTtlSeconds: 900,
  refreshTokenTtlSeconds: 2592000,
  otpTtlSeconds: 300,
  otpMaxAttempts: 3,
  otpDevMode: false,
  otpPilotPhones: [],
  otpRateWindowSeconds: 3600,
  otpMaxRequestsPerPhone: 5,
  otpMaxRequestsPerIp: 20,
  otpResendCooldownSeconds: 60,
  smsProvider: "fast2sms",
  smsApiKey: null,
  smsFast2smsRoute: "q",
  smsFast2smsSenderId: null,
  smsFast2smsMessageId: null,
  transactionalSmsEnabled: false,
  supabaseUrl: "https://example.supabase.co",
  supabaseServiceRoleKey: "service-role-key",
  publicStorageBaseUrl: null,
  erpTenantDatabaseUrl: null,
  internalHealthToken: "test-internal-token",
  backupMaxAgeHours: 26,
  auditRetentionDays: 730,
};

Deno.test("internal health allows matching token header", () => {
  const req = new Request("https://example/health/tenant-access", {
    headers: { "x-internal-health-token": "test-internal-token" },
  });
  assertEquals(requireInternalHealthAccess(req, baseConfig), null);
});

Deno.test("internal health rejects missing token when configured", () => {
  const req = new Request("https://example/health/tenant-access");
  const denied = requireInternalHealthAccess(req, baseConfig);
  assertEquals(denied?.status, 403);
});

Deno.test("production blocks internal health when token not configured", () => {
  const req = new Request("https://example/health/operations");
  const denied = requireInternalHealthAccess(req, {
    ...baseConfig,
    environment: "production",
    internalHealthToken: null,
  });
  assertEquals(denied?.status, 403);
});
