import type { AppConfig } from "../config.ts";
import {
  createModuleWriteHandlers,
  intOr,
  requireStr,
  str,
  WriteNotFoundError,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { routeReadiness } from "./transport_v2_repository.ts";

/**
 * BUS-033…BUS-042 — Transport v2 route & stop management.
 *
 * WHAT WAS MISSING BEFORE THIS FILE
 *
 * The pre-v2 module could CREATE a route and ACTIVATE it. That was all:
 *   * no PUT — a route created with a typo in its name was permanent, and its
 *     departure times could never be corrected;
 *   * no DELETE and no deactivate — a discontinued route stayed live forever,
 *     kept counting toward KPIs, and remained selectable for allocation;
 *   * creation was a SINGLE text field ("Route name"); distance, AM/PM
 *     departure and shift were silently hardcoded and, with no update endpoint,
 *     permanently uncorrectable;
 *   * activation ran with ZERO validation, so an admin could spend two hours
 *     configuring transport and activate a route that could never be tracked,
 *     with nothing on screen indicating incompleteness;
 *   * stops were a nested JSON array with no coordinates, unqueryable and
 *     unshareable between the AM and PM route.
 *
 * Every handler here operates on the Phase-2 relational tables. Nothing in this
 * file touches `transport_entities` (roadmap hard gate).
 */

const { runWrite } = createModuleWriteHandlers("manageTransport");

/** Shift/direction/status vocabularies, per TRANSPORT_DOMAIN_CONTRACT.md §1.2. */
const SHIFTS = new Set(["am", "pm"]);
const DIRECTIONS = new Set(["pickup", "drop"]);

/**
 * BUS-038 — parse an admin-supplied time into a strict `HH:MM` for a TIME column.
 *
 * Accepts 24h (`07:05`) and 12h (`7:05 AM`, `7:05am`) because both are natural to
 * type; normalises to 24h. Everything else is REJECTED rather than coerced.
 *
 * The pre-v2 field was unvalidated free text, so `"7.05"`, `"0705"` and
 * `"morning"` all persisted — which is precisely why schedule adherence, delay
 * detection and any ETA baseline were arithmetically impossible, and why the old
 * dashboard could display a hardcoded "94% On-Time" it could never compute.
 */
export function parseStopTime(raw: string): string | null {
  const value = raw.trim();
  if (value === "") return null;

  const ampm = value.match(/^(\d{1,2}):(\d{2})\s*([AaPp])\.?[Mm]\.?$/);
  if (ampm) {
    let hour = parseInt(ampm[1], 10);
    const minute = parseInt(ampm[2], 10);
    const isPm = ampm[3].toLowerCase() === "p";
    if (hour < 1 || hour > 12 || minute > 59) return null;
    if (isPm && hour !== 12) hour += 12;
    if (!isPm && hour === 12) hour = 0;
    return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
  }

  const h24 = value.match(/^(\d{1,2}):(\d{2})$/);
  if (h24) {
    const hour = parseInt(h24[1], 10);
    const minute = parseInt(h24[2], 10);
    if (hour > 23 || minute > 59) return null;
    return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
  }

  return null;
}

/** Reads an optional time field, rejecting anything unparseable with a 422. */
function timeField(
  body: Record<string, unknown>,
  ...keys: string[]
): string | null | undefined {
  const raw = str(body, ...keys);
  if (raw === undefined) return undefined;
  if (raw.trim() === "") return null;
  const parsed = parseStopTime(raw);
  if (parsed === null) {
    throw new WriteValidationError(
      `${keys[0]} must be a time like "07:05" or "7:05 AM"`,
      422,
      "INVALID_TIME",
    );
  }
  return parsed;
}

/** Extracts a path segment (e.g. /transport/v2/routes/{id} → index 3). */
function pathSegment(req: Request, index: number): string | undefined {
  return new URL(req.url).pathname.split("/").filter((s) => s.length > 0)[index];
}

// ─── BUS-035: create a route with EVERY field visible ────────────────────────

/**
 * POST /transport/v2/routes
 *
 * Every persisted attribute is either supplied or explicitly defaulted in a way
 * the admin can see and change afterwards (BUS-033). The pre-v2 handler hid four
 * hardcoded values behind a one-field dialog and gave no way to correct them.
 */
export async function handleCreateRouteV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;

    const name = requireStr(body, "name");
    const shift = str(body, "shift") ?? "am";
    const direction = str(body, "direction") ?? "pickup";
    if (!SHIFTS.has(shift)) {
      throw new WriteValidationError(`shift must be am or pm`, 422, "INVALID_SHIFT");
    }
    if (!DIRECTIONS.has(direction)) {
      throw new WriteValidationError(
        `direction must be pickup or drop`,
        422,
        "INVALID_DIRECTION",
      );
    }

    const rows = await db.queryObject<{ id: string }>(
      `INSERT INTO transport_route
         (organization_id, school_id, name, code, direction, shift, status,
          default_departure_time, default_return_time, distance_m)
       VALUES ($1, $2, $3, $4, $5, $6, 'draft', $7::time, $8::time, $9)
       RETURNING id`,
      [
        organizationId,
        schoolId,
        name,
        str(body, "code") ?? "",
        direction,
        shift,
        timeField(body, "defaultDepartureTime", "default_departure_time") ?? null,
        timeField(body, "defaultReturnTime", "default_return_time") ?? null,
        "distanceM" in body || "distance_m" in body
          ? intOr(body, 0, "distanceM", "distance_m")
          : null,
      ],
    );
    const id = rows[0].id;

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.route.created", "transport_route", id, {
        name,
        shift,
      }),
      request,
    );
    // Created as DRAFT, never active: BUS-042 requires a complete configuration
    // before a route may carry children.
    return { payload: { id, name, shift, direction, status: "draft" }, status: 201 };
  });
}

