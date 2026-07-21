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
import { authenticateRequest } from "../_shared/permission_middleware.ts";
import { errorEnvelope, routePath } from "../_shared/http.ts";
import { dispatchWithIdempotency } from "../_shared/idempotency_dispatch.ts";
import {
  recordAccessDenied,
  type AccessDeniedSink,
} from "../_shared/audit/access_denied_audit.ts";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-api-version, x-correlation-id, x-tenant-id, x-school-id, x-organization-id, idempotency-key, x-internal-health-token",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, OPTIONS",
};

export async function routeModuleRequest(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response> {
  // ICA-F1: central auth/RBAC chokepoint. Every module route is authenticated HERE,
  // before dispatch — so no route can be unauthenticated by omission (a handler that
  // forgets its own `authenticateRequest` is still gated). Only the explicitly
  // allowlisted public routes (signature-authed webhooks) bypass this. The result is
  // memoized on the request, so the handlers' own `authenticateRequest` calls (and the
  // idempotency scope resolver) reuse it with no extra session-validation DB read.
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
 * One structured JSON log line per request (Batch 7 observability). Captured by
 * `docker logs akshara-edge`. Carries method/path/status/duration + a correlation
 * id for tracing. Deliberately logs NO request/response bodies, tokens, or query
 * strings, so secrets never leak into logs. Level: 50 server error, 40 client 4xx,
 * 30 ok.
 */
function logRequest(
  fields: {
    method: string;
    path: string;
    status: number;
    durationMs: number;
    correlationId: string;
    clientIp: string | null;
    error?: string;
  },
): void {
  const level = fields.status >= 500 ? 50 : fields.status >= 400 ? 40 : 30;
  console.log(JSON.stringify({
    level,
    time: new Date().toISOString(),
    type: "request",
    service: "akshara-api",
    ...fields,
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
      error: detail,
    });
    return withCors(
      errorEnvelope("CONFIG_ERROR", "Server configuration error.", 500),
      correlationId,
    );
  }

  const path = routePath(req);
  const method = req.method.toUpperCase();

  try {
    let response: Response;

    if (method === "GET" && path === "/health") {
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
      error: detail,
    });
    return withCors(
      errorEnvelope("SERVER_ERROR", "An unexpected error occurred.", 500),
      correlationId,
    );
  }
}
