import 'package:dio/dio.dart';

import '../../../repository_query.dart';
import '../../../../../features/library/library_models.dart';
import '../../../../../features/library/library_requests.dart';
import '../../admissions/dto/api_envelope_dto.dart';
import '../dto/library_enum_codec.dart';
import '../dto/library_responses_dto.dart';
import 'library_api_paths.dart';

/// Dio-backed remote data source for Library.
class LibraryRemoteDataSource {
  LibraryRemoteDataSource(this._dio);

  final Dio _dio;

  Future<LibraryDashboardDto> fetchDashboard({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      LibraryApiPaths.dashboard,
      queryParameters: _queryParams(query),
    );
    return LibraryDashboardDto.fromJson(_responseMap(response));
  }

  Future<LibraryCatalogResponseDto> fetchCatalog({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      LibraryApiPaths.catalog,
      queryParameters: _queryParams(query),
    );
    return LibraryCatalogResponseDto.fromJson(_responseMap(response));
  }

  Future<LibraryIssuesResponseDto> fetchIssues({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      LibraryApiPaths.issues,
      queryParameters: _queryParams(query),
    );
    return LibraryIssuesResponseDto.fromJson(_responseMap(response));
  }

  Future<LibraryReturnsResponseDto> fetchReturns({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      LibraryApiPaths.returns,
      queryParameters: _queryParams(query),
    );
    return LibraryReturnsResponseDto.fromJson(_responseMap(response));
  }

  Future<LibraryMembersResponseDto> fetchMembers({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      LibraryApiPaths.members,
      queryParameters: _queryParams(query),
    );
    return LibraryMembersResponseDto.fromJson(_responseMap(response));
  }

  Future<LibraryFinesResponseDto> fetchFines({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      LibraryApiPaths.fines,
      queryParameters: _queryParams(query),
    );
    return LibraryFinesResponseDto.fromJson(_responseMap(response));
  }

  Future<LibraryDigitalResourcesResponseDto> fetchDigitalResources({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      LibraryApiPaths.digitalResources,
      queryParameters: _queryParams(query),
    );
    return LibraryDigitalResourcesResponseDto.fromJson(_responseMap(response));
  }

  Future<LibraryReportsResponseDto> fetchReports({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      LibraryApiPaths.reports,
      queryParameters: _queryParams(query),
    );
    return LibraryReportsResponseDto.fromJson(_responseMap(response));
  }

  Future<LibraryIssueRecordDto> issueBook({
    required RepositoryQuery query,
    required IssueLibraryBookRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      LibraryApiPaths.issues,
      queryParameters: _queryParams(query),
      data: {'isbn': request.isbn, 'memberId': request.memberId},
    );
    return LibraryIssueRecordDto(raw: _writeData(response));
  }

  Future<LibraryReturnRecordDto> returnBook({
    required RepositoryQuery query,
    required ReturnLibraryBookRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      LibraryApiPaths.returns,
      queryParameters: _queryParams(query),
      data: {
        'issueId': request.issueId,
        'condition': LibraryEnumCodec.returnConditionToApi(request.condition),
      },
    );
    return LibraryReturnRecordDto(raw: _writeData(response));
  }

  Future<LibraryBookDto> addBook({
    required RepositoryQuery query,
    required AddLibraryBookRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      LibraryApiPaths.catalog,
      queryParameters: _queryParams(query),
      data: {
        'isbn': request.isbn,
        'title': request.title,
        'author': request.author,
        'category': request.category,
        'totalCopies': request.totalCopies,
        'shelf': request.shelf,
      },
    );
    return LibraryBookDto(raw: _writeData(response));
  }

  Future<Map<String, dynamic>> addDigitalResource({
    required RepositoryQuery query,
    required AddLibraryResourceRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      LibraryApiPaths.digitalResources,
      queryParameters: _queryParams(query),
      data: {
        'title': request.title,
        'type': LibraryEnumCodec.resourceTypeToApi(request.type),
        'classAccess': request.classAccess,
        'resourceUrl': request.resourceUrl,
        'studentAppVisible': request.studentAppVisible,
        'teacherAppVisible': request.teacherAppVisible,
      },
    );
    return _writeData(response);
  }

  Future<LibraryMemberDto> enrollMember({
    required RepositoryQuery query,
    required EnrollLibraryMemberRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      LibraryApiPaths.members,
      queryParameters: _queryParams(query),
      data: {
        'name': request.name,
        'memberType': LibraryEnumCodec.memberTypeToApi(request.memberType),
        'identifier': request.identifier,
        'classOrDepartment': request.classOrDepartment,
        if (request.sisStudentId != null) 'sisStudentId': request.sisStudentId,
      },
    );
    return LibraryMemberDto(raw: _writeData(response));
  }

