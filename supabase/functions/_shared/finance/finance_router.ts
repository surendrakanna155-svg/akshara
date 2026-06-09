import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleArchiveFeeStructure,
  handleCreateFeeStructure,
  handleGetFeeStructure,
  handleListFeeStructures,
  handleUpdateFeeStructure,
} from "./finance_handlers.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function matchFinanceRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/finance/fee-structures" && method === "GET") {
    return { handler: handleListFeeStructures, args: [] };
  }
  if (path === "/finance/fee-structures" && method === "POST") {
    return { handler: handleCreateFeeStructure, args: [] };
  }

  const archiveMatch = path.match(/^\/finance\/fee-structures\/([^/]+)\/archive$/);
  if (archiveMatch && method === "PATCH") {
    return { handler: handleArchiveFeeStructure, args: [archiveMatch[1]!] };
  }

  const structureMatch = path.match(/^\/finance\/fee-structures\/([^/]+)$/);
  if (structureMatch) {
    const structureId = structureMatch[1]!;
    if (method === "GET") {
      return { handler: handleGetFeeStructure, args: [structureId] };
    }
    if (method === "PUT") {
      return { handler: handleUpdateFeeStructure, args: [structureId] };
    }
  }

  return null;
}

export async function routeFinance(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/finance")) return null;

  const match = matchFinanceRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  for (const arg of match.args) {
    if (arg.includes("-") && !UUID_SEGMENT.test(arg)) {
      // Allow non-UUID legacy mock ids in path for compatibility
    }
  }

  return await match.handler(req, config, ...match.args);
}
