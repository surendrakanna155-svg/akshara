import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AppConfig } from "./config.ts";
import {
  bearerToken,
  expiresAtIso,
  hashToken,
  randomToken,
  signAccessToken,
  verifyAccessToken,
} from "./jwt.ts";
import {
  permissionsPayloadFromList,
  resolveSchoolMembershipPermissions,
} from "./permission_resolver.ts";
import {
  createServiceClient,
  type SchoolMembershipRow,
  type UserRow,
} from "./db.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "./http.ts";

interface LoginBody {
  identifier?: string;
  type?: string;
}

interface VerifyOtpBody {
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

async function resolvePrimaryMembership(
  client: SupabaseClient,
  userId: string,
): Promise<SchoolMembershipRow | null> {
  const { data, error } = await client
    .from("school_memberships")
    .select(
      "id,user_id,school_id,role,permissions_version,schools(id,organization_id,name,code),school_membership_roles(role_slug,is_primary,status)",
    )
    .eq("user_id", userId)
    .eq("status", "active")
    .limit(1)
    .maybeSingle();

  if (error || !data) return null;
  return data as unknown as SchoolMembershipRow;
}

async function issueSessionTokens(
  client: SupabaseClient,
  config: AppConfig,
  user: UserRow,
  membership: SchoolMembershipRow,
  req: Request,
) {
  const organizationId = membership.schools.organization_id;
  const resolved = await resolveSchoolMembershipPermissions(
    client,
    membership.id,
    membership.role,
    membership.permissions_version,
  );
  const sessionId = crypto.randomUUID();
  const refreshToken = randomToken();
  const refreshHash = await hashToken(refreshToken);
  const familyId = crypto.randomUUID();

  const { error: sessionError } = await client.from("sessions").insert({
    id: sessionId,
    user_id: user.id,
    tenant_id: organizationId,
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

  const accessToken = await signAccessToken(
    config.jwtSecret,
    {
      sub: user.id,
      tenant_id: organizationId,
      organization_id: organizationId,
      school_id: membership.school_id,
      role: resolved.primaryRole,
      role_slugs: resolved.roleSlugs,
      primary_role: resolved.primaryRole,
      permissions: resolved.permissions,
      permissions_version: resolved.permissionsVersion,
      scope: "school",
      school_group_id: null,
      session_id: sessionId,
    },
    config.accessTokenTtlSeconds,
  );

  return {
    accessToken,
    refreshToken,
    expiresAt: expiresAtIso(config.accessTokenTtlSeconds),
    sessionId,
    permissions: permissionsPayloadFromList(resolved.permissions),
    user: {
      id: user.id,
      displayName: user.display_name,
      role: resolved.primaryRole,
      tenantId: organizationId,
      schoolId: membership.school_id,
      organizationId,
      email: user.email,
      mobile: user.phone,
    },
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

  // SMS dispatch via external provider — credentials from environment (not implemented in Sprint 2).
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

  const membership = await resolvePrimaryMembership(client, user.id);
  if (!membership) {
    return errorEnvelope("MEMBERSHIP_NOT_FOUND", "No active school membership", 403);
  }

  try {
    const tokens = await issueSessionTokens(
      client,
      config,
      user as UserRow,
      membership,
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

  const membership = await resolvePrimaryMembership(client, user.id);
  if (!membership) {
    return errorEnvelope("MEMBERSHIP_NOT_FOUND", "No active school membership", 403);
  }

  await client.from("refresh_tokens").update({ used_at: new Date().toISOString() })
    .eq("id", stored.id);

  try {
    const tokens = await issueSessionTokens(
      client,
      config,
      user as UserRow,
      membership,
      req,
    );
    return jsonResponse(envelope({
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: tokens.expiresAt,
      sessionId: tokens.sessionId,
    }));
  } catch (issueError) {
    return errorEnvelope(
      "SERVER_ERROR",
      issueError instanceof Error ? issueError.message : "Refresh failed",
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
  const { data: user } = await client.from("users").select("id,phone,email,display_name")
    .eq("id", claims.sub).maybeSingle();

  return jsonResponse(envelope({
    id: claims.sub,
    displayName: user?.display_name ?? "User",
    role: claims.role,
    tenantId: claims.tenant_id,
    schoolId: claims.school_id,
    organizationId: claims.organization_id,
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
