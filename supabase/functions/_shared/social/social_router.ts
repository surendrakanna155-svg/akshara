// Social Media Integration — router (Phase 2).

import type { AppConfig } from "../config.ts";
import {
  handleConnectComplete,
  handleConnectStart,
  handleDisconnect,
  handleListConnections,
} from "./social_handlers.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function routeSocial(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/social")) return null;

  if (path === "/social/connect/start" && method === "POST") {
    return handleConnectStart(req, config);
  }
  if (path === "/social/connect/complete" && method === "POST") {
    return handleConnectComplete(req, config);
  }
  if (path === "/social/connections" && method === "GET") {
    return handleListConnections(req, config);
  }
  const match = path.match(/^\/social\/connections\/([^/]+)$/);
  if (match && UUID.test(match[1]!) && method === "DELETE") {
    return handleDisconnect(req, config, match[1]!);
  }
  return null;
}
