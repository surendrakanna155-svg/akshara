import type { AppConfig } from "../config.ts";
import {
  createModuleWriteHandlers,
  intOr,
  requireStr,
  str,
  WriteNotFoundError,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";

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

/**
 * POST /hr/leave — submit a new leave request. Leave requests live inside the
 * `snapshot_leave` snapshot under the `requests` array, so this appends a new
 * pending request and recomputes `pendingCount`.
 */
export async function handleCreateLeaveRequest(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const id = crypto.randomUUID();
    const newRequest: Record<string, unknown> = {
      id,
      employeeId: requireStr(body, "employeeId", "employee_id"),
      employeeName: str(body, "employeeName", "employee_name") ?? "",
      department: str(body, "department") ?? "academics",
      leaveType: str(body, "leaveType", "leave_type") ?? "casual",
      fromDate: str(body, "fromDate", "from_date") ?? isoDate(new Date()),
      toDate: str(body, "toDate", "to_date") ?? isoDate(new Date()),
      days: intOr(body, 1, "days"),
      status: "pending",
      approver: str(body, "approver") ?? "HR Manager",
      reason: str(body, "reason") ?? "",
    };
    await writeStore.mutateSnapshot(
      db,
      organizationId,
      schoolId,
      "snapshot_leave",
      (current) => {
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
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.leave_request.created", "hr_leave_request", id, {
        employeeId: newRequest.employeeId,
      }),
      request,
    );
    return { payload: newRequest, status: 201 };
  });
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
