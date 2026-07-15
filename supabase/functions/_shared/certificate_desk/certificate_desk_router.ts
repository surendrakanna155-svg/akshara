// PRC-A Batch 2 (caps 136-148) — Certificate Request Desk router.
//
// Prefix: /certificate-requests. NOT yet wired into api/index.ts — that is
// the orchestrator's Phase C job (this file is deliberately never imported by
// anything outside this directory + its own tests).

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleCancelCertificateRequest,
  handleGetCertificateRequest,
  handleListCertificateRequests,
  handleRaiseCertificateRequest,
} from "./certificate_desk_handlers.ts";

const CANCEL_MATCH = /^\/certificate-requests\/([^/]+)\/cancel$/;
const DETAIL_MATCH = /^\/certificate-requests\/([^/]+)$/;

export async function routeCertificateDesk(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/certificate-requests")) return null;

  if (path === "/certificate-requests") {
    if (method === "GET") return await handleListCertificateRequests(req, config);
    if (method === "POST") return await handleRaiseCertificateRequest(req, config);
  }

  const cancelMatch = path.match(CANCEL_MATCH);
  if (cancelMatch && method === "POST") {
    return await handleCancelCertificateRequest(req, config, cancelMatch[1]!);
  }

  const detailMatch = path.match(DETAIL_MATCH);
  if (detailMatch && method === "GET") {
    return await handleGetCertificateRequest(req, config, detailMatch[1]!);
  }

  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
