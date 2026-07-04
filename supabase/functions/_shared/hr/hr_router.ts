import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAttendance,
  handleDashboard,
  handleEmployeeDetail,
  handleEmployees,
  handleLeave,
  handlePayroll,
  handlePerformance,
  handleRecruitment,
  handleSettings,
} from "./hr_handlers.ts";
import {
  handleAttendanceMuster,
  handleEmployeeDirectory,
  handleExpiringDocuments,
  handleHeadcount,
  handleLeaveBalances,
  handlePayslips,
  handleProbationEnding,
  handleSalaryRegister,
} from "./hr_reports_handlers.ts";
import {
  handleApproveLeaveRequest,
  handleBatchDecideLeave,
  handleCreateEmployee,
  handleCreateLeaveRequest,
  handleCreatePerformanceReview,
  handleCreateRecruitmentOpening,
  handleGeneratePayrollRun,
  handleProcessPayrollRun,
  handleRejectLeaveRequest,
  handleUpsertSalaryStructure,
  handleSetEmployeeProbation,
  handleSetEmployeeStatus,
  handleUpdateEmployee,
  handleUpdatePerformanceReview,
  handleUpdateRecruitmentOpening,
} from "./hr_write_handlers.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function matchHrRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (method === "GET") {
    if (path === "/hr/dashboard") {
      return { handler: handleDashboard, args: [] };
    }
    // --- HR reporting / export reads (HR-1/2/4/5/6/7). Registered BEFORE the
    //     generic /hr/employees/{id} + /hr/payroll matches so the literal
    //     report paths ("export", "register", "payslips", "muster") are not
    //     swallowed by the id/detail catch-alls. ---
    if (path === "/hr/employees/export") {
      return { handler: handleEmployeeDirectory, args: [] };
    }
    if (path === "/hr/payroll/register") {
      return { handler: handleSalaryRegister, args: [] };
    }
    if (path === "/hr/payroll/payslips") {
      return { handler: handlePayslips, args: [] };
    }
    if (path === "/hr/attendance/muster") {
      return { handler: handleAttendanceMuster, args: [] };
    }
    if (path === "/hr/leave/balances") {
      return { handler: handleLeaveBalances, args: [] };
    }
    if (path === "/hr/reports/headcount") {
      return { handler: handleHeadcount, args: [] };
    }
    // HR-D1 staff document-expiry + HR-D2 probation-ending reports.
    if (path === "/hr/documents/expiring") {
      return { handler: handleExpiringDocuments, args: [] };
    }
    if (path === "/hr/probation/ending") {
      return { handler: handleProbationEnding, args: [] };
    }
    // --- end HR reporting reads ---
    if (path === "/hr/employees") {
      return { handler: handleEmployees, args: [] };
    }
    if (path === "/hr/attendance") {
      return { handler: handleAttendance, args: [] };
    }
    if (path === "/hr/leave") {
      return { handler: handleLeave, args: [] };
    }
    if (path === "/hr/payroll") {
      return { handler: handlePayroll, args: [] };
    }
    if (path === "/hr/recruitment") {
      return { handler: handleRecruitment, args: [] };
    }
    if (path === "/hr/performance") {
      return { handler: handlePerformance, args: [] };
    }
    if (path === "/hr/settings") {
      return { handler: handleSettings, args: [] };
    }

    const employeeMatch = path.match(/^\/hr\/employees\/([^/]+)$/);
    if (employeeMatch) {
      return { handler: handleEmployeeDetail, args: [employeeMatch[1]!] };
    }

    return null;
  }

  if (method === "POST") {
    if (path === "/hr/employees") {
      return { handler: handleCreateEmployee, args: [] };
    }
    if (path === "/hr/leave") {
      return { handler: handleCreateLeaveRequest, args: [] };
    }
    // HR-3 batch leave decide (registered before the id/approve|reject matches).
    if (path === "/hr/leave/batch-decide") {
      return { handler: handleBatchDecideLeave, args: [] };
    }
    // HR-D2 probation confirm/extend.
    const probationMatch = path.match(/^\/hr\/employees\/([^/]+)\/probation$/);
    if (probationMatch) {
      return { handler: handleSetEmployeeProbation, args: [probationMatch[1]!] };
    }
    // --- A6 writes (AgentC) ---
    const leaveApproveMatch = path.match(/^\/hr\/leave\/([^/]+)\/approve$/);
    if (leaveApproveMatch) {
      return { handler: handleApproveLeaveRequest, args: [leaveApproveMatch[1]!] };
    }
    const leaveRejectMatch = path.match(/^\/hr\/leave\/([^/]+)\/reject$/);
    if (leaveRejectMatch) {
      return { handler: handleRejectLeaveRequest, args: [leaveRejectMatch[1]!] };
    }
    if (path === "/hr/performance") {
      return { handler: handleCreatePerformanceReview, args: [] };
    }
    if (path === "/hr/recruitment") {
      return { handler: handleCreateRecruitmentOpening, args: [] };
    }
    // --- end A6 writes (AgentC) ---
    // MOD-2 — payroll engine: salary structures + run generation. Generate is a
    // distinct path from the run processor; both are exact matches.
    if (path === "/hr/payroll/structures") {
      return { handler: handleUpsertSalaryStructure, args: [] };
    }
    if (path === "/hr/payroll/run/generate") {
      return { handler: handleGeneratePayrollRun, args: [] };
    }
    if (path === "/hr/payroll/run") {
      return { handler: handleProcessPayrollRun, args: [] };
    }
    return null;
  }

  if (method === "PUT") {
    const employeeMatch = path.match(/^\/hr\/employees\/([^/]+)$/);
    if (employeeMatch) {
      return { handler: handleUpdateEmployee, args: [employeeMatch[1]!] };
    }
    // --- A6 writes (AgentC) ---
    const performanceMatch = path.match(/^\/hr\/performance\/([^/]+)$/);
    if (performanceMatch) {
      return { handler: handleUpdatePerformanceReview, args: [performanceMatch[1]!] };
    }
    const recruitmentMatch = path.match(/^\/hr\/recruitment\/([^/]+)$/);
    if (recruitmentMatch) {
      return { handler: handleUpdateRecruitmentOpening, args: [recruitmentMatch[1]!] };
    }
    // --- end A6 writes (AgentC) ---
    return null;
  }

  if (method === "PATCH") {
    const statusMatch = path.match(/^\/hr\/employees\/([^/]+)\/status$/);
    if (statusMatch) {
      return { handler: handleSetEmployeeStatus, args: [statusMatch[1]!] };
    }
    return null;
  }

  return null;
}

export async function routeHr(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/hr")) return null;

  const match = matchHrRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  for (const arg of match.args) {
    if (arg.includes("-") && !UUID_SEGMENT.test(arg)) {
      // Allow non-UUID legacy mock ids in path for compatibility
    }
  }

  return await match.handler(req, config, ...match.args);
}
