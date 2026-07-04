export function jsonResponse(
  body: unknown,
  init: ResponseInit = {},
): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
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
