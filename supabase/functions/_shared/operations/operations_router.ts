import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleCompleteOperationsAction,
  handleDismissOperationsAlert,
  handleOperationsActions,
  handleOperationsHub,
} from "./operations_hub_handlers.ts";

const DISMISS_ALERT_PATH = /^\/operations\/hub\/alerts\/([^/]+)\/dismiss$/;
const COMPLETE_ACTION_PATH = /^\/operations\/hub\/actions\/([^/]+)\/complete$/;

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

  // #6 — dismiss/complete (previously unregistered → 404, silent no-op button).
  const dismissMatch = path.match(DISMISS_ALERT_PATH);
  if (dismissMatch && method === "POST") {
    try {
      return await handleDismissOperationsAlert(req, config, dismissMatch[1]!);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Operations route failed";
      return errorEnvelope("OPERATIONS_ROUTE_ERROR", message, 500);
    }
  }
  const completeMatch = path.match(COMPLETE_ACTION_PATH);
  if (completeMatch && method === "POST") {
    try {
      return await handleCompleteOperationsAction(req, config, completeMatch[1]!);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Operations route failed";
      return errorEnvelope("OPERATIONS_ROUTE_ERROR", message, 500);
    }
  }

  if (!path.startsWith("/operations")) return null;
  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
