import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../../../../exams/exam_administration_requests.dart';
import '../../../../exams/exam_administration_store.dart';
import '../../../../exams/exam_remark.dart';
import '../../../../reliability/model/mutation_outcome.dart';
import '../../../../reliability/policy/operation_policy_registry.dart';
import '../../../../reliability/reliable_datasource_write.dart';
import '../../../../reliability/reliable_writer.dart';
import '../mapper/exam_mapper.dart';
import 'exam_api_paths.dart';

/// Dio-backed remote data source for exam administration API (F4).
///
/// A per-cell mark save (`updateMark`) routes through the Data Reliability
/// Platform's [ReliableWriter] when injected, so a teacher entering a grid of
/// marks on a flaky network never loses an entry: each save is queued offline
/// and replayed exactly-once (idempotency key), returning the entered value
/// optimistically while pending. Without a writer it falls back to a direct PATCH.
class ExamRemoteDataSource {
  ExamRemoteDataSource(
    this._dio, {
    ExamMapper mapper = const ExamMapper(),
    ReliableWriter? reliableWriter,
  })  : _mapper = mapper,
        _reliable = reliableWriter;

  final Dio _dio;
  final ExamMapper _mapper;
  final ReliableWriter? _reliable;

  Future<List<ExamSession>> fetchExams({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ExamApiPaths.base,
      queryParameters: _queryParams(query),
    );
    return _mapper.toSessions(_listData(_responseMap(response)));
  }