// ─── BUS-033: update a route ─────────────────────────────────────────────────

/**
 * PUT /transport/v2/routes/{id}
 *
 * THE endpoint that did not exist. Without it a route's name, code, direction,
 * shift, departure times and distance were all write-once — a typo was
 * permanent and a corrected timetable was unrepresentable.
 *
 * Partial update: only supplied fields change. An omitted field is left
 * untouched rather than overwritten with a default, which is the failure mode
 * that silently erased stop drop-times in the pre-v2 stop editor (BUS-007).
 */
export async function handleUpdateRouteV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = pathSegment(request, 3);
    if (!id) throw new WriteNotFoundError("Route id is required");

    const sets: string[] = [];
    const args: unknown[] = [organizationId, schoolId, id];
    const push = (frag: string, value: unknown) => {
      args.push(value);
      sets.push(`${frag} = $${args.length}`);
    };

    const name = str(body, "name");
    if (name !== undefined) {
      if (name.trim() === "") {
        throw new WriteValidationError("name cannot be blank", 422, "INVALID_NAME");
      }
      push("name", name.trim());
    }
    if (str(body, "code") !== undefined) push("code", str(body, "code"));

    const shift = str(body, "shift");
    if (shift !== undefined) {
      if (!SHIFTS.has(shift)) {
        throw new WriteValidationError("shift must be am or pm", 422, "INVALID_SHIFT");
      }
      push("shift", shift);
    }
    const direction = str(body, "direction");
    if (direction !== undefined) {
      if (!DIRECTIONS.has(direction)) {
        throw new WriteValidationError(
          "direction must be pickup or drop",
          422,
          "INVALID_DIRECTION",
        );
      }
      push("direction", direction);
    }

    const dep = timeField(body, "defaultDepartureTime", "default_departure_time");
    if (dep !== undefined) push("default_departure_time", dep);
    const ret = timeField(body, "defaultReturnTime", "default_return_time");
    if (ret !== undefined) push("default_return_time", ret);
    if ("distanceM" in body || "distance_m" in body) {
      push("distance_m", intOr(body, 0, "distanceM", "distance_m"));
    }

    if (sets.length === 0) {
      throw new WriteValidationError("No updatable field supplied", 422, "NO_CHANGES");
    }

    const rows = await db.queryObject<{ id: string; name: string; status: string }>(
      `UPDATE transport_route SET ${sets.join(", ")}
       WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid
       RETURNING id, name, status`,
      args,
    );
    if (rows.length === 0) {
      throw new WriteNotFoundError(`Transport route not found: ${id}`);
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.route.updated", "transport_route", id, {
        fields: sets.length,
      }),
      request,
    );
    return { payload: rows[0], status: 200 };
  });
}

// ─── BUS-034: deactivate / delete ────────────────────────────────────────────

