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
