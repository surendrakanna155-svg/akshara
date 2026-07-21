import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppConfig } from "./config.ts";
import {
  type AuthScope,
  bearerToken,
  expiresAtIso,
  hashOtp,
  hashToken,
  randomToken,
  signAccessToken,
  verifyAccessToken,
} from "./jwt.ts";
import {
  type AuthSessionContext,
  loadChildProfiles,
  resolveAuthSessionContext,
  resolveAuthSessionContextFromSession,
  type ScopeLoginRequest,
} from "./auth_context.ts";
import { permissionsPayloadFromList } from "./permission_resolver.ts";
import { setRequestContext } from "./request_context.ts";
import { createServiceClient, type UserRow } from "./db.ts";
import { resolveStudentLoginTargetWithClient } from "./auth_login_helpers.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "./http.ts";
import { buildInfo } from "./build_info.ts";
import { isSmsConfigured, sendOtpSms, type SmsConfig } from "./sms_provider.ts";
import { evaluateOtpRateLimit } from "./otp_rate_limit.ts";
import { assertSessionValid } from "./session_validation.ts";

interface LoginBody {
  identifier?: string;
  type?: string;
  schoolId?: string;
}

interface VerifyOtpBody extends ScopeLoginRequest {
  identifier?: string;
  otp?: string;
  type?: string;
}

interface RefreshBody {
  refreshToken?: string;
}

interface RevokeSessionBody {
  sessionId?: string;
}

interface ContextSwitchBody extends ScopeLoginRequest {
  scope?: AuthScope;
}

function normalizePhone(identifier: string, type?: string): string {
  if (type === "email") {
    throw new Error("EMAIL_NOT_SUPPORTED");
  }
  const trimmed = identifier.trim();
  if (trimmed.startsWith("+")) return trimmed;
  if (/^\d{10}$/.test(trimmed)) return `+91${trimmed}`;
  return trimmed;
}

// PRA-P1-06 (S2): an OTP is an authentication secret and must be
// cryptographically random. `Math.random()` is a non-cryptographic, seedable
// PRNG whose output can be predicted from prior samples — unacceptable for a
// login code. Draw a uniform 6-digit code from `crypto.getRandomValues` using
// rejection sampling so there is no modulo bias across [100000, 999999].
function generateOtp(): string {
  const span = 900000; // 100000..999999 inclusive
  // Largest multiple of `span` below 2^32; reject the biased tail above it.
  const limit = Math.floor(0x1_0000_0000 / span) * span;
  const buf = new Uint32Array(1);
  let n: number;
  do {
    crypto.getRandomValues(buf);
    n = buf[0];
  } while (n >= limit);
  return `${100000 + (n % span)}`;
}

/** Best-effort source IP from proxy headers (Nginx sets X-Forwarded-For). */
function clientIp(req: Request): string | null {
  const fwd = req.headers.get("x-forwarded-for");
  if (fwd) return fwd.split(",")[0].trim();
  return req.headers.get("x-real-ip");
}

function smsConfigFrom(config: AppConfig): SmsConfig {
  return {
    provider: config.smsProvider,
    apiKey: config.smsApiKey,
    fast2smsRoute: config.smsFast2smsRoute,
    fast2smsSenderId: config.smsFast2smsSenderId,
    fast2smsMessageId: config.smsFast2smsMessageId,
  };
}

/**
 * A phone gets the OTP in the response (no SMS) when it is explicitly
 * allowlisted, or when global dev mode is on outside production.
 */
function canReturnOtpInResponse(config: AppConfig, phone: string): boolean {
  if (config.otpPilotPhones.includes(phone)) return true;
  if (config.otpDevMode && config.environment !== "production") return true;
  return false;
}

function buildUserPayload(
  user: UserRow,
  ctx: AuthSessionContext,
) {
  return {
    id: user.id,
    displayName: user.display_name,
    role: ctx.resolved.primaryRole,
    scope: ctx.scope,
    tenantId: ctx.tenantId,
    schoolId: ctx.schoolId,
    organizationId: ctx.organizationId,
    studentId: ctx.studentId,
    childIds: ctx.childIds,
    // PAR-7: real linked-child details for the parent child-switcher.
    children: ctx.childProfiles ?? [],
    // G4: multi-school (chain/trust) marker — drives Organization Builder visibility.
    isChainOrganization: ctx.isChainOrganization,
    email: user.email,
    mobile: user.phone,
  };
}