/**
 * POST /transport/v2/routes/{id}/deactivate
 *
 * The reversible, history-preserving retirement a school actually needs. The
 * pre-v2 module had ONLY activate, so a discontinued route stayed active
 * forever — still counted in KPIs, still selectable for allocation.
 */
export async function handleDeactivateRouteV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const id = pathSegment(request, 3);
    if (!id) throw new WriteNotFoundError("Route id is required");

    const rows = await db.queryObject<{ id: string; active_allocations: string }>(
      `UPDATE transport_route SET status = 'inactive'
       WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid
       RETURNING id,
         (SELECT count(*) FROM transport_allocation a
           WHERE a.route_id = transport_route.id AND a.status = 'active')::text
           AS active_allocations`,
      [organizationId, schoolId, id],
    );
    if (rows.length === 0) {
      throw new WriteNotFoundError(`Transport route not found: ${id}`);
    }
    const stillAllocated = parseInt(rows[0].active_allocations, 10);

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.route.deactivated", "transport_route", id, {
        stillAllocated,
      }),
      request,
    );
    // Deactivation does NOT silently strip allocations — the admin is told how
    // many children still reference this route so they can re-home them.
    return {
      payload: { id, status: "inactive", studentsStillAllocated: stillAllocated },
      status: 200,
    };
  });
}

/**
 * DELETE /transport/v2/routes/{id}
 *
 * Hard-blocked whenever the route has any history or dependents. Deleting a
 * route that 45 children ride would be silent data loss, so deactivation is the
 * offered alternative — the same reasoning as the vehicle/driver in-use guards,
 * except those were dead code pre-v2 because the field they matched on was never
 * written.
 */
export async function handleDeleteRouteV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const id = pathSegment(request, 3);
    if (!id) throw new WriteNotFoundError("Route id is required");

    const deps = await db.queryObject<{
      allocations: string;
      trips: string;
      assignments: string;
    }>(
      `SELECT
         (SELECT count(*) FROM transport_allocation WHERE route_id = $1::uuid)::text AS allocations,
         (SELECT count(*) FROM transport_trip WHERE route_id = $1::uuid)::text AS trips,
         (SELECT count(*) FROM transport_assignment WHERE route_id = $1::uuid)::text AS assignments`,
      [id],
    );
    const d = deps[0];
    const blockers: string[] = [];
    if (parseInt(d?.allocations ?? "0", 10) > 0) blockers.push("has_allocations");
    if (parseInt(d?.trips ?? "0", 10) > 0) blockers.push("has_trip_history");
    if (parseInt(d?.assignments ?? "0", 10) > 0) blockers.push("has_assignments");

    if (blockers.length > 0) {
      throw new WriteValidationError(
        `Cannot delete this route: ${blockers.join(", ")}. Deactivate it instead ` +
          `so its history is preserved.`,
        409,
        "ROUTE_IN_USE",
      );
    }

    const rows = await db.queryObject<{ id: string }>(
      `DELETE FROM transport_route
       WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid
       RETURNING id`,
      [organizationId, schoolId, id],
    );
    if (rows.length === 0) {
      throw new WriteNotFoundError(`Transport route not found: ${id}`);
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.route.deleted", "transport_route", id, {
        removed: true,
      }),
      request,
    );
    return { payload: { id, removed: true }, status: 200 };
  });
}

// ─── BUS-042: publish gate ───────────────────────────────────────────────────

/**
 * POST /transport/v2/routes/{id}/activate
 *
 * Now GATED. The pre-v2 activate set status to 'active' with no validation at
 * all, which is how a route with zero located stops, no bus and no driver could
 * be marked live. Delegates to {@link routeReadiness} so the admin UI's
 * completeness meter (BUS-119) and this gate can never disagree.
 */
export async function handleActivateRouteV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const id = pathSegment(request, 3);
    if (!id) throw new WriteNotFoundError("Route id is required");

    const today = new Date().toISOString().slice(0, 10);
    const readiness = await routeReadiness(
      db,
      { organizationId, schoolId },
      id,
      today,
    );
    if (readiness.blockers.includes("route_not_found")) {
      throw new WriteNotFoundError(`Transport route not found: ${id}`);
    }
    if (!readiness.ready) {
      throw new WriteValidationError(
        `Route is not ready to activate: ${readiness.blockers.join(", ")}`,
        409,
        "ROUTE_INCOMPLETE",
      );
    }

    await db.queryObject(
      `UPDATE transport_route SET status = 'active'
       WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid`,
      [organizationId, schoolId, id],
    );
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.route.activated", "transport_route", id, {}),
      request,
    );
    return { payload: { id, status: "active" }, status: 200 };
  });
}

