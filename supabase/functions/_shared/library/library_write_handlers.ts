import type { AppConfig } from "../config.ts";
import {
  boolOr,
  createModuleWriteHandlers,
  intOr,
  requireStr,
  str,
  WriteNotFoundError,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import { scheduleReminder } from "../reminders/reminders_service.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  FINE_PER_DAY,
  listAllEntities,
  outstandingFineForMember,
  overdueOpenLoans,
} from "./library_aggregations.ts";

const writeStore = createEntityWriteStore("library_entities", "Library");
const { runWrite } = createModuleWriteHandlers("manageLibrary");

const LOAN_DAYS = 14;

/**
 * LIB-5 — overdue reminders fan out to the whole parent body on the shared XCT-2
 * rail. The broadcast audience model resolves recipients at FIRE time and has no
 * "these specific borrowers" token, so — exactly like TRN-8 (`all_staff`
 * doc-expiry digest) and INV-7 (`storekeepers` low-stock digest) — LIB-5
 * schedules ONE `all_parents` digest rather than inventing a per-borrower
 * targeting path outside the rail.
 */
export const LIBRARY_OVERDUE_AUDIENCE = "all_parents";

/** Library member roles a caller may enrol. */
const MEMBER_TYPES = new Set(["student", "staff", "teacher"]);

/** The three enrollable library member roles (P2-12 per-type loan caps). */
export type LibraryMemberType = "student" | "staff" | "teacher";
const MEMBER_TYPE_KEYS: LibraryMemberType[] = ["student", "staff", "teacher"];

/**
 * LIB-D1 — configurable circulation guardrails, stored as a single
 * `snapshot_settings` entity row (no migration; row-locked via mutateSnapshot).
 * Defaults are the owner-agreed values: at most 2 concurrent loans / member,
 * up to 2 renewals per loan, and issue blocked once a member's outstanding
 * un-waived fine total exceeds ₹100.
 *
 * PRA-P2-12: the loan cap is no longer one global number for everyone —
 * `maxBooksByMemberType` gives students/teachers/staff distinct caps (a teacher
 * legitimately holds more than a student). `maxBooksPerMember` is kept as the
 * global fallback for an unknown member type (and for back-compat with schools
 * that only ever set the single global number).
 * PRA-P1-42: `lostBookReplacementFee` is the flat replacement charge levied when
 * a book is returned `lost` (the copy never comes back to stock).
 */
export interface LibrarySettings {
  maxBooksPerMember: number;
  maxBooksByMemberType: Record<LibraryMemberType, number>;
  maxRenewals: number;
  blockOnFineThreshold: number;
  lostBookReplacementFee: number;
  /** Settings are numbers, plus the one per-type numeric map; the index
   * signature lets a settings object satisfy the generic
   * `Record<string, unknown>` payload/read contracts. */
  [key: string]: number | Record<string, number>;
}

export const DEFAULT_LIBRARY_SETTINGS: LibrarySettings = {
  maxBooksPerMember: 2,
  maxBooksByMemberType: { student: 2, teacher: 5, staff: 5 },
  maxRenewals: 2,
  blockOnFineThreshold: 100,
  lostBookReplacementFee: 300,
};

/** The valid return conditions (PRA-P1-42 adds `lost`, mirroring the Dart
 * `LibraryReturnCondition` enum). A `lost` return levies the replacement fee
 * and does NOT restock the copy. */
export const RETURN_CONDITIONS = new Set(["good", "fair", "damaged", "lost"]);

/** PRA-P1-42 — conditions under which the returned copy does NOT go back to
 * stock and a replacement charge is raised. Kept as a set so the policy is easy
 * to extend (e.g. if `damaged` later becomes non-restockable by owner policy). */
export const NON_RESTOCK_CONDITIONS = new Set(["lost"]);

/** The effective concurrent-loan cap for a member of `memberType`: the per-type
 * cap when configured, else the global fallback (PRA-P2-12). */
export function capForMemberType(settings: LibrarySettings, memberType: string): number {
  const perType = settings.maxBooksByMemberType?.[memberType as LibraryMemberType];
  return typeof perType === "number" && perType >= 0 ? perType : settings.maxBooksPerMember;
}

export const SETTINGS_ENTITY = "snapshot_settings";

/** Coerce a persisted/settings value to a non-negative integer with a fallback. */
function nonNegInt(value: unknown, fallback: number): number {
  const n = intFromString(value, fallback);
  return n < 0 ? fallback : n;
}