function buildAccessClaims(
  userId: string,
  sessionId: string,
  ctx: AuthSessionContext,
) {
  return {
    sub: userId,
    tenant_id: ctx.tenantId,
    organization_id: ctx.organizationId,
    school_id: ctx.schoolId,
    role: ctx.resolved.primaryRole,
    role_slugs: ctx.resolved.roleSlugs,
    primary_role: ctx.resolved.primaryRole,
    permissions: ctx.resolved.permissions,
    permissions_version: ctx.resolved.permissionsVersion,
    scope: ctx.scope,
    school_group_id: ctx.schoolGroupId,
    student_id: ctx.studentId,
    child_ids: ctx.childIds,
    is_chain_organization: ctx.isChainOrganization,
    session_id: sessionId,
  };
}

async function issueSessionTokens(
  client: SupabaseClient,
  config: AppConfig,
  user: UserRow,
  ctx: AuthSessionContext,
  req: Request,
  options: { includeUser?: boolean } = {},
) {
  const sessionId = crypto.randomUUID();
  const refreshToken = randomToken();
  const refreshHash = await hashToken(refreshToken);
  const familyId = crypto.randomUUID();

  const { error: sessionError } = await client.from("sessions").insert({
    id: sessionId,
    user_id: user.id,
    tenant_id: ctx.tenantId,
    scope: ctx.scope,
    context_school_id: ctx.schoolId,
    context_school_group_id: ctx.schoolGroupId,
    context_student_id: ctx.studentId,
    context_child_ids: ctx.childIds,
    device_type: req.headers.get("X-Device-Type"),
    device_name: req.headers.get("X-Device-Name"),
    user_agent: req.headers.get("User-Agent"),
  });
  if (sessionError) throw sessionError;

  const { error: refreshError } = await client.from("refresh_tokens").insert({
    session_id: sessionId,
    user_id: user.id,
    token_hash: refreshHash,
    family_id: familyId,
    expires_at: expiresAtIso(config.refreshTokenTtlSeconds),
  });
  if (refreshError) throw refreshError;

  const claims = buildAccessClaims(user.id, sessionId, ctx);
  const accessToken = await signAccessToken(
    config.jwtSecret,
    claims,
    config.accessTokenTtlSeconds,
  );

  // Apply RLS context for subsequent queries in this request (v6.1 §6.5)
  await setRequestContext(client, claims);

  const base = {
    accessToken,
    refreshToken,
    expiresAt: expiresAtIso(config.accessTokenTtlSeconds),
    sessionId,
    scope: ctx.scope,
    permissions: permissionsPayloadFromList(ctx.resolved.permissions),
  };

  if (options.includeUser === false) return base;

  return {
    ...base,
    user: buildUserPayload(user, ctx),
  };
}

