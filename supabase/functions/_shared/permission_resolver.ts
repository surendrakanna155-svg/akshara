import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

export interface PermissionOverrideRow {
  permission_slug: string;
  effect: "grant" | "deny";
}

export interface ResolvedPermissions {
  permissions: string[];
  roleSlugs: string[];
  primaryRole: string;
  permissionsVersion: number;
}

export interface MembershipRoleRow {
  role_slug: string;
  is_primary: boolean;
  status: string;
}

/** Union role permissions; empty union falls back to viewAdminHub (v6.0 compat). */
export function aggregateRolePermissions(
  roleSlugs: string[],
  rolePermissionMap: Map<string, string[]>,
): string[] {
  const merged = new Set<string>();
  for (const slug of roleSlugs) {
    const grants = rolePermissionMap.get(slug);
    if (!grants) continue;
    for (const permission of grants) merged.add(permission);
  }
  if (merged.size === 0) merged.add("viewAdminHub");
  return [...merged].sort();
}

/** Apply membership overrides; DENY removes even if granted by another role. */
export function applyPermissionOverrides(
  permissions: string[],
  overrides: PermissionOverrideRow[],
): string[] {
  const effective = new Set(permissions);
  for (const override of overrides) {
    if (override.effect === "deny") {
      effective.delete(override.permission_slug);
    } else {
      effective.add(override.permission_slug);
    }
  }
  return [...effective].sort();
}

export function resolvePrimaryRoleSlug(
  roles: MembershipRoleRow[],
  legacyRole?: string | null,
): string {
  const active = roles.filter((r) => r.status === "active");
  const primary = active.find((r) => r.is_primary);
  if (primary) return primary.role_slug;
  if (active.length > 0) return active[0].role_slug;
  if (legacyRole) return legacyRole;
  return "teacher";
}

export function permissionsPayloadFromList(permissions: string[]) {
  return permissions.map((permission) => ({
    permission,
    source: "server" as const,
  }));
}

async function loadRolePermissionMap(
  client: SupabaseClient,
  roleSlugs: string[],
): Promise<Map<string, string[]>> {
  const map = new Map<string, string[]>();
  if (roleSlugs.length === 0) return map;

  const { data, error } = await client
    .from("role_permissions")
    .select("role_slug, permission_slug")
    .in("role_slug", roleSlugs);

  if (error) throw error;

  for (const row of data ?? []) {
    const list = map.get(row.role_slug as string) ?? [];
    list.push(row.permission_slug as string);
    map.set(row.role_slug as string, list);
  }
  return map;
}

export async function resolveSchoolMembershipPermissions(
  client: SupabaseClient,
  schoolMembershipId: string,
  legacyRole?: string | null,
  permissionsVersion = 1,
): Promise<ResolvedPermissions> {
  const { data: roleRows, error: rolesError } = await client
    .from("school_membership_roles")
    .select("role_slug, is_primary, status")
    .eq("school_membership_id", schoolMembershipId)
    .eq("status", "active");

  if (rolesError) throw rolesError;

  const roles = (roleRows ?? []) as MembershipRoleRow[];
  const roleSlugs = roles.map((r) => r.role_slug);
  if (roleSlugs.length === 0 && legacyRole) roleSlugs.push(legacyRole);

  const rolePermissionMap = await loadRolePermissionMap(client, roleSlugs);
  const aggregated = aggregateRolePermissions(roleSlugs, rolePermissionMap);

  const { data: overrideRows, error: overridesError } = await client
    .from("membership_permission_overrides")
    .select("permission_slug, effect")
    .eq("school_membership_id", schoolMembershipId);

  if (overridesError) throw overridesError;

  const permissions = applyPermissionOverrides(
    aggregated,
    (overrideRows ?? []) as PermissionOverrideRow[],
  );

  return {
    permissions,
    roleSlugs,
    primaryRole: resolvePrimaryRoleSlug(roles, legacyRole),
    permissionsVersion,
  };
}

export async function resolveOrganizationMembershipPermissions(
  client: SupabaseClient,
  organizationMembershipId: string,
  legacyRole?: string | null,
  permissionsVersion = 1,
): Promise<ResolvedPermissions> {
  const { data: roleRows, error: rolesError } = await client
    .from("organization_membership_roles")
    .select("role_slug, is_primary, status")
    .eq("organization_membership_id", organizationMembershipId)
    .eq("status", "active");

  if (rolesError) throw rolesError;

  const roles = (roleRows ?? []) as MembershipRoleRow[];
  const roleSlugs = roles.map((r) => r.role_slug);
  if (roleSlugs.length === 0 && legacyRole) roleSlugs.push(legacyRole);

  const rolePermissionMap = await loadRolePermissionMap(client, roleSlugs);
  const aggregated = aggregateRolePermissions(roleSlugs, rolePermissionMap);

  const { data: overrideRows, error: overridesError } = await client
    .from("membership_permission_overrides")
    .select("permission_slug, effect")
    .eq("organization_membership_id", organizationMembershipId);

  if (overridesError) throw overridesError;

  const permissions = applyPermissionOverrides(
    aggregated,
    (overrideRows ?? []) as PermissionOverrideRow[],
  );

  return {
    permissions,
    roleSlugs,
    primaryRole: resolvePrimaryRoleSlug(roles, legacyRole),
    permissionsVersion,
  };
}
