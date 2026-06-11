import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import 'evolution_api_paths.dart';

class EvolutionRemoteDataSource {
  EvolutionRemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) =>
      ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();

  List<Map<String, dynamic>> _items(Response<Map<String, dynamic>> response) =>
      ApiEnvelopeDto.fromJson(response.data ?? const {}).requireListItems();

  Map<String, dynamic> _params(RepositoryQuery query) => {
        if (query.page > 1) 'page': query.page,
        if (query.pageSize != 20) 'pageSize': query.pageSize,
      };

  Future<Map<String, dynamic>> createSetupWizard({
    required RepositoryQuery query,
    Map<String, dynamic> inputs = const {},
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EvolutionApiPaths.setupWizardSessions,
      queryParameters: _params(query),
      data: {'inputs': inputs},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> advanceSetupWizard({
    required RepositoryQuery query,
    required String sessionId,
    required String step,
    Map<String, dynamic> inputs = const {},
    bool complete = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EvolutionApiPaths.setupWizardAdvance(sessionId),
      queryParameters: _params(query),
      data: {'step': step, 'inputs': inputs, 'complete': complete},
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> listWidgets({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.widgetRegistry,
      queryParameters: _params(query),
    );
    return _items(response);
  }

  Future<Map<String, dynamic>> getDashboardLayout({
    required RepositoryQuery query,
    String dashboardKey = 'default',
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.widgetDashboardLayout,
      queryParameters: {..._params(query), 'dashboardKey': dashboardKey},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> saveDashboardLayout({
    required RepositoryQuery query,
    required List<Map<String, dynamic>> layout,
    String dashboardKey = 'default',
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      EvolutionApiPaths.widgetDashboardLayout,
      queryParameters: _params(query),
      data: {'dashboardKey': dashboardKey, 'layout': layout},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getWidgetData({
    required RepositoryQuery query,
    List<String>? widgetIds,
    bool forceRefresh = false,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.widgetData,
      queryParameters: {
        ..._params(query),
        if (widgetIds != null && widgetIds.isNotEmpty) 'widgetIds': widgetIds.join(','),
        if (forceRefresh) 'refresh': 'true',
      },
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getTeacherAssistantInsights({
    required RepositoryQuery query,
    String? className,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.teacherAssistantInsights,
      queryParameters: {
        ..._params(query),
        if (className != null && className.isNotEmpty) 'className': className,
      },
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> listInterventions({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.teacherInterventions,
      queryParameters: _params(query),
    );
    return _items(response);
  }

  Future<String> createIntervention({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EvolutionApiPaths.teacherInterventions,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response)['id'] as String;
  }

  Future<Map<String, dynamic>> generateParentInsights({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EvolutionApiPaths.parentInsightsGenerate,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> listParentInsights({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.parentInsightsStudent(studentId),
      queryParameters: _params(query),
    );
    return _items(response);
  }

  Future<String?> getParentLanguagePreference({
    required RepositoryQuery query,
    String? studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.parentLanguagePreference,
      queryParameters: {
        ..._params(query),
        if (studentId != null) 'studentId': studentId,
      },
    );
    final data = _data(response);
    return data['language'] as String?;
  }

  Future<void> saveParentLanguagePreference({
    required RepositoryQuery query,
    required String language,
    String? studentId,
  }) async {
    await _dio.put<Map<String, dynamic>>(
      EvolutionApiPaths.parentLanguagePreference,
      queryParameters: _params(query),
      data: {
        'language': language,
        if (studentId != null) 'studentId': studentId,
      },
    );
  }

  Future<Map<String, dynamic>> getPrincipalCommandCenter({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.principalCommandCenter,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> queryPrincipalCommand({
    required RepositoryQuery query,
    required String queryText,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.principalCommandQuery,
      queryParameters: {..._params(query), 'q': queryText},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getGrowthDashboard({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.growthDashboard,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getGrowthFunnel({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.growthFunnel,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> listGrowthCampaigns({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.growthCampaigns,
      queryParameters: _params(query),
    );
    return _items(response);
  }

  Future<List<Map<String, dynamic>>> listGrowthInquiries({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.growthInquiries,
      queryParameters: _params(query),
    );
    return _items(response);
  }

  Future<String> createGrowthCampaign({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EvolutionApiPaths.growthCampaigns,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response)['id'] as String;
  }

  Future<String> createGrowthInquiry({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EvolutionApiPaths.growthInquiries,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response)['id'] as String;
  }

  Future<String> convertGrowthInquiry({
    required RepositoryQuery query,
    required String inquiryId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EvolutionApiPaths.growthInquiryConvert(inquiryId),
      queryParameters: _params(query),
    );
    return _data(response)['leadId'] as String;
  }

  Future<List<Map<String, dynamic>>> getOperationsActions({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EvolutionApiPaths.operationsActions,
      queryParameters: _params(query),
    );
    return _items(response);
  }
}
