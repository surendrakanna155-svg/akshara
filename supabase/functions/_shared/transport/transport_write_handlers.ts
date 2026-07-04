import type { AppConfig } from "../config.ts";
import {
  boolOr,
  createModuleWriteHandlers,
  intOr,
  requireStr,
  str,
  WriteNotFoundError,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import { sendBroadcastMessage } from "../communication/communication_service.ts";
import { MAX_BULK_ITEMS } from "../http.ts";
import { resolveStudentId } from "../sis/sis_student_resolver.ts";
import { assignFeeStructure } from "../finance/finance_assignments_repository.ts";

const writeStore = createEntityWriteStore("transport_entities", "Transport");
const { runWrite } = createModuleWriteHandlers("manageTransport");

// ── TRN-2: strict ISO calendar-date validator ────────────────────────────────
// Document-expiry fields (vehicle insurance/fitness/puc/permit/roadTax, driver
// licence) must be real YYYY-MM-DD dates so TRN-8's within-N-days scan is exact.
// Rejects malformed input with a 422. Back-compat: legacy free-text values already
// stored are read through untouched — only NEW writes pass through this validator.
const ISO_DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** True when `value` is a strict, real ISO calendar date (YYYY-MM-DD). */
export function isStrictIsoDate(value: string): boolean {
  if (!ISO_DATE_RE.test(value)) return false;
  const [y, m, d] = value.split("-").map((p) => parseInt(p, 10));
  if (m < 1 || m > 12 || d < 1 || d > 31) return false;
  // Round-trip through Date to reject impossible calendar dates (e.g. 2026-02-30).
  const dt = new Date(Date.UTC(y, m - 1, d));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === m - 1 && dt.getUTCDate() === d;
}

/**
 * Reads an optional ISO-date field from the body. When present it MUST be a
 * strict YYYY-MM-DD (else 422); when absent returns undefined (field omitted).
 */
export function isoDateField(
  body: Record<string, unknown>,
  ...keys: string[]
): string | undefined {
  const raw = str(body, ...keys);
  if (raw === undefined) return undefined;
  if (!isStrictIsoDate(raw)) {
    throw new WriteValidationError(
      `${keys[0]} must be a valid ISO date (YYYY-MM-DD)`,
    );
  }
  return raw;
}

/** Number of whole days from `from` to the ISO date `iso` (positive = future). */
function daysUntilIso(iso: string, from: Date): number | null {
  if (!isStrictIsoDate(iso)) return null;
  const [y, m, d] = iso.split("-").map((p) => parseInt(p, 10));
  const target = Date.UTC(y, m - 1, d);
  const base = Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), from.getUTCDate());
  return Math.round((target - base) / 86_400_000);
}

/** The five vehicle document-expiry fields (payload key ↔ body camel/snake keys). */
const VEHICLE_EXPIRY_FIELDS: Array<[string, string, string]> = [
  ["insuranceExpiry", "insuranceExpiry", "insurance_expiry"],
  ["fitnessExpiry", "fitnessExpiry", "fitness_expiry"],
  ["pucExpiry", "pucExpiry", "puc_expiry"],
  ["permitExpiry", "permitExpiry", "permit_expiry"],
  ["roadTaxExpiry", "roadTaxExpiry", "road_tax_expiry"],
];

/** Extracts the `{id}` path segment for id-bearing routes (e.g. /transport/routes/{id}/activate). */
function pathSegment(req: Request, index: number): string | undefined {
  const segments = new URL(req.url).pathname.split("/").filter((s) => s.length > 0);
  return segments[index];
}

function routeNameById(
  routes: Array<Record<string, unknown>>,
  routeId: string,
): string {
  const route = routes.find((r) => String(r.id ?? "") === routeId);
  return (route?.name as string | undefined) ?? routeId;
}

function busById(
  routes: Array<Record<string, unknown>>,
  routeId: string,
): string {
  const route = routes.find((r) => String(r.id ?? "") === routeId);
  return (route?.assignedBus as string | undefined) ?? "";
}

/** POST /transport/routes — create a transport route. */
export async function handleCreateRoute(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const payload = {
      id,
      name: requireStr(body, "name"),
      stopCount: 0,
      distanceKm: str(body, "distanceKm", "distance_km") ?? "0 km",
      amDeparture: str(body, "amDeparture", "am_departure") ?? "7:00 AM",
      pmDeparture: str(body, "pmDeparture", "pm_departure") ?? "3:30 PM",
      assignedBus: "",
      studentCount: 0,
      status: "inactive",
      shift: str(body, "shift") ?? "am",
      stops: [],
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "route", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.route.created", "transport_route", id, {
        name: payload.name,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/**
 * POST /transport/attendance — record (or update) a transport pickup/drop
 * attendance entry. Each entry is its own `attendance` entity row so the
 * GET /transport/attendance list reads it back unchanged. Re-recording an
 * existing id replaces it.
 */
export async function handleRecordAttendance(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = str(body, "id") ?? crypto.randomUUID();
    const payload = {
      id,
      studentName: requireStr(body, "studentName", "student_name"),
      stopName: str(body, "stopName", "stop_name") ?? "",
      routeName: str(body, "routeName", "route_name") ?? "",
      scheduledTime: str(body, "scheduledTime", "scheduled_time") ?? "",
      actualTime: str(body, "actualTime", "actual_time") ?? "",
      status: str(body, "status") ?? "waiting",
      parentNotified: boolOr(body, false, "parentNotified", "parent_notified"),
      shift: str(body, "shift") ?? "am",
    };
    const existing = await writeStore.find(db, organizationId, schoolId, "attendance", id);
    const saved = existing
      ? (await writeStore.replace(db, organizationId, schoolId, "attendance", id, payload)) ?? payload
      : await writeStore.insert(db, organizationId, schoolId, "attendance", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.attendance.recorded", "transport_attendance", id, {
        status: payload.status,
      }),
      request,
    );
    return { payload: saved, status: existing ? 200 : 201 };
  });
}

