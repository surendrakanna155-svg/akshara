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

/**
 * Transport v2 READ handlers.
 *
 * WHY THIS FILE EXISTS AS A GAP-FIX
 *
 * The v2 write surface (routes, stops, assignment, substitution) shipped before
 * its reads did, and the v2 router had no GET branch at all — so the Flutter
 * client's `fetchRoutes`/`fetchStops` had nothing to route to. That was a real
 * defect introduced by building the client against endpoints that did not yet
 * exist, which is the same class of mistake the audit found throughout the
 * legacy module (a field read by three subsystems and written by none).
 *
 * Every read here:
 *   * resolves the DATED assignment for a requested service date, so "who drives
 *     Route 12 today" and "who drives it tomorrow" are different answers from
 *     the same endpoint (roadmap P-3);
 *   * counts derived values in SQL rather than fetching rows to measure them;
 *   * returns compliance state alongside vehicles/drivers so a picker can warn
 *     BEFORE the assignment gate refuses (BUS-054).
 */

function requireTransportRead(claims: Parameters<typeof requirePermission>[0]) {
  return requirePermission(claims, "viewTransport") ??
    requireSchoolOperationalScope(claims);
}

/** Reads `serviceDate` from the query string, defaulting to today (UTC). */
function serviceDateFrom(req: Request): string {
  const raw = new URL(req.url).searchParams.get("serviceDate") ?? "";
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;
  return new Date().toISOString().slice(0, 10);
}

function pathSegment(req: Request, index: number): string | undefined {
  return new URL(req.url).pathname.split("/").filter((s) => s.length > 0)[index];
}

async function readScope<T>(
  req: Request,
  config: AppConfig,
  run: (
    db: Parameters<Parameters<typeof withTenantContext<T>>[2]>[0],
    orgId: string,
    schoolId: string,
  ) => Promise<T>,
  errorMessage: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTransportRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  try {
    const payload = await withTenantContext(
      config,
      auth.claims,
      async (db) => await run(db, orgId, schoolId!),
    );
    return jsonResponse(envelope(payload as Record<string, unknown>));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error(`${errorMessage}:`, error);
    return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
  }
}

/**
 * The route projection the client consumes. Stops, the effective assignment and
 * the student count all come back in ONE query set, because a route is useless
 * to the admin UI without them and N+1 round-trips per route is exactly the
 * access pattern BUS-032 removed.
 */
const ROUTE_SELECT = `
  SELECT r.id, r.name, r.code, r.direction, r.shift, r.status,
         to_char(r.default_departure_time, 'HH24:MI') AS "defaultDepartureTime",
         to_char(r.default_return_time, 'HH24:MI') AS "defaultReturnTime",
         r.distance_m AS "distanceM",
         (SELECT count(*) FROM transport_allocation a
           WHERE a.route_id = r.id AND a.status = 'active')::int AS "studentCount",
         COALESCE((
           SELECT jsonb_agg(stop ORDER BY (stop ->> 'sequence')::int)
           FROM (
             SELECT jsonb_build_object(
               'id', s.id,
               'name', s.name,
               'sequence', rs.sequence,
               'status', s.status,
               'geofenceRadiusM', s.geofence_radius_m,
               'addressText', s.address_text,
               'landmark', s.landmark,
               'latitude', CASE WHEN s.location IS NULL THEN NULL
                                ELSE ST_Y(s.location::geometry) END,
               'longitude', CASE WHEN s.location IS NULL THEN NULL
                                 ELSE ST_X(s.location::geometry) END,
               'pickupTime', to_char(rs.scheduled_pickup_time, 'HH24:MI'),
               'dropTime', to_char(rs.scheduled_drop_time, 'HH24:MI'),
               'dwellSeconds', rs.dwell_seconds
             ) AS stop
             FROM transport_route_stop rs
             JOIN transport_stop s ON s.id = rs.stop_id
             WHERE rs.route_id = r.id
           ) stops
         ), '[]'::jsonb) AS stops,
         CASE WHEN asg.id IS NULL THEN NULL ELSE jsonb_build_object(
           'assignmentId', asg.id,
           'vehicleId', asg.vehicle_id,
           'vehicleRegistration', v.registration,
           'driverId', asg.driver_id,
           'driverName', d.name,
           'attendantId', asg.attendant_id,
           'attendantName', att.name,
           'assignmentKind', asg.assignment_kind,
           'effectiveFrom', asg.effective_from::text,
           'effectiveTo', asg.effective_to::text,
           'reason', asg.reason
         ) END AS assignment
  FROM transport_route r
  LEFT JOIN LATERAL (
    SELECT * FROM transport_effective_assignment(r.id, $3::date)
  ) asg ON true
  LEFT JOIN transport_vehicle v ON v.id = asg.vehicle_id
  LEFT JOIN transport_driver d ON d.id = asg.driver_id
  LEFT JOIN transport_driver att ON att.id = asg.attendant_id
  WHERE r.organization_id = $1 AND r.school_id = $2
`;

/** GET /transport/v2/routes?serviceDate=YYYY-MM-DD */
export async function handleListRoutesV2(req: Request, config: AppConfig) {
  const date = serviceDateFrom(req);
  return await readScope(
    req,
    config,
    async (db, orgId, schoolId) => {
      const rows = await db.queryObject<Record<string, unknown>>(
        `${ROUTE_SELECT} ORDER BY r.shift, r.name`,
        [orgId, schoolId, date],
      );
      return { items: rows, serviceDate: date };
    },
    "Failed to load transport routes",
  );
}

