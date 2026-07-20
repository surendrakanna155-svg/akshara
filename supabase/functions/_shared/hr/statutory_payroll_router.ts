// PRA-P1-35 (Owner decision #9, FINAL) — statutory payroll config router (hr-owned).
//
// A self-contained sub-router for the statutory CONFIG endpoints. hr_router.routeHr
// delegates to it (mirroring the staff-duty sub-router), so the statutory routes are
// wired without bloating the main HR match table. Returns null for any non-statutory
// path so those fall through to the rest of the HR router.
//
// The deduction ENGINE itself is not routed here — it is folded into the existing
// /hr/payroll/run/generate + /hr/payroll/run handlers (hr_write_handlers.ts).

import type { AppConfig } from "../config.ts";
import {
  handleGetStatutoryConfig,
  handleUpsertPtSlab,
  handleUpsertStatutoryConfig,
} from "./statutory_payroll_handlers.ts";

export async function routeStatutory(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/hr/payroll/statutory")) return null;

  if (method === "GET" && path === "/hr/payroll/statutory/config") {
    return await handleGetStatutoryConfig(req, config);
  }
  if (method === "POST" && path === "/hr/payroll/statutory/config") {
    return await handleUpsertStatutoryConfig(req, config);
  }
  if (method === "POST" && path === "/hr/payroll/statutory/pt-slabs") {
    return await handleUpsertPtSlab(req, config);
  }

  return null;
}
