import { loadConfig } from "../_shared/config.ts";
import type { AppConfig } from "../_shared/config.ts";
import {
  handleHealth,
  handleContextSwitch,
  handleLogin,
  handleLogout,
  handleLogoutAll,
  handleMe,
  handlePermissions,
  handleReady,
  handleRefresh,
  handleRevokeSession,
  handleVerifyOtp,
} from "../_shared/auth_handlers.ts";
import { handleTenantAccessHealth, handleOperationsHealth, handleStorageHealth, handleProviderHealth, handleBackupHealth } from "../_shared/tenant_handlers.ts";
// ICA-F4: the module-router list is now a declarative registry (with per-router prefix
// ownership + rationale) in _shared/route_registry.ts. `matchModuleRoute` iterates it and
// returns null when no router owns the path; this file turns that single null into the one
// canonical 404. Every module router is non-greedy (returns null, never its own route-404).
import { isPublicModuleRoute, matchModuleRoute } from "../_shared/route_registry.ts";
import { isPublicRoute } from "../_shared/public_routes.ts";
import { authenticateRequest } from "../_shared/permission_middleware.ts";
import { bearerToken, verifyAccessToken } from "../_shared/jwt.ts";
import { errorEnvelope, routePath } from "../_shared/http.ts";
import { dispatchWithIdempotency } from "../_shared/idempotency_dispatch.ts";
import {
  recordAccessDenied,
  type AccessDeniedSink,
} from "../_shared/audit/access_denied_audit.ts";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  // `x-user-id` sits alongside `x-tenant-id` / `x-school-id` because the web
  // client sends all three once a session exists. Omitting it failed the browser
  // preflight, so every authenticated cross-origin request from app.nikshaos.in
  // was blocked — sign-in worked (no session header yet) and everything after it
  // did not. Allowing a header only permits the BROWSER to send it; the server
  // already accepted it from any non-browser client, and per the trust boundary
  // documented on resolveRequestIdentity these three are recorded for logging
  // only and never attribute an action.
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-api-version, x-correlation-id, x-tenant-id, x-school-id, x-organization-id, x-user-id, idempotency-key, x-internal-health-token",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, OPTIONS",
};

