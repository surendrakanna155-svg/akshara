import type { AppConfig } from "../config.ts";
import {
  createModuleWriteHandlers,
  requireStr,
  str,
  WriteNotFoundError,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  effectiveAssignment,
  lockRoute,
  routeCapacity,
  unstaffedRoutes,
} from "./transport_v2_repository.ts";

/**
 * BUS-043…BUS-054 — vehicle & driver assignment, availability, substitution.
 *
 * THE SINGLE HIGHEST-VALUE FILE IN THE ROADMAP.
 *
 * Pre-v2 there was NO way to assign a bus or a driver to a route. `assignedBus`
 * was written as "" at route creation and no endpoint anywhere ever set it;
 * `assignedDriverId` was READ by the driver-delete guard and written by nothing.
 * These are the two most fundamental operations in a transport module, and their
 * absence silently killed three other features that were correctly built,
 * row-locked and concurrency-tested:
 *
 *   1. the TRN-7 capacity guard — capacity resolved from the route's assigned
 *      vehicle, so it was ALWAYS null, so the guard ALWAYS returned early. The
 *      result was unlimited over-allocation of a 48-seat bus.
 *   2. the vehicle-in-use delete guard — matched on `assignedBus`, so it never
 *      matched: you could delete a bus that 45 children rode to school.
 *   3. the driver-in-use delete guard — matched on a field nothing wrote.
 *
 * All three come alive the moment assignment exists. That is why the audit
 * called this the highest value-per-line-of-code fix in the module.
 *
 * Assignment is a DATED ROW (roadmap P-3), never a scalar on the route. That
 * single modelling choice is what makes the owner's additional requirements
 * ordinary records instead of schema changes:
 *   - substitute driver for today, permanent arrangement untouched (req 1)
 *   - temporary vehicle replacement (req 3)
 *   - AM and PM routes assigned independently (req 3)
 */

const { runWrite } = createModuleWriteHandlers("manageTransport");

function pathSegment(req: Request, index: number): string | undefined {
  return new URL(req.url).pathname.split("/").filter((s) => s.length > 0)[index];
}

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

