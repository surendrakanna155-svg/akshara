import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * BUS-032 — typed Transport v2 repository.
 *
 * REPLACES the entity-store access pattern, whose defining flaw was that every
 * write path called `findAll('allocation')` — loading EVERY allocation payload
 * in the school into Deno memory — on every assign, every bulk operation, every
 * delay notification and every roster read. Capacity checking was O(all students
 * in school) per single assignment. That degrades badly at 100 buses and is not
 * viable at 1,000.
 *
 * RULES FOR THIS FILE (enforced by transport_v2_repository_test.ts):
 *   1. No function may fetch an unbounded collection. Every read is either
 *      keyed, predicate-filtered, or explicitly paginated.
 *   2. Counts are done in SQL (`count(*)`), never by fetching rows and calling
 *      `.length` — the exact anti-pattern behind the O(n) capacity check.
 *   3. Row-locked read-modify-write (`SELECT … FOR UPDATE`) is PRESERVED where
 *      the pre-v2 code used it. That discipline was correct and understood lost
 *      updates; only the storage beneath it changes (P-10).
 *   4. Tenant scoping is passed explicitly on every call. RLS is the backstop,
 *      not the only guard.
 */

export interface TenantScope {
  organizationId: string;
  schoolId: string;
}

// ─── Assignment resolution (BUS-022 / BUS-051) ───────────────────────────────

export interface EffectiveAssignment {
  id: string;
  route_id: string;
  vehicle_id: string | null;
  driver_id: string | null;
  attendant_id: string | null;
  assignment_kind: "permanent" | "substitute";
  effective_from: string;
  effective_to: string | null;
}

/**
 * Who drives/attends route R on date D, honouring substitute precedence.
 *
 * Delegates to the `transport_effective_assignment` SQL function so the
 * precedence rule lives in exactly ONE place. Duplicating it in TypeScript is
 * how the two sides of a rule drift — which is the shape of nearly every defect
 * the audit found.
 */
export async function effectiveAssignment(
  db: TenantQueryClient,
  scope: TenantScope,
  routeId: string,
  serviceDate: string,
): Promise<EffectiveAssignment | null> {
  const rows = await db.queryObject<EffectiveAssignment>(
    `SELECT (transport_effective_assignment($1::uuid, $2::date)).*
     WHERE EXISTS (
       SELECT 1 FROM transport_route r
       WHERE r.id = $1::uuid
         AND r.organization_id = $3 AND r.school_id = $4
     )`,
    [routeId, serviceDate, scope.organizationId, scope.schoolId],
  );
  const row = rows[0];
  return row && row.id ? row : null;
}

/**
 * BUS-050 — routes with no resolvable crew on a date.
 *
 * Surfaced on the dashboard so an admin arranges a substitute BEFORE 6 a.m.,
 * rather than the school discovering the gap when a bus fails to arrive.
 */
export async function unstaffedRoutes(
  db: TenantQueryClient,
  scope: TenantScope,
  serviceDate: string,
): Promise<Array<{ route_id: string; route_name: string; missing: string }>> {
  return await db.queryObject(
    `SELECT r.id AS route_id,
            r.name AS route_name,
            CASE
              WHEN a.id IS NULL THEN 'no_assignment'
              WHEN a.driver_id IS NULL THEN 'no_driver'
              WHEN a.vehicle_id IS NULL THEN 'no_vehicle'
              WHEN av.driver_id IS NOT NULL THEN 'driver_unavailable'
            END AS missing
     FROM transport_route r
     LEFT JOIN LATERAL (
       SELECT * FROM transport_effective_assignment(r.id, $3::date)
     ) a ON true
     LEFT JOIN transport_driver_availability av
       ON av.driver_id = a.driver_id
      AND $3::date BETWEEN av.from_date AND av.to_date
     WHERE r.organization_id = $1 AND r.school_id = $2
       AND r.status = 'active'
       AND (a.id IS NULL OR a.driver_id IS NULL OR a.vehicle_id IS NULL
            OR av.driver_id IS NOT NULL)
     ORDER BY r.name`,
    [scope.organizationId, scope.schoolId, serviceDate],
  );
}

// ─── Capacity (BUS-044) ──────────────────────────────────────────────────────

export interface RouteCapacity {
  routeName: string;
  capacity: number | null;
  current: number;
}