/** POST /transport/routes/{id}/activate — activate an existing route. */
export async function handleActivateRoute(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const routeId = pathSegment(request, 2);
    if (!routeId) {
      throw new WriteNotFoundError("Route id is required");
    }
    const route = await writeStore.find(db, organizationId, schoolId, "route", routeId);
    if (!route) {
      throw new WriteNotFoundError(`Transport route not found: ${routeId}`);
    }
    const next = { ...route, status: "active" };
    const saved = await writeStore.replace(db, organizationId, schoolId, "route", routeId, next);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.route.activated", "transport_route", routeId, {}),
      request,
    );
    return { payload: saved ?? next, status: 200 };
  });
}

/** POST /transport/allocations — assign a student to a route. */
export async function handleAssignStudentTransport(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const routeId = requireStr(body, "routeId", "route_id");
    const routes = await writeStore.findAll(db, organizationId, schoolId, "route");
    const id = str(body, "allocationId", "allocation_id") ?? crypto.randomUUID();
    const sisStudentId = str(body, "sisStudentId", "sis_student_id") ?? "";
    const allowOverCapacity = boolOr(body, false, "allowOverCapacity", "allow_over_capacity");
    const payload = {
      id,
      studentName: str(body, "studentName", "student_name") ?? "",
      admissionNumber: str(body, "admissionNumber", "admission_number") ?? "",
      classLabel: str(body, "classLabel", "class_label") ?? "",
      pickupStop: requireStr(body, "pickupStop", "pickup_stop"),
      dropStop: requireStr(body, "dropStop", "drop_stop"),
      routeId,
      routeName: routeNameById(routes, routeId),
      busNumber: busById(routes, routeId),
      shift: str(body, "shift") ?? "both",
      sisStudentId,
      // SIS transport-flag handoff: the allocation row carries the student's SIS
      // id + an explicit enrolled flag. The SIS Student-360 read
      // (student_360_service.ts) matches this row back by sisStudentId, so a
      // student's profile surfaces "transport enrolled" without mutating the
      // students table. Idempotent — re-assign rewrites the same flag.
      transportEnrolled: true,
    };
    // Assign targets an existing unassigned allocation row (UI flow) OR creates a
    // new one when adding a student from SIS — upsert so a re-assign rewrites the
    // same row (idempotent) instead of colliding on the entity PK.
    const existing = await writeStore.find(db, organizationId, schoolId, "allocation", id);

    // TRN-7: capacity guard for a NEW placement onto this route. Take the route
    // row lock (SELECT … FOR UPDATE via mutateEntity), held to commit, so a
    // concurrent assign to the same route cannot over-fill the vehicle. A re-assign
    // that keeps the student on the SAME route adds no occupant, so it skips the
    // check; moving between routes / a brand-new allocation counts as +1.
    const alreadyOnThisRoute = existing != null && String(existing.routeId ?? "") === routeId;
    let overridden = false;
    if (!alreadyOnThisRoute) {
      const lockedRoute = await writeStore.mutateEntity(
        db,
        organizationId,
        schoolId,
        "route",
        routeId,
        (r) => r, // lock-only
      );
      if (lockedRoute) {
        const capCheck = await assertCapacity(
          db,
          organizationId,
          schoolId,
          lockedRoute,
          1,
          allowOverCapacity,
        );
        overridden = capCheck.overridden;
      }
    }

    const saved = existing
      ? (await writeStore.replace(db, organizationId, schoolId, "allocation", id, payload)) ?? payload
      : await writeStore.insert(db, organizationId, schoolId, "allocation", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.allocation.assigned", "transport_allocation", id, {
        routeId,
        sisStudentId,
      }),
      request,
    );
    if (overridden) {
      await emitMutationAudit(
        db,
        claims,
        moduleEntityAudit("transport.capacity.overridden", "transport_route", routeId, {
          routeId,
          allocationId: id,
          sisStudentId,
        }),
        request,
      );
    }
    return { payload: saved, status: 201 };
  });
}

/** POST /transport/allocations/{id}/transfer — move a student to a different route. */
export async function handleTransferStudentTransport(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const allocationId = pathSegment(request, 2);
    if (!allocationId) {
      throw new WriteNotFoundError("Allocation id is required");
    }
    const allocation = await writeStore.find(
      db,
      organizationId,
      schoolId,
      "allocation",
      allocationId,
    );
    if (!allocation) {
      throw new WriteNotFoundError(`Transport allocation not found: ${allocationId}`);
    }
    const targetRouteId = requireStr(body, "targetRouteId", "target_route_id", "routeId", "route_id");
    const routes = await writeStore.findAll(db, organizationId, schoolId, "route");
    const next = {
      ...allocation,
      routeId: targetRouteId,
      routeName: routeNameById(routes, targetRouteId),
      busNumber: busById(routes, targetRouteId),
      pickupStop: str(body, "pickupStop", "pickup_stop") ??
        (allocation.pickupStop as string | undefined) ?? "",
      dropStop: str(body, "dropStop", "drop_stop") ??
        (allocation.dropStop as string | undefined) ?? "",
    };
    const saved = await writeStore.replace(
      db,
      organizationId,
      schoolId,
      "allocation",
      allocationId,
      next,
    );
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.allocation.transferred", "transport_allocation", allocationId, {
        targetRouteId,
      }),
      request,
    );
    return { payload: saved ?? next, status: 200 };
  });
}

