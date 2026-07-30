import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleCreateIntervention,
  handleListInterventions,
  handleTeacherAssistantInsights,
  handleUpdateIntervention,
} from "./teacher_assistant_handlers.ts";

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function routeTeacherAssistant(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/teacher-assistant")) return null;

  if (path === "/teacher-assistant/insights" && method === "GET") {
    return handleTeacherAssistantInsights(req, config);
  }
  if (path === "/teacher-assistant/interventions" && method === "GET") {
    return handleListInterventions(req, config);
  }
  if (path === "/teacher-assistant/interventions" && method === "POST") {
    return handleCreateIntervention(req, config);
  }

  const updateMatch = path.match(/^\/teacher-assistant\/interventions\/([^/]+)$/);
  if (updateMatch && method === "PATCH" && UUID.test(updateMatch[1]!)) {
    return handleUpdateIntervention(req, config, updateMatch[1]!);
  }

  return null;
}
