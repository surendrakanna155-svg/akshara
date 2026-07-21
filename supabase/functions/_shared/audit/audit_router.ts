import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import { handleAuditBatchUpload, handleListAuditEvents } from "./audit_handlers.ts";
import { handleProcessDomainEvents } from "./domain_events_handlers.ts";

function matchAuditRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method === "POST" && path === "/audit/events/batch") {
    return { handler: handleAuditBatchUpload };
  }
  // PRA-P1-53 (S2): permission-gated read route so the immutable audit trail is
  // reviewable ("who changed this mark / deleted this payment").
  if (method === "GET" && path === "/audit/events") {
    return { handler: handleListAuditEvents };
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
    return null;
  }

  return await match.handler(req, config);
}