/** Normalise a raw settings snapshot payload into a fully-defaulted object. */
export function normalizeSettings(raw: Record<string, unknown> | null): LibrarySettings {
  const src = raw ?? {};
  const maxBooksPerMember = nonNegInt(
    src.maxBooksPerMember ?? (src as Record<string, unknown>).max_books_per_member,
    DEFAULT_LIBRARY_SETTINGS.maxBooksPerMember,
  );

  // PRA-P2-12 per-type caps. Precedence per type: an explicit per-type value →
  // the school's stored GLOBAL cap (back-compat: a library that only ever set
  // `maxBooksPerMember` keeps it applied to every type) → the built-in per-type
  // default (a brand-new library, with no global stored, gets the sensible
  // student=2 / teacher=staff=5 defaults).
  const globalPresent = "maxBooksPerMember" in src || "max_books_per_member" in src;
  const perTypeRaw = src.maxBooksByMemberType ??
    (src as Record<string, unknown>).max_books_by_member_type;
  const perTypeSrc = (perTypeRaw && typeof perTypeRaw === "object")
    ? perTypeRaw as Record<string, unknown>
    : {};
  const maxBooksByMemberType = {
    student: 0,
    staff: 0,
    teacher: 0,
  } as Record<LibraryMemberType, number>;
  for (const type of MEMBER_TYPE_KEYS) {
    const fallback = globalPresent
      ? maxBooksPerMember
      : DEFAULT_LIBRARY_SETTINGS.maxBooksByMemberType[type];
    maxBooksByMemberType[type] = nonNegInt(perTypeSrc[type], fallback);
  }

  return {
    maxBooksPerMember,
    maxBooksByMemberType,
    maxRenewals: nonNegInt(
      src.maxRenewals ?? (src as Record<string, unknown>).max_renewals,
      DEFAULT_LIBRARY_SETTINGS.maxRenewals,
    ),
    blockOnFineThreshold: nonNegInt(
      src.blockOnFineThreshold ?? (src as Record<string, unknown>).block_on_fine_threshold,
      DEFAULT_LIBRARY_SETTINGS.blockOnFineThreshold,
    ),
    lostBookReplacementFee: nonNegInt(
      src.lostBookReplacementFee ?? (src as Record<string, unknown>).lost_book_replacement_fee,
      DEFAULT_LIBRARY_SETTINGS.lostBookReplacementFee,
    ),
  };
}

/** Read the effective settings (defaults when the snapshot row is absent). */
async function readSettings(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<LibrarySettings> {
  const raw = await writeStore.find(db, organizationId, schoolId, SETTINGS_ENTITY, "default");
  return normalizeSettings(raw);
}

function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function findCatalogByIsbn(
  books: Array<Record<string, unknown>>,
  isbn: string,
): Record<string, unknown> | undefined {
  return books.find((book) => String(book.isbn ?? "") === isbn);
}

/** Coerce a possibly-stringified integer payload field to a number. */
export function intFromString(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === "string") {
    const parsed = parseInt(value, 10);
    if (!Number.isNaN(parsed)) return parsed;
  }
  return fallback;
}

/**
 * Build a `member` entity payload from a request body. Throws
 * {@link WriteValidationError} for a missing name / invalid role. Pure so it is
 * unit-testable without an auth/tenant harness.
 */
export function buildMemberPayload(
  body: Record<string, unknown>,
  id: string,
): Record<string, unknown> {
  const memberType = (str(body, "memberType", "member_type") ?? "student").toLowerCase();
  if (!MEMBER_TYPES.has(memberType)) {
    throw new WriteValidationError("memberType must be one of: student, staff, teacher");
  }
  return {
    id,
    name: requireStr(body, "name"),
    memberType,
    identifier: str(body, "identifier") ?? "",
    classOrDepartment: str(body, "classOrDepartment", "class_or_department") ?? "",
    activeLoans: 0,
    status: "active",
    sisStudentId: str(body, "sisStudentId", "sis_student_id") ?? null,
  };
}

/**
 * Build a `fine` entity payload raised when a book is returned overdue or lost.
 * `amount` is stored as a number (rupees); the read layer formats it. `reason`
 * distinguishes an overdue-day fine from a PRA-P1-42 lost-book replacement
 * charge (default "overdue" so existing overdue callers are unchanged). Pure for
 * unit-testing.
 */
export function buildReturnFinePayload(
  fineId: string,
  issue: Record<string, unknown>,
  amount: number,
  daysOverdue: number,
  now: Date,
  reason = "overdue",
): Record<string, unknown> {
  return {
    id: fineId,
    memberName: (issue.memberName as string | undefined) ?? "",
    bookTitle: (issue.bookTitle as string | undefined) ?? "",
    isbn: (issue.isbn as string | undefined) ?? "",
    amount,
    daysOverdue,
    reason,
    status: "outstanding",
    sisStudentId: (issue.sisStudentId as string | undefined) ?? null,
    raisedDate: isoDate(now),
    issueId: String(issue.id ?? ""),
  };
}

/** The outcome of the pure return charge/stock decision (PRA-P1-42). */
export interface ReturnChargeOutcome {
  overdueFine: number;
  replacementFee: number;
  totalCharge: number;
  /** True when the copy is returned to stock; false for a lost (non-restock) copy. */
  restocked: boolean;
  /** "lost" when a replacement charge applies, else "overdue". */
  fineReason: string;
}

/**
 * PRA-P1-42 — the pure charge + restock decision for a returned book. A `lost`
 * (non-restock) condition levies the flat replacement fee ON TOP of any overdue
 * accrued and keeps the copy OUT of stock; every other condition is overdue-only
 * and restocks. Exported for DB-free unit tests.
 */
