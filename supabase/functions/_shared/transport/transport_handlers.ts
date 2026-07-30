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
  getEntityPayloadById,
  getOccupancyMetrics,
  getSnapshot,
  listEntities,
  listEntityPayloads,
  TransportSnapshotNotFoundError,
} from "./transport_read_repository.ts";
import { getMonthlyFuelTrend, getMonthToDateFuel } from "./transport_expenses_repository.ts";

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

/**
 * BUS-004/BUS-005 — the transport dashboard KPI set, computed from live rows.
 *
 * The defect this replaces: `snapshot_dashboard` was a static JSONB document
 * seeded ONCE by migration 20260614100000 and never recomputed by any code path
 * (grep for `mutateSnapshot` in this module returns zero write-side hits). A
 * demo/pilot school therefore saw permanently frozen figures — "18 Active
 * Buses", "94% On-Time", "842 Students Picked" — regardless of reality, while a
 * genuinely onboarded school got `{}` and read as permanent zeros. Both are
 * misinformation on the screen most likely to be shown to a principal.
 *
 * Two rules here, both from roadmap principle P-1:
 *   - a KPI backed by real rows shows a real count;
 *   - a KPI with NO data source yet shows `null` (rendered "—" + "not
 *     configured"), never a number and never a zero that reads as a measurement.
 *
 * BUS-005 specifically drops the fuel-cost KPI, whose seed carried the literal
 * annotation `"Finance integration placeholder"` while rendering as a live
 * money figure. It returns in BUS-121 once fuel logs exist.
 *
 * On-time / delay KPIs stay `null` until BUS-093 can compute schedule adherence
 * — impossible before BUS-038 makes stop times arithmetic-capable.
 */
export function buildDashboardKpis(counts: {
  activeVehicles: number;
  activeRoutes: number;
  allocatedStudents: number;
  unallocatedStudents: number | null;
}): Array<Record<string, unknown>> {
  const kpi = (
    id: string,
    label: string,
    value: number | null,
    accentName: string,
    notConfiguredHint?: string,
  ) => ({
    id,
    label,
    value: value === null ? null : String(value),
    accentName,
    ...(value === null ? { notConfigured: true, detail: notConfiguredHint } : {}),
  });

  return [
    kpi("active_buses", "Active Buses", counts.activeVehicles, "primary"),
    kpi("active_routes", "Active Routes", counts.activeRoutes, "primary"),
    kpi("allocated_students", "Students Allocated", counts.allocatedStudents, "success"),
    kpi(
      "unallocated_students",
      "Unallocated",
      counts.unallocatedStudents,
      "warning",
    ),
    // No adherence source yet — BUS-093 (blocked on BUS-038 typed stop times).
    kpi("on_time", "On-Time Rate", null, "neutral", "Available once trips run"),
    kpi("delayed", "Delayed Today", null, "neutral", "Available once trips run"),
    // No boarding source yet — BUS-102 (transport attendance has no student id
    // and no date, so a "students picked" count cannot be attributed or dated).
    kpi("picked", "Students Boarded", null, "neutral", "Available once trips run"),
    // BUS-005/BUS-121 — the fuel KPI is emitted as NOT-CONFIGURED here and
    // overlaid with the live month-to-date figure by withLiveFuelKpi below.
    //
    // Two lanes fixed the same defect independently: BUS-005 removed the
    // fabricated "₹84K — Finance integration placeholder" seed outright, while
    // the release lane built a real `transport_expenses` source. The release
    // lane's approach is strictly better — it satisfies BUS-005's requirement
    // (never a fabricated money figure) AND pre-delivers BUS-121 — so it wins.
    // The KPI must EXIST here for the overlay to have a target; without it the
    // live-fuel work is orphaned, which is how the merge left it.
    kpi("fuel", "Fuel Cost (MTD)", null, "neutral", "No fuel expense recorded"),
  ];
}

/** Format a rupee amount in the compact style the dashboard KPIs use (₹84K/₹1.2L).
 * Exported for unit testing. */
