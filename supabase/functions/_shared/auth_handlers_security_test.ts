// Auth security regression tests for the ICA auth-layer fixes.
//
//   ICA-B2 — production must have NO privileged OTP-in-response bypass. Neither
//            the pilot-phone allowlist nor dev mode may cause the plaintext OTP
//            to be returned in the /auth/login body once environment ===
//            "production"; the normal SMS-possession flow is the ONLY path.
//   ICA-B8 — handleRevokeSession must scope the refresh_tokens revoke to the
//            CALLER's own tokens (a caller who knows a victim's session UUID
//            must NOT be able to revoke the victim's refresh tokens).
//   ICA-B9 — handleMe must still return the caller's own user after the inert
//            (RLS-bypassing) setRequestContext call was removed, and must NOT
//            emit a set_request_context RPC.
//
// The handlers build their own service_role client internally via
// createServiceClient → supabase-js, which talks over `globalThis.fetch`. These
// contract tests stub `fetch` to (a) CAPTURE the exact PostgREST requests the
// fix produces and (b) return canned rows, driving the REAL handler end-to-end.
import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  canReturnOtpInResponse,
  handleLogin,
  handleMe,
  handleRevokeSession,
} from "./auth_handlers.ts";
import { type AccessTokenClaims, signAccessToken } from "./jwt.ts";
import type { AppConfig } from "./config.ts";

const TEST_SECRET = "test-jwt-secret-minimum-32-characters-long";
const SUPABASE_URL = "http://localhost:54321";

// Only the fields the auth handlers actually read; cast to satisfy AppConfig.
const config = {
  jwtSecret: TEST_SECRET,
  supabaseUrl: SUPABASE_URL,
  supabaseServiceRoleKey: "service-role-test-key",
} as unknown as AppConfig;

function claimsFor(userId: string, scope: AccessTokenClaims["scope"] = "school"): AccessTokenClaims {
  return {
    sub: userId,
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["viewAdminHub"],
    permissions_version: 1,
    scope,
    school_group_id: null,
    student_id: null,
    child_ids: [],
    is_chain_organization: false,
    session_id: "session-self",
  };
}

interface CapturedRequest {
  method: string;
  url: string;
  path: string;
  /** Decoded query string (PostgREST filters, e.g. `user_id=eq.<uuid>`). */
  query: string;
}

/**
 * Installs a `globalThis.fetch` stub that records every request and answers with
 * `respond(req)`. Returns the capture log and a restore fn.
 */
function stubFetch(
  respond: (r: CapturedRequest) => Response,
): { captured: CapturedRequest[]; restore: () => void } {
  const captured: CapturedRequest[] = [];
  const original = globalThis.fetch;
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit): Promise<Response> => {
    const url = typeof input === "string"
      ? input
      : input instanceof URL
      ? input.href
      : input.url;
    const method = (init?.method ??
      (input instanceof Request ? input.method : "GET")).toUpperCase();
    const u = new URL(url);
    const rec: CapturedRequest = {
      method,
      url,
      path: u.pathname,
      query: decodeURIComponent(u.search.replace(/^\?/, "")),
    };
    captured.push(rec);
    return Promise.resolve(respond(rec));
  }) as typeof globalThis.fetch;
  return { captured, restore: () => (globalThis.fetch = original) };
}

function noContent(): Response {
  return new Response(null, { status: 204 });
}

// ─── ICA-B8 ─────────────────────────────────────────────────────────────────

Deno.test("ICA-B8: revoking a session you don't own does NOT revoke the victim's refresh tokens", async () => {
  const attacker = "11111111-1111-4111-8111-111111111111";
  const victimSession = "99999999-9999-4999-8999-999999999999"; // owned by victim

  const { captured, restore } = stubFetch((r) => {
    if (r.method === "PATCH") return noContent();
    return new Response("[]", { status: 200, headers: { "content-type": "application/json" } });
  });

  try {
    const token = await signAccessToken(TEST_SECRET, claimsFor(attacker), 900);
    const req = new Request(`${SUPABASE_URL}/auth/revoke-session`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ sessionId: victimSession }),
    });

    const res = await handleRevokeSession(req, config);
    assertEquals(res.status, 200);

    const refreshPatch = captured.find(
      (c) => c.method === "PATCH" && c.path.endsWith("/refresh_tokens"),
    );
    assert(refreshPatch, "expected a PATCH to refresh_tokens");

    // The core fix: the refresh-token revoke is scoped to the CALLER (attacker),
    // so it can only ever touch the attacker's own tokens — never the victim's.
    assert(
      refreshPatch!.query.includes(`user_id=eq.${attacker}`),
      `refresh_tokens revoke must be constrained to the caller's user_id; got query: ${refreshPatch!.query}`,
    );
    assert(
      refreshPatch!.query.includes(`session_id=eq.${victimSession}`),
      "refresh_tokens revoke should still target the requested session_id",
    );
    // Regression guard: there must be NO refresh_tokens PATCH scoped by
    // session_id alone (that is exactly the forced-logout DoS ICA-B8 fixed).
    const unscoped = captured.some(
      (c) =>
        c.method === "PATCH" &&
        c.path.endsWith("/refresh_tokens") &&
        !c.query.includes("user_id=eq."),
    );
    assert(!unscoped, "no refresh_tokens revoke may omit the user_id predicate");
  } finally {
    restore();
  }
});

