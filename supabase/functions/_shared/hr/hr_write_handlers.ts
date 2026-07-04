import type { AppConfig } from "../config.ts";
import {
  boolOr,
  createModuleWriteHandlers,
  intOr,
  numOr,
  requireStr,
  str,
  WriteNotFoundError,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import { MAX_BULK_ITEMS } from "../http.ts";

const writeStore = createEntityWriteStore("hr_entities", "Hr");
const { runWrite } = createModuleWriteHandlers("manageHr");

function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** POST /hr/employees — add an employee record (entity_type 'employee'). */
export async function handleCreateEmployee(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const payload: Record<string, unknown> = {
      id,
      name: requireStr(body, "name"),
      employeeCode: requireStr(body, "employeeCode", "employee_code"),
      department: str(body, "department") ?? "academics",
      role: str(body, "role") ?? "staff",
      designation: str(body, "designation") ?? "",
      email: str(body, "email") ?? "",
      phone: str(body, "phone") ?? "",
      joinDate: str(body, "joinDate", "join_date") ?? isoDate(new Date()),
      status: "active",
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "employee", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.employee.created", "hr_employee", id, {
        employeeCode: payload.employeeCode,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** PUT /hr/employees/{id} — replace an employee's editable fields. */
export async function handleUpdateEmployee(
  req: Request,
  config: AppConfig,
  employeeId: string,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const existing = await writeStore.find(db, organizationId, schoolId, "employee", employeeId);
    if (!existing) {
      throw new WriteNotFoundError(`Employee not found: ${employeeId}`);
    }
    const next: Record<string, unknown> = {
      ...existing,
      name: str(body, "name") ?? existing.name,
      designation: str(body, "designation") ?? existing.designation,
      phone: str(body, "phone") ?? existing.phone,
      department: str(body, "department") ?? existing.department,
    };
    const saved = await writeStore.replace(
      db,
      organizationId,
      schoolId,
      "employee",
      employeeId,
      next,
    );
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.employee.updated", "hr_employee", employeeId, {}),
      request,
    );
    return { payload: saved ?? next, status: 200 };
  });
}

/** PATCH /hr/employees/{id}/status — change an employee's status. */
export async function handleSetEmployeeStatus(
  req: Request,
  config: AppConfig,
  employeeId: string,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const status = requireStr(body, "status");
    const existing = await writeStore.find(db, organizationId, schoolId, "employee", employeeId);
    if (!existing) {
      throw new WriteNotFoundError(`Employee not found: ${employeeId}`);
    }
    const next = { ...existing, status };
    const saved = await writeStore.replace(
      db,
      organizationId,
      schoolId,
      "employee",
      employeeId,
      next,
    );
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.employee.status_changed", "hr_employee", employeeId, { status }),
      request,
    );
    return { payload: saved ?? next, status: 200 };
  });
}

/** Default annual leave entitlement (days) used when a policy row is absent. */
const DEFAULT_LEAVE_ENTITLEMENT = 12;

/**
 * HR-D3 — pure over-balance check for a new leave request. Sums THIS employee's
 * already-APPROVED leave days of the same type (plus any still-pending days, so a
 * stack of pending requests cannot silently blow the balance) and compares the
 * running total + the requested days against the org entitlement for that type.
 * Returns whether the request would exceed the balance and the numbers behind it.
 * Kept pure so the warn/override decision is unit-testable DB-free.
 */
export function checkLeaveBalance(
  snapshot: Record<string, unknown>,
  settings: Record<string, unknown>,
  employeeId: string,
  leaveType: string,
  requestedDays: number,
): { exceeds: boolean; entitlement: number; alreadyBooked: number; remaining: number } {
  const requests = Array.isArray(snapshot.requests)
    ? snapshot.requests as Array<Record<string, unknown>>
    : [];
  const policy = Array.isArray(settings.leavePolicy)
    ? settings.leavePolicy as Array<Record<string, unknown>>
    : [];
  const policyRow = policy.find((p) => String(p.leaveType ?? p.leave_type ?? "") === leaveType);
  const entitlement = policyRow != null && Number.isFinite(Number(policyRow.entitlement))
    ? Number(policyRow.entitlement)
    : DEFAULT_LEAVE_ENTITLEMENT;

  const alreadyBooked = requests
    .filter((r) =>
      String(r.employeeId ?? r.employee_id ?? "") === employeeId &&
      String(r.leaveType ?? r.leave_type ?? "") === leaveType &&
      (String(r.status ?? "") === "approved" || String(r.status ?? "") === "pending")
    )
    .reduce((sum, r) => sum + (Number(r.days ?? 0) || 0), 0);

  const remaining = Math.max(0, entitlement - alreadyBooked);
  const exceeds = (alreadyBooked + requestedDays) > entitlement;
  return { exceeds, entitlement, alreadyBooked, remaining };
}

