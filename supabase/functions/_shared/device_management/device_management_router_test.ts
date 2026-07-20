import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchDeviceRoute } from "./device_management_router.ts";
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

const ID = "a3000000-0000-4000-8000-000000000001";

Deno.test("matchDeviceRoute: maps each device route to its handler", () => {
  assertEquals(matchDeviceRoute("POST", "/inventory/devices"), handleRegisterDevice);
  assertEquals(matchDeviceRoute("GET", "/inventory/devices"), handleListDevices);
  assertEquals(matchDeviceRoute("GET", "/inventory/devices/by-staff"), handleListDevicesByStaff);
  assertEquals(matchDeviceRoute("GET", `/inventory/devices/${ID}`), handleGetDevice);
  assertEquals(matchDeviceRoute("GET", `/inventory/devices/${ID}/history`), handleDeviceHistory);
  assertEquals(matchDeviceRoute("POST", `/inventory/devices/${ID}/assign`), handleAssignDevice);
  assertEquals(matchDeviceRoute("POST", `/inventory/devices/${ID}/return`), handleReturnDevice);
  assertEquals(matchDeviceRoute("POST", `/inventory/devices/${ID}/retire`), handleRetireDevice);
  assertEquals(matchDeviceRoute("POST", `/inventory/devices/${ID}/lost`), handleMarkDeviceLost);
});

Deno.test("matchDeviceRoute: 'by-staff' literal is not treated as an id", () => {
  // GET by-staff -> the staff list handler, never handleGetDevice.
  assertEquals(matchDeviceRoute("GET", "/inventory/devices/by-staff"), handleListDevicesByStaff);
  // A POST to by-staff is not a route.
  assertEquals(matchDeviceRoute("POST", "/inventory/devices/by-staff"), null);
});

Deno.test("matchDeviceRoute: returns null for foreign paths, bad methods, unknown actions", () => {
  assertEquals(matchDeviceRoute("GET", "/inventory/stock"), null);
  assertEquals(matchDeviceRoute("GET", "/inventory/devicesX"), null); // prefix guard
  assertEquals(matchDeviceRoute("DELETE", "/inventory/devices"), null); // no delete
  assertEquals(matchDeviceRoute("DELETE", `/inventory/devices/${ID}`), null);
  assertEquals(matchDeviceRoute("POST", `/inventory/devices/${ID}/frobnicate`), null);
  assertEquals(matchDeviceRoute("GET", `/inventory/devices/${ID}/assign`), null); // assign is POST
});
