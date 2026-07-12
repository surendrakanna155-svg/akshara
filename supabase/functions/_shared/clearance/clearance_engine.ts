// SCE-1 — Student Clearance / No-Dues Engine (owner idea 2026-07-02).
//
// ONE consolidated cross-module clearance check office staff run before a
// student lifecycle event (Transfer Certificate / transfer / promotion / year
// close / alumni conversion), instead of checking each module by hand.
//
// Contributor-registry pattern: each dues-producing module registers a
// read-only "clearance contributor" that, given a student, returns its
// obligations. The engine fans out over the registry and aggregates. A new
// module plugs in by registering a contributor — the engine never changes.
//
// HONESTY LAW (Akshara master audit): a clearance gate is only as trustworthy
// as its data source. A contributor whose module has NO real per-student dues
// ledger reports coverage `not_tracked` — it is surfaced transparently in the
// report, NEVER fabricated into a false CLEARED or a false block. Office staff
// see exactly which obligations are and are not covered.

import type { TenantQueryClient } from "../tenant_db.ts";

/** How a lifecycle transition treats a contributor's pending obligation. */
export type ClearancePolicy = "blocking" | "advisory";

/** A contributor's coverage for this student. */
export type ClearanceCoverage =
  /** the module has a real per-student ledger and it was read */
  | "tracked"
  /** the module exists but has no reliable per-student dues ledger yet —
   *  surfaced honestly, never treated as CLEARED or as a block */
  | "not_tracked";

export type ClearanceStatus = "cleared" | "pending" | "not_tracked";

/** One line of a contributor's obligation (e.g. an unpaid distribution). */
export interface ClearanceItem {
  reference: string;
  description: string;
  amount: number; // rupees; 0 when the obligation is non-monetary
}

/** A single module's contribution to a student's clearance. */
export interface ClearanceContribution {
  module: string; // 'finance' | 'inventory' | ...
  coverage: ClearanceCoverage;
  policy: ClearancePolicy;
  items: ClearanceItem[];
  amount: number; // sum of item amounts
  /** cleared: tracked + no items; pending: tracked + items; not_tracked. */
  status: ClearanceStatus;
}

/** The read-only seam every module implements. Pure of lifecycle policy — the
 * ENGINE assigns the policy per lifecycle event, so the same contribution can
 * block a TC while only warning at year-close. */
export interface ClearanceContributor {
  readonly module: string;
  /** true when this module keeps a real per-student dues ledger; false makes
   * every contribution `not_tracked` without a DB round-trip. */
  readonly tracked: boolean;
  contribute(
    db: TenantQueryClient,
    scope: { organizationId: string; schoolId: string },
    studentId: string,
  ): Promise<ClearanceItem[]>;
}

export interface ClearanceScope {
  organizationId: string;
  schoolId: string;
}

export interface ClearanceReport {
  studentId: string;
  lifecycle: string;
  contributions: ClearanceContribution[];
  /** total owed across BLOCKING, tracked contributions with pending items. */
  blockingAmount: number;
  /** total owed across ALL tracked contributions (blocking + advisory). */
  totalOutstanding: number;
  /** true iff at least one BLOCKING contributor has a pending obligation. */
  blocked: boolean;
  /** modules with no per-student ledger yet — coverage caveat for the reader. */
  notTracked: string[];
}

/** The per-lifecycle policy map: which modules HARD-BLOCK a given transition vs
 * only warn. Defaults chosen to (a) preserve the existing SIS-D1 finance no-dues
 * gate on TC/transfer exactly, and (b) never hold a child back a grade over a
 * returnable item. A per-school override table can layer on later without
 * touching the engine — the owner decision (block-vs-warn per gate) lives in
 * DATA, this is the safe default. */
export type LifecyclePolicyMap = Record<string, ClearancePolicy>;

export const LIFECYCLE_POLICIES: Record<string, LifecyclePolicyMap> = {
  // Exit events: dues are genuinely withheld against (matches SIS-D1 today).
  transfer_certificate: { finance: "blocking", inventory: "blocking", library: "advisory" },
  transfer: { finance: "blocking", inventory: "blocking", library: "advisory" },
  alumni_conversion: { finance: "blocking", inventory: "blocking", library: "advisory" },
  // In-school progression: warn only — a student is never held back a grade over
  // dues; the school chases the money without blocking the academic record.
  promotion: { finance: "advisory", inventory: "advisory", library: "advisory" },
  year_close: { finance: "advisory", inventory: "advisory", library: "advisory" },
};

/** The default policy for a module not named in a lifecycle's map. */
const DEFAULT_POLICY: ClearancePolicy = "advisory";

function policyFor(lifecycle: string, module: string): ClearancePolicy {
  return LIFECYCLE_POLICIES[lifecycle]?.[module] ?? DEFAULT_POLICY;
}

/** Fans out over the registry, aggregates, and applies the lifecycle's policy.
 * Contributors are independent: one throwing degrades ITS line to `not_tracked`
 * (surfaced, never a silent CLEARED) and never fails the whole report. */
export async function buildClearanceReport(
  db: TenantQueryClient,
  scope: ClearanceScope,
  studentId: string,
  lifecycle: string,
  registry: readonly ClearanceContributor[],
): Promise<ClearanceReport> {
  const contributions: ClearanceContribution[] = [];

  for (const contributor of registry) {
    const policy = policyFor(lifecycle, contributor.module);
    if (!contributor.tracked) {
      contributions.push({
        module: contributor.module,
        coverage: "not_tracked",
        policy,
        items: [],
        amount: 0,
        status: "not_tracked",
      });
      continue;
    }
    let items: ClearanceItem[];
    try {
      items = await contributor.contribute(db, scope, studentId);
    } catch {
      // A read failure must NOT read as "cleared" — surface it as not_tracked.
      contributions.push({
        module: contributor.module,
        coverage: "not_tracked",
        policy,
        items: [],
        amount: 0,
        status: "not_tracked",
      });
      continue;
    }
    const amount = items.reduce((sum, i) => sum + (Number.isFinite(i.amount) ? i.amount : 0), 0);
    contributions.push({
      module: contributor.module,
      coverage: "tracked",
      policy,
      items,
      amount,
      status: items.length > 0 ? "pending" : "cleared",
    });
  }

  const blockingAmount = contributions
    .filter((c) => c.policy === "blocking" && c.status === "pending")
    .reduce((sum, c) => sum + c.amount, 0);
  const totalOutstanding = contributions
    .filter((c) => c.status === "pending")
    .reduce((sum, c) => sum + c.amount, 0);
  const blocked = contributions.some(
    (c) => c.policy === "blocking" && c.status === "pending",
  );
  const notTracked = contributions
    .filter((c) => c.coverage === "not_tracked")
    .map((c) => c.module);

  return {
    studentId,
    lifecycle,
    contributions,
    blockingAmount,
    totalOutstanding,
    blocked,
    notTracked,
  };
}