const ISO_DATE_RE = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;

/**
 * POST /hr/employees/{id}/probation (manageHr) — HR-D2 probation follow-up.
 * Body: `{ action: 'confirm' | 'extend', probationEndDate? }`.
 *   • confirm → clears probation (probationEndDate = null) and sets status active.
 *   • extend  → sets a NEW probationEndDate (required, ISO yyyy-mm-dd) and keeps
 *               the employee on probation.
 * Audited either way. Operates on the employee's JSONB payload (entity_type
 * 'employee'), where the rest of the employee CRUD lives.
 */
export async function handleSetEmployeeProbation(
  req: Request,
  config: AppConfig,
  employeeId: string,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const action = requireStr(body, "action");
    if (action !== "confirm" && action !== "extend") {
      throw new WriteValidationError("action must be 'confirm' or 'extend'");
    }
    const existing = await writeStore.find(db, organizationId, schoolId, "employee", employeeId);
    if (!existing) {
      throw new WriteNotFoundError(`Employee not found: ${employeeId}`);
    }

    let next: Record<string, unknown>;
    let newProbationEnd: string | null = null;
    if (action === "confirm") {
      // Confirmed off probation → active, probation cleared.
      next = { ...existing, status: "active", probationEndDate: null };
    } else {
      const probationEndDate = str(body, "probationEndDate", "probation_end_date");
      if (!probationEndDate || !ISO_DATE_RE.test(probationEndDate)) {
        throw new WriteValidationError(
          "probationEndDate is required as yyyy-mm-dd when extending probation",
        );
      }
      newProbationEnd = probationEndDate;
      next = { ...existing, status: "probation", probationEndDate };
    }

    const saved = await writeStore.replace(
      db,
      organizationId,
      schoolId,
      "employee",
      employeeId,
      next,
    );
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.employee.probation_updated", "hr_employee", employeeId, {
        action,
        probationEndDate: newProbationEnd,
      }),
      request,
    );
    return { payload: saved ?? next, status: 200 };
  });
}

/**
 * POST /hr/leave — submit a new leave request. Leave requests live inside the
 * `snapshot_leave` snapshot under the `requests` array, so this appends a new
 * pending request and recomputes `pendingCount`.
 *
 * HR-D3 — a manager (manageHr) may create a request ON BEHALF of an employee:
 * pass `onBehalf: true`; the acting user is recorded on `createdBy`. Half-day is
 * supported either via `halfDay: true` (recorded, and a whole-day `days` is
 * halved to 0.5) or by sending a fractional `days` directly (e.g. 0.5). If the
 * request would exceed the employee's balance for that leave type it is REFUSED
 * with 409 `LEAVE_BALANCE_EXCEEDED` UNLESS the caller passes `override: true`,
 * in which case it is allowed and the override is flagged on the row + AUDITED.
 */