/** GET-shaped readiness probe so the UI can render the checklist before trying. */
export async function handleRouteReadinessV2(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, req: request } = ctx;
    const id = pathSegment(request, 3);
    if (!id) throw new WriteNotFoundError("Route id is required");
    const today = new Date().toISOString().slice(0, 10);
    const readiness = await routeReadiness(db, { organizationId, schoolId }, id, today);
    return { payload: { routeId: id, ...readiness }, status: 200 };
  });
}

// ─── BUS-036 / BUS-037: stop CRUD with MANDATORY coordinates ─────────────────

/**
 * Reads and validates a coordinate pair.
 *
 * BUS-037 — coordinates are MANDATORY on create. This is the gating requirement
 * for the entire tracking feature: without a stop's real location there is no
 * geofence, no distance-to-stop, no arrival detection, no ETA and no map. The
 * pre-v2 write path accepted only `{name, pickupTime, dropTime}`, so every stop
 * a real school created sat at 0°N 0°E — in the Atlantic off Ghana.
 *
 * (0,0) is rejected explicitly, not merely "out of range", because it is the
 * exact signature of a dropped coordinate rather than a typo.
 */
function requireCoordinate(
  body: Record<string, unknown>,
): { lat: number; lng: number } {
  const lat = Number(body.latitude ?? body.lat);
  const lng = Number(body.longitude ?? body.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    throw new WriteValidationError(
      "latitude and longitude are required — a stop without a location cannot " +
        "be tracked, geofenced, or used for an ETA",
      422,
      "STOP_LOCATION_REQUIRED",
    );
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw new WriteValidationError(
      "latitude must be -90..90 and longitude -180..180",
      422,
      "STOP_LOCATION_INVALID",
    );
  }
  if (Math.abs(lat) < 0.0001 && Math.abs(lng) < 0.0001) {
    throw new WriteValidationError(
      "(0, 0) is not a valid stop location — this is the value the pre-v2 " +
        "write path produced when it silently dropped coordinates",
      422,
      "STOP_LOCATION_INVALID",
    );
  }
  return { lat, lng };
}

/** POST /transport/v2/stops — create a school-level stop. */
export async function handleCreateStopV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const name = requireStr(body, "name");
    const { lat, lng } = requireCoordinate(body);
    const radius = intOr(body, 100, "geofenceRadiusM", "geofence_radius_m");
    if (radius < 20 || radius > 2000) {
      throw new WriteValidationError(
        "geofenceRadiusM must be between 20 and 2000 metres",
        422,
        "INVALID_GEOFENCE_RADIUS",
      );
    }

    const rows = await db.queryObject<{ id: string }>(
      `INSERT INTO transport_stop
         (organization_id, school_id, name, location, geofence_radius_m,
          address_text, landmark, status)
       VALUES ($1, $2, $3,
               ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography,
               $6, $7, $8, 'active')
       RETURNING id`,
      [
        organizationId,
        schoolId,
        name.trim(),
        lng,
        lat,
        radius,
        // BUS-037/P-7: geocoded ONCE by the client at pick time and stored.
        // Never re-geocoded on read — that is how map bills explode.
        str(body, "addressText", "address_text") ?? "",
        str(body, "landmark") ?? "",
      ],
    );
    const id = rows[0].id;

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.stop.created", "transport_stop", id, { name }),
      request,
    );
    return { payload: { id, name, latitude: lat, longitude: lng }, status: 201 };
  });
}

/**
 * PUT /transport/v2/stops/{id}
 *
 * Partial update. Supplying a coordinate also clears a `needs_location` state,
 * which is how BUS-030's migrated legacy stops get resolved — an admin places
 * the pin and the stop becomes publishable.
 */
