// P1-PROD-22 SLICE 1 — attendance-auth router. Routes:
//   POST /attendance-auth/face/enroll        enrol/replace a reference face (self, or targetUserId + manageHr)
//   GET  /attendance-auth/face/enrollment    read own enrollment status (never the embedding)
//   POST /attendance-auth/face/revoke        revoke a reference face (self, or targetUserId + manageHr)
//
// Distinct from /staff-attendance (the SLICE 2 check-in verification chain,
// which this slice does not touch); this router owns enrollment only.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import { authenticateRequest } from "../permission_middleware.ts";
import {
  handleEnrollFace,
  handleGetEnrollmentStatus,
  handleRevokeFaceEnrollment,
} from "./face_enrollment_handlers.ts";

type Handler = (req: Request, config: AppConfig) => Promise<Response>;

/** Keyed by path -> {method: handler}, so a known path with the WRONG method
 * 405s (rather than collapsing into the generic 404 an unknown path gets). */
function matchAttendanceAuthRoute(path: string): Partial<Record<string, Handler>> | null {
  if (path === "/attendance-auth/face/enroll") {
    return { POST: handleEnrollFace };
  }
  if (path === "/attendance-auth/face/enrollment") {
    return { GET: handleGetEnrollmentStatus };
  }
  if (path === "/attendance-auth/face/revoke") {
    return { POST: handleRevokeFaceEnrollment };
  }
  return null;
}

export async function routeAttendanceAuth(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/attendance-auth")) return null;

  const route = matchAttendanceAuthRoute(path);
  if (!route) {
    return null;
  }

  // SEC-AUTH-FIRST: authenticate BEFORE answering 405. A 405 is a disclosure —
  // it tells an anonymous caller that this path exists and which method it wants,
  // which is the same leak as the 422 the live pilot returned from the attendance
  // register. Every other status this router can produce already required a
  // session; the method check was the one that did not. `authenticateRequest` is
  // memoized per Request, so this does not add a second session lookup.
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const handler = route[method];
  if (!handler) {
    return errorEnvelope("METHOD_NOT_ALLOWED", `Method not allowed: ${method} ${path}`, 405);
  }
  return await handler(req, config);
}
