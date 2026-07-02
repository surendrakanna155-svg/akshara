// HR reporting / export READ handlers (HR-1, HR-2, HR-4, HR-5, HR-6, HR-7).
//
// All gate `viewHr` + school operational scope (same read gate as the rest of
// HR), run inside the tenant RLS context, and DERIVE their payload from the
// school's real rows via hr_reports_repository.ts. Reads only — no write guard,
// no schema change. The Flutter export service turns each payload into CSV/PDF
// client-side (all ride the XCT-1 grid primitive).

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import {
  buildExpiringDocuments,
  buildHeadcount,
  buildLeaveBalanceReport,
  buildPayslips,
  buildProbationEnding,
  buildSalaryRegister,
  DEFAULT_LATE_AFTER,
  inferMuster,
  loadCheckInEvents,
  loadDirectoryEmployees,
  loadEmployeePayloads,
  loadHeadcountEmployees,
  loadHolidayDays,
  loadLeavePolicy,
  loadLeaveSnapshot,
  loadMusterEmployees,
  loadPayrollSnapshot,
} from "./hr_reports_repository.ts";

/** viewHr + school operational scope — the shared HR read gate. */
function requireHrRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewHr") ??
    requireSchoolOperationalScope(claims);
}

// Default late cutoff (09:15) is DEFAULT_LATE_AFTER, shared from
// hr_reports_repository.ts so HR-6 and the TCH-9 self-history agree.

const MONTH_RE = /^\d{4}-(0[1-9]|1[0-2])$/;

/**
 * Common wrapper: authenticate → gate viewHr → run inside the tenant context →
 * envelope the computed payload, mapping the unconfigured-DB seam to 503.
 */
async function handleHrReport(
  req: Request,
  config: AppConfig,
  errorMessage: string,
  compute: (
    db: Parameters<Parameters<typeof withTenantContext>[2]>[0],
    orgId: string,
    schoolId: string,
    url: URL,
  ) => Promise<Record<string, unknown>>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireHrRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const url = new URL(req.url);

  try {
    const payload = await withTenantContext(config, auth.claims, (db) =>
      compute(db, orgId, schoolId, url)
    );
    return jsonResponse(envelope(payload));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof HrReportBadRequestError) {
      return errorEnvelope("BAD_REQUEST", error.message, 400);
    }
    console.error(`${errorMessage}:`, error);
    return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
  }
}

class HrReportBadRequestError extends Error {}

/** GET /hr/payroll/register?runId= — HR-1 salary register + column totals. */
export function handleSalaryRegister(req: Request, config: AppConfig): Promise<Response> {
  return handleHrReport(req, config, "Failed to build salary register", async (db, orgId, schoolId, url) => {
    const runId = url.searchParams.get("runId")?.trim() ?? "";
    if (runId === "") throw new HrReportBadRequestError("runId query parameter is required");
    const payroll = await loadPayrollSnapshot(db, orgId, schoolId);
    return buildSalaryRegister(payroll, runId) as unknown as Record<string, unknown>;
  });
}

/** GET /hr/payroll/payslips?runId= — HR-2 per-employee payslip data. */
export function handlePayslips(req: Request, config: AppConfig): Promise<Response> {
  return handleHrReport(req, config, "Failed to build payslips", async (db, orgId, schoolId, url) => {
    const runId = url.searchParams.get("runId")?.trim() ?? "";
    if (runId === "") throw new HrReportBadRequestError("runId query parameter is required");
    const payroll = await loadPayrollSnapshot(db, orgId, schoolId);
    return buildPayslips(payroll, runId) as unknown as Record<string, unknown>;
  });
}

/**
 * GET /hr/attendance/muster?month=YYYY-MM — HR-6 monthly attendance muster.
 *
 * Status is INFERRED from the staff_check_ins ledger (no attendance table):
 *   • a working day with a check-in → Present; Late when the earliest check-in is
 *     after `lateAfter` (default 09:15, returned in the payload);
 *   • a working day with NO check-in → Absent.
 * Holidays: days marked with a `holiday` school_calendar_events row are '-' and
 * excluded from the % denominator. When the calendar has NO holidays for the
 * month, EVERY day is treated as working (documented default — see the doc block
 * on inferMuster). `lateAfter` may be overridden with ?lateAfter=HH:MM.
 */