export async function handleUpdateStopV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = pathSegment(request, 3);
    if (!id) throw new WriteNotFoundError("Stop id is required");

    const sets: string[] = [];
    const args: unknown[] = [organizationId, schoolId, id];
    const push = (frag: string, value: unknown) => {
      args.push(value);
      sets.push(`${frag} = $${args.length}`);
    };

    if (str(body, "name") !== undefined) push("name", str(body, "name")!.trim());
    if (str(body, "addressText", "address_text") !== undefined) {
      push("address_text", str(body, "addressText", "address_text"));
    }
    if (str(body, "landmark") !== undefined) push("landmark", str(body, "landmark"));
    if ("geofenceRadiusM" in body || "geofence_radius_m" in body) {
      const radius = intOr(body, 100, "geofenceRadiusM", "geofence_radius_m");
      if (radius < 20 || radius > 2000) {
        throw new WriteValidationError(
          "geofenceRadiusM must be between 20 and 2000 metres",
          422,
          "INVALID_GEOFENCE_RADIUS",
        );
      }
      push("geofence_radius_m", radius);
    }

    const hasCoord = body.latitude !== undefined || body.lat !== undefined;
    if (hasCoord) {
      const { lat, lng } = requireCoordinate(body);
      args.push(lng, lat);
      sets.push(
        `location = ST_SetSRID(ST_MakePoint($${args.length - 1}, $${args.length}), 4326)::geography`,
      );
      // Placing a pin on a migrated stop resolves its needs_location state.
      sets.push(`status = 'active'`);
    }

    if (sets.length === 0) {
      throw new WriteValidationError("No updatable field supplied", 422, "NO_CHANGES");
    }

    const rows = await db.queryObject<{ id: string; name: string; status: string }>(
      `UPDATE transport_stop SET ${sets.join(", ")}
       WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid
       RETURNING id, name, status`,
      args,
    );
    if (rows.length === 0) throw new WriteNotFoundError(`Transport stop not found: ${id}`);

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.stop.updated", "transport_stop", id, {
        locationSet: hasCoord,
      }),
      request,
    );
    return { payload: rows[0], status: 200 };
  });
}

/**
 * DELETE /transport/v2/stops/{id} — blocked while any route or allocation uses it.
 *
 * BUS-040: because stops are school-owned and shared, deleting one can affect
 * several routes at once. The rejection names the usage so the admin can see
 * what they would have broken.
 */
export async function handleDeleteStopV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const id = pathSegment(request, 3);
    if (!id) throw new WriteNotFoundError("Stop id is required");

    const usage = await db.queryObject<{ routes: string; allocations: string }>(
      `SELECT
         (SELECT count(*) FROM transport_route_stop WHERE stop_id = $1::uuid)::text AS routes,
         (SELECT count(*) FROM transport_allocation
           WHERE (pickup_stop_id = $1::uuid OR drop_stop_id = $1::uuid)
             AND status = 'active')::text AS allocations`,
      [id],
    );
    const routes = parseInt(usage[0]?.routes ?? "0", 10);
    const allocations = parseInt(usage[0]?.allocations ?? "0", 10);
    if (routes > 0 || allocations > 0) {
      throw new WriteValidationError(
        `Cannot delete this stop: used by ${routes} route(s) and ${allocations} ` +
          `student allocation(s). Detach it first, or retire it instead.`,
        409,
        "STOP_IN_USE",
      );
    }

    const rows = await db.queryObject<{ id: string }>(
      `DELETE FROM transport_stop
       WHERE organization_id = $1 AND school_id = $2 AND id = $3::uuid
       RETURNING id`,
      [organizationId, schoolId, id],
    );
    if (rows.length === 0) throw new WriteNotFoundError(`Transport stop not found: ${id}`);

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.stop.deleted", "transport_stop", id, { removed: true }),
      request,
    );
    return { payload: { id, removed: true }, status: 200 };
  });
}

// ─── BUS-039 / BUS-040: route ↔ stop sequence management ─────────────────────

/**
 * Locks a route row, then rewrites its stop sequence contiguously 1..n.
 *
 * PRESERVES the pre-v2 row-locked read-modify-write discipline verbatim: that
 * implementation understood lost updates and was genuinely well-engineered
 * (roadmap P-10). Only the storage beneath it changed — the sequence now lives
 * in `transport_route_stop` rather than an embedded JSON array.
 */
async function resequenceRouteStops(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  routeId: string,
): Promise<number> {
  const locked = await db.queryObject<{ id: string }>(
    `SELECT id FROM transport_route
     WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3
     FOR UPDATE`,
    [routeId, organizationId, schoolId],
  );
  if (locked.length === 0) {
    throw new WriteNotFoundError(`Transport route not found: ${routeId}`);
  }
  const rows = await db.queryObject<{ n: string }>(
    `WITH ordered AS (
       SELECT stop_id, row_number() OVER (ORDER BY sequence, stop_id) AS rn
       FROM transport_route_stop WHERE route_id = $1::uuid
     )
     UPDATE transport_route_stop rs
     SET sequence = o.rn
     FROM ordered o
     WHERE rs.route_id = $1::uuid AND rs.stop_id = o.stop_id
     RETURNING 1 AS n`,
    [routeId],
  );
  return rows.length;
}

