// PRC-A Batch 2 — Student Health / Infirmary router.
//
// Prefix is `/student-health`, NOT `/health`: `/health` is already the system
// health/readiness surface in api/app.ts, and colliding with it would be both a
// routing bug and a spectacularly bad place to accidentally serve child medical
// data from.
//
// Wiring into api/app.ts is the orchestrator's job — this module does not touch
// the shared app entrypoint.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAdministerMedication,
  handleCreateAuthorization,
  handleCreateCareAlert,
  handleCreateIncident,
  handleGetCareAlert,
  handleGetStudentRecord,
  handleListAccessLog,
  handleListIncidents,
  handleRevokeAuthorization,
  handleUpdateCareAlert,
} from "./student_health_handlers.ts";

type HealthHandler = (
  req: Request,
  config: AppConfig,
  ...args: string[]
) => Promise<Response>;

export function matchStudentHealthRoute(
  method: string,
  path: string,
): { handler: HealthHandler; args: string[] } | null {
  if (path === "/student-health/incidents") {
    if (method === "POST") return { handler: handleCreateIncident, args: [] };
    if (method === "GET") return { handler: handleListIncidents, args: [] };
  }

  if (path === "/student-health/care-alerts" && method === "POST") {
    return { handler: handleCreateCareAlert, args: [] };
  }

  const alertPatch = path.match(/^\/student-health\/care-alerts\/([^/]+)$/);
  if (alertPatch && method === "PATCH") {
    return { handler: handleUpdateCareAlert, args: [alertPatch[1]!] };
  }

  if (path === "/student-health/authorizations" && method === "POST") {
    return { handler: handleCreateAuthorization, args: [] };
  }

  const revokeMatch = path.match(
    /^\/student-health\/authorizations\/([^/]+)\/revoke$/,
  );
  if (revokeMatch && method === "POST") {
    return { handler: handleRevokeAuthorization, args: [revokeMatch[1]!] };
  }

  const administerMatch = path.match(
    /^\/student-health\/authorizations\/([^/]+)\/administer$/,
  );
  if (administerMatch && method === "POST") {
    return { handler: handleAdministerMedication, args: [administerMatch[1]!] };
  }

  // The teacher surface — matched BEFORE /record so the specific path wins.
  const careAlertMatch = path.match(
    /^\/student-health\/students\/([^/]+)\/care-alert$/,
  );
  if (careAlertMatch && method === "GET") {
    return { handler: handleGetCareAlert, args: [careAlertMatch[1]!] };
  }

  const recordMatch = path.match(/^\/student-health\/students\/([^/]+)\/record$/);
  if (recordMatch && method === "GET") {
    return { handler: handleGetStudentRecord, args: [recordMatch[1]!] };
  }

  if (path === "/student-health/access-log" && method === "GET") {
    return { handler: handleListAccessLog, args: [] };
  }

  return null;
}

export async function routeStudentHealth(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  // `null` = not ours; the next router in the chain tries.
  if (!path.startsWith("/student-health")) return null;

  const match = matchStudentHealthRoute(method, path);
  if (!match) {
    // Inside our prefix but unmatched: a definitive 404, NOT null — returning
    // null would let another router claim a /student-health path.
    return null;
  }

  return await match.handler(req, config, ...match.args);
}
