// PRA-P1-41 (Owner decision #11, FINAL) — accession register HTTP handlers.
//
// Writes go through createModuleWriteHandlers("manageLibrary") so a register /
// status change + its audit row commit or roll back together inside ONE tenant
// transaction (the same wrapper the rest of the Library writes use). Reads use
// the module's viewLibrary + school-operational-scope auth, mirroring
// library_handlers.handleComputed.

import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import {
  createModuleWriteHandlers,
  numOr,
  str,
  WriteNotFoundError,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  accessionRowToApi,
  findByAccessionNo,
  listRegister,
  parseAccessionNo,
  registerCopy,
  transitionCopyStatus,
} from "./library_accession_repository.ts";

const writeStore = createEntityWriteStore("library_entities", "Library");
const { runWrite } = createModuleWriteHandlers("manageLibrary");

/** Resolve the catalogue title a copy is being accessioned against, by catalog
 * row id OR isbn. Returns the matched catalog payload; throws when neither is
 * supplied or the title is not in the catalogue (a copy must belong to a real,
 * catalogued title). */
async function resolveCatalogBook(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  body: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const catalogId = str(body, "catalogId", "catalog_id", "bookId", "book_id");
  const isbn = str(body, "isbn");
  if (!catalogId && !isbn) {
    throw new WriteValidationError("catalogId or isbn is required to accession a copy");
  }

  if (catalogId) {
    const byId = await writeStore.find(db, organizationId, schoolId, "catalog", catalogId);
    if (byId) return byId;
    // A catalogId was named but does not exist — do NOT silently fall back to isbn.
    throw new WriteNotFoundError(`Catalogue title not found: ${catalogId}`);
  }

  const books = await writeStore.findAll(db, organizationId, schoolId, "catalog");
  const byIsbn = books.find((b) => String(b.isbn ?? "") === isbn);
  if (!byIsbn) {
    throw new WriteNotFoundError(`Catalogue title not found for ISBN: ${isbn}`);
  }
  return byIsbn;
}

/**
 * POST /library/accessions — PRA-P1-41: register (accession) a new physical copy
 * of a catalogued title. Allocates the next gapless accession number (never
 * reused, concurrency-safe via the counter guard) and writes the register row.
 */
export async function handleRegisterAccession(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const book = await resolveCatalogBook(db, organizationId, schoolId, body);

    const row = await registerCopy(db, organizationId, schoolId, {
      catalogId: String(book.id),
      isbn: String(book.isbn ?? "") || null,
      title: String(book.title ?? "") || null,
      acquiredDate: str(body, "acquiredDate", "acquired_date") ?? null,
      cost: numOr(body, 0, "cost", "price"),
    });

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.accession.registered", "library_accession", row.id, {
        accessionNo: row.accession_no,
        catalogId: row.catalog_id,
        isbn: row.isbn,
      }),
      request,
    );
    return { payload: accessionRowToApi(row), status: 201 };
  });
}

/** Shared status-transition handler for lost / withdrawn. */
async function handleAccessionTransition(
  req: Request,
  config: AppConfig,
  id: string,
  toStatus: "lost" | "withdrawn",
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, claims, req: request } = ctx;
    const row = await transitionCopyStatus(db, organizationId, schoolId, id, toStatus);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("library.accession.status_changed", "library_accession", row.id, {
        accessionNo: row.accession_no,
        status: row.status,
      }),
      request,
    );
    return { payload: accessionRowToApi(row), status: 200 };
  });
}

/** POST /library/accessions/:id/lost — mark an accessioned copy lost. */
export async function handleMarkAccessionLost(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  return await handleAccessionTransition(req, config, id, "lost");
}

/** POST /library/accessions/:id/withdraw — withdraw an accessioned copy. */
export async function handleWithdrawAccession(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  return await handleAccessionTransition(req, config, id, "withdrawn");
}

// ── Reads (viewLibrary + school scope) ───────────────────────────────────────

function requireLibraryRead(claims: AccessTokenClaims): Response | null {
  return requirePermission(claims, "viewLibrary") ??
    requireSchoolOperationalScope(claims);
}

/** Marker a read returns for "no such row" so the runner emits a clean 404. */
const NOT_FOUND = Symbol("accession-not-found");

async function runAccessionRead(
  req: Request,
  config: AppConfig,
  errorMessage: string,
  notFoundMessage: string,
  read: (
    db: TenantQueryClient,
    orgId: string,
    schoolId: string,
    url: URL,
  ) => Promise<Record<string, unknown> | typeof NOT_FOUND>,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireLibraryRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const url = new URL(req.url);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await read(db, orgId, schoolId, url)
    );
    if (result === NOT_FOUND) {
      return errorEnvelope("NOT_FOUND", notFoundMessage, 404);
    }
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("library accession read error:", error);
    return errorEnvelope("INTERNAL_ERROR", errorMessage, 500);
  }
}

/**
 * GET /library/accessions — the accession register (newest first). Optional
 * ?status=active|lost|withdrawn, ?catalogId=, ?isbn= filters.
 */
export async function handleListAccessions(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runAccessionRead(
    req,
    config,
    "Failed to load the accession register",
    "The accession register was not found",
    async (db, orgId, schoolId, url) => {
      const status = url.searchParams.get("status") ?? undefined;
      const catalogId = url.searchParams.get("catalogId") ??
        url.searchParams.get("catalog_id") ?? undefined;
      const isbn = url.searchParams.get("isbn") ?? undefined;
      const rows = await listRegister(db, orgId, schoolId, {
        status: status || undefined,
        catalogId: catalogId || undefined,
        isbn: isbn || undefined,
      });
      const items = rows.map(accessionRowToApi);
      return { items, count: items.length };
    },
  );
}

/**
 * GET /library/accessions/:accessionNo — look up a single copy by its accession
 * number (bare integer or the ACC-000001 code). 404 when no such copy.
 */
export async function handleLookupAccession(
  req: Request,
  config: AppConfig,
  accessionNoRaw: string,
): Promise<Response> {
  const accessionNo = parseAccessionNo(accessionNoRaw);
  if (accessionNo === null) {
    return errorEnvelope("VALIDATION_ERROR", `Invalid accession number: ${accessionNoRaw}`, 422);
  }
  return await runAccessionRead(
    req,
    config,
    "Failed to look up the accession copy",
    `Accession copy not found: ${accessionNo}`,
    async (db, orgId, schoolId) => {
      const row = await findByAccessionNo(db, orgId, schoolId, accessionNo);
      return row ? accessionRowToApi(row) : NOT_FOUND;
    },
  );
}
