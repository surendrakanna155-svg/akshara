import '../../../../../features/library/library_models.dart';
import '../dto/library_enum_codec.dart';
import '../dto/library_responses_dto.dart';

/// Maps Library API DTOs to domain models.
class LibraryMapper {
  const LibraryMapper();

  LibraryDashboardData toDashboard(LibraryDashboardDto dto) {
    final raw = dto.raw;
    return LibraryDashboardData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      recentIssues: _mapIssueRecords(
        raw['recentIssues'] as List<dynamic>? ?? const [],
      ),
      overdueTitles: _stringList(raw['overdueTitles']),
      issueTrend: _mapTrendPoints(
        raw['issueTrend'] as List<dynamic>? ?? const [],
      ),
      categoryDistribution: _mapSegments(
        raw['categoryDistribution'] as List<dynamic>? ?? const [],
      ),
      popularTitle: raw['popularTitle'] as String? ?? '',
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  List<LibraryBook> toCatalog(LibraryCatalogResponseDto dto) {
    return [for (final item in dto.items) toBook(item)];
  }

  LibraryBook toBook(LibraryBookDto dto) {
    final raw = dto.raw;
    return LibraryBook(
      id: raw['id'] as String? ?? '',
      isbn: raw['isbn'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      author: raw['author'] as String? ?? '',
      category: raw['category'] as String? ?? '',
      totalCopies: raw['totalCopies'] as int? ?? 0,
      availableCopies: raw['availableCopies'] as int? ?? 0,
      shelf: raw['shelf'] as String? ?? '',
      status: LibraryEnumCodec.parseBookStatus(raw['status'] as String?),
    );
  }

  List<LibraryIssueRecord> toIssues(LibraryIssuesResponseDto dto) {
    return [for (final item in dto.items) toIssueRecord(item)];
  }

  LibraryIssueRecord toIssueRecord(LibraryIssueRecordDto dto) {
    final raw = dto.raw;
    return LibraryIssueRecord(
      id: raw['id'] as String? ?? '',
      memberName: raw['memberName'] as String? ?? '',
      memberType: LibraryEnumCodec.parseMemberType(raw['memberType'] as String?),
      bookTitle: raw['bookTitle'] as String? ?? '',
      isbn: raw['isbn'] as String? ?? '',
      issuedDate: raw['issuedDate'] as String? ?? '',
      dueDate: raw['dueDate'] as String? ?? '',
      status: LibraryEnumCodec.parseLoanStatus(raw['status'] as String?),
      sisStudentId: raw['sisStudentId'] as String?,
    );
  }

  List<LibraryReturnRecord> toReturns(LibraryReturnsResponseDto dto) {
    return [for (final item in dto.items) toReturnRecord(item)];
  }

  LibraryReturnRecord toReturnRecord(LibraryReturnRecordDto dto) {
    final raw = dto.raw;
    return LibraryReturnRecord(
      id: raw['id'] as String? ?? '',
      memberName: raw['memberName'] as String? ?? '',
      bookTitle: raw['bookTitle'] as String? ?? '',
      isbn: raw['isbn'] as String? ?? '',
      returnedDate: raw['returnedDate'] as String? ?? '',
      condition: LibraryEnumCodec.parseReturnCondition(
        raw['condition'] as String?,
      ),
      fineAmount: raw['fineAmount'] as String? ?? '',
      daysOverdue: raw['daysOverdue'] as int? ?? 0,
    );
  }

  List<LibraryMember> toMembers(LibraryMembersResponseDto dto) {
    return [for (final item in dto.items) toMember(item)];
  }

  LibraryMember toMember(LibraryMemberDto dto) {
    final raw = dto.raw;
    return LibraryMember(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      memberType: LibraryEnumCodec.parseMemberType(raw['memberType'] as String?),
      identifier: raw['identifier'] as String? ?? '',
      classOrDepartment: raw['classOrDepartment'] as String? ?? '',
      activeLoans: raw['activeLoans'] as int? ?? 0,
      status: LibraryEnumCodec.parseMemberStatus(raw['status'] as String?),
      sisStudentId: raw['sisStudentId'] as String?,
    );
  }

  LibraryFinesData toFines(LibraryFinesResponseDto dto) {
    final raw = dto.raw;
    return LibraryFinesData(
      fines: _mapFines(raw['fines'] as List<dynamic>? ?? const []),
      financeIntegrationNote: raw['financeIntegrationNote'] as String? ?? '',
      financeRoute: raw['financeRoute'] as String? ?? '',
      totalPending: raw['totalPending'] as String? ?? '',
    );
  }

  LibraryDigitalResourcesData toDigitalResources(
    LibraryDigitalResourcesResponseDto dto,
  ) {
    final raw = dto.raw;
    return LibraryDigitalResourcesData(
      resources: _mapDigitalResources(
        raw['resources'] as List<dynamic>? ?? const [],
      ),
      studentAppRoute: raw['studentAppRoute'] as String? ?? '',
      teacherAppRoute: raw['teacherAppRoute'] as String? ?? '',
      integrationNote: raw['integrationNote'] as String? ?? '',
    );
  }

  LibraryReportsData toReports(LibraryReportsResponseDto dto) {
    final raw = dto.raw;
    return LibraryReportsData(
      catalog: _mapReportCatalog(raw['catalog'] as List<dynamic>? ?? const []),
      issueTrend: _mapTrendPoints(
        raw['issueTrend'] as List<dynamic>? ?? const [],
      ),
      overdueByClass: _mapSegments(
        raw['overdueByClass'] as List<dynamic>? ?? const [],
      ),
      popularTitles: _mapSegments(
        raw['popularTitles'] as List<dynamic>? ?? const [],
      ),
    );
  }

  List<LibraryKpi> _mapKpis(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          LibraryKpi(
            id: item['id'] as String? ?? '',
            value: item['value'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: LibraryEnumCodec.iconForKpi(
              item['icon'] as String?,
              item['accentName'] as String?,
              item['id'] as String?,
            ),
            accentName: item['accentName'] as String? ?? 'neutral',
            detail: item['detail'] as String?,
          ),
    ];
  }

  List<LibraryTrendPoint> _mapTrendPoints(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          LibraryTrendPoint(
            label: item['label'] as String? ?? '',
            amountLakhs: (item['amountLakhs'] as num?)?.toDouble() ?? 0,
            targetLakhs: (item['targetLakhs'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<LibrarySegment> _mapSegments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          LibrarySegment(
            label: item['label'] as String? ?? '',
            value: (item['value'] as num?)?.toDouble() ?? 0,
            percent: (item['percent'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<LibraryIssueRecord> _mapIssueRecords(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          toIssueRecord(LibraryIssueRecordDto.fromJson(item)),
    ];
  }

  /// Maps a raw persisted `fine` entity (write response) to a [LibraryFine].
  /// The stored `amount` is a number (rupees) and `status` is `outstanding` /
  /// `waived`; we normalise both to the client shape.
  LibraryFine toFineFromEntity(Map<String, dynamic> raw) {
    final amount = raw['amount'];
    final amountLabel = amount is num
        ? '₹${amount.toInt()}'
        : (amount as String? ?? '');
    final status = raw['status'] as String?;
    final sisStudentId = raw['sisStudentId'] as String?;
    return LibraryFine(
      id: raw['id'] as String? ?? '',
      memberName: raw['memberName'] as String? ?? '',
      bookTitle: raw['bookTitle'] as String? ?? '',
      amount: amountLabel,
      daysOverdue: raw['daysOverdue'] as int? ?? 0,
      status: status == 'waived'
          ? LibraryFineStatus.waived
          : LibraryEnumCodec.parseFineStatus(status),
      financeLinked: sisStudentId != null,
      sisStudentId: sisStudentId,
    );
  }

  List<LibraryFine> _mapFines(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          LibraryFine(
            id: item['id'] as String? ?? '',
            memberName: item['memberName'] as String? ?? '',
            bookTitle: item['bookTitle'] as String? ?? '',
            amount: item['amount'] as String? ?? '',
            daysOverdue: item['daysOverdue'] as int? ?? 0,
            status: LibraryEnumCodec.parseFineStatus(item['status'] as String?),
            financeLinked: item['financeLinked'] as bool? ?? false,
            sisStudentId: item['sisStudentId'] as String?,
          ),
    ];
  }

  LibraryDigitalResource toDigitalResource(Map<String, dynamic> item) {
    return LibraryDigitalResource(
      id: item['id'] as String? ?? '',
      title: item['title'] as String? ?? '',
      type: LibraryEnumCodec.parseResourceType(item['type'] as String?),
      classAccess: item['classAccess'] as String? ?? '',
      downloads: item['downloads'] as int? ?? 0,
      studentAppVisible: item['studentAppVisible'] as bool? ?? false,
      teacherAppVisible: item['teacherAppVisible'] as bool? ?? false,
      resourceUrl: item['resourceUrl'] as String?,
    );
  }

  List<LibraryDigitalResource> _mapDigitalResources(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) toDigitalResource(item),
    ];
  }

  List<LibraryReportCatalogItem> _mapReportCatalog(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          LibraryReportCatalogItem(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            description: item['description'] as String? ?? '',
            lastGenerated: item['lastGenerated'] as String? ?? '',
          ),
    ];
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item != null) '$item',
    ];
  }
}