/** DELETE /transport/allocations/{id} — remove a student's transport allocation. */
export async function handleRemoveStudentTransport(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const allocationId = pathSegment(request, 2);
    if (!allocationId) {
      throw new WriteNotFoundError("Allocation id is required");
    }
    const allocation = await writeStore.find(
      db,
      organizationId,
      schoolId,
      "allocation",
      allocationId,
    );
    if (!allocation) {
      throw new WriteNotFoundError(`Transport allocation not found: ${allocationId}`);
    }
    await writeStore.remove(db, organizationId, schoolId, "allocation", allocationId);
    // Clear the route association so the cleared allocation reads as "unassigned".
    // Also drop the SIS transport-flag so the Student-360 read stops surfacing
    // the student as transport-enrolled.
    const cleared = {
      ...allocation,
      routeId: "",
      routeName: "",
      busNumber: "",
      transportEnrolled: false,
    };
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.allocation.removed", "transport_allocation", allocationId, {
        removed: true,
      }),
      request,
    );
    return { payload: cleared, status: 200 };
  });
}

/**
 * POST /transport/notify-delay — broadcast a delay notification to the parents
 * of students on a given route. The real, certifiable half of TR-07: GPS live
 * telemetry needs hardware, but a delay alert does not — it reuses the
 * Communication broadcast pipeline ({@link sendBroadcastMessage}) which queues
 * push deliveries out of the request cycle. `recipientCount` is the number of
 * students currently allocated to the route (the affected cohort).
 */
export async function handleNotifyRouteDelay(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const routeId = requireStr(body, "routeId", "route_id");
    const message = requireStr(body, "message");

    const routes = await writeStore.findAll(db, organizationId, schoolId, "route");
    const route = routes.find((r) => String(r.id ?? "") === routeId);
    if (!route) {
      throw new WriteNotFoundError(`Transport route not found: ${routeId}`);
    }
    const routeName = (route.name as string | undefined) ?? routeId;

    const allocations = await writeStore.findAll(db, organizationId, schoolId, "allocation");
    const affected = allocations.filter((a) => String(a.routeId ?? "") === routeId);

    const title = `Transport delay — ${routeName}`;
    await sendBroadcastMessage(
      db,
      claims,
      { audience: "parents", title, body: message },
      request,
    );

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.delay.notified", "transport_route", routeId, {
        routeId,
        recipientCount: affected.length,
      }),
      request,
    );

    return {
      payload: { routeId, routeName, recipientCount: affected.length },
      status: 200,
    };
  });
}

// ─── TRN-1: vehicle CRUD ──────────────────────────────────────────────────────

/** Normalized registration key for per-school vehicle uniqueness. */
export function regKey(value: string): string {
  return value.trim().toUpperCase();
}

/** POST /transport/vehicles — register a vehicle (unique registration per school). */
export async function handleCreateVehicle(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const registration = requireStr(body, "registration", "registrationNumber", "registration_number", "number");
    const existing = await writeStore.findAll(db, organizationId, schoolId, "vehicle");
    if (existing.some((v) => regKey(String(v.registration ?? "")) === regKey(registration))) {
      throw new WriteValidationError(
        `A vehicle with registration ${registration} already exists`,
        409,
        "DUPLICATE_REGISTRATION",
      );
    }
    const id = str(body, "id") ?? crypto.randomUUID();
    const payload: Record<string, unknown> = {
      id,
      registration,
      model: str(body, "model") ?? "",
      capacity: intOr(body, 0, "capacity"),
      status: str(body, "status") ?? "active",
    };
    // TRN-2: strict ISO document-expiry dates (validated; omitted keys are dropped).
    for (const [payloadKey, ...bodyKeys] of VEHICLE_EXPIRY_FIELDS) {
      const value = isoDateField(body, ...bodyKeys);
      if (value !== undefined) payload[payloadKey] = value;
    }
    const saved = await writeStore.insert(db, organizationId, schoolId, "vehicle", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.vehicle.created", "transport_vehicle", id, { registration }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** PUT /transport/vehicles/{id} — update a vehicle (registration stays unique). */
export async function handleUpdateVehicle(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = pathSegment(request, 2);
    if (!id) throw new WriteNotFoundError("Vehicle id is required");
    const current = await writeStore.find(db, organizationId, schoolId, "vehicle", id);
    if (!current) throw new WriteNotFoundError(`Transport vehicle not found: ${id}`);

    const next = { ...current };
    const registration = str(body, "registration", "registrationNumber", "registration_number", "number");
    if (registration !== undefined) {
      const all = await writeStore.findAll(db, organizationId, schoolId, "vehicle");
      if (all.some((v) => String(v.id ?? "") !== id && regKey(String(v.registration ?? "")) === regKey(registration))) {
        throw new WriteValidationError(
          `A vehicle with registration ${registration} already exists`,
          409,
          "DUPLICATE_REGISTRATION",
        );
      }
      next.registration = registration;
    }
    if (str(body, "model") !== undefined) next.model = str(body, "model");
    if ("capacity" in body) next.capacity = intOr(body, Number(current.capacity ?? 0), "capacity");
    if (str(body, "status") !== undefined) next.status = str(body, "status");
    for (const [payloadKey, ...bodyKeys] of VEHICLE_EXPIRY_FIELDS) {
      const value = isoDateField(body, ...bodyKeys);
      if (value !== undefined) next[payloadKey] = value;
    }
    const saved = await writeStore.replace(db, organizationId, schoolId, "vehicle", id, next);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.vehicle.updated", "transport_vehicle", id, {}),
      request,
    );
    return { payload: saved ?? next, status: 200 };
  });
}

