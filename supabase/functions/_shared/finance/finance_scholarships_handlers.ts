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
  emitMutationAudit,
  financeAudit,
  moduleEntityAudit,
} from "../audit/mutation_audit_catalog.ts";
import {
  awardScholarshipToInvoice,
  createScholarship,
  isScholarshipType,
  type ScholarshipType,
  ScholarshipNotApplicableError,
  ScholarshipNotFoundError,
  scholarshipToApi,
  updateScholarship,
} from "./finance_scholarships_repository.ts";
import {
  FeeReductionValidationError,
  feeReductionToApi,
} from "./finance_fee_reductions_repository.ts";

function requireFinanceWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageFinance") ??
    requireSchoolOperationalScope(claims);
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

export async function handleCreateScholarship(
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
  const rawType = optionalStr(body, "type", "type") ?? "merit";
  const maxDiscount = optionalStr(body, "max_discount", "maxDiscount") ?? "";
  const eligibility = optionalStr(body, "eligibility", "eligibility") ?? "";

  if (!name) {
    return errorEnvelope("VALIDATION_ERROR", "name is required", 422);
  }
  if (!isScholarshipType(rawType)) {
    return errorEnvelope("VALIDATION_ERROR", `Invalid type: ${rawType}`, 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const created = await withTenantContext(config, auth.claims, async (db) => {
      const row = await createScholarship(db, orgId, schoolId, {
        name,
        type: rawType as ScholarshipType,
        maxDiscount,
        eligibility,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.scholarshipCreated(row.id),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(scholarshipToApi(created)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleUpdateScholarship(
  req: Request,
  config: AppConfig,
  scholarshipId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body is required", 422);
  }

  const rawType = optionalStr(body, "type", "type");
  if (rawType != null && !isScholarshipType(rawType)) {
    return errorEnvelope("VALIDATION_ERROR", `Invalid type: ${rawType}`, 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const updated = await withTenantContext(config, auth.claims, async (db) => {
      const row = await updateScholarship(db, orgId, schoolId, scholarshipId, {
        name: optionalStr(body, "name", "name"),
        type: rawType as ScholarshipType | undefined,
        maxDiscount: optionalStr(body, "max_discount", "maxDiscount"),
        eligibility: optionalStr(body, "eligibility", "eligibility"),
      });
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.scholarshipUpdated(row.id),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(scholarshipToApi(updated)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    if (error instanceof ScholarshipNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    throw error;
  }
}

// PRA-P1-10 (S1): POST /finance/scholarships/:id/award — award an active
// scholarship to a student's INVOICE. This is the MAKER step: it emits a PENDING
// fee-reduction (money-neutral) through the certified maker-checker path, with
// the amount derived from the scholarship's own max_discount (never the client).
// A DIFFERENT user then approves it via /finance/fee-reductions/:id/approve to
// actually reduce the payable (self-approval blocked). Closes the "a scholarship
// never reduces a payable" gap without forking the money mechanism.
export async function handleAwardScholarship(
  req: Request,
  config: AppConfig,
  scholarshipId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body is required", 422);
  }

  const invoiceId = optionalStr(body, "invoice_id", "invoiceId");
  const reason = optionalStr(body, "reason", "reason");
  if (!invoiceId) {
    return errorEnvelope("VALIDATION_ERROR", "invoiceId is required", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const reduction = await withTenantContext(config, auth.claims, async (db) => {
      const row = await awardScholarshipToInvoice(db, orgId, schoolId, {
        scholarshipId,
        invoiceId,
        reason,
        createdBy: auth.claims.sub,
      });
      await emitMutationAudit(
        db,
        auth.claims,
        moduleEntityAudit(
          "finance.feeReduction.proposed",
          "finance_fee_reduction",
          row.id,
          {
            sourceKind: "scholarship",
            sourceId: scholarshipId,
            invoiceId,
            reductionKind: row.reduction_kind,
          },
        ),
        req,
      );
      return row;
    });
    return jsonResponse(envelope(feeReductionToApi(reduction)), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    if (error instanceof ScholarshipNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (
      error instanceof ScholarshipNotApplicableError ||
      error instanceof FeeReductionValidationError
    ) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    throw error;
  }
}
