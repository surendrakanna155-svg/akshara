import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchAcademicRoute } from "./academic_router.ts";

Deno.test("academic router matches GET /academic/years", () => {
  const match = matchAcademicRoute("GET", "/academic/years");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleListAcademicYears");
});

Deno.test("academic router matches POST /academic/years", () => {
  const match = matchAcademicRoute("POST", "/academic/years");
  assertEquals(match?.args, []);
  assertEquals(match?.handler.name, "handleCreateAcademicYear");
});

Deno.test("academic router matches PUT /academic/years/:id", () => {
  const yearId = "ce100000-0000-4000-8000-000000000001";
  const match = matchAcademicRoute("PUT", `/academic/years/${yearId}`);
  assertEquals(match?.args, [yearId]);
  assertEquals(match?.handler.name, "handleUpdateAcademicYear");
});

Deno.test("academic router matches GET /academic/classes", () => {
  const match = matchAcademicRoute("GET", "/academic/classes");
  assertEquals(match?.handler.name, "handleListClasses");
});

Deno.test("academic router matches POST /academic/classes", () => {
  const match = matchAcademicRoute("POST", "/academic/classes");
  assertEquals(match?.handler.name, "handleCreateClass");
});

Deno.test("academic router matches PUT /academic/classes/:id", () => {
  const classId = "cf100000-0000-4000-8000-000000000001";
  const match = matchAcademicRoute("PUT", `/academic/classes/${classId}`);
  assertEquals(match?.args, [classId]);
  assertEquals(match?.handler.name, "handleUpdateClass");
});

Deno.test("academic router matches GET /academic/sections", () => {
  const match = matchAcademicRoute("GET", "/academic/sections");
  assertEquals(match?.handler.name, "handleListSections");
});

Deno.test("academic router matches POST /academic/sections", () => {
  const match = matchAcademicRoute("POST", "/academic/sections");
  assertEquals(match?.handler.name, "handleCreateSection");
});

Deno.test("academic router matches PUT /academic/sections/:id", () => {
  const sectionId = "d0100000-0000-4000-8000-000000000001";
  const match = matchAcademicRoute("PUT", `/academic/sections/${sectionId}`);
  assertEquals(match?.args, [sectionId]);
  assertEquals(match?.handler.name, "handleUpdateSection");
});

Deno.test("academic router matches GET /academic/teacher-assignments", () => {
  const match = matchAcademicRoute("GET", "/academic/teacher-assignments");
  assertEquals(match?.handler.name, "handleListTeacherAssignments");
});

Deno.test("academic router matches POST /academic/teacher-assignments", () => {
  const match = matchAcademicRoute("POST", "/academic/teacher-assignments");
  assertEquals(match?.handler.name, "handleCreateTeacherAssignment");
});

Deno.test("academic router matches PUT /academic/teacher-assignments/:id", () => {
  const assignmentId = "d2000000-0000-4000-8000-000000000001";
  const match = matchAcademicRoute(
    "PUT",
    `/academic/teacher-assignments/${assignmentId}`,
  );
  assertEquals(match?.args, [assignmentId]);
  assertEquals(match?.handler.name, "handleUpdateTeacherAssignment");
});

Deno.test("academic router does not match unrelated paths", () => {
  assertEquals(matchAcademicRoute("GET", "/sis/students"), null);
  assertEquals(matchAcademicRoute("GET", "/academic/attendance"), null);
});
