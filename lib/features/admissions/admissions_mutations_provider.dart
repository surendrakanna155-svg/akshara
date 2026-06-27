import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audit/audit_event.dart';
import '../../core/errors/api_failure.dart';
import '../../core/errors/api_failure_mapper.dart';
import '../../core/repositories/academic/academic_catalog_mutation.dart';
import '../../core/repositories/academic/academic_catalog_provider.dart';
import '../../core/repositories/repository_providers.dart';
import 'applications/admissions_applications_provider.dart';
import 'approval/admissions_approval_provider.dart';
import 'documents/admissions_documents_provider.dart';
import 'enrollment/admissions_enrollment_provider.dart';
import 'enrollment/admissions_enrollment_records_provider.dart';
import 'fee_handoff/admissions_fee_handoff_provider.dart';
import 'leads/admissions_leads_provider.dart';
import 'settings/admissions_settings_provider.dart';
import '../../core/tenant/tenant_provider.dart';
import 'admissions_audit.dart';
import 'admissions_models.dart';
import 'admissions_requests.dart';

void _invalidateAdmissionsReads(
  Ref ref, {
  bool leads = false,
  bool applications = false,
  bool documents = false,
  bool enrollments = false,
  bool approval = false,
  bool handoffs = false,
  bool enrollmentPrefill = false,
  bool settings = false,
}) {
  if (leads) ref.invalidate(admissionsLeadsFutureProvider);
  if (applications) ref.invalidate(admissionsApplicationsFutureProvider);
  if (documents) ref.invalidate(admissionsDocumentsFutureProvider);
  if (enrollments) ref.invalidate(admissionsPendingEnrollmentsFutureProvider);
  if (approval) ref.invalidate(admissionsApprovalQueueFutureProvider);
  if (enrollmentPrefill) {
    ref.invalidate(admissionsEnrollmentPrefillFutureProvider);
  }
  if (handoffs) {
    ref.invalidate(admissionsApprovedHandoffsFutureProvider);
  }
  if (settings) {
    ref.invalidate(admissionsSettingsFutureProvider);
  }
}

Future<T?> _runMutation<T>(
  Ref ref, {
  required Future<T> Function() action,
  required AuditEventType auditType,
  required String entityId,
  String Function(T result)? entityIdForAudit,
  Map<String, String> metadata = const {},
  bool invalidateLeads = false,
  bool invalidateApplications = false,
  bool invalidateDocuments = false,
  bool invalidateEnrollments = false,
  bool invalidateApproval = false,
  bool invalidateHandoffs = false,
  bool invalidateEnrollmentPrefill = false,
  bool invalidateSettings = false,
  void Function()? assertPermission,
}) async {
  assertPermission?.call();
  try {
    final result = await action();
    await recordAdmissionsAudit(
      ref,
      type: auditType,
      entityId: entityIdForAudit?.call(result) ?? entityId,
      metadata: metadata,
    );
    _invalidateAdmissionsReads(
      ref,
      leads: invalidateLeads,
      applications: invalidateApplications,
      documents: invalidateDocuments,
      enrollments: invalidateEnrollments,
      approval: invalidateApproval,
      handoffs: invalidateHandoffs,
      enrollmentPrefill: invalidateEnrollmentPrefill,
      settings: invalidateSettings,
    );
    return result;
  } catch (error) {
    final failure = apiFailureMapper.fromException(error);
    throw ApiFailureException(failure);
  }
}

class CreateLeadNotifier extends AsyncNotifier<AdmissionsLead?> {
  @override
  FutureOr<AdmissionsLead?> build() => null;

