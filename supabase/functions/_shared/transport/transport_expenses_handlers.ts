// PRC-A Batch 8 (slice 1) — transport expense handlers.
//
// POST /transport/expenses            record an expense           (manageTransport)
// POST /transport/expenses/:id/void   void a recorded expense     (manageTransport)
// GET  /transport/expenses?from=&to=  list expenses               (viewTransport)
// GET  /transport/cost-summary?from=&to=  real income-vs-expense  (viewTransport)

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
import { correlationIdFromRequest, recordMutationAudit } from "../audit/audit_repository.ts";
import {
  getTransportExpenseByCategory,
  getTransportIncome,
  listTransportExpenses,
  recordTransportExpense,
  TRANSPORT_EXPENSE_CATEGORIES,
  type TransportExpenseCategory,
  TransportExpenseNotVoidableError,
  voidTransportExpense,
} from "./transport_expenses_repository.ts";

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

function requireTransportRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewTransport") ?? requireSchoolOperationalScope(claims);
}
function requireTransportWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageTransport") ?? requireSchoolOperationalScope(claims);
}

function str(body: Record<string, unknown>, ...keys: string[]): string | null {
  for (const k of keys) {
    const v = body[k];
    if (typeof v === "string" && v.trim().length > 0) return v.trim();
  }
  return null;
}

/** POST /transport/expenses — record a transport expense. */
export async function handleRecordExpense(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTransportWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);

  const category = (str(body, "category") ?? "").toLowerCase();
  if (!TRANSPORT_EXPENSE_CATEGORIES.includes(category as TransportExpenseCategory)) {
    return errorEnvelope(
      "VALIDATION_ERROR",
      `category must be one of ${TRANSPORT_EXPENSE_CATEGORIES.join(", ")}`,
      422,
    );
  }
  const amountRaw = body["amount"];
  const amount = typeof amountRaw === "number" ? amountRaw : Number(amountRaw);
  if (!Number.isFinite(amount) || amount <= 0) {
    return errorEnvelope("VALIDATION_ERROR", "amount must be a positive number", 422);
  }
  const incurredOn = str(body, "incurred_on", "incurredOn") ?? "";
  if (!ISO_DATE.test(incurredOn)) {
    return errorEnvelope("VALIDATION_ERROR", "incurred_on is required (YYYY-MM-DD)", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const created = await recordTransportExpense(db, {
        organizationId: orgId,
        schoolId,
        category: category as TransportExpenseCategory,
        vehicleId: str(body, "vehicle_id", "vehicleId"),
        routeId: str(body, "route_id", "routeId"),
        amount: amount.toFixed(2),
        incurredOn,
        vendor: str(body, "vendor"),
        reference: str(body, "reference"),
        notes: str(body, "notes"),
        recordedBy: auth.claims.sub,
      });
      await recordMutationAudit(
        db,
        auth.claims,
        {
          eventType: "transportExpenseRecorded",
          category: "finance",
          entityType: "transport_expense",
          entityId: created.id,
          metadata: { category: created.category, amount: created.amount, incurredOn: created.incurred_on },
          correlationId: correlationIdFromRequest(req),
        },
        {
          eventType: "transport.expense.recorded",
          payload: { id: created.id, category: created.category, amount: created.amount },
          sourceModule: "transport",
          idempotencyKey: `transport.expense.recorded:${created.id}`,
        },
        req,
      );
      return created;
    });
    return jsonResponse(envelope(expenseToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to record transport expense", 500);
  }
}

/** POST /transport/expenses/:id/void — void a recorded expense. */
export async function handleVoidExpense(
  req: Request,
  config: AppConfig,
  id: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTransportWrite(auth.claims);
  if (denied) return denied;

  const body = (await readJson<Record<string, unknown>>(req)) ?? {};
  const reason = str(body, "reason", "void_reason", "voidReason");
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const voided = await voidTransportExpense(db, orgId, schoolId, id, reason, auth.claims.sub);
      await recordMutationAudit(
        db,
        auth.claims,
        {
          eventType: "transportExpenseVoided",
          category: "finance",
          entityType: "transport_expense",
          entityId: voided.id,
          metadata: { amount: voided.amount, reason },
          correlationId: correlationIdFromRequest(req),
        },
        {
          eventType: "transport.expense.voided",
          payload: { id: voided.id, amount: voided.amount },
          sourceModule: "transport",
          idempotencyKey: `transport.expense.voided:${voided.id}`,
        },
        req,
      );
      return voided;
    });
    return jsonResponse(envelope(expenseToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    if (error instanceof TransportExpenseNotVoidableError) {
      return errorEnvelope("NOT_FOUND", "Expense not found or already voided", 404);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to void transport expense", 500);
  }
}

function parseRange(req: Request): { from: string; to: string } | null {
  const url = new URL(req.url);
  const from = url.searchParams.get("from") ?? "";
  const to = url.searchParams.get("to") ?? "";
  if (!ISO_DATE.test(from) || !ISO_DATE.test(to) || from > to) return null;
  // P5 (red-team #2): cap the span so an unbounded range can't load every expense.
  if ((Date.parse(to) - Date.parse(from)) / 86400000 > 400) return null;
  return { from, to };
}

/** GET /transport/expenses?from=&to= — list expenses in range. */
export async function handleListExpenses(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTransportRead(auth.claims);
  if (denied) return denied;

  const range = parseRange(req);
  if (!range) return errorEnvelope("VALIDATION_ERROR", "from and to are required (YYYY-MM-DD, from<=to)", 422);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      listTransportExpenses(db, orgId, schoolId, range.from, range.to));
    return jsonResponse(envelope({ items: rows.map(expenseToApi), from: range.from, to: range.to }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to list transport expenses", 500);
  }
}

/**
 * GET /transport/cost-summary?from=&to= — the REAL transport cost picture that
 * replaces the static mock: recorded expenses (total + by category) vs. the
 * existing transport income seam (fee_head LIKE 'transport:%' for invoices dated
 * in the period), and the net. Every figure is derived from live data — never a
 * seed literal.
 */
export async function handleCostSummary(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireTransportRead(auth.claims);
  if (denied) return denied;

  const range = parseRange(req);
  if (!range) return errorEnvelope("VALIDATION_ERROR", "from and to are required (YYYY-MM-DD, from<=to)", 422);
  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const summary = await withTenantContext(config, auth.claims, async (db) => {
      const expenses = await getTransportExpenseByCategory(db, orgId, schoolId, range.from, range.to);
      const income = await getTransportIncome(db, orgId, schoolId, range.from, range.to);
      const net = (Number(income.collected) - Number(expenses.total)).toFixed(2);
      return {
        from: range.from,
        to: range.to,
        expenseTotal: expenses.total,
        expenseByCategory: expenses.byCategory,
        incomeBilled: income.billed,
        incomeCollected: income.collected,
        netCollectedMinusExpense: net,
        source: "live", // never a seed literal
      };
    });
    return jsonResponse(envelope(summary));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to build transport cost summary", 500);
  }
}

function expenseToApi(row: import("./transport_expenses_repository.ts").TransportExpenseRow) {
  return {
    id: row.id,
    category: row.category,
    vehicleId: row.vehicle_id,
    routeId: row.route_id,
    amount: row.amount,
    incurredOn: row.incurred_on,
    vendor: row.vendor,
    reference: row.reference,
    notes: row.notes,
    status: row.status,
    voidReason: row.void_reason,
    recordedBy: row.recorded_by,
    createdAt: row.created_at,
  };
}
