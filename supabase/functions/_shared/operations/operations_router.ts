import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import { handleOperationsActions, handleOperationsHub } from "./operations_hub_handlers.ts";

export async function routeOperations(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (path === "/operations/hub" && method === "GET") {
    try {
      return await handleOperationsHub(req, config);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Operations route failed";
      return errorEnvelope("OPERATIONS_ROUTE_ERROR", message, 500);
    }
  }
  if (path === "/operations/actions" && method === "GET") {
    try {
      return await handleOperationsActions(req, config);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Operations route failed";
      return errorEnvelope("OPERATIONS_ROUTE_ERROR", message, 500);
    }
  }
  if (!path.startsWith("/operations")) return null;
  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