export function formatInr(n: number): string {
  if (n >= 100000) return `₹${(n / 100000).toFixed(1)}L`;
  if (n >= 1000) return `₹${Math.round(n / 1000)}K`;
  return `₹${Math.round(n)}`;
}

/**
 * Batch 8: overlay the LIVE month-to-date fuel spend onto the dashboard's `fuel`
 * KPI, replacing the static "₹84K — Finance integration placeholder" seed literal.
 * When nothing is recorded the KPI honestly reads ₹0 / "No fuel expense recorded"
 * — never a fabricated figure. All other KPIs pass through unchanged.
 */
export function withLiveFuelKpi(snapshot: unknown, mtdFuel: number): unknown {
  if (!snapshot || typeof snapshot !== "object") return snapshot;
  const snap = snapshot as Record<string, unknown>;
  const kpis = snap.kpis;
  if (!Array.isArray(kpis)) return snapshot;
  const updated = kpis.map((k) => {
    if (k && typeof k === "object" && (k as Record<string, unknown>).id === "fuel") {
      return {
        ...(k as Record<string, unknown>),
        value: formatInr(mtdFuel),
        detail: mtdFuel > 0
          ? "Live from transport expense ledger (MTD)"
          : "No fuel expense recorded (MTD)",
      };
    }
    return k;
  });
  return { ...snap, kpis: updated };
}

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireTransportRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const payload = await runTenant(config, auth.claims, async (db) => {
      const countOf = async (entityType: string, predicate?: (p: Record<string, unknown>) => boolean) => {
        const rows = await db.queryObject<{ payload: Record<string, unknown> }>(
          `SELECT payload FROM transport_entities
           WHERE organization_id = $1 AND school_id = $2 AND entity_type = $3`,
          [orgId, schoolId, entityType],
        );
        const payloads = rows.map((r) => r.payload);
        return predicate ? payloads.filter(predicate).length : payloads.length;
      };

      const activeVehicles = await countOf(
        "vehicle",
        (p) => String(p.status ?? "active") === "active",
      );
      const activeRoutes = await countOf(
        "route",
        (p) => String(p.status ?? "") === "active",
      );
      const allocatedStudents = await countOf(
        "allocation",
        (p) => String(p.routeId ?? "").length > 0,
      );
      const unallocatedStudents = await countOf(
        "allocation",
        (p) => String(p.routeId ?? "").length === 0,
      );

      // BUS-005/BUS-121: overlay the LIVE month-to-date fuel spend from
      // transport_expenses. Zero recorded spend renders "No fuel expense
      // recorded", never a figure — the KPI is honest in both directions.
      const mtdFuel = await getMonthToDateFuel(db, orgId, schoolId);
      const kpis = withLiveFuelKpi(
        {
          kpis: buildDashboardKpis({
            activeVehicles,
            activeRoutes,
            allocatedStudents,
            unallocatedStudents,
          }),
        },
        mtdFuel,
      );

      return {
        kpis: (kpis as { kpis: unknown }).kpis,
        // Everything below has no computable source yet. Emit EMPTY rather than
        // seeded fiction; the client renders a "not configured" affordance.
        vehicleAssignments: [],
        activeDelays: [],
        routePerformance: [],
        occupancy: {
          totalCapacity: 0,
          allocatedSeats: allocatedStudents,
          unassignedStudents: unallocatedStudents,
          utilizationPercent: 0,
        },
        aiInsight: "",
      };
    });
    return jsonResponse(envelope(payload));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof TransportSnapshotNotFoundError) {
      // Same empty-state contract as handleSnapshot: a freshly onboarded school
      // with no derived snapshot gets a clean empty payload, not a 404.
      return jsonResponse(envelope({}));
    }
    console.error("handleDashboard error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load transport dashboard", 500);
  }
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

/**
 * PRA-P0-20 — derive a per-allocation `demandRaised` flag by matching raised
 * transport `demand` entities to each allocation. A demand matches when it
 * carries the allocation's id, OR (the dedupe-key shape) the same sisStudentId +
 * routeId. Pure — exported for tests.
 */
