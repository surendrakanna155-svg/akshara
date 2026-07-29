// SEC-AUTH-FIRST — the ONE declaration of this API's unauthenticated surface.
//
// WHY THIS FILE EXISTS
// The pilot answered an anonymous `GET /attendance/register/monthly` with
// `422 classLabel is required`, and anonymous `GET /audit/events` /
// `GET /identity/roles` with `404 Route not found`. Both leak: the 422 hands out
// a route's parameter contract, and 404-vs-401 tells an unauthenticated caller
// which routes exist. Neither response should have been reachable without a
// session.
//
// The root cause was structural, not a single bad handler. The public/private
// decision was spread across three places that could drift apart:
//   1. the hand-written `if/else` chain in `api/app.ts` (every `/health/*` and
//      `/auth/*` route was public simply by being matched before the auth gate);
//   2. `PUBLIC_MODULE_ROUTE_PREFIXES` in `route_registry.ts` (webhooks only);
//   3. each handler's own ordering — e.g. `handleAttendanceMonthlyRegister`
//      parsed and validated query parameters BEFORE calling `withAuth`.
// Adding a route made it public by omission; nothing forced a decision.
//
// This module makes the decision explicit and singular. `api/app.ts` consults
// `isPublicRoute` ONCE, before it matches any route and before any handler can
// read a body or a query parameter — so every path not listed here answers 401,
// including paths that do not exist (an anonymous caller cannot enumerate the
// route table). `route_registry.ts` derives its module-level allow-list from the
// same table, and `api/auth_precedes_dispatch_guard_test.ts` proves behaviourally
// that nothing outside this table answers an anonymous request with anything
// other than 401.
//
// ADDING AN ENTRY IS A SECURITY DECISION. Every entry must say what
// authenticates the route INSTEAD of a user session (`guardedBy`); "nothing"
// is only acceptable for a route that returns no tenant data at all.

/** How a request is matched against an allow-list entry. */
export type PublicRouteMatch =
  /** One exact method+path. The default: an allow-list entry should be as narrow as possible. */
  | { readonly kind: "exact"; readonly method: string; readonly path: string }
  /**
   * A path prefix, method-agnostic. Only for families that are public by the
   * same mechanism and whose membership is not fully known at build time (the
   * payment-gateway webhook namespace).
   */
  | { readonly kind: "prefix"; readonly path: string };

export interface PublicRouteEntry {
  readonly match: PublicRouteMatch;
  /**
   * Which dispatch surface the route lives on:
   *   "top-level" — matched by the `if/else` chain in `api/app.ts`
   *   "module"    — matched by a module router via the route registry
   * `route_registry.ts` uses this to derive the module-scope allow-list.
   */
  readonly surface: "top-level" | "module";
  /** What authenticates this route INSTEAD of a user session. */
  readonly guardedBy: string;
  /** Why it cannot require a session. */
  readonly reason: string;
}

/**
 * THE allow-list. Derived from the code, not from intent:
 *
 *  · `/health` — `handleHealth()` takes neither a Request nor an AppConfig, so it
 *    cannot consult auth or the database. It is the gateway/uptime liveness probe
 *    and returns only `{status, service, version, builtAt}`. Requiring a session
 *    would make liveness depend on the auth path it is supposed to observe.
 *
 *  · `/health/ready` — the container/watchdog readiness probe
 *    (deploy/akshara-vps/monitoring/akshara-watchdog.sh:106). Returns only
 *    `{status, database: boolean}`: no tenant data, no counts, no internals.
 *    Same argument as liveness — a readiness probe that needs a login cannot
 *    report that login is broken.
 *
 *  · the five sensitive `/health/*` probes — these are NOT open. Each runs
 *    `requireInternalHealthAccess` as its first statement (tenant_handlers.ts),
 *    a constant-time compare against `INTERNAL_HEALTH_TOKEN` that fails closed in
 *    production, and answers 403 to an anonymous caller. They are allow-listed
 *    from the *session* gate because the operator probes them with an internal
 *    token and no user session — putting them behind the JWT gate would break the
 *    watchdog while adding nothing (they are already gated).
 *
 *  · `/auth/login`, `/auth/verify-otp`, `/auth/refresh` — the credential-exchange
 *    endpoints. No session can exist yet (login/OTP) or the access token is by
 *    definition expired (refresh, which authenticates on the refresh token in the
 *    body). Every OTHER `/auth/*` route carries a session and is NOT listed here:
 *    `/auth/me`, `/auth/permissions`, `/auth/logout`, `/auth/sessions/logout-all`,
 *    `/auth/sessions/revoke` and `/auth/context/switch` now pass through the same
 *    central gate as everything else.
 *
 *  · `/webhooks/` and `/communications/delivery/webhook` — third-party callbacks
 *    that authenticate by HMAC signature (`verifyRazorpayWebhookSignature`,
 *    `verifyCommunicationWebhookSignature`). The caller is a payment gateway or an
 *    SMS provider; it has no user session and never will.
 */