export async function handleCreateLeaveRequest(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const employeeId = requireStr(body, "employeeId", "employee_id");
    const leaveType = str(body, "leaveType", "leave_type") ?? "casual";
    const onBehalf = boolOr(body, false, "onBehalf", "on_behalf");
    const halfDay = boolOr(body, false, "halfDay", "half_day");
    const override = boolOr(body, false, "override");

    // Half-day support: an explicit halfDay flag forces 0.5; otherwise honour a
    // fractional `days` value (e.g. 0.5) sent directly, defaulting to 1 whole day.
    let days = numOr(body, 1, "days");
    if (halfDay) days = 0.5;
    if (days <= 0) {
      throw new WriteValidationError("days must be greater than 0");
    }

    const newRequest: Record<string, unknown> = {
      id,
      employeeId,
      employeeName: str(body, "employeeName", "employee_name") ?? "",
      department: str(body, "department") ?? "academics",
      leaveType,
      fromDate: str(body, "fromDate", "from_date") ?? isoDate(new Date()),
      toDate: str(body, "toDate", "to_date") ?? isoDate(new Date()),
      days,
      halfDay,
      status: "pending",
      approver: str(body, "approver") ?? "HR Manager",
      reason: str(body, "reason") ?? "",
      onBehalf,
      // The acting manager is always recorded when known (identity, not just for
      // on-behalf rows) so who filed a request is never ambiguous.
      createdBy: claims.sub ?? "",
    };

    // The over-balance check + append run inside the SAME locked snapshot mutation
    // so the balance is evaluated against a consistent, up-to-date requests list.
    const outcome: {
      overBalance: boolean;
      info: { exceeds: boolean; entitlement: number; alreadyBooked: number; remaining: number };
      guardError: WriteValidationError | null;
    } = {
      overBalance: false,
      info: { exceeds: false, entitlement: DEFAULT_LEAVE_ENTITLEMENT, alreadyBooked: 0, remaining: DEFAULT_LEAVE_ENTITLEMENT },
      guardError: null,
    };
    const settings = await getSnapshotOrEmptyForWrite(db, organizationId, schoolId, "snapshot_settings");
    await writeStore.mutateSnapshot(
      db,
      organizationId,
      schoolId,
      "snapshot_leave",
      (current) => {
        const info = checkLeaveBalance(current, settings, employeeId, leaveType, days);
        outcome.info = info;
        if (info.exceeds && !override) {
          outcome.guardError = new WriteValidationError(
            `Leave request exceeds ${employeeId}'s ${leaveType} balance ` +
              `(${info.alreadyBooked}/${info.entitlement} booked, requesting ${days}). ` +
              `Re-send with override to allow.`,
            409,
            "LEAVE_BALANCE_EXCEEDED",
          );
          return current; // do not append on a refused request
        }
        outcome.overBalance = info.exceeds; // exceeds && override → allowed override
        if (outcome.overBalance) {
          newRequest.overrideBalance = true;
          newRequest.overrideBy = claims.sub ?? "";
        }
        const requests = Array.isArray(current.requests)
          ? current.requests as Array<Record<string, unknown>>
          : [];
        const nextRequests = [...requests, newRequest];
        const pendingCount = nextRequests.filter(
          (r) => String(r.status ?? "") === "pending",
        ).length;
        return { ...current, requests: nextRequests, pendingCount };
      },
    );

    if (outcome.guardError !== null) {
      throw outcome.guardError;
    }
    const overBalance = outcome.overBalance;
    const balanceInfo = outcome.info;

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.leave_request.created", "hr_leave_request", id, {
        employeeId,
        onBehalf,
        halfDay,
      }),
      request,
    );

    // A balance override is a distinct, deliberate act — audit it separately so a
    // reviewer can find every over-balance grant.
    if (overBalance) {
      await emitMutationAudit(
        db,
        claims,
        moduleEntityAudit("hr.leave_request.balance_overridden", "hr_leave_request", id, {
          employeeId,
          leaveType,
          requestedDays: days,
          entitlement: balanceInfo.entitlement,
          alreadyBooked: balanceInfo.alreadyBooked,
        }),
        request,
      );
    }

    return { payload: newRequest, status: 201 };
  });
}

/**
 * Loads a snapshot payload for a write path, returning {} when the snapshot does
 * not yet exist for this school (so a fresh school with no configured leave
 * policy degrades to the default entitlement instead of failing the write).
 */
async function getSnapshotOrEmptyForWrite(
  db: Parameters<typeof writeStore.find>[0],
  organizationId: string,
  schoolId: string,
  snapshotEntityType: string,
): Promise<Record<string, unknown>> {
  const found = await writeStore.find(
    db,
    organizationId,
    schoolId,
    snapshotEntityType,
    "default",
  );
  return found ?? {};
}

/**
 * Flips a single leave request's status inside the `snapshot_leave` snapshot
 * (requests live under the `requests` array) and recomputes `pendingCount`.
 * Shared by approve/reject. Returns the updated request, or throws when absent.
 */
/**
 * Pure leave-decision transform (integrity gap c — decision immutability).
 * A leave request may only be decided while it is still 'pending'. Once
 * approved/rejected its status is FROZEN: re-approving, re-rejecting, or flipping
 * an approved leave to rejected (or vice-versa) is refused. Returns the next
 * snapshot + the updated request; throws:
 *   • WriteNotFoundError (404) when the request id is absent, or
 *   • WriteValidationError(409, LEAVE_ALREADY_DECIDED) when it is not pending.
 * Kept pure (snapshot in → snapshot out) so the guard is unit-testable DB-free.
 */