export function computeReturnCharge(
  condition: string,
  daysOverdue: number,
  settings: LibrarySettings,
): ReturnChargeOutcome {
  const overdueFine = Math.max(0, daysOverdue) * FINE_PER_DAY;
  const nonRestock = NON_RESTOCK_CONDITIONS.has(condition);
  const replacementFee = nonRestock ? Math.max(0, settings.lostBookReplacementFee) : 0;
  const totalCharge = overdueFine + replacementFee;
  return {
    overdueFine,
    replacementFee,
    totalCharge,
    restocked: !nonRestock,
    fineReason: replacementFee > 0 ? "lost" : "overdue",
  };
}

// ── Pure integrity guards (DB-free, unit-testable) ───────────────────────────
// Each throws a WriteValidationError with the exact message/status a client
// receives; the handlers fetch the rows then delegate to these so the guard
// logic can be asserted without a live Postgres (mirrors the HR guard pattern).

type Row = Record<string, unknown>;

/**
 * P0 issue guards, in order: duplicate active loan → loan cap → fine threshold →
 * zero stock. `issues`/`fines` are ALL rows for the school; `book` is the
 * matched catalog row (undefined when the ISBN is not in the catalogue —
 * availability is only enforced for a known book).
 *
 * PRA-P2-12: the loan cap is per member type — the caller passes the member's
 * `memberType` so a teacher/staff cap can differ from a student cap (the cap was
 * previously one global number for everyone).
 */
export function assertIssueAllowed(
  memberName: string,
  memberType: string,
  isbn: string,
  issues: Row[],
  fines: Row[],
  book: Row | undefined,
  settings: LibrarySettings,
  now: Date = new Date(),
): void {
  const openForMember = issues.filter((i) =>
    String(i.status ?? "active") !== "returned" &&
    String(i.memberName ?? "") === memberName
  );

  if (openForMember.some((i) => String(i.isbn ?? "") === isbn)) {
    throw new WriteValidationError(
      "This member already has an active loan for this book — renew or return it first",
    );
  }
  const cap = capForMemberType(settings, memberType);
  if (openForMember.length >= cap) {
    throw new WriteValidationError(
      `Loan limit reached — a ${memberType} may hold at most ${cap} book(s) at a time`,
    );
  }
  const outstanding = outstandingFineForMember(memberName, issues, fines, now);
  if (outstanding > settings.blockOnFineThreshold) {
    throw new WriteValidationError(
      `Outstanding fine of ₹${outstanding} exceeds the ₹${settings.blockOnFineThreshold} limit — clear or waive it before issuing`,
    );
  }
  if (book && intFromString(book.availableCopies, 0) <= 0) {
    throw new WriteValidationError("No copies available to issue");
  }
}

/** P0 double-return guard: a returned loan cannot be returned again. */
export function assertReturnAllowed(issue: Row): void {
  if (String(issue.status ?? "active") === "returned") {
    throw new WriteValidationError("Book already returned");
  }
}

/** LIB-4 renew guards: not returned, and under the renewal cap. */
export function assertRenewAllowed(issue: Row, settings: LibrarySettings): void {
  if (String(issue.status ?? "active") === "returned") {
    throw new WriteValidationError("Cannot renew a returned loan");
  }
  if (intFromString(issue.renewalCount, 0) >= settings.maxRenewals) {
    throw new WriteValidationError("Renewal limit reached");
  }
}

/** LIB-2 delete guard: block while any copy of the book is on an active loan. */
export function assertBookDeletable(isbn: string, issues: Row[]): void {
  if (isbn.length === 0) return;
  const onLoan = issues.some((i) =>
    String(i.isbn ?? "") === isbn && String(i.status ?? "active") !== "returned"
  );
  if (onLoan) {
    throw new WriteValidationError(
      "Cannot delete a book while a copy is on an active loan — return it first",
    );
  }
}

