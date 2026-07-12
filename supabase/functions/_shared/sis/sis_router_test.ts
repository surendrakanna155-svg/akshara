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

Deno.test("sis router matches GET /sis/students/:id/siblings (SIS-4)", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  const match = matchSisRoute("GET", `/sis/students/${studentId}/siblings`);
  assertEquals(match?.args, [studentId]);
  assertEquals(match?.handler.name, "handleListStudentSiblings");
});

Deno.test("sis router: siblings does not collide with the generic student route", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  // The plain student GET must still resolve to handleGetStudent.
  const studentGet = matchSisRoute("GET", `/sis/students/${studentId}`);
  assertEquals(studentGet?.handler.name, "handleGetStudent");
  // Siblings is read-only (GET only) — a POST to the siblings path must not resolve.
  const wrongVerb = matchSisRoute("POST", `/sis/students/${studentId}/siblings`);
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

Deno.test("SIS-4 GET /sis/students/:id/siblings is registered as viewSis school route", () => {
  const rule = RBAC_ROUTE_INVENTORY.find(
    (r) => r.method === "GET" && r.path === "/sis/students/:id/siblings",
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

// ─── SIS-1 certificates + SIS-D1 transfer-certificate routing ────────────────

Deno.test("sis router matches GET /sis/students/:id/certificates (SIS-1 register)", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  const match = matchSisRoute("GET", `/sis/students/${studentId}/certificates`);
  assertEquals(match?.args, [studentId]);
  assertEquals(match?.handler.name, "handleListCertificates");
});

Deno.test("sis router matches POST /sis/students/:id/certificates (SIS-1 issue)", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  const match = matchSisRoute("POST", `/sis/students/${studentId}/certificates`);
  assertEquals(match?.args, [studentId]);
  assertEquals(match?.handler.name, "handleIssueCertificate");
});

Deno.test("sis router matches POST /sis/students/:id/transfer-certificate (SIS-D1)", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  const match = matchSisRoute(
    "POST",
    `/sis/students/${studentId}/transfer-certificate`,
  );
  assertEquals(match?.args, [studentId]);
  assertEquals(match?.handler.name, "handleIssueTransferCertificate");
});

Deno.test("sis router: transfer-certificate does not resolve to the generic student route", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  // The TC path is POST-only; a GET must not fall through to any handler here.
  const wrongVerb = matchSisRoute(
    "GET",
    `/sis/students/${studentId}/transfer-certificate`,
  );
  assertEquals(wrongVerb, null);
  // And the certificates path must not collide with the plain student GET.
  const studentGet = matchSisRoute("GET", `/sis/students/${studentId}`);
  assertEquals(studentGet?.handler.name, "handleGetStudent");
});

Deno.test("sis router matches GET /sis/students/:id/clearance (SCE-1)", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  const match = matchSisRoute("GET", `/sis/students/${studentId}/clearance`);
  assertEquals(match?.args, [studentId]);
  assertEquals(match?.handler.name, "handleStudentClearance");
});

Deno.test("sis router: clearance is GET-only and doesn't collide with the generic student route", () => {
  const studentId = "a4000000-0000-4000-8000-000000000001";
  assertEquals(
    matchSisRoute("POST", `/sis/students/${studentId}/clearance`),
    null,
  );
  const studentGet = matchSisRoute("GET", `/sis/students/${studentId}`);
  assertEquals(studentGet?.handler.name, "handleGetStudent");
});

Deno.test("SCE-1 GET /sis/students/:id/clearance is registered as viewSis school route", () => {
  const rule = RBAC_ROUTE_INVENTORY.find(
    (r) => r.method === "GET" && r.path === "/sis/students/:id/clearance",
  );
  assertExists(rule);
  assertEquals(rule!.permission, "viewSis");
  assertEquals(rule!.scope, "school");
  assertEquals(rule!.module, "sis");
});