/** DELETE /transport/vehicles/{id} — delete a vehicle (blocked if a route uses it). */
export async function handleDeleteVehicle(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const id = pathSegment(request, 2);
    if (!id) throw new WriteNotFoundError("Vehicle id is required");
    const vehicle = await writeStore.find(db, organizationId, schoolId, "vehicle", id);
    if (!vehicle) throw new WriteNotFoundError(`Transport vehicle not found: ${id}`);

    // Block deleting a vehicle referenced by an active route (by registration).
    const reg = regKey(String(vehicle.registration ?? ""));
    const routes = await writeStore.findAll(db, organizationId, schoolId, "route");
    const referencing = routes.find((r) =>
      regKey(String(r.assignedBus ?? "")) === reg &&
      reg.length > 0 &&
      String(r.status ?? "") === "active"
    );
    if (referencing) {
      throw new WriteValidationError(
        `Cannot delete vehicle ${vehicle.registration}: it is assigned to active route ${referencing.name ?? referencing.id}`,
        409,
        "VEHICLE_IN_USE",
      );
    }
    await writeStore.remove(db, organizationId, schoolId, "vehicle", id);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.vehicle.deleted", "transport_vehicle", id, { removed: true }),
      request,
    );
    return { payload: { id, removed: true }, status: 200 };
  });
}

// ─── TRN-1: driver CRUD ───────────────────────────────────────────────────────

/** Normalized licence key for per-school driver uniqueness. */
function licenceKey(value: string): string {
  return value.trim().toUpperCase();
}

/** POST /transport/drivers — register a driver (unique licence number per school). */
export async function handleCreateDriver(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const licenseNumber = requireStr(body, "licenseNumber", "license_number", "licence", "licenseNo");
    const existing = await writeStore.findAll(db, organizationId, schoolId, "driver");
    if (existing.some((d) => licenceKey(String(d.licenseNumber ?? "")) === licenceKey(licenseNumber))) {
      throw new WriteValidationError(
        `A driver with licence ${licenseNumber} already exists`,
        409,
        "DUPLICATE_LICENSE",
      );
    }
    const id = str(body, "id") ?? crypto.randomUUID();
    const payload: Record<string, unknown> = {
      id,
      name: requireStr(body, "name"),
      licenseNumber,
      phone: str(body, "phone") ?? "",
      status: str(body, "status") ?? "active",
    };
    // TRN-2: strict ISO licence-expiry date.
    const licenseExpiry = isoDateField(body, "licenseExpiry", "license_expiry", "licenceExpiry");
    if (licenseExpiry !== undefined) payload.licenseExpiry = licenseExpiry;

    const saved = await writeStore.insert(db, organizationId, schoolId, "driver", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.driver.created", "transport_driver", id, { licenseNumber }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** PUT /transport/drivers/{id} — update a driver (licence stays unique). */
export async function handleUpdateDriver(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = pathSegment(request, 2);
    if (!id) throw new WriteNotFoundError("Driver id is required");
    const current = await writeStore.find(db, organizationId, schoolId, "driver", id);
    if (!current) throw new WriteNotFoundError(`Transport driver not found: ${id}`);

    const next = { ...current };
    const licenseNumber = str(body, "licenseNumber", "license_number", "licence", "licenseNo");
    if (licenseNumber !== undefined) {
      const all = await writeStore.findAll(db, organizationId, schoolId, "driver");
      if (all.some((d) => String(d.id ?? "") !== id && licenceKey(String(d.licenseNumber ?? "")) === licenceKey(licenseNumber))) {
        throw new WriteValidationError(
          `A driver with licence ${licenseNumber} already exists`,
          409,
          "DUPLICATE_LICENSE",
        );
      }
      next.licenseNumber = licenseNumber;
    }
    if (str(body, "name") !== undefined) next.name = str(body, "name");
    if (str(body, "phone") !== undefined) next.phone = str(body, "phone");
    if (str(body, "status") !== undefined) next.status = str(body, "status");
    const licenseExpiry = isoDateField(body, "licenseExpiry", "license_expiry", "licenceExpiry");
    if (licenseExpiry !== undefined) next.licenseExpiry = licenseExpiry;

    const saved = await writeStore.replace(db, organizationId, schoolId, "driver", id, next);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.driver.updated", "transport_driver", id, {}),
      request,
    );
    return { payload: saved ?? next, status: 200 };
  });
}