  Future<Map<String, dynamic>> waiveFine({
    required RepositoryQuery query,
    required WaiveLibraryFineRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      LibraryApiPaths.waiveFine(request.fineId),
      queryParameters: _queryParams(query),
    );
    return _writeData(response);
  }

  /// LIB-2 — PUT /library/catalog/:id (body carries isbn; server keeps it unique).
  Future<LibraryBookDto> updateBook({
    required RepositoryQuery query,
    required String bookId,
    required UpdateLibraryBookRequest request,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      LibraryApiPaths.catalogBook(bookId),
      queryParameters: _queryParams(query),
      data: {
        'isbn': request.isbn,
        'title': request.title,
        'author': request.author,
        'category': request.category,
        'totalCopies': request.totalCopies,
        'shelf': request.shelf,
      },
    );
    return LibraryBookDto(raw: _writeData(response));
  }

  /// LIB-2 — DELETE /library/catalog/:id (rejected while a copy is on loan).
  Future<void> deleteBook({
    required RepositoryQuery query,
    required String bookId,
  }) async {
    await _dio.delete<Map<String, dynamic>>(
      LibraryApiPaths.catalogBook(bookId),
      queryParameters: _queryParams(query),
    );
  }

  /// LIB-2 — POST /library/catalog/import with `{rows:[…]}`.
  Future<ImportResultRaw> bulkImportBooks({
    required RepositoryQuery query,
    required BulkImportBooksRequest request,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      LibraryApiPaths.catalogImport,
      queryParameters: _queryParams(query),
      data: {'rows': [for (final row in request.rows) row.toJson()]},
    );
    return ImportResultRaw(raw: _writeData(response));
  }

  /// LIB-4 — POST /library/issues/:id/renew (returns the updated loan).
  Future<LibraryIssueRecordDto> renewLoan({
    required RepositoryQuery query,
    required String issueId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      LibraryApiPaths.renewLoan(issueId),
      queryParameters: _queryParams(query),
    );
    return LibraryIssueRecordDto(raw: _writeData(response));
  }

  /// LIB-1 — GET /library/overdue (open overdue loans + accrued fines).
  Future<LibraryOverdueResponseDto> fetchOverdue({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      LibraryApiPaths.overdue,
      queryParameters: _queryParams(query),
    );
    return LibraryOverdueResponseDto.fromJson(_responseMap(response));
  }

  /// LIB-5 — POST /library/reminders/overdue (returns `{recipientCount}`).
  Future<int> sendOverdueReminder({required RepositoryQuery query}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      LibraryApiPaths.overdueReminders,
      queryParameters: _queryParams(query),
    );
    final data = _writeData(response);
    final count = data['recipientCount'];
    if (count is int) return count;
    if (count is num) return count.toInt();
    return int.tryParse('${count ?? 0}') ?? 0;
  }

  /// LIB-D1 — GET /library/settings.
  Future<LibrarySettingsDto> fetchSettings({
    required RepositoryQuery query,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      LibraryApiPaths.settings,
      queryParameters: _queryParams(query),
    );
    return LibrarySettingsDto.fromJson(_responseMap(response));
  }

  /// LIB-D1 — PUT /library/settings.
  Future<LibrarySettingsDto> updateSettings({
    required RepositoryQuery query,
    required LibrarySettings settings,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      LibraryApiPaths.settings,
      queryParameters: _queryParams(query),
      data: {
        'maxBooksPerMember': settings.maxBooksPerMember,
        'maxRenewals': settings.maxRenewals,
        'blockOnFineThreshold': settings.blockOnFineThreshold,
      },
    );
    return LibrarySettingsDto.fromJson(_responseMap(response));
  }

  Map<String, dynamic> _queryParams(RepositoryQuery query) {
    return {
      'tenantId': query.tenantId,
      if (query.schoolId != null) 'schoolId': query.schoolId,
      if (query.organizationId != null) 'organizationId': query.organizationId,
    };
  }

  /// Unwraps the `{data, error}` envelope returned by write endpoints.
  Map<String, dynamic> _writeData(Response<Map<String, dynamic>> response) {
    return ApiEnvelopeDto.fromJson(_responseMap(response)).requireData();
  }

  Map<String, dynamic> _responseMap(Response<Map<String, dynamic>> response) {
    return response.data ?? const {};
  }
}
