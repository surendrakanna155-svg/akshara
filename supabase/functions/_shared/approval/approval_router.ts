import type { AppConfig } from "../config.ts";
import {
  handleApproveApproval,
  handleBatchDecideApprovals,
  handleCancelApproval,
  handleFindPendingByEntity,
  handleGetApproval,
  handleListApprovalAudit,
  handleListApprovals,
  handleListPendingApprovals,
  handleRecordApprovalAudit,
  handleRejectApproval,
  handleSubmitApproval,
} from "./approval_handlers.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function matchApprovalRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/approvals" && method === "GET") {
    return { handler: handleListApprovals, args: [] };
  }
  if (path === "/approvals/pending" && method === "GET") {
    return { handler: handleListPendingApprovals, args: [] };
  }
  if (path === "/approvals/entity" && method === "GET") {
    return { handler: handleFindPendingByEntity, args: [] };
  }
  if (path === "/approvals" && method === "POST") {
    return { handler: handleSubmitApproval, args: [] };
  }
  if (path === "/approvals/audit" && method === "POST") {
    return { handler: handleRecordApprovalAudit, args: [] };
  }
  // PRI-1 — batch multi-select decisions. MUST be matched before the `/{id}`
  // matchers below so the literal 'batch-decide' segment is not captured as an
  // approval id.
  if (path === "/approvals/batch-decide" && method === "POST") {
    return { handler: handleBatchDecideApprovals, args: [] };
  }

  const detailMatch = path.match(/^\/approvals\/([^/]+)$/);
  if (detailMatch && UUID_SEGMENT.test(detailMatch[1]!) && method === "GET") {
    return { handler: handleGetApproval, args: [detailMatch[1]!] };
  }

  const approveMatch = path.match(/^\/approvals\/([^/]+)\/approve$/);
  if (approveMatch && UUID_SEGMENT.test(approveMatch[1]!) && method === "POST") {
    return { handler: handleApproveApproval, args: [approveMatch[1]!] };
  }

  const rejectMatch = path.match(/^\/approvals\/([^/]+)\/reject$/);
  if (rejectMatch && UUID_SEGMENT.test(rejectMatch[1]!) && method === "POST") {
    return { handler: handleRejectApproval, args: [rejectMatch[1]!] };
  }

  const cancelMatch = path.match(/^\/approvals\/([^/]+)\/cancel$/);
  if (cancelMatch && UUID_SEGMENT.test(cancelMatch[1]!) && method === "POST") {
    return { handler: handleCancelApproval, args: [cancelMatch[1]!] };
  }

  const auditMatch = path.match(/^\/approvals\/([^/]+)\/audit$/);
  if (auditMatch && UUID_SEGMENT.test(auditMatch[1]!) && method === "GET") {
    return { handler: handleListApprovalAudit, args: [auditMatch[1]!] };
  }

  return null;
}

export async function routeApproval(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/approvals")) {
    return null;
  }

  const matched = matchApprovalRoute(method, path);
  if (!matched) {
    return null;
  }

  return await matched.handler(req, config, ...matched.args);
}
