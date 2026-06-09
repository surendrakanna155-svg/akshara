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
  InvalidInvoiceTransitionError,
  InvoiceNotFoundError,
  cancelInvoice,
  getInvoice,
  issueInvoice,
  listInvoices,
} from "./finance_invoices_repository.ts";
import { invoiceToApi, listEnvelope } from "./finance_mapper.ts";

function parsePagination(url: URL): { page: number; pageSize: number } {
  const page = Math.max(1, parseInt(url.searchParams.get("page") ?? "1", 10) || 1);
  const pageSize = Math.min(
    100,
    Math.max(1, parseInt(url.searchParams.get("pageSize") ?? "20", 10) || 20),
  );
  return { page, pageSize };
}

async function runTenant<T>(
  config: AppConfig,
  claims: Parameters<typeof withTenantContext>[1],
  operation: Parameters<typeof withTenantContext<T>>[2],
): Promise<T> {
  return await withTenantContext(config, claims, operation);
}

function mapInvoiceError(error: unknown): Response | null {
  if (error instanceof InvoiceNotFoundError) {
    return errorEnvelope("NOT_FOUND", error.message, 404);
  }
  if (error instanceof InvalidInvoiceTransitionError) {
    return errorEnvelope("VALIDATION_ERROR", error.message, 422);
  }
  return null;
}

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
    requireSchoolOperationalScope(claims);
}

function requireFinanceWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageFinance") ??
    requireSchoolOperationalScope(claims);
}

export async function handleListInvoices(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);
  const { page, pageSize } = parsePagination(new URL(req.url));

  try {
    const result = await runTenant(config, auth.claims, async (db) =>
      await listInvoices(db, orgId, schoolId, { page, pageSize })
    );
    return jsonResponse(
      envelope(listEnvelope(result.items.map(invoiceToApi), result)),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleGetInvoice(
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
    const invoice = await runTenant(config, auth.claims, async (db) =>
      await getInvoice(db, orgId, schoolId, invoiceId)
    );
    if (!invoice) {
      return errorEnvelope("NOT_FOUND", `Invoice not found: ${invoiceId}`, 404);
    }
    return jsonResponse(envelope(invoiceToApi(invoice)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

export async function handleIssueInvoice(
  req: Request,
  config: AppConfig,
  invoiceId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const invoice = await runTenant(config, auth.claims, async (db) =>
      await issueInvoice(db, orgId, schoolId, invoiceId)
    );
    return jsonResponse(envelope(invoiceToApi(invoice)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapInvoiceError(error);
    if (mapped) return mapped;
    throw error;
  }
}

export async function handleCancelInvoice(
  req: Request,
  config: AppConfig,
  invoiceId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const invoice = await runTenant(config, auth.claims, async (db) =>
      await cancelInvoice(db, orgId, schoolId, invoiceId)
    );
    return jsonResponse(envelope(invoiceToApi(invoice)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    const mapped = mapInvoiceError(error);
    if (mapped) return mapped;
    throw error;
  }
}