/**
 * BUS-044 — resolve a route's capacity and current occupancy for a date.
 *
 * The pre-v2 version resolved capacity from `route.assignedBus`, a field no
 * endpoint ever wrote, so capacity was ALWAYS null and the guard ALWAYS
 * returned early — meaning unlimited over-allocation of a 48-seat bus. Capacity
 * now comes from the effective assignment's vehicle (BUS-043), so the guard is
 * finally reachable.
 *
 * `current` is a SQL `count(*)`, not `rows.length` — rule 2.
 *
 * Call under the route row lock (see {@link lockRoute}) so the count is a
 * consistent snapshot and a concurrent assign cannot over-fill the vehicle.
 * That locking discipline is carried over verbatim from the pre-v2 TRN-7
 * implementation, which was genuinely well-engineered.
 */
export async function routeCapacity(
  db: TenantQueryClient,
  scope: TenantScope,
  routeId: string,
  serviceDate: string,
): Promise<RouteCapacity | null> {
  const rows = await db.queryObject<{
    route_name: string;
    capacity: number | null;
    current: string;
  }>(
    `SELECT r.name AS route_name,
            v.capacity,
            (SELECT count(*) FROM transport_allocation al
              WHERE al.route_id = r.id AND al.status = 'active')::text AS current
     FROM transport_route r
     LEFT JOIN LATERAL (
       SELECT * FROM transport_effective_assignment(r.id, $3::date)
     ) a ON true
     LEFT JOIN transport_vehicle v ON v.id = a.vehicle_id
     WHERE r.id = $4::uuid
       AND r.organization_id = $1 AND r.school_id = $2`,
    [scope.organizationId, scope.schoolId, serviceDate, routeId],
  );
  const row = rows[0];
  if (!row) return null;
  const cap = row.capacity;
  return {
    routeName: row.route_name,
    capacity: cap !== null && cap > 0 ? cap : null,
    current: parseInt(row.current, 10),
  };
}

/** Takes the route row lock, held to commit. Preserves the TRN-7 discipline. */
export async function lockRoute(
  db: TenantQueryClient,
  scope: TenantScope,
  routeId: string,
): Promise<boolean> {
  const rows = await db.queryObject<{ id: string }>(
    `SELECT id FROM transport_route
     WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3
     FOR UPDATE`,
    [routeId, scope.organizationId, scope.schoolId],
  );
  return rows.length > 0;
}

// ─── Parent single-child read (BUS-059) ──────────────────────────────────────

export interface ChildAllocation {
  allocation_id: string;
  route_id: string;
  route_name: string;
  pickup_stop_name: string;
  drop_stop_name: string;
  scheduled_pickup_time: string | null;
  scheduled_drop_time: string | null;
  shift: string;
  vehicle_registration: string | null;
  driver_name: string | null;
}

/**
 * BUS-059 — ONE child's allocation. There is deliberately no list form.
 *
 * The pre-v2 parent path fetched the school's allocation list (page 1, size 20)
 * and scanned it client-side. Three simultaneous failures: it 403'd in the live
 * build, it would have leaked other children's names / admission numbers /
 * PICKUP STOP LOCATIONS to the device, and it found the right child for only
 * ~2.5% of parents in an 800-student school.
 *
 * This is a single indexed lookup on `transport_allocation_by_student`, and RLS
 * (`transport_allocation_parent_read`) independently guarantees a parent cannot
 * read another family's row even if this query were called with a foreign id.
 */
export async function childAllocation(
  db: TenantQueryClient,
  scope: TenantScope,
  studentId: string,
  serviceDate: string,
): Promise<ChildAllocation | null> {
  const rows = await db.queryObject<ChildAllocation>(
    `SELECT a.id AS allocation_id,
            r.id AS route_id,
            r.name AS route_name,
            ps.name AS pickup_stop_name,
            ds.name AS drop_stop_name,
            rs_pick.scheduled_pickup_time,
            rs_drop.scheduled_drop_time,
            a.shift,
            v.registration AS vehicle_registration,
            d.name AS driver_name
     FROM transport_allocation a
     JOIN transport_route r ON r.id = a.route_id
     JOIN transport_stop ps ON ps.id = a.pickup_stop_id
     JOIN transport_stop ds ON ds.id = a.drop_stop_id
     LEFT JOIN transport_route_stop rs_pick
       ON rs_pick.route_id = r.id AND rs_pick.stop_id = ps.id
     LEFT JOIN transport_route_stop rs_drop
       ON rs_drop.route_id = r.id AND rs_drop.stop_id = ds.id
     LEFT JOIN LATERAL (
       SELECT * FROM transport_effective_assignment(r.id, $4::date)
     ) asg ON true
     LEFT JOIN transport_vehicle v ON v.id = asg.vehicle_id
     LEFT JOIN transport_driver d ON d.id = asg.driver_id
     WHERE a.student_id = $3::uuid
       AND a.status = 'active'
       AND a.organization_id = $1 AND a.school_id = $2
     ORDER BY a.effective_from DESC
     LIMIT 1`,
    [scope.organizationId, scope.schoolId, studentId, serviceDate],
  );
  return rows[0] ?? null;
}