/** POST /library/members — enrol a member (student / staff / teacher). */
export async function handleEnrollMember(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const payload = buildMemberPayload(body, id);
    const saved = await writeStore.insert(db, organizationId, schoolId, "member", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.member.enrolled", "library_member", id, {
        memberType: payload.memberType,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** Build a catalog book payload from a body, defaulting copies/category/shelf. */
function buildBookPayload(body: Record<string, unknown>, id: string): Record<string, unknown> {
  const totalCopies = Math.max(1, intOr(body, 1, "totalCopies", "total_copies"));
  return {
    id,
    isbn: requireStr(body, "isbn"),
    title: requireStr(body, "title"),
    author: requireStr(body, "author"),
    category: str(body, "category") ?? "General",
    totalCopies,
    availableCopies: totalCopies,
    shelf: str(body, "shelf") ?? "Unshelved",
    status: "available",
  };
}

/** POST /library/catalog — add a book to the catalogue. */
export async function handleAddBook(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const payload = buildBookPayload(body, id);

    // P0 (LIB integrity): ISBN is unique per school. A blank ISBN is not
    // deduped (optional-field convention) — but add requires ISBN, so it is
    // always present here. Lock the catalog set implicitly via the same tenant
    // txn: a concurrent duplicate is serialized by the surrounding transaction.
    const isbn = String(payload.isbn);
    if (isbn.length > 0) {
      const books = await writeStore.findAll(db, organizationId, schoolId, "catalog");
      if (findCatalogByIsbn(books, isbn)) {
        throw new WriteValidationError("A book with this ISBN already exists");
      }
    }

    const saved = await writeStore.insert(db, organizationId, schoolId, "catalog", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.book.added", "library_book", id, { isbn: payload.isbn }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** PUT /library/catalog/:id — LIB-2: edit an existing catalogue book. */
export async function handleUpdateBook(
  req: Request,
  config: AppConfig,
  bookId: string,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const existing = await writeStore.find(db, organizationId, schoolId, "catalog", bookId);
    if (!existing) {
      throw new WriteNotFoundError(`Library book not found: ${bookId}`);
    }

    const newIsbn = str(body, "isbn") ?? String(existing.isbn ?? "");
    // ISBN stays unique per school; a book may keep its OWN isbn (skip self).
    if (newIsbn.length > 0) {
      const books = await writeStore.findAll(db, organizationId, schoolId, "catalog");
      const clash = books.find(
        (b) => String(b.isbn ?? "") === newIsbn && String(b.id ?? "") !== bookId,
      );
      if (clash) {
        throw new WriteValidationError("A book with this ISBN already exists");
      }
    }

    // Preserve the on-loan delta: totalCopies may change, but availableCopies
    // must move by the same delta so the count of copies currently issued
    // (total - available) is unchanged by an edit.
    const prevTotal = intOr(existing, 0, "totalCopies");
    const prevAvailable = intOr(existing, 0, "availableCopies");
    const onLoan = Math.max(0, prevTotal - prevAvailable);
    const nextTotal = Math.max(
      onLoan,
      "totalCopies" in body || "total_copies" in body
        ? Math.max(1, intOr(body, prevTotal, "totalCopies", "total_copies"))
        : prevTotal,
    );
    const nextAvailable = Math.max(0, nextTotal - onLoan);

    const payload = {
      ...existing,
      id: bookId,
      isbn: newIsbn,
      title: str(body, "title") ?? existing.title,
      author: str(body, "author") ?? existing.author,
      category: str(body, "category") ?? existing.category,
      shelf: str(body, "shelf") ?? existing.shelf,
      totalCopies: nextTotal,
      availableCopies: nextAvailable,
      status: nextAvailable <= 0 ? "issued" : "available",
    };
    const saved = await writeStore.replace(db, organizationId, schoolId, "catalog", bookId, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.book.updated", "library_book", bookId, { isbn: newIsbn }),
      request,
    );
    return { payload: saved ?? payload, status: 200 };
  });
}

/** DELETE /library/catalog/:id — LIB-2: remove a book (blocked when on loan). */
export async function handleDeleteBook(
  req: Request,
  config: AppConfig,
  bookId: string,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const book = await writeStore.find(db, organizationId, schoolId, "catalog", bookId);
    if (!book) {
      throw new WriteNotFoundError(`Library book not found: ${bookId}`);
    }

    // Block deletion while any copy is on an active loan — deleting would orphan
    // the outstanding issue and corrupt the copy count / fine trail.
    const isbn = String(book.isbn ?? "");
    if (isbn.length > 0) {
      const issues = await writeStore.findAll(db, organizationId, schoolId, "issue");
      assertBookDeletable(isbn, issues);
    }

    await writeStore.remove(db, organizationId, schoolId, "catalog", bookId);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.book.deleted", "library_book", bookId, { isbn }),
      request,
    );
    return { payload: { id: bookId, deleted: true }, status: 200 };
  });
}

/**
 * POST /library/catalog/import — LIB-2: bulk-import books with per-row
 * validation + ISBN dedupe. Returns {imported, failed:[{row, reason}]} so a
 * partial import surfaces exactly which rows were skipped and why (mirrors the
 * onboarding per-row SAVEPOINT failure-report pattern conceptually — here each
 * row is validated in-memory before insert, and a duplicate/invalid row fails
 * without aborting the whole batch). Dedupe is enforced BOTH against the
 * existing catalogue AND within the batch itself.
 */
/** LIB-2: the pure accept/reject decision for one bulk-import row — validates it
 * into a catalog payload and dedupes its ISBN against the ISBNs already seen
 * (existing catalogue + earlier rows in this import). The handler owns the
 * SAVEPOINT/INSERT; this owns the decision so partial-success import is
 * unit-testable. A blank ISBN is never deduped (optional-field convention). */
export type ImportRowPlan =
  | { ok: true; payload: Record<string, unknown>; isbn: string }
  | { ok: false; reason: string };

export function planImportRow(
  raw: unknown,
  id: string,
  seenIsbns: Set<string>,
): ImportRowPlan {
  if (raw === null || typeof raw !== "object") {
    return { ok: false, reason: "Row must be an object" };
  }
  let payload: Record<string, unknown>;
  try {
    payload = buildBookPayload(raw as Record<string, unknown>, id);
  } catch (error) {
    return {
      ok: false,
      reason: error instanceof WriteValidationError
        ? error.message
        : (error instanceof Error ? error.message : "Import failed"),
    };
  }
  const isbn = String(payload.isbn);
  if (isbn.length > 0 && seenIsbns.has(isbn)) {
    return { ok: false, reason: "A book with this ISBN already exists" };
  }
  return { ok: true, payload, isbn };
}