/** GET /transport/v2/routes/{id}?serviceDate=… */
export async function handleGetRouteV2(req: Request, config: AppConfig) {
  const date = serviceDateFrom(req);
  const routeId = pathSegment(req, 3);
  if (!routeId) {
    return errorEnvelope("VALIDATION_ERROR", "Route id is required", 422);
  }
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTransportRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<Record<string, unknown>>(
        `${ROUTE_SELECT} AND r.id = $4::uuid`,
        [orgId, schoolId, date, routeId],
      );
      return rows[0] ?? null;
    });
    if (!row) {
      return errorEnvelope("NOT_FOUND", `Transport route not found: ${routeId}`, 404);
    }
    return jsonResponse(envelope(row));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("handleGetRouteV2:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load transport route", 500);
  }
}

/** GET /transport/v2/stops — school-owned stops, unlocated ones FIRST. */
export async function handleListStopsV2(req: Request, config: AppConfig) {
  return await readScope(
    req,
    config,
    async (db, orgId, schoolId) => {
      const rows = await db.queryObject<Record<string, unknown>>(
        `SELECT s.id, s.name, s.status,
                s.geofence_radius_m AS "geofenceRadiusM",
                s.address_text AS "addressText",
                s.landmark,
                CASE WHEN s.location IS NULL THEN NULL
                     ELSE ST_Y(s.location::geometry) END AS latitude,
                CASE WHEN s.location IS NULL THEN NULL
                     ELSE ST_X(s.location::geometry) END AS longitude,
                (SELECT count(*) FROM transport_route_stop rs
                  WHERE rs.stop_id = s.id)::int AS "routeCount"
         FROM transport_stop s
         WHERE s.organization_id = $1 AND s.school_id = $2
           AND s.status <> 'retired'
         -- Unlocated first: BUS-030 migration debt is work-to-do, and an admin
         -- should not have to hunt for it.
         ORDER BY (s.status = 'needs_location') DESC, s.name`,
        [orgId, schoolId],
      );
      return { items: rows };
    },
    "Failed to load transport stops",
  );
}

/**
 * GET /transport/v2/vehicles?serviceDate=…
 *
 * Returns compliance state and current commitment so the assignment picker can
 * warn BEFORE the BUS-054 gate refuses. A picker that offers an uninsured bus
 * and only fails on submit wastes the admin's time and teaches them to ignore
 * the error.
 */
export async function handleListVehiclesV2(req: Request, config: AppConfig) {
  const date = serviceDateFrom(req);
  return await readScope(
    req,
    config,
    async (db, orgId, schoolId) => {
      const rows = await db.queryObject<Record<string, unknown>>(
        `SELECT v.id, v.registration, v.model, v.capacity, v.status,
                v.insurance_expiry::text AS "insuranceExpiry",
                v.fitness_expiry::text AS "fitnessExpiry",
                v.permit_expiry::text AS "permitExpiry",
                -- Which statutory document is expired ON the queried date.
                CASE
                  WHEN v.insurance_expiry IS NOT NULL AND v.insurance_expiry < $3::date THEN 'insurance'
                  WHEN v.fitness_expiry  IS NOT NULL AND v.fitness_expiry  < $3::date THEN 'fitness'
                  WHEN v.permit_expiry   IS NOT NULL AND v.permit_expiry   < $3::date THEN 'permit'
                END AS "expiredDocument",
                (SELECT r.name FROM transport_assignment a
                   JOIN transport_route r ON r.id = a.route_id
                  WHERE a.vehicle_id = v.id
                    AND a.effective_from <= $3::date
                    AND (a.effective_to IS NULL OR a.effective_to >= $3::date)
                  LIMIT 1) AS "assignedRouteName"
         FROM transport_vehicle v
         WHERE v.organization_id = $1 AND v.school_id = $2
           AND v.status <> 'retired'
         ORDER BY v.registration`,
        [orgId, schoolId, date],
      );
      return { items: rows, serviceDate: date };
    },
    "Failed to load transport vehicles",
  );
}

/**
 * GET /transport/v2/drivers?serviceDate=…
 *
 * Same principle: licence expiry, leave, and current commitment are returned so
 * the substitute picker can show who is genuinely available. Offering a driver
 * who is on leave is how a school "arranges cover" and still has no driver.
 */
export async function handleListDriversV2(req: Request, config: AppConfig) {
  const date = serviceDateFrom(req);
  return await readScope(
    req,
    config,
    async (db, orgId, schoolId) => {
      const rows = await db.queryObject<Record<string, unknown>>(
        `SELECT d.id, d.name, d.phone, d.status,
                d.licence_number AS "licenceNumber",
                d.licence_expiry::text AS "licenceExpiry",
                COALESCE(d.licence_expiry < $3::date, false) AS "licenceExpired",
                -- On leave on the queried date?
                (SELECT av.kind FROM transport_driver_availability av
                  WHERE av.driver_id = d.id
                    AND $3::date BETWEEN av.from_date AND av.to_date
                  LIMIT 1) AS "unavailableKind",
                (SELECT r.name FROM transport_assignment a
                   JOIN transport_route r ON r.id = a.route_id
                  WHERE (a.driver_id = d.id OR a.attendant_id = d.id)
                    AND a.effective_from <= $3::date
                    AND (a.effective_to IS NULL OR a.effective_to >= $3::date)
                  LIMIT 1) AS "assignedRouteName"
         FROM transport_driver d
         WHERE d.organization_id = $1 AND d.school_id = $2
           AND d.status <> 'inactive'
         ORDER BY d.name`,
        [orgId, schoolId, date],
      );
      return { items: rows, serviceDate: date };
    },
    "Failed to load transport drivers",
  );
}
