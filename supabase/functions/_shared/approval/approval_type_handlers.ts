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
import type { ApprovalRequestRow } from "./approval_types.ts";
import { insertDomainEffect } from "./approval_repository.ts";

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
      effectPayload = {
        ...effectPayload,
        leaveStatus: effectAction === "approved" ? "approved" : "rejected",
        leaveId: request.entity_id,
      };
      break;

    case "staffLeave":
      effectPayload = {
        ...effectPayload,
        leaveStatus: effectAction === "approved" ? "approved" : "rejected",
        leaveId: request.entity_id,
      };
      break;

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

    case "inventoryPo":
      effectPayload = {
        ...effectPayload,
        poStatus: effectAction === "approved" ? "approved" : "rejected",
        purchaseOrderId: request.entity_id,
      };
      break;

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
