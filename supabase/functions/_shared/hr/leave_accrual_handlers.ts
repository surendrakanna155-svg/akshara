// PRA-P1-34 (Owner decision #10, FINAL) — leave accrual handlers (hr-owned).
//
//   POST /hr/leave/accrual/run       — run accrual for the school (idempotent per period)
//   GET  /hr/leave/accrual/balances  — read an employee's derivable accrual balances
//
// The run handler reads its POLICIES from the DB (config-driven — no leave-type
// vocabulary is hardcoded), computes each employee's accrual with the pure engine,
// and upserts the ledger idempotently. Re-running for the same period is a no-op
// (the period-key UNIQUE guard), so a double-tapped run never double-accrues.

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
  str,
  WriteValidationError,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import type { LeaveAccrualPolicy } from "./leave_accrual.ts";
import {
  getAccrualPolicy,
  listAccrualPolicies,
  readAccrualBalances,
  type RunAccrualResult,
  runAccrualForEmployee,
} from "./leave_accrual_repository.ts";

const writeStore = createEntityWriteStore("hr_entities", "Hr");
const { runWrite } = createModuleWriteHandlers("manageHr");

function isoToday(now = new Date()): string {
  return now.toISOString().slice(0, 10);
}

/** ISO yyyy-mm-dd validator — the accrual math depends on well-formed dates. */
function isIsoDate(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(Date.parse(value));
}

/**
 * POST /hr/leave/accrual/run
 *
 * Body (all optional):
 *   asOf        — compute accrual through this date (default: today, UTC).
 *   employeeId  — run for a single employee (default: every employee in the school).
 *   leaveType   — run for a single configured leave-type (default: every active policy).
 *
 * Idempotent: each accrual/opening/lapse ledger row is upserted on its period key,
 * so a re-run in the same period inserts nothing new (no double-accrue).
 */
export async function handleRunLeaveAccrual(req: Request, config: AppConfig): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;

    const asOf = str(body, "asOf", "as_of") ?? isoToday();
    if (!isIsoDate(asOf)) {
      throw new WriteValidationError("asOf must be an ISO yyyy-mm-dd date");
    }
    const onlyLeaveType = str(body, "leaveType", "leave_type");
    const onlyEmployeeId = str(body, "employeeId", "employee_id");

    // Policies are DATA — read them from the DB. An unconfigured school (no
    // policies) accrues nothing rather than falling back to a hardcoded rule.
    let policies: LeaveAccrualPolicy[];
    if (onlyLeaveType) {
      const one = await getAccrualPolicy(db, organizationId, schoolId, onlyLeaveType);
      policies = one ? [one] : [];
    } else {
      policies = await listAccrualPolicies(db, organizationId, schoolId);
    }

    // Employees to accrue for — each carries its own joinDate (drives proration).
    const allEmployees = await writeStore.findAll(db, organizationId, schoolId, "employee");
    const employees = onlyEmployeeId
      ? allEmployees.filter((e) => String(e.id ?? "") === onlyEmployeeId)
      : allEmployees;

    const results: RunAccrualResult[] = [];
    let totalInserted = 0;
    for (const employee of employees) {
      const employeeId = String(employee.id ?? "");
      if (employeeId === "") continue;
      // Never accrue for an employee who has left; honest no source date → skip.
      const joinDate = String(employee.joinDate ?? employee.join_date ?? "");
      if (!isIsoDate(joinDate)) continue;

      for (const policy of policies) {
        const result = await runAccrualForEmployee(
          db,
          organizationId,
          schoolId,
          employeeId,
          joinDate,
          asOf,
          policy,
          claims.sub ?? "",
        );
        results.push(result);
        totalInserted += result.inserted;
      }
    }

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit("hr.leave.accrual.run", "leave_accrual_run", asOf, {
        asOf,
        employeeCount: employees.length,
        policyCount: policies.length,
        entriesWritten: totalInserted,
      }),
      request,
    );

    return {
      payload: {
        asOf,
        employeeCount: employees.length,
        policyCount: policies.length,
        entriesWritten: totalInserted,
        results,
      },
      status: 200,
    };
  });
}

function requireHrRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewHr") ??
    requireSchoolOperationalScope(claims);
}

/**
 * GET /hr/leave/accrual/balances?employeeId=<id>
 *
 * Reads the DERIVABLE accrual balances (SUM over the append-only ledger) for one
 * employee. There is no stored balance column — the ledger is the source of truth.
 */
export async function handleLeaveAccrualBalances(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireHrRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const employeeId = (url.searchParams.get("employeeId") ??
    url.searchParams.get("employee_id") ?? "").trim();
  if (employeeId === "") {
    return errorEnvelope("VALIDATION_ERROR", "employeeId query parameter is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const balances = await withTenantContext(config, auth.claims, async (db) =>
      await readAccrualBalances(db, orgId, schoolId, employeeId)
    );
    return jsonResponse(envelope({ employeeId, balances }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("handleLeaveAccrualBalances error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to load leave accrual balances", 500);
  }
}
