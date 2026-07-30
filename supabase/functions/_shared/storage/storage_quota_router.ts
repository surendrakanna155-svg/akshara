// PRC-A Batch 4 — Storage quota router. Prefix: /storage/quota.
// Read-only surface (usage + plan limit); usage writes happen internally on the
// upload/delete paths, not through a public route.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import { handleGetStorageQuota } from "./storage_quota_handlers.ts";

export async function routeStorageQuota(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/storage/quota")) return null;

  if (path === "/storage/quota" && method === "GET") {
    return await handleGetStorageQuota(req, config);
  }
  return null;
}
