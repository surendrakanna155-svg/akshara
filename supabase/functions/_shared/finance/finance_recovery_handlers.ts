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
import {
  correlationIdFromRequest,
  recordMutationAudit,
} from "../audit/audit_repository.ts";
import {
  type CallQueueRow,
  collectorPerformanceForMonth,
  insertPromiseToPay,
  insertRecoveryContact,
  listCallQueue,
  listPromisesToPay,
  listRecoveryContactsForStudent,
  listRecoveryTargets,
  recoveryAggregates,
  resolvePromiseToPay,
  upsertRecoveryTarget,
} from "./finance_recovery_repository.ts";

// FIN-R1..R6 — fee-recovery CRM HTTP handlers. Reads gate on viewFinance, writes
// on manageFinance (same finance gate as the rest of the module).

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ?? requireSchoolOperationalScope(claims);
}

function str(body: Record<string, unknown>, key: string): string {
  return String(body[key] ?? "").trim();
}

function optUuid(body: Record<string, unknown>, key: string): string | null {
  const v = String(body[key] ?? "").trim();
  return v === "" ? null : v;
}

// ICA-A1 (P0) money-unit fix. `_minor` columns are BIGINT integer paise, so a
// rupee input must be SCALED ×100 here. The prior body did
// `Math.round(x*100)/100` then `Math.trunc(x)` — the ×100 and ÷100 cancelled and
// it stored RUPEE-magnitude values into paise columns, understating the recovery
// dashboard (promise-to-pay, targets, recovered) 100×. This now matches the
// concession reference (finance_fee_concessions_repository.parseAmountMinor):
// rupees → integer paise, paise-exact (₹1500.50 → 150050).
export function amountMinor(body: Record<string, unknown>, key: string): number {
  const raw = String(body[key] ?? "").replace(/[^\d.-]/g, "");
  const n = parseFloat(raw);
  return Number.isFinite(n) ? Math.round(n * 100) : 0;
}

