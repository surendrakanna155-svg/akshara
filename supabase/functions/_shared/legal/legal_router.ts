import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAcceptPolicies,
  handleGetLegalStatus,
} from "./legal_handlers.ts";

/**
 * Routes for the in-app legal acceptance gate. Open to any authenticated principal
 * (no RBAC permission), since accepting the mandatory policies is a per-user
 * obligation rather than a privileged action.
 *
 *   GET  /legal/status  → what the current user must accept, has accepted, owes
 *   POST /legal/accept  → record acceptance of one or more policies
 */
export async function routeLegal(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/legal")) return null;

  if (path === "/legal/status" && method === "GET") {
    return await handleGetLegalStatus(req, config);
  }
  if (path === "/legal/accept" && method === "POST") {
    return await handleAcceptPolicies(req, config);
  }

  return null;
}
