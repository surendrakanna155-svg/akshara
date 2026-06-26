import type { AppConfig } from "../config.ts";
import {
  boolOr,
  createModuleWriteHandlers,
  requireStr,
  str,
  WriteNotFoundError,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import { sendBroadcastMessage } from "../communication/communication_service.ts";

const writeStore = createEntityWriteStore("transport_entities", "Transport");
const { runWrite } = createModuleWriteHandlers("manageTransport");

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
