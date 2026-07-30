import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAiEconomics,
  handleCreateSession,
  handleGetSession,
  handleListAssistants,
  handleListSessions,
  handleListSuggestions,
  handleSendMessage,
} from "./copilot_handlers.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function matchCopilotRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/copilot/assistants" && method === "GET") {
    return { handler: handleListAssistants, args: [] };
  }
  if (path === "/copilot/suggestions" && method === "GET") {
    return { handler: handleListSuggestions, args: [] };
  }
  if (path === "/copilot/economics" && method === "GET") {
    return { handler: handleAiEconomics, args: [] };
  }
  if (path === "/copilot/sessions" && method === "GET") {
    return { handler: handleListSessions, args: [] };
  }
  if (path === "/copilot/sessions" && method === "POST") {
    return { handler: handleCreateSession, args: [] };
  }

  const messageMatch = path.match(/^\/copilot\/sessions\/([^/]+)\/messages$/);
  if (messageMatch && method === "POST") {
    return { handler: handleSendMessage, args: [messageMatch[1]!] };
  }

  const sessionMatch = path.match(/^\/copilot\/sessions\/([^/]+)$/);
  if (sessionMatch && method === "GET") {
    const sessionId = sessionMatch[1]!;
    if (UUID_SEGMENT.test(sessionId)) {
      return { handler: handleGetSession, args: [sessionId] };
    }
  }

  return null;
}

export async function routeCopilot(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/copilot")) return null;
  const match = matchCopilotRoute(method, path);
  if (!match) {
    return null;
  }
  return await match.handler(req, config, ...match.args);
}
