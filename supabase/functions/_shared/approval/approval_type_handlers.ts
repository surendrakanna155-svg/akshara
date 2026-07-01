import type { TenantQueryClient } from "../tenant_db.ts";
import {
  InvalidRefundTransitionError,
  RefundNotCollectibleError,
  RefundNotFoundError,
  approveRefund,
} from "../finance/finance_refunds_repository.ts";
import {
  publishExamResults,
  recordExamRejection,
} from "../academics/exam_administration/exam_administration_repository.ts";
import {
  applyAttendanceCorrection,
  updateAttendanceCorrectionStatus,
} from "../attendance/attendance_correction_repository.ts";
import { flipHostelLeaveStatus } from "../hostel/hostel_write_handlers.ts";
import {
  approvePurchaseOrder,
  InvalidPurchaseOrderStateError,
  PurchaseOrderNotFoundError,
  rejectPurchaseOrder,
} from "../inventory_finance/inventory_finance_repository.ts";
import { flipLeaveDecision } from "./leave_decision_effect.ts";
import { setFeeStructureStatus } from "../finance/finance_structures_repository.ts";
import type { ApprovalRequestRow } from "./approval_types.ts";
import { insertDomainEffect } from "./approval_repository.ts";

/**
 * `entity_type` values that mark a leave approval as a hostel leave/gate-pass,
 * so the decision flips the hostel leave row (not just records an effect).
 */
const HOSTEL_LEAVE_ENTITY_TYPES = new Set([
  "hostel_leave",
  "hostel_leave_request",
  "hostel_gate_pass",
]);

export type DomainEffectAction = "approved" | "rejected";

/**
 * Applies server-side domain effects for F2 approval types.
 * Domain APIs (F4/F5/F7) may replace inline effects later; this table is authoritative in API mode.
 */
