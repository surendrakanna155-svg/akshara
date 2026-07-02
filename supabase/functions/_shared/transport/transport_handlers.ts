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
import { listEnvelope } from "../finance/finance_mapper.ts";
import {
  getSnapshot,
  listEntities,
  TransportSnapshotNotFoundError,
} from "./transport_read_repository.ts";

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function requireTransportRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewTransport") ??
    requireSchoolOperationalScope(claims);
}

async function handleSnapshot(
  req: Request,
  config: AppConfig,
  entityType: string,
  notFoundMessage: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireTransportRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const snapshot = await runTenant(config, auth.claims, async (db) =>
      await getSnapshot(db, orgId, schoolId, entityType)
    );
    return jsonResponse(envelope(snapshot));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof TransportSnapshotNotFoundError) {
      // Empty-state contract: a school that has enabled Transport but not yet
      // generated its derived snapshot (e.g. freshly onboarded, no routes/buses)
      // gets a clean empty payload — never a 404. The null-tolerant client mapper
      // renders this as a zero-state dashboard instead of an error screen.
      return jsonResponse(envelope({}));
    }
    console.error(`handleSnapshot(${entityType}) error:`, error);
    return errorEnvelope("INTERNAL_ERROR", notFoundMessage, 500);
  }
}

async function handleList(
  req: Request,
  config: AppConfig,
  entityType: string,
  errorMessage: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireTransportRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) =>
      await listEntities(db, orgId, schoolId, entityType, pagination)
    );
    return jsonResponse(
      envelope(
        listEnvelope(result.items, {
          page: result.page,
          pageSize: result.pageSize,
          total: result.total,
          hasMore: result.hasMore,
        }),
      ),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error(`handleList(${entityType}) error:`, error);
    return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
  }
}

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_dashboard", "Failed to load transport dashboard");
}

export async function handleRoutes(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "route", "Failed to load transport routes");
}

export async function handleVehicles(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "vehicle", "Failed to load transport vehicles");
}

export async function handleDrivers(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "driver", "Failed to load transport drivers");
}

export async function handleAllocations(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "allocation", "Failed to load transport allocations");
}

export async function handleAttendance(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "attendance", "Failed to load transport attendance");
}

export async function handleTracking(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_tracking", "Failed to load transport tracking");
}

export async function handleReports(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_reports", "Failed to load transport reports");
}

export async function handleSettings(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_settings", "Failed to load transport settings");
}

export async function handleOccupancyMetrics(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_occupancy", "Failed to load occupancy metrics");
}

/** Extracts the `{id}` path segment for /transport/routes/{id}/roster. */
function rosterRouteId(req: Request): string | undefined {
  const segments = new URL(req.url).pathname.split("/").filter((s) => s.length > 0);
  return segments[2];
}

/**
 * TRN-3 — GET /transport/routes/{id}/roster. Aggregates the route's allocation
 * rows grouped BY pickup stop, each student carrying name/class/stop, ordered by
 * the route's own stop `sequence`. Read-only (viewTransport). CSV/PDF export is
 * the client's job (XCT-1) — this returns the structured roster.
 */
export async function handleRouteRoster(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireTransportRead(auth.claims);
  if (denied) return denied;

  const routeId = rosterRouteId(req);
  if (!routeId) {
    return errorEnvelope("VALIDATION_ERROR", "Route id is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const roster = await runTenant(config, auth.claims, async (db) => {
      const routeRows = await db.queryObject<{ payload: Record<string, unknown> }>(
        `SELECT payload FROM transport_entities
         WHERE organization_id = $1 AND school_id = $2 AND entity_type = 'route' AND id = $3`,
        [orgId, schoolId, routeId],
      );
      const route = routeRows[0]?.payload ?? null;
      if (!route) {
        throw new TransportSnapshotNotFoundError("route");
      }

      const allocRows = await db.queryObject<{ payload: Record<string, unknown> }>(
        `SELECT payload FROM transport_entities
         WHERE organization_id = $1 AND school_id = $2 AND entity_type = 'allocation'`,
        [orgId, schoolId],
      );
      const allocations = allocRows
        .map((r) => r.payload)
        .filter((a) => String(a.routeId ?? "") === routeId);

      return buildRoster(route, allocations);
    });
    return jsonResponse(envelope(roster));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof TransportSnapshotNotFoundError) {
      return errorEnvelope("NOT_FOUND", `Transport route not found: ${routeId}`, 404);
    }
    console.error("handleRouteRoster error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load transport roster", 500);
  }
}

/**
 * Groups a route's allocations by pickup stop, ordered by the route's stop
 * `sequence` (stops absent from the route definition sort last, alphabetically).
 * Pure — unit-tested directly.
 */
export function buildRoster(
  route: Record<string, unknown>,
  allocations: Array<Record<string, unknown>>,
): Record<string, unknown> {
  const stops = Array.isArray(route.stops)
    ? (route.stops as Array<Record<string, unknown>>)
    : [];
  const seqByStopName = new Map<string, number>();
  for (const s of stops) {
    const name = String(s.name ?? "").trim();
    if (name) seqByStopName.set(name, Number(s.sequence ?? Number.MAX_SAFE_INTEGER));
  }

  const groups = new Map<string, Array<Record<string, unknown>>>();
  for (const a of allocations) {
    const stopName = String(a.pickupStop ?? "").trim() || "(unassigned stop)";
    const student = {
      sisStudentId: a.sisStudentId ?? "",
      studentName: a.studentName ?? "",
      classLabel: a.classLabel ?? "",
      stop: stopName,
    };
    const list = groups.get(stopName) ?? [];
    list.push(student);
    groups.set(stopName, list);
  }

  const orderedGroups = [...groups.entries()]
    .map(([stop, students]) => ({
      stop,
      sequence: seqByStopName.get(stop) ?? Number.MAX_SAFE_INTEGER,
      students: students.sort((x, y) =>
        String(x.studentName).localeCompare(String(y.studentName))
      ),
    }))
    .sort((a, b) => a.sequence - b.sequence || a.stop.localeCompare(b.stop));

  return {
    routeId: route.id ?? "",
    routeName: route.name ?? "",
    stopCount: stops.length,
    studentCount: allocations.length,
    stops: orderedGroups,
  };
}
