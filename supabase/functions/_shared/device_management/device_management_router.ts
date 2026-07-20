// W4 (Owner decision #12, FINAL) — Device / Asset management module router. The
// parent dispatcher wires this in post-merge (this module NEVER touches
// api/app.ts). All routes live under the /inventory/devices/ sub-prefix so they
// slot beside the existing inventory module without colliding with its routes.
//
//   POST /inventory/devices                register an asset
//   GET  /inventory/devices                list the asset register (filters)
//   GET  /inventory/devices/by-staff       a staff member's held assets (?staffId=)
//   GET  /inventory/devices/:id            one asset
//   GET  /inventory/devices/:id/history    custody timeline
//   POST /inventory/devices/:id/assign     assign to a staff member
//   POST /inventory/devices/:id/return     return from a staff member
//   POST /inventory/devices/:id/retire     retire (terminal)
//   POST /inventory/devices/:id/lost       mark lost (terminal)

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAssignDevice,
  handleDeviceHistory,
  handleGetDevice,
  handleListDevices,
  handleListDevicesByStaff,
  handleMarkDeviceLost,
  handleRegisterDevice,
  handleReturnDevice,
  handleRetireDevice,
} from "./device_management_handlers.ts";

type Handler = (req: Request, config: AppConfig) => Promise<Response>;

const DEVICES_PREFIX = "/inventory/devices";

export function matchDeviceRoute(method: string, path: string): Handler | null {
  if (path !== DEVICES_PREFIX && !path.startsWith(`${DEVICES_PREFIX}/`)) return null;
  // segs = ["inventory", "devices", ...rest]
  const segs = path.split("/").filter((s) => s.length > 0);
  if (segs[0] !== "inventory" || segs[1] !== "devices") return null;
  const rest = segs.slice(2);

  if (rest.length === 0) {
    if (method === "POST") return handleRegisterDevice;
    if (method === "GET") return handleListDevices;
    return null;
  }

  if (rest.length === 1) {
    if (rest[0] === "by-staff") {
      return method === "GET" ? handleListDevicesByStaff : null;
    }
    // /inventory/devices/:id
    return method === "GET" ? handleGetDevice : null;
  }

  if (rest.length === 2) {
    // /inventory/devices/:id/<action>
    const action = rest[1];
    if (method === "GET" && action === "history") return handleDeviceHistory;
    if (method === "POST") {
      if (action === "assign") return handleAssignDevice;
      if (action === "return") return handleReturnDevice;
      if (action === "retire") return handleRetireDevice;
      if (action === "lost") return handleMarkDeviceLost;
    }
    return null;
  }

  return null;
}

export async function routeDeviceManagement(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (path !== DEVICES_PREFIX && !path.startsWith(`${DEVICES_PREFIX}/`)) return null;
  const handler = matchDeviceRoute(method, path);
  if (!handler) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }
  return await handler(req, config);
}
