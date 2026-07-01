// Approval-decision domain effect for staff/student leave.
//
// In API mode the Approval Center is authoritative and the CLIENT adapter's
// onApproved side-effect is SKIPPED (approval_center_provider `skipDomainEffects`),
// so the BACKEND must persist the leave-status change on decision. Previously the
// approval handler only recorded an audit effect and never flipped the leave row,
// leaving approved/rejected leaves stuck on "pending" in every read model.
//
// Leave lives in one of two stores depending on how it was raised:
//   • mobile_leave_requests — parent/teacher-submitted (student & staff mobile leave)
//   • snapshot_leave (hr_entities snapshot) — HR-module staff leave
// We flip by id in both (each a no-op when the id is absent), so the effect is
// correct regardless of origin.

import type { TenantQueryClient } from "../tenant_db.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";

const hrWriteStore = createEntityWriteStore("hr_entities", "Hr");

export type LeaveDecisionStatus = "approved" | "rejected";

export interface LeaveFlipResult {
  updated: boolean;
  store: "mobile" | "hr_snapshot" | "none";
}

export async function flipLeaveDecision(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  leaveId: string,
  status: LeaveDecisionStatus,
  comment?: string,
): Promise<LeaveFlipResult> {
  // 1) mobile_leave_requests (parent/teacher submitted). Match by id within tenant.
  const mobile = await db.queryObject<{ id: string }>(
    `UPDATE mobile_leave_requests
        SET status = $4, updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND id = $3
      RETURNING id`,
    [organizationId, schoolId, leaveId, status],
  );
  if (mobile.length > 0) return { updated: true, store: "mobile" };

  // 2) snapshot_leave — HR staff leave requests live under `requests[]`.
  let found = false;
  await hrWriteStore.mutateSnapshot(
    db,
    organizationId,
    schoolId,
    "snapshot_leave",
    (current) => {
      const requests = Array.isArray(current.requests)
        ? current.requests as Array<Record<string, unknown>>
        : [];
      const index = requests.findIndex((r) => String(r.id ?? "") === leaveId);
      if (index < 0) return current;
      found = true;
      const next = [...requests];
      next[index] = { ...requests[index], status, decisionComment: comment ?? null };
      const pendingCount = next.filter((r) => String(r.status ?? "") === "pending").length;
      return { ...current, requests: next, pendingCount };
    },
  );
  return found ? { updated: true, store: "hr_snapshot" } : { updated: false, store: "none" };
}
