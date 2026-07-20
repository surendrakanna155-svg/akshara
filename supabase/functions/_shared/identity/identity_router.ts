// PRA-P1-05 (S2) — identity-plane admin routes (permission overrides).
import type { AppConfig } from "../config.ts";
import {
  handleRemoveMembershipOverride,
  handleSetMembershipOverride,
} from "./identity_handlers.ts";

export async function routeIdentity(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (method === "POST" && path === "/identity/permission-overrides") {
    return await handleSetMembershipOverride(req, config);
  }
  if (method === "POST" && path === "/identity/permission-overrides/remove") {
    return await handleRemoveMembershipOverride(req, config);
  }
  return null;
}
