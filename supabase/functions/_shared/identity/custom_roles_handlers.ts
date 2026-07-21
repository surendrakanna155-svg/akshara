// ICA-G3 — custom-role admin endpoints (identity plane).
//
// A school/org admin (gated on `manageManagement`, the same governance authority
// that guards permission overrides) may CREATE / UPDATE / DELETE / LIST their own
// organization's custom roles and attach permissions from the existing catalogue.
// Built-in system roles are rejected by every write path (immutable). Custom roles
// belong to the caller's organization (`claims.tenant_id`); a role from another
// org is invisible (404) — org isolation. Writes run on the service-role client
// (the catalog carries RLS as defense-in-depth); ownership + immutability are
// enforced in the repository. Every mutation is audited.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import { authenticateRequest, requirePermission } from "../permission_middleware.ts";
import { withTenantContext } from "../tenant_db.ts";
import { createServiceClient } from "../db.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  createCustomRole,
  deleteCustomRole,
  listCustomRoles,
  RoleInUseError,
  RoleNotFoundError,
  RoleSlugConflictError,
  SystemRoleImmutableError,
  UnknownPermissionError,
  updateCustomRole,
} from "./custom_roles_repository.ts";

const ROLE_GATE = "manageManagement";

/** Shared preamble: authenticate, gate on manageManagement, require school scope. */
async function guard(
  req: Request,
  config: AppConfig,
): Promise<
  | { ok: true; claims: AccessTokenClaims; organizationId: string }
  | { ok: false; response: Response }
> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return { ok: false, response: auth.response };

  const denied = requirePermission(auth.claims, ROLE_GATE);
  if (denied) return { ok: false, response: denied };

  if (auth.claims.scope !== "school" || !auth.claims.school_id) {
    return {
      ok: false,
      response: errorEnvelope("FORBIDDEN", "Custom roles are managed within a school scope", 403),
    };
  }
  return { ok: true, claims: auth.claims, organizationId: auth.claims.tenant_id };
}

/** Map repository errors to HTTP envelopes. Returns null when `err` is unmapped. */
function mapRoleError(err: unknown): Response | null {
  if (err instanceof SystemRoleImmutableError) {
    return errorEnvelope("FORBIDDEN", err.message, 403);
  }
  if (err instanceof RoleNotFoundError) {
    return errorEnvelope("ROLE_NOT_FOUND", err.message, 404);
  }
  if (err instanceof UnknownPermissionError) {
    return errorEnvelope("VALIDATION_ERROR", err.message, 422);
  }
  if (err instanceof RoleSlugConflictError) {
    return errorEnvelope("ROLE_CONFLICT", err.message, 409);
  }
  if (err instanceof RoleInUseError) {
    return errorEnvelope("ROLE_IN_USE", err.message, 409);
  }
  return null;
}

interface CreateBody {
  displayName?: string;
  permissions?: string[];
}

/** POST /identity/roles — create a custom role + attach permissions. */
export async function handleCreateCustomRole(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const g = await guard(req, config);
  if (!g.ok) return g.response;

  const body = await readJson<CreateBody>(req);
  if (!body?.displayName || !body.displayName.trim()) {
    return errorEnvelope("VALIDATION_ERROR", "displayName is required", 422);
  }
  const permissions = Array.isArray(body.permissions) ? body.permissions : [];

  const service = createServiceClient(config);
  let created: { slug: string; displayName: string };
  try {
    created = await createCustomRole(service, {
      organizationId: g.organizationId,
      displayName: body.displayName,
      permissionSlugs: permissions,
    });
  } catch (err) {
    const mapped = mapRoleError(err);
    if (mapped) return mapped;
    throw err;
  }

  await withTenantContext(config, g.claims, (db) =>
    emitMutationAudit(
      db,
      g.claims,
      moduleEntityAudit("identity.custom_role.created", "role_definition", created.slug, {
        displayName: created.displayName,
        permissions,
      }),
      req,
    ));

  return jsonResponse(envelope({
    success: true,
    slug: created.slug,
    displayName: created.displayName,
    permissions,
  }));
}

interface UpdateBody {
  slug?: string;
  displayName?: string;
  permissions?: string[];
}

/** POST /identity/roles/update — rename and/or replace a custom role's permissions. */
export async function handleUpdateCustomRole(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const g = await guard(req, config);
  if (!g.ok) return g.response;

  const body = await readJson<UpdateBody>(req);
  if (!body?.slug) {
    return errorEnvelope("VALIDATION_ERROR", "slug is required", 422);
  }
  if (body.displayName === undefined && body.permissions === undefined) {
    return errorEnvelope("VALIDATION_ERROR", "nothing to update (displayName or permissions)", 422);
  }

  const service = createServiceClient(config);
  try {
    await updateCustomRole(service, {
      organizationId: g.organizationId,
      slug: body.slug,
      displayName: body.displayName,
      permissionSlugs: body.permissions,
    });
  } catch (err) {
    const mapped = mapRoleError(err);
    if (mapped) return mapped;
    throw err;
  }

  await withTenantContext(config, g.claims, (db) =>
    emitMutationAudit(
      db,
      g.claims,
      moduleEntityAudit("identity.custom_role.updated", "role_definition", body.slug!, {
        displayName: body.displayName,
        permissions: body.permissions,
      }),
      req,
    ));

  return jsonResponse(envelope({ success: true, slug: body.slug }));
}

interface DeleteBody {
  slug?: string;
}

/** POST /identity/roles/delete — delete a custom role (must be unassigned). */
export async function handleDeleteCustomRole(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const g = await guard(req, config);
  if (!g.ok) return g.response;

  const body = await readJson<DeleteBody>(req);
  if (!body?.slug) {
    return errorEnvelope("VALIDATION_ERROR", "slug is required", 422);
  }

  const service = createServiceClient(config);
  try {
    await deleteCustomRole(service, { organizationId: g.organizationId, slug: body.slug });
  } catch (err) {
    const mapped = mapRoleError(err);
    if (mapped) return mapped;
    throw err;
  }

  await withTenantContext(config, g.claims, (db) =>
    emitMutationAudit(
      db,
      g.claims,
      moduleEntityAudit("identity.custom_role.deleted", "role_definition", body.slug!, {}),
      req,
    ));

  return jsonResponse(envelope({ success: true, slug: body.slug }));
}

/** GET /identity/roles — list the caller org's custom roles + permission sets. */
export async function handleListCustomRoles(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const g = await guard(req, config);
  if (!g.ok) return g.response;

  const service = createServiceClient(config);
  const roles = await listCustomRoles(service, g.organizationId);
  return jsonResponse(envelope({ roles }));
}