/** DELETE /transport/drivers/{id} — delete a driver (blocked if a route uses them). */
export async function handleDeleteDriver(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const id = pathSegment(request, 2);
    if (!id) throw new WriteNotFoundError("Driver id is required");
    const driver = await writeStore.find(db, organizationId, schoolId, "driver", id);
    if (!driver) throw new WriteNotFoundError(`Transport driver not found: ${id}`);

    // Block deleting a driver referenced by an active route (by driver id).
    const routes = await writeStore.findAll(db, organizationId, schoolId, "route");
    const referencing = routes.find((r) =>
      String(r.assignedDriverId ?? "") === id && String(r.status ?? "") === "active"
    );
    if (referencing) {
      throw new WriteValidationError(
        `Cannot delete driver ${driver.name}: they are assigned to active route ${referencing.name ?? referencing.id}`,
        409,
        "DRIVER_IN_USE",
      );
    }
    await writeStore.remove(db, organizationId, schoolId, "driver", id);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.driver.deleted", "transport_driver", id, { removed: true }),
      request,
    );
    return { payload: { id, removed: true }, status: 200 };
  });
}

// ─── TRN-7: race-safe capacity guard ─────────────────────────────────────────

export class CapacityExceededError extends WriteValidationError {
  constructor(routeName: string, capacity: number, current: number) {
    super(
      `Route ${routeName} is at capacity (${current}/${capacity}); pass allowOverCapacity to override`,
      409,
      "CAPACITY_EXCEEDED",
    );
  }
}

/**
 * TRN-7 — resolve a route's effective capacity from its assigned vehicle, then
 * count the students already allocated to that route. Both reads happen while the
 * caller holds the route row lock (mutateEntity), so a concurrent assign to the
 * same route cannot slip past the check (no over-fill race). Returns null capacity
 * when the route has no assigned vehicle / capacity (guard is skipped — unbounded).
 */
export async function routeCapacityAndCount(
  db: Parameters<typeof writeStore.findAll>[0],
  organizationId: string,
  schoolId: string,
  route: Record<string, unknown>,
): Promise<{ capacity: number | null; current: number; routeName: string }> {
  const routeId = String(route.id ?? "");
  const routeName = (route.name as string | undefined) ?? routeId;
  const reg = regKey(String(route.assignedBus ?? ""));
  let capacity: number | null = null;
  if (reg.length > 0) {
    const vehicles = await writeStore.findAll(db, organizationId, schoolId, "vehicle");
    const vehicle = vehicles.find((v) => regKey(String(v.registration ?? "")) === reg);
    const cap = vehicle ? Number(vehicle.capacity ?? 0) : 0;
    capacity = Number.isFinite(cap) && cap > 0 ? cap : null;
  }
  const allocations = await writeStore.findAll(db, organizationId, schoolId, "allocation");
  const current = allocations.filter((a) => String(a.routeId ?? "") === routeId).length;
  return { capacity, current, routeName };
}

/**
 * TRN-7 — assert that adding `adding` NEW students to `route` will not exceed the
 * assigned vehicle's capacity, UNLESS `allowOverCapacity` is set. Called under the
 * route row lock so `current` is a consistent snapshot. `adding` must already
 * exclude students being re-assigned in place (they already count in `current`).
 * Returns whether the capacity was overridden (for a separate audit trail).
 */
export async function assertCapacity(
  db: Parameters<typeof writeStore.findAll>[0],
  organizationId: string,
  schoolId: string,
  route: Record<string, unknown>,
  adding: number,
  allowOverCapacity: boolean,
): Promise<{ overridden: boolean; capacity: number | null; current: number; routeName: string }> {
  const { capacity, current, routeName } = await routeCapacityAndCount(
    db,
    organizationId,
    schoolId,
    route,
  );
  if (capacity === null) {
    return { overridden: false, capacity, current, routeName };
  }
  const projected = current + adding;
  if (projected > capacity) {
    if (!allowOverCapacity) {
      throw new CapacityExceededError(routeName, capacity, current);
    }
    return { overridden: true, capacity, current, routeName };
  }
  return { overridden: false, capacity, current, routeName };
}

// ─── TRN-4: stop editor (row-locked RMW on the route's stops[]) ───────────────

/** Rewrites contiguous 1-based `sequence` values in array order. */
function resequence(stops: Array<Record<string, unknown>>): Array<Record<string, unknown>> {
  return stops.map((s, i) => ({ ...s, sequence: i + 1 }));
}

async function mutateRouteStops(
  ctx: Parameters<Parameters<typeof runWrite>[2]>[0],
  routeId: string,
  eventSlug: string,
  mutate: (stops: Array<Record<string, unknown>>) => Array<Record<string, unknown>>,
  auditMeta: Record<string, unknown>,
): Promise<{ payload: Record<string, unknown>; status: number }> {
  const { db, organizationId, schoolId, claims, req: request } = ctx;
  const saved = await writeStore.mutateEntity(
    db,
    organizationId,
    schoolId,
    "route",
    routeId,
    (route) => {
      const stops = Array.isArray(route.stops) ? (route.stops as Array<Record<string, unknown>>) : [];
      const nextStops = resequence(mutate(stops.map((s) => ({ ...s }))));
      return { ...route, stops: nextStops, stopCount: nextStops.length };
    },
  );
  if (!saved) throw new WriteNotFoundError(`Transport route not found: ${routeId}`);
  await emitMutationAudit(
    db,
    claims,
    moduleEntityAudit(eventSlug, "transport_route", routeId, auditMeta),
    request,
  );
  return { payload: saved, status: 200 };
}

