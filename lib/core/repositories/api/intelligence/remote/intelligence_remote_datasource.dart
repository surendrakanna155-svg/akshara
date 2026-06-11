import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../../../../../features/intelligence/intelligence_models.dart';
import '../mapper/intelligence_mapper.dart';
import 'intelligence_api_paths.dart';

class IntelligenceRemoteDataSource {
  IntelligenceRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetchStudentRisks({
    required RepositoryQuery query,
    String? className,
    StudentRiskLevel? riskLevel,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.studentRisks,
      queryParameters: {
        ..._params(query),
        if (className != null) 'className': className,
        if (riskLevel != null) 'riskLevel': riskLevel.name,
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> computeStudentRisks({
    required RepositoryQuery query,
    String? academicYearLabel,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      IntelligenceApiPaths.studentRisksCompute,
      queryParameters: _params(query),
      data: {if (academicYearLabel != null) 'academicYearLabel': academicYearLabel},
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchClassRisks({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.classRisks,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> generateCommunication({
    required RepositoryQuery query,
    required CommunicationScenario scenario,
    String? studentName,
    String? className,
    String? customNote,
    List<IntelLanguage> languages = const [IntelLanguage.english],
    IntelLanguage? parentPreferredLanguage,
    String? feeAmount,
    String? dueDate,
    String? examName,
    String? meetingDate,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      IntelligenceApiPaths.communicationGenerate,
      queryParameters: _params(query),
      data: {
        'scenario': IntelligenceMapper.scenarioToApi(scenario),
        if (studentName != null) 'studentName': studentName,
        if (className != null) 'className': className,
        if (customNote != null) 'customNote': customNote,
        'languages': languages.map(IntelligenceMapper.languageToApi).toList(),
        if (parentPreferredLanguage != null)
          'parentPreferredLanguage': IntelligenceMapper.languageToApi(parentPreferredLanguage),
        if (feeAmount != null) 'feeAmount': feeAmount,
        if (dueDate != null) 'dueDate': dueDate,
        if (examName != null) 'examName': examName,
        if (meetingDate != null) 'meetingDate': meetingDate,
      },
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> generateParentGuidance({
    required RepositoryQuery query,
    required String studentId,
    required GuidanceMode mode,
    IntelLanguage language = IntelLanguage.english,
    Map<String, dynamic> inputs = const {},
    bool publish = true,
    bool autoFillFromRisk = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      IntelligenceApiPaths.parentGuidanceGenerate,
      queryParameters: _params(query),
      data: {
        'studentId': studentId,
        'mode': IntelligenceMapper.modeToApi(mode),
        'language': IntelligenceMapper.languageToApi(language),
        'inputs': inputs,
        'publish': publish,
        'autoFillFromRisk': autoFillFromRisk,
      },
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchPrincipalQuery({
    required RepositoryQuery query,
    required String queryText,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.principalQuery,
      queryParameters: {..._params(query), 'q': queryText},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchTeacherSuccessCenter({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.teacherSuccessCenter,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchPrincipalCenter({
    required RepositoryQuery query,
    String period = 'monthly',
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.principalCenter,
      queryParameters: {..._params(query), 'period': period},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchStudentSuccessDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.studentSuccessDashboard,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchStudentSuccessPredictions({
    required RepositoryQuery query,
    String? className,
    int? minDropoutRisk,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.studentSuccessPredictions,
      queryParameters: {
        ..._params(query),
        if (className != null) 'className': className,
        if (minDropoutRisk != null) 'minDropoutRisk': minDropoutRisk,
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> computeStudentSuccess({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      IntelligenceApiPaths.studentSuccessCompute,
      queryParameters: _params(query),
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchStudentSuccess({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.studentSuccessStudent(studentId),
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchStudentImprovements({
    required RepositoryQuery query,
    String? className,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.studentSuccessImprovements,
      queryParameters: {
        ..._params(query),
        if (className != null) 'className': className,
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchInterventionEffectiveness({
    required RepositoryQuery query,
    String? studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.studentSuccessInterventions,
      queryParameters: {
        ..._params(query),
        if (studentId != null) 'studentId': studentId,
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchExamAnalytics({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
    String? examType,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.examAnalytics,
      queryParameters: {
        ..._params(query),
        if (className != null) 'className': className,
        if (subjectName != null) 'subjectName': subjectName,
        if (examType != null) 'examType': examType,
      },
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchSubjectPerformance({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.examSubjectPerformance,
      queryParameters: {
        ..._params(query),
        if (className != null) 'className': className,
        if (subjectName != null) 'subjectName': subjectName,
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchWeakChapters({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.examWeakChapters,
      queryParameters: {
        ..._params(query),
        if (className != null) 'className': className,
        if (subjectName != null) 'subjectName': subjectName,
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchResultIntelligence({
    required RepositoryQuery query,
    String? className,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.examResultIntelligence,
      queryParameters: {
        ..._params(query),
        if (className != null) 'className': className,
      },
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchAcademicForecast({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.examForecast,
      queryParameters: {
        ..._params(query),
        if (className != null) 'className': className,
        if (subjectName != null) 'subjectName': subjectName,
      },
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> fetchRankMovement({
    required RepositoryQuery query,
    String? className,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.examRankMovement,
      queryParameters: {
        ..._params(query),
        if (className != null) 'className': className,
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchLessonEffectivenessScores({
    required RepositoryQuery query,
    String? teacherUserId,
    String? className,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.teacherEffectivenessLessonScores,
      queryParameters: {
        ..._params(query),
        if (teacherUserId != null) 'teacherUserId': teacherUserId,
        if (className != null) 'className': className,
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchTopicMasteryAnalytics({
    required RepositoryQuery query,
    String? teacherUserId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.teacherEffectivenessTopicMastery,
      queryParameters: {
        ..._params(query),
        if (teacherUserId != null) 'teacherUserId': teacherUserId,
      },
    );
    final data = _data(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchTeacherPerformanceInsights({
    required RepositoryQuery query,
    String? teacherUserId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.teacherEffectivenessPerformance,
      queryParameters: {
        ..._params(query),
        if (teacherUserId != null) 'teacherUserId': teacherUserId,
      },
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> fetchTeacherPlanningCenter({
    required RepositoryQuery query,
    String? teacherUserId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      IntelligenceApiPaths.teacherEffectivenessPlanningCenter,
      queryParameters: {
        ..._params(query),
        if (teacherUserId != null) 'teacherUserId': teacherUserId,
      },
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> generateParentMeetingSummary({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      IntelligenceApiPaths.teacherEffectivenessParentMeetingSummary,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Map<String, dynamic> _params(RepositoryQuery query) => {
        if (query.page > 1) 'page': query.page,
        if (query.pageSize != 20) 'pageSize': query.pageSize,
      };

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();
  }
}
