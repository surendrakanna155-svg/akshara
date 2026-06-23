import type { AppConfig } from "../config.ts";
import {
  boolOr,
  createModuleWriteHandlers,
  intOr,
  requireStr,
  str,
  WriteNotFoundError,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";

const writeStore = createEntityWriteStore("library_entities", "Library");
const { runWrite } = createModuleWriteHandlers("manageLibrary");

const LOAN_DAYS = 14;
/** Per-day overdue fine, in rupees — mirrors the fines snapshot convention. */
const FINE_PER_DAY = 5;

function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function findCatalogByIsbn(
  books: Array<Record<string, unknown>>,
  isbn: string,
): Record<string, unknown> | undefined {
  return books.find((book) => String(book.isbn ?? "") === isbn);
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

    const member = await writeStore.find(db, organizationId, schoolId, "member", memberId);
    const books = await writeStore.findAll(db, organizationId, schoolId, "catalog");
    const book = findCatalogByIsbn(books, isbn);

    const now = new Date();
    const due = new Date(now.getTime() + LOAN_DAYS * 24 * 60 * 60 * 1000);
    const id = crypto.randomUUID();
    const payload = {
      id,
      memberName: (member?.name as string | undefined) ?? memberId,
      memberType: (member?.memberType as string | undefined) ?? "student",
      bookTitle: (book?.title as string | undefined) ?? isbn,
      isbn,
      issuedDate: isoDate(now),
      dueDate: isoDate(due),
      status: "active",
      sisStudentId: (member?.sisStudentId as string | undefined) ?? null,
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "issue", id, payload);

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
    const id = crypto.randomUUID();
    const payload = {
      id,
      memberName: (issue.memberName as string | undefined) ?? "",
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

    // Close the loan and return the copy to the catalogue.
    await writeStore.replace(db, organizationId, schoolId, "issue", issueId, {
      ...issue,
      status: "returned",
    });
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

/** POST /library/digital-resources — add a digital resource to the shelf. */
export async function handleAddDigitalResource(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const resource = {
      id,
      title: requireStr(body, "title"),
      type: str(body, "type") ?? "pdf",
      classAccess: str(body, "classAccess", "class_access") ?? "All classes",
      downloads: 0,
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
