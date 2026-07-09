class OnboardingApiPaths {
  static const String base = '/onboarding';
  static const String dashboard = '$base/dashboard';
  static const String imports = '$base/imports';
  static const String studentPreview = '$base/imports/students/preview';
  static const String teacherPreview = '$base/imports/teachers/preview';
  static const String invites = '$base/invites';
  static const String generateStudents = '$base/students/generate';

  static String importJob(String jobId) => '$imports/$jobId';
  static String commitImport(String jobId) => '$imports/$jobId/commit';
  static String rollbackImport(String jobId) => '$imports/$jobId/rollback';

  /// #10 — confirm-sent, called only after a real WhatsApp launch.
  static String markInviteSent(String inviteId) => '$invites/$inviteId/mark-sent';
}