/** POST /transport/v2/routes/{id}/stops — attach a stop with its times. */
export async function handleAttachStopV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const routeId = pathSegment(request, 3);
    if (!routeId) throw new WriteNotFoundError("Route id is required");
    const stopId = requireStr(body, "stopId", "stop_id");

    // A route may not include a stop that has no location — that would create a
    // route which can never be published (BUS-042) with no obvious cause.
    const stop = await db.queryObject<{ status: string }>(
      `SELECT status FROM transport_stop
       WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3`,
      [stopId, organizationId, schoolId],
    );
    if (stop.length === 0) throw new WriteNotFoundError(`Transport stop not found: ${stopId}`);
    if (stop[0].status === "needs_location") {
      throw new WriteValidationError(
        `Stop ${stopId} has no location yet. Place it on the map before adding ` +
          `it to a route.`,
        422,
        "STOP_LOCATION_REQUIRED",
      );
    }

    await db.queryObject(
      `INSERT INTO transport_route_stop
         (organization_id, school_id, route_id, stop_id, sequence,
          scheduled_pickup_time, scheduled_drop_time, dwell_seconds)
       VALUES ($1, $2, $3::uuid, $4::uuid,
               COALESCE((SELECT max(sequence) + 1 FROM transport_route_stop
                          WHERE route_id = $3::uuid), 1),
               $5::time, $6::time, $7)
       ON CONFLICT (route_id, stop_id) DO UPDATE SET
         scheduled_pickup_time = EXCLUDED.scheduled_pickup_time,
         scheduled_drop_time = EXCLUDED.scheduled_drop_time,
         dwell_seconds = EXCLUDED.dwell_seconds`,
      [
        organizationId,
        schoolId,
        routeId,
        stopId,
        timeField(body, "pickupTime", "pickup_time") ?? null,
        timeField(body, "dropTime", "drop_time") ?? null,
        intOr(body, 60, "dwellSeconds", "dwell_seconds"),
      ],
    );
    const count = await resequenceRouteStops(db, organizationId, schoolId, routeId);

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.stop.attached", "transport_route", routeId, {
        stopId,
      }),
      request,
    );
    return { payload: { routeId, stopId, stopCount: count }, status: 201 };
  });
}

/**
 * PUT /transport/v2/routes/{id}/stops/{stopId} — update times on one route-stop.
 *
 * BUS-007's lesson applied structurally: an OMITTED time is left untouched, never
 * overwritten. In the pre-v2 editor an unrelated edit silently erased the drop
 * time because the form submitted an empty value it had never loaded.
 */
export async function handleUpdateRouteStopV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const routeId = pathSegment(request, 3);
    const stopId = pathSegment(request, 5);
    if (!routeId || !stopId) {
      throw new WriteNotFoundError("Route id and stop id are required");
    }

    const sets: string[] = [];
    const args: unknown[] = [routeId, stopId];
    const push = (frag: string, value: unknown) => {
      args.push(value);
      sets.push(`${frag} = $${args.length}`);
    };

    const pickup = timeField(body, "pickupTime", "pickup_time");
    if (pickup !== undefined) push("scheduled_pickup_time", pickup);
    const drop = timeField(body, "dropTime", "drop_time");
    if (drop !== undefined) push("scheduled_drop_time", drop);
    if ("dwellSeconds" in body || "dwell_seconds" in body) {
      push("dwell_seconds", intOr(body, 60, "dwellSeconds", "dwell_seconds"));
    }
    if (sets.length === 0) {
      throw new WriteValidationError("No updatable field supplied", 422, "NO_CHANGES");
    }

    const rows = await db.queryObject<{ stop_id: string }>(
      `UPDATE transport_route_stop SET ${sets.join(", ")}
       WHERE route_id = $1::uuid AND stop_id = $2::uuid
         AND organization_id = $${args.push(organizationId)}
         AND school_id = $${args.push(schoolId)}
       RETURNING stop_id`,
      args,
    );
    if (rows.length === 0) {
      throw new WriteNotFoundError(`Stop ${stopId} is not on route ${routeId}`);
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.stop.updated", "transport_route", routeId, {
        stopId,
      }),
      request,
    );
    return { payload: { routeId, stopId }, status: 200 };
  });
}

