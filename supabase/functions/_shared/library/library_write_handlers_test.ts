import { assertEquals, assertThrows } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { WriteValidationError } from "../entity_write/module_write_handlers.ts";
import {
  assertBookDeletable,
  assertIssueAllowed,
  assertRenewAllowed,
  assertReturnAllowed,
  buildMemberPayload,
  buildReturnFinePayload,
  DEFAULT_LIBRARY_SETTINGS,
  intFromString,
  type LibrarySettings,
  normalizeResourceUrl,
  normalizeSettings,
} from "./library_write_handlers.ts";
import { computeFines } from "./library_aggregations.ts";

const NOW = new Date("2026-06-26T10:00:00.000Z");

function settings(over: Partial<LibrarySettings> = {}): LibrarySettings {
  return { ...DEFAULT_LIBRARY_SETTINGS, ...over } as LibrarySettings;
}

function catalogBook(over: Record<string, unknown> = {}): Record<string, unknown> {
  return { id: "b1", isbn: "111", title: "Book", totalCopies: 3, availableCopies: 3, ...over };
}

function loan(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: "iss-1",
    memberName: "Arjun",
    isbn: "111",
    status: "active",
    dueDate: "2026-07-10",
    renewalCount: 0,
    ...over,
  };
}

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

// ── P0 issue guards (assertIssueAllowed) ─────────────────────────────────────

Deno.test("issue: a clean issue with copies available and no fines passes", () => {
  // Should NOT throw.
  assertIssueAllowed("Arjun", "111", [], [], catalogBook(), settings(), NOW);
});

Deno.test("issue: duplicate ACTIVE loan for same member+book is rejected", () => {
  const issues = [loan({ memberName: "Arjun", isbn: "111", status: "active" })];
  const err = assertThrows(
    () => assertIssueAllowed("Arjun", "111", issues, [], catalogBook(), settings(), NOW),
    WriteValidationError,
    "already has an active loan",
  );
  assertEquals(err.status, 422);
});

Deno.test("issue: a RETURNED prior loan for the same book does NOT block a re-issue", () => {
  const issues = [loan({ memberName: "Arjun", isbn: "111", status: "returned" })];
  assertIssueAllowed("Arjun", "111", issues, [], catalogBook(), settings(), NOW);
});

Deno.test("issue: over-issue against zero stock is rejected", () => {
  assertThrows(
    () => assertIssueAllowed("Arjun", "111", [], [], catalogBook({ availableCopies: 0 }), settings(), NOW),
    WriteValidationError,
    "No copies available to issue",
  );
});

Deno.test("issue: an unknown book (no catalog row) skips the stock check", () => {
  // book === undefined => availability not enforced (loan still recorded).
  assertIssueAllowed("Arjun", "999", [], [], undefined, settings(), NOW);
});

Deno.test("issue: loan cap enforced — 3rd concurrent loan rejected at maxBooksPerMember=2", () => {
  const issues = [
    loan({ memberName: "Arjun", isbn: "111", status: "active" }),
    loan({ memberName: "Arjun", isbn: "222", status: "active" }),
  ];
  assertThrows(
    () => assertIssueAllowed("Arjun", "333", issues, [], catalogBook({ isbn: "333" }), settings(), NOW),
    WriteValidationError,
    "Loan limit reached",
  );
});

Deno.test("issue: a higher maxBooksPerMember setting allows the 3rd loan", () => {
  const issues = [
    loan({ memberName: "Arjun", isbn: "111", status: "active" }),
    loan({ memberName: "Arjun", isbn: "222", status: "active" }),
  ];
  assertIssueAllowed(
    "Arjun",
    "333",
    issues,
    [],
    catalogBook({ isbn: "333" }),
    settings({ maxBooksPerMember: 5 }),
    NOW,
  );
});

Deno.test("issue: blocked when outstanding un-waived fine exceeds threshold", () => {
  const fines = [{ memberName: "Arjun", amount: 150, status: "outstanding" }];
  assertThrows(
    () => assertIssueAllowed("Arjun", "111", [], fines, catalogBook(), settings(), NOW),
    WriteValidationError,
    "exceeds the ₹100 limit",
  );
});

Deno.test("issue: a WAIVED fine does NOT count toward the block threshold", () => {
  const fines = [{ memberName: "Arjun", amount: 150, status: "waived" }];
  assertIssueAllowed("Arjun", "111", [], fines, catalogBook(), settings(), NOW);
});

Deno.test("issue: fine exactly AT the threshold is allowed (block is strictly-greater)", () => {
  const fines = [{ memberName: "Arjun", amount: 100, status: "outstanding" }];
  assertIssueAllowed("Arjun", "111", [], fines, catalogBook(), settings(), NOW);
});

// ── P0 double-return guard (assertReturnAllowed) ─────────────────────────────

Deno.test("return: an active loan may be returned", () => {
  assertReturnAllowed(loan({ status: "active" }));
});

Deno.test("return: a second return of an already-returned loan is rejected", () => {
  const err = assertThrows(
    () => assertReturnAllowed(loan({ status: "returned" })),
    WriteValidationError,
    "Book already returned",
  );
  assertEquals(err.status, 422);
});

// ── LIB-4 renew guards (assertRenewAllowed) ──────────────────────────────────

Deno.test("renew: an active loan under the cap may be renewed", () => {
  assertRenewAllowed(loan({ status: "active", renewalCount: 1 }), settings());
});

Deno.test("renew: a returned loan cannot be renewed", () => {
  assertThrows(
    () => assertRenewAllowed(loan({ status: "returned" }), settings()),
    WriteValidationError,
    "Cannot renew a returned loan",
  );
});

Deno.test("renew: renewal cap enforced at maxRenewals=2", () => {
  assertThrows(
    () => assertRenewAllowed(loan({ status: "active", renewalCount: 2 }), settings()),
    WriteValidationError,
    "Renewal limit reached",
  );
});

// ── LIB-2 delete guard (assertBookDeletable) ─────────────────────────────────

Deno.test("delete: a book with no active loans is deletable", () => {
  assertBookDeletable("111", [loan({ isbn: "111", status: "returned" })]);
});

Deno.test("delete: a book with a copy on an active loan is NOT deletable", () => {
  assertThrows(
    () => assertBookDeletable("111", [loan({ isbn: "111", status: "active" })]),
    WriteValidationError,
    "Cannot delete a book while a copy is on an active loan",
  );
});

// ── LIB-D1 settings normalisation ────────────────────────────────────────────

Deno.test("normalizeSettings: null => owner-agreed defaults", () => {
  const s = normalizeSettings(null);
  assertEquals(s.maxBooksPerMember, 2);
  assertEquals(s.maxRenewals, 2);
  assertEquals(s.blockOnFineThreshold, 100);
});

Deno.test("normalizeSettings: reads camelCase and snake_case, coerces strings", () => {
  assertEquals(normalizeSettings({ maxBooksPerMember: "4" }).maxBooksPerMember, 4);
  assertEquals(normalizeSettings({ max_renewals: 3 }).maxRenewals, 3);
  assertEquals(normalizeSettings({ block_on_fine_threshold: "250" }).blockOnFineThreshold, 250);
});

Deno.test("normalizeSettings: a negative value falls back to the default", () => {
  assertEquals(normalizeSettings({ maxBooksPerMember: -1 }).maxBooksPerMember, 2);
});