export function applyLeaveDecision(
  current: Record<string, unknown>,
  leaveRequestId: string,
  status: "approved" | "rejected",
  comment: string,
): { next: Record<string, unknown>; updated: Record<string, unknown> } {
  const requests = Array.isArray(current.requests)
    ? current.requests as Array<Record<string, unknown>>
    : [];
  const index = requests.findIndex((r) => String(r.id ?? "") === leaveRequestId);
  if (index < 0) {
    throw new WriteNotFoundError(`Leave request not found: ${leaveRequestId}`);
  }
  const currentStatus = String(requests[index]!.status ?? "");
  if (currentStatus !== "pending") {
    throw new WriteValidationError(
      `Leave request already ${currentStatus}; a decided request cannot be changed`,
      409,
      "LEAVE_ALREADY_DECIDED",
    );
  }
  const updated = { ...requests[index], status, decisionComment: comment };
  const nextRequests = [...requests];
  nextRequests[index] = updated;
  const pendingCount = nextRequests.filter(
    (r) => String(r.status ?? "") === "pending",
  ).length;
  return { next: { ...current, requests: nextRequests, pendingCount }, updated };
}

/**
 * HR-3 — pure batch leave-decision transform. Applies {@link applyLeaveDecision}
 * to each id in turn against a SINGLE evolving snapshot, so the per-row 409
 * `LEAVE_ALREADY_DECIDED` / 404 guard fires exactly as it does for a single
 * decision. Partial success by design: an id that is already decided (or absent)
 * is recorded under `skipped` with its reason and is NEVER flipped — the loop
 * continues to the next id. Returns the final snapshot + the list of decided ids
 * (for the caller to audit one row per real decision) + the skipped list.
 *
 * Kept pure (snapshot in → snapshot out) so the partial-success behaviour is
 * unit-testable DB-free.
 */
export function applyBatchLeaveDecision(
  current: Record<string, unknown>,
  leaveRequestIds: string[],
  status: "approved" | "rejected",
  comment: string,
): {
  next: Record<string, unknown>;
  decided: Array<Record<string, unknown>>;
  skipped: Array<{ id: string; reason: string }>;
} {
  let snapshot = current;
  const decided: Array<Record<string, unknown>> = [];
  const skipped: Array<{ id: string; reason: string }> = [];
  const seen = new Set<string>();

  for (const id of leaveRequestIds) {
    // A duplicate id in the request body is skipped — the first occurrence
    // already decided it, so the second would hit the freshly-decided guard.
    if (seen.has(id)) {
      skipped.push({ id, reason: "Duplicate id in request" });
      continue;
    }
    seen.add(id);
    try {
      const result = applyLeaveDecision(snapshot, id, status, comment);
      snapshot = result.next;
      decided.push(result.updated);
    } catch (error) {
      if (
        error instanceof WriteValidationError ||
        error instanceof WriteNotFoundError
      ) {
        // Non-pending / absent rows are reported, never flipped. Keep going.
        skipped.push({ id, reason: error.message });
        continue;
      }
      throw error;
    }
  }

  return { next: snapshot, decided, skipped };
}

/**
 * POST /hr/leave/batch-decide (manageHr) — decide many leave requests at once.
 * Body: `{ ids: string[], decision: 'approve' | 'reject', reason? }`. Loops the
 * existing per-row guard (409 already-decided / 404 absent → skipped), audits one
 * row per REAL decision, and returns `{ decided, skipped }` for partial success.
 */
