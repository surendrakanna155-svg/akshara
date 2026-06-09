import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppConfig } from "./config.ts";
import {
  type AuthScope,
  bearerToken,
  expiresAtIso,
  hashToken,
  randomToken,
  signAccessToken,
  verifyAccessToken,
} from "./jwt.ts";
import {
  type AuthSessionContext,
  resolveAuthSessionContext,
  resolveAuthSessionContextFromSession,
  type ScopeLoginRequest,
} from "./auth_context.ts";
import { permissionsPayloadFromList } from "./permission_resolver.ts";
import { setRequestContext } from "./request_context.ts";
import { createServiceClient, type UserRow } from "./db.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "./http.ts";

interface LoginBody {
  identifier?: string;
  type?: string;
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

function generateOtp(): string {
  return `${Math.floor(100000 + Math.random() * 900000)}`;
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

  let phone: string;
  try {
    phone = normalizePhone(body.identifier, body.type);
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Only phone OTP is supported in v6.0", 422);
  }

  const client = createServiceClient(config);
  const otp = generateOtp();
  const otpHash = await hashToken(otp);
  const expiresAt = expiresAtIso(config.otpTtlSeconds);

  const { error } = await client.from("otp_requests").insert({
    phone,
    otp_hash: otpHash,
    organization_slug: null,
    expires_at: expiresAt,
  });
  if (error) {
    return errorEnvelope("SERVER_ERROR", error.message, 500);
  }

  if (!config.otpDevMode && config.environment === "production") {
    const smsConfigured = Boolean(Deno.env.get("SMS_PROVIDER_API_KEY"));
    if (!smsConfigured) {
      return errorEnvelope("SMS_NOT_CONFIGURED", "SMS provider is not configured", 503);
    }
  }

  const message = config.otpDevMode
    ? `OTP sent (dev mode). Use code ${otp} for ${phone}.`
    : "OTP sent successfully.";

  return jsonResponse(
    envelope({
      success: true,
      message,
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

  let phone: string;
  try {
    phone = normalizePhone(body.identifier, body.type);
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Only phone OTP is supported in v6.0", 422);
  }

  const client = createServiceClient(config);
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

  const submittedHash = await hashToken(body.otp.trim());
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
    scope: body.scope,
    schoolId: body.schoolId,
    organizationId: body.organizationId,
    studentId: body.studentId,
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
  await client.from("refresh_tokens").update({ revoked_at: now })
    .eq("session_id", body.sessionId);

  return jsonResponse(envelope({ success: true }));
}

export async function handleMe(req: Request, config: AppConfig): Promise<Response> {
  const token = bearerToken(req);
  if (!token) return errorEnvelope("UNAUTHORIZED", "Missing bearer token", 401);

  const claims = await verifyAccessToken(config.jwtSecret, token);
  if (!claims) return errorEnvelope("UNAUTHORIZED", "Invalid access token", 401);

  const client = createServiceClient(config);
  await setRequestContext(client, claims);

  const { data: user } = await client.from("users").select("id,phone,email,display_name")
    .eq("id", claims.sub).maybeSingle();

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
  return jsonResponse(envelope({ status: "ok", service: "akshara-api" }));
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