/** POST /transport/routes/{id}/stops — append a stop. */
export async function handleAddStop(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const routeId = pathSegment(ctx.req, 2);
    if (!routeId) throw new WriteNotFoundError("Route id is required");
    const name = requireStr(ctx.body, "name", "stopName", "stop_name");
    const stopId = str(ctx.body, "stopId", "stop_id") ?? crypto.randomUUID();
    const pickupTime = str(ctx.body, "pickupTime", "pickup_time") ?? "";
    const dropTime = str(ctx.body, "dropTime", "drop_time") ?? "";
    return await mutateRouteStops(
      ctx,
      routeId,
      "transport.stop.added",
      (stops) => [...stops, { id: stopId, name, pickupTime, dropTime }],
      { stopId, name },
    );
  });
}

/** PUT /transport/routes/{id}/stops/{stopId} — update a stop's fields. */
export async function handleUpdateStop(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const routeId = pathSegment(ctx.req, 2);
    const stopId = pathSegment(ctx.req, 4);
    if (!routeId || !stopId) throw new WriteNotFoundError("Route id and stop id are required");
    return await mutateRouteStops(
      ctx,
      routeId,
      "transport.stop.updated",
      (stops) => {
        const idx = stops.findIndex((s) => String(s.id ?? "") === stopId);
        if (idx < 0) throw new WriteNotFoundError(`Transport stop not found: ${stopId}`);
        const s = stops[idx];
        const name = str(ctx.body, "name", "stopName", "stop_name");
        const pickupTime = str(ctx.body, "pickupTime", "pickup_time");
        const dropTime = str(ctx.body, "dropTime", "drop_time");
        stops[idx] = {
          ...s,
          ...(name !== undefined ? { name } : {}),
          ...(pickupTime !== undefined ? { pickupTime } : {}),
          ...(dropTime !== undefined ? { dropTime } : {}),
        };
        return stops;
      },
      { stopId },
    );
  });
}

/** DELETE /transport/routes/{id}/stops/{stopId} — remove a stop (resequences). */
export async function handleRemoveStop(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const routeId = pathSegment(ctx.req, 2);
    const stopId = pathSegment(ctx.req, 4);
    if (!routeId || !stopId) throw new WriteNotFoundError("Route id and stop id are required");
    return await mutateRouteStops(
      ctx,
      routeId,
      "transport.stop.removed",
      (stops) => {
        const next = stops.filter((s) => String(s.id ?? "") !== stopId);
        if (next.length === stops.length) {
          throw new WriteNotFoundError(`Transport stop not found: ${stopId}`);
        }
        return next;
      },
      { stopId },
    );
  });
}

/** POST /transport/routes/{id}/stops/reorder — reorder stops by an explicit id order. */
export async function handleReorderStops(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const routeId = pathSegment(ctx.req, 2);
    if (!routeId) throw new WriteNotFoundError("Route id is required");
    const order = ctx.body.stopOrder ?? ctx.body.stop_order ?? ctx.body.order;
    if (!Array.isArray(order) || order.length === 0) {
      throw new WriteValidationError("stopOrder must be a non-empty array of stop ids");
    }
    const orderIds = order.map((x) => String(x));
    return await mutateRouteStops(
      ctx,
      routeId,
      "transport.stops.reordered",
      (stops) => {
        const byId = new Map(stops.map((s) => [String(s.id ?? ""), s]));
        if (orderIds.length !== stops.length || orderIds.some((id) => !byId.has(id))) {
          throw new WriteValidationError(
            "stopOrder must be a permutation of the route's current stop ids",
          );
        }
        return orderIds.map((id) => byId.get(id)!);
      },
      { count: orderIds.length },
    );
  });
}

// ─── TRN-5: bulk allocation (reuses single-assign logic + TRN-7 guard) ────────

/** Builds the allocation payload for one student on a route/stop. */
function buildAllocationPayload(
  id: string,
  routeId: string,
  routeName: string,
  busNumber: string,
  fields: {
    studentName: string;
    admissionNumber: string;
    classLabel: string;
    pickupStop: string;
    dropStop: string;
    shift: string;
    sisStudentId: string;
  },
): Record<string, unknown> {
  return {
    id,
    studentName: fields.studentName,
    admissionNumber: fields.admissionNumber,
    classLabel: fields.classLabel,
    pickupStop: fields.pickupStop,
    dropStop: fields.dropStop,
    routeId,
    routeName,
    busNumber,
    shift: fields.shift,
    sisStudentId: fields.sisStudentId,
    transportEnrolled: true,
  };
}

/**
 * POST /transport/allocations/bulk — assign many students to a route/stop at once.
 * Students are given either as an explicit `sisStudentIds` list, or resolved from
 * a `className`/`sectionName` via the current SIS enrollments. Each student is
 * assigned with the SAME single-assign shape; the TRN-7 capacity guard runs ONCE
 * under the route lock for the whole batch. Returns a per-student partial result
 * {assigned, skipped:[{studentId, reason}]}.
 */
