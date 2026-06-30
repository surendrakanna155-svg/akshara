import type { AppConfig } from "../config.ts";
import { bearerToken, verifyAccessToken } from "../jwt.ts";

/**
 * QW6 · QA-X-017 — server-side denied-access audit.
 *
 * The Flutter client already records a denied-access audit when a route guard
 * blocks navigation (`lib/core/security/denied_access_audit.dart`). The backend
 * had the matching gap: `requirePermission` / `requireAnyPermission` return a
 * 403 FORBIDDEN with **no** audit trail, so a blocked mutation left no
 * security-observability record server-side.
 *
 * This closes it at the **single request choke point** (`handleRequest`) rather
 * than touching all ~29 `requirePermission` call sites: every response that
 * carries a 403 is observed once and emitted as a structured `access_denied`
 * event on the same channel `logRequest` already uses. No request/response
 * bodies, tokens, or query strings are ever logged.
 */
export interface AccessDeniedEvent {
  type: "access_denied";
  time: string;
  /** Subject of the (valid) token that was denied; "unknown" if absent/invalid. */
  actorId: string;
  tenantId: string | null;
  schoolId: string | null;
  scope: string | null;
  method: string;
  path: string;
  status: 403;
  /** The FORBIDDEN envelope message, e.g. "Permission required: manageFinance". */
  reason: string;
  /** The required permission(s) parsed from [reason], when present. */
  requiredPermission: string | null;
  correlationId: string;
}

export type AccessDeniedSink = (event: AccessDeniedEvent) => void | Promise<void>;

/**
 * Default sink: one structured log line (level 40 = client 4xx), captured by
 * `docker logs akshara-edge` and the monitoring pipeline — the same observability
 * channel the per-request log uses.
 */
export const consoleAccessDeniedSink: AccessDeniedSink = (event) => {
  console.log(JSON.stringify({ service: "akshara-api", level: 40, ...event }));
};

const PERMISSION_RE = /Permission required: (?:one of )?(.+)$/;

/** Extracts the required permission(s) from a FORBIDDEN envelope message. */
export function parseRequiredPermission(reason: string | undefined): string | null {
  if (!reason) return null;
  const match = PERMISSION_RE.exec(reason);
  return match ? match[1].trim() : null;
}

/**
 * Emits an [AccessDeniedEvent] when [response] is a 403. Best-effort actor
 * resolution: a 403 means a *valid* token that simply lacked the permission, so
 * re-verifying the bearer recovers the actor; an absent/invalid token yields
 * "unknown". Reads the body via `clone()` so the response returned to the client
 * is untouched. Never throws — observability must not break the response path.
 *
 * Returns the emitted event (for tests) or `null` when nothing was emitted.
 */
export async function recordAccessDenied(args: {
  req: Request;
  config: AppConfig;
  response: Response;
  method: string;
  path: string;
  correlationId: string;
  sink?: AccessDeniedSink;
  now?: () => Date;
}): Promise<AccessDeniedEvent | null> {
  if (args.response.status !== 403) return null;
  const sink = args.sink ?? consoleAccessDeniedSink;

  let reason = "Forbidden";
  let requiredPermission: string | null = null;
  try {
    const env = await args.response.clone().json();
    reason = env?.error?.message ?? reason;
    requiredPermission = parseRequiredPermission(reason);
  } catch (_) {
    // Non-JSON 403 — keep the default reason.
  }

  let actorId = "unknown";
  let tenantId: string | null = null;
  let schoolId: string | null = null;
  let scope: string | null = null;
  try {
    const token = bearerToken(args.req);
    if (token) {
      const claims = await verifyAccessToken(args.config.jwtSecret, token);
      if (claims) {
        actorId = claims.sub;
        tenantId = claims.tenant_id ?? null;
        schoolId = claims.school_id ?? null;
        scope = claims.scope ?? null;
      }
    }
  } catch (_) {
    // Best-effort actor resolution only.
  }

  const event: AccessDeniedEvent = {
    type: "access_denied",
    time: (args.now ?? (() => new Date()))().toISOString(),
    actorId,
    tenantId,
    schoolId,
    scope,
    method: args.method,
    path: args.path,
    status: 403,
    reason,
    requiredPermission,
    correlationId: args.correlationId,
  };

  try {
    await sink(event);
  } catch (_) {
    // Never break the response path on an audit-sink failure.
  }
  return event;
}