export async function handleBatchDecideLeave(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const rawIds = body.ids;
    if (!Array.isArray(rawIds) || rawIds.length === 0) {
      throw new WriteValidationError("ids must be a non-empty array");
    }
    // ENG-8 (SEC-11): cap the bulk array before any per-row DB work.
    if (rawIds.length > MAX_BULK_ITEMS) {
      throw new WriteValidationError(`Maximum ${MAX_BULK_ITEMS} ids per request`);
    }
    const ids = rawIds
      .map((value) => String(value ?? "").trim())
      .filter((value) => value.length > 0);
    if (ids.length === 0) {
      throw new WriteValidationError("ids must contain at least one non-empty id");
    }
    const decision = requireStr(body, "decision");
    if (decision !== "approve" && decision !== "reject") {
      throw new WriteValidationError("decision must be 'approve' or 'reject'");
    }
    const status: "approved" | "rejected" = decision === "approve" ? "approved" : "rejected";
    const comment = str(body, "reason", "comment") ?? "";

    let decided: Array<Record<string, unknown>> = [];
    let skipped: Array<{ id: string; reason: string }> = [];
    await writeStore.mutateSnapshot(
      db,
      organizationId,
      schoolId,
      "snapshot_leave",
      (currentSnap) => {
        const result = applyBatchLeaveDecision(currentSnap, ids, status, comment);
        decided = result.decided;
        skipped = result.skipped;
        return result.next;
      },
    );

    // One audit row per REAL decision (skipped rows were never changed).
    for (const row of decided) {
      const id = String(row.id ?? "");
      await emitMutationAudit(
        db,
        claims,
        moduleEntityAudit(`hr.leave_request.${status}`, "hr_leave_request", id, {
          status,
          batch: true,
        }),
        request,
      );
    }

    return {
      payload: {
        decided: decided.map((row) => ({ id: String(row.id ?? ""), status })),
        skipped,
      },
      status: 200,
    };
  });
}

async function decideLeaveRequest(
  req: Request,
  config: AppConfig,
  leaveRequestId: string,
  status: "approved" | "rejected",
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const comment = str(body, "comment") ?? "";

    // The guard raises inside the mutator; capture it and re-throw AFTER the
    // snapshot resolves so a rejected decision never mutates the snapshot.
    let updated: Record<string, unknown> | null = null;
    let guardError: WriteValidationError | WriteNotFoundError | null = null;
    await writeStore.mutateSnapshot(
      db,
      organizationId,
      schoolId,
      "snapshot_leave",
      (current) => {
        try {
          const result = applyLeaveDecision(current, leaveRequestId, status, comment);
          updated = result.updated;
          return result.next;
        } catch (error) {
          if (
            error instanceof WriteValidationError ||
            error instanceof WriteNotFoundError
          ) {
            guardError = error;
            return current; // do not mutate on a rejected decision
          }
          throw error;
        }
      },
    );

    if (guardError !== null) {
      throw guardError;
    }
    if (updated === null) {
      // Defensive — applyLeaveDecision always sets `updated` or throws.
      throw new WriteNotFoundError(`Leave request not found: ${leaveRequestId}`);
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit(`hr.leave_request.${status}`, "hr_leave_request", leaveRequestId, {
        status,
      }),
      request,
    );
    return { payload: updated, status: 200 };
  });
}

/** POST /hr/leave/{id}/approve — approve a pending leave request. */
export async function handleApproveLeaveRequest(
  req: Request,
  config: AppConfig,
  leaveRequestId: string,
): Promise<Response> {
  return await decideLeaveRequest(req, config, leaveRequestId, "approved");
}

/** POST /hr/leave/{id}/reject — reject a pending leave request. */
export async function handleRejectLeaveRequest(
  req: Request,
  config: AppConfig,
  leaveRequestId: string,
): Promise<Response> {
  return await decideLeaveRequest(req, config, leaveRequestId, "rejected");
}

/**
 * POST /hr/performance — create a performance review (entity_type 'review').
 */
export async function handleCreatePerformanceReview(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const payload: Record<string, unknown> = {
      id,
      employeeId: requireStr(body, "employeeId", "employee_id"),
      employeeName: str(body, "employeeName", "employee_name") ?? "",
      department: str(body, "department") ?? "academics",
      cycle: str(body, "cycle") ?? "",
      reviewer: str(body, "reviewer") ?? "",
      rating: intOr(body, 0, "rating"),
      status: str(body, "status") ?? "draft",
      summary: str(body, "summary") ?? "",
      reviewDate: str(body, "reviewDate", "review_date") ?? isoDate(new Date()),
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "review", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.performance_review.created", "hr_performance_review", id, {
        employeeId: payload.employeeId,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** PUT /hr/performance/{id} — update an existing performance review. */
export async function handleUpdatePerformanceReview(
  req: Request,
  config: AppConfig,
  reviewId: string,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const existing = await writeStore.find(db, organizationId, schoolId, "review", reviewId);
    if (!existing) {
      throw new WriteNotFoundError(`Performance review not found: ${reviewId}`);
    }
    const next: Record<string, unknown> = {
      ...existing,
      cycle: str(body, "cycle") ?? existing.cycle,
      reviewer: str(body, "reviewer") ?? existing.reviewer,
      rating: "rating" in body ? intOr(body, intOr(existing, 0, "rating"), "rating") : existing.rating,
      status: str(body, "status") ?? existing.status,
      summary: str(body, "summary") ?? existing.summary,
    };
    const saved = await writeStore.replace(db, organizationId, schoolId, "review", reviewId, next);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.performance_review.updated", "hr_performance_review", reviewId, {}),
      request,
    );
    return { payload: saved ?? next, status: 200 };
  });
}

