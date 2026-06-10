import type { AppConfig } from "../config.ts";
import { createModuleReadHandlers } from "../entity_read/module_read_handlers.ts";
import { hostelStore } from "./hostel_read_repository.ts";

const { handleSnapshot, handleList } = createModuleReadHandlers("viewHostel", hostelStore);

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_dashboard", "Failed to load hostel dashboard");
}

export async function handleStudents(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "student", "Failed to load hostel students");
}

export async function handleRooms(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "room", "Failed to load hostel rooms");
}

export async function handleAttendance(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "attendance", "Failed to load hostel attendance");
}

export async function handleLeave(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "leave_request", "Failed to load hostel leave requests");
}

export async function handleMess(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_mess", "Failed to load hostel mess data");
}

export async function handleVisitors(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_visitors", "Failed to load hostel visitors");
}

export async function handleReports(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_reports", "Failed to load hostel reports");
}

export async function handleOccupancyMetrics(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_occupancy", "Failed to load hostel occupancy");
}