export async function handleBulkAllocateTransport(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const routeId = requireStr(body, "routeId", "route_id");
    const pickupStop = requireStr(body, "pickupStop", "pickup_stop");
    const dropStop = requireStr(body, "dropStop", "drop_stop");
    const shift = str(body, "shift") ?? "both";
    const allowOverCapacity = boolOr(body, false, "allowOverCapacity", "allow_over_capacity");

    const route = await writeStore.find(db, organizationId, schoolId, "route", routeId);
    if (!route) throw new WriteNotFoundError(`Transport route not found: ${routeId}`);
    const routeName = (route.name as string | undefined) ?? routeId;
    const busNumber = (route.assignedBus as string | undefined) ?? "";

    // Resolve the target students: explicit id list OR class/section roster.
    const explicitIds = Array.isArray(body.sisStudentIds)
      ? (body.sisStudentIds as unknown[]).map((x) => String(x))
      : Array.isArray(body.sis_student_ids)
      ? (body.sis_student_ids as unknown[]).map((x) => String(x))
      : [];
    // ENG-8 (SEC-11): cap the bulk id array before any per-row DB work.
    if (explicitIds.length > MAX_BULK_ITEMS) {
      throw new WriteValidationError(
        `Maximum ${MAX_BULK_ITEMS} student ids per request`,
      );
    }
    const className = str(body, "className", "class_name");
    const sectionName = str(body, "sectionName", "section_name");

    interface Target { rawId: string; sisStudentId: string; studentName: string; classLabel: string; admissionNumber: string }
    const targets: Target[] = [];
    const skipped: Array<{ studentId: string; reason: string }> = [];

    if (explicitIds.length > 0) {
      for (const rawId of explicitIds) {
        targets.push({ rawId, sisStudentId: rawId, studentName: "", classLabel: "", admissionNumber: "" });
      }
    } else if (className) {
      const rows = await db.queryObject<{
        student_id: string;
        display_name: string | null;
        class_name: string | null;
        section_name: string | null;
      }>(
        `SELECT e.student_id, s.display_name, e.class_name, e.section_name
         FROM sis_student_enrollments e
         JOIN students s ON s.id = e.student_id
           AND s.organization_id = e.organization_id AND s.school_id = e.school_id
         WHERE e.organization_id = $1 AND e.school_id = $2 AND e.is_current = true
           AND e.class_name = $3
           AND ($4::text IS NULL OR e.section_name = $4)
         ORDER BY e.student_id`,
        [organizationId, schoolId, className, sectionName ?? null],
      );
      for (const r of rows) {
        targets.push({
          rawId: r.student_id,
          sisStudentId: r.student_id,
          studentName: r.display_name ?? "",
          classLabel: [r.class_name, r.section_name].filter(Boolean).join("-"),
          admissionNumber: "",
        });
      }
    } else {
      throw new WriteValidationError(
        "Provide either sisStudentIds or a className to bulk-allocate",
      );
    }

    // TRN-7: take the route row lock FIRST (SELECT … FOR UPDATE via mutateEntity),
    // held until this tenant transaction commits, so a concurrent bulk/single
    // assign to the same route is serialized and cannot over-fill the vehicle.
    const lockedRoute = await writeStore.mutateEntity(
      db,
      organizationId,
      schoolId,
      "route",
      routeId,
      (r) => r, // lock-only: no route field changes here
    );
    if (!lockedRoute) throw new WriteNotFoundError(`Transport route not found: ${routeId}`);

    // Count current occupants under the lock; re-assigns of students already on
    // this route do not add to the projected count.
    const existingAllocations = await writeStore.findAll(db, organizationId, schoolId, "allocation");
    const alreadyOnRoute = new Set(
      existingAllocations
        .filter((a) => String(a.routeId ?? "") === routeId)
        .map((a) => String(a.sisStudentId ?? "")),
    );
    const newcomers = targets.filter((t) => !alreadyOnRoute.has(t.sisStudentId)).length;

    const capCheck = await assertCapacity(
      db,
      organizationId,
      schoolId,
      lockedRoute,
      newcomers,
      allowOverCapacity,
    );
    const overridden = capCheck.overridden;

    // Assign each student (upsert by allocation id keyed on sisStudentId+route).
    const assigned: string[] = [];
    for (const t of targets) {
      const sisStudentId = t.sisStudentId;
      if (!sisStudentId) {
        skipped.push({ studentId: t.rawId, reason: "empty student id" });
        continue;
      }
      const allocId = `${routeId}:${sisStudentId}`;
      const payload = buildAllocationPayload(allocId, routeId, routeName, busNumber, {
        studentName: t.studentName,
        admissionNumber: t.admissionNumber,
        classLabel: t.classLabel,
        pickupStop,
        dropStop,
        shift,
        sisStudentId,
      });
      const existing = await writeStore.find(db, organizationId, schoolId, "allocation", allocId);
      if (existing) {
        await writeStore.replace(db, organizationId, schoolId, "allocation", allocId, payload);
      } else {
        await writeStore.insert(db, organizationId, schoolId, "allocation", allocId, payload);
      }
      await emitMutationAudit(
        db,
        claims,
        moduleEntityAudit("transport.allocation.assigned", "transport_allocation", allocId, {
          routeId,
          sisStudentId,
          bulk: true,
        }),
        request,
      );
      assigned.push(sisStudentId);
    }

    if (overridden) {
      await emitMutationAudit(
        db,
        claims,
        moduleEntityAudit("transport.capacity.overridden", "transport_route", routeId, {
          routeId,
          capacity: capCheck.capacity,
          assignedCount: assigned.length,
          bulk: true,
        }),
        request,
      );
    }

    return {
      payload: {
        routeId,
        assigned,
        assignedCount: assigned.length,
        skipped,
        capacityOverridden: overridden,
      },
      status: 200,
    };
  });
}

// ─── TRN-8: document-expiry reminder (in-app broadcast) ───────────────────────

