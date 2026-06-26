import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { routeManagement } from "./management_router.ts";
import type { AppConfig } from "../config.ts";

// Self-contained test config. These router unit tests only exercise path/method
// matching (not real JWT/DB), so we construct an AppConfig directly instead of
// calling loadConfig(), which would require live secrets in the environment.
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
  const init: RequestInit = { method };
  if (method !== "GET" && method !== "HEAD") {
    init.body = "{}";
    init.headers = { "content-type": "application/json" };
  }
  return new Request(`https://example.com/api${path}`, init);
}

Deno.test("management router matches PUT /management/settings (does not 404)", async () => {
  const response = await routeManagement(
    mockRequest("PUT", "/management/settings"),
    config,
    "PUT",
    "/management/settings",
  );
  // A matched route reaches auth and fails there (401) — it must NOT 404. This
  // proves the PUT method is allowed through the matcher (the bug being fixed).
  assertEquals(response != null, true);
  assertEquals(response!.status, 401);
});

Deno.test("management router still matches GET /management/settings", async () => {
  const response = await routeManagement(
    mockRequest("GET", "/management/settings"),
    config,
    "GET",
    "/management/settings",
  );
  assertEquals(response != null, true);
  assertEquals(response!.status, 401);
});

Deno.test("management router 404s an unsupported method on /management/settings", async () => {
  const response = await routeManagement(
    mockRequest("DELETE", "/management/settings"),
    config,
    "DELETE",
    "/management/settings",
  );
  // Path is under /management so routeManagement returns a 404 envelope (not
  // null) for a method/route it does not recognise.
  assertEquals(response != null, true);
  assertEquals(response!.status, 404);
});

Deno.test("management router returns null for unrelated paths", async () => {
  const response = await routeManagement(
    mockRequest("GET", "/finance/refunds"),
    config,
    "GET",
    "/finance/refunds",
  );
  assertEquals(response, null);
});