export async function routeModuleRequest(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response> {
  // ICA-F1: module-level auth/RBAC chokepoint. Every module route is authenticated
  // HERE, before dispatch — so no route can be unauthenticated by omission (a handler
  // that forgets its own `authenticateRequest` is still gated). Only the explicitly
  // allowlisted public routes (signature-authed webhooks) bypass this.
  //
  // SEC-AUTH-FIRST: `handleRequest` now runs the SAME gate one level higher, before it
  // matches any route at all. This check is therefore normally redundant — deliberately
  // so. It is kept because `routeModuleRequest` is exported and separately callable, and
  // because a defence that only exists at one level is one edit away from being gone
  // (which is exactly how the pilot came to answer an anonymous 422). It costs nothing:
  // `authenticateRequest` is memoized per Request, so the second call reuses the first
  // result with no extra session-validation DB read.
  //
  // Fine-grained RBAC (requirePermission/requireAnyPermission/scope) stays in the
  // handlers, unchanged — this gate guarantees AUTHENTICATION, not authorization.
  if (!isPublicModuleRoute(method, path)) {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;
  }

  // Universal store-and-replay idempotency (Data Reliability Platform §8.1):
  // every mutating module route carrying an `Idempotency-Key` replays exactly
  // once. Inert for any request without the header, so existing traffic is
  // unchanged.
  return dispatchWithIdempotency(req, config, async () => {
    // ICA-F4: the ordered, declarative module-route registry lives in
    // route_registry.ts. It returns null when no module router owns the path; this is
    // the SINGLE place a route-level 404 is produced (module routers never emit their
    // own route-404 — enforced by route_registry_test.ts).
    const matched = await matchModuleRoute(req, config, method, path);
    if (matched) return matched;
    return errorEnvelope(
      "NOT_FOUND",
      `Route not found: ${method} ${path}`,
      404,
    );
  });
}

/**
 * Who made the request — attached to every request log line so a support ticket
 * ("my child was marked absent on Tuesday") can be narrowed to actual traffic.
 * This log is the only durable per-request diagnostic the service produces, and
 * without an actor it could only ever be narrowed to a path and a minute.
 *
 * TRUST BOUNDARY. Everything above `tokenState` is read from the SIGNED access
 * token, verified here with the same HS256 check the auth middleware performs —
 * so it is attributable. The client also sends `X-User-Id` / `X-School-Id` /
 * `X-Tenant-Id`, which any caller can set to any value; those are recorded ONLY
 * under the `header*` names and must NEVER be used to attribute an action.
 * `headerIdentityMismatch` marks a request whose headers disagree with its
 * token — normally a stale client, occasionally worth a second look.
 *
 * PRIVACY (holds the discipline documented on `logRequest`): IDs only. Fields
 * deliberately EXCLUDED even though the verified token carries them:
 *   • `student_id` / `child_ids` — these identify the CHILD a request concerns.
 *     They are not needed to find a request (userId + sessionId + correlationId
 *     already do that) and logging them would turn a diagnostic log into a
 *     durable parent→child linkage dataset outside the RLS-protected DB.
 *   • `role` / `permissions` — not identifiers, and recoverable from `userId`.
 *   • everything else already excluded: bodies, tokens, query strings, names,
 *     phone numbers, marks, OTPs, free text.
 */
export interface RequestLogIdentity {
  /** Verified `sub` — the acting user. Null unless a valid token was presented. */
  userId: string | null;
  /** Verified `session_id` — which login/device, for "it only fails on my phone". */
  sessionId: string | null;
  /** Verified tenant (organization) id. */
  tenantId: string | null;
  /** Verified school id; null for org-scope tokens. */
  schoolId: string | null;
  /** Verified scope enum (school/parent/student/organization) — a role class, not a person. */
  scope: string | null;
  /**
   * `verified` — signature + expiry checked, ids above are attributable.
   * `invalid` — a token was presented but failed verification (expired/forged):
   *             the ids are unknown, which is itself the diagnostic.
   * `none` — no bearer at all (health, login, public webhooks).
   * `unverifiable` — config never loaded, so no secret to verify with.
   */
  tokenState: "verified" | "invalid" | "none" | "unverifiable";
  /** UNVERIFIED, client-supplied. Never attribution — only a narrowing hint. */
  headerUserId: string | null;
  headerSchoolId: string | null;
  headerTenantId: string | null;
  /** True when a supplied header contradicts the verified token. */
  headerIdentityMismatch: boolean;
}

function trimmedHeader(req: Request, name: string): string | null {
  const value = req.headers.get(name)?.trim();
  return value ? value : null;
}

/**
 * Resolves [RequestLogIdentity] for one request. Verification is a local HMAC
 * check (no DB read, no session lookup), so it costs the same as the auth
 * middleware's own verify and cannot fail the request: any error degrades to
 * `tokenState: "invalid"` with null ids. `jwtSecret` is null only on the
 * config-error path, where there is nothing to verify with.
 */
export async function resolveRequestIdentity(
  req: Request,
  jwtSecret: string | null,
): Promise<RequestLogIdentity> {
  const headerUserId = trimmedHeader(req, "x-user-id");
  const headerSchoolId = trimmedHeader(req, "x-school-id");
  const headerTenantId = trimmedHeader(req, "x-tenant-id");
  const anonymous = {
    userId: null,
    sessionId: null,
    tenantId: null,
    schoolId: null,
    scope: null,
    headerUserId,
    headerSchoolId,
    headerTenantId,
    headerIdentityMismatch: false,
  };

  let token: string | null = null;
  try {
    token = bearerToken(req);
  } catch (_) {
    token = null;
  }
  if (!token) return { ...anonymous, tokenState: "none" };
  if (!jwtSecret) return { ...anonymous, tokenState: "unverifiable" };

  let claims = null;
  try {
    claims = await verifyAccessToken(jwtSecret, token);
  } catch (_) {
    // verifyAccessToken already swallows its own failures; this is belt-and-braces
    // so observability can never break the response path.
    claims = null;
  }
  if (!claims) return { ...anonymous, tokenState: "invalid" };

  return {
    userId: claims.sub ?? null,
    sessionId: claims.session_id ?? null,
    tenantId: claims.tenant_id ?? null,
    schoolId: claims.school_id ?? null,
    scope: claims.scope ?? null,
    tokenState: "verified",
    headerUserId,
    headerSchoolId,
    headerTenantId,
    headerIdentityMismatch: (headerUserId !== null && headerUserId !== claims.sub) ||
      (headerTenantId !== null && headerTenantId !== claims.tenant_id) ||
      (headerSchoolId !== null && claims.school_id !== null &&
        headerSchoolId !== claims.school_id),
  };
}

/**
 * One structured JSON log line per request (Batch 7 observability). Captured by
 * `docker logs akshara-edge`. Carries method/path/status/duration, a correlation
 * id for tracing, and the actor identifiers in [RequestLogIdentity] so a ticket
 * can be narrowed to a user/school/session. Deliberately logs NO request/response
 * bodies, tokens, or query strings, so secrets never leak into logs — and no
 * names, phone numbers, marks, OTPs or free text either: IDs only.
 * Level: 50 server error, 40 client 4xx, 30 ok.
 *
 * `clientIp` is USUALLY NULL in production and that is expected, not a defect:
 * it is read from `X-Forwarded-For`, and the internal gateway that fronts this
 * function does not set that header, so there is no client address to record.
 * It is kept because a deployment that does front the service with a proxy will
 * populate it. Never treat a null `clientIp` as suspicious.
 */
function logRequest(
  fields: {
    method: string;
    path: string;
    status: number;
    durationMs: number;
    correlationId: string;
    clientIp: string | null;
    identity: RequestLogIdentity;
    error?: string;
  },
): void {
  const level = fields.status >= 500 ? 50 : fields.status >= 400 ? 40 : 30;
  const { identity, ...rest } = fields;
  console.log(JSON.stringify({
    level,
    time: new Date().toISOString(),
    type: "request",
    service: "akshara-api",
    ...rest,
    ...identity,
  }));
}

/**
 * Attaches CORS headers + the correlation id to a response. Applied to EVERY
 * response — success, NOT_FOUND, CONFIG_ERROR and SERVER_ERROR alike — so a
 * browser client always sees the real status (a 500 without CORS headers is
 * masked as an opaque CORS/network error in the browser) and every response is
 * traceable by its correlation id.
 */
function withCors(response: Response, correlationId: string): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders)) {
    headers.set(key, value);
  }
  headers.set("x-correlation-id", correlationId);
  return new Response(response.body, { status: response.status, headers });
}

