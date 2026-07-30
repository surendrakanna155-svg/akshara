import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleCreateMemoryEvent,
  handleGetMemoryEvent,
  handleListMemoryEvents,
  handleMemoryAnalytics,
  handleMemoryMediaDownload,
  handleMemoryShareLink,
  handleMemoryUploadConfirm,
  handleMemoryUploadPresign,
  handlePublishMemoryEvent,
} from "./school_memories_handlers.ts";

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function routeMemories(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/memories")) return null;

  if (path === "/memories/events" && method === "GET") {
    return await handleListMemoryEvents(req, config);
  }
  if (path === "/memories/events" && method === "POST") {
    return await handleCreateMemoryEvent(req, config);
  }
  if (path === "/memories/analytics" && method === "GET") {
    return await handleMemoryAnalytics(req, config);
  }

  const shareMatch = path.match(/^\/memories\/share\/([^/]+)$/);
  if (shareMatch && method === "GET") {
    return await handleMemoryShareLink(req, config, shareMatch[1]!);
  }

  const mediaDownloadMatch = path.match(/^\/memories\/media\/([^/]+)\/download$/);
  if (mediaDownloadMatch && method === "GET" && UUID.test(mediaDownloadMatch[1]!)) {
    return await handleMemoryMediaDownload(req, config, mediaDownloadMatch[1]!);
  }

  const eventMatch = path.match(/^\/memories\/events\/([^/]+)(?:\/(publish|upload\/presign|upload\/confirm))?$/);
  if (eventMatch && UUID.test(eventMatch[1]!)) {
    const eventId = eventMatch[1]!;
    const action = eventMatch[2];
    if (method === "GET" && !action) {
      return await handleGetMemoryEvent(req, config, eventId);
    }
    if (method === "POST" && action === "publish") {
      return await handlePublishMemoryEvent(req, config, eventId);
    }
    if (method === "POST" && action === "upload/presign") {
      return await handleMemoryUploadPresign(req, config, eventId);
    }
    if (method === "POST" && action === "upload/confirm") {
      return await handleMemoryUploadConfirm(req, config, eventId);
    }
  }

  return null;
}
