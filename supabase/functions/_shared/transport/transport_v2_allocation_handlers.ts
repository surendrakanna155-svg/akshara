import type { AppConfig } from "../config.ts";
import {
  createModuleWriteHandlers,
  requireStr,
  str,
  WriteNotFoundError,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { lockRoute, routeCapacity } from "./transport_v2_repository.ts";

/**
 * BUS-055…BUS-060 — student allocation on the relational model.
 *
 * THE DEFECTS THIS CLOSES
 *
 * 1. STOPS WERE FREE TEXT (BUS-055). An admin typed a pickup-stop name and the
 *    roster grouped children by EXACT STRING MATCH, so "Green Park Gate",
 *    "Green park gate" and "Green Park gate " became three different stops.
 *    Referential integrity between a child and their pickup point depended on
 *    typing accuracy — a safety defect, not a data-quality one. Here both stops
 *    are foreign keys, and a stop that is not on the route is rejected.
 *
 * 2. A STUDENT COULD RIDE TWO BUSES AT ONCE (BUS-056). Nothing checked, so a
 *    double-allocated child counted against both capacities, appeared on both
 *    rosters, and BOTH DRIVERS expected them. The schema now enforces one active
 *    allocation per (student, shift); this layer turns the resulting constraint
 *    violation into an actionable message rather than a 500.
 *
 * 3. THE CAPACITY GUARD NEVER RAN (BUS-044). It resolved capacity from a field
 *    no endpoint wrote. It runs here, under the route row lock, so two
 *    concurrent assignments cannot both slip past the last seat.
 *
 * 4. THE PARENT READ RETURNED THE WHOLE SCHOOL (BUS-059). See
 *    handleParentChildAllocationV2 — the single most important handler in this
 *    file.
 */

const { runWrite } = createModuleWriteHandlers("manageTransport");

const PG_UNIQUE_VIOLATION = "23505";

function isUniqueViolation(error: unknown): boolean {
  if (typeof error !== "object" || error === null) return false;
  const code = (error as { code?: unknown; fields?: { code?: unknown } }).code ??
    (error as { fields?: { code?: unknown } }).fields?.code;
  return code === PG_UNIQUE_VIOLATION;
}

function pathSegment(req: Request, index: number): string | undefined {
  return new URL(req.url).pathname.split("/").filter((s) => s.length > 0)[index];
}

const SHIFTS = new Set(["am", "pm", "both"]);

/**
 * Asserts a stop is actually ON the route before a child is allocated to it.
 *
 * Without this a child could be allocated to a stop the bus never visits — the
 * relational equivalent of the legacy typo defect, and just as invisible.
 */
async function assertStopOnRoute(
  db: Parameters<typeof lockRoute>[0],
  routeId: string,
  stopId: string,
  label: string,
): Promise<void> {
  const rows = await db.queryObject<{ n: string }>(
    `SELECT count(*)::text AS n FROM transport_route_stop
     WHERE route_id = $1::uuid AND stop_id = $2::uuid`,
    [routeId, stopId],
  );
  if (parseInt(rows[0]?.n ?? "0", 10) === 0) {
    throw new WriteValidationError(
      `The ${label} stop is not on this route. Add it to the route first, or ` +
        `choose one of the route's stops.`,
      422,
      "STOP_NOT_ON_ROUTE",
    );
  }
}

/** POST /transport/v2/allocations — allocate ONE student to a route + stops. */
export async function handleAllocateStudentV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;

    const studentId = requireStr(body, "studentId", "student_id");
    const routeId = requireStr(body, "routeId", "route_id");
    const pickupStopId = requireStr(body, "pickupStopId", "pickup_stop_id");
    const dropStopId = requireStr(body, "dropStopId", "drop_stop_id");
    const shift = str(body, "shift") ?? "both";
    if (!SHIFTS.has(shift)) {
      throw new WriteValidationError(
        "shift must be am, pm or both",
        422,
        "INVALID_SHIFT",
      );
    }
    const allowOverCapacity = body.allowOverCapacity === true ||
      body.allow_over_capacity === true;

    // Lock the route FIRST so the capacity count below is a consistent snapshot
    // and a concurrent assignment cannot also take the last seat. This is the
    // TRN-7 discipline, preserved — it was always correct, just unreachable.
    if (!(await lockRoute(db, { organizationId, schoolId }, routeId))) {
      throw new WriteNotFoundError(`Transport route not found: ${routeId}`);
    }

    await assertStopOnRoute(db, routeId, pickupStopId, "pickup");
    await assertStopOnRoute(db, routeId, dropStopId, "drop");

    const today = new Date().toISOString().slice(0, 10);
    const cap = await routeCapacity(db, { organizationId, schoolId }, routeId, today);
    let capacityOverridden = false;
    if (cap?.capacity != null && cap.current + 1 > cap.capacity) {
      if (!allowOverCapacity) {
        throw new WriteValidationError(
          `${cap.routeName} is full (${cap.current}/${cap.capacity}). Assign a ` +
            `larger bus, or pass allowOverCapacity to override.`,
          409,
          "CAPACITY_EXCEEDED",
        );
      }
      capacityOverridden = true;
    }

    let id: string;
    try {
      const rows = await db.queryObject<{ id: string }>(
        `INSERT INTO transport_allocation
           (organization_id, school_id, student_id, route_id,
            pickup_stop_id, drop_stop_id, shift, status)
         VALUES ($1, $2, $3::uuid, $4::uuid, $5::uuid, $6::uuid, $7, 'active')
         RETURNING id`,
        [organizationId, schoolId, studentId, routeId, pickupStopId, dropStopId, shift],
      );
      id = rows[0].id;
    } catch (error) {
      // BUS-056: the partial unique index fired. Translate it into the action
      // the admin should take rather than surfacing a 500.
      if (!isUniqueViolation(error)) throw error;
      throw new WriteValidationError(
        `This student already has an active ${shift} allocation. Transfer them ` +
          `instead of creating a second one — a child cannot ride two buses.`,
        409,
        "ALLOCATION_CONFLICT",
      );
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.allocation.assigned", "transport_allocation", id, {
        studentId,
        routeId,
        shift,
      }),
      request,
    );
    // A capacity override is audited SEPARATELY, so "who authorised the 49th
    // child on a 48-seat bus" stays answerable.
    if (capacityOverridden) {
      await emitMutationAudit(
        db,
        claims,
        moduleEntityAudit("transport.capacity.overridden", "transport_route", routeId, {
          allocationId: id,
          studentId,
          capacity: cap?.capacity,
          current: cap?.current,
        }),
        request,
      );
    }

    return {
      payload: { id, studentId, routeId, shift, capacityOverridden },
      status: 201,
    };
  });
}

