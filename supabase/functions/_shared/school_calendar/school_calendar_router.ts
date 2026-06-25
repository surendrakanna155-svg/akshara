// Holiday/Event Calendar — router (Phase 1).

import type { AppConfig } from "../config.ts";
import {
  handleCreateCalendarEvent,
  handleDeleteCalendarEvent,
  handleListCalendar,
} from "./school_calendar_handlers.ts";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function routeSchoolCalendar(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/school-calendar")) return null;

  if (path === "/school-calendar" && method === "GET") {
    return handleListCalendar(req, config);
  }
  if (path === "/school-calendar" && method === "POST") {
    return handleCreateCalendarEvent(req, config);
  }
  const match = path.match(/^\/school-calendar\/([^/]+)$/);
  if (match && UUID.test(match[1]!) && method === "DELETE") {
    return handleDeleteCalendarEvent(req, config, match[1]!);
  }
  return null;
}
