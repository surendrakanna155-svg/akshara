import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
} from "../permission_middleware.ts";
import {
  type TenantQueryClient,
  TenantDbNotConfiguredError,
  withTenantContext,
} from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import { enforceSchoolLimit } from "../entitlements/entitlement_limits.ts";

/**
 * Write counterpart to the Control Center read handlers. Control Center is
 * PLATFORM/ORG scope, so these gate on the `manageControlCenter` permission and
 * an `organization` token scope (NOT `requireSchoolOperationalScope`). Records
 * are persisted into the org-scoped `control_center_entities` table (no
 * `school_id` column), so the shared entity write store cannot be reused — the
 * inserts below are keyed by `organization_id` only.
 */

const TABLE = "control_center_entities";

function tenantError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  return errorEnvelope("INTERNAL_ERROR", String(error), 500);
}

function requireManageOrgScope(
  claims: Parameters<typeof requirePermission>[0],
): Response | null {
  const denied = requirePermission(claims, "manageControlCenter");
  if (denied) return denied;
  if (claims.scope !== "organization") {
    return errorEnvelope("FORBIDDEN", "Control center requires organization scope", 403);
  }
  return null;
}

/** Insert a row into the org-scoped control_center_entities table. */
async function insertEntity(
  db: TenantQueryClient,
  organizationId: string,
  entityType: string,
  id: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `INSERT INTO ${TABLE} (id, organization_id, entity_type, payload)
     VALUES ($1, $2, $3, $4::jsonb)
     RETURNING payload`,
    [id, organizationId, entityType, JSON.stringify(payload)],
  );
  return rows[0]?.payload ?? payload;
}

/**
 * Read-modify-write the `snapshot_crm` document. The current payload (or `{}`
 * when absent) is passed to `mutate`; the full result is persisted and returned.
 */
async function mutateCrmSnapshot(
  db: TenantQueryClient,
  organizationId: string,
  mutate: (current: Record<string, unknown>) => Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const existing = await db.queryObject<{ payload: Record<string, unknown> }>(
    `SELECT payload FROM ${TABLE}
     WHERE organization_id = $1 AND entity_type = 'snapshot_crm' AND id = 'default'`,
    [organizationId],
  );
  const current = existing[0]?.payload ?? {};
  const next = mutate(current);
  if (existing.length === 0) {
    return await insertEntity(db, organizationId, "snapshot_crm", "default", next);
  }
  const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
    `UPDATE ${TABLE} SET payload = $2::jsonb
     WHERE organization_id = $1 AND entity_type = 'snapshot_crm' AND id = 'default'
     RETURNING payload`,
    [organizationId, JSON.stringify(next)],
  );
  return rows[0]?.payload ?? next;
}

function str(body: Record<string, unknown> | null, key: string): string | undefined {
  const value = body?.[key];
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : undefined;
}

function numFrom(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number.parseFloat(value.replace(/[^0-9.+-]/g, ""));
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function intFrom(value: unknown): number {
  return Math.max(0, Math.trunc(numFrom(value)));
}

const ALLOWED_PLANS = new Set(["standard", "premium", "enterprise"]);

/** POST /control-center/schools — onboard a platform school. */
export async function handleCreateSchool(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireManageOrgScope(auth.claims);
  if (denied) return denied;

  // B2 school slab limit (no-op unless ENTITLEMENT_ENFORCEMENT is on for an assigned plan).
  const limitDenied = await enforceSchoolLimit(config, auth.claims);
  if (limitDenied) return limitDenied;

  const body = await readJson<Record<string, unknown>>(req);
  const name = str(body, "name");
  if (!name) {
    return errorEnvelope("VALIDATION_ERROR", "name required", 422);
  }
  const planRaw = (str(body, "plan") ?? "standard").toLowerCase();
  const plan = ALLOWED_PLANS.has(planRaw) ? planRaw : "standard";

  const orgId = organizationIdFromClaims(auth.claims);
  const id = crypto.randomUUID();
  const payload: Record<string, unknown> = {
    id,
    name,
    plan,
    studentCount: intFrom(body?.studentCount),
    status: "active",
    createdDate: new Date().toISOString().slice(0, 10),
    mrrLakhs: numFrom(body?.mrrLakhs),
    healthScore: 100,
    region: str(body, "region") ?? "",
    tenantId: str(body, "tenantId") ?? "",
  };

  try {
    const saved = await withTenantContext(config, auth.claims, async (db) => {
      const persisted = await insertEntity(db, orgId, "school", id, payload);
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("control_center.school.created", "control_center_school", id, {
          name,
          plan,
        }),
        req,
      );
      return persisted;
    });
    return jsonResponse(envelope(saved), { status: 201 });
  } catch (error) {
    return tenantError(error);
  }
}

/** POST /control-center/crm-pipeline — add a CRM lead/deal to the pipeline. */
export async function handleCreateLead(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireManageOrgScope(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  const schoolName = str(body, "schoolName");
  if (!schoolName) {
    return errorEnvelope("VALIDATION_ERROR", "schoolName required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const id = crypto.randomUUID();
  const deal: Record<string, unknown> = {
    id,
    schoolName,
    contactName: str(body, "contactName") ?? "",
    stage: "lead",
    estimatedMrrLakhs: numFrom(body?.estimatedMrr ?? body?.estimatedMrrLakhs),
    owner: str(body, "owner") ?? "",
    lastActivity: new Date().toISOString().slice(0, 10),
  };

  try {
    await withTenantContext(config, auth.claims, async (db) => {
      await mutateCrmSnapshot(db, orgId, (current) => {
        const deals = Array.isArray(current.deals) ? current.deals as Array<unknown> : [];
        return { ...current, deals: [...deals, deal] };
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("control_center.lead.created", "control_center_lead", id, {
          schoolName,
        }),
        req,
      );
    });
    return jsonResponse(envelope(deal), { status: 201 });
  } catch (error) {
    return tenantError(error);
  }
}
