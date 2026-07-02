import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  correlationIdFromRequest,
  type DomainEventInput,
  recordMutationAudit,
  type ServerAuditInput,
} from "./audit_repository.ts";

export interface MutationAuditSpec {
  audit: ServerAuditInput;
  domain: DomainEventInput;
}

export async function emitMutationAudit(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  spec: MutationAuditSpec,
  req?: Request,
): Promise<void> {
  const correlationId = spec.audit.correlationId ??
    (req ? correlationIdFromRequest(req) : undefined);
  await recordMutationAudit(
    db,
    claims,
    { ...spec.audit, correlationId },
    { ...spec.domain, correlationId: spec.domain.correlationId ?? correlationId },
    req,
  );
}

function workflow(
  eventType: string,
  entityType: string,
  entityId: string,
  metadata: Record<string, unknown> = {},
): Pick<MutationAuditSpec, "audit"> {
  return {
    audit: {
      eventType,
      category: "workflow",
      entityType,
      entityId,
      metadata,
    },
  };
}

/**
 * Generic audit/domain-event spec for module entity-store writes (Batch 5:
 * library/transport/hostel/hr/alumni). `eventType` is a dotted slug such as
 * `"library.book.added"` reused for both the audit row and the domain event;
 * `sourceModule` is its first segment. Avoids hand-maintaining a bespoke
 * factory per CRUD verb for the secondary modules.
 */
export function moduleEntityAudit(
  eventType: string,
  entityType: string,
  entityId: string,
  metadata: Record<string, unknown> = {},
): MutationAuditSpec {
  const sourceModule = eventType.split(".")[0] || "module";
  return {
    ...workflow(eventType, entityType, entityId, metadata),
    domain: {
      eventType,
      payload: { entityId, ...metadata },
      sourceModule,
      idempotencyKey: `${eventType}:${entityId}`,
    },
  };
}

// ─── Director portal ─────────────────────────────────────────────────────────

export const directorAudit = {
  /**
   * DIR-D1 — the director opened an audited, READ-ONLY per-school drill-down
   * ("Open Management Portal"). This is intentionally a READ that audits: the
   * "read-through with audit" requirement. Category is `read` (no state changed);
   * the event captures the actor (via claims on emit), the target schoolId and a
   * timestamp. `nonce` keys the outbox so every distinct view is recorded, not
   * deduped away.
   */
  schoolDrilldown: (schoolId: string, nonce: string): MutationAuditSpec => ({
    audit: {
      eventType: "director.school.drilldown",
      category: "read",
      entityType: "school",
      entityId: schoolId,
      metadata: { schoolId, viewedAt: nonce },
    },
    domain: {
      eventType: "director.school.drilldown",
      payload: { schoolId, viewedAt: nonce },
      sourceModule: "director",
      idempotencyKey: `director.school.drilldown:${schoolId}:${nonce}`,
    },
  }),
};

// ─── Admissions ─────────────────────────────────────────────────────────────

