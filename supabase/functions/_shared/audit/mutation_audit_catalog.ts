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
  collectionCancelled: (collectionId: string): MutationAuditSpec => ({
    ...workflow("collectionCancelled", "finance_collection", collectionId, { collectionId }),
    domain: {
      eventType: "finance.collection.cancelled",
      payload: { collectionId },
      sourceModule: "finance",
      idempotencyKey: `finance.collection.cancelled:${collectionId}`,
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