// ─── Driver "today" read (BUS-065) ───────────────────────────────────────────

export interface DriverTrip {
  trip_id: string;
  route_id: string;
  route_name: string;
  shift: string;
  status: string;
  service_date: string;
  vehicle_registration: string | null;
  is_substitute: boolean;
  stop_count: number;
  student_count: number;
}

/**
 * BUS-065/BUS-052 — the driver app's ONLY trip read: today, theirs.
 *
 * Resolution is by effective assignment for the CURRENT DATE, which is why a
 * substitute driver needs no special case anywhere in the app: a substitute
 * assigned at 06:30 logs in at 06:45 and sees the covered route exactly as the
 * permanent driver would, and tomorrow reverts automatically with zero admin
 * cleanup (owner requirement 1).
 *
 * `is_substitute` is surfaced so the UI can say so plainly — a driver covering
 * an unfamiliar route should know that is what is happening.
 */
export async function driverTripsToday(
  db: TenantQueryClient,
  scope: TenantScope,
  driverId: string,
  serviceDate: string,
): Promise<DriverTrip[]> {
  return await db.queryObject<DriverTrip>(
    `SELECT t.id AS trip_id,
            t.route_id,
            r.name AS route_name,
            t.shift,
            t.status,
            t.service_date::text,
            v.registration AS vehicle_registration,
            (asg.assignment_kind = 'substitute') AS is_substitute,
            (SELECT count(*) FROM transport_route_stop rs
              WHERE rs.route_id = r.id)::int AS stop_count,
            (SELECT count(*) FROM transport_allocation al
              WHERE al.route_id = r.id AND al.status = 'active')::int AS student_count
     FROM transport_trip t
     JOIN transport_route r ON r.id = t.route_id
     LEFT JOIN transport_vehicle v ON v.id = t.vehicle_id
     LEFT JOIN transport_assignment asg ON asg.id = t.assignment_id
     WHERE t.service_date = $3::date
       AND (t.driver_id = $4::uuid OR t.attendant_id = $4::uuid)
       AND t.organization_id = $1 AND t.school_id = $2
       AND t.status IN ('scheduled', 'started')
     ORDER BY t.shift, r.name`,
    [scope.organizationId, scope.schoolId, serviceDate, driverId],
  );
}

/**
 * BUS-067 — the manifest for ONE trip, grouped by stop sequence.
 *
 * Bounded by the trip's own route, so this is never a school-wide fetch. The
 * pre-v2 roster loaded every allocation in the school and grouped in JavaScript
 * by exact stop-NAME string match.
 */
export async function tripManifest(
  db: TenantQueryClient,
  scope: TenantScope,
  tripId: string,
): Promise<
  Array<{
    stop_id: string;
    stop_name: string;
    sequence: number;
    scheduled_pickup_time: string | null;
    student_id: string;
    student_name: string;
    boarding_event: string | null;
  }>
> {
  return await db.queryObject(
    `SELECT s.id AS stop_id,
            s.name AS stop_name,
            rs.sequence,
            rs.scheduled_pickup_time,
            st.id AS student_id,
            st.display_name AS student_name,
            b.event AS boarding_event
     FROM transport_trip t
     JOIN transport_route_stop rs ON rs.route_id = t.route_id
     JOIN transport_stop s ON s.id = rs.stop_id
     JOIN transport_allocation a
       ON a.route_id = t.route_id
      AND a.pickup_stop_id = s.id
      AND a.status = 'active'
     JOIN students st ON st.id = a.student_id
     LEFT JOIN transport_boarding b
       ON b.trip_id = t.id AND b.student_id = a.student_id
     WHERE t.id = $3::uuid
       AND t.organization_id = $1 AND t.school_id = $2
     ORDER BY rs.sequence, st.display_name`,
    [scope.organizationId, scope.schoolId, tripId],
  );
}

// ─── Dashboard counts (BUS-120) ──────────────────────────────────────────────

/**
 * BUS-004/BUS-120 — dashboard counts as SQL aggregates.
 *
 * Every figure here is traceable to live rows. The pre-v2 dashboard read a
 * static JSONB snapshot seeded once by a migration and never recomputed, so a
 * demo school saw permanently frozen numbers and a real school saw permanent
 * zeros.
 */
