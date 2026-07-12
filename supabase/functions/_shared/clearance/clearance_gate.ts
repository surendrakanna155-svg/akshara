// SCE-1 — gate-mode clearance evaluation for a student lifecycle transition.
//
// The single entry point a transition (TC issuance, transfer, promotion, alumni
// conversion) calls to decide whether dues block the event. Distinct from the
// read-only report path in ONE critical way: it FAILS CLOSED — a BLOCKING dues
// source that cannot be read re-throws (the caller's transaction rolls back)
// rather than degrading to not_tracked, so a read outage can never let a duesful
// student through a gate. Advisory sources still degrade (their outage must not
// block the event).

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  buildClearanceReport,
  type ClearanceReport,
  type ClearanceScope,
} from "./clearance_engine.ts";
import { DEFAULT_CLEARANCE_REGISTRY } from "./clearance_contributors.ts";
import {
  findActiveWaiver,
  type WaiverLifecycle,
} from "./clearance_waiver_repository.ts";

export async function evaluateClearanceGate(
  db: TenantQueryClient,
  scope: ClearanceScope,
  studentId: string,
  lifecycle: string,
): Promise<ClearanceReport> {
  return await buildClearanceReport(
    db,
    scope,
    studentId,
    lifecycle,
    DEFAULT_CLEARANCE_REGISTRY,
    // Gate mode: fail closed on a blocking-source read error, and run ONLY the
    // blocking contributors — an advisory query has no bearing on the decision
    // and (audit slice-2 P2) must not run inside the gate's transaction where a
    // DB-level error would poison it.
    { failClosedOnBlocking: true, blockingContributorsOnly: true },
  );
}

/** The final gate verdict for a lifecycle transition: dues (from the engine)
 * with an APPROVED waiver applied. A waiver clears the block ONLY when it still
 * COVERS the current dues (dues have not grown past the snapshotted amount the
 * checker approved) — no open-ended "waive all future dues". */
export interface ClearanceGateDecision {
  /** true when dues remain AFTER any covering waiver — the caller must block. */
  blocked: boolean;
  /** the unwaived dues that remain (0 when cleared) — the 409 amount. */
  blockingAmount: number;
  /** dues present at the gate BEFORE any waiver — the immutable audit snapshot. */
  duesAtGate: number;
  /** the approved waiver applied to clear the block, else null. */
  waiver: { id: string; amount: number } | null;
}

export async function resolveClearanceDecision(
  db: TenantQueryClient,
  scope: ClearanceScope,
  studentId: string,
  lifecycle: WaiverLifecycle,
): Promise<ClearanceGateDecision> {
  const report = await evaluateClearanceGate(db, scope, studentId, lifecycle);
  const dues = report.blockingAmount;
  if (!report.blocked) {
    return { blocked: false, blockingAmount: 0, duesAtGate: dues, waiver: null };
  }
  // Dues block — is there an approved waiver that still COVERS them? (A read
  // error here is inside the gate txn → propagates → rollback → fails closed.)
  const waiver = await findActiveWaiver(db, scope, studentId, lifecycle);
  const covered = Number(waiver?.blocking_amount ?? -1);
  if (waiver && dues <= covered) {
    return {
      blocked: false,
      blockingAmount: 0,
      duesAtGate: dues,
      waiver: { id: waiver.id, amount: covered },
    };
  }
  // No waiver, or dues grew past what it covered → still blocked.
  return { blocked: true, blockingAmount: dues, duesAtGate: dues, waiver: null };
}
