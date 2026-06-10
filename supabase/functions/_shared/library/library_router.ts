import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleCatalog,
  handleDashboard,
  handleDigitalResources,
  handleFines,
  handleIssues,
  handleMembers,
  handleReports,
  handleReturns,
} from "./library_handlers.ts";

function matchLibraryRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method !== "GET") return null;

  const routes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
    "/library/dashboard": handleDashboard,
    "/library/catalog": handleCatalog,
    "/library/issues": handleIssues,
    "/library/returns": handleReturns,
    "/library/members": handleMembers,
    "/library/fines": handleFines,
    "/library/digital-resources": handleDigitalResources,
    "/library/reports": handleReports,
  };

  const handler = routes[path];
  return handler ? { handler } : null;
}

export async function routeLibrary(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/library")) return null;

  const match = matchLibraryRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
