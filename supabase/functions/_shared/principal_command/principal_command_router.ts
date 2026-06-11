import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handlePrincipalCommandCenter,
  handlePrincipalCommandQuery,
} from "./principal_command_handlers.ts";

export async function routePrincipalCommand(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/principal-command")) return null;

  if (path === "/principal-command/center" && method === "GET") {
    return handlePrincipalCommandCenter(req, config);
  }
  if (path === "/principal-command/query" && method === "GET") {
    return handlePrincipalCommandQuery(req, config);
  }

  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
