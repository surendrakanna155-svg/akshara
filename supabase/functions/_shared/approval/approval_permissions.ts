import type { F2ApprovalType } from "./approval_types.ts";

const APPROVAL_PERMISSION_BY_TYPE: Record<F2ApprovalType, string> = {
  examResults: "approveExamResults",
  studentLeave: "approveStudentLeave",
  staffLeave: "approveStaffLeave",
  attendanceCorrection: "approveAttendanceCorrection",
  feeConcession: "approveFeeConcession",
  feeStructure: "approveFeeStructure",
  refund: "approveRefunds",
  inventoryPo: "approvePurchaseOrder",
  certificateRequest: "approveCertificateRequest",
  gatePass: "approveGatePass",
};

/** RBAC permission slug required to approve/reject a given approval type. */
export function approvalPermissionForType(type: string): string | null {
  if (!(type in APPROVAL_PERMISSION_BY_TYPE)) {
    return null;
  }
  return APPROVAL_PERMISSION_BY_TYPE[type as F2ApprovalType];
}

/** Submit requires manage or approve permission for the type (or view for self-submit flows). */
export function submitPermissionForType(type: string): string | null {
  return approvalPermissionForType(type) ?? "manageApprovals";
}