function dateField(
  body: Record<string, unknown>,
  ...keys: string[]
): string | undefined {
  const raw = str(body, ...keys);
  if (raw === undefined) return undefined;
  if (!ISO_DATE.test(raw)) {
    throw new WriteValidationError(
      `${keys[0]} must be an ISO date (YYYY-MM-DD)`,
      422,
      "INVALID_DATE",
    );
  }
  return raw;
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

// ─── BUS-054: compliance gate ────────────────────────────────────────────────

/**
 * BUS-054 — refuse to put an out-of-compliance vehicle or driver on a route.
 *
 * The pre-v2 module tracked these dates with strict ISO validation and sent a
 * staff digest, which was a genuine strength — but it only ever REPORTED. A
 * report tells a school there is a problem; a gate stops the problem. When a
 * transport authority asks whether an uninsured bus carried children, "we sent
 * an email about it" is not an answer.
 *
 * Override is possible but requires an explicit flag and is audited separately,
 * mirroring the capacity-override trail that made "who authorised the 49th
 * child" answerable.
 */
async function assertCompliance(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  vehicleId: string | null,
  driverId: string | null,
  onDate: string,
  allowNonCompliant: boolean,
): Promise<string[]> {
  const problems: string[] = [];

  if (vehicleId) {
    const rows = await db.queryObject<{
      registration: string;
      status: string;
      expired: string | null;
    }>(
      `SELECT registration, status,
              CASE
                WHEN insurance_expiry IS NOT NULL AND insurance_expiry < $2::date THEN 'insurance'
                WHEN fitness_expiry  IS NOT NULL AND fitness_expiry  < $2::date THEN 'fitness'
                WHEN permit_expiry   IS NOT NULL AND permit_expiry   < $2::date THEN 'permit'
              END AS expired
       FROM transport_vehicle
       WHERE id = $1::uuid AND organization_id = $3 AND school_id = $4`,
      [vehicleId, onDate, organizationId, schoolId],
    );
    if (rows.length === 0) {
      throw new WriteNotFoundError(`Transport vehicle not found: ${vehicleId}`);
    }
    if (rows[0].status !== "active") {
      problems.push(`vehicle_${rows[0].status}`);
    }
    if (rows[0].expired) problems.push(`vehicle_${rows[0].expired}_expired`);
  }

  if (driverId) {
    const rows = await db.queryObject<{
      name: string;
      status: string;
      licence_expired: boolean;
    }>(
      `SELECT name, status,
              COALESCE(licence_expiry < $2::date, false) AS licence_expired
       FROM transport_driver
       WHERE id = $1::uuid AND organization_id = $3 AND school_id = $4`,
      [driverId, onDate, organizationId, schoolId],
    );
    if (rows.length === 0) {
      throw new WriteNotFoundError(`Transport driver not found: ${driverId}`);
    }
    if (rows[0].status === "inactive") problems.push("driver_inactive");
    if (rows[0].licence_expired) problems.push("driver_licence_expired");
  }

  if (problems.length > 0 && !allowNonCompliant) {
    throw new WriteValidationError(
      `Cannot assign: ${problems.join(", ")}. Renew the document, or pass ` +
        `allowNonCompliant to override (this is audited separately).`,
      409,
      "COMPLIANCE_BLOCKED",
    );
  }
  return problems;
}

/**
 * BUS-050 — is this driver already committed elsewhere, or unavailable?
 *
 * Without this a school can assign one person to two buses at the same time and
 * only discover it when a route has no driver at 7 a.m.
 */
async function assertDriverAvailable(
  db: TenantQueryClient,
  driverId: string,
  routeId: string,
  from: string,
  to: string | null,
  shift: string,
): Promise<void> {
  const leave = await db.queryObject<{ kind: string; from_date: string; to_date: string }>(
    `SELECT kind, from_date::text, to_date::text
     FROM transport_driver_availability
     WHERE driver_id = $1::uuid
       AND daterange(from_date, to_date, '[]')
           && daterange($2::date, COALESCE($3::date, 'infinity'::date), '[]')
     LIMIT 1`,
    [driverId, from, to],
  );
  if (leave.length > 0) {
    throw new WriteValidationError(
      `Driver is unavailable (${leave[0].kind}) from ${leave[0].from_date} to ` +
        `${leave[0].to_date}. Assign a substitute for those dates instead.`,
      409,
      "DRIVER_UNAVAILABLE",
    );
  }

  const clash = await db.queryObject<{ route_name: string }>(
    `SELECT r.name AS route_name
     FROM transport_assignment a
     JOIN transport_route r ON r.id = a.route_id
     WHERE a.driver_id = $1::uuid
       AND a.route_id <> $2::uuid
       AND r.shift = $5
       AND daterange(a.effective_from, COALESCE(a.effective_to, 'infinity'::date), '[]')
           && daterange($3::date, COALESCE($4::date, 'infinity'::date), '[]')
     LIMIT 1`,
    [driverId, routeId, from, to, shift],
  );
  if (clash.length > 0) {
    throw new WriteValidationError(
      `Driver is already assigned to "${clash[0].route_name}" in the same shift ` +
        `over these dates.`,
      409,
      "DRIVER_DOUBLE_BOOKED",
    );
  }
}

/** BUS-043 — the same check for a vehicle: one bus cannot run two routes at once. */
async function assertVehicleAvailable(
  db: TenantQueryClient,
  vehicleId: string,
  routeId: string,
  from: string,
  to: string | null,
  shift: string,
): Promise<void> {
  const clash = await db.queryObject<{ route_name: string }>(
    `SELECT r.name AS route_name
     FROM transport_assignment a
     JOIN transport_route r ON r.id = a.route_id
     WHERE a.vehicle_id = $1::uuid
       AND a.route_id <> $2::uuid
       AND r.shift = $5
       AND daterange(a.effective_from, COALESCE(a.effective_to, 'infinity'::date), '[]')
           && daterange($3::date, COALESCE($4::date, 'infinity'::date), '[]')
     LIMIT 1`,
    [vehicleId, routeId, from, to, shift],
  );
  if (clash.length > 0) {
    throw new WriteValidationError(
      `Vehicle is already assigned to "${clash[0].route_name}" in the same shift ` +
        `over these dates.`,
      409,
      "VEHICLE_DOUBLE_BOOKED",
    );
  }
}

// ─── BUS-043 + BUS-048: the assignment endpoint that did not exist ───────────

/**
 * PUT /transport/v2/routes/{id}/assignment
 *
 * Sets the PERMANENT vehicle + driver (+ optional attendant) for a route, by ID.
 * Never by registration or licence string — mutating a registration must not be
 * able to break the link, which is exactly what the pre-v2 string reference
 * allowed (BUS-047).
 *
 * Closing an existing permanent assignment and opening a new one happens in ONE
 * transaction under the route lock, so the exclusion constraint
 * (transport_assignment_no_permanent_overlap) can never see two open rows.
 */
export async function handleSetRouteAssignmentV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const routeId = pathSegment(request, 3);
    if (!routeId) throw new WriteNotFoundError("Route id is required");

    if (!(await lockRoute(db, { organizationId, schoolId }, routeId))) {
      throw new WriteNotFoundError(`Transport route not found: ${routeId}`);
    }

    const vehicleId = str(body, "vehicleId", "vehicle_id") ?? null;
    const driverId = str(body, "driverId", "driver_id") ?? null;
    const attendantId = str(body, "attendantId", "attendant_id") ?? null;
    if (!vehicleId && !driverId) {
      throw new WriteValidationError(
        "Supply at least a vehicleId or a driverId",
        422,
        "NOTHING_TO_ASSIGN",
      );
    }
    if (attendantId && attendantId === driverId) {
      throw new WriteValidationError(
        "The attendant cannot also be the driver",
        422,
        "ATTENDANT_IS_DRIVER",
      );
    }

    const from = dateField(body, "effectiveFrom", "effective_from") ?? today();
    const allowNonCompliant = body.allowNonCompliant === true ||
      body.allow_non_compliant === true;

    const shiftRows = await db.queryObject<{ shift: string }>(
      `SELECT shift FROM transport_route WHERE id = $1::uuid`,
      [routeId],
    );
    const shift = shiftRows[0]?.shift ?? "am";

    const problems = await assertCompliance(
      db,
      organizationId,
      schoolId,
      vehicleId,
      driverId,
      from,
      allowNonCompliant,
    );
    if (vehicleId) {
      await assertVehicleAvailable(db, vehicleId, routeId, from, null, shift);
    }
    if (driverId) {
      await assertDriverAvailable(db, driverId, routeId, from, null, shift);
    }

    // Close any open permanent assignment the day before the new one starts.
    await db.queryObject(
      `UPDATE transport_assignment
       SET effective_to = ($2::date - INTERVAL '1 day')::date
       WHERE route_id = $1::uuid
         AND assignment_kind = 'permanent'
         AND (effective_to IS NULL OR effective_to >= $2::date)`,
      [routeId, from],
    );

    const rows = await db.queryObject<{ id: string }>(
      `INSERT INTO transport_assignment
         (organization_id, school_id, route_id, vehicle_id, driver_id,
          attendant_id, effective_from, effective_to, assignment_kind, reason,
          created_by)
       VALUES ($1, $2, $3::uuid, $4::uuid, $5::uuid, $6::uuid, $7::date, NULL,
               'permanent', $8, $9)
       RETURNING id`,
      [
        organizationId,
        schoolId,
        routeId,
        vehicleId,
        driverId,
        attendantId,
        from,
        str(body, "reason") ?? "",
        claims.sub,
      ],
    );
    const id = rows[0].id;

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.assignment.set", "transport_route", routeId, {
        assignmentId: id,
        vehicleId,
        driverId,
        attendantId,
        effectiveFrom: from,
      }),
      request,
    );
    // A separately-audited override trail, mirroring the capacity-override
    // pattern that made "who authorised this" answerable.
    if (problems.length > 0) {
      await emitMutationAudit(
        db,
        claims,
        moduleEntityAudit(
          "transport.compliance.overridden",
          "transport_route",
          routeId,
          { assignmentId: id, problems },
        ),
        request,
      );
    }

    return {
      payload: {
        assignmentId: id,
        routeId,
        vehicleId,
        driverId,
        attendantId,
        effectiveFrom: from,
        complianceOverridden: problems.length > 0,
        complianceProblems: problems,
      },
      status: 200,
    };
  });
}