Deno.test("ICA-B8: the sessions revoke is also owner-scoped (both writes carry user_id)", async () => {
  const attacker = "22222222-2222-4222-8222-222222222222";
  const victimSession = "88888888-8888-4888-8888-888888888888";

  const { captured, restore } = stubFetch((r) =>
    r.method === "PATCH" ? noContent() : new Response("[]", { status: 200 })
  );
  try {
    const token = await signAccessToken(TEST_SECRET, claimsFor(attacker), 900);
    const req = new Request(`${SUPABASE_URL}/auth/revoke-session`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ sessionId: victimSession }),
    });
    await handleRevokeSession(req, config);

    for (const c of captured.filter((x) => x.method === "PATCH")) {
      assert(
        c.query.includes(`user_id=eq.${attacker}`),
        `every revoke write must be caller-scoped; ${c.path} query was: ${c.query}`,
      );
    }
  } finally {
    restore();
  }
});

// ─── ICA-B9 ─────────────────────────────────────────────────────────────────

Deno.test("ICA-B9: handleMe returns the caller's own user (explicit id filter, no context RPC)", async () => {
  const me = "33333333-3333-4333-8333-333333333333";
  const userRow = {
    id: me,
    phone: "+919000000000",
    email: "me@example.com",
    display_name: "Me Myself",
  };

  const { captured, restore } = stubFetch((r) => {
    if (r.path.endsWith("/users") && r.method === "GET") {
      // maybeSingle() ⇒ PostgREST returns a bare object.
      return new Response(JSON.stringify(userRow), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    }
    return new Response("null", { status: 200, headers: { "content-type": "application/json" } });
  });

  try {
    const token = await signAccessToken(TEST_SECRET, claimsFor(me), 900);
    const req = new Request(`${SUPABASE_URL}/auth/me`, {
      method: "GET",
      headers: { Authorization: `Bearer ${token}` },
    });

    const res = await handleMe(req, config);
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.error, null);
    assertEquals(body.data.id, me, "handleMe must return the caller's own id");
    assertEquals(body.data.displayName, "Me Myself");
    assertEquals(body.data.mobile, "+919000000000");
    assertEquals(body.data.email, "me@example.com");

    // The users read MUST carry the explicit self filter (service_role bypasses
    // RLS, so this filter is the only thing scoping the row to the caller).
    const usersGet = captured.find((c) => c.path.endsWith("/users") && c.method === "GET");
    assert(usersGet, "expected a GET on users");
    assert(
      usersGet!.query.includes(`id=eq.${me}`),
      `handleMe must filter users by the caller's id; got: ${usersGet!.query}`,
    );

    // ICA-B9: the inert setRequestContext call was removed — no such RPC fires.
    const rpc = captured.find((c) => c.path.includes("set_request_context"));
    assertEquals(rpc, undefined, "handleMe must not emit the inert set_request_context RPC");
  } finally {
    restore();
  }
});

// ─── ICA-B2 ─────────────────────────────────────────────────────────────────
// Remove all privileged/demo/pilot OTP bypass from the PRODUCTION path. In
// production the plaintext OTP must NEVER be returned in the /auth/login body —
// for any phone, allowlisted or not. The dev/pilot return path survives only in
// non-production (dev/test) so it still avoids SMS spend there.

const PILOT_PHONE = "+919550055155";

/** Minimal AppConfig for canReturnOtpInResponse invariant checks. */
function otpFlagConfig(overrides: Partial<AppConfig>): AppConfig {
  return {
    environment: "development",
    otpPilotPhones: [],
    otpDevMode: false,
    ...overrides,
  } as unknown as AppConfig;
}

Deno.test("ICA-B2: canReturnOtpInResponse is false in production even for an allowlisted pilot phone", () => {
  const config = otpFlagConfig({
    environment: "production",
    otpPilotPhones: [PILOT_PHONE],
    otpDevMode: true, // even with dev mode ALSO on, production must not leak.
  });
  assertEquals(
    canReturnOtpInResponse(config, PILOT_PHONE),
    false,
    "production must never return the OTP in the response body for an allowlisted phone",
  );
});

Deno.test("ICA-B2: canReturnOtpInResponse is false in production for ANY phone", () => {
  const config = otpFlagConfig({
    environment: "production",
    otpPilotPhones: [PILOT_PHONE],
    otpDevMode: true,
  });
  for (const phone of [PILOT_PHONE, "+919000000001", "+441234567890", ""]) {
    assertEquals(
      canReturnOtpInResponse(config, phone),
      false,
      `production must never return the OTP in the body (phone=${phone})`,
    );
  }
});

