import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AuthScope } from "./jwt.ts";
import {
  resolveOrganizationMembershipPermissions,
  resolveSchoolMembershipPermissions,
  type ResolvedPermissions,
} from "./permission_resolver.ts";

export interface AuthSessionContext {
  scope: AuthScope;
  tenantId: string;
  organizationId: string;
  schoolId: string | null;
  schoolGroupId: string | null;
  studentId: string | null;
  childIds: string[];
  resolved: ResolvedPermissions;
}

export interface ScopeLoginRequest {
  scope?: AuthScope;
  schoolId?: string;
  organizationId?: string;
  studentId?: string;
}

const ORG_SCOPES: AuthScope[] = ["organization"];
const RELATIONSHIP_SCOPES: AuthScope[] = ["parent", "student"];

/** Default login: school staff if present, else org, parent, student (v6.0 school-first compat). */
export function resolveLoginScopeOrder(
  requested?: AuthScope,
): AuthScope[] {
  if (requested) return [requested];
  return ["school", "organization", "parent", "student"];
}

export async function resolveAuthSessionContext(
  client: SupabaseClient,
  userId: string,
  request: ScopeLoginRequest = {},
): Promise<AuthSessionContext | null> {
  const order = resolveLoginScopeOrder(request.scope);

  for (const scope of order) {
    const ctx = await resolveScopeContext(client, userId, scope, request);
    if (ctx) return ctx;
  }
  return null;
}

async function resolveScopeContext(
  client: SupabaseClient,
  userId: string,
  scope: AuthScope,
  request: ScopeLoginRequest,
): Promise<AuthSessionContext | null> {
  switch (scope) {
    case "school":
      return resolveSchoolContext(client, userId, request.schoolId);
    case "organization":
      return resolveOrganizationContext(client, userId, request.organizationId);
    case "parent":
      return resolveParentContext(client, userId, request.schoolId, request.studentId);
    case "student":
      return resolveStudentContext(client, userId, request.schoolId);
    default:
      return null;
  }
}

async function resolveSchoolContext(
  client: SupabaseClient,
  userId: string,
  schoolId?: string,
): Promise<AuthSessionContext | null> {
  let query = client
    .from("school_memberships")
    .select(
      "id,user_id,school_id,role,permissions_version,schools(id,organization_id,name,code),school_membership_roles(role_slug,is_primary,status)",
    )
    .eq("user_id", userId)
    .eq("status", "active");

  if (schoolId) query = query.eq("school_id", schoolId);

  const { data, error } = await query.limit(1).maybeSingle();
  if (error || !data) return null;

  const membership = data as unknown as {
    id: string;
    school_id: string;
    role: string;
    permissions_version: number;
    schools: { organization_id: string };
  };

  const resolved = await resolveSchoolMembershipPermissions(
    client,
    membership.id,
    membership.role,
    membership.permissions_version,
  );

  return {
    scope: "school",
    tenantId: membership.schools.organization_id,
    organizationId: membership.schools.organization_id,
    schoolId: membership.school_id,
    schoolGroupId: null,
    studentId: null,
    childIds: [],
    resolved,
  };
}

async function resolveOrganizationContext(
  client: SupabaseClient,
  userId: string,
  organizationId?: string,
): Promise<AuthSessionContext | null> {
  let query = client
    .from("organization_memberships")
    .select(
      "id,user_id,organization_id,role,permissions_version,organization_membership_roles(role_slug,is_primary,status)",
    )
    .eq("user_id", userId)
    .eq("status", "active");

  if (organizationId) query = query.eq("organization_id", organizationId);

  const { data, error } = await query.limit(1).maybeSingle();
  if (error || !data) return null;

  const membership = data as {
    id: string;
    organization_id: string;
    role: string;
    permissions_version: number;
  };

  const resolved = await resolveOrganizationMembershipPermissions(
    client,
    membership.id,
    membership.role,
    membership.permissions_version,
  );

  return {
    scope: "organization",
    tenantId: membership.organization_id,
    organizationId: membership.organization_id,
    schoolId: null,
    schoolGroupId: null,
    studentId: null,
    childIds: [],
    resolved,
  };
}