export async function applyApprovalTypeHandler(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  request: ApprovalRequestRow,
  effectAction: DomainEffectAction,
  comment?: string,
  actorId?: string,
): Promise<Record<string, unknown>> {
  const basePayload: Record<string, unknown> = {
    type: request.type,
    entityType: request.entity_type,
    entityId: request.entity_id,
    comment: comment ?? null,
  };

  let effectPayload = { ...basePayload };

  switch (request.type) {
    case "examResults":
      if (effectAction === "approved") {
        const publishedCount = await publishExamResults(
          db,
          organizationId,
          schoolId,
          request.entity_id,
        );
        effectPayload = {
          ...effectPayload,
          published: true,
          examSessionId: request.entity_id,
          publishedCount,
        };
      } else {
        await recordExamRejection(
          db,
          organizationId,
          schoolId,
          request.entity_id,
          comment ?? "Rejected",
        );
        effectPayload = {
          ...effectPayload,
          published: false,
          examSessionId: request.entity_id,
        };
      }
      break;

    case "studentLeave":
    case "staffLeave": {
      const leaveStatus = effectAction === "approved" ? "approved" : "rejected";
      effectPayload = {
        ...effectPayload,
        leaveStatus,
        leaveId: request.entity_id,
      };
      // A hostel leave/gate-pass is approved through the same studentLeave type;
      // flip the underlying hostel_entities row so its status reflects the
      // decision (previously only the approval effect was recorded).
      if (HOSTEL_LEAVE_ENTITY_TYPES.has(request.entity_type)) {
        const flipped = await flipHostelLeaveStatus(
          db,
          organizationId,
          schoolId,
          request.entity_id,
          leaveStatus,
        );
        effectPayload = {
          ...effectPayload,
          hostelLeaveUpdated: flipped !== null,
        };
      } else {
        // Persist the actual leave-status change on the underlying row
        // (mobile_leave_requests or the HR snapshot_leave snapshot). In API mode
        // the client adapter side-effect is skipped, so without this the leave
        // stayed "pending" forever after approval/rejection.
        const flip = await flipLeaveDecision(
          db,
          organizationId,
          schoolId,
          request.entity_id,
          leaveStatus,
          comment,
        );
        effectPayload = {
          ...effectPayload,
          leaveRowUpdated: flip.updated,
          leaveStore: flip.store,
        };
      }
      break;
    }

    case "attendanceCorrection":
      if (effectAction === "approved") {
        const applied = await applyAttendanceCorrection(
          db,
          organizationId,
          schoolId,
          request.entity_id,
        );
        effectPayload = {
          ...effectPayload,
          correctionStatus: "applied",
          correctionId: request.entity_id,
          presentDelta: applied.present_delta,
        };
      } else {
        await updateAttendanceCorrectionStatus(
          db,
          organizationId,
          schoolId,
          request.entity_id,
          "rejected",
        );
        effectPayload = {
          ...effectPayload,
          correctionStatus: "denied",
          correctionId: request.entity_id,
          comment: comment ?? null,
        };
      }
      break;

    case "feeConcession":
      effectPayload = {
        ...effectPayload,
        concessionStatus: effectAction === "approved" ? "active" : "rejected",
        concessionId: request.entity_id,
      };
      break;

    case "feeStructure": {
      // Fee structures are created `inactive` when approval is required; approving
      // must flip the real finance_fee_structures row to `active` (reject leaves
      // it inactive). Previously feeStructure was not even a recognised approval
      // type, so this decision never persisted.
      const activate = effectAction === "approved";
      const row = await setFeeStructureStatus(
        db,
        organizationId,
        schoolId,
        request.entity_id,
        activate ? "active" : "inactive",
      );
      effectPayload = {
        ...effectPayload,
        feeStructureId: request.entity_id,
        feeStructureStatus: row?.status ?? (activate ? "active" : "inactive"),
        feeStructureUpdated: row !== null,
      };
      break;
    }

    case "refund": {
      const refundId = String(request.payload.refundId ?? request.entity_id);
      if (effectAction === "approved" && actorId) {
        try {
          const refund = await approveRefund(
            db,
            organizationId,
            schoolId,
            refundId,
            actorId,
          );
          effectPayload = {
            ...effectPayload,
            refundId,
            refundStatus: refund.refund_status,
            financeIntegrated: true,
          };
        } catch (error) {
          if (
            error instanceof RefundNotFoundError ||
            error instanceof InvalidRefundTransitionError ||
            error instanceof RefundNotCollectibleError
          ) {
            effectPayload = {
              ...effectPayload,
              refundId,
              refundStatus: "approved_pending_finance",
              financeIntegrated: false,
              financeNote: error.message,
            };
          } else {
            throw error;
          }
        }
      } else {
        effectPayload = {
          ...effectPayload,
          refundId,
          refundStatus: effectAction === "approved" ? "approved" : "rejected",
          financeIntegrated: false,
        };
      }
      break;
    }

    case "inventoryPo": {
      const poStatus = effectAction === "approved" ? "approved" : "rejected";
      effectPayload = {
        ...effectPayload,
        poStatus,
        purchaseOrderId: request.entity_id,
      };
      // Persist the PO decision on the real purchase_orders row. Approve runs the
      // finance-integrated path (AP commitment + posting); reject just flips the
      // status. Previously this was audit-only, so an approved PO stayed "draft".
      try {
        if (effectAction === "approved" && actorId) {
          const result = await approvePurchaseOrder(
            db,
            organizationId,
            schoolId,
            request.entity_id,
            actorId,
          );
          effectPayload = {
            ...effectPayload,
            poRowUpdated: true,
            poStatus: result.purchaseOrder.status,
            apCommitmentId: result.apCommitmentId,
            financeIntegrated: true,
          };
        } else if (effectAction === "rejected") {
          const rejected = await rejectPurchaseOrder(
            db,
            organizationId,
            schoolId,
            request.entity_id,
          );
          effectPayload = {
            ...effectPayload,
            poRowUpdated: rejected !== null,
            poStatus: rejected?.status ?? poStatus,
          };
        }
      } catch (error) {
        // PO absent or no longer a draft (already decided) — keep the audit
        // effect but flag that the row write was not re-applied.
        if (
          error instanceof PurchaseOrderNotFoundError ||
          error instanceof InvalidPurchaseOrderStateError
        ) {
          effectPayload = { ...effectPayload, poRowUpdated: false, poNote: error.message };
        } else {
          throw error;
        }
      }
      break;
    }

    default:
      effectPayload = {
        ...effectPayload,
        note: "Unhandled approval type — recorded for audit only",
      };
  }

  await insertDomainEffect(
    db,
    organizationId,
    schoolId,
    request.id,
    request.type,
    request.entity_type,
    request.entity_id,
    effectAction,
    effectPayload,
  );

  return effectPayload;
}
