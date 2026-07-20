// W4 (Owner decision #12, FINAL) — Device / Asset management handlers.
//
//   POST /inventory/devices                  register an asset            (manageInventory)
//   GET  /inventory/devices                  list register ?status/type/assignee (viewInventory|manageInventory)
//   GET  /inventory/devices/by-staff         staff member's held assets ?staffId= (viewInventory|manageInventory)
//   GET  /inventory/devices/:id              one asset                    (viewInventory|manageInventory)
//   GET  /inventory/devices/:id/history      custody timeline             (viewInventory|manageInventory)
//   POST /inventory/devices/:id/assign       assign to a staff member     (manageInventory)
//   POST /inventory/devices/:id/return       return from a staff member   (manageInventory)
//   POST /inventory/devices/:id/retire       retire (terminal)            (manageInventory)
//   POST /inventory/devices/:id/lost         mark lost (terminal)         (manageInventory)
//
// RBAC reuses the existing inventory-management permissions (manageInventory to
// write, viewInventory OR manageInventory to read) — an org asset register is an
// inventory / store concern (the `inventoryManager` role already holds them). Every
// write audits via moduleEntityAudit INSIDE the tenant transaction, so the audit
// row and the asset write commit (or roll back) together.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireAnyPermission,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  assetRowToApi,
  assignDevice,
  assignmentRowToApi,
  DeviceConflictError,
  DeviceNotFoundError,
  type DeviceScope,
  DeviceStatusConflictError,
  DeviceValidationError,
  findDeviceById,
  getDeviceHistory,
  listDevices,
  listDevicesByStaff,
  markDeviceLost,
  registerDevice,
  returnDevice,
  retireDevice,
} from "./device_management_repository.ts";

const WRITE_PERMISSION = "manageInventory";
const READ_PERMISSIONS = ["viewInventory", "manageInventory"];

function requireWriter(claims: AccessTokenClaims): Response | null {
  return requirePermission(claims, WRITE_PERMISSION) ??
    requireSchoolOperationalScope(claims, "Device management");
}

function requireReader(claims: AccessTokenClaims): Response | null {
  return requireAnyPermission(claims, READ_PERMISSIONS) ??
    requireSchoolOperationalScope(claims, "Device management");
}

function subjectOf(claims: AccessTokenClaims): string {
  return String(claims.sub ?? "");
}

function scopeOf(claims: AccessTokenClaims): DeviceScope {
  return {
    organizationId: organizationIdFromClaims(claims),
    schoolId: schoolIdFromClaims(claims),
  };
}

/** The :id segment of /inventory/devices/:id[/action]. */
export function deviceIdFromPath(path: string): string {
  return (path.split("/")[3] ?? "").trim();
}

function str(body: Record<string, unknown>, key: string): string {
  const v = body[key];
  return typeof v === "string" ? v.trim() : "";
}

async function readBody(req: Request): Promise<Record<string, unknown> | null> {
  try {
    return (await readJson<Record<string, unknown>>(req)) ?? {};
  } catch {
    return null;
  }
}

/** Map a repository/DB error to its HTTP envelope. Re-throws the unknown ones. */
function mapError(error: unknown): Response {
  if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
  if (error instanceof DeviceValidationError) {
    return errorEnvelope("DEVICE_VALIDATION", error.message, 422);
  }
  if (error instanceof DeviceNotFoundError) {
    return errorEnvelope("DEVICE_NOT_FOUND", error.message, 404);
  }
  if (error instanceof DeviceStatusConflictError) {
    return errorEnvelope("DEVICE_STATUS_CONFLICT", error.message, 409);
  }
  if (error instanceof DeviceConflictError) {
    return errorEnvelope("DEVICE_CONFLICT", error.message, 409);
  }
  throw error;
}

// ─── Register / list / lookup ─────────────────────────────────────────────────

export async function handleRegisterDevice(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWriter(auth.claims);
  if (denied) return denied;

  const body = await readBody(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  const assetTag = str(body, "assetTag");
  const assetType = str(body, "assetType");
  if (!assetTag) return errorEnvelope("DEVICE_VALIDATION", "assetTag is required", 422);
  if (!assetType) return errorEnvelope("DEVICE_VALIDATION", "assetType is required", 422);

  const scope = scopeOf(auth.claims);
  const createdBy = subjectOf(auth.claims);
  const rawCost = body["purchaseCost"];
  const purchaseCost = typeof rawCost === "number" ? rawCost : Number(rawCost);
  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const row = await registerDevice(db, scope, {
        assetTag,
        assetType,
        serialNo: str(body, "serialNo") || null,
        purchaseRef: str(body, "purchaseRef") || null,
        purchaseCost: Number.isFinite(purchaseCost) ? purchaseCost : 0,
        note: str(body, "note") || null,
        createdBy,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("devicemgmt.asset.registered", "org_asset", row.id, {
          assetTag: row.asset_tag,
          assetType: row.asset_type,
        }),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(assetRowToApi(created)), { status: 201 });
  } catch (error) {
    return mapError(error);
  }
}

export async function handleListDevices(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireReader(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const scope = scopeOf(auth.claims);
  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      listDevices(db, scope, {
        status: (url.searchParams.get("status") ?? "").trim() || undefined,
        assetType: (url.searchParams.get("type") ?? "").trim() || undefined,
        assignee: (url.searchParams.get("assignee") ?? "").trim() || undefined,
      }));
    return jsonResponse(envelope({ items: rows.map(assetRowToApi), count: rows.length }));
  } catch (error) {
    return mapError(error);
  }
}