// ─── BUS-046 + BUS-051: temporary substitution (owner requirement 1) ─────────

/**
 * POST /transport/v2/routes/{id}/substitute
 *
 * Assigns a different vehicle and/or driver for a BOUNDED date range WITHOUT
 * touching the permanent assignment. This is the owner's first additional
 * requirement, and it is a plain INSERT rather than a feature because assignment
 * was modelled as a dated row from the start (P-3).
 *
 * Consequences that fall out for free:
 *   - today's trip resolves to the substitute via transport_effective_assignment
 *   - tomorrow reverts automatically, with NO admin cleanup step to forget
 *   - the driver app needs no special case: BUS-065 resolves "today's trip" by
 *     effective assignment, so a substitute assigned at 06:30 logs in at 06:45
 *     and sees the covered route exactly as the permanent driver would
 */
export async function handleSubstituteAssignmentV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const routeId = pathSegment(request, 3);
    if (!routeId) throw new WriteNotFoundError("Route id is required");

    if (!(await lockRoute(db, { organizationId, schoolId }, routeId))) {
      throw new WriteNotFoundError(`Transport route not found: ${routeId}`);
    }

    const from = dateField(body, "effectiveFrom", "effective_from", "date") ?? today();
    // A substitute MUST be bounded — an unbounded one is a permanent assignment
    // wearing the wrong label, and the schema rejects it.
    const to = dateField(body, "effectiveTo", "effective_to") ?? from;
    if (to < from) {
      throw new WriteValidationError(
        "effectiveTo cannot be before effectiveFrom",
        422,
        "INVALID_DATE_RANGE",
      );
    }

    const reason = requireStr(body, "reason");
    const allowNonCompliant = body.allowNonCompliant === true ||
      body.allow_non_compliant === true;

    // Inherit whatever the permanent assignment provides, so a driver-only
    // substitution keeps the regular bus and vice versa.
    const permanent = await effectiveAssignment(
      db,
      { organizationId, schoolId },
      routeId,
      from,
    );
    const vehicleId = str(body, "vehicleId", "vehicle_id") ??
      permanent?.vehicle_id ?? null;
    const driverId = str(body, "driverId", "driver_id") ?? permanent?.driver_id ?? null;
    const attendantId = str(body, "attendantId", "attendant_id") ??
      permanent?.attendant_id ?? null;

    if (!vehicleId && !driverId) {
      throw new WriteValidationError(
        "Supply a vehicleId or driverId to substitute",
        422,
        "NOTHING_TO_ASSIGN",
      );
    }

    const shiftRows = await db.queryObject<{ shift: string }>(
      `SELECT shift FROM transport_route WHERE id = $1::uuid`,
      [routeId],
    );
    const shift = shiftRows[0]?.shift ?? "am";

    const problems = await assertCompliance(
      db,
      organizationId,
      schoolId,
      vehicleId,
      driverId,
      from,
      allowNonCompliant,
    );
    // A substitute driver must themselves be available and not double-booked —
    // covering one route by stripping another is not a fix.
    if (driverId && driverId !== permanent?.driver_id) {
      await assertDriverAvailable(db, driverId, routeId, from, to, shift);
    }
    if (vehicleId && vehicleId !== permanent?.vehicle_id) {
      await assertVehicleAvailable(db, vehicleId, routeId, from, to, shift);
    }

    const rows = await db.queryObject<{ id: string }>(
      `INSERT INTO transport_assignment
         (organization_id, school_id, route_id, vehicle_id, driver_id,
          attendant_id, effective_from, effective_to, assignment_kind, reason,
          created_by)
       VALUES ($1, $2, $3::uuid, $4::uuid, $5::uuid, $6::uuid, $7::date, $8::date,
               'substitute', $9, $10)
       RETURNING id`,
      [
        organizationId,
        schoolId,
        routeId,
        vehicleId,
        driverId,
        attendantId,
        from,
        to,
        reason,
        claims.sub,
      ],
    );
    const id = rows[0].id;

    // Re-bind any ALREADY-GENERATED trip in the range to the substitute.
    // Without this, trips generated last night would still carry the regular
    // driver and the substitute would see nothing on login.
    const rebound = await db.queryObject<{ id: string }>(
      `UPDATE transport_trip
       SET vehicle_id = COALESCE($4::uuid, vehicle_id),
           driver_id = COALESCE($5::uuid, driver_id),
           attendant_id = $6::uuid,
           assignment_id = $7::uuid
       WHERE route_id = $1::uuid
         AND service_date BETWEEN $2::date AND $3::date
         AND status = 'scheduled'
       RETURNING id`,
      [routeId, from, to, vehicleId, driverId, attendantId, id],
    );

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.assignment.substituted", "transport_route", routeId, {
        assignmentId: id,
        vehicleId,
        driverId,
        effectiveFrom: from,
        effectiveTo: to,
        reason,
        tripsRebound: rebound.length,
      }),
      request,
    );
    if (problems.length > 0) {
      await emitMutationAudit(
        db,
        claims,
        moduleEntityAudit(
          "transport.compliance.overridden",
          "transport_route",
          routeId,
          { assignmentId: id, problems, substitute: true },
        ),
        request,
      );
    }

    return {
      payload: {
        assignmentId: id,
        routeId,
        vehicleId,
        driverId,
        attendantId,
        effectiveFrom: from,
        effectiveTo: to,
        reason,
        tripsRebound: rebound.length,
        complianceOverridden: problems.length > 0,
      },
      status: 201,
    };
  });
}

