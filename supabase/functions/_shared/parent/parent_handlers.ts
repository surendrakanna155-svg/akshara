import type { AppConfig } from "../config.ts";
import { createParentScopedReadHandlers } from "../entity_read/mobile_read_handlers.ts";
import { parentStore } from "./parent_read_repository.ts";

const {
  handleSnapshot,
  handleAttendanceSnapshot,
  handleTimetableSnapshot,
  handleList,
  handleDetail,
  handleFinanceReceipts,
} = createParentScopedReadHandlers(parentStore);

export async function handleDashboard(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_dashboard", "Failed to load parent dashboard");
}

export async function handleAttendance(req: Request, config: AppConfig): Promise<Response> {
  return await handleAttendanceSnapshot(req, config, "Failed to load parent attendance");
}

export async function handleHomework(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_homework", "Failed to load parent homework");
}

export async function handleExams(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_exams", "Failed to load parent exams");
}

export async function handleTimetable(req: Request, config: AppConfig): Promise<Response> {
  return await handleTimetableSnapshot(req, config, "Failed to load parent timetable");
}

export async function handleFees(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_fees", "Failed to load parent fees");
}

export async function handleReceipts(req: Request, config: AppConfig): Promise<Response> {
  // Real fee receipts from finance_receipts (not the stale parent_entities cache),
  // so a collection recorded by the office actually reaches the parent app.
  return await handleFinanceReceipts(req, config, "Failed to load parent receipts");
}

export async function handleNotices(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "notice", "Failed to load parent notices");
}

export async function handleEvents(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_events", "Failed to load parent events");
}

export async function handleLeave(req: Request, config: AppConfig): Promise<Response> {
  return await handleList(req, config, "leave_request", "Failed to load parent leave history");
}

export async function handleProfile(req: Request, config: AppConfig): Promise<Response> {
  return await handleSnapshot(req, config, "snapshot_profile", "Failed to load parent profile");
}

export async function handlePaymentSummary(
  req: Request,
  config: AppConfig,
  installmentId: string,
): Promise<Response> {
  return await handleDetail(
    req,
    config,
    "payment_summary",
    installmentId,
    "Failed to load payment summary",
  );
}
