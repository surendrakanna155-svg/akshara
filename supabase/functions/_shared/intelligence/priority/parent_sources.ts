// Adaptive AI — P3-AI-2 / W2 persona rollout: PARENT priority-item generators.
//
// The parent feed is own-children-scoped: it iterates ONLY the children on the
// signed JWT (`claims.child_ids`, resolved at login from student_guardians), and
// every per-child read is additionally RLS-bounded to the parent's own children
// (finance_invoices / attendance_records parent-scope policies). It reuses the
// exact deterministic reads that back the existing /parent/* routes —
// loadStudentParentSnapshotContext (child identity), overlayAttendanceSnapshot-
// FromRecords (canonical attendance %), overlayFeesSnapshotFromFinance (dues) —
// so no new query and no new RLS surface is introduced.
//
// PURE generators (structural input → RawPriorityItem, no DB/clock/model) + one
// async loader. Zero model calls. Nothing here touches the LLM parent-guidance /
// insights enrichment path (that lives behind its own governed handler).

import type { AccessTokenClaims } from "../../jwt.ts";
import { organizationIdFromClaims, schoolIdFromClaims } from "../../permission_middleware.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import {
  loadStudentParentSnapshotContext,
  overlayAttendanceSnapshotFromRecords,
  overlayFeesSnapshotFromFinance,
} from "../../pilot/pilot_operations_repository.ts";
import { dueInDaysFrom } from "./feed_dates.ts";
import type { PriorityFactors, Persona, RawPriorityItem } from "./priority_types.ts";

const PARENT: Persona[] = ["parent"];

/** Canonical parent attendance-alert threshold, mirroring the existing
 * generateParentAcademicSummary "attendance below 75%" alert. */
export const PARENT_ATTENDANCE_ALERT_PERCENT = 75;

/** Bound the per-request fan-out (parents rarely have many children; the login
 * fan-out itself is capped at 50). */
const MAX_CHILDREN = 20;

// ─── Structural inputs (the loader maps overlay outputs onto these) ───────────

export interface ParentChildAttendanceInput {
  studentId: string;
  childName: string;
  /** Canonical attendance %, or null when there is nothing to compute from. */
  attendancePercent: number | null;
  absentDays: number;
}

export interface ParentChildFeeInput {
  studentId: string;
  childName: string;
  /** Outstanding amount in minor units (paise). */
  totalDueMinor: number;
  /** Days until the nearest unpaid installment is due (loader-computed). */
  nearestDueInDays?: number;
}

// ─── Pure generators ─────────────────────────────────────────────────────────

/** (1) A child whose attendance has dropped below the alert threshold → a
 * per-child exception for the parent. Severity scales with how low it is. */
export function parentAttendanceItems(children: ParentChildAttendanceInput[]): RawPriorityItem[] {
  return children
    .filter((c) => c.attendancePercent !== null && c.attendancePercent < PARENT_ATTENDANCE_ALERT_PERCENT)
    .map((c) => {
      const pct = Math.round(c.attendancePercent as number);
      const absent = Math.max(0, Math.trunc(c.absentDays));
      return {
        itemKey: `parent:attendance:${c.studentId}`,
        type: "exception" as const,
        title: `${c.childName}'s attendance needs attention`,
        detail: `${c.childName}'s attendance is ${pct}% (below ${PARENT_ATTENDANCE_ALERT_PERCENT}%)` +
          `${absent > 0 ? `, with ${absent} recent absence${absent === 1 ? "" : "s"}` : ""}. ` +
          `Please review and reach out to the class teacher if needed.`,
        personas: PARENT,
        entityTags: [`student:${c.studentId}:attendance`],
        factors: { peopleAffected: 1, impactClass: pct < 60 ? "serious" as const : "elevated" as const },
        source: "parent_attendance",
      };
    });
}

/** (2) A child with an outstanding fee balance → a follow-up sized by the amount
 * due and (when known) the nearest due date. */
