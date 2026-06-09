/**
 * @deprecated Use permission_resolver.ts (DB-backed). Re-exports for backward compatibility.
 */
export {
  aggregateRolePermissions,
  applyPermissionOverrides,
  permissionsPayloadFromList as permissionsPayload,
  resolveSchoolMembershipPermissions,
} from "./permission_resolver.ts";

import { aggregateRolePermissions } from "./permission_resolver.ts";

/** Fallback map for unit tests only — production uses DB via resolveSchoolMembershipPermissions. */
const TEST_ROLE_PERMISSIONS: Record<string, string[]> = {
  schoolAdmin: ["viewAdminHub", "manageFinance", "viewAdmissions", "manageAdmissions"],
  teacher: ["viewAdminHub"],
  coordinator: ["viewAdminHub", "viewSis", "viewAdmissions", "manageAdmissions"],
};

/** @deprecated Use resolveSchoolMembershipPermissions in auth handlers. */
export function permissionsForRole(role: string): string[] {
  return aggregateRolePermissions(
    [role],
    new Map(Object.entries(TEST_ROLE_PERMISSIONS)),
  );
}
