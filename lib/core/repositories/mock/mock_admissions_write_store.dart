import '../../../features/admissions/admissions_models.dart';

/// Mutable in-memory store backing mock admissions write operations.
class MockAdmissionsWriteStore {
  MockAdmissionsWriteStore._();

  static final MockAdmissionsWriteStore instance = MockAdmissionsWriteStore._();

  List<AdmissionsLead>? leads;
  List<AdmissionsApplication>? applications;
  List<StudentDocumentRecord>? documents;
  List<PendingEnrollmentRecord>? enrollments;
  List<ApprovedStudentHandoff>? handoffs;
  List<ApprovalQueueItem>? approvalQueue;
  AdmissionsSettingsData? settings;

  int _leadSeq = 2000;
  int _appSeq = 3000;
  int _docSeq = 4000;
  int _enrollSeq = 5000;
  int _approvalSeq = 6000;
  int _handoffSeq = 7000;

  String nextLeadId() => 'LD-${++_leadSeq}';
  String nextAppId() => 'APP-${++_appSeq}';
  String nextDocId() => 'DOC-${++_docSeq}';
  String nextEnrollId() => 'enr_${++_enrollSeq}';
  String nextApprovalId() => 'appr_${++_approvalSeq}';
  String nextHandoffId() => 'handoff_${++_handoffSeq}';

  /// applicationId → leadId for journey traceability.
  final Map<String, String> applicationLeadIds = {};

  AdmissionsLead? lastCreatedLead;

  PendingEnrollmentRecord? findEnrollment(String id) {
    return enrollments?.cast<PendingEnrollmentRecord?>().firstWhere(
          (record) => record?.id == id,
          orElse: () => null,
        );
  }

  PendingEnrollmentRecord? findEnrollmentByApplication(String applicationId) {
    return enrollments?.cast<PendingEnrollmentRecord?>().firstWhere(
          (record) => record?.applicationId == applicationId,
          orElse: () => null,
        );
  }

  ApprovalQueueItem? findApprovalByApplication(String applicationId) {
    return approvalQueue?.cast<ApprovalQueueItem?>().firstWhere(
          (item) => item?.applicationId == applicationId,
          orElse: () => null,
        );
  }

  AdmissionsLead? findLead(String id) {
    return leads?.cast<AdmissionsLead?>().firstWhere(
          (lead) => lead?.id == id,
          orElse: () => null,
        );
  }

  AdmissionsApplication? findApplication(String id) {
    return applications?.cast<AdmissionsApplication?>().firstWhere(
          (app) => app?.id == id,
          orElse: () => null,
        );
  }

  StudentDocumentRecord? findDocument(String id) {
    return documents?.cast<StudentDocumentRecord?>().firstWhere(
          (doc) => doc?.id == id,
          orElse: () => null,
        );
  }

  ApprovalQueueItem? findApproval(String id) {
    return approvalQueue?.cast<ApprovalQueueItem?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
  }

  ApprovedStudentHandoff? findHandoff(String id) {
    return handoffs?.cast<ApprovedStudentHandoff?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
  }

  AdmissionsLead copyLead(
    AdmissionsLead lead, {
    String? parentName,
    String? studentName,
    String? classLabel,
    String? phone,
    LeadSource? source,
    String? campaign,
    LeadStage? stage,
    String? counselor,
    String? nextFollowUpLabel,
  }) {
    return AdmissionsLead(
      id: lead.id,
      parentName: parentName ?? lead.parentName,
      studentName: studentName ?? lead.studentName,
      classLabel: classLabel ?? lead.classLabel,
      phone: phone ?? lead.phone,
      source: source ?? lead.source,
      campaign: campaign ?? lead.campaign,
      stage: stage ?? lead.stage,
      counselor: counselor ?? lead.counselor,
      score: lead.score,
      nextFollowUpLabel: nextFollowUpLabel ?? lead.nextFollowUpLabel,
    );
  }

  AdmissionsApplication copyApplication(
    AdmissionsApplication app, {
    String? studentName,
    String? classLabel,
    String? parentName,
    String? submittedLabel,
    ApplicationStatus? status,
    String? counselor,
  }) {
    return AdmissionsApplication(
      id: app.id,
      studentName: studentName ?? app.studentName,
      classLabel: classLabel ?? app.classLabel,
      parentName: parentName ?? app.parentName,
      submittedLabel: submittedLabel ?? app.submittedLabel,
      status: status ?? app.status,
      documentsComplete: app.documentsComplete,
      documentsTotal: app.documentsTotal,
      counselor: counselor ?? app.counselor,
    );
  }
}
