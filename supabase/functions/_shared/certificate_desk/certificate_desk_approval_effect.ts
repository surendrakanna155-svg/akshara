// PRC-A Batch 2 (caps 136-148) — Certificate Request Desk F2 approval effect.
//
// Wired by the orchestrator into approval_type_handlers.ts as:
//   case "certificateRequest":
//     return await applyCertificateRequestDecision(db, organizationId, schoolId,
//       request.entity_id, effectAction, actorId ?? "", comment ?? null);
//
// This runs INSIDE the SAME transaction as decideApproval's guarded UPDATE on
// approval_requests (see approval_orchestrator.ts: decideApproval THEN
// applyApprovalTypeHandler, one db, one withTenantContext). A throw here rolls
// back the ENTIRE approval decision — including the approval_requests status
// flip that already happened in this same transaction.
//
// ⚠ WHY THIS DOES **NOT** CATCH THE SIS ENGINE'S ERRORS (unlike `case "refund":`)
// The TC engine throws from BOTH sides of its first write, and the two are
// indistinguishable by error type:
//   - NoDuesPendingError               @ sis_certificates_repository.ts:461  (BEFORE any write — safe)
//   - InvalidStudentStatusTransitionError @ :471/:475                        (BEFORE any write — safe)
//   - NoDuesPendingError               @ :525  (AFTER allocateTcSerial + insertIssue)
//   - InvalidStudentStatusTransitionError @ :560  (AFTER allocateTcSerial + insertIssue)
// The two late throws ARE the rollback mechanism: :525 fails closed when a
// concurrent TC already consumed the covering waiver, and :560 is the
// prior-status guard that stops two concurrent zero-dues TCs from each burning
// a serial and each inserting a row. The engine's own comments say so
// explicitly ("the throw rolls back the just-inserted issue row + the allocated
// serial").
//
// Catching them here would convert that rollback into a COMMIT: a phantom
// sis_certificate_issues row with a burned sequential serial, no clearance
// snapshot (:528 never ran), the student never flipped to transferred — while
// the request cheerfully reports blocked_dues. That is a duplicate legal
// document, i.e. exactly the defect the engine guards against.
//
// So: the ONE expected, recoverable outcome (a student who genuinely owes
// money) is PRE-CHECKED before the engine writes anything. Every engine throw
// then propagates and fails closed. The fake DB cannot model transaction
// rollback, so no unit test can catch this class of mistake — it is a
// read-the-engine-and-reason obligation.

import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type CertificateData,
  issueCertificate,
  issueTransferCertificate,
  NoDuesPendingError,
} from "../sis/sis_certificates_repository.ts";
import { resolveClearanceDecision } from "../clearance/clearance_gate.ts";
import {
  assertCertificateRequestType,
  CertificateRequestNotFoundError,
  type CertificateRequestScope,
  getCertificateRequestById,
  markRequestBlockedDues,
  markRequestIssued,
  markRequestRejected,
} from "./certificate_desk_repository.ts";

/**
 * Decides a pending certificate request whose F2 approval was just approved
 * or rejected.
 *
 * - "rejected"  -> guarded pending -> rejected; returns
 *                  { requestStatus: "rejected", certificateRequestId }.
 * - "approved"  -> dispatches on certificate_type: "transfer" goes through
 *                  issueTransferCertificate (no-dues gate + serial + status
 *                  flip); every other type goes through issueCertificate
 *                  (including the new "fee" type — a real finance pull, no
 *                  status change). On success: guarded pending -> issued,
 *                  stamping issued_certificate_id. Returns
 *                  { requestStatus: "issued", certificateRequestId,
 *                    certificateIssueId, serialNo? }.
 *
 * NoDuesPendingError / InvalidStudentStatusTransitionError / StudentNotFoundError
 * thrown by the SIS engine are caught (NOT rethrown): the request is marked
 * guarded pending -> blocked_dues with the reason in issue_note, and the
 * function returns { requestStatus: "blocked_dues", issued: false, note } so
 * the approval decision still records honestly instead of rolling back.
 *
 * Every terminal write is a status='pending'-guarded UPDATE (via the
 * certificate_desk_repository helpers) — a concurrent second call for the
 * same request (e.g. a retried decide) finds 0 rows on its guarded UPDATE and
 * throws CertificateRequestStateError, so a double-issue is impossible.
 */
export async function applyCertificateRequestDecision(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  requestId: string,
  action: "approved" | "rejected",
  actorId: string,
  comment?: string | null,
): Promise<Record<string, unknown>> {
  const scope: CertificateRequestScope = { organizationId, schoolId };

  const request = await getCertificateRequestById(db, scope, requestId);
  if (!request) {
    throw new CertificateRequestNotFoundError(requestId);
  }

  if (action === "rejected") {
    const updated = await markRequestRejected(db, scope, requestId, comment?.trim() || null);
    return {
      requestStatus: "rejected",
      certificateRequestId: updated.id,
    };
  }

  // action === "approved"
  const type = assertCertificateRequestType(request.certificate_type);

  // PRE-FLIGHT the one expected, recoverable gate: a student who genuinely owes
  // money. This is the same waiver-aware decision the TC engine itself consults
  // (clearance_gate.resolveClearanceDecision), so a student cleared by an
  // APPROVED waiver is NOT pre-blocked here — we must not diverge from the gate
  // by reading raw dues instead. Checked BEFORE the engine writes anything, so
  // reporting "blocked_dues" never requires recovering from a post-write throw.
  if (type === "transfer") {
    const decision = await resolveClearanceDecision(
      db,
      { organizationId, schoolId },
      request.student_id,
      "transfer_certificate",
    );
    if (decision.blocked) {
      const note = new NoDuesPendingError(decision.blockingAmount).message;
      const updated = await markRequestBlockedDues(db, scope, requestId, note);
      return {
        requestStatus: "blocked_dues",
        certificateRequestId: updated.id,
        issued: false,
        note,
      };
    }
  }

  // From here every engine failure propagates and rolls back the WHOLE decision
  // (approval stays pending; the approver retries). That is deliberate and
  // fail-closed: a late NoDuesPendingError/InvalidStudentStatusTransitionError
  // means a concurrent request beat us to the waiver or the status, and the
  // rollback is what discards the serial + issue row this call already wrote.
  // See the header comment — do NOT wrap this in a try/catch.
  let issued: CertificateData;
  let serialNo: string | undefined;

  if (type === "transfer") {
    const tc = await issueTransferCertificate(db, organizationId, schoolId, {
      studentId: request.student_id,
      reason: request.purpose,
      issuedBy: actorId,
    });
    issued = tc.certificate;
    serialNo = tc.serialNo;
  } else {
    issued = await issueCertificate(db, organizationId, schoolId, {
      studentId: request.student_id,
      type,
      reason: request.purpose,
      issuedBy: actorId,
    });
  }

  const updated = await markRequestIssued(db, scope, requestId, issued.issueId);
  return {
    requestStatus: "issued",
    certificateRequestId: updated.id,
    certificateIssueId: issued.issueId,
    ...(serialNo ? { serialNo } : {}),
  };
}