export function handleAttendanceMuster(req: Request, config: AppConfig): Promise<Response> {
  return handleHrReport(req, config, "Failed to build attendance muster", async (db, orgId, schoolId, url) => {
    const month = url.searchParams.get("month")?.trim() ?? "";
    if (!MONTH_RE.test(month)) {
      throw new HrReportBadRequestError("month query parameter is required as YYYY-MM");
    }
    const lateAfter = url.searchParams.get("lateAfter")?.trim() || DEFAULT_LATE_AFTER;
    const [employees, events, holidayDays] = await Promise.all([
      loadMusterEmployees(db, orgId, schoolId),
      loadCheckInEvents(db, orgId, schoolId, month),
      loadHolidayDays(db, orgId, schoolId, month),
    ]);
    return inferMuster(month, employees, events, { lateAfter, holidayDays }) as unknown as Record<string, unknown>;
  });
}

/** GET /hr/leave/balances — HR-4 per employee × leave type balance report. */
export function handleLeaveBalances(req: Request, config: AppConfig): Promise<Response> {
  return handleHrReport(req, config, "Failed to build leave balances", async (db, orgId, schoolId) => {
    const [leave, employees, policy] = await Promise.all([
      loadLeaveSnapshot(db, orgId, schoolId),
      loadMusterEmployees(db, orgId, schoolId),
      loadLeavePolicy(db, orgId, schoolId),
    ]);
    return buildLeaveBalanceReport(leave, employees, policy) as unknown as Record<string, unknown>;
  });
}

/** GET /hr/reports/headcount — HR-5 active headcount grouped by department. */
export function handleHeadcount(req: Request, config: AppConfig): Promise<Response> {
  return handleHrReport(req, config, "Failed to build headcount", async (db, orgId, schoolId) => {
    const employees = await loadHeadcountEmployees(db, orgId, schoolId);
    return buildHeadcount(employees) as unknown as Record<string, unknown>;
  });
}

/** GET /hr/employees/export — HR-7 employee directory rows. */
export function handleEmployeeDirectory(req: Request, config: AppConfig): Promise<Response> {
  return handleHrReport(req, config, "Failed to build employee directory", async (db, orgId, schoolId) => {
    const rows = await loadDirectoryEmployees(db, orgId, schoolId);
    return { rows } as unknown as Record<string, unknown>;
  });
}

/** ISO yyyy-mm-dd for "today" (UTC) — the window anchor for the two HR-D reports. */
function isoToday(): string {
  return new Date().toISOString().slice(0, 10);
}

/** Parses a positive `withinDays` query param, clamped to [1, 365] with a default. */
function parseWithinDays(url: URL, fallback: number): number {
  const raw = parseInt(url.searchParams.get("withinDays") ?? "", 10);
  if (!Number.isFinite(raw) || raw <= 0) return fallback;
  return Math.min(365, raw);
}

/**
 * GET /hr/documents/expiring?withinDays=30 — HR-D1 staff documents expiring within
 * the window. Reads each employee's JSONB `documents[]` and returns
 * `{ employee, code, docType, docName, expiryDate, daysToExpiry }`. Default 30-day
 * look-ahead. The automated reminder rides a future XCT-2 rule-engine.
 */
export function handleExpiringDocuments(req: Request, config: AppConfig): Promise<Response> {
  return handleHrReport(req, config, "Failed to build expiring documents", async (db, orgId, schoolId, url) => {
    const withinDays = parseWithinDays(url, 30);
    const employees = await loadEmployeePayloads(db, orgId, schoolId);
    return buildExpiringDocuments(employees, withinDays, isoToday()) as unknown as Record<string, unknown>;
  });
}

/**
 * GET /hr/probation/ending?withinDays=15 — HR-D2 employees whose probation ends
 * within the window. Reads each employee's JSONB `probationEndDate`. Default
 * 15-day look-ahead.
 */
export function handleProbationEnding(req: Request, config: AppConfig): Promise<Response> {
  return handleHrReport(req, config, "Failed to build probation ending", async (db, orgId, schoolId, url) => {
    const withinDays = parseWithinDays(url, 15);
    const employees = await loadEmployeePayloads(db, orgId, schoolId);
    return buildProbationEnding(employees, withinDays, isoToday()) as unknown as Record<string, unknown>;
  });
}
