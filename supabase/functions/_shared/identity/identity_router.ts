// PRA-P1-05 (S2) — identity-plane admin routes (permission overrides).
// ICA-G3 — tenant custom-role management routes.
import type { AppConfig } from "../config.ts";
import {
  handleRemoveMembershipOverride,
  handleSetMembershipOverride,
} from "./identity_handlers.ts";
import {
  handleCreateCustomRole,
  handleDeleteCustomRole,
  handleListCustomRoles,
  handleUpdateCustomRole,
} from "./custom_roles_handlers.ts";

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
  // ICA-G3 — tenant custom roles (org-scoped; system roles are immutable).
  if (method === "GET" && path === "/identity/roles") {
    return await handleListCustomRoles(req, config);
  }
  if (method === "POST" && path === "/identity/roles") {
    return await handleCreateCustomRole(req, config);
  }
  if (method === "POST" && path === "/identity/roles/update") {
    return await handleUpdateCustomRole(req, config);
  }
  if (method === "POST" && path === "/identity/roles/delete") {
    return await handleDeleteCustomRole(req, config);
  }
  return null;
}