/**
 * POST /transport/v2/allocations/{id}/transfer — move a student to another route.
 *
 * Atomic under BOTH route locks, so the seat is released on the source and taken
 * on the target in one transaction. Transferring is the ONLY correct way to move
 * a child: creating a second allocation is what produced the two-bus defect.
 */
export async function handleTransferAllocationV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const allocationId = pathSegment(request, 3);
    if (!allocationId) throw new WriteNotFoundError("Allocation id is required");

    const targetRouteId = requireStr(body, "targetRouteId", "target_route_id");
    const pickupStopId = requireStr(body, "pickupStopId", "pickup_stop_id");
    const dropStopId = requireStr(body, "dropStopId", "drop_stop_id");
    const allowOverCapacity = body.allowOverCapacity === true;

    const current = await db.queryObject<{ route_id: string; student_id: string }>(
      `SELECT route_id, student_id FROM transport_allocation
       WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3
         AND status = 'active'`,
      [allocationId, organizationId, schoolId],
    );
    if (current.length === 0) {
      throw new WriteNotFoundError(`Active allocation not found: ${allocationId}`);
    }

    // Lock both routes in a STABLE order (by id) so two concurrent transfers in
    // opposite directions cannot deadlock.
    const [first, second] = [current[0].route_id, targetRouteId].sort();
    if (!(await lockRoute(db, { organizationId, schoolId }, first))) {
      throw new WriteNotFoundError(`Transport route not found: ${first}`);
    }
    if (second !== first) {
      if (!(await lockRoute(db, { organizationId, schoolId }, second))) {
        throw new WriteNotFoundError(`Transport route not found: ${second}`);
      }
    }

    await assertStopOnRoute(db, targetRouteId, pickupStopId, "pickup");
    await assertStopOnRoute(db, targetRouteId, dropStopId, "drop");

    const today = new Date().toISOString().slice(0, 10);
    const cap = await routeCapacity(
      db,
      { organizationId, schoolId },
      targetRouteId,
      today,
    );
    let capacityOverridden = false;
    if (cap?.capacity != null && cap.current + 1 > cap.capacity) {
      if (!allowOverCapacity) {
        throw new WriteValidationError(
          `${cap.routeName} is full (${cap.current}/${cap.capacity}).`,
          409,
          "CAPACITY_EXCEEDED",
        );
      }
      capacityOverridden = true;
    }

    await db.queryObject(
      `UPDATE transport_allocation
       SET route_id = $2::uuid, pickup_stop_id = $3::uuid, drop_stop_id = $4::uuid
       WHERE id = $1::uuid`,
      [allocationId, targetRouteId, pickupStopId, dropStopId],
    );

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit(
        "transport.allocation.transferred",
        "transport_allocation",
        allocationId,
        { fromRouteId: current[0].route_id, targetRouteId, capacityOverridden },
      ),
      request,
    );
    return {
      payload: { id: allocationId, targetRouteId, capacityOverridden },
      status: 200,
    };
  });
}