/**
 * POST /transport/reminders/document-expiry — scan vehicles + drivers for TRN-2
 * document dates falling within N days (default 30), enqueue ONE in-app broadcast
 * summarising the upcoming expiries (external SMS/WA stays gated in the broadcast
 * pipeline), and audit the run with the count. Returns {reminded:0} when nothing
 * is due.
 */
export async function handleDocumentExpiryReminder(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const withinDays = intOr(body, 30, "withinDays", "within_days", "days");
    const now = new Date();

    const vehicles = await writeStore.findAll(db, organizationId, schoolId, "vehicle");
    const drivers = await writeStore.findAll(db, organizationId, schoolId, "driver");

    const expiries: Array<{ subject: string; document: string; expiresOn: string; inDays: number }> = [];
    for (const v of vehicles) {
      for (const [payloadKey] of VEHICLE_EXPIRY_FIELDS) {
        const raw = v[payloadKey];
        if (typeof raw !== "string") continue;
        const inDays = daysUntilIso(raw, now);
        if (inDays === null) continue; // legacy free-text — not a real date, skip
        if (inDays <= withinDays) {
          expiries.push({
            subject: `Vehicle ${v.registration ?? v.id}`,
            document: payloadKey.replace(/Expiry$/, ""),
            expiresOn: raw,
            inDays,
          });
        }
      }
    }
    for (const d of drivers) {
      const raw = d.licenseExpiry;
      if (typeof raw !== "string") continue;
      const inDays = daysUntilIso(raw, now);
      if (inDays === null) continue;
      if (inDays <= withinDays) {
        expiries.push({
          subject: `Driver ${d.name ?? d.id}`,
          document: "licence",
          expiresOn: raw,
          inDays,
        });
      }
    }

    if (expiries.length === 0) {
      return { payload: { reminded: 0, withinDays, expiries: [] }, status: 200 };
    }

    const lines = expiries
      .map((e) => `${e.subject}: ${e.document} expires ${e.expiresOn} (in ${e.inDays} day(s))`)
      .join("\n");
    await sendBroadcastMessage(
      db,
      claims,
      {
        audience: "staff",
        title: `Transport document expiries — ${expiries.length} upcoming`,
        body: lines,
      },
      request,
    );

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.document.reminded", "transport_school", schoolId, {
        count: expiries.length,
        withinDays,
      }),
      request,
    );

    return { payload: { reminded: expiries.length, withinDays, expiries }, status: 200 };
  });
}

// ─── TRN-9: raise a Finance transport-fee DEMAND (payment-free) ───────────────

/**
 * POST /transport/demands — Transport DEFINES a transport fee and RAISES a Finance
 * DEMAND only. It contains ZERO payment/collection logic: it never calls
 * createCollection and never touches finance_collections. It resolves the student
 * UUID (transport stores a display code), then calls Finance's `assignFeeStructure`
 * — which now GET-OR-CREATEs the student's per-year account (TRN-9 step 1) so a
 * transport invoice coexists with tuition under ONE account. The raised demand is
 * recorded as a transport `demand` entity keyed for idempotency on
 * (sisStudentId, routeId, academicYear, term): a re-raise for the same tuple
 * returns the existing demand and raises nothing new.
 */
export async function handleRaiseTransportDemand(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const sisStudentId = requireStr(body, "sisStudentId", "sis_student_id", "studentId", "student_id");
    const routeId = requireStr(body, "routeId", "route_id");
    const feeStructureId = requireStr(body, "feeStructureId", "fee_structure_id");
    const academicYear = requireStr(body, "academicYear", "academic_year");
    const term = str(body, "term") ?? "annual";
    const allocationId = str(body, "allocationId", "allocation_id") ?? "";

    // Idempotency: dedupe on (sisStudentId, routeId, academicYear, term).
    const dedupeKey = `${sisStudentId}::${routeId}::${academicYear}::${term}`;
    const existingDemands = await writeStore.findAll(db, organizationId, schoolId, "demand");
    const priorDemand = existingDemands.find((d) => String(d.dedupeKey ?? "") === dedupeKey);
    if (priorDemand) {
      // Re-raise is idempotent — return the existing demand, raise nothing new.
      return { payload: { ...priorDemand, idempotent: true }, status: 200 };
    }

    // Resolve the student UUID (transport stores a display code, not the PK).
    const studentUuid = await resolveStudentId(db, organizationId, schoolId, sisStudentId);
    if (!studentUuid) {
      throw new WriteNotFoundError(`Student not found for transport demand: ${sisStudentId}`);
    }

    // Raise the Finance demand ONLY (assignment + invoice + installments). Finance
    // collects — Transport never does. assignFeeStructure creates NO collection.
    const result = await assignFeeStructure(db, organizationId, schoolId, {
      studentId: studentUuid,
      feeStructureId,
      academicYear,
      assignedBy: claims.sub,
    });

    const demandId = crypto.randomUUID();
    const demandPayload = {
      id: demandId,
      dedupeKey,
      allocationId,
      sisStudentId,
      studentUuid,
      routeId,
      feeStructureId,
      academicYear,
      term,
      invoiceId: result.invoice.id,
      assignmentId: result.assignment.id,
      accountId: result.account.id,
      raisedAt: new Date().toISOString(),
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "demand", demandId, demandPayload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("transport.demand.raised", "transport_demand", demandId, {
        sisStudentId,
        routeId,
        academicYear,
        term,
        invoiceId: result.invoice.id,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}
