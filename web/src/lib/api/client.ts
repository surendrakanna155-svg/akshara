import { API_CONFIG } from './config';

export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public details?: unknown,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

interface Session {
  token?: string;
  /** Rotating refresh token from /auth/verify-otp or /auth/refresh. */
  refreshToken?: string;
  /** ISO expiry of the ACCESS token, used to refresh slightly before it dies. */
  expiresAt?: string;
  sessionId?: string;
  tenantId?: string;
  schoolId?: string;
  userId?: string;
}

let session: Session = {};

/** Auth layer calls this after login so every request carries tenant + bearer. */
export function setApiSession(next: Session) {
  session = { ...session, ...next };
}

export function clearApiSession() {
  session = {};
  refreshInFlight = null;
}

/** Read-only view of the current session (auth layer persists it). */
export function getApiSession(): Readonly<Session> {
  return session;
}

// --- Token refresh -----------------------------------------------------------

export interface RefreshedTokens {
  token: string;
  refreshToken: string;
  expiresAt?: string;
  sessionId?: string;
}

let onTokensRefreshed: ((t: RefreshedTokens) => void) | null = null;
let onSessionExpired: (() => void) | null = null;

/**
 * The auth layer registers here so a refresh performed deep inside a data call
 * still updates React state + localStorage, and a dead refresh token logs out.
 */
export function setSessionCallbacks(cb: {
  onTokensRefreshed?: (t: RefreshedTokens) => void;
  onSessionExpired?: () => void;
}) {
  onTokensRefreshed = cb.onTokensRefreshed ?? null;
  onSessionExpired = cb.onSessionExpired ?? null;
}

/** Refresh a bit early so an in-flight request never races the expiry. */
const REFRESH_SKEW_MS = 30_000;

/**
 * Single-flight guard. The backend rotates refresh tokens and treats a REUSED
 * one as a breach — it revokes the whole token family AND every session for the
 * user. Two parallel refreshes would therefore log the user out permanently, so
 * concurrent callers MUST share one in-flight promise.
 */
let refreshInFlight: Promise<boolean> | null = null;

function accessTokenExpired(skewMs = REFRESH_SKEW_MS): boolean {
  if (!session.expiresAt) return false;
  const t = Date.parse(session.expiresAt);
  if (Number.isNaN(t)) return false;
  return t - skewMs <= Date.now();
}

/** True when a refresh is even possible. */
function canRefresh(): boolean {
  return Boolean(session.refreshToken);
}

/**
 * Exchange the refresh token for a new access+refresh pair. Uses a raw `fetch`
 * (never `apiFetch`) so it can never recurse into itself. Resolves true when the
 * session is usable again, false when it is gone for good.
 */
export function refreshAccessToken(): Promise<boolean> {
  if (!canRefresh()) return Promise.resolve(false);
  if (!refreshInFlight) {
    refreshInFlight = doRefresh().finally(() => {
      refreshInFlight = null;
    });
  }
  return refreshInFlight;
}

async function doRefresh(): Promise<boolean> {
  const presented = session.refreshToken;
  if (!presented) return false;
  const base = typeof window !== 'undefined' ? window.location.origin : undefined;
  const url = new URL(API_CONFIG.baseUrl + '/auth/refresh', base);

  let res: Response;
  try {
    res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        [API_CONFIG.headers.apiVersion]: API_CONFIG.apiVersion,
        [API_CONFIG.headers.correlationId]: correlationId(),
      },
      body: JSON.stringify({ refreshToken: presented }),
    });
  } catch {
    // Network blip — the session may still be fine. Keep it and let the caller
    // surface the network error rather than logging a working user out.
    return false;
  }

  const text = await res.text();
  const json = text ? safeParse(text) : null;

  if (!res.ok) {
    // 401/404 = the refresh token is invalid, expired, reused or revoked. That
    // session is unrecoverable; anything else (5xx) is transient — keep it.
    if (res.status === 401 || res.status === 404) expireSession();
    return false;
  }

  const data = (json && typeof json === 'object' && 'data' in json ? (json as { data: unknown }).data : json) as
    | { accessToken?: string; token?: string; refreshToken?: string; expiresAt?: string; sessionId?: string }
    | null;

  const token = data?.accessToken || data?.token;
  const refreshToken = data?.refreshToken;
  // The rotated refresh token is mandatory: keeping the presented one would
  // replay a SPENT token on the next refresh and trip reuse-detection.
  if (!token || !refreshToken) {
    expireSession();
    return false;
  }

  setApiSession({ token, refreshToken, expiresAt: data?.expiresAt, sessionId: data?.sessionId });
  onTokensRefreshed?.({ token, refreshToken, expiresAt: data?.expiresAt, sessionId: data?.sessionId });
  return true;
}

