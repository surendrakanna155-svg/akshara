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
  handleCreateEmployee,
  handleCreateLeaveRequest,
  handleProcessPayrollRun,
  handleSetEmployeeStatus,
  handleUpdateEmployee,
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
