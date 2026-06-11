import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAdvanceSetupWizard,
  handleCreateSetupWizard,
  handleGetSetupWizard,
} from "./setup_wizard_handlers.ts";

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function routeSetupWizard(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/setup-wizard")) return null;

  if (path === "/setup-wizard/sessions" && method === "POST") {
    return handleCreateSetupWizard(req, config);
  }

  const sessionMatch = path.match(/^\/setup-wizard\/sessions\/([^/]+)$/);
  if (sessionMatch && method === "GET" && UUID.test(sessionMatch[1]!)) {
    return handleGetSetupWizard(req, config, sessionMatch[1]!);
  }

  const advanceMatch = path.match(/^\/setup-wizard\/sessions\/([^/]+)\/advance$/);
  if (advanceMatch && method === "POST" && UUID.test(advanceMatch[1]!)) {
    return handleAdvanceSetupWizard(req, config, advanceMatch[1]!);
  }

  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
