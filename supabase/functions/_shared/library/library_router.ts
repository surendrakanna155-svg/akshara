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
import {
  handleAddBook,
  handleAddDigitalResource,
  handleEnrollMember,
  handleIssueBook,
  handleReturnBook,
  handleWaiveFine,
} from "./library_write_handlers.ts";

type RouteHandler = (req: Request, config: AppConfig) => Promise<Response>;
type ParamRouteHandler = (
  req: Request,
  config: AppConfig,
  ...args: string[]
) => Promise<Response>;

function matchLibraryRoute(
  method: string,
  path: string,
): { handler: ParamRouteHandler; args: string[] } | null {
  if (method === "GET") {
    const routes: Record<string, RouteHandler> = {
      "/library/dashboard": handleDashboard,
      "/library/catalog": handleCatalog,
      "/library/issues": handleIssues,
      "/library/returns": handleReturns,
      "/library/members": handleMembers,
      "/library/fines": handleFines,
      "/library/digital-resources": handleDigitalResources,
      "/library/reports": handleReports,
    };
    const handler = routes[path] as RouteHandler | undefined;
    return handler ? { handler, args: [] } : null;
  }

  if (method === "POST") {
    const waiveMatch = path.match(/^\/library\/fines\/([^/]+)\/waive$/);
    if (waiveMatch) {
      return { handler: handleWaiveFine, args: [waiveMatch[1]!] };
    }

    const routes: Record<string, RouteHandler> = {
      "/library/catalog": handleAddBook,
      "/library/issues": handleIssueBook,
      "/library/returns": handleReturnBook,
      "/library/members": handleEnrollMember,
      "/library/digital-resources": handleAddDigitalResource,
    };
    const handler = routes[path] as RouteHandler | undefined;
    return handler ? { handler, args: [] } : null;
  }

  return null;
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

  return await match.handler(req, config, ...match.args);
}