export async function handleBulkImportBooks(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const rows = Array.isArray(body.books)
      ? body.books as Array<unknown>
      : Array.isArray((body as { rows?: unknown }).rows)
      ? (body as { rows: unknown[] }).rows
      : null;
    if (!rows) {
      throw new WriteValidationError("books must be a non-empty array of book rows");
    }
    if (rows.length === 0) {
      throw new WriteValidationError("books must be a non-empty array of book rows");
    }

    const existing = await writeStore.findAll(db, organizationId, schoolId, "catalog");
    const seenIsbns = new Set(existing.map((b) => String(b.isbn ?? "")).filter((s) => s.length > 0));

    let imported = 0;
    const failed: Array<{ row: number; reason: string }> = [];

    for (let index = 0; index < rows.length; index++) {
      const rowNum = index + 1;
      const plan = planImportRow(rows[index], crypto.randomUUID(), seenIsbns);
      if (!plan.ok) {
        failed.push({ row: rowNum, reason: plan.reason });
        continue;
      }
      // Per-row SAVEPOINT so a single bad insert rolls back only that row and
      // does NOT poison the outer tenant transaction (onboarding import pattern).
      await db.queryObject(`SAVEPOINT library_import_row`);
      try {
        await writeStore.insert(
          db,
          organizationId,
          schoolId,
          "catalog",
          plan.payload.id as string,
          plan.payload,
        );
        await db.queryObject(`RELEASE SAVEPOINT library_import_row`);
        if (plan.isbn.length > 0) seenIsbns.add(plan.isbn);
        imported++;
      } catch (error) {
        await db.queryObject(`ROLLBACK TO SAVEPOINT library_import_row`);
        failed.push({
          row: rowNum,
          reason: error instanceof Error ? error.message : "Import failed",
        });
      }
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.catalog.imported", "library_catalog", schoolId, {
        imported,
        failedCount: failed.length,
        total: rows.length,
      }),
      request,
    );
    return { payload: { imported, failed }, status: 200 };
  });
}

