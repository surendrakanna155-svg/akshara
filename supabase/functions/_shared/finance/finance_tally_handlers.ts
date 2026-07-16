// PRC-A Batch 7 — Tally export handlers.
//
// GET  /finance/reports/tally-export?from=&to=&format=  — export completed
//        receipts as Tally Import-Data XML (viewFinance).
// GET  /finance/tally-ledger-map                        — read the ledger map (viewFinance).
// PUT  /finance/tally-ledger-map                        — configure it (manageFinance).

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
import { buildTallyReceiptVouchersXml } from "./finance_tally_export.ts";
import {
  getTallyLedgerMap,
  listCollectionsForTallyExport,
  tallyLedgerMapToRuntime,
  upsertTallyLedgerMap,
} from "./finance_tally_repository.ts";

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
    requireSchoolOperationalScope(claims);
}

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/**
 * GET /finance/reports/tally-export — completed fee receipts in [from, to] as a
 * Tally Import-Data ENVELOPE. `?format=xml` returns the raw XML as a downloadable
 * file; the default returns a JSON envelope carrying the xml + voucher count so a
 * client can preview before download.
 */
export async function handleTallyExport(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const url = new URL(req.url);
  const from = url.searchParams.get("from") ?? "";
  const to = url.searchParams.get("to") ?? "";
  const format = (url.searchParams.get("format") ?? "json").toLowerCase();
  if (!ISO_DATE.test(from) || !ISO_DATE.test(to)) {
    return errorEnvelope("VALIDATION_ERROR", "from and to are required (YYYY-MM-DD)", 422);
  }
  if (from > to) {
    return errorEnvelope("VALIDATION_ERROR", "from must be on or before to", 422);
  }
  // P5 (red-team #2): cap the export span so an unbounded range (e.g. 1900→9999)
  // can't load + serialize every collection into one in-memory XML string (DoS).
  if ((Date.parse(to) - Date.parse(from)) / 86400000 > 400) {
    return errorEnvelope("VALIDATION_ERROR", "date range too large (max 400 days per export)", 422);
  }

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const { xml, count } = await withTenantContext(config, auth.claims, async (db) => {
      const mapRow = await getTallyLedgerMap(db, orgId, schoolId);
      const receipts = await listCollectionsForTallyExport(db, orgId, schoolId, from, to);
      const xml = buildTallyReceiptVouchersXml(receipts, tallyLedgerMapToRuntime(mapRow));
      return { xml, count: receipts.length };
    });

    if (format === "xml") {
      return new Response(xml, {
        status: 200,
        headers: {
          "Content-Type": "application/xml; charset=utf-8",
          "Content-Disposition": `attachment; filename="tally_receipts_${from}_${to}.xml"`,
        },
      });
    }
    return jsonResponse(envelope({ format: "tally-xml", from, to, voucherCount: count, xml }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to build Tally export", 500);
  }
}

/** GET /finance/tally-ledger-map — the school's Tally ledger map, or the default
 * shape when unconfigured. */
export async function handleGetTallyLedgerMap(
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
    const runtime = await withTenantContext(config, auth.claims, async (db) => {
      const row = await getTallyLedgerMap(db, orgId, schoolId);
      return { configured: !!row, ...tallyLedgerMapToRuntime(row) };
    });
    return jsonResponse(envelope(runtime));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load Tally ledger map", 500);
  }
}

function ledgerName(body: Record<string, unknown>, snake: string, camel: string, fallback: string): string {
  const raw = body[snake] ?? body[camel];
  const v = typeof raw === "string" ? raw.trim() : "";
  return v.length > 0 ? v : fallback;
}

/** PUT /finance/tally-ledger-map — configure the school's Tally ledger map. */
export async function handleUpsertTallyLedgerMap(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;
  const denied = requirePermission(auth.claims, "manageFinance") ??
    requireSchoolOperationalScope(auth.claims);
  if (denied) return denied;
  if (auth.claims.scope !== "school") {
    return errorEnvelope("VALIDATION_ERROR", "Tally ledger map requires school scope", 422);
  }

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);

  // Overrides: only string→string entries survive (keys lowercased on read).
  const rawOverrides = body["method_ledger_overrides"] ?? body["methodLedgerOverrides"];
  const overrides: Record<string, string> = {};
  if (rawOverrides && typeof rawOverrides === "object" && !Array.isArray(rawOverrides)) {
    for (const [k, v] of Object.entries(rawOverrides as Record<string, unknown>)) {
      if (typeof v === "string" && v.trim().length > 0) overrides[k.toLowerCase()] = v.trim();
    }
  }
  const companyRaw = body["company_name"] ?? body["companyName"];
  const isActiveRaw = body["is_active"] ?? body["isActive"];

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, (db) =>
      upsertTallyLedgerMap(db, {
        organizationId: orgId,
        schoolId,
        cashLedger: ledgerName(body, "cash_ledger", "cashLedger", "Cash"),
        bankLedger: ledgerName(body, "bank_ledger", "bankLedger", "Bank"),
        feeIncomeLedger: ledgerName(body, "fee_income_ledger", "feeIncomeLedger", "Fee Income"),
        methodLedgerOverrides: overrides,
        companyName: typeof companyRaw === "string" && companyRaw.trim().length > 0
          ? companyRaw.trim()
          : null,
        isActive: typeof isActiveRaw === "boolean" ? isActiveRaw : true,
        createdBy: auth.claims.sub,
      }));
    return jsonResponse(envelope({
      configured: true,
      cashLedger: row.cash_ledger,
      bankLedger: row.bank_ledger,
      feeIncomeLedger: row.fee_income_ledger,
      methodLedgerOverrides: row.method_ledger_overrides,
      companyName: row.company_name,
      isActive: row.is_active,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to save Tally ledger map", 500);
  }
}