  Future<AdmissionsLead?> execute(CreateLeadRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.leadCreated,
        entityId: 'lead',
        entityIdForAudit: (lead) => lead.id,
        invalidateLeads: true,
        invalidateEnrollmentPrefill: true,
        action: () => ref.read(admissionsRepositoryProvider).createLead(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final createLeadProvider =
    AsyncNotifierProvider<CreateLeadNotifier, AdmissionsLead?>(
  CreateLeadNotifier.new,
);

class UpdateLeadNotifier extends AsyncNotifier<AdmissionsLead?> {
  @override
  FutureOr<AdmissionsLead?> build() => null;

  Future<AdmissionsLead?> execute({
    required String leadId,
    required UpdateLeadRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.leadUpdated,
        entityId: leadId,
        invalidateLeads: true,
        action: () => ref.read(admissionsRepositoryProvider).updateLead(
              query: ref.read(repositoryQueryProvider),
              leadId: leadId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final updateLeadProvider =
    AsyncNotifierProvider<UpdateLeadNotifier, AdmissionsLead?>(
  UpdateLeadNotifier.new,
);

class AssignCounselorNotifier extends AsyncNotifier<AdmissionsLead?> {
  @override
  FutureOr<AdmissionsLead?> build() => null;

  Future<AdmissionsLead?> execute({
    required String leadId,
    required AssignCounselorRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.leadAssigned,
        entityId: leadId,
        metadata: {'counselor': request.counselor},
        invalidateLeads: true,
        action: () => ref.read(admissionsRepositoryProvider).assignCounselor(
              query: ref.read(repositoryQueryProvider),
              leadId: leadId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final assignCounselorProvider =
    AsyncNotifierProvider<AssignCounselorNotifier, AdmissionsLead?>(
  AssignCounselorNotifier.new,
);

class ChangeLeadStageNotifier extends AsyncNotifier<AdmissionsLead?> {
  @override
  FutureOr<AdmissionsLead?> build() => null;

  Future<AdmissionsLead?> execute({
    required String leadId,
    required ChangeLeadStageRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.leadStageChanged,
        entityId: leadId,
        metadata: {'stage': request.stage.name},
        invalidateLeads: true,
        action: () => ref.read(admissionsRepositoryProvider).changeLeadStage(
              query: ref.read(repositoryQueryProvider),
              leadId: leadId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final changeLeadStageProvider =
    AsyncNotifierProvider<ChangeLeadStageNotifier, AdmissionsLead?>(
  ChangeLeadStageNotifier.new,
);

class AddLeadFollowUpNotifier extends AsyncNotifier<LeadFollowUpRecord?> {
  @override
  FutureOr<LeadFollowUpRecord?> build() => null;

  Future<LeadFollowUpRecord?> execute({
    required String leadId,
    required FollowUpRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.followupAdded,
        entityId: leadId,
        invalidateLeads: true,
        action: () => ref.read(admissionsRepositoryProvider).addLeadFollowUp(
              query: ref.read(repositoryQueryProvider),
              leadId: leadId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final addLeadFollowUpProvider =
    AsyncNotifierProvider<AddLeadFollowUpNotifier, LeadFollowUpRecord?>(
  AddLeadFollowUpNotifier.new,
);

class AddLeadNoteNotifier extends AsyncNotifier<LeadActivityItem?> {
  @override
  FutureOr<LeadActivityItem?> build() => null;

  Future<LeadActivityItem?> execute({
    required String leadId,
    required LeadNoteRequest request,
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.leadUpdated,
        entityId: leadId,
        metadata: {'action': 'noteAdded'},
        invalidateLeads: true,
        action: () => ref.read(admissionsRepositoryProvider).addLeadNote(
              query: ref.read(repositoryQueryProvider),
              leadId: leadId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final addLeadNoteProvider =
    AsyncNotifierProvider<AddLeadNoteNotifier, LeadActivityItem?>(
  AddLeadNoteNotifier.new,
);

class SubmitApplicationNotifier extends AsyncNotifier<AdmissionsApplication?> {
  @override
  FutureOr<AdmissionsApplication?> build() => null;

  Future<AdmissionsApplication?> execute(String applicationId) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.applicationSubmitted,
        entityId: applicationId,
        invalidateApplications: true,
        action: () => ref.read(admissionsRepositoryProvider).submitApplication(
              query: ref.read(repositoryQueryProvider),
              applicationId: applicationId,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final submitApplicationProvider =
    AsyncNotifierProvider<SubmitApplicationNotifier, AdmissionsApplication?>(
  SubmitApplicationNotifier.new,
);

class CreateApplicationNotifier extends AsyncNotifier<AdmissionsApplication?> {
  @override
  FutureOr<AdmissionsApplication?> build() => null;

  Future<AdmissionsApplication?> execute(
      CreateApplicationRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.leadUpdated,
        entityId: 'application',
        entityIdForAudit: (app) => app.id,
        metadata: const {'action': 'applicationCreated'},
        invalidateApplications: true,
        action: () => ref.read(admissionsRepositoryProvider).createApplication(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final createApplicationProvider =
    AsyncNotifierProvider<CreateApplicationNotifier, AdmissionsApplication?>(
  CreateApplicationNotifier.new,
);

class SubmitEnrollmentNotifier extends AsyncNotifier<PendingEnrollmentRecord?> {
  @override
  FutureOr<PendingEnrollmentRecord?> build() => null;

  Future<PendingEnrollmentRecord?> execute(
    EnrollmentSubmitRequest request,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final catalog = ref.read(academicCatalogProvider);
      final enriched = catalog == null
          ? request
          : enrichEnrollmentSubmitRequest(request, catalog);
      final record = await _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.enrollmentSubmitted,
        entityId: 'enrollment',
        entityIdForAudit: (record) => record.id,
        invalidateEnrollments: true,
        invalidateApproval: true,
        action: () => ref.read(admissionsRepositoryProvider).submitEnrollment(
              query: ref.read(repositoryQueryProvider),
              request: enriched,
            ),
      );
      return record!;
    });
    return state.valueOrNull;
  }
}

final submitEnrollmentProvider =
    AsyncNotifierProvider<SubmitEnrollmentNotifier, PendingEnrollmentRecord?>(
  SubmitEnrollmentNotifier.new,
);

class ApproveDocumentNotifier extends AsyncNotifier<StudentDocumentRecord?> {
  @override
  FutureOr<StudentDocumentRecord?> build() => null;

  Future<StudentDocumentRecord?> execute({
    required String documentId,
    DocumentVerificationRequest request = const DocumentVerificationRequest(),
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.documentApproved,
        entityId: documentId,
        invalidateDocuments: true,
        action: () => ref.read(admissionsRepositoryProvider).approveDocument(
              query: ref.read(repositoryQueryProvider),
              documentId: documentId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final approveDocumentProvider =
    AsyncNotifierProvider<ApproveDocumentNotifier, StudentDocumentRecord?>(
  ApproveDocumentNotifier.new,
);

class RejectDocumentNotifier extends AsyncNotifier<StudentDocumentRecord?> {
  @override
  FutureOr<StudentDocumentRecord?> build() => null;

  Future<StudentDocumentRecord?> execute({
    required String documentId,
    DocumentVerificationRequest request = const DocumentVerificationRequest(),
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.documentRejected,
        entityId: documentId,
        invalidateDocuments: true,
        action: () => ref.read(admissionsRepositoryProvider).rejectDocument(
              query: ref.read(repositoryQueryProvider),
              documentId: documentId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final rejectDocumentProvider =
    AsyncNotifierProvider<RejectDocumentNotifier, StudentDocumentRecord?>(
  RejectDocumentNotifier.new,
);

/// ADMIS-5: uploads a real document file (presign → PUT bytes → confirm) so the
/// stored object is retrievable during verification.
class UploadDocumentNotifier extends AsyncNotifier<StudentDocumentRecord?> {
  @override
  FutureOr<StudentDocumentRecord?> build() => null;

  Future<StudentDocumentRecord?> execute({
    required String leadId,
    required DocumentType documentType,
    required String fileName,
    required List<int> bytes,
    required String contentType,
    String studentName = '',
    String classLabel = '',
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.documentUploaded,
        entityId: leadId,
        entityIdForAudit: (doc) => doc.id,
        metadata: {'leadId': leadId},
        invalidateDocuments: true,
        action: () => ref.read(admissionsRepositoryProvider).uploadDocumentFile(
              query: ref.read(repositoryQueryProvider),
              leadId: leadId,
              documentType: documentType,
              fileName: fileName,
              bytes: bytes,
              contentType: contentType,
              studentName: studentName,
              classLabel: classLabel,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final uploadDocumentProvider =
    AsyncNotifierProvider<UploadDocumentNotifier, StudentDocumentRecord?>(
  UploadDocumentNotifier.new,
);

/// ADMIS-5: resolves a short-lived signed URL to open a stored document.
class DocumentDownloadUrlNotifier extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  Future<String?> execute({required String documentId}) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        return await ref.read(admissionsRepositoryProvider).getDocumentDownloadUrl(
              query: ref.read(repositoryQueryProvider),
              documentId: documentId,
            );
      } catch (error) {
        throw ApiFailureException(apiFailureMapper.fromException(error));
      }
    });
    return state.valueOrNull;
  }
}

final documentDownloadUrlProvider =
    AsyncNotifierProvider<DocumentDownloadUrlNotifier, String?>(
  DocumentDownloadUrlNotifier.new,
);

class ApproveAdmissionNotifier extends AsyncNotifier<ApprovalQueueItem?> {
  @override
  FutureOr<ApprovalQueueItem?> build() => null;

  Future<ApprovalQueueItem?> execute({
    required String approvalId,
    ApprovalDecisionRequest request = const ApprovalDecisionRequest(),
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertApproveAdmissions(ref),
        auditType: AuditEventType.admissionApproved,
        entityId: approvalId,
        invalidateApproval: true,
        invalidateHandoffs: true,
        action: () => ref.read(admissionsRepositoryProvider).approveAdmission(
              query: ref.read(repositoryQueryProvider),
              approvalId: approvalId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final approveAdmissionProvider =
    AsyncNotifierProvider<ApproveAdmissionNotifier, ApprovalQueueItem?>(
  ApproveAdmissionNotifier.new,
);

class RejectAdmissionNotifier extends AsyncNotifier<ApprovalQueueItem?> {
  @override
  FutureOr<ApprovalQueueItem?> build() => null;

  Future<ApprovalQueueItem?> execute({
    required String approvalId,
    ApprovalDecisionRequest request = const ApprovalDecisionRequest(),
  }) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertApproveAdmissions(ref),
        auditType: AuditEventType.admissionRejected,
        entityId: approvalId,
        invalidateApproval: true,
        action: () => ref.read(admissionsRepositoryProvider).rejectAdmission(
              query: ref.read(repositoryQueryProvider),
              approvalId: approvalId,
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final rejectAdmissionProvider =
    AsyncNotifierProvider<RejectAdmissionNotifier, ApprovalQueueItem?>(
  RejectAdmissionNotifier.new,
);

class SendToFinanceNotifier extends AsyncNotifier<ApprovedStudentHandoff?> {
  @override
  FutureOr<ApprovedStudentHandoff?> build() => null;

  Future<ApprovedStudentHandoff?> execute(FinanceHandoffRequest request) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.financeHandoffSent,
        entityId: request.handoffId,
        metadata: {'feeStructureId': request.feeStructureId},
        invalidateHandoffs: true,
        action: () => ref.read(admissionsRepositoryProvider).sendToFinance(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final sendToFinanceProvider =
    AsyncNotifierProvider<SendToFinanceNotifier, ApprovedStudentHandoff?>(
  SendToFinanceNotifier.new,
);

class UpdateAdmissionsSettingsNotifier
    extends AsyncNotifier<AdmissionsSettingsData?> {
  @override
  FutureOr<AdmissionsSettingsData?> build() => null;

  Future<AdmissionsSettingsData?> execute(
    UpdateAdmissionsSettingsRequest request,
  ) async {
    if (state.isLoading) return state.valueOrNull;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _runMutation(
        ref,
        assertPermission: () => assertManageAdmissions(ref),
        auditType: AuditEventType.leadUpdated,
        entityId: 'admissionsSettings',
        metadata: const {'action': 'updateSettings'},
        invalidateSettings: true,
        action: () => ref.read(admissionsRepositoryProvider).updateSettings(
              query: ref.read(repositoryQueryProvider),
              request: request,
            ),
      );
    });
    return state.valueOrNull;
  }
}

final updateAdmissionsSettingsProvider = AsyncNotifierProvider<
    UpdateAdmissionsSettingsNotifier, AdmissionsSettingsData?>(
  UpdateAdmissionsSettingsNotifier.new,
);
