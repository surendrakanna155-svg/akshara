import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import type { AuthScope } from "./jwt.ts";
import {
  resolveOrganizationMembershipPermissions,
  resolveSchoolMembershipPermissions,
  type ResolvedPermissions,
} from "./permission_resolver.ts";

export interface ChildProfileSummary {
  id: string;
  name: string;
  classLabel: string;
}

export interface AuthSessionContext {
  scope: AuthScope;
  tenantId: string;
  organizationId: string;
  schoolId: string | null;
  schoolGroupId: string | null;
  studentId: string | null;
  childIds: string[];
  /// Display details for linked children (login payload only; not in the JWT).
  childProfiles?: ChildProfileSummary[];
  /// G4 — true when the caller's organization runs more than one school (a
  /// chain/trust). Drives Organization Builder visibility client-side, which
  /// otherwise had no server source and was permanently hidden.
  isChainOrganization: boolean;
  resolved: ResolvedPermissions;
}

/**
 * An organization is a "chain" when it operates more than one (non-deleted)
 * school — the natural source of truth for trust/multi-branch visibility.
 * Best-effort: any read error resolves to false (single-school behavior).
 */
async function resolveChainStatus(
  client: SupabaseClient,
  organizationId: string,
): Promise<boolean> {
  const { count, error } = await client
    .from("schools")
    .select("id", { count: "exact", head: true })
    .eq("organization_id", organizationId)
    .is("deleted_at", null);
  if (error) return false;
  return (count ?? 0) > 1;
}

export interface ScopeLoginRequest {
  scope?: AuthScope;
  schoolId?: string;
  organizationId?: string;
  studentId?: string;
}

const ORG_SCOPES: AuthScope[] = ["organization"];
const RELATIONSHIP_SCOPES: AuthScope[] = ["parent", "student"];

/// RT-34 — upper bound on the parent/guardian children fan-out queries. A real
/// guardian is linked to a handful of students; this caps the worst-case login
/// query for an outlier (or abusive) account.
const PARENT_FANOUT_LIMIT = 50;

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

  // PRA-P1-04 (S2): a user with memberships in more than one school must resolve
  // to a STABLE school across logins — `.limit(1)` with no ORDER BY let Postgres
  // pick any row, so the same staff-parent could land in a different school (and
  // permission set) request to request. Order deterministically (oldest
  // membership first, school_id as the tiebreak).
  const { data, error } = await query
    .order("created_at", { ascending: true })
    .order("school_id", { ascending: true })
    .limit(1)
    .maybeSingle();
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
    isChainOrganization: await resolveChainStatus(client, membership.schools.organization_id),
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

  // PRA-P1-04 (S2): deterministic pick when a user has multiple org memberships.
  const { data, error } = await query
    .order("created_at", { ascending: true })
    .order("organization_id", { ascending: true })
    .limit(1)
    .maybeSingle();
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
    isChainOrganization: await resolveChainStatus(client, membership.organization_id),
    resolved,
  };
}

/**
 * Builds display details (name + current class) for a set of linked children.
 * Names may be pre-resolved (e.g. from a guardian-link join); any missing ones
 * are fetched from `students.display_name`. Class comes from the current SIS
 * enrollment. Read-only and best-effort — missing data yields empty strings.
 */
export async function loadChildProfiles(
  client: SupabaseClient,
  childIds: string[],
  preResolvedNames: Map<string, string> = new Map(),
): Promise<ChildProfileSummary[]> {
  if (childIds.length === 0) return [];

  const nameByStudent = new Map(preResolvedNames);
  const missing = childIds.filter((id) => !nameByStudent.has(id));
  if (missing.length > 0) {
    const { data: students } = await client
      .from("students")
      .select("id,display_name")
      .in("id", missing)
      .limit(PARENT_FANOUT_LIMIT); // RT-34: bound the fan-out
    for (const row of (students ?? []) as Array<{ id: string; display_name: string }>) {
      nameByStudent.set(row.id, row.display_name ?? "");
    }
  }

  const classByStudent = new Map<string, string>();
  const { data: enrollments } = await client
    .from("sis_student_enrollments")
    .select("student_id,class_name,section_name")
    .in("student_id", childIds)
    .eq("is_current", true)
    .limit(PARENT_FANOUT_LIMIT); // RT-34: bound the fan-out
  for (const row of (enrollments ?? []) as Array<
    { student_id: string; class_name: string; section_name: string | null }
  >) {
    const label = [row.class_name, row.section_name].filter((p) => p && p.length)
      .join("-");
    classByStudent.set(row.student_id, label);
  }

  return childIds.map((id) => ({
    id,
    name: nameByStudent.get(id) ?? "",
    classLabel: classByStudent.get(id) ?? "",
  }));
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

  // RT-34: bound the guardian-link fan-out (no family has 50+ active links).
  // PRA-P1-04 (S2): order by student_id so the resolved child list — and the
  // default active child (childIds[0]) — is stable across logins.
  const { data, error } = await query
    .order("student_id", { ascending: true })
    .limit(PARENT_FANOUT_LIMIT);
  if (error || !data?.length) return null;

  const links = data as Array<{
    organization_id: string;
    school_id: string;
    student_id: string;
    students?: { id: string; display_name: string; status: string }[] | null;
  }>;

  // PRA-P1-04 (S2): sort so a guardian linked across multiple schools resolves
  // to a stable default school (was Set-iteration order = non-deterministic).
  const schoolIds = [...new Set(links.map((l) => l.school_id))].sort();
  const activeSchoolId = schoolId ?? schoolIds[0];
  const schoolLinks = links.filter((l) => l.school_id === activeSchoolId);
  if (schoolLinks.length === 0) return null;

  const childIds = schoolLinks.map((l) => l.student_id);
  const studentId = activeStudentId && childIds.includes(activeStudentId)
    ? activeStudentId
    : childIds[0];

  // PAR-7: enrich linked children with real name + current class so the parent
  // child-switcher shows distinct students, not placeholder "Child" entries.
  const nameByStudent = new Map<string, string>();
  for (const l of schoolLinks) {
    const studentName = l.students?.[0]?.display_name;
    if (studentName) nameByStudent.set(l.student_id, studentName);
  }
  const childProfiles = await loadChildProfiles(client, childIds, nameByStudent);

  const parentResolved = await loadRelationshipRolePermissions(client, "parent");

  return {
    scope: "parent",
    tenantId: schoolLinks[0].organization_id,
    organizationId: schoolLinks[0].organization_id,
    schoolId: activeSchoolId,
    schoolGroupId: null,
    studentId: null,
    childIds,
    childProfiles,
    isChainOrganization: false,
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
    isChainOrganization: false,
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

  // PRA-P1-03 (S2): on refresh/context rebuild, do NOT blindly restore the child
  // list captured in the session at login — a guardian link revoked since then
  // would silently persist, keeping the parent's access to a child they are no
  // longer linked to. Start from the FRESHLY resolved active links (ctx.childIds,
  // derived from live `student_guardians` rows with status='active') and keep
  // only those the session was actually scoped to. This drops revoked children
  // and never widens the session's scope.
  if (session.scope === "parent") {
    const sessionChildIds = session.context_child_ids ?? [];
    const childIds = sessionChildIds.length
      ? ctx.childIds.filter((id) => sessionChildIds.includes(id))
      : ctx.childIds;
    return { ...ctx, childIds };
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