/** POST /library/issues — issue a book to a member. */
export async function handleIssueBook(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const isbn = requireStr(body, "isbn");
    const memberId = requireStr(body, "memberId", "member_id");

    // A loan must be against a real, enrolled member — never a free-text id.
    // (Previously the memberId string was used as the member name, which let a
    //  garbage member create a phantom loan; MJ-H21 / LIBRA-1.)
    const member = await writeStore.find(db, organizationId, schoolId, "member", memberId);
    if (!member) {
      throw new WriteNotFoundError(`Library member not found: ${memberId}`);
    }
    const memberName = member.name as string;
    const memberType = (member.memberType as string | undefined) ?? "student";
    const books = await writeStore.findAll(db, organizationId, schoolId, "catalog");
    const book = findCatalogByIsbn(books, isbn);

    // Read the member's live loans + fines once for the guardrail checks below.
    const [issues, fines, settings] = await Promise.all([
      writeStore.findAll(db, organizationId, schoolId, "issue"),
      writeStore.findAll(db, organizationId, schoolId, "fine"),
      readSettings(db, organizationId, schoolId),
    ]);
    const now = new Date();

    // P0 + LIB-D1 integrity guards (duplicate-active loan, PER-TYPE loan cap
    // (PRA-P2-12), outstanding-fine threshold, zero-stock). Pure + DB-free; see
    // assertIssueAllowed. The zero-stock check here is a fast reject; the
    // authoritative last-copy check is re-done under the row lock below.
    assertIssueAllowed(memberName, memberType, isbn, issues, fines, book, settings, now);

    const due = new Date(now.getTime() + LOAN_DAYS * 24 * 60 * 60 * 1000);
    const id = crypto.randomUUID();
    const payload = {
      id,
      memberName,
      memberType: (member.memberType as string | undefined) ?? "student",
      bookTitle: (book?.title as string | undefined) ?? isbn,
      isbn,
      issuedDate: isoDate(now),
      dueDate: isoDate(due),
      status: "active",
      renewalCount: 0,
      sisStudentId: (member.sisStudentId as string | undefined) ?? null,
    };

    // P0 (availableCopies race): atomically re-check + decrement the catalog row
    // UNDER A ROW LOCK, so two concurrent issues can never lost-update the count
    // or both slip past a last-copy check. mutateEntity locks the row
    // (SELECT … FOR UPDATE) inside this same tenant txn. We re-read availability
    // inside the lock — the pre-lock check above is a fast reject; the locked
    // re-check is the authority.
    if (book) {
      let raced = false;
      await writeStore.mutateEntity(
        db,
        organizationId,
        schoolId,
        "catalog",
        String(book.id),
        (current) => {
          const available = intFromString(current.availableCopies, 0);
          if (available <= 0) {
            raced = true;
            return current; // no-op; we reject after releasing.
          }
          const next = available - 1;
          return {
            ...current,
            availableCopies: next,
            status: next <= 0 ? "issued" : "available",
          };
        },
      );
      if (raced) {
        throw new WriteValidationError("No copies available to issue");
      }
    }

    const saved = await writeStore.insert(db, organizationId, schoolId, "issue", id, payload);

    // Bump the member's live active-loan counter (best-effort mirror; the read
    // layer recomputes the authoritative count from open loans).
    await writeStore.replace(db, organizationId, schoolId, "member", memberId, {
      ...member,
      activeLoans: intFromString(member.activeLoans, 0) + 1,
    });

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.book.issued", "library_issue", id, { isbn, memberId }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** POST /library/returns — record a book return against an issue. */
export async function handleReturnBook(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const issueId = requireStr(body, "issueId", "issue_id");
    const condition = (str(body, "condition") ?? "good").toLowerCase();
    if (!RETURN_CONDITIONS.has(condition)) {
      throw new WriteValidationError(
        "condition must be one of: good, fair, damaged, lost",
      );
    }

    const issue = await writeStore.find(db, organizationId, schoolId, "issue", issueId);
    if (!issue) {
      throw new WriteNotFoundError(`Library issue not found: ${issueId}`);
    }

    // P0 (double-return): a loan already marked returned must not be returned
    // again — otherwise a second return raises a duplicate fine AND over-counts
    // the copy back into stock (mirrors the already-waived guard in
    // handleWaiveFine).
    assertReturnAllowed(issue);

    const settings = await readSettings(db, organizationId, schoolId);
    const now = new Date();
    const dueRaw = issue.dueDate as string | undefined;
    const due = dueRaw ? new Date(dueRaw) : now;
    const daysOverdue = Math.max(
      0,
      Math.floor((now.getTime() - due.getTime()) / (24 * 60 * 60 * 1000)),
    );
    // PRA-P1-42 — lost-book workflow. A `lost` return levies a flat replacement
    // charge (settings.lostBookReplacementFee) ON TOP of any overdue accrued, and
    // the copy is NOT returned to stock (skip the availableCopies increment
    // below). The total is persisted as ONE `fine` entity so it survives the
    // closed loan and can be waived, exactly like an overdue fine.
    const { replacementFee, totalCharge, restocked, fineReason } = computeReturnCharge(
      condition,
      daysOverdue,
      settings,
    );
    const nonRestock = !restocked;

    const memberName = (issue.memberName as string | undefined) ?? "";
    const id = crypto.randomUUID();
    const payload = {
      id,
      memberName,
      bookTitle: (issue.bookTitle as string | undefined) ?? "",
      isbn: (issue.isbn as string | undefined) ?? "",
      returnedDate: isoDate(now),
      condition,
      fineAmount: totalCharge > 0 ? `₹${totalCharge}` : "₹0",
      replacementFee,
      restocked,
      daysOverdue,
    };
    const saved = await writeStore.insert(
      db,
      organizationId,
      schoolId,
      "return_record",
      id,
      payload,
    );

    // Persist an outstanding fine entity so an overdue / lost-replacement charge
    // survives the return (and can later be waived) instead of vanishing with
    // the closed loan (LIBRA-2 / LIBRA-6 / PRA-P1-42).
    if (totalCharge > 0) {
      const fineId = crypto.randomUUID();
      await writeStore.insert(
        db,
        organizationId,
        schoolId,
        "fine",
        fineId,
        buildReturnFinePayload(fineId, issue, totalCharge, daysOverdue, now, fineReason),
      );
    }

    // Close the loan. (A lost copy still closes the loan so it stops counting as
    // an active/overdue holding; the physical copy simply never re-enters stock.)
    await writeStore.replace(db, organizationId, schoolId, "issue", issueId, {
      ...issue,
      status: "returned",
    });

    // Decrement the borrower's live active-loan counter (look up by name, the
    // identity carried on the issue row).
    const members = await writeStore.findAll(db, organizationId, schoolId, "member");
    const member = members.find((m) => String(m.name ?? "") === memberName);
    if (member) {
      const next = Math.max(0, intFromString(member.activeLoans, 0) - 1);
      await writeStore.replace(db, organizationId, schoolId, "member", String(member.id), {
        ...member,
        activeLoans: next,
      });
    }

    // PRA-P1-42: a lost (non-restock) copy is NOT returned to the catalogue — it
    // is gone, so availableCopies stays reduced. Only a physically-returned copy
    // is restocked.
    const isbn = String(issue.isbn ?? "");
    if (isbn && !nonRestock) {
      const books = await writeStore.findAll(db, organizationId, schoolId, "catalog");
      const book = findCatalogByIsbn(books, isbn);
      if (book) {
        // P0 (availableCopies race): increment the copy back under a row lock so
        // a concurrent issue/return can't lost-update the count. Clamp to
        // totalCopies read inside the lock.
        await writeStore.mutateEntity(
          db,
          organizationId,
          schoolId,
          "catalog",
          String(book.id),
          (current) => {
            const total = intFromString(current.totalCopies, 0);
            const available = Math.min(total, intFromString(current.availableCopies, 0) + 1);
            return { ...current, availableCopies: available, status: "available" };
          },
        );
      }
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.book.returned", "library_return", id, {
        issueId,
        daysOverdue,
        condition,
        replacementFee,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** Accept only a real, openable http(s) URL as a resource content pointer. */
export function normalizeResourceUrl(raw: string | undefined): string {
  if (!raw) {
    throw new WriteValidationError("resourceUrl is required and must be a valid http(s) link");
  }
  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    throw new WriteValidationError("resourceUrl must be a valid http(s) link");
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new WriteValidationError("resourceUrl must be a valid http(s) link");
  }
  return parsed.toString();
}

/** POST /library/digital-resources — add a digital resource to the shelf. */
export async function handleAddDigitalResource(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    // A digital resource must point at real, retrievable content — not be a
    // metadata-only shell (LIBRA-4). We store the URL and expose it on read.
    const resourceUrl = normalizeResourceUrl(str(body, "resourceUrl", "resource_url", "url"));
    const resource = {
      id,
      title: requireStr(body, "title"),
      type: str(body, "type") ?? "pdf",
      classAccess: str(body, "classAccess", "class_access") ?? "All classes",
      downloads: 0,
      resourceUrl,
      studentAppVisible: boolOr(body, true, "studentAppVisible", "student_app_visible"),
      teacherAppVisible: boolOr(body, true, "teacherAppVisible", "teacher_app_visible"),
    };
    await writeStore.mutateSnapshot(
      db,
      organizationId,
      schoolId,
      "snapshot_digital_resources",
      (current) => {
        const resources = Array.isArray(current.resources)
          ? current.resources as Array<unknown>
          : [];
        return { ...current, resources: [...resources, resource] };
      },
    );
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.digital_resource.added", "library_digital_resource", id, {
        title: resource.title,
      }),
      request,
    );
    return { payload: resource, status: 201 };
  });
}

