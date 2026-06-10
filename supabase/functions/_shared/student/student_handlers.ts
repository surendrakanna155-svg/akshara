import type { AppConfig } from "../config.ts";
import { createStudentScopedReadHandlers } from "../entity_read/mobile_read_handlers.ts";
import { studentStore } from "./student_read_repository.ts";

const { handleSnapshot, handleAttendanceSnapshot, handleTimetableSnapshot, handleList } =
  createStudentScopedReadHandlers(studentStore);

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_dashboard", "Failed to load student dashboard");
}

export async function handleAttendance(req: Request, config: AppConfig): Promise<Response> {
  return await handleAttendanceSnapshot(req, config, "Failed to load student attendance");
}

export async function handleHomework(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "homework_item", "Failed to load student homework");
}

export async function handleExams(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_exams", "Failed to load student exams");
}

export async function handleTimetable(req: Request, config: AppConfig): Promise<Response> {
  return await handleTimetableSnapshot(req, config, "Failed to load student timetable");
}

export async function handleNotices(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "notice", "Failed to load student notices");
}

export async function handleProfile(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_profile", "Failed to load student profile");
}
