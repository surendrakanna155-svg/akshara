// SCE-1 — the concrete clearance contributors.
//
// Only modules with a REAL per-student dues ledger are `tracked: true`. Library
// (loans/fines are keyed by member NAME, not the student UUID) and Hostel (the
// current read APIs are seeded/mock, no per-student dues ledger) are registered
// `tracked: false` so the report is HONEST about coverage — they surface as
// `not_tracked`, never a fabricated CLEARED or block. They flip to tracked when
// a real student-keyed ledger + a UUID linkage exist (no engine change needed).

import type { TenantQueryClient } from "../tenant_db.ts";
import type { ClearanceContributor, ClearanceItem } from "./clearance_engine.ts";

/** Finance — the authoritative money source. Sum of outstanding across the
 * student's OPEN finance_student_accounts (current + prior years) — the SAME
 * balance the defaulters report and the SIS-D1 TC gate already read. Because
 * TRN-9 transport fees and inventory payment requests are raised AS finance
 * demands, this line already absorbs most cross-module money. */
export const financeContributor: ClearanceContributor = {
  module: "finance",
  tracked: true,
  async contribute(db, scope, studentId): Promise<ClearanceItem[]> {
    const rows = await db.queryObject<{
      id: string;
      academic_year: string | null;
      outstanding: string | null;
    }>(
      `SELECT id, academic_year, outstanding_amount::text AS outstanding
         FROM finance_student_accounts
        WHERE organization_id = $1
          AND school_id = $2
          AND student_id = $3::uuid
          AND status = 'open'
          AND outstanding_amount > 0
        ORDER BY academic_year DESC`,
      [scope.organizationId, scope.schoolId, studentId],
    );
    return rows.map((r) => ({
      reference: r.id,
      description: r.academic_year
        ? `Fee dues — ${r.academic_year}`
        : "Fee dues",
      amount: Number(r.outstanding ?? 0),
    }));
  },
};

/** Inventory — un-paid distributed items (textbooks/uniforms a student was
 * given and owes for). Reads inv_student_distributions in the money-owed state
 * `payment_pending`; keyed by the real student_id. Non-payment_pending statuses
 * (distributed/acknowledged/paid) are NOT dues.
 *
 * The rupees live on the linked payment_requests row — a SEPARATE ledger from
 * finance_student_accounts (which this row's amount never posts to), so reading
 * it here does NOT double-count the finance line; it fills a real gap in the
 * total. LEFT JOIN + a still-owed status filter (a captured/cancelled request
 * is settled) so a distribution without a live request still flags as pending
 * (amount 0) rather than vanishing. */
export const inventoryContributor: ClearanceContributor = {
  module: "inventory",
  tracked: true,
  async contribute(db, scope, studentId): Promise<ClearanceItem[]> {
    const rows = await db.queryObject<{
      id: string;
      item_name: string | null;
      quantity: number;
      amount: string | null;
    }>(
      `SELECT d.id,
              c.name AS item_name,
              d.quantity,
              CASE WHEN pr.status IN ('pending', 'initiated', 'failed')
                   THEN pr.amount::text END AS amount
         FROM inv_student_distributions d
         JOIN inv_catalog_items c ON c.id = d.catalog_item_id
         LEFT JOIN payment_requests pr ON pr.id = d.payment_request_id
        WHERE d.organization_id = $1
          AND d.school_id = $2
          AND d.student_id = $3::uuid
          AND d.status = 'payment_pending'
        ORDER BY d.created_at DESC`,
      [scope.organizationId, scope.schoolId, studentId],
    );
    return rows.map((r) => ({
      reference: r.id,
      description: r.item_name
        ? `Unpaid item — ${r.item_name}${r.quantity > 1 ? ` ×${r.quantity}` : ""}`
        : "Unpaid distributed item",
      // Real owed rupees from the linked (still-open) payment request; 0 when no
      // live request is attached — the obligation still flags as pending.
      amount: Number(r.amount ?? 0),
    }));
  },
};

/** Library — registered but NOT yet tracked: loans/fines key by member name,
 * not the student UUID, so a reliable per-student read is not possible today.
 * Surfaced as `not_tracked` (honest coverage gap), never a false block. */
export const libraryContributor: ClearanceContributor = {
  module: "library",
  tracked: false,
  contribute() {
    return Promise.resolve([]);
  },
};

/** Hostel — registered but NOT yet tracked: the current hostel read APIs are
 * seeded/mock with no real per-student dues ledger (hostel fees, where real,
 * are raised as finance demands and already counted by the finance line). */
export const hostelContributor: ClearanceContributor = {
  module: "hostel",
  tracked: false,
  contribute() {
    return Promise.resolve([]);
  },
};

/** The default registry, in report order. Finance first (authoritative money),
 * then inventory (real, non-monetary flag), then the honest coverage caveats. */
export const DEFAULT_CLEARANCE_REGISTRY: readonly ClearanceContributor[] = [
  financeContributor,
  inventoryContributor,
  libraryContributor,
  hostelContributor,
];
