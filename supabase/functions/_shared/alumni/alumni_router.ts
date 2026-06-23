import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAlumniDetail,
  handleCampaigns,
  handleDashboard,
  handleDonations,
  handleEvents,
  handleMentorship,
  handleRegistry,
  handleReports,
  handleSettings,
} from "./alumni_handlers.ts";
import {
  handleAddAlumni,
  handleAddMentorshipPair,
  handleCreateCampaign,
  handleCreateEvent,
} from "./alumni_write_handlers.ts";

function matchAlumniRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (method === "GET") {
    const staticRoutes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
      "/alumni/dashboard": handleDashboard,
      "/alumni/registry": handleRegistry,
      "/alumni/events": handleEvents,
      "/alumni/donations": handleDonations,
      "/alumni/campaigns": handleCampaigns,
      "/alumni/mentorship": handleMentorship,
      "/alumni/reports": handleReports,
      "/alumni/settings": handleSettings,
    };

    const staticHandler = staticRoutes[path];
    if (staticHandler) {
      return { handler: staticHandler, args: [] };
    }

    const detailMatch = path.match(/^\/alumni\/registry\/([^/]+)$/);
    if (detailMatch) {
      return { handler: handleAlumniDetail, args: [detailMatch[1]!] };
    }

    return null;
  }

  if (method === "POST") {
    const routes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
      "/alumni/registry": handleAddAlumni,
      "/alumni/events": handleCreateEvent,
      "/alumni/campaigns": handleCreateCampaign,
      "/alumni/mentorship": handleAddMentorshipPair,
    };
    const handler = routes[path] as ((req: Request, config: AppConfig) => Promise<Response>) | undefined;
    return handler ? { handler, args: [] } : null;
  }

  return null;
}

export async function routeAlumni(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/alumni")) return null;

  const match = matchAlumniRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config, ...match.args);
}
