// ICA-G3 — write path for tenant-specific custom roles.
//
// Schools create and manage their OWN custom roles within the RBAC framework;
// built-in system roles (organization_id IS NULL / is_system=true) are immutable.
// This module runs on the service-role client (which bypasses RLS), so tenant
// isolation + system-role immutability are enforced HERE in code (belt) AND
// re-asserted as `.eq("organization_id", org).eq("is_system", false)` filters on
// every write (suspenders) — a logic slip still cannot touch a system row or
// another org's role. The DB adds the matching RLS + org-match trigger + detector
// (migration 20260920000200) as defense in depth.
//
// A custom role's stored slug is app-generated and globally unique
// (`custom_<org-without-dashes>_<kebab-name>`): it can never collide with a
// camelCase system slug (shadow-proof), and the same human name in two different
// orgs yields two different slugs — so `role_definitions.slug` stays the global
// PK and every existing FK keeps resolving unchanged.

import type { SupabaseClient } from "npm:@supabase/supabase-js@2";

/** Attempt to modify/delete a built-in system role (immutable to tenants). */
export class SystemRoleImmutableError extends Error {
  constructor(slug: string) {
    super(`System role is immutable and cannot be modified: ${slug}`);
    this.name = "SystemRoleImmutableError";
  }
}

/** Role does not exist in the caller's organization (also covers cross-org). */
export class RoleNotFoundError extends Error {
  constructor(slug: string) {
    super(`Custom role not found in your organization: ${slug}`);
    this.name = "RoleNotFoundError";
  }
}

/** One or more permission slugs are not in the system catalogue. */
export class UnknownPermissionError extends Error {
  constructor(slugs: string[]) {
    super(`Unknown permission(s): ${slugs.join(", ")}`);
    this.name = "UnknownPermissionError";
  }
}

/** A custom role with this (org, name) already exists. */
export class RoleSlugConflictError extends Error {
  constructor(displayName: string) {
    super(`A custom role named "${displayName}" already exists in your organization`);
    this.name = "RoleSlugConflictError";
  }
}

/** The role is still assigned to one or more memberships and cannot be deleted. */
export class RoleInUseError extends Error {
  constructor(slug: string) {
    super(`Custom role is still assigned to members and cannot be deleted: ${slug}`);
    this.name = "RoleInUseError";
  }
}

export interface CustomRoleRow {
  slug: string;
  organization_id: string | null;
  is_system: boolean;
  display_name: string;
}

export interface CustomRoleSummary {
  slug: string;
  displayName: string;
  permissions: string[];
}

// Postgres unique/FK SQLSTATE codes surfaced by PostgREST.
const UNIQUE_VIOLATION = "23505";
const FK_VIOLATION = "23503";

