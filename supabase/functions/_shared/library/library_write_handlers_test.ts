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
  LIBRARY_OVERDUE_AUDIENCE,
  type LibrarySettings,
  normalizeResourceUrl,
  normalizeSettings,
  planImportRow,
  runOverdueReminder,
} from "./library_write_handlers.ts";
import { computeFines } from "./library_aggregations.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { AccessTokenClaims } from "../jwt.ts";

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

// --- LIB-2 bulk import: pure per-row accept/reject + ISBN dedupe -------------

Deno.test("planImportRow: a valid row is accepted with a catalog payload", () => {
  const plan = planImportRow(
    { isbn: "978-1", title: "Algebra", author: "Rao", totalCopies: 4 },
    "id-1",
    new Set<string>(),
  );
  assertEquals(plan.ok, true);
  if (plan.ok) {
    assertEquals(plan.isbn, "978-1");
    assertEquals(plan.payload.title, "Algebra");
    assertEquals(plan.payload.totalCopies, 4);
    assertEquals(plan.payload.availableCopies, 4);
    assertEquals(plan.payload.status, "available");
  }
});

Deno.test("planImportRow: a non-object row is rejected", () => {
  assertEquals(planImportRow("not a row", "id-1", new Set()), {
    ok: false,
    reason: "Row must be an object",
  });
  assertEquals(planImportRow(null, "id-1", new Set()), {
    ok: false,
    reason: "Row must be an object",
  });
});

Deno.test("planImportRow: a row missing a required field is rejected (not thrown)", () => {
  // No title/author → buildBookPayload's requireStr fails; the row is collected
  // as a per-row failure rather than aborting the whole import.
  const plan = planImportRow({ isbn: "978-2" }, "id-1", new Set());
  assertEquals(plan.ok, false);
  if (!plan.ok) assertEquals(plan.reason.length > 0, true);
});

Deno.test("planImportRow: a duplicate ISBN (already seen) is rejected", () => {
  const seen = new Set<string>(["978-1"]);
  assertEquals(
    planImportRow(
      { isbn: "978-1", title: "Dup", author: "Rao" },
      "id-2",
      seen,
    ),
    { ok: false, reason: "A book with this ISBN already exists" },
  );
});

// ── LIB-5 overdue reminder rides the XCT-2 rail (runOverdueReminder) ──────────
//
// Capturing fake TenantQueryClient (same pattern as
// reminders/reminders_service_test.ts): the open-loans SELECT returns the
// seeded issue rows; the scheduled-broadcast INSERT echoes a row back so
// scheduleReminder resolves a broadcastId. Proves LIB-5 now SCHEDULES ONE
// all_parents digest on the ONE rail (persisted 'scheduled', not an immediate
// send) instead of the old blast-all-parents sendBroadcastMessage.

const OVERDUE_ORG = "org-1";
const OVERDUE_SCHOOL = "school-1";

function overdueClaims(): AccessTokenClaims {
  return {
    sub: "u-lib",
    tenant_id: OVERDUE_ORG,
    organization_id: OVERDUE_ORG,
    school_id: OVERDUE_SCHOOL,
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
    permissions: ["sendBroadcast", "viewCommunications", "manageLibrary"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  } as unknown as AccessTokenClaims;
}

function overdueFakeDb(
  issues: Record<string, unknown>[],
): { db: TenantQueryClient; calls: Array<{ sql: string; args: unknown[] }> } {
  const calls: Array<{ sql: string; args: unknown[] }> = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, args: unknown[] = []): Promise<any[]> {
      calls.push({ sql, args });
      if (/FROM library_entities/.test(sql)) {
        return Promise.resolve(issues.map((payload) => ({ payload })));
      }
      if (/INSERT INTO comm_broadcasts/.test(sql)) {
        // Echo the scheduled row the way createScheduledBroadcast RETURNINGs it.
        return Promise.resolve([{
          id: "rem-lib5",
          organization_id: args[0],
          school_id: args[1],
          audience: args[2],
          status: "scheduled",
          scheduled_at: args[8],
        }]);
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

/** A loan overdue regardless of the wall clock (dueDate far in the past). */
function overdueLoan(over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    id: "iss-od",
    memberName: "Arjun",
    isbn: "111",
    bookTitle: "Algebra",
    status: "active",
    dueDate: "2000-01-01",
    ...over,
  };
}

Deno.test("LIB-5: overdue loans schedule ONE all_parents reminder on the XCT-2 rail + audit", async () => {
  const { db, calls } = overdueFakeDb([
    overdueLoan({ id: "a", bookTitle: "Algebra" }),
    overdueLoan({ id: "b", bookTitle: "Physics" }),
  ]);

  const result = await runOverdueReminder(db, overdueClaims(), OVERDUE_ORG, OVERDUE_SCHOOL);

  assertEquals(result.recipientCount, 2);
  assertEquals(result.reminderId, "rem-lib5");

  // ONE scheduled reminder rides the rail — persisted 'scheduled', not sent now.
  const inserts = calls.filter((c) => /INSERT INTO comm_broadcasts/.test(c.sql));
  assertEquals(inserts.length, 1);
  assertEquals(inserts[0].sql.includes("'scheduled'"), true);
  // Fired to the valid, role-scoped parent audience (not the old alias "parents").
  assertEquals(inserts[0].args[2], "all_parents");
  assertEquals(inserts[0].args[2], LIBRARY_OVERDUE_AUDIENCE);
  // Copy is broadcast-appropriate (not the old misleading "You have N ...").
  assertEquals(String(inserts[0].args[7]).includes("If your child has"), true);
  assertEquals(String(inserts[0].args[7]).includes("Algebra"), true);

  // The run is audited (library.overdue.reminded carries count + reminderId).
  const audits = calls.filter((c) => /INSERT INTO audit_events/.test(c.sql));
  assertEquals(audits.length >= 1, true);
  assertEquals(
    audits.some((c) => c.args.some((a) => String(a).includes("library.overdue.reminded"))),
    true,
  );
});

Deno.test("LIB-5: no overdue loans → nothing rides the rail, recipientCount 0", async () => {
  const { db, calls } = overdueFakeDb([
    overdueLoan({ id: "future", dueDate: "2999-01-01" }), // not yet due
    overdueLoan({ id: "returned", status: "returned" }), // returned → excluded
  ]);

  const result = await runOverdueReminder(db, overdueClaims(), OVERDUE_ORG, OVERDUE_SCHOOL);

  assertEquals(result.recipientCount, 0);
  assertEquals(result.reminderId, "");
  // Check-at-trigger-time: nothing overdue → NOTHING is scheduled on the rail.
  assertEquals(calls.some((c) => /INSERT INTO comm_broadcasts/.test(c.sql)), false);
});
