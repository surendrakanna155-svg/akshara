import type { AppConfig } from "../config.ts";
import {
  handleGetPlans,
  handleGetSubscription,
} from "./entitlement_handlers.ts";

/** Routes the read-only entitlement endpoints (B2 Step 2). */
export async function routeEntitlements(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (method === "GET" && path === "/plans") {
    return await handleGetPlans(req, config);
  }
  if (method === "GET" && path === "/subscription") {
    return await handleGetSubscription(req, config);
  }
  return null;
}
