// ASIP — router for the platform-support module. Owns the `/support` prefix and
// returns Response|null (null ⇒ not our prefix, the chain continues). A matched
// prefix with no route match returns 404 (mirrors audit_router — nothing else
// owns /support so we never fall through).

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAnalyzeIncident,
  handleApproveAnalysis,
  handleCollectEvidence,
  handleConfirmAttachment,
  handleCreateIncident,
  handleGetIncident,
  handleListIncidents,
  handlePostMessage,
  handlePresignAttachment,
  handleTransitionStatus,
} from "./support_handlers.ts";
import {
  handlePlatformAssign,
  handlePlatformCluster,
  handlePlatformClusters,
  handlePlatformEscalate,
  handlePlatformHandoff,
  handlePlatformIncident,
  handlePlatformInvestigate,
  handlePlatformKbArticle,
  handlePlatformKbList,
  handlePlatformNote,
  handlePlatformQueue,
  handlePlatformResolve,
  handlePlatformSupportStatus,
} from "./support_platform_handlers.ts";

const UUID_RE = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

export async function routeSupport(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/support")) return null;

  const segs = path.split("/").filter((s) => s.length > 0); // ["support", "incidents", …]

  // /support/platform/* — the Akshara support-console (PLATFORM_ORG) surface.
  if (segs[1] === "platform") {
    return await routeSupportPlatform(req, config, method, path, segs);
  }

  // /support/incidents
  if (segs.length === 2 && segs[1] === "incidents") {
    if (method === "POST") return await handleCreateIncident(req, config);
    if (method === "GET") return await handleListIncidents(req, config);
    return errorEnvelope("METHOD_NOT_ALLOWED", `Method not allowed: ${method} ${path}`, 405);
  }

  // /support/incidents/:id/…
  if (segs.length >= 3 && segs[1] === "incidents") {
    const id = segs[2];
    if (!UUID_RE.test(id)) {
      return errorEnvelope("VALIDATION", "invalid incident id", 422);
    }

    if (segs.length === 3) {
      if (method === "GET") return await handleGetIncident(req, config, id);
      return errorEnvelope("METHOD_NOT_ALLOWED", `Method not allowed: ${method} ${path}`, 405);
    }

    if (segs.length === 4 && method === "POST") {
      switch (segs[3]) {
        case "messages":
          return await handlePostMessage(req, config, id);
        case "collect-evidence":
          return await handleCollectEvidence(req, config, id);
        case "analyze":
          return await handleAnalyzeIncident(req, config, id);
        case "status":
          return await handleTransitionStatus(req, config, id);
      }
    }

    if (segs.length === 5 && method === "POST") {
      if (segs[3] === "attachments" && segs[4] === "presign") {
        return await handlePresignAttachment(req, config, id);
      }
      if (segs[3] === "attachments" && segs[4] === "confirm") {
        return await handleConfirmAttachment(req, config, id);
      }
      if (segs[3] === "analysis" && segs[4] === "approve") {
        return await handleApproveAnalysis(req, config, id);
      }
    }
  }

  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}

// /support/platform/… — segs = ["support","platform", …]
async function routeSupportPlatform(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
  segs: string[],
): Promise<Response> {
  // /support/platform/incidents…
  if (segs[2] === "incidents") {
    if (segs.length === 3) {
      if (method === "GET") return await handlePlatformQueue(req, config);
      return errorEnvelope("METHOD_NOT_ALLOWED", `Method not allowed: ${method} ${path}`, 405);
    }
    const id = segs[3];
    if (!UUID_RE.test(id)) return errorEnvelope("VALIDATION", "invalid incident id", 422);

    if (segs.length === 4) {
      if (method === "GET") return await handlePlatformIncident(req, config, id);
      return errorEnvelope("METHOD_NOT_ALLOWED", `Method not allowed: ${method} ${path}`, 405);
    }
    if (segs.length === 5) {
      const action = segs[4];
      if (method === "GET" && action === "handoff") return await handlePlatformHandoff(req, config, id);
      if (method === "POST") {
        switch (action) {
          case "assign":
            return await handlePlatformAssign(req, config, id);
          case "support-status":
            return await handlePlatformSupportStatus(req, config, id);
          case "escalate":
            return await handlePlatformEscalate(req, config, id);
          case "notes":
            return await handlePlatformNote(req, config, id);
          case "investigate":
            return await handlePlatformInvestigate(req, config, id);
          case "resolve":
            return await handlePlatformResolve(req, config, id);
        }
      }
    }
  }

  // /support/platform/clusters…
  if (segs[2] === "clusters") {
    if (segs.length === 3 && method === "GET") return await handlePlatformClusters(req, config);
    if (segs.length === 4) {
      const id = segs[3];
      if (!UUID_RE.test(id)) return errorEnvelope("VALIDATION", "invalid cluster id", 422);
      if (method === "GET") return await handlePlatformCluster(req, config, id);
    }
  }

  // /support/platform/kb… — ASIP-8 knowledge base (learned resolutions)
  if (segs[2] === "kb") {
    if (segs.length === 3 && method === "GET") return await handlePlatformKbList(req, config);
    if (segs.length === 4) {
      const id = segs[3];
      if (!UUID_RE.test(id)) return errorEnvelope("VALIDATION", "invalid article id", 422);
      if (method === "GET") return await handlePlatformKbArticle(req, config, id);
    }
  }

  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