export async function handleLogin(req: Request, config: AppConfig): Promise<Response> {
  const body = await readJson<LoginBody>(req);
  if (!body?.identifier) {
    return errorEnvelope("VALIDATION_ERROR", "identifier is required", 422);
  }

  const client = createServiceClient(config);
  let phone: string;
  let otpMeta: Record<string, unknown> = {
    identifier_type: "phone",
    identifier_value: body.identifier,
  };

  if (body.type === "student_id") {
    if (!body.schoolId) {
      return errorEnvelope("VALIDATION_ERROR", "schoolId is required for student_id login", 422);
    }
    const target = await resolveStudentLoginTargetWithClient(
      client,
      body.schoolId,
      body.identifier.trim(),
    );
    if (!target) {
      return errorEnvelope(
        "STUDENT_LOGIN_NOT_FOUND",
        "Student account not provisioned for OTP login",
        404,
      );
    }
    phone = target.phone;
    otpMeta = {
      identifier_type: "student_id",
      identifier_value: body.identifier.trim(),
      context_school_id: body.schoolId,
      context_student_id: target.studentId,
    };
  } else {
    try {
      phone = normalizePhone(body.identifier, body.type);
      otpMeta.identifier_value = phone;
    } catch {
      return errorEnvelope("VALIDATION_ERROR", "Only phone or student_id OTP is supported", 422);
    }
  }

  // --- Rate limiting (per phone + per IP, sliding window) ---
  const ip = clientIp(req);
  const windowStartIso = new Date(
    Date.now() - config.otpRateWindowSeconds * 1000,
  ).toISOString();

  const { data: recentPhone } = await client
    .from("otp_requests")
    .select("created_at")
    .eq("phone", phone)
    .gte("created_at", windowStartIso);

  let ipCount = 0;
  if (ip) {
    const { count } = await client
      .from("otp_requests")
      .select("id", { count: "exact", head: true })
      .eq("ip_address", ip)
      .gte("created_at", windowStartIso);
    ipCount = count ?? 0;
  }

  const decision = evaluateOtpRateLimit(
    (recentPhone ?? []).map((r) => new Date(r.created_at as string).getTime()),
    ipCount,
    {
      windowSeconds: config.otpRateWindowSeconds,
      maxPerPhone: config.otpMaxRequestsPerPhone,
      maxPerIp: config.otpMaxRequestsPerIp,
      resendCooldownSeconds: config.otpResendCooldownSeconds,
    },
    Date.now(),
  );
  if (!decision.allowed) {
    const headers: Record<string, string> = {};
    if (decision.retryAfterSeconds) {
      headers["Retry-After"] = String(decision.retryAfterSeconds);
    }
    return jsonResponse(
      {
        data: null,
        error: {
          code: decision.code ?? "OTP_RATE_LIMITED",
          message: "Too many OTP requests. Please wait before trying again.",
        },
      },
      { status: 429, headers },
    );
  }

  const otp = generateOtp();
  // ICA-B4: OTPs are keyed-hashed (HMAC under the server secret), never a bare
  // SHA-256 — a 6-digit code has only 10^6 preimages and would be reversible
  // from a DB dump. Verify path (handleVerifyOtp) must use the SAME hashOtp.
  const otpHash = await hashOtp(otp, config.jwtSecret);
  const expiresAt = expiresAtIso(config.otpTtlSeconds);

  const returnOtp = canReturnOtpInResponse(config, phone);
  const deliveryChannel = returnOtp ? "response" : "sms";

  const { error } = await client.from("otp_requests").insert({
    phone,
    otp_hash: otpHash,
    organization_slug: null,
    expires_at: expiresAt,
    ip_address: ip,
    delivery_channel: deliveryChannel,
    ...otpMeta,
  });
  if (error) {
    return errorEnvelope("SERVER_ERROR", error.message, 500);
  }

  // --- Delivery ---
  // Pilot/dev numbers receive the code in the response (no SMS spend).
  if (returnOtp) {
    return jsonResponse(
      envelope({
        success: true,
        message: "OTP issued (pilot/dev: returned in response, not by SMS).",
        otp,
        sessionId: crypto.randomUUID(),
      }),
    );
  }

  // Everyone else: real SMS. No code is ever leaked in the response.
  const smsConfig = smsConfigFrom(config);
  if (!isSmsConfigured(smsConfig)) {
    return errorEnvelope("SMS_NOT_CONFIGURED", "SMS provider is not configured", 503);
  }

  const sent = await sendOtpSms(smsConfig, phone, otp);
  if (!sent.ok) {
    return errorEnvelope(
      sent.code ?? "SMS_SEND_FAILED",
      sent.detail ?? "Failed to send OTP SMS",
      502,
    );
  }

  return jsonResponse(
    envelope({
      success: true,
      message: "OTP sent successfully.",
      sessionId: crypto.randomUUID(),
    }),
  );
}

