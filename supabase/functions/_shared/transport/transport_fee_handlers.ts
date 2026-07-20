// W4 (Owner decisions #2 + #3) — HTTP handlers for the HYBRID transport fee model.
//
// Self-contained: reads use the direct auth+tenant pattern (viewTransport);
// writes reuse createModuleWriteHandlers("manageTransport") — the SAME RBAC the
// rest of transport uses (no new permission slug). Wired by transport_fee_router.ts,
// which the parent mounts; nothing here touches api/app.ts.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import {
  createModuleWriteHandlers,
  requireStr,
  str,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  getFeeConfig,
  getFeeRate,
  getStudentTransport,
  resolveTransportFee,
  upsertFeeConfig,
  upsertFeeRate,
  upsertStudentTransport,
} from "./transport_fee_config_repository.ts";
import {
  isTransportFeeModel,
  isTransportRequirement,
  TRANSPORT_FEE_MODELS,
  type TransportFeeModel,
  TRANSPORT_REQUIREMENTS,
  type TransportRequirement,
} from "./transport_fee_model.ts";

const { runWrite } = createModuleWriteHandlers("manageTransport");

// ── validation helpers ────────────────────────────────────────────────────────

/** Read a non-negative money field: absent/null → null; present → validated rupees. */
function optRupees(body: Record<string, unknown>, ...keys: string[]): number | null {
  for (const key of keys) {
    if (key in body) {
      const raw = body[key];
      if (raw === null || raw === "") return null;
      const n = Number(raw);
      if (!Number.isFinite(n) || n < 0) {
        throw new WriteValidationError(`${key} must be a non-negative number`);
      }
      if (n > 1_000_000_000_000) {
        throw new WriteValidationError(`${key} is out of the allowed range`);
      }
      return n;
    }
  }
  return null;
}

function requireModel(body: Record<string, unknown>): TransportFeeModel {
  const raw = requireStr(body, "feeModel", "fee_model");
  if (!isTransportFeeModel(raw)) {
    throw new WriteValidationError(
      `feeModel must be one of: ${TRANSPORT_FEE_MODELS.join(", ")}`,
    );
  }
  return raw;
}

function readRequirement(body: Record<string, unknown>): TransportRequirement {
  const raw = str(body, "requirement");
  if (raw === undefined) return "bus";
  if (!isTransportRequirement(raw)) {
    throw new WriteValidationError(
      `requirement must be one of: ${TRANSPORT_REQUIREMENTS.join(", ")}`,
    );
  }
  return raw;
}

function readDistanceSource(body: Record<string, unknown>): "route" | "stop" {
  const raw = str(body, "distanceSource", "distance_source");
  if (raw === undefined) return "route";
  if (raw !== "route" && raw !== "stop") {
    throw new WriteValidationError(`distanceSource must be 'route' or 'stop'`);
  }
  return raw;
}

// ── read plumbing (viewTransport) ─────────────────────────────────────────────

async function runTransportRead(
  req: Request,
  config: AppConfig,
  operation: (
    db: Parameters<Parameters<typeof withTenantContext>[2]>[0],
    orgId: string,
    schoolId: string,
  ) => Promise<Record<string, unknown>>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewTransport") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  try {
    const payload = await withTenantContext(config, auth.claims, (db) => operation(db, orgId, schoolId));
    return jsonResponse(envelope(payload), { status: 200 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof WriteValidationError) {
      return errorEnvelope(error.code, error.message, error.status);
    }
    console.error("[viewTransport] fee read error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Read operation failed", 500);
  }
}

// ── fee-config: GET / PUT ──────────────────────────────────────────────────────

/** GET /transport/fee-config — the school's chosen model + rate inputs. */
export function handleGetFeeConfig(req: Request, config: AppConfig): Promise<Response> {
  return runTransportRead(req, config, async (db, orgId, schoolId) => {
    const cfg = await getFeeConfig(db, orgId, schoolId);
    return cfg ? { configured: true, ...cfg } : { configured: false };
  });
}

/** PUT /transport/fee-config — set/replace the school's fee model (owner #2). */
export function handlePutFeeConfig(req: Request, config: AppConfig): Promise<Response> {
  return runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const saved = await upsertFeeConfig(db, organizationId, schoolId, {
      feeModel: requireModel(body),
      ratePerKm: optRupees(body, "ratePerKm", "rate_per_km"),
      distanceSource: readDistanceSource(body),
      flatAmount: optRupees(body, "flatAmount", "flat_amount"),
      defaultRouteAmount: optRupees(body, "defaultRouteAmount", "default_route_amount"),
      defaultStopAmount: optRupees(body, "defaultStopAmount", "default_stop_amount"),
      updatedBy: claims.sub ?? null,
    });
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.feeConfig.updated", "transport_fee_config", schoolId, {
        feeModel: saved.feeModel,
      }),
      request,
    );
    return { payload: { configured: true, ...saved }, status: 200 };
  });
}

