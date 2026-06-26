import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { routeTeacher } from "./teacher_router.ts";
import type { AppConfig } from "../config.ts";

// Path/method-parity unit tests for the teacher router (MJ-C5 exam workflow +
// MJ-H13 parent communication). These only exercise route matching, not real
// JWT/DB — a matched route reaches auth and fails there (401); it must NOT 404.
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

async function assertMatches(method: string, path: string) {
  const response = await routeTeacher(mockRequest(method, path), config, method, path);
  assertEquals(response != null, true, `${method} ${path} should be routed`);
  assertEquals(
    response!.status,
    401,
    `${method} ${path} should reach auth (401), not 404`,
  );
}

// --- MJ-C5: exam workflow (delegated to exam-administration) ---
Deno.test("teacher router matches GET /teacher/exams/marks-entry", async () => {
  await assertMatches("GET", "/teacher/exams/marks-entry");
});
Deno.test("teacher router matches PUT /teacher/exams/marks/{id}", async () => {
  await assertMatches("PUT", "/teacher/exams/marks/mark-123");
});
Deno.test("teacher router matches POST /teacher/exams/{examId}/process", async () => {
  await assertMatches("POST", "/teacher/exams/exam-1/process");
});
Deno.test("teacher router matches POST /teacher/exams/{examId}/publish", async () => {
  await assertMatches("POST", "/teacher/exams/exam-1/publish");
});

// --- MJ-H13: parent communication + subject concerns ---
Deno.test("teacher router matches POST /teacher/parent-communication", async () => {
  await assertMatches("POST", "/teacher/parent-communication");
});
Deno.test("teacher router matches POST /teacher/parent-communication/concerns", async () => {
  await assertMatches("POST", "/teacher/parent-communication/concerns");
});
Deno.test("teacher router matches GET /teacher/parent-communication/concerns", async () => {
  await assertMatches("GET", "/teacher/parent-communication/concerns");
});
Deno.test("teacher router matches POST .../concerns/{id}/dismiss", async () => {
  await assertMatches("POST", "/teacher/parent-communication/concerns/c1/dismiss");
});

// --- regression: existing read surface still routes ---
Deno.test("teacher router still matches GET /teacher/dashboard", async () => {
  await assertMatches("GET", "/teacher/dashboard");
});

// --- non-teacher path is not claimed ---
Deno.test("teacher router returns null for unrelated paths", async () => {
  const response = await routeTeacher(
    mockRequest("GET", "/finance/refunds"),
    config,
    "GET",
    "/finance/refunds",
  );
  assertEquals(response, null);
});
