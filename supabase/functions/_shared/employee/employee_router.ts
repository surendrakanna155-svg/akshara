import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAssignEmployeeRole,
  handleEmployeeDashboard,
  handleGetEmployee,
  handleListEmployees,
} from "./employee_handlers.ts";
import {
  handleEmployee360,
  handleEmployeeIntelligenceDashboard,
} from "./employee_intelligence_handlers.ts";

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function matchEmployeeRoute(
  method: string,
  path: string,
): {
  handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>;
  args: string[];
} | null {
  if (path === "/employees/dashboard" && method === "GET") {
    return { handler: handleEmployeeDashboard, args: [] };
  }
  if (path === "/employees/intelligence/dashboard" && method === "GET") {
    return { handler: handleEmployeeIntelligenceDashboard, args: [] };
  }
  if (path === "/employees" && method === "GET") {
    return { handler: handleListEmployees, args: [] };
  }

  const intel360Match = path.match(/^\/employees\/([^/]+)\/360$/);
  if (intel360Match && method === "GET" && UUID.test(intel360Match[1]!)) {
    return { handler: handleEmployee360, args: [intel360Match[1]!] };
  }

  const roleMatch = path.match(/^\/employees\/([^/]+)\/roles$/);
  if (roleMatch && method === "POST" && UUID.test(roleMatch[1]!)) {
    return { handler: handleAssignEmployeeRole, args: [roleMatch[1]!] };
  }

  const employeeMatch = path.match(/^\/employees\/([^/]+)$/);
  if (employeeMatch && method === "GET" && UUID.test(employeeMatch[1]!)) {
    return { handler: handleGetEmployee, args: [employeeMatch[1]!] };
  }

  return null;
}

export async function routeEmployee(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/employees")) return null;
  const match = matchEmployeeRoute(method, path);
  if (!match) {
    return null;
  }
  try {
    return await match.handler(req, config, ...match.args);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Employee route failed";
    return errorEnvelope("EMPLOYEE_ROUTE_ERROR", message, 500);
  }
}
