// W4 Staff Duty — self-contained module router. The parent dispatcher wires this
// in post-merge (this module NEVER touches api/app.ts). All routes live under the
// /hr/staff-duties/ prefix so they slot cleanly beside the existing HR module.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleCreateInvigilationDuty,
  handleCreateNonTeachingDuty,
  handleCreateSubstituteClass,
  handleListInvigilationDuties,
  handleListNonTeachingDuties,
  handleListSubstituteClasses,
  handleStaffDutyRollup,
} from "./staff_duty_handlers.ts";

export function matchStaffDutyRoute(
  method: string,
  path: string,
): ((req: Request, config: AppConfig) => Promise<Response>) | null {
  if (path === "/hr/staff-duties/substitutions" && method === "POST") {
    return handleCreateSubstituteClass;
  }
  if (path === "/hr/staff-duties/substitutions" && method === "GET") {
    return handleListSubstituteClasses;
  }
  if (path === "/hr/staff-duties/invigilations" && method === "POST") {
    return handleCreateInvigilationDuty;
  }
  if (path === "/hr/staff-duties/invigilations" && method === "GET") {
    return handleListInvigilationDuties;
  }
  if (path === "/hr/staff-duties/non-teaching" && method === "POST") {
    return handleCreateNonTeachingDuty;
  }
  if (path === "/hr/staff-duties/non-teaching" && method === "GET") {
    return handleListNonTeachingDuties;
  }
  if (path === "/hr/staff-duties/rollup" && method === "GET") {
    return handleStaffDutyRollup;
  }
  return null;
}

export async function routeStaffDuty(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/hr/staff-duties")) return null;
  const handler = matchStaffDutyRoute(method, path);
  if (!handler) {
    return null;
  }
  return await handler(req, config);
}
