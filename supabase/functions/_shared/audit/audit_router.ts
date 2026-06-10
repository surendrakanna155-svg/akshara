import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import { handleAuditBatchUpload } from "./audit_handlers.ts";
import { handleProcessDomainEvents } from "./domain_events_handlers.ts";

function matchAuditRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method === "POST" && path === "/audit/events/batch") {
    return { handler: handleAuditBatchUpload };
  }
  if (method === "POST" && path === "/domain-events/process-pending") {
    return { handler: handleProcessDomainEvents };
  }
  return null;
}

export async function routeAudit(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/audit") && path !== "/domain-events/process-pending") return null;

  const match = matchAuditRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
