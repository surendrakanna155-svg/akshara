import '../../../features/admissions/admissions_models.dart';

/// Contract for admissions data access (mock or API).
abstract class AdmissionsRepository {
  AdmissionsDashboardData getDashboard();
  List<AdmissionsLead> getLeads();
  List<AdmissionsApplication> getApplications();
  List<StudentDocumentRecord> getDocuments();
  List<PendingEnrollmentRecord> getPendingEnrollments();
  List<ApprovedStudentHandoff> getApprovedHandoffs();
  List<FeeStructureOption> getFeeStructureOptions();
  List<ApprovalQueueItem> getApprovalQueue();
  AdmissionsReportsData getReports();
  AdmissionsSettingsData getSettings();
  EnrollmentFormState getEnrollmentPrefill();
}
