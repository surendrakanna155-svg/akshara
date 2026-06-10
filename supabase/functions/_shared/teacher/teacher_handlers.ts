import type { AppConfig } from "../config.ts";
import { createTeacherMobileReadHandlers } from "../entity_read/mobile_read_handlers.ts";
import { teacherStore } from "./teacher_read_repository.ts";

const { handleSnapshot, handleTimetableSnapshot, handleList } = createTeacherMobileReadHandlers(teacherStore);

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_dashboard", "Failed to load teacher dashboard");
}

export async function handleAttendanceClasses(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "attendance_class", "Failed to load attendance classes");
}

export async function handleAttendanceStudents(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(
    req,
    config,
    "snapshot_attendance_students",
    "Failed to load attendance students",
  );
}

export async function handleHomework(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "homework_assignment", "Failed to load homework assignments");
}

export async function handleExamsUpcoming(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "upcoming_exam", "Failed to load upcoming exams");
}

export async function handleExamsMarks(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "exam_mark", "Failed to load exam marks");
}

export async function handleTimetable(req: Request, config: AppConfig): Promise<Response> {
  return await handleTimetableSnapshot(req, config, "Failed to load teacher timetable");
}

export async function handleLeave(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "leave_request", "Failed to load teacher leave history");
}

export async function handleLeaveBalance(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_leave_balance", "Failed to load leave balance");
}

export async function handleMessages(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "message_thread", "Failed to load message threads");
}
