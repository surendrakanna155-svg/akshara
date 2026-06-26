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
import type { TenantQueryClient } from "../tenant_db.ts";

const writeStore = createEntityWriteStore("hostel_entities", "Hostel");
const { runWrite } = createModuleWriteHandlers("manageHostel");

/** Entity-store key under which hostel leave/gate-pass requests are stored. */
export const HOSTEL_LEAVE_ENTITY_TYPE = "leave_request";

/**
 * Flips a hostel leave request's status to `approved`/`rejected`. Called by the
 * generic approval engine when a hostel-leave approval is decided, so the
 * approval decision actually mutates the underlying `hostel_entities` row
 * (not just the approval audit/effect record). Returns the updated payload, or
 * null when no matching leave row exists. Tenant RLS (`manageHostel` scope) is
 * already enforced by the approval decision path's tenant context.
 */
export async function flipHostelLeaveStatus(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leaveRequestId: string,
  status: "approved" | "rejected",
): Promise<Record<string, unknown> | null> {
  const existing = await writeStore.find(
    db,
    organizationId,
    schoolId,
    HOSTEL_LEAVE_ENTITY_TYPE,
    leaveRequestId,
  );
  if (!existing) return null;
  const next = { ...existing, status };
  return await writeStore.replace(
    db,
    organizationId,
    schoolId,
    HOSTEL_LEAVE_ENTITY_TYPE,
    leaveRequestId,
    next,
  ) ?? next;
}

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

/** Hostel attendance status values accepted from the client (mirror `HostelAttendanceStatus`). */
const HOSTEL_ATTENDANCE_STATUSES = ["present", "absent", "onLeave"] as const;

/** Normalises a body session field to a valid attendance status, defaulting to `present`. */
function attendanceStatus(
  body: Record<string, unknown>,
  fallback: string,
  ...keys: string[]
): string {
  const value = str(body, ...keys);
  if (value && (HOSTEL_ATTENDANCE_STATUSES as readonly string[]).includes(value)) {
    return value;
  }
  return fallback;
}

/** Worst-of the three sessions decides the overall status shown on the roster. */
function overallAttendanceStatus(
  morning: string,
  evening: string,
  night: string,
): string {
  const sessions = [morning, evening, night];
  if (sessions.includes("absent")) return "absent";
  if (sessions.includes("onLeave")) return "onLeave";
  return "present";
}

/**
 * POST /hostel/attendance — record a hostel attendance roster row (HOSTE-1).
 * Inserts an `attendance` entity in the exact shape the Attendance screen mapper
 * reads, so the just-recorded row appears immediately on the read
 * (`handleAttendance` is already a `handleList(...,'attendance',...)`).
 */
export async function handleRecordHostelAttendance(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const studentName = requireStr(body, "studentName", "student_name");
    const morning = attendanceStatus(body, "present", "morning");
    const evening = attendanceStatus(body, morning, "evening");
    const night = attendanceStatus(body, evening, "night");
    const id = crypto.randomUUID();
    const payload = {
      id,
      studentName,
      room: str(body, "room") ?? "",
      rollNumber: str(body, "rollNumber", "roll_number") ?? "",
      morning,
      evening,
      night,
      overallStatus: overallAttendanceStatus(morning, evening, night),
      remark: str(body, "remark") ?? "",
      parentNotified: boolOr(body, false, "parentNotified", "parent_notified"),
      sisStudentId: str(body, "sisStudentId", "sis_student_id") ?? "",
    };
    const saved = await writeStore.insert(
      db,
      organizationId,
      schoolId,
      "attendance",
      id,
      payload,
    );
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hostel.attendance.recorded", "hostel_attendance", id, {
        studentName: payload.studentName,
        overallStatus: payload.overallStatus,
        sisStudentId: payload.sisStudentId,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/**
 * POST /hostel/mess — record today's mess menu + headcount + cost (HOSTE-3).
 * Inserts a `mess_record` entity that the Mess read (`handleMess`) recomputes
 * the live menu/cost from, so the just-recorded menu appears immediately.
 */
export async function handleRecordMess(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const day = requireStr(body, "day");
    const mealType = requireStr(body, "mealType", "meal_type");
    const items = requireStr(body, "items");
    const headcount = intOr(body, 0, "headcount");
    const costRupees = intOr(body, 0, "costRupees", "cost_rupees");
    if (headcount < 0 || costRupees < 0) {
      throw new WriteValidationError("headcount and cost must not be negative");
    }
    const id = crypto.randomUUID();
    const payload = {
      id,
      day,
      mealType,
      items,
      dietaryTags: ((): string[] => {
        const raw = body["dietaryTags"] ?? body["dietary_tags"];
        if (Array.isArray(raw)) {
          return raw.filter((tag) => tag != null).map((tag) => String(tag).trim())
            .filter((tag) => tag.length > 0);
        }
        const single = str(body, "dietaryTags", "dietary_tags");
        return single ? [single] : [];
      })(),
      headcount,
      costRupees,
      recordedAt: new Date().toISOString(),
    };
    const saved = await writeStore.insert(
      db,
      organizationId,
      schoolId,
      "mess_record",
      id,
      payload,
    );
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hostel.mess.recorded", "hostel_mess_record", id, {
        day: payload.day,
        mealType: payload.mealType,
        headcount: payload.headcount,
        costRupees: payload.costRupees,
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