/**
 * DELETE /transport/v2/allocations/{id} — end an allocation.
 *
 * Ended, not deleted: the row is retained with an effective_to so a boarding
 * record from last term still resolves the stop the child used at the time.
 */
export async function handleEndAllocationV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const allocationId = pathSegment(request, 3);
    if (!allocationId) throw new WriteNotFoundError("Allocation id is required");

    const rows = await db.queryObject<{ id: string }>(
      `UPDATE transport_allocation
       SET status = 'ended', effective_to = CURRENT_DATE
       WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3
         AND status = 'active'
       RETURNING id`,
      [allocationId, organizationId, schoolId],
    );
    if (rows.length === 0) {
      throw new WriteNotFoundError(`Active allocation not found: ${allocationId}`);
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit(
        "transport.allocation.removed",
        "transport_allocation",
        allocationId,
        { ended: true },
      ),
      request,
    );
    return { payload: { id: allocationId, status: "ended" }, status: 200 };
  });
}

/**
 * BUS-060 — POST /transport/v2/allocations/bulk
 *
 * Allocates a whole class to one route/stop pair. Preserves the legacy handler's
 * genuinely good semantics: ONE capacity check for the whole batch under the
 * route lock, and a partial-success result so one bad row does not lose the
 * other thirty-nine.
 */