/** POST /library/fines/:id/waive — waive an outstanding fine (audited). */
export async function handleWaiveFine(
  req: Request,
  config: AppConfig,
  fineId: string,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const fine = await writeStore.find(db, organizationId, schoolId, "fine", fineId);
    if (!fine) {
      throw new WriteNotFoundError(`Library fine not found: ${fineId}`);
    }
    if (String(fine.status ?? "") === "waived") {
      throw new WriteValidationError("Fine is already waived");
    }
    const updated = await writeStore.replace(db, organizationId, schoolId, "fine", fineId, {
      ...fine,
      status: "waived",
      waivedDate: isoDate(new Date()),
    });
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.fine.waived", "library_fine", fineId, {}),
      request,
    );
    return { payload: updated ?? { ...fine, status: "waived" }, status: 200 };
  });
}

/**
 * POST /library/issues/:id/renew — LIB-4: renew an ACTIVE loan, capped at
 * settings.maxRenewals. Extends dueDate by LOAN_DAYS and increments
 * renewalCount. A returned loan cannot be renewed.
 */
export async function handleRenewLoan(
  req: Request,
  config: AppConfig,
  issueId: string,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const issue = await writeStore.find(db, organizationId, schoolId, "issue", issueId);
    if (!issue) {
      throw new WriteNotFoundError(`Library issue not found: ${issueId}`);
    }
    const settings = await readSettings(db, organizationId, schoolId);
    assertRenewAllowed(issue, settings);
    const currentRenewals = intFromString(issue.renewalCount, 0);

    // Extend from the LATER of today or the existing due date, so a renewal
    // always pushes the due date forward (never backward for an overdue loan).
    const now = new Date();
    const existingDueRaw = issue.dueDate as string | undefined;
    const existingDue = existingDueRaw ? new Date(existingDueRaw) : now;
    const base = existingDue.getTime() > now.getTime() ? existingDue : now;
    const nextDue = new Date(base.getTime() + LOAN_DAYS * 24 * 60 * 60 * 1000);

    const payload = {
      ...issue,
      dueDate: isoDate(nextDue),
      renewalCount: currentRenewals + 1,
      status: "active",
    };
    const saved = await writeStore.replace(db, organizationId, schoolId, "issue", issueId, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.loan.renewed", "library_issue", issueId, {
        renewalCount: currentRenewals + 1,
      }),
      request,
    );
    return { payload: saved ?? payload, status: 200 };
  });
}

/**
 * LIB-5 core (exported so tests drive it with a fake db, mirroring TRN-8's
 * `runDocumentExpiryReminder`): scan the open loans at trigger time. Nothing
 * overdue → schedule nothing, `{recipientCount: 0}`. Otherwise schedule ONE
 * `all_parents` digest on the shared XCT-2 reminder rail ({@link scheduleReminder},
 * remindAt = now so it fires on the next runner pass into parents' in-app inboxes;
 * external SMS/WhatsApp stays owner-gated inside the rail) and audit the run with
 * the count + reminderId.
 *
 * Previously this fired an IMMEDIATE `sendBroadcastMessage` to `audience:"parents"`
 * with a body that read "You have N overdue item(s)" — misleading when blasted to
 * every parent, and off the ONE reminder rail every other module rides. Re-pointed
 * onto {@link scheduleReminder} so library overdue reminders can never diverge from
 * TRN-8 / INV-7 / EXM-6, with copy corrected for a broadcast audience.
 */