// ── per-route / per-stop rate: GET / PUT ──────────────────────────────────────

function requireScope(raw: string): "route" | "stop" {
  if (raw !== "route" && raw !== "stop") {
    throw new WriteValidationError(`scope must be 'route' or 'stop'`);
  }
  return raw;
}

/** GET /transport/fee-rates/{scope}/{entityId}. */
export function handleGetFeeRate(
  req: Request,
  config: AppConfig,
  scope: string,
  entityId: string,
): Promise<Response> {
  return runTransportRead(req, config, async (db, orgId, schoolId) => {
    const rate = await getFeeRate(db, orgId, schoolId, requireScope(scope), entityId);
    return rate ? { found: true, ...rate } : { found: false, scope, entityId };
  });
}

/** PUT /transport/fee-rates/{scope}/{entityId} — per-route/per-stop amount + distance. */
export function handlePutFeeRate(
  req: Request,
  config: AppConfig,
  scope: string,
  entityId: string,
): Promise<Response> {
  return runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const scopeVal = requireScope(scope);
    if (!entityId) throw new WriteValidationError("entityId is required");
    const saved = await upsertFeeRate(db, organizationId, schoolId, {
      scope: scopeVal,
      entityId,
      amount: optRupees(body, "amount"),
      distanceKm: optRupees(body, "distanceKm", "distance_km"),
      updatedBy: claims.sub ?? null,
    });
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.feeRate.updated", "transport_fee_rate", `${scopeVal}:${entityId}`, {
        scope: scopeVal,
        entityId,
      }),
      request,
    );
    return { payload: { found: true, ...saved }, status: 200 };
  });
}

// ── per-student requirement + override: GET / PUT (owner #3) ───────────────────

/** GET /transport/students/{sisStudentId}/transport. */
export function handleGetStudentTransport(
  req: Request,
  config: AppConfig,
  sisStudentId: string,
): Promise<Response> {
  return runTransportRead(req, config, async (db, orgId, schoolId) => {
    const row = await getStudentTransport(db, orgId, schoolId, sisStudentId);
    // Default view for a student with no explicit row: rides the bus, no override.
    return row
      ? { sisStudentId: row.sisStudentId, requirement: row.requirement, feeOverride: row.feeOverride }
      : { sisStudentId, requirement: "bus", feeOverride: null };
  });
}

/** PUT /transport/students/{sisStudentId}/transport — requirement + fee override. */
export function handlePutStudentTransport(
  req: Request,
  config: AppConfig,
  sisStudentId: string,
): Promise<Response> {
  return runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    if (!sisStudentId) throw new WriteValidationError("sisStudentId is required");
    const saved = await upsertStudentTransport(db, organizationId, schoolId, {
      sisStudentId,
      requirement: readRequirement(body),
      // Nullable: absent/null clears the override (fall back to the model / ₹0).
      feeOverride: optRupees(body, "feeOverride", "fee_override"),
      updatedBy: claims.sub ?? null,
    });
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit(
        "transport.studentTransport.updated",
        "transport_student_transport",
        sisStudentId,
        { requirement: saved.requirement, overrideSet: saved.feeOverride !== null },
      ),
      request,
    );
    return {
      payload: {
        sisStudentId: saved.sisStudentId,
        requirement: saved.requirement,
        feeOverride: saved.feeOverride,
      },
      status: 200,
    };
  });
}

// ── fee preview (compute for one student) ─────────────────────────────────────

/**
 * GET /transport/fee-preview?sisStudentId=&routeId=&pickupStop=&distanceKm=
 * Resolves the payable off the live config/requirement/override — what the UI
 * shows before raising a demand. Returns hybridActive:false when nothing hybrid
 * applies (a plain 'bus' student and no fee-config → legacy fee-structure billing).
 */
export function handleFeePreview(req: Request, config: AppConfig): Promise<Response> {
  const url = new URL(req.url);
  const sisStudentId = url.searchParams.get("sisStudentId") ?? url.searchParams.get("sis_student_id") ?? "";
  const routeId = url.searchParams.get("routeId") ?? url.searchParams.get("route_id");
  const pickupStop = url.searchParams.get("pickupStop") ?? url.searchParams.get("pickup_stop");
  const distanceRaw = url.searchParams.get("distanceKm") ?? url.searchParams.get("distance_km");
  const routeDistanceKm = distanceRaw != null && Number.isFinite(Number(distanceRaw))
    ? Number(distanceRaw)
    : null;
  return runTransportRead(req, config, async (db, orgId, schoolId) => {
    if (!sisStudentId) throw new WriteValidationError("sisStudentId is required");
    const resolved = await resolveTransportFee(db, orgId, schoolId, {
      sisStudentId,
      routeId,
      pickupStop,
      routeDistanceKm,
    });
    if (!resolved) return { hybridActive: false, sisStudentId };
    return { hybridActive: true, sisStudentId, ...resolved };
  });
}