export async function handleBulkAllocateV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;

    const routeId = requireStr(body, "routeId", "route_id");
    const pickupStopId = requireStr(body, "pickupStopId", "pickup_stop_id");
    const dropStopId = requireStr(body, "dropStopId", "drop_stop_id");
    const shift = str(body, "shift") ?? "both";
    const allowOverCapacity = body.allowOverCapacity === true;
    const className = str(body, "className", "class_name");
    const sectionName = str(body, "sectionName", "section_name");
    const explicitIds = Array.isArray(body.studentIds)
      ? (body.studentIds as unknown[]).map((x) => String(x))
      : [];

    if (explicitIds.length === 0 && !className) {
      throw new WriteValidationError(
        "Provide studentIds or a className",
        422,
        "NOTHING_TO_ALLOCATE",
      );
    }

    if (!(await lockRoute(db, { organizationId, schoolId }, routeId))) {
      throw new WriteNotFoundError(`Transport route not found: ${routeId}`);
    }
    await assertStopOnRoute(db, routeId, pickupStopId, "pickup");
    await assertStopOnRoute(db, routeId, dropStopId, "drop");

    let targets: string[] = explicitIds;
    if (targets.length === 0) {
      const rows = await db.queryObject<{ student_id: string }>(
        `SELECT e.student_id
         FROM sis_student_enrollments e
         WHERE e.organization_id = $1 AND e.school_id = $2
           AND e.is_current = true AND e.class_name = $3
           AND ($4::text IS NULL OR e.section_name = $4)
         ORDER BY e.student_id`,
        [organizationId, schoolId, className, sectionName ?? null],
      );
      targets = rows.map((r) => r.student_id);
    }

    const today = new Date().toISOString().slice(0, 10);
    const cap = await routeCapacity(db, { organizationId, schoolId }, routeId, today);
    let capacityOverridden = false;
    if (cap?.capacity != null && cap.current + targets.length > cap.capacity) {
      if (!allowOverCapacity) {
        throw new WriteValidationError(
          `${cap.routeName} cannot take ${targets.length} more ` +
            `(${cap.current}/${cap.capacity}).`,
          409,
          "CAPACITY_EXCEEDED",
        );
      }
      capacityOverridden = true;
    }

    const assigned: string[] = [];
    const skipped: Array<{ studentId: string; reason: string }> = [];

    for (const studentId of targets) {
      // A savepoint per row: a conflict on one student must not abort the whole
      // transaction and lose the rest of the class.
      await db.queryObject(`SAVEPOINT alloc_row`);
      try {
        await db.queryObject(
          `INSERT INTO transport_allocation
             (organization_id, school_id, student_id, route_id,
              pickup_stop_id, drop_stop_id, shift, status)
           VALUES ($1, $2, $3::uuid, $4::uuid, $5::uuid, $6::uuid, $7, 'active')`,
          [organizationId, schoolId, studentId, routeId, pickupStopId, dropStopId, shift],
        );
        await db.queryObject(`RELEASE SAVEPOINT alloc_row`);
        assigned.push(studentId);
      } catch (error) {
        await db.queryObject(`ROLLBACK TO SAVEPOINT alloc_row`);
        if (isUniqueViolation(error)) {
          skipped.push({
            studentId,
            reason: "already_allocated_for_this_shift",
          });
        } else {
          skipped.push({ studentId, reason: "insert_failed" });
        }
      }
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.allocation.bulk", "transport_route", routeId, {
        assignedCount: assigned.length,
        skippedCount: skipped.length,
        capacityOverridden,
      }),
      request,
    );

    return {
      payload: {
        routeId,
        assigned,
        assignedCount: assigned.length,
        skipped,
        capacityOverridden,
      },
      status: 200,
    };
  });
}

/**
 * BUS-058 — GET /transport/v2/routes/{id}/roster
 *
 * Stop-wise roster as a single indexed join, ordered by the route's own stop
 * sequence. The legacy version loaded EVERY allocation in the school and grouped
 * them in JavaScript by exact stop-NAME match.
 */
export async function handleRouteRosterV2(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "viewTransport");
  if (denied) return denied;

  const routeId = pathSegment(req, 3);
  if (!routeId) {
    return errorEnvelope("VALIDATION_ERROR", "Route id is required", 422);
  }
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const payload = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<Record<string, unknown>>(
        `SELECT s.id AS "stopId", s.name AS "stopName", rs.sequence,
                to_char(rs.scheduled_pickup_time, 'HH24:MI') AS "pickupTime",
                st.id AS "studentId", st.display_name AS "studentName",
                a.shift
         FROM transport_route_stop rs
         JOIN transport_stop s ON s.id = rs.stop_id
         LEFT JOIN transport_allocation a
           ON a.route_id = rs.route_id AND a.pickup_stop_id = s.id
          AND a.status = 'active'
         LEFT JOIN students st ON st.id = a.student_id
         WHERE rs.route_id = $1::uuid
           AND rs.organization_id = $2 AND rs.school_id = $3
         ORDER BY rs.sequence, st.display_name`,
        [routeId, orgId, schoolId],
      );

      // Group in one pass. Stops with no students are RETAINED — an empty stop
      // is information (nobody boards there), not absence of data.
      const stops: Array<Record<string, unknown>> = [];
      let current: Record<string, unknown> | null = null;
      for (const r of rows) {
        if (!current || current.stopId !== r.stopId) {
          current = {
            stopId: r.stopId,
            stopName: r.stopName,
            sequence: r.sequence,
            pickupTime: r.pickupTime,
            students: [] as Array<Record<string, unknown>>,
          };
          stops.push(current);
        }
        if (r.studentId) {
          (current.students as Array<Record<string, unknown>>).push({
            studentId: r.studentId,
            studentName: r.studentName,
            shift: r.shift,
          });
        }
      }
      const studentCount = stops.reduce(
        (n, s) => n + (s.students as unknown[]).length,
        0,
      );
      return { routeId, stops, stopCount: stops.length, studentCount };
    });
    return jsonResponse(envelope(payload));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("handleRouteRosterV2:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load roster", 500);
  }
}