async function resolveParentContext(
  client: SupabaseClient,
  userId: string,
  schoolId?: string,
  activeStudentId?: string,
): Promise<AuthSessionContext | null> {
  let query = client
    .from("student_guardians")
    .select(
      "organization_id,school_id,student_id,students(id,display_name,status)",
    )
    .eq("guardian_user_id", userId)
    .eq("status", "active");

  if (schoolId) query = query.eq("school_id", schoolId);

  const { data, error } = await query;
  if (error || !data?.length) return null;

  const links = data as Array<{
    organization_id: string;
    school_id: string;
    student_id: string;
  }>;

  const schoolIds = [...new Set(links.map((l) => l.school_id))];
  const activeSchoolId = schoolId ?? schoolIds[0];
  const schoolLinks = links.filter((l) => l.school_id === activeSchoolId);
  if (schoolLinks.length === 0) return null;

  const childIds = schoolLinks.map((l) => l.student_id);
  const studentId = activeStudentId && childIds.includes(activeStudentId)
    ? activeStudentId
    : childIds[0];

  const parentResolved = await loadRelationshipRolePermissions(client, "parent");

  return {
    scope: "parent",
    tenantId: schoolLinks[0].organization_id,
    organizationId: schoolLinks[0].organization_id,
    schoolId: activeSchoolId,
    schoolGroupId: null,
    studentId: null,
    childIds,
    resolved: parentResolved,
  };
}

async function resolveStudentContext(
  client: SupabaseClient,
  userId: string,
  schoolId?: string,
): Promise<AuthSessionContext | null> {
  let query = client
    .from("students")
    .select("id,organization_id,school_id,display_name,status")
    .eq("user_id", userId)
    .eq("status", "active");

  if (schoolId) query = query.eq("school_id", schoolId);

  const { data, error } = await query.limit(1).maybeSingle();
  if (error || !data) return null;

  const student = data as {
    id: string;
    organization_id: string;
    school_id: string;
  };

  const studentResolved = await loadRelationshipRolePermissions(client, "student");

  return {
    scope: "student",
    tenantId: student.organization_id,
    organizationId: student.organization_id,
    schoolId: student.school_id,
    schoolGroupId: null,
    studentId: student.id,
    childIds: [],
    resolved: studentResolved,
  };
}

async function loadRelationshipRolePermissions(
  client: SupabaseClient,
  roleSlug: string,
): Promise<ResolvedPermissions> {
  const { data, error } = await client
    .from("role_permissions")
    .select("permission_slug")
    .eq("role_slug", roleSlug);

  if (error) throw error;

  const permissions = (data ?? []).map((r) => r.permission_slug as string).sort();
  if (permissions.length === 0) permissions.push("viewAdminHub");

  return {
    permissions,
    roleSlugs: [roleSlug],
    primaryRole: roleSlug,
    permissionsVersion: 1,
  };
}

/** Rebuild session context from persisted session row (refresh / context switch). */
export async function resolveAuthSessionContextFromSession(
  client: SupabaseClient,
  userId: string,
  session: {
    scope: AuthScope;
    context_school_id: string | null;
    context_school_group_id: string | null;
    context_student_id: string | null;
    context_child_ids: string[] | null;
    tenant_id: string;
  },
): Promise<AuthSessionContext | null> {
  const request: ScopeLoginRequest = {
    scope: session.scope,
    schoolId: session.context_school_id ?? undefined,
    organizationId: session.tenant_id,
    studentId: session.context_student_id ?? undefined,
  };

  const ctx = await resolveAuthSessionContext(client, userId, request);
  if (!ctx) return null;

  if (session.scope === "parent" && session.context_child_ids?.length) {
    return { ...ctx, childIds: session.context_child_ids };
  }
  if (session.scope === "student" && session.context_student_id) {
    return { ...ctx, studentId: session.context_student_id };
  }
  return ctx;
}

export function isOrgScope(scope: AuthScope): boolean {
  return ORG_SCOPES.includes(scope);
}

export function isRelationshipScope(scope: AuthScope): boolean {
  return RELATIONSHIP_SCOPES.includes(scope);
}