/** DELETE /transport/v2/assignments/{id} — cancel a substitution. */
export async function handleCancelSubstituteV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const id = pathSegment(request, 3);
    if (!id) throw new WriteNotFoundError("Assignment id is required");

    const rows = await db.queryObject<{
      id: string;
      route_id: string;
      assignment_kind: string;
      effective_from: string;
      effective_to: string | null;
    }>(
      `SELECT id, route_id, assignment_kind, effective_from::text, effective_to::text
       FROM transport_assignment
       WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3`,
      [id, organizationId, schoolId],
    );
    if (rows.length === 0) {
      throw new WriteNotFoundError(`Assignment not found: ${id}`);
    }
    // A permanent assignment is replaced, never cancelled — cancelling it would
    // leave the route unstaffed with no record of what it used to be.
    if (rows[0].assignment_kind !== "substitute") {
      throw new WriteValidationError(
        "Only a substitute assignment can be cancelled. Replace the permanent " +
          "assignment instead.",
        409,
        "NOT_A_SUBSTITUTE",
      );
    }

    await db.queryObject(`DELETE FROM transport_assignment WHERE id = $1::uuid`, [id]);

    // Re-bind affected scheduled trips back to the permanent assignment.
    const permanent = await effectiveAssignment(
      db,
      { organizationId, schoolId },
      rows[0].route_id,
      rows[0].effective_from,
    );
    const rebound = await db.queryObject<{ id: string }>(
      `UPDATE transport_trip
       SET vehicle_id = $4::uuid, driver_id = $5::uuid,
           attendant_id = $6::uuid, assignment_id = $7::uuid
       WHERE route_id = $1::uuid
         AND service_date BETWEEN $2::date AND COALESCE($3::date, $2::date)
         AND status = 'scheduled'
       RETURNING id`,
      [
        rows[0].route_id,
        rows[0].effective_from,
        rows[0].effective_to,
        permanent?.vehicle_id ?? null,
        permanent?.driver_id ?? null,
        permanent?.attendant_id ?? null,
        permanent?.id ?? null,
      ],
    );

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit(
        "transport.assignment.substitution_cancelled",
        "transport_route",
        rows[0].route_id,
        { assignmentId: id, tripsRebound: rebound.length },
      ),
      request,
    );
    return {
      payload: { assignmentId: id, removed: true, tripsRebound: rebound.length },
      status: 200,
    };
  });
}

