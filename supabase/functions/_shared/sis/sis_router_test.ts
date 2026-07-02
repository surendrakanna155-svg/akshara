import { assertEquals, assertExists } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchSisRoute } from "./sis_router.ts";
import { RBAC_ROUTE_INVENTORY } from "../validation/rbac_route_inventory.ts";

Deno.test("sis router matches GET /sis/dashboard", () => {
  const match = matchSisRoute("GET", "/sis/dashboard");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleDashboard");
});

Deno.test("sis router matches GET /sis/students", () => {
  const match = matchSisRoute("GET", "/sis/students");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleListStudents");
});

Deno.test("sis router matches POST /sis/students", () => {
  const match = matchSisRoute("POST", "/sis/students");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleCreateStudent");
});

Deno.test("sis router matches GET /sis/transfers (SIS-5)", () => {
  const match = matchSisRoute("GET", "/sis/transfers");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleListStudentTransfers");
});

Deno.test("sis router matches PATCH /sis/students/:id/documents/:docId/verify (SIS-3)", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  const docId = "d5000000-0000-4000-8000-000000000009";
  const match = matchSisRoute(
    "PATCH",
    `/sis/students/${studentId}/documents/${docId}/verify`,
  );
  assertEquals(match?.args, [studentId, docId]);
  assertEquals(match?.handler.name, "handleVerifyStudentDocument");
});

Deno.test("sis router: document verify does not collide with documents list", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  const listMatch = matchSisRoute("GET", `/sis/students/${studentId}/documents`);
  assertEquals(listMatch?.handler.name, "handleListStudentDocuments");
  // verify requires PATCH — a GET to the verify path must not resolve here.
  const wrongVerb = matchSisRoute("GET", `/sis/students/${studentId}/documents/x/verify`);
  assertEquals(wrongVerb, null);
});

Deno.test("sis router matches GET /sis/students/:id", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  const match = matchSisRoute("GET", `/sis/students/${studentId}`);
  assertEquals(match?.args, [studentId]);
  assertEquals(match?.handler.name, "handleGetStudent");
});

Deno.test("sis router matches PUT /sis/students/:id", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  const match = matchSisRoute("PUT", `/sis/students/${studentId}`);
  assertEquals(match?.args, [studentId]);
  assertEquals(match?.handler.name, "handleUpdateStudent");
});

Deno.test("sis router matches PATCH /sis/students/:id/status", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  const match = matchSisRoute("PATCH", `/sis/students/${studentId}/status`);
  assertEquals(match?.args, [studentId]);
  assertEquals(match?.handler.name, "handleUpdateStudentStatus");
});

Deno.test("sis router matches GET /sis/enrollments", () => {
  const match = matchSisRoute("GET", "/sis/enrollments");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleListEnrollments");
});

Deno.test("sis router matches POST /sis/enrollments", () => {
  const match = matchSisRoute("POST", "/sis/enrollments");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleCreateEnrollment");
});

Deno.test("sis router matches PUT /sis/enrollments/:id", () => {
  const enrollmentId = "bc100000-0000-4000-8000-000000000001";
  const match = matchSisRoute("PUT", `/sis/enrollments/${enrollmentId}`);
  assertEquals(match?.args, [enrollmentId]);
  assertEquals(match?.handler.name, "handleUpdateEnrollment");
});

Deno.test("sis router matches POST /sis/admissions-conversion", () => {
  const match = matchSisRoute("POST", "/sis/admissions-conversion");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleAdmissionsConversion");
});

Deno.test("SIS-5 GET /sis/transfers is registered as viewSis school route", () => {
  const rule = RBAC_ROUTE_INVENTORY.find(
    (r) => r.method === "GET" && r.path === "/sis/transfers",
  );
  assertExists(rule);
  assertEquals(rule!.permission, "viewSis");
  assertEquals(rule!.scope, "school");
  assertEquals(rule!.module, "sis");
});

Deno.test("SIS-3 PATCH document verify is registered as manageSis school route", () => {
  const rule = RBAC_ROUTE_INVENTORY.find(
    (r) =>
      r.method === "PATCH" &&
      r.path === "/sis/students/:id/documents/:docId/verify",
  );
  assertExists(rule);
  assertEquals(rule!.permission, "manageSis");
  assertEquals(rule!.scope, "school");
  assertEquals(rule!.module, "sis");
});
