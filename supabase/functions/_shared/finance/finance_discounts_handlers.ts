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
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";
import {
  createDiscountRule,
  discountRuleToApi,
  DiscountRuleNotFoundError,
  type DiscountRuleStatus,
  isDiscountRuleStatus,
  listDiscountRules,
  updateDiscountRule,
} from "./finance_discounts_repository.ts";
import {
  listScholarships,
  scholarshipToApi,
} from "./finance_scholarships_repository.ts";

function requireFinanceWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageFinance") ??
    requireSchoolOperationalScope(claims);
}

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
    requireSchoolOperationalScope(claims);
}

/**
 * GET /finance/discounts — discounts dashboard (rules + scholarships + KPIs).
 * The client mapper reads `{ kpis, scholarships, rules, assignments,
 * impactSummary }` from the unwrapped envelope data.
 */
export async function handleDiscountsDashboard(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const data = await withTenantContext(config, auth.claims, async (db) => {
      const [rules, scholarships] = await Promise.all([
        listDiscountRules(db, orgId, schoolId),
        listScholarships(db, orgId, schoolId),
      ]);
      return { rules, scholarships };
    });

    const activeScholarships = data.scholarships.length;
    const pendingApproval = data.rules.filter((r) => r.status === "pending").length;
    const assignedCount = data.scholarships.reduce(
      (sum, s) => sum + (s.active_assignments ?? 0),
      0,
    );

    const body = {
      kpis: [
        {
          id: "active_scholarships",
          value: String(activeScholarships),
          label: "Active Scholarships",
          accentName: "primary",
        },
        {
          id: "assigned",
          value: String(assignedCount),
          label: "Students Assigned",
          accentName: "success",
        },
        {
          id: "pending_approval",
          value: String(pendingApproval),
          label: "Pending Approval",
          accentName: "warning",
        },
      ],
      scholarships: data.scholarships.map(scholarshipToApi),
      rules: data.rules.map(discountRuleToApi),
      assignments: [] as Record<string, unknown>[],
      impactSummary: activeScholarships > 0
        ? `${activeScholarships} scholarship${activeScholarships === 1 ? "" : "s"} active across ${assignedCount} assignment${assignedCount === 1 ? "" : "s"}.`
        : "",
    };

    return jsonResponse(envelope(body));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

function optionalStr(
  body: Record<string, unknown>,
  snakeKey: string,
  camelKey: string,
): string | undefined {
  if (snakeKey in body && body[snakeKey] != null) return String(body[snakeKey]);
  if (camelKey in body && body[camelKey] != null) return String(body[camelKey]);
  return undefined;
}

function parseStatus(value: string | undefined): DiscountRuleStatus | undefined {
  if (value == null) return undefined;
  return isDiscountRuleStatus(value) ? value : undefined;
}

export async function handleCreateDiscountRule(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body is required", 422);
  }

  const name = optionalStr(body, "name", "name");
  const discountPercent = optionalStr(body, "discount_percent", "discountPercent");
  const appliesTo = optionalStr(body, "applies_to", "appliesTo");

  if (!name) {
    return errorEnvelope("VALIDATION_ERROR", "name is required", 422);
  }
  if (!discountPercent) {
    return errorEnvelope("VALIDATION_ERROR", "discountPercent is required", 422);
  }
  if (!appliesTo) {
    return errorEnvelope("VALIDATION_ERROR", "appliesTo is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const row = await createDiscountRule(db, orgId, schoolId, {
        name,
        discountPercent,
        appliesTo,
        status: parseStatus(optionalStr(body, "status", "status")),
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit(
          "finance.discount.created",
          "finance_discount_rule",
          row.id,
          { name: row.name, discountPercent: String(row.discount_percent) },
        ),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(discountRuleToApi(created)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleUpdateDiscountRule(
  req: Request,
  config: AppConfig,
  ruleId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body is required", 422);
  }

  const rawStatus = optionalStr(body, "status", "status");
  if (rawStatus != null && parseStatus(rawStatus) == null) {
    return errorEnvelope("VALIDATION_ERROR", `Invalid status: ${rawStatus}`, 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const updated = await withTenantContext(config, auth.claims, async (db) => {
      const row = await updateDiscountRule(db, orgId, schoolId, ruleId, {
        name: optionalStr(body, "name", "name"),
        discountPercent: optionalStr(body, "discount_percent", "discountPercent"),
        appliesTo: optionalStr(body, "applies_to", "appliesTo"),
        status: parseStatus(rawStatus),
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit(
          "finance.discount.updated",
          "finance_discount_rule",
          row.id,
          { name: row.name, status: row.status },
        ),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(discountRuleToApi(updated)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    if (error instanceof DiscountRuleNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    throw error;
  }
}
