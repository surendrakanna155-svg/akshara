import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import 'school_completion_api_paths.dart';

class SchoolCompletionRemoteDataSource {
  SchoolCompletionRemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) =>
      ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();

  List<Map<String, dynamic>> _items(Response<Map<String, dynamic>> response) =>
      ApiEnvelopeDto.fromJson(response.data ?? const {}).requireListItems();

  Map<String, dynamic> _params(RepositoryQuery query) => {
        if (query.page > 1) 'page': query.page,
        if (query.pageSize != 20) 'pageSize': query.pageSize,
      };

  Future<List<Map<String, dynamic>>> listSubjects({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.subjects,
      queryParameters: _params(query),
    );
    return _items(response);
  }

  Future<Map<String, dynamic>> createSubject({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SchoolCompletionApiPaths.subjects,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> updateSubject({
    required RepositoryQuery query,
    required String subjectId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      SchoolCompletionApiPaths.subject(subjectId),
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> listLessonLogs({
    required RepositoryQuery query,
    String? className,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.lessonLogs,
      queryParameters: {
        ..._params(query),
        if (className != null) 'className': className,
      },
    );
    return _items(response);
  }

  Future<Map<String, dynamic>> createLessonLog({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SchoolCompletionApiPaths.lessonLogs,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> automateTimetables({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SchoolCompletionApiPaths.timetableAutomate,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getBranding({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.branding,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> saveBranding({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      SchoolCompletionApiPaths.branding,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getWhatsAppProvider({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.whatsAppProvider,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> saveWhatsAppProvider({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      SchoolCompletionApiPaths.whatsAppProvider,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> testWhatsAppProvider({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SchoolCompletionApiPaths.whatsAppProviderTest,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> listClassSubjectAssignments({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.classSubjectAssignments,
      queryParameters: {
        ..._params(query),
        if (academicYearId != null) 'academicYearId': academicYearId,
      },
    );
    return _items(response);
  }

  Future<Map<String, dynamic>> createClassSubjectAssignment({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SchoolCompletionApiPaths.classSubjectAssignments,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<void> deleteClassSubjectAssignment({
    required RepositoryQuery query,
    required String assignmentId,
  }) async {
    await _dio.delete<void>(
      SchoolCompletionApiPaths.classSubjectAssignment(assignmentId),
      queryParameters: _params(query),
    );
  }

  Future<List<Map<String, dynamic>>> listTeacherSubjectAssignments({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.teacherSubjectAssignments,
      queryParameters: {
        ..._params(query),
        if (academicYearId != null) 'academicYearId': academicYearId,
      },
    );
    return _items(response);
  }

  Future<Map<String, dynamic>> createTeacherSubjectAssignment({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SchoolCompletionApiPaths.teacherSubjectAssignments,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> getSubjectWorkload({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.subjectWorkload,
      queryParameters: _params(query),
    );
    return _items(response);
  }

  Future<Map<String, dynamic>> getTeacherLessonAnalytics({
    required RepositoryQuery query,
    String? className,
    String? teacherUserId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.teacherLessonAnalytics,
      queryParameters: {
        ..._params(query),
        if (className != null) 'className': className,
        if (teacherUserId != null) 'teacherUserId': teacherUserId,
      },
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> getPrincipalLessonAnalytics({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.principalLessonAnalytics,
      queryParameters: _params(query),
    );
    return _items(response);
  }

  Future<Map<String, dynamic>> getTimetableOptimization({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.timetableOptimize,
      queryParameters: {
        ..._params(query),
        'academicYearId': academicYearId,
      },
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getDeliveryAnalytics({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.deliveryAnalytics,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getPilotDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.pilotDashboard,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> listSubjectTemplates({
    required RepositoryQuery query,
    String? board,
    String? gradeLabel,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.syllabusTemplates,
      queryParameters: {
        ..._params(query),
        if (board != null) 'board': board,
        if (gradeLabel != null) 'gradeLabel': gradeLabel,
      },
    );
    return _items(response);
  }

  Future<Map<String, dynamic>> generateSyllabus({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SchoolCompletionApiPaths.syllabusGenerate,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> cloneSyllabus({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SchoolCompletionApiPaths.syllabusClone,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> listSyllabusChapters({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.syllabusChapters,
      queryParameters: {
        ..._params(query),
        if (academicYearId != null) 'academicYearId': academicYearId,
      },
    );
    return _items(response);
  }

  Future<void> completeTopic({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    await _dio.post<void>(
      SchoolCompletionApiPaths.completeTopic,
      queryParameters: _params(query),
      data: body,
    );
  }

  Future<Map<String, dynamic>> getTeacherProgress({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.teacherProgress,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getPrincipalAcademicProgress({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.principalAcademicProgress,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<List<Map<String, dynamic>>> listRooms({required RepositoryQuery query}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.rooms,
      queryParameters: _params(query),
    );
    return _items(response);
  }

  Future<Map<String, dynamic>> createRoom({
    required RepositoryQuery query,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SchoolCompletionApiPaths.rooms,
      queryParameters: _params(query),
      data: body,
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getTimetableIntelligence({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.timetableIntelligence,
      queryParameters: {
        ..._params(query),
        'academicYearId': academicYearId,
      },
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getCommunicationAnalytics({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.communicationAnalyticsSummary,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getParentActivationDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      SchoolCompletionApiPaths.parentActivationDashboard,
      queryParameters: _params(query),
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> allocateRooms({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      SchoolCompletionApiPaths.roomsAllocate,
      queryParameters: {..._params(query), 'academicYearId': academicYearId},
    );
    return _data(response);
  }
}
