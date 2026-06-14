abstract final class EvolutionApiPaths {
  static const String setupWizardSessions = '/setup-wizard/sessions';
  static String setupWizardSession(String id) => '/setup-wizard/sessions/$id';
  static String setupWizardAdvance(String id) => '/setup-wizard/sessions/$id/advance';

  static const String widgetRegistry = '/widgets/registry';
  static const String widgetDashboardLayout = '/widgets/dashboard/layout';
  static const String widgetData = '/widgets/data';

  static const String teacherAssistantInsights = '/teacher-assistant/insights';
  static const String teacherInterventions = '/teacher-assistant/interventions';
  static String teacherIntervention(String id) => '/teacher-assistant/interventions/$id';

  static const String parentInsightsGenerate = '/parent-insights/generate';
  static String parentInsightsStudent(String studentId) => '/parent-insights/students/$studentId';
  static const String parentLanguagePreference = '/parent-insights/language-preference';

  static const String principalCommandCenter = '/principal-command/center';
  static const String principalCommandQuery = '/principal-command/query';

  static const String growthDashboard = '/growth/dashboard';
  static const String growthFunnel = '/growth/funnel';
  static const String growthCampaigns = '/growth/campaigns';
  static String growthCampaign(String id) => '/growth/campaigns/$id';
  static String growthCampaignPause(String id) => '/growth/campaigns/$id/pause';
  static const String growthCampaignHistory = '/growth/campaigns/history';
  static const String growthInquiries = '/growth/inquiries';
  static String growthInquiryConvert(String id) => '/growth/inquiries/$id/convert';

  static const String operationsActions = '/operations/actions';
}
