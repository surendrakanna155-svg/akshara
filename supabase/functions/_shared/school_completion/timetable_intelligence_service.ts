import type { TenantQueryClient } from "../tenant_db.ts";
import { analyzeTimetableOptimization, computeQualityScore } from "../school_completion/timetable_optimization_service.ts";

export interface AcademicRoomRow {
  id: string;
  room_label: string;
  room_type: string;
  capacity: number;
  status: string;
}

export interface ExamTimetableRow {
  id: string;
  class_name: string;
  subject_label: string;
  exam_date: string;
  start_period: number;
  end_period: number;
  room_id: string | null;
  status: string;
}

export async function listRooms(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<AcademicRoomRow[]> {
  return await db.queryObject<AcademicRoomRow>(
    `SELECT id, room_label, room_type, capacity, status
     FROM academic_rooms
     WHERE organization_id = $1 AND school_id = $2 AND status = 'active'
     ORDER BY room_label`,
    [orgId, schoolId],
  );
}

export async function createRoom(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: { roomLabel: string; roomType?: string; capacity?: number },
): Promise<AcademicRoomRow> {
  const rows = await db.queryObject<AcademicRoomRow>(
    `INSERT INTO academic_rooms (organization_id, school_id, room_label, room_type, capacity)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, room_label, room_type, capacity, status`,
    [orgId, schoolId, input.roomLabel, input.roomType ?? "classroom", input.capacity ?? 40],
  );
  return rows[0]!;
}

export async function allocateRoomsForTimetable(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
): Promise<{ allocated: number; conflicts: string[] }> {
  const rooms = await listRooms(db, orgId, schoolId);
  const labRooms = rooms.filter((r) => r.room_type === "lab");
  const classRooms = rooms.filter((r) => r.room_type === "classroom");

  const periods = await db.queryObject<{
    id: string;
    subject_label: string;
    room_label: string;
  }>(
    `SELECT tp.id, tp.subject_label, tp.room_label
     FROM academic_timetable_periods tp
     JOIN academic_timetables t ON t.id = tp.timetable_id
     WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3`,
    [orgId, schoolId, academicYearId],
  );

  let allocated = 0;
  const conflicts: string[] = [];
  let classIdx = 0;
  let labIdx = 0;

  for (const period of periods) {
    if (period.room_label) continue;
    const isLab = /lab|science|physics|chemistry|biology/i.test(period.subject_label);
    const pool = isLab ? labRooms : classRooms;
    if (pool.length === 0) {
      conflicts.push(`No ${isLab ? "lab" : "classroom"} available for ${period.subject_label}`);
      continue;
    }
    const room = pool[(isLab ? labIdx++ : classIdx++) % pool.length]!;
    await db.queryObject(
      `UPDATE academic_timetable_periods SET room_label = $2 WHERE id = $1`,
      [period.id, room.room_label],
    );
    allocated++;
  }

  return { allocated, conflicts };
}

export async function generateExamTimetable(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: {
    academicYearId: string;
    className: string;
    subjects: string[];
    startDate: string;
  },
): Promise<ExamTimetableRow[]> {
  const rooms = await listRooms(db, orgId, schoolId);
  const defaultRoom = rooms[0]?.id ?? null;
  const created: ExamTimetableRow[] = [];
  let dayOffset = 0;

  for (const subject of input.subjects) {
    const examDate = new Date(input.startDate);
    examDate.setDate(examDate.getDate() + dayOffset);
    const rows = await db.queryObject<ExamTimetableRow>(
      `INSERT INTO exam_timetable_entries (
         organization_id, school_id, academic_year_id, class_name,
         subject_label, exam_date, start_period, end_period, room_id
       ) VALUES ($1, $2, $3, $4, $5, $6, 1, 2, $7)
       RETURNING id, class_name, subject_label, exam_date::text, start_period, end_period, room_id, status`,
      [orgId, schoolId, input.academicYearId, input.className, subject, examDate.toISOString().slice(0, 10), defaultRoom],
    );
    created.push(rows[0]!);
    dayOffset++;
  }
  return created;
}

export async function analyzeTimetableIntelligence(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId: string,
): Promise<{
  optimization: Awaited<ReturnType<typeof analyzeTimetableOptimization>>;
  roomUtilization: Array<{ roomLabel: string; periodCount: number; capacity: number }>;
  examCount: number;
  intelligenceScore: number;
}> {
  const optimization = await analyzeTimetableOptimization(db, orgId, schoolId, academicYearId);
  const rooms = await listRooms(db, orgId, schoolId);

  const roomUsage = await db.queryObject<{ room_label: string; count: string }>(
    `SELECT room_label, count(*)::text AS count
     FROM academic_timetable_periods tp
     JOIN academic_timetables t ON t.id = tp.timetable_id
     WHERE t.organization_id = $1 AND t.school_id = $2 AND t.academic_year_id = $3
       AND room_label != ''
     GROUP BY room_label`,
    [orgId, schoolId, academicYearId],
  );
  const usageMap = new Map(roomUsage.map((r) => [r.room_label, Number(r.count)]));

  const roomUtilization = rooms.map((r) => ({
    roomLabel: r.room_label,
    periodCount: usageMap.get(r.room_label) ?? 0,
    capacity: r.capacity,
  }));

  const exams = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count FROM exam_timetable_entries
     WHERE organization_id = $1 AND school_id = $2 AND academic_year_id = $3`,
    [orgId, schoolId, academicYearId],
  );

  const overCapacity = roomUtilization.filter((r) => r.periodCount > r.capacity * 5).length;
  const intelligenceScore = computeQualityScore({
    conflictCount: optimization.conflictCount,
    overloadCount: optimization.overloadAlerts.length,
    gapCount: overCapacity,
    timetableCount: roomUtilization.length || 1,
  });

  return {
    optimization,
    roomUtilization,
    examCount: Number(exams[0]?.count ?? 0),
    intelligenceScore,
  };
}

export function roomToApi(r: AcademicRoomRow) {
  return {
    id: r.id,
    roomLabel: r.room_label,
    roomType: r.room_type,
    capacity: r.capacity,
    status: r.status,
  };
}

export function examToApi(e: ExamTimetableRow) {
  return {
    id: e.id,
    className: e.class_name,
    subjectLabel: e.subject_label,
    examDate: e.exam_date,
    startPeriod: e.start_period,
    endPeriod: e.end_period,
    roomId: e.room_id,
    status: e.status,
  };
}