Deno.test("ICA-B2: dev convenience preserved — non-production still returns the OTP for an allowlisted phone", () => {
  for (const env of ["development", "test", "staging"]) {
    const config = otpFlagConfig({
      environment: env,
      otpPilotPhones: [PILOT_PHONE],
    });
    assertEquals(
      canReturnOtpInResponse(config, PILOT_PHONE),
      true,
      `allowlisted pilot phone must still get the OTP in-response in non-prod (${env})`,
    );
    // dev mode alone (no allowlist) also works outside production.
    const devModeConfig = otpFlagConfig({ environment: env, otpDevMode: true });
    assertEquals(
      canReturnOtpInResponse(devModeConfig, "+919000000009"),
      true,
      `dev-mode in-response OTP must still work in non-prod (${env})`,
    );
  }
});

/** Fuller AppConfig for the end-to-end handleLogin path. */
function loginConfig(overrides: Partial<AppConfig>): AppConfig {
  return {
    environment: "development",
    jwtSecret: TEST_SECRET,
    supabaseUrl: SUPABASE_URL,
    supabaseServiceRoleKey: "service-role-test-key",
    otpTtlSeconds: 300,
    otpMaxAttempts: 3,
    otpDevMode: false,
    otpPilotPhones: [],
    otpRateWindowSeconds: 3600,
    otpMaxRequestsPerPhone: 5,
    otpMaxRequestsPerIp: 20,
    otpResendCooldownSeconds: 60,
    smsProvider: "fast2sms",
    smsApiKey: null, // SMS intentionally NOT configured for these tests.
    smsFast2smsRoute: "q",
    smsFast2smsSenderId: null,
    smsFast2smsMessageId: null,
    ...overrides,
  } as unknown as AppConfig;
}

/** Stub the otp_requests rate-limit SELECT (→ []) and the insert (→ 201). */
function stubLoginDb(): { restore: () => void } {
  const { restore } = stubFetch((r) => {
    if (r.path.endsWith("/otp_requests")) {
      if (r.method === "GET") {
        return new Response("[]", {
          status: 200,
          headers: { "content-type": "application/json" },
        });
      }
      // POST insert (return=minimal ⇒ no body).
      return new Response(null, { status: 201 });
    }
    return new Response("[]", {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  });
  return { restore };
}

function loginRequest(identifier: string): Request {
  return new Request(`${SUPABASE_URL}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ identifier }),
  });
}

Deno.test("ICA-B2 (e2e): in production, /auth/login for an allowlisted pilot phone does NOT leak the OTP in the body", async () => {
  const config = loginConfig({
    environment: "production",
    otpPilotPhones: [PILOT_PHONE], // allowlisted, yet must NOT bypass in prod.
    otpDevMode: true,
  });
  const { restore } = stubLoginDb();
  try {
    const res = await handleLogin(loginRequest(PILOT_PHONE), config);
    const body = await res.json();

    // The normal SMS-possession flow is now the only path. With SMS
    // deliberately unconfigured, the request is pushed onto the SMS branch
    // (503) instead of ever short-circuiting to return the code — proving no
    // privileged in-response bypass survives in production.
    assertEquals(res.status, 503);
    assertEquals(body.error?.code, "SMS_NOT_CONFIGURED");
    assertEquals(
      body.data,
      null,
      "production login must return no data envelope carrying an OTP",
    );
  } finally {
    restore();
  }
});

Deno.test("ICA-B2 (e2e): in production, no phone gets an OTP in the /auth/login body", async () => {
  const config = loginConfig({
    environment: "production",
    otpPilotPhones: [PILOT_PHONE],
    otpDevMode: true,
  });
  for (const phone of [PILOT_PHONE, "+919000000123"]) {
    const { restore } = stubLoginDb();
    try {
      const res = await handleLogin(loginRequest(phone), config);
      const raw = await res.text();
      assert(
        !JSON.parse(raw).data?.otp,
        `production login body must never contain an otp (phone=${phone})`,
      );
      // Belt-and-suspenders: the plaintext-OTP field must not appear at all.
      assert(
        !/"otp"\s*:/.test(raw),
        `production login response must not carry an "otp" field (phone=${phone})`,
      );
    } finally {
      restore();
    }
  }
});

Deno.test("ICA-B2 (e2e): in a non-production env, the pilot phone still gets the OTP in-response (dev convenience preserved)", async () => {
  const config = loginConfig({
    environment: "development",
    otpPilotPhones: [PILOT_PHONE],
  });
  const { restore } = stubLoginDb();
  try {
    const res = await handleLogin(loginRequest(PILOT_PHONE), config);
    assertEquals(res.status, 200);
    const body = await res.json();
    assertEquals(body.error, null);
    assert(
      typeof body.data?.otp === "string" && /^\d{6}$/.test(body.data.otp),
      "non-production pilot login must still return a 6-digit OTP in the body",
    );
  } finally {
    restore();
  }
});
