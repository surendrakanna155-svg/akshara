import '../../interfaces/evolution_repository.dart';
import '../../repository_query.dart';
import '../../../../features/evolution/evolution_models.dart';
import 'api_evolution_repository.dart';

/// Routes all evolution operations to [ApiEvolutionRepository].
class HybridEvolutionRepository implements EvolutionRepository {
  HybridEvolutionRepository({required ApiEvolutionRepository api}) : _api = api;

  final ApiEvolutionRepository _api;

  @override
  Future<SetupWizardSession> createSetupWizard({
    required RepositoryQuery query,
    Map<String, dynamic> inputs = const {},
  }) =>
      _api.createSetupWizard(query: query, inputs: inputs);

  @override
  Future<SetupWizardSession> advanceSetupWizard({
    required RepositoryQuery query,
    required String sessionId,
    required String step,
    Map<String, dynamic> inputs = const {},
    bool complete = false,
  }) =>
      _api.advanceSetupWizard(
        query: query,
        sessionId: sessionId,
        step: step,
        inputs: inputs,
        complete: complete,
      );

  @override
  Future<List<WidgetDefinition>> listWidgets({required RepositoryQuery query}) =>
      _api.listWidgets(query: query);

  @override
  Future<List<DashboardWidgetPlacement>> getDashboardLayout({
    required RepositoryQuery query,
    String dashboardKey = 'default',
  }) =>
      _api.getDashboardLayout(query: query, dashboardKey: dashboardKey);

  @override
  Future<List<DashboardWidgetPlacement>> saveDashboardLayout({
    required RepositoryQuery query,
    required List<DashboardWidgetPlacement> layout,
    String dashboardKey = 'default',
  }) =>
      _api.saveDashboardLayout(query: query, layout: layout, dashboardKey: dashboardKey);

  @override
  Future<Map<String, WidgetLiveData>> getWidgetData({
    required RepositoryQuery query,
    List<String>? widgetIds,
    bool forceRefresh = false,
  }) =>
      _api.getWidgetData(query: query, widgetIds: widgetIds, forceRefresh: forceRefresh);

  @override
  Future<TeacherAssistantInsights> getTeacherAssistantInsights({
    required RepositoryQuery query,
    String? className,
  }) =>
      _api.getTeacherAssistantInsights(query: query, className: className);

  @override
  Future<List<TeacherIntervention>> listInterventions({required RepositoryQuery query}) =>
      _api.listInterventions(query: query);

  @override
  Future<String> createIntervention({
    required RepositoryQuery query,
    required String studentId,
    required String interventionType,
    required String title,
    String? notes,
    String priority = 'medium',
  }) =>
      _api.createIntervention(
        query: query,
        studentId: studentId,
        interventionType: interventionType,
        title: title,
        notes: notes,
        priority: priority,
      );

  @override
  Future<ParentInsightSnapshot> generateParentInsights({
    required RepositoryQuery query,
    required String studentId,
    String period = 'weekly',
    String language = 'english',
  }) =>
      _api.generateParentInsights(
        query: query,
        studentId: studentId,
        period: period,
        language: language,
      );

  @override
  Future<List<ParentInsightSnapshot>> listParentInsights({
    required RepositoryQuery query,
    required String studentId,
  }) =>
      _api.listParentInsights(query: query, studentId: studentId);

  @override
  Future<String?> getParentLanguagePreference({
    required RepositoryQuery query,
    String? studentId,
  }) =>
      _api.getParentLanguagePreference(query: query, studentId: studentId);

  @override
  Future<void> saveParentLanguagePreference({
    required RepositoryQuery query,
    required String language,
    String? studentId,
  }) =>
      _api.saveParentLanguagePreference(
        query: query,
        language: language,
        studentId: studentId,
      );

  @override
  Future<PrincipalCommandCenter> getPrincipalCommandCenter({
    required RepositoryQuery query,
  }) =>
      _api.getPrincipalCommandCenter(query: query);

  @override
  Future<Map<String, dynamic>> queryPrincipalCommand({
    required RepositoryQuery query,
    required String queryText,
  }) =>
      _api.queryPrincipalCommand(query: query, queryText: queryText);

  @override
  Future<GrowthDashboard> getGrowthDashboard({required RepositoryQuery query}) =>
      _api.getGrowthDashboard(query: query);

  @override
  Future<GrowthFunnel> getGrowthFunnel({required RepositoryQuery query}) =>
      _api.getGrowthFunnel(query: query);

  @override
  Future<List<GrowthCampaign>> listGrowthCampaigns({required RepositoryQuery query}) =>
      _api.listGrowthCampaigns(query: query);

  @override
  Future<List<GrowthInquiry>> listGrowthInquiries({required RepositoryQuery query}) =>
      _api.listGrowthInquiries(query: query);

  @override
  Future<String> createGrowthCampaign({
    required RepositoryQuery query,
    required String name,
    required String channel,
    double? budgetInr,
  }) =>
      _api.createGrowthCampaign(
        query: query,
        name: name,
        channel: channel,
        budgetInr: budgetInr,
      );

  @override
  Future<String> createGrowthInquiry({
    required RepositoryQuery query,
    required String parentName,
    required String source,
    String? phone,
    String? gradeInterest,
    String? campaignId,
  }) =>
      _api.createGrowthInquiry(
        query: query,
        parentName: parentName,
        source: source,
        phone: phone,
        gradeInterest: gradeInterest,
        campaignId: campaignId,
      );

  @override
  Future<String> convertGrowthInquiry({
    required RepositoryQuery query,
    required String inquiryId,
  }) =>
      _api.convertGrowthInquiry(query: query, inquiryId: inquiryId);

  @override
  Future<List<OperationsActionItem>> getOperationsActions({
    required RepositoryQuery query,
  }) =>
      _api.getOperationsActions(query: query);
}