export async function runOverdueReminder(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  organizationId: string,
  schoolId: string,
  request?: Request,
): Promise<Record<string, unknown>> {
  const now = new Date();
  const issues = await listAllEntities(db, organizationId, schoolId, "issue");
  const overdue = overdueOpenLoans(issues, now);
  const recipientCount = overdue.length;

  let reminderId = "";
  if (recipientCount > 0) {
    const titles = [
      ...new Set(overdue.map((l) => String(l.issue.bookTitle ?? "")).filter((t) => t.length > 0)),
    ].slice(0, 5);
    const title = "Library — overdue book reminder";
    const body =
      `${recipientCount} library item(s) are overdue and not yet returned. If your child has ` +
      `borrowed a library book, please return it promptly to avoid further fines.` +
      (titles.length > 0 ? ` Overdue titles include: ${titles.join(", ")}.` : "");
    const scheduled = await scheduleReminder(
      db,
      claims,
      {
        audience: LIBRARY_OVERDUE_AUDIENCE,
        title,
        body,
        // Fire on the next scheduled-broadcast runner pass (i.e. promptly).
        remindAt: now.toISOString(),
      },
      request,
    );
    reminderId = String(scheduled.broadcastId ?? "");
  }

  await emitMutationAudit(
    db,
    claims,
    moduleEntityAudit("library.overdue.reminded", "library_reminder", schoolId, {
      recipientCount,
      reminderId,
    }),
    request,
  );
  return { recipientCount, reminderId };
}

/**
 * POST /library/reminders/overdue — LIB-5: schedule an IN-APP overdue reminder to
 * the parent body on the shared XCT-2 rail. Thin wrapper over
 * {@link runOverdueReminder}, which holds the testable core.
 */
export async function handleSendOverdueReminders(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const payload = await runOverdueReminder(db, claims, organizationId, schoolId, request);
    return { payload, status: 200 };
  });
}

/** PUT /library/settings — LIB-D1: update the circulation guardrail settings. */
export async function handleUpdateSettings(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const current = await readSettings(db, organizationId, schoolId);

    // PRA-P2-12 — resolve one per-type cap: an explicit nested
    // `maxBooksByMemberType.<type>`, else a flat `maxBooks<Type>` /
    // `max_books_<type>` key, else keep the current per-type value. Clamped to
    // ≥1 so a misconfig can never lock a whole member class out of borrowing.
    const nestedRaw = (body.maxBooksByMemberType ??
      (body as Record<string, unknown>).max_books_by_member_type);
    const nestedSrc = (nestedRaw && typeof nestedRaw === "object")
      ? nestedRaw as Record<string, unknown>
      : {};
    const perTypeCap = (
      type: LibraryMemberType,
      flatCamel: string,
      flatSnake: string,
    ): number => {
      if (type in nestedSrc && nestedSrc[type] != null) {
        return Math.max(1, intFromString(nestedSrc[type], current.maxBooksByMemberType[type]));
      }
      if (flatCamel in body || flatSnake in body) {
        return Math.max(1, intOr(body, current.maxBooksByMemberType[type], flatCamel, flatSnake));
      }
      return current.maxBooksByMemberType[type];
    };

    // Only overwrite fields explicitly present in the body; keep the rest.
    const next: LibrarySettings = {
      maxBooksPerMember: "maxBooksPerMember" in body || "max_books_per_member" in body
        ? Math.max(1, intOr(body, current.maxBooksPerMember, "maxBooksPerMember", "max_books_per_member"))
        : current.maxBooksPerMember,
      maxBooksByMemberType: {
        student: perTypeCap("student", "maxBooksStudent", "max_books_student"),
        teacher: perTypeCap("teacher", "maxBooksTeacher", "max_books_teacher"),
        staff: perTypeCap("staff", "maxBooksStaff", "max_books_staff"),
      },
      maxRenewals: "maxRenewals" in body || "max_renewals" in body
        ? Math.max(0, intOr(body, current.maxRenewals, "maxRenewals", "max_renewals"))
        : current.maxRenewals,
      blockOnFineThreshold: "blockOnFineThreshold" in body || "block_on_fine_threshold" in body
        ? Math.max(0, intOr(body, current.blockOnFineThreshold, "blockOnFineThreshold", "block_on_fine_threshold"))
        : current.blockOnFineThreshold,
      lostBookReplacementFee:
        "lostBookReplacementFee" in body || "lost_book_replacement_fee" in body
          ? Math.max(
            0,
            intOr(body, current.lostBookReplacementFee, "lostBookReplacementFee", "lost_book_replacement_fee"),
          )
          : current.lostBookReplacementFee,
    };
    const saved = await writeStore.mutateSnapshot(
      db,
      organizationId,
      schoolId,
      SETTINGS_ENTITY,
      (existing) => ({ ...existing, ...next }),
    );
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.settings.updated", "library_settings", schoolId, { ...next }),
      request,
    );
    return { payload: normalizeSettings(saved), status: 200 };
  });
}