// ─── BUS-050: driver availability ────────────────────────────────────────────

/**
 * POST /transport/v2/drivers/{id}/availability
 *
 * Records leave/sick/rest as a DATED row. This is what raises the
 * substitution-needed flag: without dates, a school cannot know a route will be
 * unstaffed tomorrow, and the gap surfaces when a bus fails to arrive.
 */
export async function handleSetDriverAvailabilityV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const driverId = pathSegment(request, 3);
    if (!driverId) throw new WriteNotFoundError("Driver id is required");

    const from = dateField(body, "fromDate", "from_date") ?? today();
    const to = dateField(body, "toDate", "to_date") ?? from;
    if (to < from) {
      throw new WriteValidationError(
        "toDate cannot be before fromDate",
        422,
        "INVALID_DATE_RANGE",
      );
    }
    const kind = str(body, "kind") ?? "leave";
    if (!["leave", "sick", "rest", "suspended", "training"].includes(kind)) {
      throw new WriteValidationError(
        "kind must be leave, sick, rest, suspended or training",
        422,
        "INVALID_KIND",
      );
    }

    const rows = await db.queryObject<{ id: string }>(
      `INSERT INTO transport_driver_availability
         (organization_id, school_id, driver_id, from_date, to_date, kind,
          reason, recorded_by)
       VALUES ($1, $2, $3::uuid, $4::date, $5::date, $6, $7, $8)
       RETURNING id`,
      [
        organizationId,
        schoolId,
        driverId,
        from,
        to,
        kind,
        str(body, "reason") ?? "",
        claims.sub,
      ],
    );

    // Which routes does this leave leave uncovered? Surfaced immediately so the
    // admin can arrange a substitute now rather than discovering it at 7 a.m.
    const affected = await db.queryObject<{ route_id: string; route_name: string }>(
      `SELECT DISTINCT r.id AS route_id, r.name AS route_name
       FROM transport_assignment a
       JOIN transport_route r ON r.id = a.route_id
       WHERE a.driver_id = $1::uuid
         AND r.status = 'active'
         AND daterange(a.effective_from, COALESCE(a.effective_to, 'infinity'::date), '[]')
             && daterange($2::date, $3::date, '[]')
       ORDER BY r.name`,
      [driverId, from, to],
    );

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.driver.availability_set", "transport_driver", driverId, {
        kind,
        from,
        to,
        routesNeedingSubstitute: affected.length,
      }),
      request,
    );
    return {
      payload: {
        id: rows[0].id,
        driverId,
        kind,
        fromDate: from,
        toDate: to,
        routesNeedingSubstitute: affected,
      },
      status: 201,
    };
  });
}

