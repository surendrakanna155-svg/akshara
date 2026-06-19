import type { TenantQueryClient } from "../tenant_db.ts";
import { applyApprovalTypeHandler } from "./approval_type_handlers.ts";
import {
  decideApproval,
  type DecideApprovalInput,
} from "./approval_repository.ts";
import type { ApprovalRequestRow } from "./approval_types.ts";

export interface OrchestrateDecisionInput {
  approvalId: string;
  status: "approved" | "rejected" | "cancelled";
  actorId: string;
  actorName: string;
  comment?: string | null;
}

/**
 * F2.2 — Updates approval row, writes audit, and invokes type handler on approve/reject.
 */
export async function orchestrateApprovalDecision(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: OrchestrateDecisionInput,
): Promise<ApprovalRequestRow> {
  const decideInput: DecideApprovalInput = {
    approvalId: input.approvalId,
    status: input.status,
    actorId: input.actorId,
    actorName: input.actorName,
    comment: input.comment,
  };

  const updated = await decideApproval(db, organizationId, schoolId, decideInput);

  if (input.status === "approved" || input.status === "rejected") {
    await applyApprovalTypeHandler(
      db,
      organizationId,
      schoolId,
      updated,
      input.status,
      input.comment ?? undefined,
      input.actorId,
    );
  }

  return updated;
}