/** DELETE /transport/v2/routes/{id}/stops/{stopId} — detach, then resequence. */
export async function handleDetachStopV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const routeId = pathSegment(request, 3);
    const stopId = pathSegment(request, 5);
    if (!routeId || !stopId) {
      throw new WriteNotFoundError("Route id and stop id are required");
    }

    // Detaching a stop that children are allocated to would orphan them.
    const allocated = await db.queryObject<{ n: string }>(
      `SELECT count(*)::text AS n FROM transport_allocation
       WHERE route_id = $1::uuid AND status = 'active'
         AND (pickup_stop_id = $2::uuid OR drop_stop_id = $2::uuid)`,
      [routeId, stopId],
    );
    const n = parseInt(allocated[0]?.n ?? "0", 10);
    if (n > 0) {
      throw new WriteValidationError(
        `Cannot remove this stop: ${n} student(s) are allocated to it on this ` +
          `route. Move them to another stop first.`,
        409,
        "STOP_HAS_ALLOCATIONS",
      );
    }

    const rows = await db.queryObject<{ stop_id: string }>(
      `DELETE FROM transport_route_stop
       WHERE route_id = $1::uuid AND stop_id = $2::uuid
         AND organization_id = $3 AND school_id = $4
       RETURNING stop_id`,
      [routeId, stopId, organizationId, schoolId],
    );
    if (rows.length === 0) {
      throw new WriteNotFoundError(`Stop ${stopId} is not on route ${routeId}`);
    }
    const count = await resequenceRouteStops(db, organizationId, schoolId, routeId);

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.stop.detached", "transport_route", routeId, {
        stopId,
      }),
      request,
    );
    return { payload: { routeId, stopId, stopCount: count }, status: 200 };
  });
}

/**
 * POST /transport/v2/routes/{id}/stops/reorder
 *
 * PRESERVES the pre-v2 permutation validation: the supplied order must be an
 * exact permutation of the route's current stop ids. A partial list would
 * silently drop stops from the route.
 */
export async function handleReorderStopsV2(req: Request, config: AppConfig) {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const routeId = pathSegment(request, 3);
    if (!routeId) throw new WriteNotFoundError("Route id is required");

    const raw = body.stopOrder ?? body.stop_order ?? body.order;
    if (!Array.isArray(raw) || raw.length === 0) {
      throw new WriteValidationError(
        "stopOrder must be a non-empty array of stop ids",
        422,
        "INVALID_STOP_ORDER",
      );
    }
    const order = raw.map((x) => String(x));

    const locked = await db.queryObject<{ id: string }>(
      `SELECT id FROM transport_route
       WHERE id = $1::uuid AND organization_id = $2 AND school_id = $3
       FOR UPDATE`,
      [routeId, organizationId, schoolId],
    );
    if (locked.length === 0) {
      throw new WriteNotFoundError(`Transport route not found: ${routeId}`);
    }

    const current = await db.queryObject<{ stop_id: string }>(
      `SELECT stop_id FROM transport_route_stop WHERE route_id = $1::uuid`,
      [routeId],
    );
    const currentIds = new Set(current.map((r) => r.stop_id));
    if (
      order.length !== currentIds.size ||
      order.some((id) => !currentIds.has(id)) ||
      new Set(order).size !== order.length
    ) {
      throw new WriteValidationError(
        "stopOrder must be a permutation of the route's current stop ids",
        422,
        "INVALID_STOP_ORDER",
      );
    }

    // Two-phase to satisfy UNIQUE(route_id, sequence): park sequences in a
    // negative band, then write the target order.
    await db.queryObject(
      `UPDATE transport_route_stop SET sequence = -sequence WHERE route_id = $1::uuid`,
      [routeId],
    );
    for (let i = 0; i < order.length; i++) {
      await db.queryObject(
        `UPDATE transport_route_stop SET sequence = $3
         WHERE route_id = $1::uuid AND stop_id = $2::uuid`,
        [routeId, order[i], i + 1],
      );
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.stops.reordered", "transport_route", routeId, {
        count: order.length,
      }),
      request,
    );
    return { payload: { routeId, stopCount: order.length }, status: 200 };
  });
}
