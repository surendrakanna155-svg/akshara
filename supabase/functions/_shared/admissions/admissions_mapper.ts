import { formatDisplayDate, formatDisplayDateTime } from "./admissions_format.ts";

export interface AdmissionsLeadRow {
  id: string;
  organization_id: string;
  school_id: string;
  parent_name: string;
  student_name: string;
  class_label: string;
  phone: string;
  source: string;
  campaign: string;
  stage: string;
  counselor: string;
  score: string;
  next_follow_up_label: string;
  email: string | null;
  address: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface AdmissionsApplicationRow {
  id: string;
  organization_id: string;
  school_id: string;
  lead_id: string | null;
  student_name: string;
  class_label: string;
  parent_name: string;
  counselor: string;
  status: string;
  submitted_at: string | null;
  submitted_by: string | null;
  created_at: string;
  updated_at: string;
  documents_complete?: number;
  documents_total?: number;
}

export interface AdmissionsDocumentRow {
  id: string;
  organization_id: string;
  school_id: string;
  lead_id: string | null;
  application_id: string | null;
  student_name: string;
  class_label: string;
  document_type: string;
  file_name: string;
  is_required: boolean;
  status: string;
  uploaded_at: string | null;
  verified_by: string | null;
  reviewer_note: string | null;
  storage_path: string | null;
  created_at: string;
  updated_at: string;
}

export interface AdmissionsApprovalRow {
  id: string;
  organization_id: string;
  school_id: string;
  application_id: string;
  student_name: string;
  class_label: string;
  parent_name: string;
  counselor: string;
  decision: string;
  ai_score: number;
  submitted_at: string | null;
  decided_by: string | null;
  decided_at: string | null;
  created_at: string;
  updated_at: string;
  documents_complete?: number;
  documents_total?: number;
}

export interface AdmissionsEnrollmentRow {
  id: string;
  organization_id: string;
  school_id: string;
  application_id: string | null;
  student_id: string | null;
  guardian_user_id: string | null;
  student_name: string;
  seeking_class: string;
  section: string;
  academic_year: string;
  academic_year_id: string | null;
  class_id: string | null;
  section_id: string | null;
  guardian_name: string;
  phone: string;
  gender: string;
  date_of_birth: string;
  conversion_status: string;
  admission_number: string | null;
  submitted_at: string;
  created_at: string;
}

export function leadToApi(row: AdmissionsLeadRow): Record<string, unknown> {
  return {
    id: row.id,
    parentName: row.parent_name,
    studentName: row.student_name,
    classLabel: row.class_label,
    phone: row.phone,
    source: row.source,
    campaign: row.campaign,
    stage: row.stage,
    counselor: row.counselor,
    score: row.score,
    nextFollowUpLabel: row.next_follow_up_label,
    email: row.email ?? "",
    address: row.address ?? "",
    notes: row.notes ?? "",
    createdLabel: formatDisplayDate(row.created_at),
    lastActivityLabel: formatDisplayDateTime(row.updated_at),
  };
}

export function applicationToApi(
  row: AdmissionsApplicationRow,
): Record<string, unknown> {
  return {
    id: row.id,
    studentName: row.student_name,
    classLabel: row.class_label,
    parentName: row.parent_name,
    submittedLabel: row.submitted_at
      ? formatDisplayDate(row.submitted_at)
      : "Not submitted",
    status: row.status,
    documentsComplete: row.documents_complete ?? 0,
    documentsTotal: row.documents_total ?? 0,
    counselor: row.counselor,
    leadId: row.lead_id,
  };
}

export function documentToApi(
  row: AdmissionsDocumentRow,
): Record<string, unknown> {
  return {
    id: row.id,
    studentName: row.student_name,
    classLabel: row.class_label,
    documentType: row.document_type,
    isRequired: row.is_required,
    status: row.status,
    uploadedLabel: row.uploaded_at
      ? formatDisplayDateTime(row.uploaded_at)
      : "—",
    verifiedBy: row.verified_by,
    leadId: row.lead_id ?? "",
    // A real file is attached and retrievable (signed URL) via the document
    // download endpoint. Null storage_path = metadata-only legacy row.
    hasFile: !!row.storage_path,
  };
}

export function approvalToApi(
  row: AdmissionsApprovalRow,
): Record<string, unknown> {
  return {
    id: row.id,
    applicationId: row.application_id,
    studentName: row.student_name,
    classLabel: row.class_label,
    parentName: row.parent_name,
    counselor: row.counselor,
    submittedLabel: row.submitted_at
      ? formatDisplayDate(row.submitted_at)
      : "—",
    documentsComplete: row.documents_complete ?? 0,
    documentsTotal: row.documents_total ?? 0,
    decision: row.decision,
    aiScore: row.ai_score,
  };
}

export interface AdmissionsFeeHandoffRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  application_id: string | null;
  enrollment_id: string | null;
  academic_year: string;
  recommended_fee_plan_id: string | null;
  handoff_status: string;
  student_name: string;
  class_label: string;
  admission_number: string;
  needs_transport: boolean;
  needs_hostel: boolean;
  sis_handoff_label: string;
  created_at: string;
  updated_at: string;
}

