// Adaptive AI — P3-AI-2 / W2.S: Universal School Search router (top-level /search).

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import { handleUniversalSearch } from "./search_handlers.ts";

export async function routeSearch(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (path !== "/search") return null;
  if (method !== "GET") {
    return errorEnvelope("METHOD_NOT_ALLOWED", `Method not allowed: ${method} ${path}`, 405);
  }
  return await handleUniversalSearch(req, config);
}
