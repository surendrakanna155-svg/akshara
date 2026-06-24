import type { AppConfig } from "../config.ts";
import {
  handleGetPlans,
  handleGetSubscription,
} from "./entitlement_handlers.ts";
import {
  handleAssignSubscription,
  handleListAssignments,
} from "./subscription_admin_handlers.ts";

/** Matches PUT /platform/organizations/{id}/subscription → returns the id. */
function matchAssignPath(path: string): string | null {
  const m = path.match(/^\/platform\/organizations\/([^/]+)\/subscription$/);
  return m ? decodeURIComponent(m[1]) : null;
}

/** Routes the entitlement endpoints (B2 Step 2 reads + Step 4.5 assignment). */
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
  // Step 4.5 — superAdmin platform plan assignment (gated in the handlers).
  if (method === "GET" && path === "/platform/subscriptions") {
    return await handleListAssignments(req, config);
  }
  if (method === "PUT") {
    const orgId = matchAssignPath(path);
    if (orgId !== null) {
      return await handleAssignSubscription(req, config, orgId);
    }
  }
  return null;
}