/**
 * The full request handler, extracted from `Deno.serve` so it is unit-testable
 * without binding a socket (CI runs `deno test` with no `--allow-net`). `index.ts`
 * serves this verbatim; tests import it directly. `configLoader` is injectable so
 * the CONFIG_ERROR(500) path can be exercised with a throwing loader.
 */
export async function handleRequest(
  req: Request,
  configLoader: () => AppConfig = loadConfig,
  accessDeniedSink?: AccessDeniedSink,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startedAt = Date.now();
  const correlationId = req.headers.get("x-correlation-id") ?? crypto.randomUUID();
  const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null;

  let config;
  try {
    config = configLoader();
  } catch (error) {
    // ENG-7 (SEC-6): the real reason (e.g. "SUPABASE_URL missing") is logged
    // server-side only; the client gets a generic message so backend
    // configuration / env internals never leak. The correlation id (response
    // header + log line) is how support ties the two together.
    const detail = error instanceof Error ? error.message : "Configuration error";
    logRequest({
      method: req.method.toUpperCase(),
      path: routePath(req),
      status: 500,
      durationMs: Date.now() - startedAt,
      correlationId,
      clientIp,
      // No config means no jwtSecret, so the token cannot be verified here —
      // the header hints are all that can honestly be recorded.
      identity: await resolveRequestIdentity(req, null),
      error: detail,
    });
    return withCors(
      errorEnvelope("CONFIG_ERROR", "Server configuration error.", 500),
      correlationId,
    );
  }

  const path = routePath(req);
  const method = req.method.toUpperCase();
  // Resolved once, up front, so BOTH the normal and the unexpected-error log
  // line carry the same actor. A local HMAC verify — no DB read.
  const identity = await resolveRequestIdentity(req, config.jwtSecret ?? null);

  try {
    let response: Response;

    // ── SEC-AUTH-FIRST — authentication precedes validation AND dispatch ──────
    //
    // This is the FIRST thing that happens to a request after the correlation id
    // and config are resolved: before the route table below is consulted, before
    // any handler runs, and therefore before any body is read or any query
    // parameter is parsed. An anonymous caller to anything not on the one
    // declared allow-list gets exactly one answer — 401 — and learns nothing else.
    //
    // What this closes (all three confirmed against the live pilot):
    //   · GET /attendance/register/monthly answered `422 classLabel is required`.
    //     `handleAttendanceMonthlyRegister` validated its query string before
    //     calling `withAuth`, so an anonymous caller was handed the route's
    //     parameter contract. (The handler ordering is fixed too — see
    //     attendance_handlers.ts — but no gate may depend on ~664 handlers each
    //     getting their ordering right.)
    //   · GET /audit/events and GET /identity/roles answered `404 Route not
    //     found`. 404-vs-401 is route-existence disclosure: it lets an anonymous
    //     caller map the API surface by diffing status codes. Because this gate
    //     runs before the route is matched, a non-existent path and a real one
    //     are now indistinguishable — both 401. (The authenticated 404 is
    //     unchanged; see eng4_5_forced_auth_test.)
    //
    // The allow-list is declared once in `_shared/public_routes.ts`, with a
    // stated `guardedBy` for every entry, and is proven minimal + sufficient by
    // `auth_precedes_dispatch_guard_test.ts`.
    const gate = isPublicRoute(method, path)
      ? null
      : await authenticateRequest(req, config);
    if (gate && !gate.ok) {
      response = gate.response;
    } else if (method === "GET" && path === "/health") {
      response = handleHealth();
    } else if (method === "GET" && path === "/health/ready") {
      response = await handleReady(config);
    } else if (method === "GET" && path === "/health/tenant-access") {
      response = await handleTenantAccessHealth(req, config);
    } else if (method === "GET" && path === "/health/operations") {
      response = await handleOperationsHealth(req, config);
    } else if (method === "GET" && path === "/health/storage") {
      response = await handleStorageHealth(req, config);
    } else if (method === "GET" && path === "/health/providers") {
      response = await handleProviderHealth(req, config);
    } else if (method === "GET" && path === "/health/backup") {
      response = await handleBackupHealth(req, config);
    } else if (method === "POST" && path === "/auth/login") {
      response = await handleLogin(req, config);
    } else if (method === "POST" && path === "/auth/verify-otp") {
      response = await handleVerifyOtp(req, config);
    } else if (method === "POST" && path === "/auth/refresh") {
      response = await handleRefresh(req, config);
    } else if (method === "POST" && path === "/auth/logout") {
      response = await handleLogout(req, config);
    } else if (method === "POST" && path === "/auth/sessions/logout-all") {
      response = await handleLogoutAll(req, config);
    } else if (method === "POST" && path === "/auth/sessions/revoke") {
      response = await handleRevokeSession(req, config);
    } else if (method === "GET" && path === "/auth/me") {
      response = await handleMe(req, config);
    } else if (method === "GET" && path === "/auth/permissions") {
      response = await handlePermissions(req, config);
    } else if (method === "POST" && path === "/auth/context/switch") {
      response = await handleContextSwitch(req, config);
    } else {
      response = await routeModuleRequest(req, config, method, path);
    }

    // QA-X-017: every RBAC/scope denial (403 FORBIDDEN) is recorded as a
    // server-side access-denied audit event — observed once here rather than at
    // each requirePermission call site. Best-effort + never throws.
    if (response.status === 403) {
      await recordAccessDenied({
        req,
        config,
        response,
        method,
        path,
        correlationId,
        sink: accessDeniedSink,
      });
    }

    logRequest({
      method,
      path,
      status: response.status,
      durationMs: Date.now() - startedAt,
      correlationId,
      clientIp,
      identity,
    });
    return withCors(response, correlationId);
  } catch (error) {
    // ENG-7 (SEC-6): never surface a raw internal error (DB text, stack detail,
    // driver messages) to the client. The real message is logged server-side;
    // the client gets a generic envelope, traceable via the correlation id.
    const detail = error instanceof Error ? error.message : "Unexpected error";
    logRequest({
      method,
      path,
      status: 500,
      durationMs: Date.now() - startedAt,
      correlationId,
      clientIp,
      identity,
      error: detail,
    });
    return withCors(
      errorEnvelope("SERVER_ERROR", "An unexpected error occurred.", 500),
      correlationId,
    );
  }
}
