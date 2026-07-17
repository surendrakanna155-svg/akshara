/**
 * Production security certification (final holistic review) — baseline defensive
 * response headers applied to EVERY API response from the one central helper.
 * This is a JSON API consumed by the Flutter client, so the browser-context headers
 * are pure defense-in-depth (a strict `default-src 'none'` CSP + `frame-ancestors
 * 'none'` are safe because the API serves no HTML/scripts to load or frame):
 *   - nosniff: never MIME-sniff a JSON body into something executable.
 *   - X-Frame-Options / frame-ancestors: the API can never be framed (clickjacking).
 *   - Referrer-Policy: never leak the request URL (which can carry ids) as a referrer.
 * TLS/HSTS is terminated + set at the gateway layer (not the app), by design.
 */
export const SECURITY_HEADERS: Record<string, string> = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "no-referrer",
  "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
};

export function jsonResponse(
  body: unknown,
  init: ResponseInit = {},
): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...SECURITY_HEADERS,
      ...init.headers ?? {},
    },
  });
}

export function envelope(data: unknown) {
  return { data, error: null };
}

/**
 * ENG-8 (SEC-11): default cap on a client-supplied bulk-write array. Bounds
 * per-request memory + per-row DB work so an oversized payload can't exhaust the
 * edge worker (a cheap DoS). Bulk handlers validate `array.length <= this`
 * BEFORE doing any work and reject with 422 otherwise. Generous enough for a
 * whole-grade operation; individual endpoints may pass a tighter limit.
 */
export const MAX_BULK_ITEMS = 500;

export function errorEnvelope(
  code: string,
  message: string,
  status = 400,
): Response {
  return jsonResponse(
    {
      data: null,
      error: { code, message },
    },
    { status },
  );
}

export async function readJson<T>(req: Request): Promise<T | null> {
  try {
    return await req.json() as T;
  } catch {
    return null;
  }
}

export function routePath(req: Request): string {
  const url = new URL(req.url);
  const pathname = url.pathname;
  const markers = ["/functions/v1/api", "/api"];
  for (const marker of markers) {
    const index = pathname.indexOf(marker);
    if (index >= 0) {
      const rest = pathname.slice(index + marker.length);
      return rest.length === 0 ? "/" : rest;
    }
  }
  return pathname;
}
