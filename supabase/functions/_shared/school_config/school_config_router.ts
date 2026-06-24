import type { AppConfig } from "../config.ts";
import {
  handleGetSchoolConfig,
  handlePutSchoolConfig,
} from "./school_config_handlers.ts";

/** Routes the per-school capability gating endpoints. */
export async function routeSchoolConfig(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (path !== "/school-config") return null;

  if (method === "GET") return await handleGetSchoolConfig(req, config);
  if (method === "PUT") return await handlePutSchoolConfig(req, config);

  return null;
}