function expireSession() {
  clearApiSession();
  onSessionExpired?.();
}

/**
 * Auth endpoints that must never trigger (or be retried by) a token refresh:
 * the sign-in bootstrap (no session exists yet), the refresh call itself (it
 * would recurse), and logout — renewing a session we are in the act of ending
 * would leave the client holding fresh tokens for a signed-out user.
 */
function isAuthBootstrapPath(path: string): boolean {
  return (
    path === '/auth/login' ||
    path === '/auth/verify-otp' ||
    path === '/auth/refresh' ||
    path === '/auth/logout'
  );
}

function correlationId(): string {
  return 'web-' + Math.random().toString(36).slice(2, 10);
}

export interface RequestOptions extends Omit<RequestInit, 'body'> {
  body?: unknown;
  query?: Record<string, string | number | boolean | undefined>;
}

/**
 * Thin fetch wrapper over the Akshara REST edge function. Injects the standard
 * X- headers, bearer token, and normalizes error envelopes to ApiError.
 */
export async function apiFetch<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  // Proactive: the access token is expired (or about to be) and we hold a
  // refresh token → renew BEFORE spending a request on a guaranteed 401.
  if (!isAuthBootstrapPath(path) && canRefresh() && accessTokenExpired()) {
    await refreshAccessToken();
  }
  try {
    return await rawFetch<T>(path, opts);
  } catch (e) {
    // Reactive: the server rejected the token (short TTL, clock skew, rotation
    // in another tab). Refresh once and replay the request exactly once.
    if (e instanceof ApiError && e.status === 401 && !isAuthBootstrapPath(path) && canRefresh()) {
      const ok = await refreshAccessToken();
      if (ok) return await rawFetch<T>(path, opts);
    }
    throw e;
  }
}

async function rawFetch<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const { body, query, headers, ...rest } = opts;
  // Resolve against the current origin so a RELATIVE base (e.g. `/api` behind a
  // same-origin reverse proxy) works — `new URL()` alone requires an absolute URL.
  const base = typeof window !== 'undefined' ? window.location.origin : undefined;
  const url = new URL(API_CONFIG.baseUrl + path, base);
  if (query) {
    for (const [k, v] of Object.entries(query)) {
      if (v !== undefined) url.searchParams.set(k, String(v));
    }
  }

  const h = new Headers(headers);
  h.set('Content-Type', 'application/json');
  h.set(API_CONFIG.headers.apiVersion, API_CONFIG.apiVersion);
  h.set(API_CONFIG.headers.correlationId, correlationId());
  if (session.token) h.set('Authorization', `Bearer ${session.token}`);
  if (session.tenantId) h.set(API_CONFIG.headers.tenantId, session.tenantId);
  if (session.schoolId) h.set(API_CONFIG.headers.schoolId, session.schoolId);
  if (session.userId) h.set(API_CONFIG.headers.userId, session.userId);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), API_CONFIG.receiveTimeoutMs);

  let res: Response;
  try {
    res = await fetch(url, {
      ...rest,
      headers: h,
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal: controller.signal,
    });
  } catch (e) {
    clearTimeout(timer);
    throw new ApiError(0, 'network_error', (e as Error).message || 'Network error');
  }
  clearTimeout(timer);

  const text = await res.text();
  const json = text ? safeParse(text) : null;

  if (!res.ok) {
    const err = (json as { error?: { code?: string; message?: string } })?.error;
    throw new ApiError(res.status, err?.code || String(res.status), err?.message || res.statusText, json);
  }
  // Unwrap the common { data } envelope when present.
  if (json && typeof json === 'object' && 'data' in json) return (json as { data: T }).data;
  return json as T;
}

function safeParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}