/**
 * POST /hr/recruitment — open a recruitment requisition (entity_type 'opening').
 */
export async function handleCreateRecruitmentOpening(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const payload: Record<string, unknown> = {
      id,
      title: requireStr(body, "title"),
      department: str(body, "department") ?? "academics",
      role: str(body, "role") ?? "staff",
      openings: Math.max(1, intOr(body, 1, "openings")),
      applicants: 0,
      status: str(body, "status") ?? "open",
      postedDate: str(body, "postedDate", "posted_date") ?? isoDate(new Date()),
    };
    const saved = await writeStore.insert(db, organizationId, schoolId, "opening", id, payload);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.recruitment_opening.created", "hr_recruitment_opening", id, {
        title: payload.title,
      }),
      request,
    );
    return { payload: saved, status: 201 };
  });
}

/** PUT /hr/recruitment/{id} — update a recruitment requisition. */
export async function handleUpdateRecruitmentOpening(
  req: Request,
  config: AppConfig,
  openingId: string,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const existing = await writeStore.find(db, organizationId, schoolId, "opening", openingId);
    if (!existing) {
      throw new WriteNotFoundError(`Recruitment opening not found: ${openingId}`);
    }
    const next: Record<string, unknown> = {
      ...existing,
      title: str(body, "title") ?? existing.title,
      openings: "openings" in body
        ? Math.max(1, intOr(body, intOr(existing, 1, "openings"), "openings"))
        : existing.openings,
      applicants: "applicants" in body
        ? intOr(body, intOr(existing, 0, "applicants"), "applicants")
        : existing.applicants,
      status: str(body, "status") ?? existing.status,
    };
    const saved = await writeStore.replace(db, organizationId, schoolId, "opening", openingId, next);
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.recruitment_opening.updated", "hr_recruitment_opening", openingId, {}),
      request,
    );
    return { payload: saved ?? next, status: 200 };
  });
}

/** Coerces a JSONB numeric field to a finite number (0 when absent/non-numeric). */
function money(entry: Record<string, unknown>, ...keys: string[]): number {
  for (const key of keys) {
    if (key in entry && entry[key] != null) {
      const n = Number(entry[key]);
      if (Number.isFinite(n)) return n;
    }
  }
  return 0;
}

/**
 * Money-safety guards for a payroll run's entries (integrity gap b). For every
 * entry that will be marked processed this validates:
 *   1. netPay === basicPay + allowances - deductions (within a 1-unit rounding
 *      tolerance — amounts are whole rupees, so this absorbs float noise only).
 *   2. netPay >= 0 — a processed run never disburses a negative net.
 *   3. each employee appears at most once (per-run per-employee uniqueness) — an
 *      employee listed twice in one run would be double-paid.
 * Throws a 422 `PAYROLL_ENTRY_INVALID` naming the first offending employee.
 */
export function validatePayrollEntries(entries: Array<Record<string, unknown>>): void {
  const ROUNDING_TOLERANCE = 1;
  const seenEmployees = new Set<string>();
  for (const entry of entries) {
    const employeeId = String(entry.employeeId ?? entry.employee_id ?? "");
    const employeeLabel = employeeId ||
      String(entry.employeeName ?? entry.employee_name ?? entry.id ?? "unknown");

    if (employeeId) {
      if (seenEmployees.has(employeeId)) {
        throw new WriteValidationError(
          `Payroll entry invalid: employee ${employeeLabel} appears more than once in this run`,
          422,
          "PAYROLL_ENTRY_INVALID",
        );
      }
      seenEmployees.add(employeeId);
    }

    const basicPay = money(entry, "basicPay", "basic_pay");
    const allowances = money(entry, "allowances");
    const deductions = money(entry, "deductions");
    const netPay = money(entry, "netPay", "net_pay");
    const expectedNet = basicPay + allowances - deductions;

    if (Math.abs(netPay - expectedNet) > ROUNDING_TOLERANCE) {
      throw new WriteValidationError(
        `Payroll entry invalid for employee ${employeeLabel}: ` +
          `netPay ${netPay} != basicPay ${basicPay} + allowances ${allowances} - deductions ${deductions} (= ${expectedNet})`,
        422,
        "PAYROLL_ENTRY_INVALID",
      );
    }
    if (netPay < 0) {
      throw new WriteValidationError(
        `Payroll entry invalid for employee ${employeeLabel}: netPay ${netPay} is negative`,
        422,
        "PAYROLL_ENTRY_INVALID",
      );
    }
  }
}

