import type { TenantQueryClient } from "../tenant_db.ts";

// Data access for the finance reports surface. The 6-month collection /
// outstanding trend is derived from real finance_collections + finance_invoices;
// the handler shapes the rows into the client report contract.

export interface MonthlyRow {
  month: string; // YYYY-MM
  collected: string;
  outstanding: string;
}

/**
 * The trailing 6 months of collected vs. outstanding totals for the current
 * tenant scope, one row per month (oldest first). Tenant-scoped via the RLS
 * context on `db`.
 */
export async function getMonthlyFinanceTrends(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
): Promise<MonthlyRow[]> {
  return await db.queryObject<MonthlyRow>(
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
  );
}
