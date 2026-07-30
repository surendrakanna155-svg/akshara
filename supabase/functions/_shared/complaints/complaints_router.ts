// PRC-A Batch 2 (caps 101-108) — Complaint / Internal Issue router.
// Prefix: /complaints. Not wired into app.ts by this module (orchestrator's
// Phase C job) — exported for that wiring.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAddComplaintComment,
  handleAssignComplaint,
  handleAttachComplaintPhoto,
  handleAttachComplaintVendor,
  handleGetComplaint,
  handleListComplaints,
  handleRaiseComplaint,
  handleTransitionComplaintStatus,
} from "./complaints_handlers.ts";

export function matchComplaintsRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/complaints" && method === "GET") {
    return { handler: handleListComplaints, args: [] };
  }
  if (path === "/complaints" && method === "POST") {
    return { handler: handleRaiseComplaint, args: [] };
  }

  const assignMatch = path.match(/^\/complaints\/([^/]+)\/assign$/);
  if (assignMatch && method === "POST") {
    return { handler: handleAssignComplaint, args: [assignMatch[1]!] };
  }

  const statusMatch = path.match(/^\/complaints\/([^/]+)\/status$/);
  if (statusMatch && method === "POST") {
    return { handler: handleTransitionComplaintStatus, args: [statusMatch[1]!] };
  }

  const commentMatch = path.match(/^\/complaints\/([^/]+)\/comment$/);
  if (commentMatch && method === "POST") {
    return { handler: handleAddComplaintComment, args: [commentMatch[1]!] };
  }

  const vendorMatch = path.match(/^\/complaints\/([^/]+)\/vendor$/);
  if (vendorMatch && method === "POST") {
    return { handler: handleAttachComplaintVendor, args: [vendorMatch[1]!] };
  }

  const photoMatch = path.match(/^\/complaints\/([^/]+)\/photo$/);
  if (photoMatch && method === "POST") {
    return { handler: handleAttachComplaintPhoto, args: [photoMatch[1]!] };
  }

  const detailMatch = path.match(/^\/complaints\/([^/]+)$/);
  if (detailMatch && method === "GET") {
    return { handler: handleGetComplaint, args: [detailMatch[1]!] };
  }

  return null;
}

export async function routeComplaints(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/complaints")) return null;

  const match = matchComplaintsRoute(method, path);
  if (!match) {
    return null;
  }

  return await match.handler(req, config, ...match.args);
}