// ─── BUS-044: the capacity guard, finally reachable ─────────────────────────

/**
 * POST /transport/v2/routes/{id}/capacity-check
 *
 * Exposes the revived guard so the allocation UI can warn BEFORE a save fails.
 *
 * The guard itself was never broken — it was unreachable. It resolved capacity
 * from the route's assigned vehicle, and no endpoint wrote that field, so
 * capacity was always null and the check always returned early. Now that
 * BUS-043 exists, `routeCapacity()` resolves a real number from the effective
 * assignment's vehicle and the guard does its job.
 */
export async function handleRouteCapacityV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, req: request } = ctx;
    const routeId = pathSegment(request, 3);
    if (!routeId) throw new WriteNotFoundError("Route id is required");

    const onDate = dateField(body, "serviceDate", "service_date") ?? today();
    const cap = await routeCapacity(db, { organizationId, schoolId }, routeId, onDate);
    if (!cap) throw new WriteNotFoundError(`Transport route not found: ${routeId}`);

    const adding = Number(body.adding ?? 0) || 0;
    const projected = cap.current + adding;
    return {
      payload: {
        routeId,
        routeName: cap.routeName,
        // null = no vehicle assigned yet, so capacity is UNBOUNDED rather than
        // zero. Reporting 0 would read as "this bus has no seats".
        capacity: cap.capacity,
        current: cap.current,
        projected,
        wouldExceed: cap.capacity !== null && projected > cap.capacity,
        unbounded: cap.capacity === null,
      },
      status: 200,
    };
  });
}