export function handoffToApi(
  row: AdmissionsFeeHandoffRow,
): Record<string, unknown> {
  return {
    id: row.id,
    studentName: row.student_name,
    classLabel: row.class_label,
    applicationId: row.application_id ?? "",
    admissionNumber: row.admission_number,
    needsTransport: row.needs_transport,
    needsHostel: row.needs_hostel,
    selectedFeeStructureId: row.recommended_fee_plan_id,
    handoffStatus: row.handoff_status,
    previewStudentId: row.student_id,
    sisHandoffLabel: row.sis_handoff_label,
    academicYear: row.academic_year,
    enrollmentId: row.enrollment_id,
    recommendedFeePlanId: row.recommended_fee_plan_id,
  };
}

export function enrollmentToApi(
  row: AdmissionsEnrollmentRow,
): Record<string, unknown> {
  return {
    id: row.id,
    studentName: row.student_name,
    applicationId: row.application_id ?? "",
    seekingClass: row.seeking_class,
    section: row.section,
    academicYear: row.academic_year,
    academicYearId: row.academic_year_id,
    classId: row.class_id,
    sectionId: row.section_id,
    guardianName: row.guardian_name,
    phone: row.phone,
    submittedAt: formatDisplayDateTime(row.submitted_at),
    conversionStatus: row.conversion_status,
    generatedAdmissionNumber: row.admission_number,
    previewStudentId: row.student_id,
    gender: row.gender,
    dateOfBirth: row.date_of_birth,
  };
}

export interface AdmissionsLeadActivityRow {
  id: string;
  organization_id: string;
  school_id: string;
  lead_id: string;
  activity_type: string;
  title: string;
  description: string;
  actor: string;
  created_at: string;
}

export interface AdmissionsLeadFollowUpRow {
  id: string;
  organization_id: string;
  school_id: string;
  lead_id: string;
  task: string;
  scheduled_label: string;
  completed_label: string;
  counselor: string;
  status: string;
  outcome: string;
  created_at: string;
  updated_at: string;
}

export function leadActivityToApi(
  row: AdmissionsLeadActivityRow,
): Record<string, unknown> {
  return {
    id: row.id,
    timestampLabel: formatDisplayDateTime(row.created_at),
    title: row.title,
    description: row.description,
    actor: row.actor,
    type: row.activity_type,
  };
}

export function followUpToApi(
  row: AdmissionsLeadFollowUpRow,
): Record<string, unknown> {
  return {
    id: row.id,
    scheduledLabel: row.scheduled_label,
    completedLabel: row.completed_label,
    task: row.task,
    counselor: row.counselor,
    status: row.status,
    outcome: row.outcome,
  };
}

export function listEnvelope(
  items: Record<string, unknown>[],
  pagination: {
    page: number;
    pageSize: number;
    total: number;
    hasMore: boolean;
  },
): Record<string, unknown> {
  return {
    items,
    pagination: {
      page: pagination.page,
      pageSize: pagination.pageSize,
      total: pagination.total,
      hasMore: pagination.hasMore,
    },
  };
}
