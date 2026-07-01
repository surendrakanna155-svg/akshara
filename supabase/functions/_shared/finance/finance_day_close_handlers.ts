import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, financeAudit } from "../audit/mutation_audit_catalog.ts";
import {
  closeDay,
  type FinanceDayCloseRow,
  listDayClose,
  reopenDay,
} from "./finance_day_close_repository.ts";

// FIN-D1 — day-close lock HTTP handlers.
//   • GET  /finance/day-close            → viewFinance (list closed/reopened days)
//   • POST /finance/day-close            → manageFinance (close a date)
//   • POST /finance/day-close/{date}/reopen → manageFinance (supervisor reopen)
//
// Reopen decision (documented): the codebase exposes no distinct "supervisor"
// permission slug for finance beyond manageFinance / approveRefunds (which is
// refund-specific), so reopen gates on manageFinance — the same slug that closes
// a day — and every reopen is audited (finance.day_close.reopened) so the
// supervisory action is fully traceable.

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
    requireSchoolOperationalScope(claims);
}

function requireFinanceWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageFinance") ??
    requireSchoolOperationalScope(claims);
}

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

function dayCloseToApi(row: FinanceDayCloseRow): Record<string, unknown> {
  return {
    id: row.id,
    closeDate: row.close_date,
    status: row.status,
    closedBy: row.closed_by ?? "",
    closedAt: row.closed_at,
    reopenedBy: row.reopened_by ?? "",
    reopenedAt: row.reopened_at ?? "",
  };
}

function todayIso(): string {
  return new Date().toISOString().slice(0, 10);
}

export async function handleListDayClose(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const from = url.searchParams.get("from") ?? undefined;
  const to = url.searchParams.get("to") ?? undefined;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      listDayClose(db, orgId, schoolId, from, to)
    );
    return jsonResponse(envelope({ items: rows.map(dayCloseToApi) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleCloseDay(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req) ?? {};
  const rawDate = String(body.close_date ?? body.closeDate ?? "").trim();
  const closeDate = rawDate === "" ? todayIso() : rawDate;
  if (!ISO_DATE.test(closeDate)) {
    return errorEnvelope("VALIDATION_ERROR", "closeDate must be YYYY-MM-DD", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const closed = await closeDay(db, orgId, schoolId, closeDate, auth.claims.sub);
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.dayClosed(schoolId ?? "", closeDate),
        req,
      );
      return closed;
    });
    return jsonResponse(envelope(dayCloseToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleReopenDay(
  req: Request,
  config: AppConfig,
  date: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  if (!ISO_DATE.test(date)) {
    return errorEnvelope("VALIDATION_ERROR", "date must be YYYY-MM-DD", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const reopened = await reopenDay(db, orgId, schoolId, date, auth.claims.sub);
      if (reopened) {
        await emitMutationAudit(
          db,
          auth.claims,
          financeAudit.dayReopened(schoolId ?? "", date, `${Date.now()}`),
          req,
        );
      }
      return reopened;
    });
    if (!row) {
      return errorEnvelope("NOT_FOUND", `No closed day found for date: ${date}`, 404);
    }
    return jsonResponse(envelope(dayCloseToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}