export async function handleVerifyOtp(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const body = await readJson<VerifyOtpBody>(req);
  if (!body?.identifier || !body?.otp) {
    return errorEnvelope("VALIDATION_ERROR", "identifier and otp are required", 422);
  }

  const client = createServiceClient(config);

  let phone: string;
  let loginScope: AuthScope | undefined = body.scope;
  let loginSchoolId = body.schoolId;
  let loginStudentId = body.studentId;

  if (body.type === "student_id") {
    if (!body.schoolId) {
      return errorEnvelope("VALIDATION_ERROR", "schoolId is required for student_id login", 422);
    }
    const target = await resolveStudentLoginTargetWithClient(
      client,
      body.schoolId,
      body.identifier.trim(),
    );
    if (!target) {
      return errorEnvelope("STUDENT_LOGIN_NOT_FOUND", "Student account not provisioned", 404);
    }
    phone = target.phone;
    loginScope = "student";
    loginSchoolId = body.schoolId;
    loginStudentId = target.studentId;
  } else {
    try {
      phone = normalizePhone(body.identifier, body.type);
    } catch {
      return errorEnvelope("VALIDATION_ERROR", "Only phone or student_id OTP is supported", 422);
    }
  }

  const { data: otpRows, error: otpError } = await client
    .from("otp_requests")
    .select("*")
    .eq("phone", phone)
    .is("consumed_at", null)
    .order("created_at", { ascending: false })
    .limit(1);

  if (otpError || !otpRows?.length) {
    return errorEnvelope("OTP_INVALID", "OTP expired or not found", 401);
  }

  const otpRow = otpRows[0];
  if (new Date(otpRow.expires_at).getTime() < Date.now()) {
    return errorEnvelope("OTP_EXPIRED", "OTP has expired", 401);
  }
  if ((otpRow.attempts as number) >= config.otpMaxAttempts) {
    return errorEnvelope("OTP_LOCKED", "Too many invalid attempts", 429);
  }

  // ICA-B4: must mirror the store path's keyed hashOtp (same server secret).
  const submittedHash = await hashOtp(body.otp.trim(), config.jwtSecret);
  if (submittedHash !== otpRow.otp_hash) {
    await client.from("otp_requests").update({
      attempts: (otpRow.attempts as number) + 1,
    }).eq("id", otpRow.id);
    return errorEnvelope("OTP_INVALID", "Invalid OTP", 401);
  }

  await client.from("otp_requests").update({ consumed_at: new Date().toISOString() })
    .eq("id", otpRow.id);

  const { data: user, error: userError } = await client
    .from("users")
    .select("id,phone,email,display_name")
    .eq("phone", phone)
    .maybeSingle();

  if (userError || !user) {
    return errorEnvelope("USER_NOT_FOUND", "No user registered for this phone", 404);
  }

  const ctx = await resolveAuthSessionContext(client, user.id, {
    scope: loginScope ?? body.scope,
    schoolId: loginSchoolId,
    organizationId: body.organizationId,
    studentId: loginStudentId,
  });

  if (!ctx) {
    return errorEnvelope("MEMBERSHIP_NOT_FOUND", "No active membership for requested scope", 403);
  }

  try {
    const tokens = await issueSessionTokens(
      client,
      config,
      user as UserRow,
      ctx,
      req,
    );
    return jsonResponse(envelope(tokens));
  } catch (error) {
    return errorEnvelope(
      "SERVER_ERROR",
      error instanceof Error ? error.message : "Token issue failed",
      500,
    );
  }
}

export async function handleRefresh(req: Request, config: AppConfig): Promise<Response> {
  const body = await readJson<RefreshBody>(req);
  if (!body?.refreshToken) {
    return errorEnvelope("VALIDATION_ERROR", "refreshToken is required", 422);
  }

  const client = createServiceClient(config);
  const tokenHash = await hashToken(body.refreshToken);

  const { data: stored, error } = await client
    .from("refresh_tokens")
    .select("*")
    .eq("token_hash", tokenHash)
    .maybeSingle();

  if (error || !stored) {
    return errorEnvelope("REFRESH_INVALID", "Invalid refresh token", 401);
  }

  if (stored.used_at || stored.revoked_at) {
    await client.from("refresh_tokens").update({ revoked_at: new Date().toISOString() })
      .eq("family_id", stored.family_id);
    await client.from("sessions").update({ revoked_at: new Date().toISOString() })
      .eq("user_id", stored.user_id);
    return errorEnvelope("REFRESH_REUSE", "Refresh token reuse detected", 401);
  }

  if (new Date(stored.expires_at).getTime() < Date.now()) {
    return errorEnvelope("REFRESH_EXPIRED", "Refresh token expired", 401);
  }

  const { data: user } = await client.from("users").select("id,phone,email,display_name")
    .eq("id", stored.user_id).maybeSingle();
  if (!user) {
    return errorEnvelope("USER_NOT_FOUND", "User not found", 404);
  }

  const { data: session } = await client
    .from("sessions")
    .select(
      "scope,context_school_id,context_school_group_id,context_student_id,context_child_ids,tenant_id",
    )
    .eq("id", stored.session_id)
    .maybeSingle();

  if (!session) {
    return errorEnvelope("SESSION_NOT_FOUND", "Session not found", 401);
  }

  const ctx = await resolveAuthSessionContextFromSession(
    client,
    user.id,
    session as {
      scope: AuthScope;
      context_school_id: string | null;
      context_school_group_id: string | null;
      context_student_id: string | null;
      context_child_ids: string[] | null;
      tenant_id: string;
    },
  );

  if (!ctx) {
    return errorEnvelope("MEMBERSHIP_NOT_FOUND", "No active membership for session scope", 403);
  }

  await client.from("refresh_tokens").update({ used_at: new Date().toISOString() })
    .eq("id", stored.id);

  try {
    const tokens = await issueSessionTokens(
      client,
      config,
      user as UserRow,
      ctx,
      req,
      { includeUser: false },
    );
    return jsonResponse(envelope({
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: tokens.expiresAt,
      sessionId: tokens.sessionId,
      scope: tokens.scope,
    }));
  } catch (issueError) {
    return errorEnvelope(
      "SERVER_ERROR",
      issueError instanceof Error ? issueError.message : "Refresh failed",
      500,
    );
  }
}