/**
 * BUS-059 — GET /parent/transport/allocation?childId=…
 *
 * THE MOST IMPORTANT HANDLER IN THIS FILE. It closes one of the three original
 * P0s, all of which the same legacy call caused:
 *
 *   * it 403'd in the live build — the parent role held no transport permission
 *     and the endpoint demanded school scope;
 *   * it would have LEAKED the school roster — other children's names, admission
 *     numbers, class, bus and PICKUP STOP LOCATIONS — to any parent's device.
 *     Publishing where other people's children stand each morning is a
 *     child-safety failure, not merely a privacy one;
 *   * it read page 1 of 20 and scanned client-side, so in an 800-student school
 *     it found the right child for roughly 2.5% of parents.
 *
 * Three properties make those unrepresentable rather than merely fixed:
 *   1. it takes ONE childId and returns ONE allocation. There is no list form.
 *   2. it verifies the caller is an active guardian OF THAT CHILD before reading.
 *   3. RLS (transport_allocation_parent_read) independently enforces the same
 *      thing, so a careless future handler still cannot leak.
 */
export async function handleParentChildAllocationV2(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  // Parent scope, not school scope. This is the fix for the 403.
  if (auth.claims.scope !== "parent") {
    return errorEnvelope(
      "FORBIDDEN",
      "This endpoint is for parent sessions",
      403,
    );
  }
  const denied = requirePermission(auth.claims, "viewChildTransport");
  if (denied) return denied;

  const childId = new URL(req.url).searchParams.get("childId") ?? "";
  if (childId.trim() === "") {
    // No implicit "first child" default: guessing which child a parent meant is
    // how the legacy path ended up scanning a school-wide list.
    return errorEnvelope("VALIDATION_ERROR", "childId is required", 422);
  }
  // Defence in depth: the JWT already lists the parent's children, so a foreign
  // id is refused before any query runs.
  if (!(auth.claims.child_ids ?? []).includes(childId)) {
    return errorEnvelope(
      "FORBIDDEN",
      "That child is not linked to this parent",
      403,
    );
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const payload = await withTenantContext(config, auth.claims, async (db) => {
      const rows = await db.queryObject<Record<string, unknown>>(
        `SELECT a.id AS "allocationId",
                r.id AS "routeId", r.name AS "routeName", r.shift,
                ps.name AS "pickupStopName",
                ds.name AS "dropStopName",
                to_char(rsp.scheduled_pickup_time, 'HH24:MI') AS "pickupTime",
                to_char(rsd.scheduled_drop_time, 'HH24:MI') AS "dropTime",
                v.registration AS "vehicleRegistration",
                d.name AS "driverName"
         FROM transport_allocation a
         JOIN transport_route r ON r.id = a.route_id
         JOIN transport_stop ps ON ps.id = a.pickup_stop_id
         JOIN transport_stop ds ON ds.id = a.drop_stop_id
         LEFT JOIN transport_route_stop rsp
           ON rsp.route_id = r.id AND rsp.stop_id = ps.id
         LEFT JOIN transport_route_stop rsd
           ON rsd.route_id = r.id AND rsd.stop_id = ds.id
         LEFT JOIN LATERAL (
           SELECT * FROM transport_effective_assignment(r.id, CURRENT_DATE)
         ) asg ON true
         LEFT JOIN transport_vehicle v ON v.id = asg.vehicle_id
         LEFT JOIN transport_driver d ON d.id = asg.driver_id
         WHERE a.student_id = $1::uuid
           AND a.status = 'active'
           AND a.organization_id = $2 AND a.school_id = $3
           -- The guardian link is re-checked HERE, not trusted from the token.
           AND EXISTS (
             SELECT 1 FROM student_guardians sg
             WHERE sg.student_id = a.student_id
               AND sg.guardian_user_id = $4::uuid
               AND sg.status = 'active'
           )
         LIMIT 1`,
        [childId, orgId, schoolId, auth.claims.sub],
      );
      // No allocation is a legitimate answer (the child walks or is driven), not
      // an error.
      return rows[0] ?? {};
    });
    return jsonResponse(envelope(payload as Record<string, unknown>));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("handleParentChildAllocationV2:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load transport", 500);
  }
}
