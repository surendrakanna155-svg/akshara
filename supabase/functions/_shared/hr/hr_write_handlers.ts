import type { AppConfig } from "../config.ts";
import {
  createModuleWriteHandlers,
  intOr,
  requireStr,
  str,
  WriteNotFoundError,
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
 * POST /hr/payroll/run — process a payroll run. Runs live inside the
 * `snapshot_payroll` snapshot under the `runs` array, so this marks the
 * matching run processed (or appends one when absent).
 */
export async function handleProcessPayrollRun(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const runId = requireStr(body, "runId", "run_id");
    const processedOn = str(body, "processedOn", "processed_on") ?? isoDate(new Date());

    let processedRun: Record<string, unknown> = {
      id: runId,
      status: "processed",
      processedOn,
    };
    await writeStore.mutateSnapshot(
      db,
      organizationId,
      schoolId,
      "snapshot_payroll",
      (current) => {
        const runs = Array.isArray(current.runs)
          ? current.runs as Array<Record<string, unknown>>
          : [];
        const index = runs.findIndex((run) => String(run.id ?? "") === runId);
        if (index >= 0) {
          processedRun = { ...runs[index], status: "processed", processedOn };
          const nextRuns = [...runs];
          nextRuns[index] = processedRun;
          return { ...current, runs: nextRuns };
        }
        return { ...current, runs: [...runs, processedRun] };
      },
    );
    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.payroll_run.processed", "hr_payroll_run", runId, { processedOn }),
      request,
    );
    return { payload: processedRun, status: 201 };
  });
}