export async function handleContextSwitch(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const token = bearerToken(req);
  if (!token) return errorEnvelope("UNAUTHORIZED", "Missing bearer token", 401);

  const currentClaims = await verifyAccessToken(config.jwtSecret, token);
  if (!currentClaims) return errorEnvelope("UNAUTHORIZED", "Invalid access token", 401);

  // PRA-P1-07 (S2): verifying the JWT signature alone is not enough for a
  // context switch. This route mints a BRAND-NEW session + refresh token from
  // the presented token, so a still-unexpired access token belonging to a
  // revoked/logged-out session (or a user whose membership was revoked) could
  // otherwise re-establish full access — defeating revocation entirely. Route
  // the switch through the same live-session/membership gate the normal request
  // path uses (RT-16/RT-17) before issuing anything.
  const sessionInvalid = await assertSessionValid(config, currentClaims);
  if (sessionInvalid) return sessionInvalid;

  const body = await readJson<ContextSwitchBody>(req);
  if (!body?.scope) {
    return errorEnvelope("VALIDATION_ERROR", "scope is required", 422);
  }

  const client = createServiceClient(config);
  const { data: user } = await client.from("users").select("id,phone,email,display_name")
    .eq("id", currentClaims.sub).maybeSingle();
  if (!user) {
    return errorEnvelope("USER_NOT_FOUND", "User not found", 404);
  }

  const ctx = await resolveAuthSessionContext(client, user.id, {
    scope: body.scope,
    schoolId: body.schoolId,
    organizationId: body.organizationId ?? currentClaims.tenant_id,
    studentId: body.studentId,
  });

  if (!ctx) {
    return errorEnvelope("CONTEXT_FORBIDDEN", "No membership for requested context", 403);
  }

  // Revoke prior session tokens before issuing new context (AuthArchitecture §2 context switch)
  await client.from("sessions").update({ revoked_at: new Date().toISOString() })
    .eq("id", currentClaims.session_id);
  await client.from("refresh_tokens").update({ revoked_at: new Date().toISOString() })
    .eq("session_id", currentClaims.session_id);

  try {
    const tokens = await issueSessionTokens(
      client,
      config,
      user as UserRow,
      ctx,
      req,
    );
    return jsonResponse(envelope({
      ...tokens,
      previousScope: currentClaims.scope,
    }));
  } catch (error) {
    return errorEnvelope(
      "SERVER_ERROR",
      error instanceof Error ? error.message : "Context switch failed",
      500,
    );
  }
}

export async function handleLogout(req: Request, config: AppConfig): Promise<Response> {
  const token = bearerToken(req);
  if (!token) return errorEnvelope("UNAUTHORIZED", "Missing bearer token", 401);

  const claims = await verifyAccessToken(config.jwtSecret, token);
  if (!claims) return errorEnvelope("UNAUTHORIZED", "Invalid access token", 401);

  const client = createServiceClient(config);
  await client.from("sessions").update({ revoked_at: new Date().toISOString() })
    .eq("id", claims.session_id);
  await client.from("refresh_tokens").update({ revoked_at: new Date().toISOString() })
    .eq("session_id", claims.session_id);

  return jsonResponse(envelope({ success: true }));
}

export async function handleLogoutAll(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const token = bearerToken(req);
  if (!token) return errorEnvelope("UNAUTHORIZED", "Missing bearer token", 401);

  const claims = await verifyAccessToken(config.jwtSecret, token);
  if (!claims) return errorEnvelope("UNAUTHORIZED", "Invalid access token", 401);

  const client = createServiceClient(config);
  const now = new Date().toISOString();
  await client.from("sessions").update({ revoked_at: now }).eq("user_id", claims.sub);
  await client.from("refresh_tokens").update({ revoked_at: now }).eq("user_id", claims.sub);

  return jsonResponse(envelope({ success: true }));
}