export const admissionsAudit = {
  leadCreated: (leadId: string, source: string): MutationAuditSpec => ({
    ...workflow("leadCreated", "lead", leadId, { leadId, source }),
    domain: {
      eventType: "admissions.lead.created",
      payload: { leadId, source },
      sourceModule: "admissions",
      idempotencyKey: `admissions.lead.created:${leadId}`,
    },
  }),
  leadUpdated: (leadId: string): MutationAuditSpec => ({
    ...workflow("leadUpdated", "lead", leadId, { leadId }),
    domain: {
      eventType: "admissions.lead.updated",
      payload: { leadId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.lead.updated:${leadId}`,
    },
  }),
  leadAssigned: (leadId: string, counselor: string, activityId: string): MutationAuditSpec => ({
    ...workflow("leadAssigned", "lead", leadId, { leadId, counselor }),
    domain: {
      eventType: "admissions.lead.assigned",
      payload: { leadId, counselor },
      sourceModule: "admissions",
      idempotencyKey: `admissions.lead.assigned:${activityId}`,
    },
  }),
  leadStageChanged: (leadId: string, stage: string, activityId: string): MutationAuditSpec => ({
    ...workflow("leadStageChanged", "lead", leadId, { leadId, stage }),
    domain: {
      eventType: "admissions.lead.stage_changed",
      payload: { leadId, stage },
      sourceModule: "admissions",
      idempotencyKey: `admissions.lead.stage_changed:${activityId}`,
    },
  }),
  leadFollowUpAdded: (leadId: string, followUpId: string): MutationAuditSpec => ({
    ...workflow("leadFollowUpAdded", "lead", leadId, { leadId, followUpId }),
    domain: {
      eventType: "admissions.lead.follow_up_added",
      payload: { leadId, followUpId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.lead.follow_up_added:${followUpId}`,
    },
  }),
  leadNoteAdded: (leadId: string, activityId: string, activityType: string): MutationAuditSpec => ({
    ...workflow("leadNoteAdded", "lead", leadId, { leadId, activityType }),
    domain: {
      eventType: "admissions.lead.note_added",
      payload: { leadId, activityType },
      sourceModule: "admissions",
      idempotencyKey: `admissions.lead.note_added:${activityId}`,
    },
  }),
  // ADM-D1 — a lead was marked lost with a reason from the fixed picklist.
  leadLost: (leadId: string, reason: string): MutationAuditSpec => ({
    ...workflow("leadLost", "lead", leadId, { leadId, reason }),
    domain: {
      eventType: "admissions.lead.lost",
      payload: { leadId, reason },
      sourceModule: "admissions",
      idempotencyKey: `admissions.lead.lost:${leadId}`,
    },
  }),
  // ADM-4 — a follow-up was completed. `nonce` keys the outbox so a legitimate
  // re-complete of a re-opened follow-up is recorded, not deduped away.
  followUpCompleted: (
    leadId: string,
    followupId: string,
    nonce: string,
  ): MutationAuditSpec => ({
    ...workflow("leadFollowUpCompleted", "lead_follow_up", followupId, {
      leadId,
      followupId,
    }),
    domain: {
      eventType: "admissions.lead.follow_up_completed",
      payload: { leadId, followupId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.lead.follow_up_completed:${followupId}:${nonce}`,
    },
  }),
  // ADM-4 — a follow-up was rescheduled to a new due label.
  followUpRescheduled: (
    leadId: string,
    followupId: string,
    nonce: string,
  ): MutationAuditSpec => ({
    ...workflow("leadFollowUpRescheduled", "lead_follow_up", followupId, {
      leadId,
      followupId,
    }),
    domain: {
      eventType: "admissions.lead.follow_up_rescheduled",
      payload: { leadId, followupId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.lead.follow_up_rescheduled:${followupId}:${nonce}`,
    },
  }),
  // #6 — admissions settings snapshot saved (single row per school). `nonce`
  // keys the outbox so each save is recorded (the row is updated in place).
  settingsSaved: (schoolId: string, nonce: string): MutationAuditSpec => ({
    ...workflow("admissionsSettingsSaved", "admissions_settings", schoolId, {
      schoolId,
    }),
    domain: {
      eventType: "admissions.settings.saved",
      payload: { schoolId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.settings.saved:${schoolId}:${nonce}`,
    },
  }),
  applicationCreated: (applicationId: string): MutationAuditSpec => ({
    ...workflow("applicationSubmitted", "application", applicationId, { applicationId }),
    domain: {
      eventType: "admissions.application.created",
      payload: { applicationId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.application:${applicationId}`,
    },
  }),
  applicationUpdated: (applicationId: string): MutationAuditSpec => ({
    ...workflow("applicationSubmitted", "application", applicationId, { applicationId, action: "updated" }),
    domain: {
      eventType: "admissions.application.updated",
      payload: { applicationId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.application.updated:${applicationId}`,
    },
  }),
  applicationSubmitted: (applicationId: string): MutationAuditSpec => ({
    ...workflow("applicationSubmitted", "application", applicationId, { applicationId }),
    domain: {
      eventType: "admissions.application.submitted",
      payload: { applicationId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.application.submitted:${applicationId}`,
    },
  }),
  documentUploaded: (documentId: string, leadId: string): MutationAuditSpec => ({
    ...workflow("applicationSubmitted", "document", documentId, { documentId, leadId }),
    domain: {
      eventType: "admissions.document.uploaded",
      payload: { documentId, leadId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.document:${documentId}`,
    },
  }),
  documentApproved: (documentId: string): MutationAuditSpec => ({
    ...workflow("documentApproved", "document", documentId, { documentId }),
    domain: {
      eventType: "admissions.document.approved",
      payload: { documentId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.document.approved:${documentId}`,
    },
  }),
  documentRejected: (documentId: string): MutationAuditSpec => ({
    ...workflow("documentRejected", "document", documentId, { documentId }),
    domain: {
      eventType: "admissions.document.rejected",
      payload: { documentId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.document.rejected:${documentId}`,
    },
  }),
  approvalNoteAdded: (
    approvalId: string,
    noteId: string,
  ): MutationAuditSpec => ({
    ...workflow("approvalNoteAdded", "approval", approvalId, {
      approvalId,
      noteId,
    }),
    domain: {
      eventType: "admissions.approval.note_added",
      payload: { approvalId, noteId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.approval.note_added:${noteId}`,
    },
  }),
  admissionApproved: (approvalId: string): MutationAuditSpec => ({
    ...workflow("admissionApproved", "approval", approvalId, { approvalId }),
    domain: {
      eventType: "admissions.approval.approved",
      payload: { approvalId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.approval.approved:${approvalId}`,
    },
  }),
  admissionRejected: (approvalId: string): MutationAuditSpec => ({
    ...workflow("admissionRejected", "approval", approvalId, { approvalId }),
    domain: {
      eventType: "admissions.approval.rejected",
      payload: { approvalId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.approval.rejected:${approvalId}`,
    },
  }),
  enrollmentSubmitted: (enrollmentId: string): MutationAuditSpec => ({
    ...workflow("enrollmentSubmitted", "enrollment", enrollmentId, { enrollmentId }),
    domain: {
      eventType: "admissions.enrollment.submitted",
      payload: { enrollmentId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.enrollment:${enrollmentId}`,
    },
  }),
  financeHandoffSent: (handoffId: string): MutationAuditSpec => ({
    ...workflow("financeHandoffSent", "fee_handoff", handoffId, { handoffId }),
    domain: {
      eventType: "admissions.handoff.sent",
      payload: { handoffId },
      sourceModule: "admissions",
      idempotencyKey: `admissions.handoff.sent:${handoffId}`,
    },
  }),
  handoffStatusUpdated: (handoffId: string, status: string): MutationAuditSpec => ({
    ...workflow("financeHandoffSent", "fee_handoff", handoffId, { handoffId, status }),
    domain: {
      eventType: "admissions.handoff.status_updated",
      payload: { handoffId, status },
      sourceModule: "admissions",
      idempotencyKey: `admissions.handoff.status:${handoffId}:${status}`,
    },
  }),
};

// ─── Finance ────────────────────────────────────────────────────────────────

export const financeAudit = {
  feeStructureCreated: (structureId: string): MutationAuditSpec => ({
    ...workflow("feeStructureCreated", "fee_structure", structureId, { structureId }),
    domain: {
      eventType: "finance.fee_structure.created",
      payload: { structureId },
      sourceModule: "finance",
      idempotencyKey: `finance.fee_structure:${structureId}`,
    },
  }),
  feeStructureUpdated: (structureId: string): MutationAuditSpec => ({
    ...workflow("feeStructureUpdated", "fee_structure", structureId, { structureId }),
    domain: {
      eventType: "finance.fee_structure.updated",
      payload: { structureId },
      sourceModule: "finance",
      idempotencyKey: `finance.fee_structure.updated:${structureId}`,
    },
  }),
  feeStructureArchived: (structureId: string): MutationAuditSpec => ({
    ...workflow("feeStructureArchived", "fee_structure", structureId, { structureId }),
    domain: {
      eventType: "finance.fee_structure.archived",
      payload: { structureId },
      sourceModule: "finance",
      idempotencyKey: `finance.fee_structure.archived:${structureId}`,
    },
  }),
  feeAssignmentCreated: (assignmentId: string): MutationAuditSpec => ({
    ...workflow("feeAssignmentCreated", "fee_assignment", assignmentId, { assignmentId }),
    domain: {
      eventType: "finance.fee_assignment.created",
      payload: { assignmentId },
      sourceModule: "finance",
      idempotencyKey: `finance.fee_assignment:${assignmentId}`,
    },
  }),
  feeAssignmentCancelled: (assignmentId: string): MutationAuditSpec => ({
    ...workflow("feeAssignmentCancelled", "fee_assignment", assignmentId, { assignmentId }),
    domain: {
      eventType: "finance.fee_assignment.cancelled",
      payload: { assignmentId },
      sourceModule: "finance",
      idempotencyKey: `finance.fee_assignment.cancelled:${assignmentId}`,
    },
  }),
  // FIN-D3: cancellation now carries the mandatory reason for the register/trail.
  collectionCancelled: (collectionId: string, reason = ""): MutationAuditSpec => ({
    ...workflow("collectionCancelled", "finance_collection", collectionId, {
      collectionId,
      ...(reason ? { reason } : {}),
    }),
    domain: {
      eventType: "finance.collection.cancelled",
      payload: { collectionId, reason },
      sourceModule: "finance",
      idempotencyKey: `finance.collection.cancelled:${collectionId}`,
    },
  }),
  // FIN-D5: a late-fee accrual pass ran (summary of how many/total accrued).
  lateFeesAccrued: (
    schoolId: string,
    accruedCount: number,
    totalLateFee: number,
    nonce: string,
  ): MutationAuditSpec => ({
    ...workflow("financeLateFeesAccrued", "finance_school", schoolId, {
      schoolId,
      accruedCount,
      totalLateFee,
    }),
    domain: {
      eventType: "finance.late_fees.accrued",
      payload: { schoolId, accruedCount, totalLateFee },
      sourceModule: "finance",
      idempotencyKey: `finance.late_fees.accrued:${schoolId}:${nonce}`,
    },
  }),
  // FIN-D5: a late fee on a specific invoice was waived (with reason).
  lateFeeWaived: (invoiceId: string, reason: string): MutationAuditSpec => ({
    ...workflow("financeLateFeeWaived", "finance_invoice", invoiceId, {
      invoiceId,
      reason,
    }),
    domain: {
      eventType: "finance.late_fee.waived",
      payload: { invoiceId, reason },
      sourceModule: "finance",
      idempotencyKey: `finance.late_fee.waived:${invoiceId}`,
    },
  }),
  // FIN-D1: a cashier day was closed / reopened (keyed per school+date+action).
  dayClosed: (schoolId: string, closeDate: string): MutationAuditSpec => ({
    ...workflow("financeDayClosed", "finance_day_close", schoolId, {
      schoolId,
      closeDate,
    }),
    domain: {
      eventType: "finance.day_close.closed",
      payload: { schoolId, closeDate },
      sourceModule: "finance",
      idempotencyKey: `finance.day_close.closed:${schoolId}:${closeDate}`,
    },
  }),
  dayReopened: (
    schoolId: string,
    closeDate: string,
    nonce: string,
  ): MutationAuditSpec => ({
    ...workflow("financeDayReopened", "finance_day_close", schoolId, {
      schoolId,
      closeDate,
    }),
    domain: {
      eventType: "finance.day_close.reopened",
      payload: { schoolId, closeDate },
      sourceModule: "finance",
      idempotencyKey: `finance.day_close.reopened:${schoolId}:${closeDate}:${nonce}`,
    },
  }),
  invoiceIssued: (invoiceId: string): MutationAuditSpec => ({
    ...workflow("invoiceIssued", "finance_invoice", invoiceId, { invoiceId }),
    domain: {
      eventType: "finance.invoice.issued",
      payload: { invoiceId },
      sourceModule: "finance",
      idempotencyKey: `finance.invoice.issued:${invoiceId}`,
    },
  }),
  invoiceCancelled: (invoiceId: string): MutationAuditSpec => ({
    ...workflow("invoiceCancelled", "finance_invoice", invoiceId, { invoiceId }),
    domain: {
      eventType: "finance.invoice.cancelled",
      payload: { invoiceId },
      sourceModule: "finance",
      idempotencyKey: `finance.invoice.cancelled:${invoiceId}`,
    },
  }),
  refundApproved: (refundId: string): MutationAuditSpec => ({
    ...workflow("refundApproved", "finance_refund", refundId, { refundId }),
    domain: {
      eventType: "finance.refund.approved",
      payload: { refundId },
      sourceModule: "finance",
      idempotencyKey: `finance.refund.approved:${refundId}`,
    },
  }),
  refundRejected: (refundId: string): MutationAuditSpec => ({
    ...workflow("refundRejected", "finance_refund", refundId, { refundId }),
    domain: {
      eventType: "finance.refund.rejected",
      payload: { refundId },
      sourceModule: "finance",
      idempotencyKey: `finance.refund.rejected:${refundId}`,
    },
  }),
  intelligenceComputed: (): MutationAuditSpec => ({
    ...workflow("financeIntelligenceComputed", "finance_intelligence", "copilot", {}),
    domain: {
      eventType: "finance.intelligence.computed",
      payload: { snapshotType: "copilot" },
      sourceModule: "finance",
      idempotencyKey: `finance.intelligence:${Date.now()}`,
    },
  }),
  executiveViewed: (healthScore: number): MutationAuditSpec => ({
    ...workflow("financeExecutiveViewed", "finance_intelligence", "executive", { healthScore }),
    domain: {
      eventType: "finance.executive.viewed",
      payload: { healthScore },
      sourceModule: "finance",
      idempotencyKey: `finance.executive:${Date.now()}`,
    },
  }),
  // ─── Wave 3 finance peripheral routes ──────────────────────────────────────
  offlinePaymentRecorded: (offlinePaymentId: string): MutationAuditSpec => ({
    ...workflow("offlinePaymentRecorded", "finance_offline_payment", offlinePaymentId, {
      offlinePaymentId,
    }),
    domain: {
      eventType: "finance.offline_payment.recorded",
      payload: { offlinePaymentId },
      sourceModule: "finance",
      idempotencyKey: `finance.offline_payment.recorded:${offlinePaymentId}`,
    },
  }),
  offlinePaymentReconciled: (offlinePaymentId: string): MutationAuditSpec => ({
    ...workflow("offlinePaymentReconciled", "finance_offline_payment", offlinePaymentId, {
      offlinePaymentId,
    }),
    domain: {
      eventType: "finance.offline_payment.reconciled",
      payload: { offlinePaymentId },
      sourceModule: "finance",
      idempotencyKey: `finance.offline_payment.reconciled:${offlinePaymentId}`,
    },
  }),
  qrSessionCreated: (sessionId: string): MutationAuditSpec => ({
    ...workflow("qrSessionCreated", "finance_qr_session", sessionId, { sessionId }),
    domain: {
      eventType: "finance.qr_session.created",
      payload: { sessionId },
      sourceModule: "finance",
      idempotencyKey: `finance.qr_session.created:${sessionId}`,
    },
  }),
  qrSessionConfirmed: (sessionId: string): MutationAuditSpec => ({
    ...workflow("qrSessionConfirmed", "finance_qr_session", sessionId, { sessionId }),
    domain: {
      eventType: "finance.qr_session.confirmed",
      payload: { sessionId },
      sourceModule: "finance",
      idempotencyKey: `finance.qr_session.confirmed:${sessionId}`,
    },
  }),
  scholarshipCreated: (scholarshipId: string): MutationAuditSpec => ({
    ...workflow("scholarshipCreated", "finance_scholarship", scholarshipId, { scholarshipId }),
    domain: {
      eventType: "finance.scholarship.created",
      payload: { scholarshipId },
      sourceModule: "finance",
      idempotencyKey: `finance.scholarship.created:${scholarshipId}`,
    },
  }),
  scholarshipUpdated: (scholarshipId: string): MutationAuditSpec => ({
    ...workflow("scholarshipUpdated", "finance_scholarship", scholarshipId, { scholarshipId }),
    domain: {
      eventType: "finance.scholarship.updated",
      payload: { scholarshipId },
      sourceModule: "finance",
      idempotencyKey: `finance.scholarship.updated:${scholarshipId}`,
    },
  }),
  financeSettingsUpdated: (schoolId: string, nonce: string): MutationAuditSpec => ({
    ...workflow("financeSettingsUpdated", "finance_settings", schoolId, { schoolId }),
    domain: {
      eventType: "finance.settings.updated",
      payload: { schoolId },
      sourceModule: "finance",
      idempotencyKey: `finance.settings.updated:${schoolId}:${nonce}`,
    },
  }),
};

// ─── SIS ────────────────────────────────────────────────────────────────────

export const sisAudit = {
  studentUpdated: (studentId: string): MutationAuditSpec => ({
    ...workflow("studentUpdated", "student", studentId, { studentId }),
    domain: {
      eventType: "sis.student.updated",
      payload: { studentId },
      sourceModule: "sis",
      idempotencyKey: `sis.student.updated:${studentId}`,
    },
  }),
  studentStatusUpdated: (studentId: string, status: string): MutationAuditSpec => ({
    ...workflow("studentUpdated", "student", studentId, { studentId, status }),
    domain: {
      eventType: "sis.student.status_updated",
      payload: { studentId, status },
      sourceModule: "sis",
      idempotencyKey: `sis.student.status:${studentId}:${status}`,
    },
  }),
  documentVerified: (
    documentId: string,
    studentId: string,
    status: string,
    note?: string | null,
  ): MutationAuditSpec => ({
    ...workflow("sisDocumentVerified", "student_document", documentId, {
      documentId,
      studentId,
      status,
      ...(note ? { note } : {}),
    }),
    domain: {
      eventType: "sis.document.verified",
      payload: { documentId, studentId, status },
      sourceModule: "sis",
      idempotencyKey: `sis.document.verified:${documentId}:${status}`,
    },
  }),
  enrollmentCreated: (enrollmentId: string): MutationAuditSpec => ({
    ...workflow("sisEnrollmentCreated", "sis_enrollment", enrollmentId, { enrollmentId }),
    domain: {
      eventType: "sis.enrollment.created",
      payload: { enrollmentId },
      sourceModule: "sis",
      idempotencyKey: `sis.enrollment:${enrollmentId}`,
    },
  }),
  enrollmentUpdated: (enrollmentId: string): MutationAuditSpec => ({
    ...workflow("sisEnrollmentUpdated", "sis_enrollment", enrollmentId, { enrollmentId }),
    domain: {
      eventType: "sis.enrollment.updated",
      payload: { enrollmentId },
      sourceModule: "sis",
      idempotencyKey: `sis.enrollment.updated:${enrollmentId}`,
    },
  }),
  admissionsConverted: (studentId: string, enrollmentId: string): MutationAuditSpec => ({
    ...workflow("admissionsConversionCompleted", "student", studentId, { studentId, enrollmentId }),
    domain: {
      eventType: "sis.admissions.converted",
      payload: { studentId, enrollmentId },
      sourceModule: "sis",
      idempotencyKey: `sis.admissions.converted:${enrollmentId}`,
    },
  }),
};

// ─── Academic ───────────────────────────────────────────────────────────────

export const academicAudit = {
  yearCreated: (yearId: string): MutationAuditSpec => ({
    ...workflow("academicYearCreated", "academic_year", yearId, { yearId }),
    domain: {
      eventType: "academic.year.created",
      payload: { yearId },
      sourceModule: "academic",
      idempotencyKey: `academic.year:${yearId}`,
    },
  }),
  yearUpdated: (yearId: string): MutationAuditSpec => ({
    ...workflow("academicYearUpdated", "academic_year", yearId, { yearId }),
    domain: {
      eventType: "academic.year.updated",
      payload: { yearId },
      sourceModule: "academic",
      idempotencyKey: `academic.year.updated:${yearId}`,
    },
  }),
  yearTransitionExecuted: (
    transitionId: string,
    metadata: Record<string, unknown>,
  ): MutationAuditSpec => ({
    ...workflow("academicYearTransitionExecuted", "academic_year_transition", transitionId, metadata),
    domain: {
      eventType: "academic.year.transition.executed",
      payload: { transitionId, ...metadata },
      sourceModule: "academic",
      idempotencyKey: `academic.year.transition:${transitionId}`,
    },
  }),
  classCreated: (classId: string): MutationAuditSpec => ({
    ...workflow("academicClassCreated", "academic_class", classId, { classId }),
    domain: {
      eventType: "academic.class.created",
      payload: { classId },
      sourceModule: "academic",
      idempotencyKey: `academic.class:${classId}`,
    },
  }),
  classUpdated: (classId: string): MutationAuditSpec => ({
    ...workflow("academicClassUpdated", "academic_class", classId, { classId }),
    domain: {
      eventType: "academic.class.updated",
      payload: { classId },
      sourceModule: "academic",
      idempotencyKey: `academic.class.updated:${classId}`,
    },
  }),
  sectionCreated: (sectionId: string): MutationAuditSpec => ({
    ...workflow("academicSectionCreated", "academic_section", sectionId, { sectionId }),
    domain: {
      eventType: "academic.section.created",
      payload: { sectionId },
      sourceModule: "academic",
      idempotencyKey: `academic.section:${sectionId}`,
    },
  }),
  sectionUpdated: (sectionId: string): MutationAuditSpec => ({
    ...workflow("academicSectionUpdated", "academic_section", sectionId, { sectionId }),
    domain: {
      eventType: "academic.section.updated",
      payload: { sectionId },
      sourceModule: "academic",
      idempotencyKey: `academic.section.updated:${sectionId}`,
    },
  }),
  teacherAssignmentCreated: (assignmentId: string): MutationAuditSpec => ({
    ...workflow("academicTeacherAssignmentCreated", "teacher_assignment", assignmentId, {
      assignmentId,
    }),
    domain: {
      eventType: "academic.teacher_assignment.created",
      payload: { assignmentId },
      sourceModule: "academic",
      idempotencyKey: `academic.teacher_assignment:${assignmentId}`,
    },
  }),
  teacherAssignmentUpdated: (assignmentId: string): MutationAuditSpec => ({
    ...workflow("academicTeacherAssignmentUpdated", "teacher_assignment", assignmentId, {
      assignmentId,
    }),
    domain: {
      eventType: "academic.teacher_assignment.updated",
      payload: { assignmentId },
      sourceModule: "academic",
      idempotencyKey: `academic.teacher_assignment.updated:${assignmentId}`,
    },
  }),
};

// ─── Exam Administration ─────────────────────────────────────────────────────

export const examAudit = {
  /**
   * EXM-D6 / integrity gap (e) — a SINGLE mark entry was updated (marks and/or
   * attendance status). Captures the FULL before→after of BOTH marks_obtained and
   * status so the original attempt (including an AB/ML/DB) is always recoverable
   * from the audit trail — the design requirement for a future supplementary /
   * re-exam without losing history. `nonce` keys the outbox so every legitimate
   * re-edit of the same cell is recorded (not deduped away); row_version keeps
   * bumping on the row itself.
   */
  markUpdated: (
    examId: string,
    markEntryId: string,
    studentId: string,
    before: { marksObtained: number | null; status: string },
    after: { marksObtained: number | null; status: string },
    rowVersion: number,
    nonce: string,
  ): MutationAuditSpec => ({
    ...workflow("examMarkUpdated", "exam_mark_entry", markEntryId, {
      examId,
      markEntryId,
      studentId,
      before,
      after,
      rowVersion,
    }),
    domain: {
      eventType: "exam.mark.updated",
      payload: { examId, markEntryId, studentId, before, after, rowVersion },
      sourceModule: "exam",
      idempotencyKey: `exam.mark.updated:${markEntryId}:${nonce}`,
    },
  }),
  /**
   * EXM-D2 — a grace / moderation adjustment (a signed delta) was recorded for a
   * (exam, student) by a coordinator, BEFORE publish. The ORIGINAL mark is never
   * overwritten; the delta + reason + the resulting effective mark are captured so
   * the moderation is fully auditable (and reversible by recording an offsetting
   * delta). `adjustmentId` keys the outbox so every distinct adjustment is
   * recorded exactly once.
   */
  markGraceApplied: (
    examId: string,
    studentId: string,
    adjustmentId: string,
    delta: number,
    reason: string,
    effectiveMark: number | null,
  ): MutationAuditSpec => ({
    ...workflow("examMarkGraceApplied", "exam_mark_adjustment", adjustmentId, {
      examId,
      studentId,
      adjustmentId,
      delta,
      reason,
      effectiveMark,
    }),
    domain: {
      eventType: "exam.mark.grace_applied",
      payload: { examId, studentId, adjustmentId, delta, reason, effectiveMark },
      sourceModule: "exam",
      idempotencyKey: `exam.mark.grace_applied:${adjustmentId}`,
    },
  }),
  /**
   * Exam results were PUBLISHED (made visible to students/parents) — a critical,
   * non-reversible mutation. `examId` is the exam_session (result set) id; the
   * approver who authorized the publish (when an approval gate is used) and the
   * count of published mark entries are recorded for the trail. Keyed per exam so
   * a re-publish of the same session is deduped on the outbox.
   */
  resultsPublished: (
    examId: string,
    publishedCount: number,
    approvalId?: string | null,
  ): MutationAuditSpec => ({
    ...workflow("examResultsPublished", "exam_session", examId, {
      examId,
      publishedCount,
      ...(approvalId ? { approvalId } : {}),
    }),
    domain: {
      eventType: "exam.results.published",
      payload: { examId, publishedCount, approvalId: approvalId ?? null },
      sourceModule: "exam",
      idempotencyKey: `exam.results.published:${examId}`,
    },
  }),
};

// ─── Education (v8.5–v8.8) ──────────────────────────────────────────────────

export const educationAudit = {
  questionBankCreated: (itemId: string): MutationAuditSpec => ({
    ...workflow("questionBankItemCreated", "question_bank_item", itemId, { itemId }),
    domain: {
      eventType: "education.question_bank.created",
      payload: { itemId },
      sourceModule: "education",
      idempotencyKey: `education.question_bank:${itemId}`,
    },
  }),
  questionBankArchived: (itemId: string): MutationAuditSpec => ({
    ...workflow("questionBankItemArchived", "question_bank_item", itemId, { itemId }),
    domain: {
      eventType: "education.question_bank.archived",
      payload: { itemId },
      sourceModule: "education",
      idempotencyKey: `education.question_bank.archived:${itemId}`,
    },
  }),
  questionPaperGenerated: (paperId: string): MutationAuditSpec => ({
    ...workflow("questionPaperGenerated", "question_paper", paperId, { paperId }),
    domain: {
      eventType: "education.question_paper.generated",
      payload: { paperId },
      sourceModule: "education",
      idempotencyKey: `education.question_paper:${paperId}`,
    },
  }),
  questionPaperPublished: (paperId: string): MutationAuditSpec => ({
    ...workflow("questionPaperPublished", "question_paper", paperId, { paperId }),
    domain: {
      eventType: "education.question_paper.published",
      payload: { paperId },
      sourceModule: "education",
      idempotencyKey: `education.question_paper.published:${paperId}`,
    },
  }),
  questionPaperSubmitted: (paperId: string): MutationAuditSpec => ({
    ...workflow("questionPaperSubmitted", "question_paper", paperId, { paperId }),
    domain: {
      eventType: "education.question_paper.submitted",
      payload: { paperId },
      sourceModule: "education",
      idempotencyKey: `education.question_paper.submitted:${paperId}`,
    },
  }),
  questionPaperReviewed: (paperId: string, decision: string): MutationAuditSpec => ({
    ...workflow("questionPaperReviewed", "question_paper", paperId, { paperId, decision }),
    domain: {
      eventType: "education.question_paper.reviewed",
      payload: { paperId, decision },
      sourceModule: "education",
      idempotencyKey: `education.question_paper.reviewed:${paperId}:${decision}`,
    },
  }),
  questionPaperItemModerated: (
    paperId: string,
    itemId: string,
    decision: string,
  ): MutationAuditSpec => ({
    ...workflow("questionPaperItemModerated", "question_paper_item", itemId, {
      paperId,
      itemId,
      decision,
    }),
    domain: {
      eventType: "education.question_paper_item.moderated",
      payload: { paperId, itemId, decision },
      sourceModule: "education",
      idempotencyKey: `education.question_paper_item.moderated:${itemId}:${decision}`,
    },
  }),
  questionBankUpdated: (itemId: string, nonce: string): MutationAuditSpec => ({
    ...workflow("questionBankItemUpdated", "question_bank_item", itemId, { itemId }),
    domain: {
      eventType: "education.question_bank.updated",
      payload: { itemId },
      sourceModule: "education",
      idempotencyKey: `education.question_bank.updated:${itemId}:${nonce}`,
    },
  }),
  questionPaperItemEdited: (
    paperId: string,
    itemId: string,
    nonce: string,
  ): MutationAuditSpec => ({
    ...workflow("questionPaperItemEdited", "question_paper_item", itemId, {
      paperId,
      itemId,
    }),
    domain: {
      eventType: "education.question_paper_item.edited",
      payload: { paperId, itemId },
      sourceModule: "education",
      idempotencyKey: `education.question_paper_item.edited:${itemId}:${nonce}`,
    },
  }),
  questionPaperItemRegenerated: (
    paperId: string,
    itemId: string,
    nonce: string,
  ): MutationAuditSpec => ({
    ...workflow("questionPaperItemRegenerated", "question_paper_item", itemId, {
      paperId,
      itemId,
    }),
    domain: {
      eventType: "education.question_paper_item.regenerated",
      payload: { paperId, itemId },
      sourceModule: "education",
      idempotencyKey: `education.question_paper_item.regenerated:${itemId}:${nonce}`,
    },
  }),
  questionPaperItemPromoted: (
    paperId: string,
    itemId: string,
    bankItemId: string,
  ): MutationAuditSpec => ({
    ...workflow("questionPaperItemPromoted", "question_bank_item", bankItemId, {
      paperId,
      itemId,
      bankItemId,
    }),
    domain: {
      eventType: "education.question_paper_item.promoted",
      payload: { paperId, itemId, bankItemId },
      sourceModule: "education",
      idempotencyKey: `education.question_paper_item.promoted:${bankItemId}`,
    },
  }),
  homeworkGenerated: (assignmentId: string): MutationAuditSpec => ({
    ...workflow("homeworkGenerated", "homework_assignment", assignmentId, { assignmentId }),
    domain: {
      eventType: "education.homework.generated",
      payload: { assignmentId },
      sourceModule: "education",
      idempotencyKey: `education.homework:${assignmentId}`,
    },
  }),
  homeworkPublished: (assignmentId: string): MutationAuditSpec => ({
    ...workflow("homeworkPublished", "homework_assignment", assignmentId, { assignmentId }),
    domain: {
      eventType: "education.homework.published",
      payload: { assignmentId },
      sourceModule: "education",
      idempotencyKey: `education.homework.published:${assignmentId}`,
    },
  }),
  reportRemarkGenerated: (remarkId: string): MutationAuditSpec => ({
    ...workflow("reportRemarkGenerated", "report_card_remark", remarkId, { remarkId }),
    domain: {
      eventType: "education.report_remark.generated",
      payload: { remarkId },
      sourceModule: "education",
      idempotencyKey: `education.report_remark:${remarkId}`,
    },
  }),
  reportRemarkUpdated: (remarkId: string): MutationAuditSpec => ({
    ...workflow("reportRemarkUpdated", "report_card_remark", remarkId, { remarkId }),
    domain: {
      eventType: "education.report_remark.updated",
      payload: { remarkId },
      sourceModule: "education",
      idempotencyKey: `education.report_remark.updated:${remarkId}`,
    },
  }),
  reportRemarkPublished: (remarkId: string): MutationAuditSpec => ({
    ...workflow("reportRemarkPublished", "report_card_remark", remarkId, { remarkId }),
    domain: {
      eventType: "education.report_remark.published",
      payload: { remarkId },
      sourceModule: "education",
      idempotencyKey: `education.report_remark.published:${remarkId}`,
    },
  }),
};

// ─── Intelligence Layer (v8.9–v9.3) ─────────────────────────────────────────

export const intelligenceAudit = {
  studentRiskComputed: (schoolId: string, count: number): MutationAuditSpec => ({
    ...workflow("studentRiskComputed", "school", schoolId, { schoolId, count }),
    domain: {
      eventType: "intelligence.student_risk.computed",
      payload: { schoolId, count },
      sourceModule: "intelligence",
      idempotencyKey: `intelligence.student_risk:${schoolId}:${count}`,
    },
  }),
  communicationGenerated: (draftId: string): MutationAuditSpec => ({
    ...workflow("communicationDraftGenerated", "communication_draft", draftId, { draftId }),
    domain: {
      eventType: "intelligence.communication.generated",
      payload: { draftId },
      sourceModule: "intelligence",
      idempotencyKey: `intelligence.communication:${draftId}`,
    },
  }),
  parentGuidanceGenerated: (reportId: string): MutationAuditSpec => ({
    ...workflow("parentGuidanceGenerated", "parent_guidance_report", reportId, { reportId }),
    domain: {
      eventType: "intelligence.parent_guidance.generated",
      payload: { reportId },
      sourceModule: "intelligence",
      idempotencyKey: `intelligence.parent_guidance:${reportId}`,
    },
  }),
  homeworkIntelligenceGenerated: (runId: string, homeworkCount: number): MutationAuditSpec => ({
    ...workflow("homeworkIntelligenceGenerated", "homework_intelligence_run", runId, {
      runId,
      homeworkCount,
    }),
    domain: {
      eventType: "intelligence.homework.generated",
      payload: { runId, homeworkCount },
      sourceModule: "intelligence",
      idempotencyKey: `intelligence.homework:${runId}`,
    },
  }),
  studentSuccessComputed: (schoolId: string, count: number): MutationAuditSpec => ({
    ...workflow("studentSuccessComputed", "school", schoolId, { schoolId, count }),
    domain: {
      eventType: "intelligence.student_success.computed",
      payload: { schoolId, count },
      sourceModule: "intelligence",
      idempotencyKey: `intelligence.student_success:${schoolId}:${count}`,
    },
  }),
  parentMeetingSummaryGenerated: (studentId: string): MutationAuditSpec => ({
    ...workflow("parentMeetingSummaryGenerated", "parent_meeting_summary", studentId, { studentId }),
    domain: {
      eventType: "intelligence.parent_meeting_summary.generated",
      payload: { studentId },
      sourceModule: "intelligence",
      idempotencyKey: `intelligence.parent_meeting_summary:${studentId}`,
    },
  }),
};

// ─── Employee Platform (v9.6) ────────────────────────────────────────────────

export const employeeAudit = {
  roleAssigned: (employeeId: string, roleCode: string): MutationAuditSpec => ({
    ...workflow("employeeRoleAssigned", "employee", employeeId, { employeeId, roleCode }),
    domain: {
      eventType: "employee.role.assigned",
      payload: { employeeId, roleCode },
      sourceModule: "employee",
      idempotencyKey: `employee.role:${employeeId}:${roleCode}`,
    },
  }),
};

// ─── Inventory Distribution (v9.7) ─────────────────────────────────────────────

export const inventoryDistributionAudit = {
  created: (distributionId: string, studentId: string): MutationAuditSpec => ({
    ...workflow("inventoryDistributionCreated", "inv_student_distribution", distributionId, {
      distributionId,
      studentId,
    }),
    domain: {
      eventType: "inventory.distribution.created",
      payload: { distributionId, studentId },
      sourceModule: "inventory",
      idempotencyKey: `inventory.distribution:${distributionId}`,
    },
  }),
  statusChanged: (distributionId: string, status: string): MutationAuditSpec => ({
    ...workflow("inventoryDistributionStatusChanged", "inv_student_distribution", distributionId, {
      distributionId,
      status,
    }),
    domain: {
      eventType: "inventory.distribution.status_changed",
      payload: { distributionId, status },
      sourceModule: "inventory",
      idempotencyKey: `inventory.distribution.status:${distributionId}:${status}`,
    },
  }),
  replacementRequested: (distributionId: string): MutationAuditSpec => ({
    ...workflow("inventoryReplacementRequested", "inv_student_distribution", distributionId, {
      distributionId,
    }),
    domain: {
      eventType: "inventory.distribution.replacement_requested",
      payload: { distributionId },
      sourceModule: "inventory",
      idempotencyKey: `inventory.distribution.replacement:${distributionId}`,
    },
  }),
};

// ─── Inventory Intelligence (v13.4) ──────────────────────────────────────────

export const inventoryIntelligenceAudit = {
  copilotComputed: (): MutationAuditSpec => ({
    ...workflow("inventoryIntelligenceComputed", "inventory_intelligence", "copilot", {}),
    domain: {
      eventType: "inventory.intelligence.computed",
      payload: { snapshotType: "copilot" },
      sourceModule: "inventory",
      idempotencyKey: `inventory.intelligence:${Date.now()}`,
    },
  }),
  lifecycleViewed: (assetsTracked: number): MutationAuditSpec => ({
    ...workflow("assetLifecycleViewed", "asset_lifecycle", "summary", { assetsTracked }),
    domain: {
      eventType: "inventory.lifecycle.viewed",
      payload: { assetsTracked },
      sourceModule: "inventory",
      idempotencyKey: `inventory.lifecycle.viewed:${Date.now()}`,
    },
  }),
  lifecycleEventRecorded: (eventId: string, eventType: string): MutationAuditSpec => ({
    ...workflow("assetLifecycleEventRecorded", "asset_lifecycle_event", eventId, { eventType }),
    domain: {
      eventType: "inventory.lifecycle.event_recorded",
      payload: { eventId, eventType },
      sourceModule: "inventory",
      idempotencyKey: `inventory.lifecycle.event:${eventId}`,
    },
  }),
  procurementWorkflowViewed: (pendingApprovals: number): MutationAuditSpec => ({
    ...workflow("procurementWorkflowViewed", "procurement_workflow", "summary", { pendingApprovals }),
    domain: {
      eventType: "inventory.procurement.workflow_viewed",
      payload: { pendingApprovals },
      sourceModule: "inventory",
      idempotencyKey: `inventory.procurement.viewed:${Date.now()}`,
    },
  }),
  procurementWorkflowAdvanced: (purchaseOrderId: string, status: string): MutationAuditSpec => ({
    ...workflow("procurementWorkflowAdvanced", "purchase_order", purchaseOrderId, { status }),
    domain: {
      eventType: "inventory.procurement.workflow_advanced",
      payload: { purchaseOrderId, status },
      sourceModule: "inventory",
      idempotencyKey: `inventory.procurement.advanced:${purchaseOrderId}:${status}`,
    },
  }),
};

// ─── Parent Experience (v9.8) ─────────────────────────────────────────────────

export const parentExperienceAudit = {
  acknowledge: (distributionId: string, acknowledgementType: string): MutationAuditSpec => ({
    ...workflow("parentItemAcknowledged", "parent_item_acknowledgement", distributionId, {
      distributionId,
      acknowledgementType,
    }),
    domain: {
      eventType: "parent.inventory.acknowledged",
      payload: { distributionId, acknowledgementType },
      sourceModule: "parent",
      idempotencyKey: `parent.ack:${distributionId}:${acknowledgementType}`,
    },
  }),
};

// ─── School Memories (v10.2) ─────────────────────────────────────────────────

export const schoolMemoriesAudit = {
  created: (eventId: string): MutationAuditSpec => ({
    ...workflow("schoolMemoryEventCreated", "school_memory_event", eventId, { eventId }),
    domain: {
      eventType: "memories.event.created",
      payload: { eventId },
      sourceModule: "memories",
      idempotencyKey: `memories.event:${eventId}`,
    },
  }),
  published: (eventId: string): MutationAuditSpec => ({
    ...workflow("schoolMemoryEventPublished", "school_memory_event", eventId, { eventId }),
    domain: {
      eventType: "memories.event.published",
      payload: { eventId },
      sourceModule: "memories",
      idempotencyKey: `memories.event.published:${eventId}`,
    },
  }),
  mediaUploaded: (mediaId: string): MutationAuditSpec => ({
    ...workflow("schoolMemoryMediaUploaded", "school_memory_media", mediaId, { mediaId }),
    domain: {
      eventType: "memories.media.uploaded",
      payload: { mediaId },
      sourceModule: "memories",
      idempotencyKey: `memories.media:${mediaId}`,
    },
  }),
  mediaDownloaded: (mediaId: string): MutationAuditSpec => ({
    ...workflow("schoolMemoryMediaDownloaded", "school_memory_media", mediaId, { mediaId }),
    domain: {
      eventType: "memories.media.downloaded",
      payload: { mediaId },
      sourceModule: "memories",
      idempotencyKey: `memories.media.download:${mediaId}`,
    },
  }),
  shareResolved: (shareToken: string, mediaId: string): MutationAuditSpec => ({
    ...workflow("schoolMemoryShareResolved", "school_memory_media", mediaId, { shareToken, mediaId }),
    domain: {
      eventType: "memories.share.resolved",
      payload: { shareToken, mediaId },
      sourceModule: "memories",
      idempotencyKey: `memories.share:${shareToken}`,
    },
  }),
};

// ─── Achievement Promotion (v10.3) ───────────────────────────────────────────

export const achievementPromotionAudit = {
  created: (promotionId: string): MutationAuditSpec => ({
    ...workflow("achievementPromotionCreated", "achievement_promotion", promotionId, { promotionId }),
    domain: {
      eventType: "promotion.created",
      payload: { promotionId },
      sourceModule: "promotion",
      idempotencyKey: `promotion.created:${promotionId}`,
    },
  }),
  generated: (promotionId: string): MutationAuditSpec => ({
    ...workflow("achievementPromotionGenerated", "achievement_promotion", promotionId, { promotionId }),
    domain: {
      eventType: "promotion.assets.generated",
      payload: { promotionId },
      sourceModule: "promotion",
      idempotencyKey: `promotion.generated:${promotionId}`,
    },
  }),
  approved: (promotionId: string): MutationAuditSpec => ({
    ...workflow("achievementPromotionApproved", "achievement_promotion", promotionId, { promotionId }),
    domain: {
      eventType: "promotion.approved",
      payload: { promotionId },
      sourceModule: "promotion",
      idempotencyKey: `promotion.approved:${promotionId}`,
    },
  }),
  published: (promotionId: string): MutationAuditSpec => ({
    ...workflow("achievementPromotionPublished", "achievement_promotion", promotionId, { promotionId }),
    domain: {
      eventType: "promotion.published",
      payload: { promotionId },
      sourceModule: "promotion",
      idempotencyKey: `promotion.published:${promotionId}`,
    },
  }),
  metricTracked: (promotionId: string, metric: string): MutationAuditSpec => ({
    ...workflow("achievementPromotionMetricTracked", "achievement_promotion", promotionId, { promotionId, metric }),
    domain: {
      eventType: "promotion.metric.tracked",
      payload: { promotionId, metric },
      sourceModule: "promotion",
      idempotencyKey: `promotion.metric:${promotionId}:${metric}:${Date.now()}`,
    },
  }),
};

// ─── Setup Wizard (v10.5) ─────────────────────────────────────────────────────

export const setupWizardAudit = {
  sessionCreated: (sessionId: string): MutationAuditSpec => ({
    ...workflow("setupWizardSessionCreated", "setup_wizard_session", sessionId, { sessionId }),
    domain: {
      eventType: "setup_wizard.session.created",
      payload: { sessionId },
      sourceModule: "setup_wizard",
      idempotencyKey: `setup_wizard.created:${sessionId}`,
    },
  }),
  sessionCompleted: (sessionId: string): MutationAuditSpec => ({
    ...workflow("setupWizardSessionCompleted", "setup_wizard_session", sessionId, { sessionId }),
    domain: {
      eventType: "setup_wizard.session.completed",
      payload: { sessionId },
      sourceModule: "setup_wizard",
      idempotencyKey: `setup_wizard.completed:${sessionId}`,
    },
  }),
};

// ─── Widget Platform (v10.6) ─────────────────────────────────────────────────

export const widgetPlatformAudit = {
  layoutSaved: (layoutId: string): MutationAuditSpec => ({
    ...workflow("dashboardLayoutSaved", "dashboard_layout", layoutId, { layoutId }),
    domain: {
      eventType: "widget_platform.layout.saved",
      payload: { layoutId },
      sourceModule: "widget_platform",
      idempotencyKey: `widget_platform.layout:${layoutId}`,
    },
  }),
  // B11 — role/vertical-pack dashboard override saved (entity = layout row id).
  roleLayoutSaved: (role: string, layoutRowId: string): MutationAuditSpec => ({
    ...workflow("widget_platform.role_layout.saved", "dashboard_layout", layoutRowId, { role }),
    domain: {
      eventType: "widget_platform.role_layout.saved",
      payload: { role, layoutRowId },
      sourceModule: "widget_platform",
      idempotencyKey: `widget_platform.role_layout:${layoutRowId}`,
    },
  }),
};

// ─── Teacher Assistant (v10.7) ───────────────────────────────────────────────

export const teacherAssistantAudit = {
  interventionCreated: (id: string): MutationAuditSpec => ({
    ...workflow("teacherInterventionCreated", "teacher_intervention", id, { id }),
    domain: {
      eventType: "teacher_assistant.intervention.created",
      payload: { id },
      sourceModule: "teacher_assistant",
      idempotencyKey: `teacher_assistant.intervention:${id}`,
    },
  }),
  interventionUpdated: (id: string): MutationAuditSpec => ({
    ...workflow("teacherInterventionUpdated", "teacher_intervention", id, { id }),
    domain: {
      eventType: "teacher_assistant.intervention.updated",
      payload: { id },
      sourceModule: "teacher_assistant",
      idempotencyKey: `teacher_assistant.intervention.updated:${id}`,
    },
  }),
};

// ─── Parent Insights (v10.8) ─────────────────────────────────────────────────

export const parentInsightsAudit = {
  snapshotGenerated: (id: string, studentId: string): MutationAuditSpec => ({
    ...workflow("parentInsightGenerated", "parent_insight_snapshot", id, { id, studentId }),
    domain: {
      eventType: "parent_insights.snapshot.generated",
      payload: { id, studentId },
      sourceModule: "parent_insights",
      idempotencyKey: `parent_insights.snapshot:${id}`,
    },
  }),
};

// ─── Growth Platform (v11.0) ─────────────────────────────────────────────────

export const growthPlatformAudit = {
  campaignCreated: (id: string): MutationAuditSpec => ({
    ...workflow("growthCampaignCreated", "growth_campaign", id, { id }),
    domain: {
      eventType: "growth.campaign.created",
      payload: { id },
      sourceModule: "growth",
      idempotencyKey: `growth.campaign:${id}`,
    },
  }),
  inquiryCreated: (id: string): MutationAuditSpec => ({
    ...workflow("growthInquiryCreated", "growth_inquiry", id, { id }),
    domain: {
      eventType: "growth.inquiry.created",
      payload: { id },
      sourceModule: "growth",
      idempotencyKey: `growth.inquiry:${id}`,
    },
  }),
  inquiryConverted: (inquiryId: string, leadId: string): MutationAuditSpec => ({
    ...workflow("growthInquiryConverted", "growth_inquiry", inquiryId, { inquiryId, leadId }),
    domain: {
      eventType: "growth.inquiry.converted",
      payload: { inquiryId, leadId },
      sourceModule: "growth",
      idempotencyKey: `growth.inquiry.convert:${inquiryId}`,
    },
  }),
  // Campaign edit/pause are repeatable — the row's post-update `updated_at` keys
  // the outbox event so legitimate re-edits are not deduped away.
  campaignUpdated: (id: string, version: string): MutationAuditSpec => ({
    ...workflow("growthCampaignUpdated", "growth_campaign", id, { id }),
    domain: {
      eventType: "growth.campaign.updated",
      payload: { id },
      sourceModule: "growth",
      idempotencyKey: `growth.campaign.update:${id}:${version}`,
    },
  }),
  campaignPaused: (id: string, version: string): MutationAuditSpec => ({
    ...workflow("growthCampaignPaused", "growth_campaign", id, { id }),
    domain: {
      eventType: "growth.campaign.paused",
      payload: { id },
      sourceModule: "growth",
      idempotencyKey: `growth.campaign.pause:${id}:${version}`,
    },
  }),
};

export const schoolCompletionAudit = {
  subjectCreated: (id: string): MutationAuditSpec => ({
    ...workflow("subjectCreated", "academic_subject", id, { id }),
    domain: {
      eventType: "school.subject.created",
      payload: { id },
      sourceModule: "school_completion",
      idempotencyKey: `school.subject:${id}`,
    },
  }),
  subjectUpdated: (id: string): MutationAuditSpec => ({
    ...workflow("subjectUpdated", "academic_subject", id, { id }),
    domain: {
      eventType: "school.subject.updated",
      payload: { id },
      sourceModule: "school_completion",
      idempotencyKey: `school.subject.update:${id}`,
    },
  }),
  lessonLogCreated: (id: string): MutationAuditSpec => ({
    ...workflow("lessonLogCreated", "teacher_lesson_log", id, { id }),
    domain: {
      eventType: "school.lesson_log.created",
      payload: { id },
      sourceModule: "school_completion",
      idempotencyKey: `school.lesson_log:${id}`,
    },
  }),
  timetableAutomated: (academicYearId: string, count: number): MutationAuditSpec => ({
    ...workflow("timetableAutomated", "academic_timetable", academicYearId, { academicYearId, count }),
    domain: {
      eventType: "school.timetable.automated",
      payload: { academicYearId, count },
      sourceModule: "school_completion",
      idempotencyKey: `school.timetable.automate:${academicYearId}:${count}`,
    },
  }),
  brandingUpdated: (id: string): MutationAuditSpec => ({
    ...workflow("schoolBrandingUpdated", "school_branding", id, { id }),
    domain: {
      eventType: "school.branding.updated",
      payload: { id },
      sourceModule: "school_completion",
      idempotencyKey: `school.branding:${id}`,
    },
  }),
  whatsAppProviderUpdated: (id: string): MutationAuditSpec => ({
    ...workflow("whatsAppProviderUpdated", "whatsapp_provider_config", id, { id }),
    domain: {
      eventType: "school.whatsapp_provider.updated",
      payload: { id },
      sourceModule: "school_completion",
      idempotencyKey: `school.whatsapp_provider:${id}`,
    },
  }),
  whatsAppTestSent: (toPhone: string): MutationAuditSpec => ({
    ...workflow("whatsAppTestSent", "whatsapp_provider_config", toPhone, { toPhone }),
    domain: {
      eventType: "school.whatsapp_provider.test",
      payload: { toPhone },
      sourceModule: "school_completion",
      idempotencyKey: `school.whatsapp_test:${toPhone}`,
    },
  }),
  classSubjectAssigned: (id: string): MutationAuditSpec => ({
    ...workflow("classSubjectAssigned", "class_subject_assignment", id, { id }),
    domain: {
      eventType: "school.class_subject.assigned",
      payload: { id },
      sourceModule: "school_completion",
      idempotencyKey: `school.class_subject:${id}`,
    },
  }),
  classSubjectRemoved: (id: string): MutationAuditSpec => ({
    ...workflow("classSubjectRemoved", "class_subject_assignment", id, { id }),
    domain: {
      eventType: "school.class_subject.removed",
      payload: { id },
      sourceModule: "school_completion",
      idempotencyKey: `school.class_subject.remove:${id}`,
    },
  }),
  teacherSubjectAssigned: (id: string): MutationAuditSpec => ({
    ...workflow("teacherSubjectAssigned", "teacher_subject_assignment", id, { id }),
    domain: {
      eventType: "school.teacher_subject.assigned",
      payload: { id },
      sourceModule: "school_completion",
      idempotencyKey: `school.teacher_subject:${id}`,
    },
  }),
  templateMessageSent: (templateCode: string): MutationAuditSpec => ({
    ...workflow("templateMessageSent", "communication_delivery_event", templateCode, { templateCode }),
    domain: {
      eventType: "school.communication.template_sent",
      payload: { templateCode },
      sourceModule: "school_completion",
      idempotencyKey: `school.template_sent:${templateCode}:${Date.now()}`,
    },
  }),
  syllabusGenerated: (id: string): MutationAuditSpec => ({
    ...workflow("syllabusGenerated", "syllabus_generation", id, { id }),
    domain: {
      eventType: "school.syllabus.generated",
      payload: { id },
      sourceModule: "school_completion",
      idempotencyKey: `school.syllabus.generated:${id}`,
    },
  }),
  syllabusCloned: (yearId: string): MutationAuditSpec => ({
    ...workflow("syllabusCloned", "syllabus_generation", yearId, { yearId }),
    domain: {
      eventType: "school.syllabus.cloned",
      payload: { yearId },
      sourceModule: "school_completion",
      idempotencyKey: `school.syllabus.cloned:${yearId}`,
    },
  }),
  topicCompleted: (topicId: string): MutationAuditSpec => ({
    ...workflow("topicCompleted", "syllabus_topic", topicId, { topicId }),
    domain: {
      eventType: "school.topic.completed",
      payload: { topicId },
      sourceModule: "school_completion",
      idempotencyKey: `school.topic.completed:${topicId}`,
    },
  }),
  roomCreated: (id: string): MutationAuditSpec => ({
    ...workflow("roomCreated", "academic_room", id, { id }),
    domain: {
      eventType: "school.room.created",
      payload: { id },
      sourceModule: "school_completion",
      idempotencyKey: `school.room:${id}`,
    },
  }),
  examTimetableGenerated: (className: string): MutationAuditSpec => ({
    ...workflow("examTimetableGenerated", "exam_timetable", className, { className }),
    domain: {
      eventType: "school.exam_timetable.generated",
      payload: { className },
      sourceModule: "school_completion",
      idempotencyKey: `school.exam_timetable:${className}`,
    },
  }),
  platformProviderUpdated: (id: string): MutationAuditSpec => ({
    ...workflow("platformProviderUpdated", "platform_provider_config", id, { id }),
    domain: {
      eventType: "platform.provider.updated",
      payload: { id },
      sourceModule: "control_center",
      idempotencyKey: `platform.provider:${id}`,
    },
  }),
  vaultSecretRotated: (secretId: string): MutationAuditSpec => ({
    ...workflow("vaultSecretRotated", "platform_secret_vault", secretId, { secretId }),
    domain: {
      eventType: "platform.vault.rotated",
      payload: { secretId },
      sourceModule: "vault",
      idempotencyKey: `platform.vault.rotated:${secretId}`,
    },
  }),
  featureEnablementUpdated: (featureKey: string): MutationAuditSpec => ({
    ...workflow("featureEnablementUpdated", "platform_feature_enablement", featureKey, { featureKey }),
    domain: {
      eventType: "platform.feature.updated",
      payload: { featureKey },
      sourceModule: "control_center",
      idempotencyKey: `platform.feature:${featureKey}`,
    },
  }),
};

// ─── Legal & Compliance ──────────────────────────────────────────────────────

export const legalAudit = {
  /**
   * A user accepted a legal policy version in-app. Keyed per user+policy+version so
   * every distinct acceptance is recorded exactly once (re-accepting the same
   * version is deduped both here and by the table's unique constraint).
   */
  policyAccepted: (
    userId: string,
    policyKey: string,
    policyVersion: string,
  ): MutationAuditSpec => ({
    ...workflow("legalPolicyAccepted", "legal_policy", policyKey, {
      policyKey,
      policyVersion,
    }),
    domain: {
      eventType: "legal.policy.accepted",
      payload: { userId, policyKey, policyVersion },
      sourceModule: "legal",
      idempotencyKey: `legal.policy.accepted:${userId}:${policyKey}:${policyVersion}`,
    },
  }),
};

// ─── Subscription / Entitlement (B2) ─────────────────────────────────────────

export const subscriptionAudit = {
  /**
   * A superAdmin assigned/changed an organization's plan (no payment). Keyed off
   * a per-event id so every assignment is recorded (the org has one row that is
   * updated in place, so there is no per-change row id to key on).
   */
  planAssigned: (
    organizationId: string,
    planSlug: string,
    status: string,
    eventId: string,
  ): MutationAuditSpec => ({
    ...workflow("subscriptionPlanAssigned", "organization_subscription",
      organizationId, { organizationId, planSlug, status }),
    domain: {
      eventType: "subscription.plan.assigned",
      payload: { organizationId, planSlug, status },
      sourceModule: "entitlements",
      idempotencyKey: `subscription.plan.assigned:${eventId}`,
    },
  }),
};

// ─── Staff attendance (Face ID self check-in/out, O5) ────────────────────────

export const staffAttendanceAudit = {
  checkInRecorded: (
    checkInId: string,
    userId: string,
    method: string,
  ): MutationAuditSpec => ({
    ...workflow("staffCheckInRecorded", "staff_check_in", checkInId, {
      userId,
      method,
      eventType: "check_in",
    }),
    domain: {
      eventType: "staff_attendance.check_in.recorded",
      payload: { checkInId, userId, method },
      sourceModule: "staff_attendance",
      idempotencyKey: `staff_attendance.check_in.recorded:${checkInId}`,
    },
  }),
  checkOutRecorded: (
    checkInId: string,
    userId: string,
    method: string,
  ): MutationAuditSpec => ({
    ...workflow("staffCheckOutRecorded", "staff_check_in", checkInId, {
      userId,
      method,
      eventType: "check_out",
    }),
    domain: {
      eventType: "staff_attendance.check_out.recorded",
      payload: { checkInId, userId, method },
      sourceModule: "staff_attendance",
      idempotencyKey: `staff_attendance.check_out.recorded:${checkInId}`,
    },
  }),
  faceEnrolled: (enrollmentId: string, userId: string): MutationAuditSpec => ({
    ...workflow("staffFaceEnrolled", "staff_face_enrollment", enrollmentId, { userId }),
    domain: {
      eventType: "staff_attendance.face.enrolled",
      payload: { enrollmentId, userId },
      sourceModule: "staff_attendance",
      idempotencyKey: `staff_attendance.face.enrolled:${enrollmentId}`,
    },
  }),
  geofenceConfigured: (schoolId: string, radiusM: number): MutationAuditSpec => ({
    ...workflow("staffGeofenceConfigured", "school_attendance_geofence", schoolId, { radiusM }),
    domain: {
      eventType: "staff_attendance.geofence.configured",
      payload: { schoolId, radiusM },
      sourceModule: "staff_attendance",
      idempotencyKey: `staff_attendance.geofence.configured:${schoolId}:${radiusM}`,
    },
  }),
  manualRequestCreated: (requestId: string, userId: string, eventType: string): MutationAuditSpec => ({
    ...workflow("staffAttendanceManualRequested", "staff_attendance_request", requestId, {
      userId,
      eventType,
    }),
    domain: {
      eventType: "staff_attendance.manual_request.created",
      payload: { requestId, userId, eventType },
      sourceModule: "staff_attendance",
      idempotencyKey: `staff_attendance.manual_request.created:${requestId}`,
    },
  }),
  manualRequestDecided: (
    requestId: string,
    approverId: string,
    status: string,
  ): MutationAuditSpec => ({
    ...workflow("staffAttendanceManualDecided", "staff_attendance_request", requestId, {
      approverId,
      status,
    }),
    domain: {
      eventType: "staff_attendance.manual_request.decided",
      payload: { requestId, approverId, status },
      sourceModule: "staff_attendance",
      idempotencyKey: `staff_attendance.manual_request.decided:${requestId}:${status}`,
    },
  }),
};
