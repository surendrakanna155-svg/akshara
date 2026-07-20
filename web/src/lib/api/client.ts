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