/**
 * Pure payroll-run process transform (integrity gaps a + b — money-safety).
 * Given the current `snapshot_payroll` document, marks the run `runId` processed:
 *   (a) A run already 'processed' is NOT re-processed — re-running would silently
 *       overwrite the processed record and risk a DOUBLE-PAY. Refused with 409
 *       `PAYROLL_RUN_ALREADY_PROCESSED`.
 *   (b) Every per-employee entry is validated (via validatePayrollEntries) BEFORE
 *       the run is marked processed. Refused with 422 `PAYROLL_ENTRY_INVALID`.
 * A run absent from `runs` is appended (first process). Returns the next snapshot
 * + the processed run record. Kept pure so the guards are unit-testable DB-free.
 */
export function applyPayrollRun(
  current: Record<string, unknown>,
  runId: string,
  processedOn: string,
): { next: Record<string, unknown>; processedRun: Record<string, unknown> } {
  const runs = Array.isArray(current.runs)
    ? current.runs as Array<Record<string, unknown>>
    : [];
  const entries = Array.isArray(current.entries)
    ? current.entries as Array<Record<string, unknown>>
    : [];
  const index = runs.findIndex((run) => String(run.id ?? "") === runId);

  // (a) Re-process guard — never overwrite an already-processed run.
  if (index >= 0 && String(runs[index]!.status ?? "") === "processed") {
    throw new WriteValidationError(
      `Payroll run ${runId} is already processed; re-processing is not allowed`,
      409,
      "PAYROLL_RUN_ALREADY_PROCESSED",
    );
  }

  // (b) Validate every per-employee salary line before disbursing.
  validatePayrollEntries(entries);

  if (index >= 0) {
    const processedRun = { ...runs[index], status: "processed", processedOn };
    const nextRuns = [...runs];
    nextRuns[index] = processedRun;
    return { next: { ...current, runs: nextRuns }, processedRun };
  }
  const processedRun: Record<string, unknown> = {
    id: runId,
    status: "processed",
    processedOn,
  };
  return { next: { ...current, runs: [...runs, processedRun] }, processedRun };
}

/**
 * POST /hr/payroll/run — process a payroll run. Runs live inside the
 * `snapshot_payroll` snapshot under the `runs` array, with per-employee salary
 * lines under the `entries` array. Money-safety guards live in applyPayrollRun
 * (gap a: 409 re-process; gap b: 422 invalid/duplicate entry). Code-level guards
 * on the JSONB payload — no schema change.
 */
export async function handleProcessPayrollRun(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const runId = requireStr(body, "runId", "run_id");
    const processedOn = str(body, "processedOn", "processed_on") ?? isoDate(new Date());

    let processedRun: Record<string, unknown> | null = null;
    // The guard raises inside the mutator; capture it and re-throw AFTER the
    // snapshot resolves so a rejected run never mutates the snapshot.
    let guardError: WriteValidationError | null = null;
    await writeStore.mutateSnapshot(
      db,
      organizationId,
      schoolId,
      "snapshot_payroll",
      (current) => {
        try {
          const result = applyPayrollRun(current, runId, processedOn);
          processedRun = result.processedRun;
          return result.next;
        } catch (error) {
          if (error instanceof WriteValidationError) {
            guardError = error;
            return current; // do not mutate on a rejected run
          }
          throw error;
        }
      },
    );

    if (guardError !== null) {
      throw guardError;
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.payroll_run.processed", "hr_payroll_run", runId, { processedOn }),
      request,
    );
    return { payload: processedRun!, status: 201 };
  });
}
