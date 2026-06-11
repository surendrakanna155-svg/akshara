import '../../../features/evolution/evolution_models.dart';
import '../repository_query.dart';

abstract class EvolutionRepository {
  Future<SetupWizardSession> createSetupWizard({
    required RepositoryQuery query,
    Map<String, dynamic> inputs = const {},
  });

  Future<SetupWizardSession> advanceSetupWizard({
    required RepositoryQuery query,
    required String sessionId,
    required String step,
    Map<String, dynamic> inputs = const {},
    bool complete = false,
  });

  Future<List<WidgetDefinition>> listWidgets({required RepositoryQuery query});

  Future<List<DashboardWidgetPlacement>> getDashboardLayout({
    required RepositoryQuery query,
    String dashboardKey = 'default',
  });

  Future<List<DashboardWidgetPlacement>> saveDashboardLayout({
    required RepositoryQuery query,
    required List<DashboardWidgetPlacement> layout,
    String dashboardKey = 'default',
  });

  Future<Map<String, WidgetLiveData>> getWidgetData({
    required RepositoryQuery query,
    List<String>? widgetIds,
    bool forceRefresh = false,
  });

  Future<TeacherAssistantInsights> getTeacherAssistantInsights({
    required RepositoryQuery query,
    String? className,
  });

  Future<List<TeacherIntervention>> listInterventions({required RepositoryQuery query});

  Future<String> createIntervention({
    required RepositoryQuery query,
    required String studentId,
    required String interventionType,
    required String title,
    String? notes,
    String priority = 'medium',
  });

  Future<ParentInsightSnapshot> generateParentInsights({
    required RepositoryQuery query,
    required String studentId,
    String period = 'weekly',
    String language = 'english',
  });

  Future<List<ParentInsightSnapshot>> listParentInsights({
    required RepositoryQuery query,
    required String studentId,
  });

  Future<String?> getParentLanguagePreference({
    required RepositoryQuery query,
    String? studentId,
  });

  Future<void> saveParentLanguagePreference({
    required RepositoryQuery query,
    required String language,
    String? studentId,
  });

  Future<PrincipalCommandCenter> getPrincipalCommandCenter({
    required RepositoryQuery query,
  });

  Future<Map<String, dynamic>> queryPrincipalCommand({
    required RepositoryQuery query,
    required String queryText,
  });

  Future<GrowthDashboard> getGrowthDashboard({required RepositoryQuery query});

  Future<GrowthFunnel> getGrowthFunnel({required RepositoryQuery query});

  Future<List<GrowthCampaign>> listGrowthCampaigns({required RepositoryQuery query});

  Future<List<GrowthInquiry>> listGrowthInquiries({required RepositoryQuery query});

  Future<String> createGrowthCampaign({
    required RepositoryQuery query,
    required String name,
    required String channel,
    double? budgetInr,
  });

  Future<String> createGrowthInquiry({
    required RepositoryQuery query,
    required String parentName,
    required String source,
    String? phone,
    String? gradeInterest,
    String? campaignId,
  });

  Future<String> convertGrowthInquiry({
    required RepositoryQuery query,
    required String inquiryId,
  });

  Future<List<OperationsActionItem>> getOperationsActions({
    required RepositoryQuery query,
  });
}
