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

const writeStore = createEntityWriteStore("library_entities", "Library");
const { runWrite } = createModuleWriteHandlers("manageLibrary");

const LOAN_DAYS = 14;
/** Per-day overdue fine, in rupees — mirrors the fines snapshot convention. */
const FINE_PER_DAY = 5;

/** Library member roles a caller may enrol. */
const MEMBER_TYPES = new Set(["student", "staff", "teacher"]);

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
 * Build a `fine` entity payload raised when an overdue book is returned.
 * `amount` is stored as a number (rupees); the read layer formats it. Pure for
 * unit-testing.
 */
export function buildReturnFinePayload(
  fineId: string,
  issue: Record<string, unknown>,
  amount: number,
  daysOverdue: number,
  now: Date,
): Record<string, unknown> {
  return {
    id: fineId,
    memberName: (issue.memberName as string | undefined) ?? "",
    bookTitle: (issue.bookTitle as string | undefined) ?? "",
    isbn: (issue.isbn as string | undefined) ?? "",
    amount,
    daysOverdue,
    status: "outstanding",
    sisStudentId: (issue.sisStudentId as string | undefined) ?? null,
    raisedDate: isoDate(now),
    issueId: String(issue.id ?? ""),
  };
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

/** POST /library/catalog — add a book to the catalogue. */
export async function handleAddBook(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const totalCopies = Math.max(1, intOr(body, 1, "totalCopies", "total_copies"));
    const id = crypto.randomUUID();
    const payload = {
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
    const books = await writeStore.findAll(db, organizationId, schoolId, "catalog");
    const book = findCatalogByIsbn(books, isbn);

    const now = new Date();
    const due = new Date(now.getTime() + LOAN_DAYS * 24 * 60 * 60 * 1000);
    const id = crypto.randomUUID();
    const payload = {
      id,
      memberName: member.name as string,
      memberType: (member.memberType as string | undefined) ?? "student",
      bookTitle: (book?.title as string | undefined) ?? isbn,
      isbn,
      issuedDate: isoDate(now),
      dueDate: isoDate(due),
      status: "active",
      sisStudentId: (member.sisStudentId as string | undefined) ?? null,
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "issue", id, payload);

    // Bump the member's live active-loan counter.
    await writeStore.replace(db, organizationId, schoolId, "member", memberId, {
      ...member,
      activeLoans: intFromString(member.activeLoans, 0) + 1,
    });

    // Keep the catalogue consistent: decrement availability when the book is known.
    if (book) {
      const available = Math.max(0, intOr(book, 0, "availableCopies") - 1);
      const nextBook = {
        ...book,
        availableCopies: available,
        status: available <= 0 ? "issued" : "available",
      };
      await writeStore.replace(
        db,
        organizationId,
        schoolId,
        "catalog",
        String(book.id),
        nextBook,
      );
    }

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
    const condition = str(body, "condition") ?? "good";

    const issue = await writeStore.find(db, organizationId, schoolId, "issue", issueId);
    if (!issue) {
      throw new WriteNotFoundError(`Library issue not found: ${issueId}`);
    }

    const now = new Date();
    const dueRaw = issue.dueDate as string | undefined;
    const due = dueRaw ? new Date(dueRaw) : now;
    const daysOverdue = Math.max(
      0,
      Math.floor((now.getTime() - due.getTime()) / (24 * 60 * 60 * 1000)),
    );
    const fineAmount = daysOverdue * FINE_PER_DAY;
    const memberName = (issue.memberName as string | undefined) ?? "";
    const id = crypto.randomUUID();
    const payload = {
      id,
      memberName,
      bookTitle: (issue.bookTitle as string | undefined) ?? "",
      isbn: (issue.isbn as string | undefined) ?? "",
      returnedDate: isoDate(now),
      condition,
      fineAmount: fineAmount > 0 ? `₹${fineAmount}` : "₹0",
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

    // Persist an outstanding fine entity so an overdue charge survives the
    // return (and can later be waived) instead of vanishing with the closed
    // loan (LIBRA-2 / LIBRA-6).
    if (fineAmount > 0) {
      const fineId = crypto.randomUUID();
      await writeStore.insert(
        db,
        organizationId,
        schoolId,
        "fine",
        fineId,
        buildReturnFinePayload(fineId, issue, fineAmount, daysOverdue, now),
      );
    }

    // Close the loan and return the copy to the catalogue.
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

    const isbn = String(issue.isbn ?? "");
    if (isbn) {
      const books = await writeStore.findAll(db, organizationId, schoolId, "catalog");
      const book = findCatalogByIsbn(books, isbn);
      if (book) {
        const total = intOr(book, 0, "totalCopies");
        const available = Math.min(total, intOr(book, 0, "availableCopies") + 1);
        await writeStore.replace(db, organizationId, schoolId, "catalog", String(book.id), {
          ...book,
          availableCopies: available,
          status: "available",
        });
      }
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.book.returned", "library_return", id, { issueId, daysOverdue }),
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
