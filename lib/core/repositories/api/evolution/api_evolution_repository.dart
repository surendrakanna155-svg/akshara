import '../../interfaces/evolution_repository.dart';
import '../../repository_query.dart';
import '../../../../features/evolution/evolution_models.dart';
import 'mapper/evolution_mapper.dart';
import 'remote/evolution_remote_datasource.dart';

class ApiEvolutionRepository implements EvolutionRepository {
  ApiEvolutionRepository({
    required EvolutionRemoteDataSource remote,
    EvolutionMapper mapper = const EvolutionMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final EvolutionRemoteDataSource _remote;
  final EvolutionMapper _mapper;

  @override
  Future<SetupWizardSession> createSetupWizard({
    required RepositoryQuery query,
    Map<String, dynamic> inputs = const {},
  }) async {
    final dto = await _remote.createSetupWizard(query: query, inputs: inputs);
    return _mapper.toSetupWizardSession(dto);
  }

  @override
  Future<SetupWizardSession> advanceSetupWizard({
    required RepositoryQuery query,
    required String sessionId,
    required String step,
    Map<String, dynamic> inputs = const {},
    bool complete = false,
  }) async {
    final dto = await _remote.advanceSetupWizard(
      query: query,
      sessionId: sessionId,
      step: step,
      inputs: inputs,
      complete: complete,
    );
    return _mapper.toSetupWizardSession({...dto, 'id': sessionId});
  }

  @override
  Future<List<WidgetDefinition>> listWidgets({required RepositoryQuery query}) async {
    final items = await _remote.listWidgets(query: query);
    return items.map(_mapper.toWidgetDefinition).toList();
  }

  @override
  Future<List<DashboardWidgetPlacement>> getDashboardLayout({
    required RepositoryQuery query,
    String dashboardKey = 'default',
  }) async {
    final dto = await _remote.getDashboardLayout(query: query, dashboardKey: dashboardKey);
    return _mapper.toDashboardLayout(dto);
  }

  @override
  Future<List<DashboardWidgetPlacement>> saveDashboardLayout({
    required RepositoryQuery query,
    required List<DashboardWidgetPlacement> layout,
    String dashboardKey = 'default',
  }) async {
    final dto = await _remote.saveDashboardLayout(
      query: query,
      dashboardKey: dashboardKey,
      layout: [
        for (final item in layout)
          {
            'widgetId': item.widgetId,
            'order': item.order,
            'visible': item.visible,
            'width': item.width,
            'height': item.height,
          },
      ],
    );
    return _mapper.toDashboardLayout(dto);
  }

  @override
  Future<Map<String, WidgetLiveData>> getWidgetData({
    required RepositoryQuery query,
    List<String>? widgetIds,
    bool forceRefresh = false,
  }) async {
    final dto = await _remote.getWidgetData(
      query: query,
      widgetIds: widgetIds,
      forceRefresh: forceRefresh,
    );
    return _mapper.toWidgetDataMap(dto);
  }

  @override
  Future<TeacherAssistantInsights> getTeacherAssistantInsights({
    required RepositoryQuery query,
    String? className,
  }) async {
    final dto = await _remote.getTeacherAssistantInsights(query: query, className: className);
    return _mapper.toTeacherAssistantInsights(dto);
  }

  @override
  Future<List<TeacherIntervention>> listInterventions({required RepositoryQuery query}) async {
    final items = await _remote.listInterventions(query: query);
    return items.map(_mapper.toTeacherIntervention).toList();
  }

  @override
  Future<String> createIntervention({
    required RepositoryQuery query,
    required String studentId,
    required String interventionType,
    required String title,
    String? notes,
    String priority = 'medium',
  }) async {
    return _remote.createIntervention(
      query: query,
      body: {
        'studentId': studentId,
        'interventionType': interventionType,
        'title': title,
        if (notes != null) 'notes': notes,
        'priority': priority,
      },
    );
  }

  @override
  Future<ParentInsightSnapshot> generateParentInsights({
    required RepositoryQuery query,
    required String studentId,
    String period = 'weekly',
    String language = 'english',
  }) async {
    final dto = await _remote.generateParentInsights(
      query: query,
      body: {'studentId': studentId, 'period': period, 'language': language},
    );
    return _mapper.toParentInsightSnapshot(dto);
  }

  @override
  Future<List<ParentInsightSnapshot>> listParentInsights({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final items = await _remote.listParentInsights(query: query, studentId: studentId);
    return items.map(_mapper.toParentInsightSnapshot).toList();
  }

  @override
  Future<String?> getParentLanguagePreference({
    required RepositoryQuery query,
    String? studentId,
  }) =>
      _remote.getParentLanguagePreference(query: query, studentId: studentId);

  @override
  Future<void> saveParentLanguagePreference({
    required RepositoryQuery query,
    required String language,
    String? studentId,
  }) =>
      _remote.saveParentLanguagePreference(
        query: query,
        language: language,
        studentId: studentId,
      );

  @override
  Future<PrincipalCommandCenter> getPrincipalCommandCenter({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.getPrincipalCommandCenter(query: query);
    return _mapper.toPrincipalCommandCenter(dto);
  }

  @override
  Future<Map<String, dynamic>> queryPrincipalCommand({
    required RepositoryQuery query,
    required String queryText,
  }) =>
      _remote.queryPrincipalCommand(query: query, queryText: queryText);

  @override
  Future<GrowthDashboard> getGrowthDashboard({required RepositoryQuery query}) async {
    final dto = await _remote.getGrowthDashboard(query: query);
    return _mapper.toGrowthDashboard(dto);
  }

  @override
  Future<GrowthFunnel> getGrowthFunnel({required RepositoryQuery query}) async {
    final dto = await _remote.getGrowthFunnel(query: query);
    return _mapper.toGrowthFunnel(dto);
  }

  @override
  Future<List<GrowthCampaign>> listGrowthCampaigns({required RepositoryQuery query}) async {
    final items = await _remote.listGrowthCampaigns(query: query);
    return items.map(_mapper.toGrowthCampaign).toList();
  }

  @override
  Future<List<GrowthInquiry>> listGrowthInquiries({required RepositoryQuery query}) async {
    final items = await _remote.listGrowthInquiries(query: query);
    return items.map(_mapper.toGrowthInquiry).toList();
  }

  @override
  Future<String> createGrowthCampaign({
    required RepositoryQuery query,
    required String name,
    required String channel,
    double? budgetInr,
  }) =>
      _remote.createGrowthCampaign(
        query: query,
        body: {
          'name': name,
          'channel': channel,
          if (budgetInr != null) 'budgetInr': budgetInr,
        },
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
      _remote.createGrowthInquiry(
        query: query,
        body: {
          'parentName': parentName,
          'source': source,
          if (phone != null) 'phone': phone,
          if (gradeInterest != null) 'gradeInterest': gradeInterest,
          if (campaignId != null) 'campaignId': campaignId,
        },
      );

  @override
  Future<String> convertGrowthInquiry({
    required RepositoryQuery query,
    required String inquiryId,
  }) =>
      _remote.convertGrowthInquiry(query: query, inquiryId: inquiryId);

  @override
  Future<List<OperationsActionItem>> getOperationsActions({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.getOperationsActions(query: query);
    return items.map(_mapper.toOperationsAction).toList();
  }
}
