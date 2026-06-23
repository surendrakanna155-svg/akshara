import type { AppConfig } from "../config.ts";
import {
  createModuleWriteHandlers,
  intOr,
  requireStr,
  str,
  WriteNotFoundError,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";

const writeStore = createEntityWriteStore("hostel_entities", "Hostel");
const { runWrite } = createModuleWriteHandlers("manageHostel");

/** POST /hostel/students — admit a student into the hostel. */
export async function handleAdmitStudent(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const payload = {
      id,
      studentName: requireStr(body, "studentName", "student_name"),
      admissionNumber: requireStr(body, "admissionNumber", "admission_number"),
      classLabel: str(body, "classLabel", "class_label") ?? "",
      block: "",
      room: "",
      bed: "",
      sisStudentId: str(body, "sisStudentId", "sis_student_id") ?? "",
      status: "awaitingAllocation",
      feePending: "₹0",
      parentAppLinked: false,
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "student", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hostel.student.admitted", "hostel_student", id, {
        admissionNumber: payload.admissionNumber,
        sisStudentId: payload.sisStudentId,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** POST /hostel/students/{id}/room — assign a room/bed to a hostel student. */
export function handleAssignRoom(hostelStudentId: string) {
  return async (req: Request, config: AppConfig): Promise<Response> => {
    return await runWrite(req, config, async (ctx) => {
      const { db, organizationId, schoolId, body, claims, req: request } = ctx;
      const roomId = requireStr(body, "roomId", "room_id");
      const bed = requireStr(body, "bed");

      const student = await writeStore.find(
        db,
        organizationId,
        schoolId,
        "student",
        hostelStudentId,
      );
      if (!student) {
        throw new WriteNotFoundError(`Hostel student not found: ${hostelStudentId}`);
      }

      const room = await writeStore.find(db, organizationId, schoolId, "room", roomId);
      const block = (room?.block as string | undefined) ?? "";
      const roomNumber = (room?.roomNumber as string | undefined) ?? roomId;

      const nextStudent = {
        ...student,
        block,
        room: roomNumber,
        bed,
        status: "resident",
      };
      const saved = await writeStore.replace(
        db,
        organizationId,
        schoolId,
        "student",
        hostelStudentId,
        nextStudent,
      ) ?? nextStudent;

      // Keep room occupancy consistent when the room is tracked.
      if (room) {
        const total = intOr(room, 0, "totalBeds");
        const occupied = Math.min(
          total === 0 ? Number.MAX_SAFE_INTEGER : total,
          intOr(room, 0, "occupiedBeds") + 1,
        );
        const nextStatus = total > 0 && occupied >= total ? "occupied" : "vacant";
        await writeStore.replace(db, organizationId, schoolId, "room", roomId, {
          ...room,
          occupiedBeds: occupied,
          status: nextStatus,
        });
      }

      await emitMutationAudit(
        db,
        claims,
        moduleEntityAudit("hostel.room.assigned", "hostel_student", hostelStudentId, {
          roomId,
          bed,
        }),
        request,
      );
      return { payload: saved, status: 200 };
    });
  };
}

/** POST /hostel/students/{id}/checkout — check a student out of the hostel. */
export function handleCheckoutStudent(hostelStudentId: string) {
  return async (req: Request, config: AppConfig): Promise<Response> => {
    return await runWrite(req, config, async (ctx) => {
      const { db, organizationId, schoolId, claims, req: request } = ctx;

      const student = await writeStore.find(
        db,
        organizationId,
        schoolId,
        "student",
        hostelStudentId,
      );
      if (!student) {
        throw new WriteNotFoundError(`Hostel student not found: ${hostelStudentId}`);
      }

      const nextStudent = {
        ...student,
        status: "checkedOut",
      };
      const saved = await writeStore.replace(
        db,
        organizationId,
        schoolId,
        "student",
        hostelStudentId,
        nextStudent,
      ) ?? nextStudent;

      await emitMutationAudit(
        db,
        claims,
        moduleEntityAudit("hostel.student.checked_out", "hostel_student", hostelStudentId, {}),
        request,
      );
      return { payload: saved, status: 200 };
    });
  };
}

/** POST /hostel/rooms — create a hostel room. */
export async function handleCreateRoom(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const totalBeds = Math.max(1, intOr(body, 1, "totalBeds", "total_beds"));
    const id = crypto.randomUUID();
    const payload = {
      id,
      block: requireStr(body, "block"),
      roomNumber: requireStr(body, "roomNumber", "room_number"),
      floor: intOr(body, 0, "floor"),
      type: str(body, "type") ?? "standard",
      totalBeds,
      occupiedBeds: 0,
      status: "vacant",
      facilities: str(body, "facilities") ?? "",
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "room", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hostel.room.created", "hostel_room", id, {
        roomNumber: payload.roomNumber,
        block: payload.block,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** POST /hostel/visitors — log a hostel visitor check-in. */
export async function handleLogVisitor(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const now = new Date();
    const payload = {
      id,
      visitorName: requireStr(body, "visitorName", "visitor_name"),
      relation: str(body, "relation") ?? "",
      studentName: requireStr(body, "studentName", "student_name"),
      sisStudentId: str(body, "sisStudentId", "sis_student_id") ?? "",
      checkIn: now.toISOString(),
      checkOut: null,
      passId: `VP-${now.getTime()}`,
      status: "active",
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "visitor", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hostel.visitor.logged", "hostel_visitor", id, {
        visitorName: payload.visitorName,
        sisStudentId: payload.sisStudentId,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}
