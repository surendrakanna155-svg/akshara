import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { routeApproval } from "./approval_router.ts";
import type { AppConfig } from "../config.ts";

// Self-contained test config. These router unit tests only exercise path
// matching (not real JWT/DB), so we construct an AppConfig directly instead of
// calling loadConfig(), which would require live secrets in the environment.
// Building a literal (rather than setting process env) keeps the env clean so
// it cannot leak into sibling test files that gate on SUPABASE_URL presence.
const config: AppConfig = {
  environment: "test",
  jwtSecret: "test-jwt-secret-minimum-32-characters-long",
  accessTokenTtlSeconds: 900,
  refreshTokenTtlSeconds: 2592000,
  otpTtlSeconds: 300,
  otpMaxAttempts: 3,
  otpDevMode: false,
  otpPilotPhones: [],
  otpRateWindowSeconds: 3600,
  otpMaxRequestsPerPhone: 5,
  otpMaxRequestsPerIp: 20,
  otpResendCooldownSeconds: 30,
  smsProvider: "fast2sms",
  smsApiKey: null,
  smsFast2smsRoute: "q",
  smsFast2smsSenderId: null,
  smsFast2smsMessageId: null,
  transactionalSmsEnabled: false,
  supabaseUrl: "http://localhost:54321",
  supabaseServiceRoleKey: "test-service-role-key",
  publicStorageBaseUrl: null,
  erpTenantDatabaseUrl: null,
  internalHealthToken: null,
  backupMaxAgeHours: 26,
};

function mockRequest(method: string, path: string): Request {
  return new Request(`https://example.com/api${path}`, { method });
}

Deno.test("approval router matches pending list route", async () => {
  const response = await routeApproval(
    mockRequest("GET", "/approvals/pending"),
    config,
    "GET",
    "/approvals/pending",
  );
  assertEquals(response != null, true);
  assertEquals(response!.status, 401);
});

Deno.test("approval router returns null for unrelated paths", async () => {
  const response = await routeApproval(
    mockRequest("GET", "/finance/refunds"),
    config,
    "GET",
    "/finance/refunds",
  );
  assertEquals(response, null);
});

Deno.test("approval router matches entity lookup route", async () => {
  const response = await routeApproval(
    mockRequest("GET", "/approvals/entity"),
    config,
    "GET",
    "/approvals/entity",
  );
  assertEquals(response != null, true);
});
