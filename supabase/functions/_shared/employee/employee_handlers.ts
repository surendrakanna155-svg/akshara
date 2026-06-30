import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requireAnyPermission,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { employeeAudit, emitMutationAudit } from "../audit/mutation_audit_catalog.ts";
import {
  assignEmployeeRole,
  buildEmployeeDashboard,
  getEmployee,
  listEmployeeRoles,
  listEmployees,
} from "./employee_repository.ts";

function requireEmployeeRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requireAnyPermission(claims, ["viewEmployees", "viewHr"]) ??
    requireSchoolOperationalScope(claims);
}

function requireEmployeeWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requireAnyPermission(claims, ["manageEmployees", "manageHr"]) ??
    requireSchoolOperationalScope(claims);
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

export async function handleEmployeeDashboard(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEmployeeRead(auth.claims);
  if (denied) return denied;

  try {
    const dashboard = await runTenant(config, auth.claims, (db) => buildEmployeeDashboard(db));
    return jsonResponse(envelope(dashboard));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("EMPLOYEE_ERROR", "Employee dashboard failed", 500);
  }
}

export async function handleListEmployees(req: Request, config: AppConfig): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEmployeeRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  try {
    const items = await runTenant(config, auth.claims, (db) =>
      listEmployees(db, {
        search: url.searchParams.get("search") ?? undefined,
        status: url.searchParams.get("status") ?? undefined,
      })
    );
    return jsonResponse(envelope({
      items: items.map((e) => ({
        id: e.id,
        employeeCode: e.employee_code,
        displayName: e.display_name,
        email: e.email,
        phone: e.phone,
        status: e.status,
        primaryDepartment: e.primary_department,
        userId: e.user_id,
      })),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("EMPLOYEE_ERROR", "List employees failed", 500);
  }
}

export async function handleGetEmployee(
  req: Request,
  config: AppConfig,
  employeeId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEmployeeRead(auth.claims);
  if (denied) return denied;

  try {
    const data = await runTenant(config, auth.claims, async (db) => {
      const employee = await getEmployee(db, employeeId);
      if (!employee) return null;
      const roles = await listEmployeeRoles(db, employeeId);
      return { employee, roles };
    });
    if (!data) return errorEnvelope("NOT_FOUND", "Employee not found", 404);
    return jsonResponse(envelope({
      id: data.employee.id,
      employeeCode: data.employee.employee_code,
      displayName: data.employee.display_name,
      email: data.employee.email,
      phone: data.employee.phone,
      status: data.employee.status,
      primaryDepartment: data.employee.primary_department,
      userId: data.employee.user_id,
      roles: data.roles.map((r) => ({
        id: r.id,
        roleCode: r.role_code,
        effectiveFrom: r.effective_from,
        effectiveTo: r.effective_to,
        isPrimary: r.is_primary,
        notes: r.notes,
      })),
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("EMPLOYEE_ERROR", "Get employee failed", 500);
  }
}

export async function handleAssignEmployeeRole(
  req: Request,
  config: AppConfig,
  employeeId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireEmployeeWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<{ roleCode: string; isPrimary?: boolean }>(req);
  if (!body?.roleCode) {
    return errorEnvelope("VALIDATION_ERROR", "roleCode is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const role = await runTenant(config, auth.claims, async (db) => {
      const created = await assignEmployeeRole(
        db,
        orgId,
        schoolId,
        employeeId,
        body.roleCode,
        auth.claims.sub,
        body.isPrimary ?? false,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        employeeAudit.roleAssigned(employeeId, body.roleCode),
        req,
      );
      return created;
    });
    return jsonResponse(envelope({
      id: role.id,
      roleCode: role.role_code,
      effectiveFrom: role.effective_from,
      isPrimary: role.is_primary,
    }), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) return tenantDbNotConfiguredResponse(error);
    return errorEnvelope("EMPLOYEE_ERROR", "Role assignment failed", 500);
  }
}