export function parentFeeItems(children: ParentChildFeeInput[]): RawPriorityItem[] {
  return children
    .filter((c) => c.totalDueMinor > 0)
    .map((c) => {
      const rupees = Math.round(c.totalDueMinor / 100);
      const factors: PriorityFactors = { moneyAtStakeMinor: c.totalDueMinor };
      if (typeof c.nearestDueInDays === "number") factors.dueInDays = c.nearestDueInDays;
      return {
        itemKey: `parent:fees:${c.studentId}`,
        type: "follow_up" as const,
        title: `Fees due for ${c.childName}`,
        detail: `₹${rupees.toLocaleString("en-IN")} outstanding for ${c.childName}. ` +
          `Review the invoices and pay online or at the school office.`,
        personas: PARENT,
        entityTags: [`student:${c.studentId}:fees`],
        factors,
        source: "parent_fees",
      };
    });
}

export interface ParentSourceInputs {
  attendance?: ParentChildAttendanceInput[];
  fees?: ParentChildFeeInput[];
}

export function collectParentRawItems(inputs: ParentSourceInputs): RawPriorityItem[] {
  const items: RawPriorityItem[] = [];
  if (inputs.attendance) items.push(...parentAttendanceItems(inputs.attendance));
  if (inputs.fees) items.push(...parentFeeItems(inputs.fees));
  return items;
}

// ─── Loader (DB reads; reuses the parent /parent-route repo functions) ────────

interface FeeInstallment {
  dueDateLabel?: unknown;
  statusLabel?: unknown;
}

/** Nearest still-unpaid (issued / partially_paid) installment's dueInDays, or
 * undefined when nothing is outstanding with a parseable date. */
function nearestUnpaidDueInDays(installments: FeeInstallment[], nowIso: string): number | undefined {
  const dues = installments
    .filter((i) => i.statusLabel === "issued" || i.statusLabel === "partially_paid")
    .map((i) => dueInDaysFrom(nowIso, i.dueDateLabel == null ? null : String(i.dueDateLabel)))
    .filter((n): n is number => typeof n === "number");
  return dues.length > 0 ? Math.min(...dues) : undefined;
}

/** Load the parent's raw priority items for their own children. RLS + the
 * child_ids fence are the isolation wall — a parent can only ever read their own
 * children's rows. Honest empty feed when a child has no attendance/fee signal.
 * Not degraded (self-scoped reads, not permission-gated cross-cohort sources).
 * Deterministic, zero model calls. */
export async function loadParentFeedSources(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  nowIso: string,
): Promise<{ rawItems: RawPriorityItem[]; degraded: boolean }> {
  const orgId = organizationIdFromClaims(claims);
  const schoolId = schoolIdFromClaims(claims);
  const childIds = (claims.child_ids ?? []).slice(0, MAX_CHILDREN);

  const attendance: ParentChildAttendanceInput[] = [];
  const fees: ParentChildFeeInput[] = [];

  // Sequential per child: one pooled connection / one transaction.
  for (const childId of childIds) {
    const ctx = await loadStudentParentSnapshotContext(db, orgId, schoolId, childId);
    const base = { childName: ctx.childName, childClass: ctx.childClass };

    const att = await overlayAttendanceSnapshotFromRecords(db, orgId, schoolId, childId, base);
    const kpi = (att.kpi ?? {}) as { attendancePercent?: number | null; absentDays?: number };
    attendance.push({
      studentId: childId,
      childName: ctx.childName,
      attendancePercent: typeof kpi.attendancePercent === "number" ? kpi.attendancePercent : null,
      absentDays: Number(kpi.absentDays ?? 0),
    });

    const feeSnap = await overlayFeesSnapshotFromFinance(db, orgId, schoolId, childId, base);
    const installments = Array.isArray(feeSnap.installments)
      ? (feeSnap.installments as FeeInstallment[])
      : [];
    fees.push({
      studentId: childId,
      childName: ctx.childName,
      totalDueMinor: Math.round(Number(feeSnap.totalDue ?? 0) * 100),
      nearestDueInDays: nearestUnpaidDueInDays(installments, nowIso),
    });
  }

  return { rawItems: collectParentRawItems({ attendance, fees }), degraded: false };
}
