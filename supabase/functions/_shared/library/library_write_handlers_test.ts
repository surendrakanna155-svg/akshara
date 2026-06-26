import { assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { WriteValidationError } from "../entity_write/module_write_handlers.ts";
import {
  buildMemberPayload,
  buildReturnFinePayload,
  intFromString,
  normalizeResourceUrl,
} from "./library_write_handlers.ts";
import { computeFines } from "./library_aggregations.ts";

const NOW = new Date("2026-06-26T10:00:00.000Z");

// --- buildMemberPayload (enrolment, MJ-H21 A) --------------------------------

Deno.test("buildMemberPayload: defaults role to student, loans to 0, status active", () => {
  const payload = buildMemberPayload({ name: "Asha Rao" }, "m-1");
  assertEquals(payload.id, "m-1");
  assertEquals(payload.name, "Asha Rao");
  assertEquals(payload.memberType, "student");
  assertEquals(payload.activeLoans, 0);
  assertEquals(payload.status, "active");
  assertEquals(payload.sisStudentId, null);
});

Deno.test("buildMemberPayload: carries identifier, class, sis ref and role", () => {
  const payload = buildMemberPayload({
    name: "Dr. Meera Iyer",
    memberType: "teacher",
    identifier: "EMP-TCH-042",
    classOrDepartment: "English Dept",
    sisStudentId: "SIS-STU-1",
  }, "m-2");
  assertEquals(payload.memberType, "teacher");
  assertEquals(payload.identifier, "EMP-TCH-042");
  assertEquals(payload.classOrDepartment, "English Dept");
  assertEquals(payload.sisStudentId, "SIS-STU-1");
});

Deno.test("buildMemberPayload: rejects a missing name", () => {
  assertThrows(() => buildMemberPayload({ memberType: "student" }, "m-3"), WriteValidationError);
});

Deno.test("buildMemberPayload: rejects an invalid role", () => {
  assertThrows(
    () => buildMemberPayload({ name: "X", memberType: "alien" }, "m-4"),
    WriteValidationError,
    "memberType",
  );
});

// --- buildReturnFinePayload (LIBRA-2 persisted fine) -------------------------

Deno.test("buildReturnFinePayload: outstanding fine carries member, amount, sis ref", () => {
  const issue = {
    id: "iss-9",
    memberName: "Arjun Patel",
    bookTitle: "Beta",
    isbn: "111",
    sisStudentId: "SIS-STU-10421",
  };
  const fine = buildReturnFinePayload("f-1", issue, 15, 3, NOW);
  assertEquals(fine.id, "f-1");
  assertEquals(fine.memberName, "Arjun Patel");
  assertEquals(fine.bookTitle, "Beta");
  assertEquals(fine.amount, 15);
  assertEquals(fine.daysOverdue, 3);
  assertEquals(fine.status, "outstanding");
  assertEquals(fine.sisStudentId, "SIS-STU-10421");
  assertEquals(fine.issueId, "iss-9");
  assertEquals(fine.raisedDate, "2026-06-26");
});

// --- normalizeResourceUrl (LIBRA-4 real content pointer) --------------------

Deno.test("normalizeResourceUrl: accepts http(s) links", () => {
  assertEquals(
    normalizeResourceUrl("https://cdn.example.com/ncert-sci-10.pdf"),
    "https://cdn.example.com/ncert-sci-10.pdf",
  );
  assertEquals(
    normalizeResourceUrl("http://example.org/a"),
    "http://example.org/a",
  );
});

Deno.test("normalizeResourceUrl: rejects missing / non-http URLs", () => {
  assertThrows(() => normalizeResourceUrl(undefined), WriteValidationError);
  assertThrows(() => normalizeResourceUrl("not a url"), WriteValidationError);
  assertThrows(() => normalizeResourceUrl("ftp://example.com/x"), WriteValidationError);
  assertThrows(() => normalizeResourceUrl("javascript:alert(1)"), WriteValidationError);
});

// --- computeFines merge (persisted fine entities surface, waived excluded) ---

Deno.test("computeFines: a persisted outstanding fine appears and counts toward pending", () => {
  const fineEntity = {
    id: "f-1",
    memberName: "Arjun Patel",
    bookTitle: "Beta",
    amount: 15,
    daysOverdue: 3,
    status: "outstanding",
    sisStudentId: "SIS-1",
  };
  const result = computeFines([], [], [fineEntity], NOW);
  const fines = result.fines as Array<Record<string, unknown>>;
  assertEquals(fines.length, 1);
  assertEquals(fines[0].id, "f-1");
  assertEquals(fines[0].memberName, "Arjun Patel");
  assertEquals(fines[0].amount, "₹15");
  assertEquals(fines[0].status, "pending");
  assertEquals(fines[0].financeLinked, true);
  assertEquals(result.totalPending, "₹15");
});

Deno.test("computeFines: a waived fine is listed but excluded from pending total", () => {
  const waived = {
    id: "f-2",
    memberName: "Priya Sharma",
    bookTitle: "Gamma",
    amount: 40,
    daysOverdue: 8,
    status: "waived",
    sisStudentId: null,
  };
  const result = computeFines([], [], [waived], NOW);
  const fines = result.fines as Array<Record<string, unknown>>;
  assertEquals(fines.length, 1);
  assertEquals(fines[0].status, "waived");
  assertEquals(fines[0].financeLinked, false);
  assertEquals(result.totalPending, "₹0");
});

// --- intFromString -----------------------------------------------------------

Deno.test("intFromString: parses numbers and numeric strings, falls back otherwise", () => {
  assertEquals(intFromString(3), 3);
  assertEquals(intFromString("4"), 4);
  assertEquals(intFromString(undefined, 7), 7);
  assertEquals(intFromString("abc", 1), 1);
});
