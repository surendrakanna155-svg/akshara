import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleCatalog,
  handleDashboard,
  handleDigitalResources,
  handleFines,
  handleIssues,
  handleMembers,
  handleOverdue,
  handleReports,
  handleReturns,
  handleSettings,
} from "./library_handlers.ts";
import {
  handleAddBook,
  handleAddDigitalResource,
  handleBulkImportBooks,
  handleDeleteBook,
  handleEnrollMember,
  handleIssueBook,
  handleRenewLoan,
  handleReturnBook,
  handleSendOverdueReminders,
  handleUpdateBook,
  handleUpdateSettings,
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
      "/library/overdue": handleOverdue,
      "/library/settings": handleSettings,
    };
    const handler = routes[path] as RouteHandler | undefined;
    return handler ? { handler, args: [] } : null;
  }

  if (method === "POST") {
    const waiveMatch = path.match(/^\/library\/fines\/([^/]+)\/waive$/);
    if (waiveMatch) {
      return { handler: handleWaiveFine, args: [waiveMatch[1]!] };
    }

    // LIB-4: renew a specific active loan (matched before any bare id route).
    const renewMatch = path.match(/^\/library\/issues\/([^/]+)\/renew$/);
    if (renewMatch) {
      return { handler: handleRenewLoan, args: [renewMatch[1]!] };
    }

    const routes: Record<string, RouteHandler> = {
      "/library/catalog": handleAddBook,
      "/library/catalog/import": handleBulkImportBooks,
      "/library/issues": handleIssueBook,
      "/library/returns": handleReturnBook,
      "/library/members": handleEnrollMember,
      "/library/digital-resources": handleAddDigitalResource,
      "/library/reminders/overdue": handleSendOverdueReminders,
    };
    const handler = routes[path] as RouteHandler | undefined;
    return handler ? { handler, args: [] } : null;
  }

  if (method === "PUT") {
    if (path === "/library/settings") {
      return { handler: handleUpdateSettings, args: [] };
    }
    // LIB-2: edit a catalogue book (matched after the literal settings route).
    const bookMatch = path.match(/^\/library\/catalog\/([^/]+)$/);
    if (bookMatch) {
      return { handler: handleUpdateBook, args: [bookMatch[1]!] };
    }
    return null;
  }

  if (method === "DELETE") {
    // LIB-2: delete a catalogue book.
    const bookMatch = path.match(/^\/library\/catalog\/([^/]+)$/);
    if (bookMatch) {
      return { handler: handleDeleteBook, args: [bookMatch[1]!] };
    }
    return null;
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
