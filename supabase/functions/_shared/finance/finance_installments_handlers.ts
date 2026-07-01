// FIN-6 — GET /finance/invoices/{id}/installments (read → viewFinance).
//
// Returns the invoice's informational term-wise due schedule. 404 when the
// invoice does not exist for the school (so a caller can't probe other invoices).

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
import { getInvoice } from "./finance_invoices_repository.ts";
import { listInstallmentsForInvoice } from "./finance_installments_repository.ts";
import { installmentToApi } from "./finance_mapper.ts";

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
    requireSchoolOperationalScope(claims);
}

export async function handleListInvoiceInstallments(
  req: Request,
  config: AppConfig,
  invoiceId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const result = await withTenantContext(config, auth.claims, async (db) => {
      const invoice = await getInvoice(db, orgId, schoolId, invoiceId);
      if (!invoice) return null;
      const rows = await listInstallmentsForInvoice(db, orgId, schoolId, invoiceId);
      return rows;
    });
    if (result === null) {
      return errorEnvelope("NOT_FOUND", `Invoice not found: ${invoiceId}`, 404);
    }
    return jsonResponse(envelope({ items: result.map(installmentToApi) }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}