/** GET-shaped: routes with no resolvable crew for a date (BUS-050 dashboard feed). */
export async function handleUnstaffedRoutesV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body } = ctx;
    const onDate = dateField(body, "serviceDate", "service_date") ?? today();
    const rows = await unstaffedRoutes(db, { organizationId, schoolId }, onDate);
    return { payload: { serviceDate: onDate, routes: rows, count: rows.length }, status: 200 };
  });
}

// ─── BUS-045 + BUS-049: the delete guards, finally reachable ────────────────

/**
 * DELETE /transport/v2/vehicles/{id} — BUS-045.
 *
 * The pre-v2 guard matched `route.assignedBus` against a registration string.
 * Since nothing ever wrote that field it never matched, so a bus that 45
 * children rode could be deleted with no warning. Now it matches on the
 * assignment FK, and trip history blocks deletion outright.
 */
export async function handleDeleteVehicleV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const id = pathSegment(request, 3);
    if (!id) throw new WriteNotFoundError("Vehicle id is required");

    const usage = await db.queryObject<{
      assignments: string;
      trips: string;
      registration: string;
    }>(
      `SELECT
         (SELECT count(*) FROM transport_assignment WHERE vehicle_id = $1::uuid)::text AS assignments,
         (SELECT count(*) FROM transport_trip WHERE vehicle_id = $1::uuid)::text AS trips,
         (SELECT registration FROM transport_vehicle WHERE id = $1::uuid) AS registration`,
      [id],
    );
    if (!usage[0]?.registration) {
      throw new WriteNotFoundError(`Transport vehicle not found: ${id}`);
    }
    const assignments = parseInt(usage[0].assignments, 10);
    const trips = parseInt(usage[0].trips, 10);
    if (assignments > 0 || trips > 0) {
      throw new WriteValidationError(
        `Cannot delete vehicle ${usage[0].registration}: ${assignments} ` +
          `assignment(s) and ${trips} trip(s) reference it. Retire it instead so ` +
          `its history is preserved.`,
        409,
        "VEHICLE_IN_USE",
      );
    }

    await db.queryObject(
      `DELETE FROM transport_vehicle
       WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3`,
      [id, organizationId, schoolId],
    );
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.vehicle.deleted", "transport_vehicle", id, {
        removed: true,
      }),
      request,
    );
    return { payload: { id, removed: true }, status: 200 };
  });
}

/** DELETE /transport/v2/drivers/{id} — BUS-049, same reasoning. */
export async function handleDeleteDriverV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const id = pathSegment(request, 3);
    if (!id) throw new WriteNotFoundError("Driver id is required");

    const usage = await db.queryObject<{
      assignments: string;
      trips: string;
      name: string;
    }>(
      `SELECT
         (SELECT count(*) FROM transport_assignment
           WHERE driver_id = $1::uuid OR attendant_id = $1::uuid)::text AS assignments,
         (SELECT count(*) FROM transport_trip
           WHERE driver_id = $1::uuid OR attendant_id = $1::uuid)::text AS trips,
         (SELECT name FROM transport_driver WHERE id = $1::uuid) AS name`,
      [id],
    );
    if (!usage[0]?.name) {
      throw new WriteNotFoundError(`Transport driver not found: ${id}`);
    }
    const assignments = parseInt(usage[0].assignments, 10);
    const trips = parseInt(usage[0].trips, 10);
    if (assignments > 0 || trips > 0) {
      throw new WriteValidationError(
        `Cannot delete ${usage[0].name}: ${assignments} assignment(s) and ` +
          `${trips} trip(s) reference them. Deactivate instead so trip history ` +
          `keeps its driver.`,
        409,
        "DRIVER_IN_USE",
      );
    }

    await db.queryObject(
      `DELETE FROM transport_driver
       WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3`,
      [id, organizationId, schoolId],
    );
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.driver.deleted", "transport_driver", id, {
        removed: true,
      }),
      request,
    );
    return { payload: { id, removed: true }, status: 200 };
  });
}