function monthStartIso(): string {
  const now = new Date();
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, "0")}-01`;
}

const CHANNELS = ["call", "whatsapp", "sms", "visit", "email", "other"];
const OUTCOMES = [
  "reached", "no_answer", "promised", "refused", "wrong_number",
  "partial_paid", "other",
];

// ── FIN-R4: log a contact ──────────────────────────────────────────────────
export async function handleLogRecoveryContact(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageFinance");
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);

  const studentId = str(body, "studentId") || str(body, "student_id");
  const channel = str(body, "channel");
  const outcome = str(body, "outcome");
  if (studentId === "") {
    return errorEnvelope("VALIDATION_ERROR", "studentId is required", 422);
  }
  if (!CHANNELS.includes(channel)) {
    return errorEnvelope("VALIDATION_ERROR", `Invalid channel: ${channel}`, 422);
  }
  if (!OUTCOMES.includes(outcome)) {
    return errorEnvelope("VALIDATION_ERROR", `Invalid outcome: ${outcome}`, 422);
  }

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const created = await insertRecoveryContact(db, {
        organizationId: organizationIdFromClaims(auth.claims),
        schoolId: schoolIdFromClaims(auth.claims)!,
        studentId,
        feeAccountId: optUuid(body, "feeAccountId") ?? optUuid(body, "fee_account_id"),
        channel,
        outcome,
        notes: str(body, "notes"),
        contactedBy: auth.claims.sub,
      });
      await recordMutationAudit(
        db,
        auth.claims,
        {
          eventType: "recoveryContactLogged",
          category: "workflow",
          entityType: "finance_recovery_contact",
          entityId: created.id,
          metadata: { studentId, channel, outcome },
          correlationId: correlationIdFromRequest(req),
        },
        {
          eventType: "finance.recovery.contact_logged",
          payload: { studentId, channel, outcome },
          sourceModule: "finance",
          idempotencyKey: `finance.recovery.contact:${created.id}`,
        },
        req,
      );
      return created;
    });
    return jsonResponse(envelope(contactToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleListRecoveryContacts(
  req: Request,
  config: AppConfig,
  studentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      listRecoveryContactsForStudent(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        studentId,
      )
    );
    return jsonResponse(envelope({ items: rows.map(contactToApi) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

// ── FIN-R3: promise-to-pay ─────────────────────────────────────────────────
export async function handleCreatePromiseToPay(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageFinance");
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);

  const studentId = str(body, "studentId") || str(body, "student_id");
  const amount = amountMinor(body, "amount");
  const promiseDate = str(body, "promiseDate") || str(body, "promise_date");
  if (studentId === "") {
    return errorEnvelope("VALIDATION_ERROR", "studentId is required", 422);
  }
  if (amount <= 0) {
    return errorEnvelope("VALIDATION_ERROR", "amount must be greater than zero", 422);
  }
  if (promiseDate === "" || Number.isNaN(new Date(promiseDate).getTime())) {
    return errorEnvelope("VALIDATION_ERROR", "valid promiseDate is required", 422);
  }

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const created = await insertPromiseToPay(db, {
        organizationId: organizationIdFromClaims(auth.claims),
        schoolId: schoolIdFromClaims(auth.claims)!,
        studentId,
        feeAccountId: optUuid(body, "feeAccountId") ?? optUuid(body, "fee_account_id"),
        amountMinor: amount,
        promiseDate: new Date(promiseDate).toISOString().slice(0, 10),
        notes: str(body, "notes"),
        createdBy: auth.claims.sub,
      });
      await recordMutationAudit(
        db,
        auth.claims,
        {
          eventType: "promiseToPayCreated",
          category: "workflow",
          entityType: "finance_promise_to_pay",
          entityId: created.id,
          metadata: { studentId, amountMinor: `${amount}`, promiseDate: created.promise_date },
          correlationId: correlationIdFromRequest(req),
        },
        {
          eventType: "finance.recovery.ptp_created",
          payload: { studentId, amountMinor: amount },
          sourceModule: "finance",
          idempotencyKey: `finance.recovery.ptp:${created.id}`,
        },
        req,
      );
      return created;
    });
    return jsonResponse(envelope(ptpToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleListPromisesToPay(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const statusFilter = url.searchParams.get("status") ?? undefined;

  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      listPromisesToPay(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        statusFilter && statusFilter !== "all" ? statusFilter : undefined,
      )
    );
    return jsonResponse(envelope({ items: rows.map(ptpToApi) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleResolvePromiseToPay(
  req: Request,
  config: AppConfig,
  promiseId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageFinance");
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req) ?? {};
  const status = str(body, "status");
  if (!["kept", "broken", "cancelled"].includes(status)) {
    return errorEnvelope("VALIDATION_ERROR", "status must be kept, broken or cancelled", 422);
  }

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const updated = await resolvePromiseToPay(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        promiseId,
        status as "kept" | "broken" | "cancelled",
        auth.claims.sub,
      );
      if (updated) {
        await recordMutationAudit(
          db,
          auth.claims,
          {
            eventType: "promiseToPayResolved",
            category: "workflow",
            entityType: "finance_promise_to_pay",
            entityId: promiseId,
            metadata: { status },
            correlationId: correlationIdFromRequest(req),
          },
          {
            eventType: "finance.recovery.ptp_resolved",
            payload: { promiseId, status },
            sourceModule: "finance",
            idempotencyKey: `finance.recovery.ptp_resolved:${promiseId}:${status}`,
          },
          req,
        );
      }
      return updated;
    });
    if (!row) {
      return errorEnvelope("NOT_FOUND", "Pending promise not found", 404);
    }
    return jsonResponse(envelope(ptpToApi(row)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

// ── FIN-R1/R5: recovery dashboard + collector performance ──────────────────
export async function handleRecoveryDashboard(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;
  const monthStart = monthStartIso();

  const period = monthStart.slice(0, 7);
  try {
    const [agg, collectors, targets] = await withTenantContext(config, auth.claims, async (db) => {
      const a = await recoveryAggregates(db, orgId, schoolId, monthStart);
      const c = await collectorPerformanceForMonth(db, orgId, schoolId, monthStart);
      // FIN-R6: this month's per-collector targets, to compute attainment.
      const t = await listRecoveryTargets(db, orgId, schoolId, period);
      return [a, c, t] as const;
    });
    // FIN-R6: collector_user_id → target_minor for this period.
    const targetByCollector = new Map<string, number>();
    for (const t of targets) {
      if (t.collector_user_id) {
        targetByCollector.set(t.collector_user_id, parseInt(t.target_minor, 10) || 0);
      }
    }
    return jsonResponse(envelope({
      period,
      ptpPending: parseInt(agg.ptp_pending, 10),
      ptpDueToday: parseInt(agg.ptp_due_today, 10),
      ptpOverdue: parseInt(agg.ptp_overdue, 10),
      ptpKept: parseInt(agg.ptp_kept, 10),
      ptpBroken: parseInt(agg.ptp_broken, 10),
      contactsThisMonth: parseInt(agg.contacts_this_month, 10),
      recoveredThisMonth: minorToRupees(agg.recovered_this_month_minor),
      collectorPerformance: collectors.map((c) => {
        const recoveredMinor = parseInt(c.amount_recovered_minor, 10) || 0;
        const targetMinor = targetByCollector.get(c.collector_id) ?? 0;
        return {
          collectorId: c.collector_id,
          collectorName: c.collector_name,
          contactsMade: parseInt(c.contacts_made, 10),
          promisesObtained: parseInt(c.promises_obtained, 10),
          collectionsCount: parseInt(c.collections_count, 10),
          amountRecovered: minorToRupees(c.amount_recovered_minor),
          // FIN-R6: target + attainment (null target when unset → no % yet).
          target: targetMinor > 0 ? minorToRupees(`${targetMinor}`) : null,
          attainmentPct: targetMinor > 0
            ? Math.round((recoveredMinor / targetMinor) * 100)
            : null,
        };
      }),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

// ── FIN-R2: telecaller call queue ──────────────────────────────────────────
// The order a telecaller works top-down. Ranking is a PURE function so the
// "who to call next" priority is deterministic and unit-tested; the handler
// only pulls the candidate pool (the same open/overdue accounts the defaulters
// list uses — no duplicate source) and sorts it.

export interface CallQueueSignals {
  daysOverdue: number;
  hasBrokenPromise: boolean;
  /** nearest pending promise date (YYYY-MM-DD) or null. */
  pendingPromiseDate: string | null;
  /** last contact timestamp (ISO) or null. */
  lastContactAt: string | null;
  /** today (YYYY-MM-DD) — injected so ranking is time-testable. */
  today: string;
}

function daysSince(fromIso: string, todayIsoDate: string): number {
  const a = Date.parse(fromIso.slice(0, 10));
  const b = Date.parse(todayIsoDate);
  if (Number.isNaN(a) || Number.isNaN(b)) return 0;
  return Math.floor((b - a) / 86400000);
}

/** Lower = call sooner. A future pending promise is DE-prioritised (they've
 *  already committed to a date — leave them alone until it arrives). */
export function callQueuePriority(s: CallQueueSignals): number {
  if (s.hasBrokenPromise) return 0;
  if (s.pendingPromiseDate) return s.pendingPromiseDate <= s.today ? 1 : 5;
  if (s.lastContactAt === null) return s.daysOverdue > 0 ? 2 : 4;
  return daysSince(s.lastContactAt, s.today) >= 7 ? 3 : 4;
}

export function callQueueReason(s: CallQueueSignals): string {
  if (s.hasBrokenPromise) return "Promise broken — follow up";
  if (s.pendingPromiseDate) {
    return s.pendingPromiseDate <= s.today
      ? "Promise due — confirm payment"
      : "Promised — awaiting date";
  }
  if (s.lastContactAt === null) {
    return s.daysOverdue > 0 ? "Not yet contacted" : "Follow up";
  }
  return daysSince(s.lastContactAt, s.today) >= 7
    ? "No contact in 7+ days"
    : "Recently contacted";
}

function formatAmount(value: number): string {
  return Number.isInteger(value) ? String(value) : value.toFixed(2);
}

function clampLimit(raw: string | null): number {
  const n = parseInt(raw ?? "", 10);
  if (!Number.isFinite(n) || n <= 0) return 100;
  return Math.min(n, 200);
}

export function callQueueEntryToApi(
  row: CallQueueRow,
  today: string,
): Record<string, unknown> {
  const daysOverdue = parseInt(row.days_overdue, 10) || 0;
  const signals: CallQueueSignals = {
    daysOverdue,
    hasBrokenPromise: row.has_broken_promise === true,
    pendingPromiseDate: row.pending_promise_date,
    lastContactAt: row.last_contact_at,
    today,
  };
  return {
    studentId: row.student_id,
    studentName: row.student_name,
    admissionNumber: row.admission_number,
    classLabel: row.class_label,
    outstanding: formatAmount(parseFloat(row.outstanding) || 0),
    daysOverdue,
    guardianPhone: row.guardian_phone ?? "",
    feeAccountId: row.fee_account_id,
    lastContact: row.last_contact_at ?? "",
    pendingPromiseDate: row.pending_promise_date ?? "",
    hasBrokenPromise: row.has_broken_promise === true,
    priority: callQueuePriority(signals),
    reason: callQueueReason(signals),
  };
}

export async function handleFinanceCallQueue(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims)!;
  const url = new URL(req.url);
  const limit = clampLimit(url.searchParams.get("limit"));
  const today = new Date().toISOString().slice(0, 10);

  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      listCallQueue(db, orgId, schoolId, limit));
    const items = rows.map((r) => callQueueEntryToApi(r, today));
    // Priority first, then highest balance, then oldest arrears.
    items.sort((a, b) =>
      (a.priority as number) - (b.priority as number) ||
      (parseFloat(String(b.outstanding)) - parseFloat(String(a.outstanding))) ||
      (b.daysOverdue as number) - (a.daysOverdue as number));
    return jsonResponse(envelope({
      generatedAt: new Date().toISOString(),
      items,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

// ── FIN-R6: collection targets ─────────────────────────────────────────────
export async function handleUpsertRecoveryTarget(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageFinance");
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);

  const period = str(body, "periodMonth") || str(body, "period_month");
  const target = amountMinor(body, "target");
  if (!/^\d{4}-\d{2}$/.test(period)) {
    return errorEnvelope("VALIDATION_ERROR", "periodMonth must be YYYY-MM", 422);
  }

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const saved = await upsertRecoveryTarget(db, {
        organizationId: organizationIdFromClaims(auth.claims),
        schoolId: schoolIdFromClaims(auth.claims)!,
        collectorUserId: optUuid(body, "collectorUserId") ?? optUuid(body, "collector_user_id"),
        periodMonth: period,
        targetMinor: target,
        createdBy: auth.claims.sub,
      });
      await recordMutationAudit(
        db,
        auth.claims,
        {
          eventType: "recoveryTargetSet",
          category: "workflow",
          entityType: "finance_recovery_target",
          entityId: saved.id,
          metadata: { period, targetMinor: `${target}` },
          correlationId: correlationIdFromRequest(req),
        },
        {
          eventType: "finance.recovery.target_set",
          payload: { period, targetMinor: target },
          sourceModule: "finance",
          idempotencyKey: `finance.recovery.target:${saved.id}:${target}`,
        },
        req,
      );
      return saved;
    });
    return jsonResponse(envelope(targetToApi(row)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

export async function handleListRecoveryTargets(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const period = url.searchParams.get("period") ?? monthStartIso().slice(0, 7);

  try {
    const rows = await withTenantContext(config, auth.claims, (db) =>
      listRecoveryTargets(
        db,
        organizationIdFromClaims(auth.claims),
        schoolIdFromClaims(auth.claims)!,
        period,
      )
    );
    return jsonResponse(envelope({ period, items: rows.map(targetToApi) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    throw error;
  }
}

// ── mappers ────────────────────────────────────────────────────────────────
// ICA-A1: BIGINT paise (`_minor`) → rupee string at the API boundary (÷100).
export function minorToRupees(minor: string): string {
  const n = parseInt(minor, 10) || 0;
  return (n / 100).toFixed(2);
}

function contactToApi(row: {
  id: string;
  student_id: string;
  channel: string;
  outcome: string;
  notes: string;
  contacted_by: string | null;
  created_at: string;
}): Record<string, unknown> {
  return {
    id: row.id,
    studentId: row.student_id,
    channel: row.channel,
    outcome: row.outcome,
    notes: row.notes,
    contactedBy: row.contacted_by ?? "",
    timestamp: row.created_at,
  };
}

function ptpToApi(row: {
  id: string;
  student_id: string;
  student_name: string;
  amount_minor: string;
  promise_date: string;
  status: string;
  notes: string;
  created_at: string;
  resolved_at: string | null;
}): Record<string, unknown> {
  return {
    id: row.id,
    studentId: row.student_id,
    studentName: row.student_name,
    amount: minorToRupees(row.amount_minor),
    promiseDate: row.promise_date,
    status: row.status,
    notes: row.notes,
    createdAt: row.created_at,
    resolvedAt: row.resolved_at ?? "",
  };
}

function targetToApi(row: {
  id: string;
  collector_user_id: string | null;
  period_month: string;
  target_minor: string;
}): Record<string, unknown> {
  return {
    id: row.id,
    collectorUserId: row.collector_user_id ?? "",
    periodMonth: row.period_month,
    target: minorToRupees(row.target_minor),
  };
}
