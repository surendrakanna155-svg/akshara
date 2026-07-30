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
// HONESTY LAW (NIKSHA master audit): a clearance gate is only as trustworthy
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
  // Exit events: FINANCE dues are genuinely withheld against — this is exactly
  // today's SIS-D1 finance-only TC no-dues gate, preserved. Inventory dues are
  // ADVISORY by default (surfaced + summed, non-blocking) so wiring the gate to
  // this engine (slice 2) does not silently start blocking TCs on unpaid items;
  // inventory→blocking is the owner's per-gate opt-in (a DATA change, no code).
  transfer_certificate: { finance: "blocking", inventory: "advisory", library: "advisory" },
  transfer: { finance: "blocking", inventory: "advisory", library: "advisory" },
  alumni_conversion: { finance: "blocking", inventory: "advisory", library: "advisory" },
  // In-school progression: warn only — a student is never held back a grade over
  // dues; the school chases the money without blocking the academic record.
  promotion: { finance: "advisory", inventory: "advisory", library: "advisory" },
  year_close: { finance: "advisory", inventory: "advisory", library: "advisory" },
};

/** The default policy for a KNOWN lifecycle's module that isn't named in its map
 * (progression is lenient, so an unlisted module warns rather than blocks). */
const DEFAULT_MODULE_POLICY: ClearancePolicy = "advisory";

/** Resolves a module's policy for a lifecycle. Two safety properties:
 *  1. Prototype-safe: `Object.hasOwn`, never `in`/`[]` — so `constructor`,
 *     `valueOf`, `toString` etc. can never masquerade as a known lifecycle/
 *     module and pull an inherited value.
 *  2. Fail-STRICT on an unknown lifecycle: an unrecognized lifecycle is treated
 *     as BLOCKING (the exit-event stance), so a caller passing a bad/typo/
 *     attacker-supplied lifecycle can never downgrade a gate to advisory. The
 *     handler ALSO coerces unknown→transfer_certificate; this is the engine's
 *     own independent backstop. */
export function policyFor(lifecycle: string, module: string): ClearancePolicy {
  if (!Object.hasOwn(LIFECYCLE_POLICIES, lifecycle)) return "blocking";
  const map = LIFECYCLE_POLICIES[lifecycle]!;
  return Object.hasOwn(map, module) ? map[module]! : DEFAULT_MODULE_POLICY;
}

export interface BuildClearanceOptions {
  /** GATE MODE. When true, a BLOCKING-policy contributor that THROWS re-throws
   * (fails CLOSED) instead of degrading to not_tracked — so a failed read of a
   * blocking dues source can never let a duesful student through a gate. Leave
   * false for read-only reports (fail-SAFE: an inconclusive read must never
   * fabricate a block). Advisory contributors ALWAYS degrade regardless of this
   * flag — an advisory module's outage must not block a lifecycle event. */
  failClosedOnBlocking?: boolean;
  /** GATE MODE. When true, ADVISORY-policy contributors are skipped entirely
   * (not even queried) — they cannot affect the block decision, so a gate never
   * needs them. This also avoids a subtle transactional hazard (audit slice-2
   * P2): an advisory query that errors at the Postgres LEVEL inside the gate's
   * transaction would poison the whole txn (aborting the subsequent writes),
   * turning a supposed graceful-degrade into a blocked lifecycle event. A gate
   * running only blocking contributors is immune. Stays future-proof: a module
   * the owner flips to blocking IS run. Read-only reports leave this false to
   * surface the full cross-module picture (advisory dues + not_tracked coverage). */
  blockingContributorsOnly?: boolean;
}

/** Fans out over the registry, aggregates, and applies the lifecycle's policy.
 * Contributors are independent: one throwing degrades ITS line to `not_tracked`
 * (surfaced, never a silent CLEARED) and never fails the whole report — EXCEPT
 * a BLOCKING contributor under {failClosedOnBlocking} (gate mode), which
 * re-throws so the caller's transaction rolls back rather than issue un-gated. */
export async function buildClearanceReport(
  db: TenantQueryClient,
  scope: ClearanceScope,
  studentId: string,
  lifecycle: string,
  registry: readonly ClearanceContributor[],
  opts: BuildClearanceOptions = {},
): Promise<ClearanceReport> {
  const contributions: ClearanceContribution[] = [];

  for (const contributor of registry) {
    const policy = policyFor(lifecycle, contributor.module);
    // Gate mode: an advisory contributor cannot change the block decision, so
    // it is never queried — no wasted round-trip, and no advisory query can
    // poison the gate's transaction (audit slice-2 P2).
    if (opts.blockingContributorsOnly && policy !== "blocking") continue;
    // Fail-closed invariant (audit final P3-1): a BLOCKING source with no real
    // ledger cannot be verified either way — in gate mode it must NOT silently
    // pass as not_tracked. (No current config hits this — finance, the only
    // blocking source, is tracked — but a future owner flipping an untracked
    // module to blocking must fail closed, matching the documented guarantee.)
    if (opts.failClosedOnBlocking && policy === "blocking" && !contributor.tracked) {
      throw new Error(
        `Clearance gate: blocking module '${contributor.module}' has no ledger to verify (fail closed)`,
      );
    }
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
    } catch (err) {
      // Gate mode: a BLOCKING source that can't be read must fail CLOSED (roll
      // back), never silently pass. Advisory sources always degrade.
      if (opts.failClosedOnBlocking && policy === "blocking") throw err;
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
