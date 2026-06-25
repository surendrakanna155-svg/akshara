/// REST paths for the Admissions API module.
abstract final class AdmissionsApiPaths {
  static const String base = '/admissions';

  static const String dashboard = '$base/dashboard';
  static const String intelligence = '$base/intelligence';
  static const String leads = '$base/leads';
  static const String applications = '$base/applications';
  static const String documents = '$base/documents';
  static const String enrollmentsPending = '$base/enrollments/pending';
  static const String handoffsApproved = '$base/handoffs/approved';
  static const String feeStructures = '$base/fee-structures';
  static const String approvalQueue = '$base/approval-queue';
  static const String reports = '$base/reports';
  static const String settings = '$base/settings';
  static const String enrollmentPrefill = '$base/enrollment/prefill';

  static const String enrollments = '$base/enrollments';
  static const String enrollmentsGenerateNumber =
      '$base/enrollments/generate-admission-number';
  static const String documentsUpload = '$base/documents/upload';
  static const String handoffsSend = '$base/handoffs/send';

  static String lead(String leadId) => '$leads/$leadId';
  static String leadAssign(String leadId) => '${lead(leadId)}/assign';
  static String leadStage(String leadId) => '${lead(leadId)}/stage';
  static String leadFollowUps(String leadId) => '${lead(leadId)}/followups';
  static String leadNotes(String leadId) => '${lead(leadId)}/notes';

  static String application(String applicationId) =>
      '$applications/$applicationId';
  static String applicationSubmit(String applicationId) =>
      '${application(applicationId)}/submit';

  static String documentApprove(String documentId) =>
      '$documents/$documentId/approve';
  static String documentReject(String documentId) =>
      '$documents/$documentId/reject';

  static String approval(String approvalId) => '$base/approval/$approvalId';
  static String approvalApprove(String approvalId) =>
      '${approval(approvalId)}/approve';
  static String approvalReject(String approvalId) =>
      '${approval(approvalId)}/reject';
  static String approvalNotes(String approvalId) =>
      '${approval(approvalId)}/notes';

  static String handoffStatus(String handoffId) =>
      '$base/handoffs/$handoffId/status';
}