export async function handleListDevicesByStaff(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireReader(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const staffId = (url.searchParams.get("staffId") ?? "").trim();
  if (!staffId) return errorEnvelope("DEVICE_VALIDATION", "staffId query parameter is required", 422);
  const scope = scopeOf(auth.claims);
  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      listDevicesByStaff(db, scope, staffId));
    return jsonResponse(
      envelope({ staffId, items: rows.map(assetRowToApi), count: rows.length }),
    );
  } catch (error) {
    return mapError(error);
  }
}

export async function handleGetDevice(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireReader(auth.claims);
  if (denied) return denied;

  const id = deviceIdFromPath(new URL(req.url).pathname);
  if (!id) return errorEnvelope("DEVICE_VALIDATION", "device id is required", 422);
  const scope = scopeOf(auth.claims);
  try {
    const row = await withTenantContext(config, auth.claims, (db) => findDeviceById(db, scope, id));
    if (!row) return errorEnvelope("DEVICE_NOT_FOUND", `Asset not found: ${id}`, 404);
    return jsonResponse(envelope(assetRowToApi(row)));
  } catch (error) {
    return mapError(error);
  }
}

export async function handleDeviceHistory(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireReader(auth.claims);
  if (denied) return denied;

  const id = deviceIdFromPath(new URL(req.url).pathname);
  if (!id) return errorEnvelope("DEVICE_VALIDATION", "device id is required", 422);
  const scope = scopeOf(auth.claims);
  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const asset = await findDeviceById(db, scope, id);
      if (!asset) return null;
      const history = await getDeviceHistory(db, scope, id);
      return { asset, history };
    });
    if (!result) return errorEnvelope("DEVICE_NOT_FOUND", `Asset not found: ${id}`, 404);
    return jsonResponse(envelope({
      asset: assetRowToApi(result.asset),
      history: result.history.map(assignmentRowToApi),
      count: result.history.length,
    }));
  } catch (error) {
    return mapError(error);
  }
}

// ─── Lifecycle writes ─────────────────────────────────────────────────────────

export async function handleAssignDevice(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWriter(auth.claims);
  if (denied) return denied;

  const id = deviceIdFromPath(new URL(req.url).pathname);
  if (!id) return errorEnvelope("DEVICE_VALIDATION", "device id is required", 422);
  const body = await readBody(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  const assignedTo = str(body, "assignedTo") || str(body, "staffId");
  if (!assignedTo) return errorEnvelope("DEVICE_VALIDATION", "assignedTo (staffId) is required", 422);

  const scope = scopeOf(auth.claims);
  const assignedBy = subjectOf(auth.claims);
  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const res = await assignDevice(db, scope, id, {
        assignedTo,
        assignedBy,
        note: str(body, "note") || null,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("devicemgmt.asset.assigned", "org_asset", id, {
          assignedTo,
          assignmentId: res.assignment.id,
          assetTag: res.asset.asset_tag,
        }),
        req,
      );
      return res;
    });
    return jsonResponse(
      envelope({
        asset: assetRowToApi(result.asset),
        assignment: assignmentRowToApi(result.assignment),
      }),
      { status: 200 },
    );
  } catch (error) {
    return mapError(error);
  }
}

export async function handleReturnDevice(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWriter(auth.claims);
  if (denied) return denied;

  const id = deviceIdFromPath(new URL(req.url).pathname);
  if (!id) return errorEnvelope("DEVICE_VALIDATION", "device id is required", 422);
  const body = (await readBody(req)) ?? {};

  const scope = scopeOf(auth.claims);
  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const res = await returnDevice(db, scope, id, {
        condition: str(body, "condition") || null,
        note: str(body, "note") || null,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("devicemgmt.asset.returned", "org_asset", id, {
          condition: res.assignment?.condition ?? null,
          assetTag: res.asset.asset_tag,
        }),
        req,
      );
      return res;
    });
    return jsonResponse(envelope({
      asset: assetRowToApi(result.asset),
      assignment: result.assignment ? assignmentRowToApi(result.assignment) : null,
    }));
  } catch (error) {
    return mapError(error);
  }
}

export async function handleRetireDevice(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWriter(auth.claims);
  if (denied) return denied;

  const id = deviceIdFromPath(new URL(req.url).pathname);
  if (!id) return errorEnvelope("DEVICE_VALIDATION", "device id is required", 422);
  const scope = scopeOf(auth.claims);
  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const asset = await retireDevice(db, scope, id);
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("devicemgmt.asset.retired", "org_asset", id, {
          assetTag: asset.asset_tag,
        }),
        req,
      );
      return asset;
    });
    return jsonResponse(envelope(assetRowToApi(row)));
  } catch (error) {
    return mapError(error);
  }
}

export async function handleMarkDeviceLost(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireWriter(auth.claims);
  if (denied) return denied;

  const id = deviceIdFromPath(new URL(req.url).pathname);
  if (!id) return errorEnvelope("DEVICE_VALIDATION", "device id is required", 422);
  const body = (await readBody(req)) ?? {};
  const scope = scopeOf(auth.claims);
  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const asset = await markDeviceLost(db, scope, id, {
        note: str(body, "note") || null,
        condition: str(body, "condition") || null,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit("devicemgmt.asset.lost", "org_asset", id, {
          assetTag: asset.asset_tag,
        }),
        req,
      );
      return asset;
    });
    return jsonResponse(envelope(assetRowToApi(row)));
  } catch (error) {
    return mapError(error);
  }
}