export async function dashboardCounts(
  db: TenantQueryClient,
  scope: TenantScope,
  serviceDate: string,
): Promise<{
  activeVehicles: number;
  activeRoutes: number;
  allocatedStudents: number;
  unstaffedRoutes: number;
  tripsRunning: number;
  openIncidents: number;
  stopsNeedingLocation: number;
}> {
  const rows = await db.queryObject<Record<string, string>>(
    `SELECT
       (SELECT count(*) FROM transport_vehicle
         WHERE organization_id = $1 AND school_id = $2 AND status = 'active')::text AS active_vehicles,
       (SELECT count(*) FROM transport_route
         WHERE organization_id = $1 AND school_id = $2 AND status = 'active')::text AS active_routes,
       (SELECT count(*) FROM transport_allocation
         WHERE organization_id = $1 AND school_id = $2 AND status = 'active')::text AS allocated_students,
       (SELECT count(*) FROM transport_trip
         WHERE organization_id = $1 AND school_id = $2
           AND service_date = $3::date AND status = 'started')::text AS trips_running,
       (SELECT count(*) FROM transport_incident
         WHERE organization_id = $1 AND school_id = $2
           AND acknowledged_at IS NULL)::text AS open_incidents,
       (SELECT count(*) FROM transport_stop
         WHERE organization_id = $1 AND school_id = $2
           AND status = 'needs_location')::text AS stops_needing_location`,
    [scope.organizationId, scope.schoolId, serviceDate],
  );
  const r = rows[0] ?? {};
  const unstaffed = await unstaffedRoutes(db, scope, serviceDate);
  const n = (k: string) => parseInt(r[k] ?? "0", 10);
  return {
    activeVehicles: n("active_vehicles"),
    activeRoutes: n("active_routes"),
    allocatedStudents: n("allocated_students"),
    unstaffedRoutes: unstaffed.length,
    tripsRunning: n("trips_running"),
    openIncidents: n("open_incidents"),
    stopsNeedingLocation: n("stops_needing_location"),
  };
}

// ─── Route publication readiness (BUS-042) ───────────────────────────────────

export interface RouteReadiness {
  ready: boolean;
  blockers: string[];
}

/**
 * BUS-042 — can this route be activated?
 *
 * The pre-v2 activate endpoint set status to 'active' with NO validation
 * whatsoever, so an admin could spend two hours configuring transport and end
 * with a seating chart that could never be tracked — with nothing on screen
 * indicating incompleteness.
 */
export async function routeReadiness(
  db: TenantQueryClient,
  scope: TenantScope,
  routeId: string,
  serviceDate: string,
): Promise<RouteReadiness> {
  const rows = await db.queryObject<{
    stop_count: string;
    stops_without_location: string;
    student_count: string;
    has_vehicle: boolean;
    has_driver: boolean;
    driver_licence_expired: boolean;
  }>(
    `SELECT
       (SELECT count(*) FROM transport_route_stop rs
         WHERE rs.route_id = r.id)::text AS stop_count,
       (SELECT count(*) FROM transport_route_stop rs
          JOIN transport_stop s ON s.id = rs.stop_id
         WHERE rs.route_id = r.id AND s.status = 'needs_location')::text AS stops_without_location,
       (SELECT count(*) FROM transport_allocation a
         WHERE a.route_id = r.id AND a.status = 'active')::text AS student_count,
       (asg.vehicle_id IS NOT NULL) AS has_vehicle,
       (asg.driver_id IS NOT NULL) AS has_driver,
       COALESCE(d.licence_expiry < $3::date, false) AS driver_licence_expired
     FROM transport_route r
     LEFT JOIN LATERAL (
       SELECT * FROM transport_effective_assignment(r.id, $3::date)
     ) asg ON true
     LEFT JOIN transport_driver d ON d.id = asg.driver_id
     WHERE r.id = $4::uuid AND r.organization_id = $1 AND r.school_id = $2`,
    [scope.organizationId, scope.schoolId, serviceDate, routeId],
  );
  const row = rows[0];
  if (!row) return { ready: false, blockers: ["route_not_found"] };

  const blockers: string[] = [];
  if (parseInt(row.stop_count, 10) < 2) blockers.push("needs_at_least_two_stops");
  if (parseInt(row.stops_without_location, 10) > 0) {
    blockers.push("stops_missing_location");
  }
  if (parseInt(row.student_count, 10) < 1) blockers.push("no_students_allocated");
  if (!row.has_vehicle) blockers.push("no_vehicle_assigned");
  if (!row.has_driver) blockers.push("no_driver_assigned");
  if (row.driver_licence_expired) blockers.push("driver_licence_expired");

  return { ready: blockers.length === 0, blockers };
}
