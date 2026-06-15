abstract final class OrganizationBuilderApiPaths {
  static const String packs = '/platform/org-builder/packs';
  static const String interviewDrafts = '/platform/org-builder/interview/drafts';
  static String interviewDraft(String id) =>
      '/platform/org-builder/interview/drafts/$id';
  static String interviewStep(String id) =>
      '/platform/org-builder/interview/drafts/$id/step';
  static const String preview = '/platform/org-builder/preview';
  static const String provision = '/platform/org-builder/provision';
  static String provisioningJob(String id) => '/platform/provisioning-jobs/$id';
}