/** Slugify a human role name to a kebab token (letters/digits only). */
function kebab(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

/**
 * Globally-unique, org-namespaced slug for a custom role. The full org UUID (sans
 * dashes) guarantees cross-org uniqueness; the kebab name guarantees the same org
 * cannot silently reuse a name (also enforced by a partial unique index). Never
 * equals a system slug (all system slugs are camelCase, never `custom_…`).
 */
export function customRoleSlug(organizationId: string, displayName: string): string {
  return `custom_${organizationId.replace(/-/g, "")}_${kebab(displayName)}`;
}

/** True when every slug in `slugs` exists in `permission_definitions`. */
async function assertPermissionsExist(
  client: SupabaseClient,
  slugs: string[],
): Promise<void> {
  const unique = [...new Set(slugs)];
  if (unique.length === 0) return;
  const { data, error } = await client
    .from("permission_definitions")
    .select("slug")
    .in("slug", unique);
  if (error) throw new Error(`permission lookup failed: ${error.message}`);
  const found = new Set((data ?? []).map((r) => (r as { slug: string }).slug));
  const missing = unique.filter((s) => !found.has(s));
  if (missing.length > 0) throw new UnknownPermissionError(missing);
}

/** Load a role by slug (any org — the caller enforces org ownership). */
async function loadRole(
  client: SupabaseClient,
  slug: string,
): Promise<CustomRoleRow | null> {
  const { data, error } = await client
    .from("role_definitions")
    .select("slug, organization_id, is_system, display_name")
    .eq("slug", slug)
    .maybeSingle();
  if (error) throw new Error(`role lookup failed: ${error.message}`);
  return (data as CustomRoleRow | null) ?? null;
}

/**
 * Assert the role exists AND is a custom role owned by `organizationId`. A system
 * role -> SystemRoleImmutableError; a missing OR other-org role -> RoleNotFoundError
 * (org A gets a 404 for org B's role — no cross-org existence disclosure).
 */
async function requireOwnCustomRole(
  client: SupabaseClient,
  organizationId: string,
  slug: string,
): Promise<CustomRoleRow> {
  const role = await loadRole(client, slug);
  if (!role) throw new RoleNotFoundError(slug);
  if (role.is_system || role.organization_id === null) {
    throw new SystemRoleImmutableError(slug);
  }
  if (role.organization_id !== organizationId) throw new RoleNotFoundError(slug);
  return role;
}

async function replaceRolePermissions(
  client: SupabaseClient,
  organizationId: string,
  slug: string,
  permissionSlugs: string[],
): Promise<void> {
  await assertPermissionsExist(client, permissionSlugs);

  const del = await client
    .from("role_permissions")
    .delete()
    .eq("role_slug", slug);
  if (del.error) throw new Error(`role permission clear failed: ${del.error.message}`);

  const rows = [...new Set(permissionSlugs)].map((permission_slug) => ({
    role_slug: slug,
    permission_slug,
    organization_id: organizationId, // trigger re-derives from the role; explicit for clarity
  }));
  if (rows.length === 0) return;

  const ins = await client.from("role_permissions").insert(rows);
  if (ins.error) throw new Error(`role permission insert failed: ${ins.error.message}`);
}

export interface CreateCustomRoleInput {
  organizationId: string;
  displayName: string;
  permissionSlugs: string[];
}

/** Create a tenant custom role + attach permissions. Returns its slug. */
export async function createCustomRole(
  client: SupabaseClient,
  input: CreateCustomRoleInput,
): Promise<{ slug: string; displayName: string }> {
  const displayName = input.displayName.trim();
  if (!displayName) throw new Error("displayName is required");

  await assertPermissionsExist(client, input.permissionSlugs);

  const slug = customRoleSlug(input.organizationId, displayName);

  const ins = await client.from("role_definitions").insert({
    slug,
    display_name: displayName,
    scope: "school", // tenant custom roles are school-scoped (never platform/org)
    is_system: false,
    organization_id: input.organizationId,
  });
  if (ins.error) {
    if (ins.error.code === UNIQUE_VIOLATION) throw new RoleSlugConflictError(displayName);
    throw new Error(`custom role insert failed: ${ins.error.message}`);
  }

  await replaceRolePermissions(client, input.organizationId, slug, input.permissionSlugs);
  return { slug, displayName };
}

export interface UpdateCustomRoleInput {
  organizationId: string;
  slug: string;
  displayName?: string;
  permissionSlugs?: string[];
}

/** Rename and/or replace the permission set of a tenant's OWN custom role. */
export async function updateCustomRole(
  client: SupabaseClient,
  input: UpdateCustomRoleInput,
): Promise<void> {
  await requireOwnCustomRole(client, input.organizationId, input.slug);

  if (input.displayName !== undefined) {
    const displayName = input.displayName.trim();
    if (!displayName) throw new Error("displayName cannot be blank");
    const upd = await client
      .from("role_definitions")
      .update({ display_name: displayName })
      .eq("slug", input.slug)
      .eq("organization_id", input.organizationId) // re-assert org ownership
      .eq("is_system", false); //                     re-assert immutability
    if (upd.error) {
      if (upd.error.code === UNIQUE_VIOLATION) throw new RoleSlugConflictError(displayName);
      throw new Error(`custom role rename failed: ${upd.error.message}`);
    }
  }

  if (input.permissionSlugs !== undefined) {
    await replaceRolePermissions(
      client,
      input.organizationId,
      input.slug,
      input.permissionSlugs,
    );
  }
}

/** Delete a tenant's OWN custom role (fails if it is still assigned to members). */
export async function deleteCustomRole(
  client: SupabaseClient,
  input: { organizationId: string; slug: string },
): Promise<void> {
  await requireOwnCustomRole(client, input.organizationId, input.slug);

  const del = await client
    .from("role_definitions")
    .delete()
    .eq("slug", input.slug)
    .eq("organization_id", input.organizationId) // re-assert org ownership
    .eq("is_system", false); //                     re-assert immutability
  if (del.error) {
    if (del.error.code === FK_VIOLATION) throw new RoleInUseError(input.slug);
    throw new Error(`custom role delete failed: ${del.error.message}`);
  }
}

/** List a tenant's own custom roles with their permission sets. */
export async function listCustomRoles(
  client: SupabaseClient,
  organizationId: string,
): Promise<CustomRoleSummary[]> {
  const { data: roles, error: rolesErr } = await client
    .from("role_definitions")
    .select("slug, display_name")
    .eq("organization_id", organizationId)
    .eq("is_system", false);
  if (rolesErr) throw new Error(`custom role list failed: ${rolesErr.message}`);

  const roleRows = (roles ?? []) as Array<{ slug: string; display_name: string }>;
  if (roleRows.length === 0) return [];

  const slugs = roleRows.map((r) => r.slug);
  const { data: perms, error: permsErr } = await client
    .from("role_permissions")
    .select("role_slug, permission_slug")
    .in("role_slug", slugs);
  if (permsErr) throw new Error(`custom role permission list failed: ${permsErr.message}`);

  const bySlug = new Map<string, string[]>();
  for (const row of (perms ?? []) as Array<{ role_slug: string; permission_slug: string }>) {
    const list = bySlug.get(row.role_slug) ?? [];
    list.push(row.permission_slug);
    bySlug.set(row.role_slug, list);
  }

  return roleRows.map((r) => ({
    slug: r.slug,
    displayName: r.display_name,
    permissions: (bySlug.get(r.slug) ?? []).sort(),
  }));
}
