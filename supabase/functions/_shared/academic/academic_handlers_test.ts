import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

const HANDLER_PATH = new URL("./academic_handlers.ts", import.meta.url);
const handlerSource = await Deno.readTextFile(HANDLER_PATH);

const READ_HANDLERS = [
  "handleListAcademicYears",
  "handleListClasses",
  "handleListSections",
  "handleListTeacherAssignments",
] as const;

const WRITE_HANDLERS = [
  "handleCreateAcademicYear",
  "handleUpdateAcademicYear",
  "handleCreateClass",
  "handleUpdateClass",
  "handleCreateSection",
  "handleUpdateSection",
  "handleCreateTeacherAssignment",
  "handleUpdateTeacherAssignment",
] as const;

Deno.test("academic read handlers require viewSis and school scope", () => {
  assertEquals(handlerSource.includes("function requireAcademicRead"), true);
  assertEquals(handlerSource.includes('requirePermission(claims, "viewSis")'), true);
  assertEquals(handlerSource.includes("requireSchoolOperationalScope"), true);
  for (const handler of READ_HANDLERS) {
    const start = handlerSource.indexOf(`export async function ${handler}`);
    const block = handlerSource.slice(start, start + 2000);
    assertEquals(block.includes("requireAcademicRead"), true, handler);
    assertEquals(block.includes("runTenant"), true, handler);
  }
});

Deno.test("academic write handlers require manageSis and school scope", () => {
  assertEquals(handlerSource.includes("function requireAcademicWrite"), true);
  assertEquals(handlerSource.includes('requirePermission(claims, "manageSis")'), true);
  for (const handler of WRITE_HANDLERS) {
    const start = handlerSource.indexOf(`export async function ${handler}`);
    const block = handlerSource.slice(start, start + 2000);
    assertEquals(block.includes("requireAcademicWrite"), true, handler);
    assertEquals(block.includes("runTenant"), true, handler);
  }
});

Deno.test("academic handlers use withTenantContext via runTenant", () => {
  assertEquals(handlerSource.includes("withTenantContext"), true);
  assertEquals(handlerSource.includes("async function runTenant"), true);
});

Deno.test("academic handlers derive tenant ids from JWT claims only", () => {
  assertEquals(handlerSource.includes("organizationIdFromClaims"), true);
  assertEquals(handlerSource.includes("schoolIdFromClaims"), true);
  assertEquals(handlerSource.includes("createServiceClient"), false);
  assertEquals(handlerSource.includes("service_role"), false);
});

Deno.test("academic handlers map duplicate and concurrency errors to 409", () => {
  assertEquals(handlerSource.includes('errorEnvelope("CONFLICT"'), true);
  assertEquals(handlerSource.includes("DuplicateAcademicYearLabelError"), true);
  assertEquals(handlerSource.includes("ConcurrentCurrentYearError"), true);
  assertEquals(handlerSource.includes("DuplicatePrimaryClassTeacherError"), true);
});

Deno.test("academic handlers map teacher membership validation to 422", () => {
  assertEquals(handlerSource.includes("Teacher is not an active member"), true);
  assertEquals(handlerSource.includes('errorEnvelope("VALIDATION_ERROR"'), true);
});

Deno.test("academic handlers map cross-school section access to 404", () => {
  assertEquals(handlerSource.includes("Section not found"), true);
  assertEquals(handlerSource.includes('errorEnvelope("NOT_FOUND"'), true);
});

Deno.test("academic list handlers use paginated repository functions", () => {
  assertEquals(handlerSource.includes("listAcademicYearsPage"), true);
  assertEquals(handlerSource.includes("listClassesPage"), true);
  assertEquals(handlerSource.includes("listSectionsPage"), true);
  assertEquals(handlerSource.includes("listTeacherAssignmentsPage"), true);
  assertEquals(handlerSource.includes("parsePagination"), true);
});

Deno.test("academic write handlers map not-found errors to HTTP 404", () => {
  assertEquals(handlerSource.includes("AcademicYearNotFoundError"), true);
  assertEquals(handlerSource.includes("ClassNotFoundError"), true);
  assertEquals(handlerSource.includes("SectionNotFoundError"), true);
  assertEquals(handlerSource.includes("TeacherAssignmentNotFoundError"), true);
  assertEquals(handlerSource.includes('errorEnvelope("NOT_FOUND"'), true);
});
