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
  static const String documentsUploadPresign = '$base/documents/upload/presign';
  static const String handoffsSend = '$base/handoffs/send';

  // ADM-3: bulk assign / stage change over many leads.
  static const String leadsBulk = '$leads/bulk';

  // ADM-D2: warn-only duplicate lookup by phone.
  static const String leadsCheckDuplicate = '$leads/check-duplicate';

  static String documentDownload(String documentId) =>
      '$documents/$documentId/download';

  static String lead(String leadId) => '$leads/$leadId';
  static String leadAssign(String leadId) => '${lead(leadId)}/assign';
  static String leadStage(String leadId) => '${lead(leadId)}/stage';
  static String leadFollowUps(String leadId) => '${lead(leadId)}/followups';
  static String leadNotes(String leadId) => '${lead(leadId)}/notes';

  // ADM-D1: mark a lead lost with a reason.
  static String leadLost(String leadId) => '${lead(leadId)}/lost';

  // ADM-4: complete / reschedule a scheduled follow-up.
  static String followUpComplete(String leadId, String followUpId) =>
      '${leadFollowUps(leadId)}/$followUpId/complete';
  static String followUpReschedule(String leadId, String followUpId) =>
      '${leadFollowUps(leadId)}/$followUpId/reschedule';

  // ADM-D4: offer-letter data for an approved enrollment.
  static String enrollmentOfferLetter(String enrollmentId) =>
      '$enrollments/$enrollmentId/offer-letter';

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
