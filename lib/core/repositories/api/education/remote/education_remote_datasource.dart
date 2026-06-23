import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../../../../features/education/education_models.dart';
import '../mapper/education_mapper.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import 'education_api_paths.dart';

class EducationRemoteDataSource {
  EducationRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Map<String, dynamic>>> fetchQuestionBank({
    required RepositoryQuery query,
    String? subjectName,
    String? search,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EducationApiPaths.questionBank,
      queryParameters: {
        ..._queryParams(query),
        if (subjectName != null) 'subjectName': subjectName,
        if (search != null) 'search': search,
      },
    );
    final data = _envelopeData(response);
    final items = data['items'] as List<dynamic>? ?? const [];
    return items.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createQuestionBankItem({
    required RepositoryQuery query,
    required QuestionBankItem item,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EducationApiPaths.questionBank,
      queryParameters: _queryParams(query),
      data: {
        'subjectName': item.subjectName,
        'chapter': item.chapter,
        'topic': item.topic,
        'difficulty': EducationMapper.difficultyToApi(item.difficulty),
        'questionType': EducationMapper.questionTypeToApi(item.questionType),
        'marks': item.marks,
        'questionText': item.questionText,
        if (item.answerText != null) 'answerText': item.answerText,
        'options': item.options,
        'programTrack': EducationMapper.programTrackToApi(item.programTrack),
        if (item.cognitiveLevel != null)
          'cognitiveLevel': EducationMapper.cognitiveLevelToApi(item.cognitiveLevel!),
        if (item.syllabusChapterId != null) 'syllabusChapterId': item.syllabusChapterId,
        if (item.sourceReference != null) 'sourceReference': item.sourceReference,
      },
    );
    return _envelopeData(response);
  }

  Future<List<Map<String, dynamic>>> fetchQuestionPapers({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EducationApiPaths.questionPapers,
      queryParameters: _queryParams(query),
    );
    final data = _envelopeData(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> generateQuestionPaper({
    required RepositoryQuery query,
    required GenerateQuestionPaperRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EducationApiPaths.questionPapersGenerate,
      queryParameters: _queryParams(query),
      data: {
        'academicYearLabel': request.academicYearLabel,
        'className': request.className,
        if (request.sectionName != null) 'sectionName': request.sectionName,
        'subjectName': request.subjectName,
        'chapters': request.chapters,
        'difficulty': EducationMapper.difficultyToApi(request.difficulty),
        'totalMarks': request.totalMarks,
        'examType': EducationMapper.examTypeToApi(request.examType),
        'programTrack': EducationMapper.programTrackToApi(request.programTrack),
        'allowAiGapFill': request.allowAiGapFill,
      },
    );
    return _envelopeData(response);
  }

  Future<Map<String, dynamic>> fetchQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EducationApiPaths.questionPaper(paperId),
      queryParameters: _queryParams(query),
    );
    return _envelopeData(response);
  }

  Future<Map<String, dynamic>> publishQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EducationApiPaths.questionPaperPublish(paperId),
      queryParameters: _queryParams(query),
    );
    return _envelopeData(response);
  }

  Future<Map<String, dynamic>> exportQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EducationApiPaths.questionPaperExport(paperId),
      queryParameters: _queryParams(query),
    );
    return _envelopeData(response);
  }

  Future<Map<String, dynamic>> submitQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EducationApiPaths.questionPaperSubmit(paperId),
      queryParameters: _queryParams(query),
    );
    return _envelopeData(response);
  }

  Future<Map<String, dynamic>> reviewQuestionPaper({
    required RepositoryQuery query,
    required String paperId,
    required String decision,
    String? comments,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EducationApiPaths.questionPaperReview(paperId),
      queryParameters: _queryParams(query),
      data: {
        'decision': decision,
        if (comments != null && comments.trim().isNotEmpty) 'comments': comments.trim(),
      },
    );
    return _envelopeData(response);
  }

  Future<List<Map<String, dynamic>>> fetchPaperReviews({
    required RepositoryQuery query,
    required String paperId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EducationApiPaths.questionPaperReviews(paperId),
      queryParameters: _queryParams(query),
    );
    final data = _envelopeData(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> moderatePaperItem({
    required RepositoryQuery query,
    required String paperId,
    required String itemId,
    required String decision,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EducationApiPaths.questionPaperItemModerate(paperId, itemId),
      queryParameters: _queryParams(query),
      data: {'decision': decision},
    );
    return _envelopeData(response);
  }

  Future<List<Map<String, dynamic>>> fetchHomework({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EducationApiPaths.homework,
      queryParameters: _queryParams(query),
    );
    final data = _envelopeData(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> generateHomework({
    required RepositoryQuery query,
    required GenerateHomeworkRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EducationApiPaths.homeworkGenerate,
      queryParameters: _queryParams(query),
      data: {
        'academicYearLabel': request.academicYearLabel,
        'className': request.className,
        if (request.sectionName != null) 'sectionName': request.sectionName,
        'subjectName': request.subjectName,
        'topic': request.topic,
        'difficulty': EducationMapper.difficultyToApi(request.difficulty),
        'assignmentType': EducationMapper.homeworkTypeToApi(request.assignmentType),
        if (request.dueDate != null) 'dueDate': request.dueDate!.toIso8601String().split('T').first,
      },
    );
    return _envelopeData(response);
  }

  Future<Map<String, dynamic>> publishHomework({
    required RepositoryQuery query,
    required String homeworkId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EducationApiPaths.homeworkPublish(homeworkId),
      queryParameters: _queryParams(query),
    );
    return _envelopeData(response);
  }

  Future<Map<String, dynamic>> exportHomework({
    required RepositoryQuery query,
    required String homeworkId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EducationApiPaths.homeworkExport(homeworkId),
      queryParameters: _queryParams(query),
    );
    return _envelopeData(response);
  }

  Future<List<Map<String, dynamic>>> fetchReportRemarks({
    required RepositoryQuery query,
    String? studentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      EducationApiPaths.reportRemarks,
      queryParameters: {
        ..._queryParams(query),
        if (studentId != null) 'studentId': studentId,
      },
    );
    final data = _envelopeData(response);
    return (data['items'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> generateReportRemark({
    required RepositoryQuery query,
    required GenerateReportRemarkRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EducationApiPaths.reportRemarksGenerate,
      queryParameters: _queryParams(query),
      data: {
        'studentId': request.studentId,
        'academicYearLabel': request.academicYearLabel,
        'remarkType': EducationMapper.remarkTypeToApi(request.remarkType),
        'language': EducationMapper.remarkLanguageToApi(request.language),
        'inputs': request.inputs.toJson(),
      },
    );
    return _envelopeData(response);
  }

  Future<Map<String, dynamic>> updateReportRemark({
    required RepositoryQuery query,
    required String remarkId,
    required String editedRemark,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      EducationApiPaths.reportRemark(remarkId),
      queryParameters: _queryParams(query),
      data: {'editedRemark': editedRemark},
    );
    return _envelopeData(response);
  }

  Future<Map<String, dynamic>> publishReportRemark({
    required RepositoryQuery query,
    required String remarkId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      EducationApiPaths.reportRemarkPublish(remarkId),
      queryParameters: _queryParams(query),
    );
    return _envelopeData(response);
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      if (query.page > 1) 'page': query.page,
      if (query.pageSize != 20) 'pageSize': query.pageSize,
    };
  }

  Map<String, dynamic> _envelopeData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(response.data ?? const {}).requireData();
  }
}