  Future<ExamSession?> fetchExam({
    required RepositoryQuery query,
    required String examId,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ExamApiPaths.exam(examId),
        queryParameters: _queryParams(query),
      );
      final data = ApiEnvelopeDto.fromJson(_responseMap(response)).data;
      if (data == null) return null;
      return _mapper.toSession(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<ExamSession> createExam({
    required RepositoryQuery query,
    required CreateExamAdministrationRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ExamApiPaths.base,
      queryParameters: _queryParams(query),
      data: _mapper.createExamBody(request),
    );
    return _mapper.toSession(_requireData(response));
  }

  Future<ExamSession> scheduleExam({
    required RepositoryQuery query,
    required String examId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ExamApiPaths.schedule(examId),
      queryParameters: _queryParams(query),
    );
    return _mapper.toSession(_requireData(response));
  }

  Future<ExamSession> openMarksEntry({
    required RepositoryQuery query,
    required String examId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ExamApiPaths.openMarks(examId),
      queryParameters: _queryParams(query),
    );
    return _mapper.toSession(_requireData(response));
  }

  Future<ExamSession> processResults({
    required RepositoryQuery query,
    required String examId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ExamApiPaths.process(examId),
      queryParameters: _queryParams(query),
    );
    return _mapper.toSession(_requireData(response));
  }

  Future<ExamSession> verifyCoordinatorResults({
    required RepositoryQuery query,
    required String examId,
    required String verifiedBy,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ExamApiPaths.verifyCoordinator(examId),
      queryParameters: _queryParams(query),
      data: {'verifiedBy': verifiedBy},
    );
    return _mapper.toSession(_requireData(response));
  }

  Future<int> publishResults({
    required RepositoryQuery query,
    required String examId,
    String? approvalId,
    bool requireApproval = true,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ExamApiPaths.publish(examId),
      queryParameters: _queryParams(query),
      data: {
        if (approvalId != null) 'approvalId': approvalId,
        'requireApproval': requireApproval,
      },
    );
    final data = _requireData(response);
    return (data['publishedCount'] as num?)?.toInt() ?? 0;
  }

  Future<List<ExamMarkRecord>> fetchMarks({
    required RepositoryQuery query,
    required String examId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ExamApiPaths.marks(examId),
      queryParameters: _queryParams(query),
    );
    return _mapper.toMarks(_listData(_responseMap(response)));
  }

  Future<ExamMarkRecord> updateMark({
    required RepositoryQuery query,
    required UpdateExamMarkRequest request,
  }) async {
    // EXM-D6 — a non-present student has no marks: send null (the server forces
    // null too) so the wire payload matches the persisted state.
    final bool isPresent = request.status.isPresent;
    final Map<String, dynamic> body = {
      'marksObtained': isPresent ? request.marksObtained : null,
      'status': request.status.wire,
    };
    final ReliableWriter? reliable = _reliable;
    if (reliable == null) {
      final response = await _dio.patch<Map<String, dynamic>>(
        ExamApiPaths.markEntry(request.markEntryId),
        queryParameters: _queryParams(query),
        data: body,
      );
      return _mapper.toMark(_requireData(response));
    }
    final MutationOutcome outcome = await reliable.runWrite(
      type: OperationTypes.saveExamMarksDraft,
      method: 'PATCH',
      path: ExamApiPaths.markEntry(request.markEntryId),
      body: body,
      scope: _queryParams(query),
      entityRef: 'examMark:${request.markEntryId}',
    );
    final ResolvedWrite resolved = resolveWriteOutcome(
      outcome,
      optimistic: () => <String, dynamic>{
        'id': request.markEntryId,
        'marksObtained': isPresent ? request.marksObtained : null,
        'status': request.status.wire,
      },
    );
    return _mapper.toMark(resolved.data);
  }

  /// EXM-1 — fast bulk marks save for one exam. Partial success: published rows
  /// are reported in `failed` and never overwritten. Sent as a single POST so a
  /// full grid of dirty rows lands in one round-trip.
  Future<BulkExamMarkSaveResult> bulkUpdateMarks({
    required RepositoryQuery query,
    required BulkUpdateExamMarksRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ExamApiPaths.marksBatch(request.examId),
      queryParameters: _queryParams(query),
      data: _mapper.bulkMarksBody(request),
    );
    return _mapper.toBulkResult(_requireData(response));
  }

  /// EXM-2 — marks-entry progress for the school (exams awaiting marks).
  Future<List<MarksEntryProgress>> fetchMarksEntryProgress({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ExamApiPaths.progress,
      queryParameters: _queryParams(query),
    );
    return _mapper.toProgressList(_listData(_responseMap(response)));
  }

  Future<List<PublishedExamResult>> fetchPublishedResultsForStudent({
    required RepositoryQuery query,
    required String sisStudentId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ExamApiPaths.publishedResults(sisStudentId),
      queryParameters: _queryParams(query),
    );
    return _mapper.toPublishedResults(_listData(_responseMap(response)));
  }

  Future<ExamRemark> upsertRemark({
    required RepositoryQuery query,
    required String examId,
    required String sisStudentId,
    required String text,
    required String authorName,
    required ExamRemarkAuthorRole authorRole,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      ExamApiPaths.remark(examId, sisStudentId),
      queryParameters: _queryParams(query),
      data: {
        'text': text,
        'authorName': authorName,
        'authorRole': authorRole.name,
      },
    );
    return ExamRemark.fromJson(_requireData(response));
  }

  Future<List<ExamRemark>> fetchRemarks({
    required RepositoryQuery query,
    required String examId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ExamApiPaths.remarks(examId),
      queryParameters: _queryParams(query),
    );
    return [
      for (final raw in _listData(_responseMap(response)))
        if (raw is Map)
          ExamRemark.fromJson(Map<String, dynamic>.from(raw)),
    ];
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) => {
        'tenantId': query.tenantId,
        'schoolId': query.schoolId,
      };

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }

  Map<String, dynamic> _requireData(Response<Map<String, dynamic>> response) {
    final envelope = ApiEnvelopeDto.fromJson(_responseMap(response));
    return envelope.data ?? const {};
  }

  List<dynamic> _listData(Map<String, dynamic> body) {
    final dataField = body['data'];
    if (dataField is List<dynamic>) return dataField;
    if (dataField is Map<String, dynamic>) return _items(dataField);
    return const [];
  }

  List<dynamic> _items(Map<String, dynamic> data) {
    final items = data['items'];
    if (items is List<dynamic>) return items;
    if (data.isEmpty) return const [];
    if (data.containsKey('id')) return [data];
    return const [];
  }
}
