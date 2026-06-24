import 'admissions_models.dart';

/// Domain request to create a new admissions lead.
class CreateLeadRequest {
  const CreateLeadRequest({
    required this.parentName,
    required this.studentName,
    required this.classLabel,
    required this.phone,
    this.source = LeadSource.website,
    this.campaign = '',
    this.counselor = '',
    this.email = '',
    this.address = '',
    this.notes = '',
  });

  final String parentName;
  final String studentName;
  final String classLabel;
  final String phone;
  final LeadSource source;
  final String campaign;
  final String counselor;
  final String email;
  final String address;
  final String notes;
}

/// Domain request to update an existing lead.
class UpdateLeadRequest {
  const UpdateLeadRequest({
    this.parentName,
    this.studentName,
    this.classLabel,
    this.phone,
    this.source,
    this.campaign,
    this.email,
    this.address,
    this.notes,
  });

  final String? parentName;
  final String? studentName;
  final String? classLabel;
  final String? phone;
  final LeadSource? source;
  final String? campaign;
  final String? email;
  final String? address;
  final String? notes;
}

/// Assigns a counselor to a lead.
class AssignCounselorRequest {
  const AssignCounselorRequest({required this.counselor});

  final String counselor;
}

/// Changes the pipeline stage for a lead.
class ChangeLeadStageRequest {
  const ChangeLeadStageRequest({required this.stage});

  final LeadStage stage;
}

/// Schedules or records a lead follow-up.
class FollowUpRequest {
  const FollowUpRequest({
    required this.task,
    required this.scheduledLabel,
    this.outcome = '',
    this.counselor = '',
  });

  final String task;
  final String scheduledLabel;
  final String outcome;
  final String counselor;
}

/// Adds a note to a lead timeline.
class LeadNoteRequest {
  const LeadNoteRequest({
    required this.content,
    this.activityType = 'note',
    this.title = '',
  });

  final String content;

  /// Timeline channel: `note`, `whatsapp` or `call`. Lets the same endpoint log
  /// WhatsApp (wa.me) sends and call records onto the unified activity timeline.
  final String activityType;

  /// Optional override for the timeline entry title.
  final String title;
}

/// Creates a draft application.
class CreateApplicationRequest {
  const CreateApplicationRequest({
    required this.studentName,
    required this.classLabel,
    required this.parentName,
    this.leadId,
    this.counselor = '',
  });

  final String studentName;
  final String classLabel;
  final String parentName;
  final String? leadId;
  final String counselor;
}

/// Updates a draft application.
class UpdateApplicationRequest {
  const UpdateApplicationRequest({
    this.studentName,
    this.classLabel,
    this.parentName,
    this.counselor,
  });

  final String? studentName;
  final String? classLabel;
  final String? parentName;
  final String? counselor;
}

/// Uploads a student document metadata payload.
class DocumentUploadRequest {
  const DocumentUploadRequest({
    required this.leadId,
    required this.documentType,
    required this.fileName,
    this.studentName = '',
    this.classLabel = '',
  });

  final String leadId;
  final DocumentType documentType;
  final String fileName;
  final String studentName;
  final String classLabel;
}

/// Approves or rejects a document with optional reviewer note.
class DocumentVerificationRequest {
  const DocumentVerificationRequest({this.note = ''});

  final String note;
}

/// Principal approval or rejection decision.
class ApprovalDecisionRequest {
  const ApprovalDecisionRequest({this.comment = ''});

  final String comment;
}

/// Adds a counselor/principal note to an approval record.
class ApprovalNoteRequest {
  const ApprovalNoteRequest({required this.content});

  final String content;
}

/// Sends an approved student to Finance for fee setup.
class FinanceHandoffRequest {
  const FinanceHandoffRequest({
    required this.handoffId,
    required this.feeStructureId,
  });

  final String handoffId;
  final String feeStructureId;
}

/// Updates fee handoff workflow status.
class UpdateHandoffStatusRequest {
  const UpdateHandoffStatusRequest({required this.status});

  final FeeHandoffStatus status;
}

/// Submits a completed enrollment wizard.
class EnrollmentSubmitRequest {
  const EnrollmentSubmitRequest({
    required this.student,
    required this.parent,
    required this.academic,
    this.applicationId,
  });

  final EnrollmentStudentProfile student;
  final EnrollmentParentInfo parent;
  final EnrollmentAcademicInfo academic;
  final String? applicationId;
}

/// Generates an admission number for an enrollment or application.
class GenerateAdmissionNumberRequest {
  const GenerateAdmissionNumberRequest({
    this.enrollmentId,
    this.applicationId,
  });

  final String? enrollmentId;
  final String? applicationId;
}

/// Result of generating an admission number.
class GeneratedAdmissionNumber {
  const GeneratedAdmissionNumber({required this.admissionNumber});

  final String admissionNumber;
}

/// Single setting value update within admissions settings.
class AdmissionsSettingUpdate {
  const AdmissionsSettingUpdate({
    required this.sectionId,
    required this.itemId,
    required this.value,
  });

  final String sectionId;
  final String itemId;
  final String value;
}

/// Domain request to update admissions module settings.
class UpdateAdmissionsSettingsRequest {
  const UpdateAdmissionsSettingsRequest({
    this.academicYear,
    this.updates = const [],
  });

  final String? academicYear;
  final List<AdmissionsSettingUpdate> updates;
}
