import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleGenerateTimetables,
  handleGetTimetable,
  handleListTimetables,
  handleMoveTimetablePeriod,
  handlePublishTimetable,
  handleTimetableConflicts,
  handleTimetableSummary,
  handleTimetableWorkload,
  handleValidateTimetable,
} from "./timetable_handlers.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function matchTimetableRoute(
  method: string,
  path: string,
): {
  handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>;
  args: string[];
} | null {
  if (path === "/academic/timetables/summary" && method === "GET") {
    return { handler: handleTimetableSummary, args: [] };
  }
  if (path === "/academic/timetables/workload" && method === "GET") {
    return { handler: handleTimetableWorkload, args: [] };
  }
  if (path === "/academic/timetables/conflicts" && method === "GET") {
    return { handler: handleTimetableConflicts, args: [] };
  }
  if (path === "/academic/timetables/generate" && method === "POST") {
    return { handler: handleGenerateTimetables, args: [] };
  }
  if (path === "/academic/timetables/validate" && method === "POST") {
    return { handler: handleValidateTimetable, args: [] };
  }
  if (path === "/academic/timetables/periods/move" && method === "POST") {
    return { handler: handleMoveTimetablePeriod, args: [] };
  }
  if (path === "/academic/timetables" && method === "GET") {
    return { handler: handleListTimetables, args: [] };
  }

  const detailMatch = path.match(/^\/academic\/timetables\/([^/]+)$/);
  if (detailMatch && method === "GET" && UUID_SEGMENT.test(detailMatch[1]!)) {
    return { handler: handleGetTimetable, args: [detailMatch[1]!] };
  }

  const publishMatch = path.match(/^\/academic\/timetables\/([^/]+)\/publish$/);
  if (publishMatch && method === "POST" && UUID_SEGMENT.test(publishMatch[1]!)) {
    return { handler: handlePublishTimetable, args: [publishMatch[1]!] };
  }

  return null;
}

export async function routeTimetable(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/academic/timetables")) return null;
  const match = matchTimetableRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }
  return await match.handler(req, config, ...match.args);
}