export async function handleRevokeSession(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const token = bearerToken(req);
  if (!token) return errorEnvelope("UNAUTHORIZED", "Missing bearer token", 401);

  const claims = await verifyAccessToken(config.jwtSecret, token);
  if (!claims) return errorEnvelope("UNAUTHORIZED", "Invalid access token", 401);

  const body = await readJson<RevokeSessionBody>(req);
  if (!body?.sessionId) {
    return errorEnvelope("VALIDATION_ERROR", "sessionId is required", 422);
  }

  const client = createServiceClient(config);
  const now = new Date().toISOString();
  await client.from("sessions").update({ revoked_at: now })
    .eq("id", body.sessionId)
    .eq("user_id", claims.sub);
  // ICA-B8: scope the refresh-token revoke to the CALLER's own tokens. Without
  // the user_id predicate, knowing another user's session UUID would revoke the
  // victim's refresh tokens (forced-logout DoS). refresh_tokens.user_id is NOT
  // NULL (see 20260607100000_core_platform_schema.sql).
  await client.from("refresh_tokens").update({ revoked_at: now })
    .eq("session_id", body.sessionId)
    .eq("user_id", claims.sub);

  return jsonResponse(envelope({ success: true }));
}

export async function handleMe(req: Request, config: AppConfig): Promise<Response> {
  const token = bearerToken(req);
  if (!token) return errorEnvelope("UNAUTHORIZED", "Missing bearer token", 401);

  const claims = await verifyAccessToken(config.jwtSecret, token);
  if (!claims) return errorEnvelope("UNAUTHORIZED", "Invalid access token", 401);

  const client = createServiceClient(config);
  // ICA-B9: no setRequestContext here. This is a service_role client, which
  // BYPASSES RLS; and set_request_context sets transaction-local GUCs while each
  // PostgREST call runs in its own transaction, so the context would not persist
  // to the read below — the call was an inert no-op that falsely implied tenant
  // scoping. service_role reads MUST carry their own explicit filter. This one is
  // safe because it is bounded to the caller by `.eq("id", claims.sub)` — any
  // future list/read on a service_role client must do the same.
  const { data: user } = await client.from("users").select("id,phone,email,display_name")
    .eq("id", claims.sub).maybeSingle();

  // PAR-7: rehydrate real linked-child details so a restored parent session
  // shows distinct children, not placeholder entries.
  const children = claims.scope === "parent" && claims.child_ids.length > 0
    ? await loadChildProfiles(client, claims.child_ids)
    : [];

  return jsonResponse(envelope({
    id: claims.sub,
    displayName: user?.display_name ?? "User",
    role: claims.role,
    scope: claims.scope,
    tenantId: claims.tenant_id,
    schoolId: claims.school_id,
    organizationId: claims.organization_id,
    studentId: claims.student_id,
    childIds: claims.child_ids,
    children,
    isChainOrganization: claims.is_chain_organization ?? false,
    email: user?.email,
    mobile: user?.phone,
  }));
}

export async function handlePermissions(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const token = bearerToken(req);
  if (!token) return errorEnvelope("UNAUTHORIZED", "Missing bearer token", 401);

  const claims = await verifyAccessToken(config.jwtSecret, token);
  if (!claims) return errorEnvelope("UNAUTHORIZED", "Invalid access token", 401);

  return jsonResponse(envelope({
    permissions: permissionsPayloadFromList(claims.permissions),
    permissionsVersion: claims.permissions_version,
    scope: claims.scope,
  }));
}

export function handleHealth(): Response {
  const { version, builtAt } = buildInfo();
  return jsonResponse(
    envelope({ status: "ok", service: "akshara-api", version, builtAt }),
  );
}

export async function handleReady(config: AppConfig): Promise<Response> {
  try {
    const client = createServiceClient(config);
    const { error } = await client.from("organizations").select("id").limit(1);
    if (error) {
      return jsonResponse(envelope({ status: "degraded", database: false }), { status: 503 });
    }
    return jsonResponse(envelope({ status: "ready", database: true }));
  } catch {
    return jsonResponse(envelope({ status: "degraded", database: false }), { status: 503 });
  }
}