Deno.test("sis router matches the SCE-1 waiver routes (raise / queue / decide)", () => {
  const sid = "a4000000-0000-4000-8000-000000000001";
  const raise = matchSisRoute("POST", `/sis/students/${sid}/clearance/waivers`);
  assertEquals(raise?.args, [sid]);
  assertEquals(raise?.handler.name, "handleCreateClearanceWaiver");

  const queue = matchSisRoute("GET", "/sis/clearance/waivers");
  assertEquals(queue?.args, []);
  assertEquals(queue?.handler.name, "handleListPendingClearanceWaivers");

  const decide = matchSisRoute("POST", "/sis/clearance/waivers/w-9/decide");
  assertEquals(decide?.args, ["w-9"]);
  assertEquals(decide?.handler.name, "handleDecideClearanceWaiver");

  const revoke = matchSisRoute("POST", "/sis/clearance/waivers/w-9/revoke");
  assertEquals(revoke?.args, ["w-9"]);
  assertEquals(revoke?.handler.name, "handleRevokeClearanceWaiver");
});

Deno.test("sis router: waiver-raise (POST) does not collide with the clearance GET report", () => {
  const sid = "a4000000-0000-4000-8000-000000000001";
  // GET /clearance is the report; POST /clearance/waivers is the raise. Distinct.
  assertEquals(matchSisRoute("GET", `/sis/students/${sid}/clearance`)?.handler.name, "handleStudentClearance");
  assertEquals(matchSisRoute("POST", `/sis/students/${sid}/clearance`), null);
  assertEquals(
    matchSisRoute("POST", `/sis/students/${sid}/clearance/waivers`)?.handler.name,
    "handleCreateClearanceWaiver",
  );
});

Deno.test("SCE-1 waiver routes are registered with the right RBAC (maker=manageSis, checker=approveClearanceWaiver)", () => {
  const raise = RBAC_ROUTE_INVENTORY.find(
    (r) => r.method === "POST" && r.path === "/sis/students/:id/clearance/waivers",
  );
  assertExists(raise);
  assertEquals(raise!.permission, "manageSis");
  for (const path of ["/sis/clearance/waivers", "/sis/clearance/waivers/:id/decide"]) {
    const rule = RBAC_ROUTE_INVENTORY.find((r) => r.path === path);
    assertExists(rule);
    assertEquals(rule!.permission, "approveClearanceWaiver");
    assertEquals(rule!.scope, "school");
  }
});

Deno.test("sis router matches GET /sis/admissions-conversion (#5)", () => {
  const match = matchSisRoute("GET", "/sis/admissions-conversion");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleListAdmissionsConversion");
});

Deno.test("sis router: GET /sis/admissions-conversion is distinct from the POST convert action", () => {
  const getMatch = matchSisRoute("GET", "/sis/admissions-conversion");
  assertEquals(getMatch?.handler.name, "handleListAdmissionsConversion");
  const postMatch = matchSisRoute("POST", "/sis/admissions-conversion");
  assertEquals(postMatch?.handler.name, "handleAdmissionsConversion");
});

Deno.test("#5 GET /sis/admissions-conversion is registered as viewSis school route", () => {
  const rule = RBAC_ROUTE_INVENTORY.find(
    (r) => r.method === "GET" && r.path === "/sis/admissions-conversion",
  );
  assertExists(rule);
  assertEquals(rule!.permission, "viewSis");
  assertEquals(rule!.scope, "school");
  assertEquals(rule!.module, "sis");
});

Deno.test("SIS-1/D1 certificate routes are registered with correct RBAC", () => {
  const list = RBAC_ROUTE_INVENTORY.find(
    (r) => r.method === "GET" && r.path === "/sis/students/:id/certificates",
  );
  assertExists(list);
  assertEquals(list!.permission, "viewSis");
  assertEquals(list!.scope, "school");
  assertEquals(list!.module, "sis");

  const issue = RBAC_ROUTE_INVENTORY.find(
    (r) => r.method === "POST" && r.path === "/sis/students/:id/certificates",
  );
  assertExists(issue);
  assertEquals(issue!.permission, "manageSis");
  assertEquals(issue!.scope, "school");

  const transfer = RBAC_ROUTE_INVENTORY.find(
    (r) =>
      r.method === "POST" &&
      r.path === "/sis/students/:id/transfer-certificate",
  );
  assertExists(transfer);
  assertEquals(transfer!.permission, "manageSis");
  assertEquals(transfer!.scope, "school");
});
