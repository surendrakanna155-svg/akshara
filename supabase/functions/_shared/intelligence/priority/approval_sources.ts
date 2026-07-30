// Living Dashboard Phase 6a — the `approval` priority source.
//
// WHY THIS EXISTS
// ---------------
// `approval` has been in the item taxonomy since W2.0a and was produced by ZERO
// generators, so doc 04 §4's headline principal recommendation — "8 approvals
// ≥48h old (5 leave, 3 admissions)" — was not computable. Two things were
// missing: nothing read the approval queue for the feed, and nothing measured
// how long anything had waited.
//
// This closes both. It is also what finally makes `ageBoost` a live factor:
// `approval_requests` has no due date (no queue in this ERP does — see the
// Phase 6 design doc), but it has `created_at`, and how long a decision has been
// pending is a FACT we already store. No migration, no SLA policy decision.
//
// ONE ITEM PER TYPE, NOT PER REQUEST. A principal with 40 pending approvals
// needs one actionable line per queue, not 40 cards — the standing feed-flood
// rule that `ops_sources.ts` follows. The action deep-links to the Approval
// Center, where batch-decide already lives.
//
// PURE: the generator takes measured values; the loader does all clock and DB
// work and passes `nowIso` in, exactly as every other source does.

import type { AccessTokenClaims } from "../../jwt.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import { listPendingApprovals } from "../../approval/approval_repository.ts";
import { approvalPermissionForType } from "../../approval/approval_permissions.ts";
import { waitingDaysSince } from "./feed_dates.ts";
import type { ImpactClass, Persona, RawPriorityItem } from "./priority_types.ts";

/** Approvals are a school-leadership concern; the per-type permission check
 * below is what actually decides who sees which queue. */
const APPROVAL_PERSONAS: Persona[] = ["principal", "admin"];

/** One pending-approval queue, already measured. */
export interface PendingApprovalBucket {
  type: string;
  /** How many are pending in this bucket. */
  count: number;
  /** Days the OLDEST pending request has waited. undefined = no usable clock. */
  oldestWaitingDays: number | undefined;
}

/** Severity from how long the oldest request has been sitting.
 *
 * Deliberately conservative: an approval is not an emergency because it exists,
 * it becomes one because nobody has acted. Thresholds are working-day shaped —
 * a decision pending over a week has visibly fallen through a crack. */
function impactForWait(waitingDays: number | undefined): ImpactClass {
  if (waitingDays === undefined) return "routine";
  if (waitingDays >= 7) return "serious";
  if (waitingDays >= 2) return "elevated";
  return "routine";
}

function humanType(type: string): string {
  // camelCase → spaced words, lower-cased for use mid-sentence.
  const spaced = type.replace(/([a-z0-9])([A-Z])/g, "$1 $2").toLowerCase();
  return spaced.trim();
}

/** Pure: buckets → priority items. One item per queue that has anything in it. */
export function buildApprovalItems(
  buckets: readonly PendingApprovalBucket[],
): RawPriorityItem[] {
  const items: RawPriorityItem[] = [];
  for (const bucket of buckets) {
    if (bucket.count <= 0) continue;
    const waiting = bucket.oldestWaitingDays;
    const label = humanType(bucket.type);
    const waitPhrase = waiting === undefined
      ? "awaiting a decision"
      : waiting <= 0
      ? "raised today"
      : `oldest waiting ${waiting} ${waiting === 1 ? "day" : "days"}`;

    items.push({
      itemKey: `ops:approvals:${bucket.type}`,
      type: "approval",
      title: `${bucket.count} ${label} ${bucket.count === 1 ? "approval" : "approvals"} pending`,
      detail: `${waitPhrase}. Decide in the Approval Center.`,
      personas: APPROVAL_PERSONAS,
      entityTags: ["school:approvals", `approvals:${bucket.type}`],
      factors: {
        // The wait clock — no queue in this ERP carries a due date, so age is
        // the only honest urgency signal available before Phase 6b's SLAs.
        waitingDays: waiting,
        peopleAffected: bucket.count,
        impactClass: impactForWait(waiting),
      },
      source: "approval_queue",
    });
  }
  // Stable order so the feed's dedupe/tie-break stays deterministic.
  return items.sort((a, b) => a.itemKey.localeCompare(b.itemKey));
}

/** Read the pending queue and bucket it by type, keeping only the types this
 * caller may actually decide.
 *
 * RBAC reuses `approvalPermissionForType` — the same map the approval routes
 * enforce — so the feed can never advertise a queue the user cannot act on. A
 * type with no mapped permission is dropped rather than defaulted open. */
export async function loadApprovalFeedSources(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  organizationId: string,
  schoolId: string,
  nowIso: string,
): Promise<RawPriorityItem[]> {
  const rows = await listPendingApprovals(db, organizationId, schoolId);
  const perms = claims.permissions;

  const byType = new Map<string, { count: number; oldest: number | undefined }>();
  for (const row of rows) {
    const permission = approvalPermissionForType(row.type);
    if (!permission || !perms.includes(permission)) continue;

    const waited = waitingDaysSince(nowIso, row.created_at);
    const existing = byType.get(row.type);
    if (!existing) {
      byType.set(row.type, { count: 1, oldest: waited });
      continue;
    }
    existing.count += 1;
    // "Oldest" = the largest wait we can actually measure; an unmeasurable one
    // never displaces a real number.
    if (waited !== undefined && (existing.oldest === undefined || waited > existing.oldest)) {
      existing.oldest = waited;
    }
  }

  return buildApprovalItems(
    [...byType.entries()].map(([type, v]) => ({
      type,
      count: v.count,
      oldestWaitingDays: v.oldest,
    })),
  );
}