export const PUBLIC_ROUTES: readonly PublicRouteEntry[] = [
  {
    match: { kind: "exact", method: "GET", path: "/health" },
    surface: "top-level",
    guardedBy: "nothing — by design; discloses no tenant data",
    reason: "Liveness probe. handleHealth() receives no Request and no AppConfig, so it cannot read auth or the DB.",
  },
  {
    match: { kind: "exact", method: "GET", path: "/health/ready" },
    surface: "top-level",
    guardedBy: "nothing — by design; returns only {status, database:boolean}",
    reason: "Readiness probe used by the deploy watchdog and container health check; must work when auth is broken.",
  },
  {
    match: { kind: "exact", method: "GET", path: "/health/tenant-access" },
    surface: "top-level",
    guardedBy: "requireInternalHealthAccess — x-internal-health-token, constant-time, fail-closed in production (403)",
    reason: "Operator probe with an internal token and no user session; already gated, so the session gate would only break ops.",
  },
  {
    match: { kind: "exact", method: "GET", path: "/health/operations" },
    surface: "top-level",
    guardedBy: "requireInternalHealthAccess (403 to an anonymous caller)",
    reason: "Operator probe with an internal token and no user session.",
  },
  {
    match: { kind: "exact", method: "GET", path: "/health/storage" },
    surface: "top-level",
    guardedBy: "requireInternalHealthAccess (403 to an anonymous caller)",
    reason: "Operator probe with an internal token and no user session.",
  },
  {
    match: { kind: "exact", method: "GET", path: "/health/providers" },
    surface: "top-level",
    guardedBy: "requireInternalHealthAccess (403 to an anonymous caller)",
    reason: "Operator probe with an internal token and no user session.",
  },
  {
    match: { kind: "exact", method: "GET", path: "/health/backup" },
    surface: "top-level",
    guardedBy: "requireInternalHealthAccess (403 to an anonymous caller)",
    reason: "Operator probe with an internal token and no user session.",
  },
  {
    match: { kind: "exact", method: "POST", path: "/auth/login" },
    surface: "top-level",
    guardedBy: "the credential itself (phone + OTP issuance) plus OTP rate limiting",
    reason: "Entry point to authentication — no session can exist yet.",
  },
  {
    match: { kind: "exact", method: "POST", path: "/auth/verify-otp" },
    surface: "top-level",
    guardedBy: "the OTP secret + attempt/rate limits (otp_rate_limit.ts)",
    reason: "Second leg of login — the session is what this route creates.",
  },
  {
    match: { kind: "exact", method: "POST", path: "/auth/refresh" },
    surface: "top-level",
    guardedBy: "the refresh token in the body (hashed lookup + reuse detection)",
    reason: "Exists precisely to be callable when the access token is expired; requiring one would deadlock the client.",
  },
  {
    match: { kind: "prefix", path: "/webhooks/" },
    surface: "module",
    guardedBy: "per-gateway HMAC signature verification in the handler (verifyRazorpayWebhookSignature)",
    reason: "Payment-gateway server-to-server callback; the caller has no user session. A prefix so a second gateway is covered without a code change.",
  },
  {
    match: { kind: "exact", method: "POST", path: "/communications/delivery/webhook" },
    surface: "module",
    guardedBy: "verifyCommunicationWebhookSignature (HMAC)",
    reason: "SMS/message-provider delivery-status callback; the caller has no user session.",
  },
] as const;

function matches(entry: PublicRouteEntry, method: string, path: string): boolean {
  if (entry.match.kind === "prefix") {
    const p = entry.match.path;
    return path === p.replace(/\/$/, "") || path.startsWith(p);
  }
  return entry.match.method === method.toUpperCase() && entry.match.path === path;
}

/**
 * True when (method, path) is an explicitly-declared public route. Consulted by
 * `api/app.ts` BEFORE any route matching, body read or parameter parse: anything
 * this returns false for is answered 401 without the request touching a handler.
 */
export function isPublicRoute(method: string, path: string): boolean {
  return PUBLIC_ROUTES.some((e) => matches(e, method, path));
}

/**
 * The module-router subset, used by `route_registry.ts` so the module-level
 * chokepoint and the central gate can never disagree about what is public.
 */
export function isPublicModuleSurfaceRoute(method: string, path: string): boolean {
  return PUBLIC_ROUTES.some((e) => e.surface === "module" && matches(e, method, path));
}
