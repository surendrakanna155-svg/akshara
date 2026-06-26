import type { AppConfig } from "../config.ts";
import { envelope, jsonResponse } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
    requireSchoolOperationalScope(claims);
}

interface MonthlyRow {
  month: string; // YYYY-MM
  collected: string;
  outstanding: string;
}

/**
 * GET /finance/reports — report catalog + 6-month collection/outstanding trends
 * derived from real finance_collections + finance_invoices. The client mapper
 * reads `{ selectedReportId, catalog[], collectionTrend[], outstandingTrend[] }`.
 */
export async function handleFinanceReports(
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
    const rows = await withTenantContext(config, auth.claims, (db) =>
      db.queryObject<MonthlyRow>(
        `WITH months AS (
           SELECT to_char(date_trunc('month', (timezone('utc', now()) - (n || ' months')::interval)), 'YYYY-MM') AS month
           FROM generate_series(5, 0, -1) AS n
         ),
         coll AS (
           SELECT to_char(date_trunc('month', collection_date::timestamptz), 'YYYY-MM') AS month,
                  COALESCE(sum(amount_collected), 0) AS total
           FROM finance_collections
           WHERE organization_id = $1 AND school_id = $2
             AND collection_status = 'completed'
           GROUP BY 1
         ),
         outs AS (
           SELECT to_char(date_trunc('month', invoice_date::timestamptz), 'YYYY-MM') AS month,
                  COALESCE(sum(outstanding_amount), 0) AS total
           FROM finance_invoices
           WHERE organization_id = $1 AND school_id = $2
             AND invoice_status <> 'cancelled'
           GROUP BY 1
         )
         SELECT m.month AS month,
                COALESCE(coll.total, 0)::text AS collected,
                COALESCE(outs.total, 0)::text AS outstanding
         FROM months m
         LEFT JOIN coll ON coll.month = m.month
         LEFT JOIN outs ON outs.month = m.month
         ORDER BY m.month ASC`,
        [orgId, schoolId],
      ));

    const collectionTrend = rows.map((r) => ({
      label: monthLabel(r.month),
      value: round1(parseFloat(r.collected) / 100000),
      target: 0,
    }));
    const outstandingTrend = rows.map((r) => ({
      label: monthLabel(r.month),
      value: round1(parseFloat(r.outstanding) / 100000),
      target: 0,
    }));

    const body = {
      selectedReportId: "collection",
      catalog: [
        {
          id: "collection",
          title: "Collection Report",
          description: "Monthly fee collection performance.",
          type: "collection",
          lastGenerated: "",
        },
        {
          id: "outstanding",
          title: "Outstanding Report",
          description: "Outstanding dues by month.",
          type: "outstanding",
          lastGenerated: "",
        },
        {
          id: "discount",
          title: "Discount & Scholarship Report",
          description: "Discounts and scholarships granted.",
          type: "discount",
          lastGenerated: "",
        },
        {
          id: "refund",
          title: "Refund Report",
          description: "Refund requests and disbursements.",
          type: "refund",
          lastGenerated: "",
        },
      ],
      collectionTrend,
      outstandingTrend,
    };

    return jsonResponse(envelope(body));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

function round1(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.round(value * 10) / 10;
}

const MONTH_NAMES = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

function monthLabel(ym: string): string {
  const parts = ym.split("-");
  const month = parseInt(parts[1] ?? "1", 10);
  return MONTH_NAMES[(month - 1 + 12) % 12] ?? ym;
}
