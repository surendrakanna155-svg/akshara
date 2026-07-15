// PRC-A Batch 2 — Gate Pass / Early Pickup router. Style mirrors sis_router.ts.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleCancelGatePass,
  handleCreateGatePass,
  handleGetGatePass,
  handleListGatePasses,
  handleVerifyGatePass,
} from "./gate_pass_handlers.ts";

export function matchGatePassRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/gate-passes" && method === "GET") {
    return { handler: handleListGatePasses, args: [] };
  }
  if (path === "/gate-passes" && method === "POST") {
    return { handler: handleCreateGatePass, args: [] };
  }

  const verifyMatch = path.match(/^\/gate-passes\/([^/]+)\/verify$/);
  if (verifyMatch && method === "POST") {
    return { handler: handleVerifyGatePass, args: [verifyMatch[1]!] };
  }

  const cancelMatch = path.match(/^\/gate-passes\/([^/]+)\/cancel$/);
  if (cancelMatch && method === "POST") {
    return { handler: handleCancelGatePass, args: [cancelMatch[1]!] };
  }

  const detailMatch = path.match(/^\/gate-passes\/([^/]+)$/);
  if (detailMatch && method === "GET") {
    return { handler: handleGetGatePass, args: [detailMatch[1]!] };
  }

  return null;
}

/** `null` = not our prefix (caller tries the next router); inside the prefix
 * with no route match => a 404 envelope (NOT null) per the router contract. */
export async function routeGatePass(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/gate-passes")) return null;

  const match = matchGatePassRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config, ...match.args);
}