export function annotateAllocationsWithDemand(
  allocations: Array<Record<string, unknown>>,
  demands: Array<Record<string, unknown>>,
): Array<Record<string, unknown>> {
  const byAllocationId = new Set<string>();
  const byStudentRoute = new Set<string>();
  for (const d of demands) {
    const allocationId = String(d.allocationId ?? "");
    if (allocationId.length > 0) byAllocationId.add(allocationId);
    const sisStudentId = String(d.sisStudentId ?? "");
    const routeId = String(d.routeId ?? "");
    if (sisStudentId.length > 0 && routeId.length > 0) {
      byStudentRoute.add(`${sisStudentId}::${routeId}`);
    }
  }
  return allocations.map((a) => {
    const allocationId = String(a.id ?? "");
    const sisStudentId = String(a.sisStudentId ?? "");
    const routeId = String(a.routeId ?? "");
    const demandRaised = (allocationId.length > 0 && byAllocationId.has(allocationId)) ||
      (sisStudentId.length > 0 && routeId.length > 0 &&
        byStudentRoute.has(`${sisStudentId}::${routeId}`));
    return { ...a, demandRaised };
  });
}

/**
 * GET /transport/allocations — list student allocations, each annotated with a
 * derived `demandRaised` (PRA-P0-20) so the client can surface per-row billed
 * status and offer to raise a demand for the unbilled. Same viewTransport gate
 * and pagination as the generic entity list.
 */
export async function handleAllocations(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireTransportRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const pagination = parsePagination(url);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await runTenant(config, auth.claims, async (db) => {
      const page = await listEntities(db, orgId, schoolId, "allocation", pagination);
      const demands = await listEntityPayloads(db, orgId, schoolId, "demand");
      return { ...page, items: annotateAllocationsWithDemand(page.items, demands) };
    });
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
    console.error("handleAllocations error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load transport allocations", 500);
  }
}

export async function handleAttendance(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "attendance", "Failed to load transport attendance");
}

export async function handleTracking(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_tracking", "Failed to load transport tracking");
}

/** Batch 8 slice 2: overlay the LIVE monthly fuel trend onto snapshot_reports,
 * replacing the static `fuelTrend` seed array. Other report sections pass through. */
export function withLiveFuelTrend(
  snapshot: unknown,
  trend: { label: string; amountLakhs: number; targetLakhs: null }[],
): unknown {
  if (!snapshot || typeof snapshot !== "object") return snapshot;
  return { ...(snapshot as Record<string, unknown>), fuelTrend: trend };
}

export async function handleReports(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireTransportRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const { snapshot, trend } = await runTenant(config, auth.claims, async (db) => {
      const snapshot = await getSnapshot(db, orgId, schoolId, "snapshot_reports");
      const trend = await getMonthlyFuelTrend(db, orgId, schoolId);
      return { snapshot, trend };
    });
    return jsonResponse(envelope(withLiveFuelTrend(snapshot, trend)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof TransportSnapshotNotFoundError) return jsonResponse(envelope({}));
    console.error("handleReports error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load transport reports", 500);
  }
}

export async function handleSettings(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_settings", "Failed to load transport settings");
}

export async function handleOccupancyMetrics(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireTransportRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    // Batch 8 slice 2: LIVE occupancy from vehicles/allocations/routes, replacing
    // the static snapshot_occupancy literal. A school with no fleet yields an
    // honest all-zero payload — never the fabricated 88% / 860-seat seed.
    const metrics = await runTenant(config, auth.claims, (db) =>
      getOccupancyMetrics(db, orgId, schoolId));
    return jsonResponse(envelope(metrics));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    console.error("handleOccupancyMetrics error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load occupancy metrics", 500);
  }
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
      const route = await getEntityPayloadById(db, orgId, schoolId, "route", routeId);
      if (!route) {
        throw new TransportSnapshotNotFoundError("route");
      }

      const allocations = (await listEntityPayloads(db, orgId, schoolId, "allocation"))
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
