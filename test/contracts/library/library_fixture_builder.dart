import 'package:akshara_erp/core/repositories/api/library/dto/library_enum_codec.dart';
import 'package:akshara_erp/features/library/library_models.dart';

/// Builds API-shaped JSON envelopes from Library domain models for contract tests.
class LibraryFixtureBuilder {
  const LibraryFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> trendPoint(LibraryTrendPoint point) => {
        'label': point.label,
        'amountLakhs': point.amountLakhs,
        'targetLakhs': point.targetLakhs,
      };

  Map<String, dynamic> segment(LibrarySegment segment) => {
        'label': segment.label,
        'value': segment.value,
        'percent': segment.percent,
      };

  Map<String, dynamic> bookItem(LibraryBook book) => {
        'id': book.id,
        'isbn': book.isbn,
        'title': book.title,
        'author': book.author,
        'category': book.category,
        'totalCopies': book.totalCopies,
        'availableCopies': book.availableCopies,
        'shelf': book.shelf,
        'status': LibraryEnumCodec.bookStatusToApi(book.status),
      };

  Map<String, dynamic> issueRecordItem(LibraryIssueRecord record) => {
        'id': record.id,
        'memberName': record.memberName,
        'memberType': LibraryEnumCodec.memberTypeToApi(record.memberType),
        'bookTitle': record.bookTitle,
        'isbn': record.isbn,
        'issuedDate': record.issuedDate,
        'dueDate': record.dueDate,
        'status': LibraryEnumCodec.loanStatusToApi(record.status),
        if (record.sisStudentId != null) 'sisStudentId': record.sisStudentId,
      };

  Map<String, dynamic> returnRecordItem(LibraryReturnRecord record) => {
        'id': record.id,
        'memberName': record.memberName,
        'bookTitle': record.bookTitle,
        'isbn': record.isbn,
        'returnedDate': record.returnedDate,
        'condition': LibraryEnumCodec.returnConditionToApi(record.condition),
        'fineAmount': record.fineAmount,
        'daysOverdue': record.daysOverdue,
      };

  Map<String, dynamic> memberItem(LibraryMember member) => {
        'id': member.id,
        'name': member.name,
        'memberType': LibraryEnumCodec.memberTypeToApi(member.memberType),
        'identifier': member.identifier,
        'classOrDepartment': member.classOrDepartment,
        'activeLoans': member.activeLoans,
        'status': LibraryEnumCodec.memberStatusToApi(member.status),
        if (member.sisStudentId != null) 'sisStudentId': member.sisStudentId,
      };

  Map<String, dynamic> dashboardEnvelope(LibraryDashboardData data) {
    return envelope({
      'aiInsight': data.aiInsight,
      'popularTitle': data.popularTitle,
      'overdueTitles': data.overdueTitles,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
            if (kpi.detail != null) 'detail': kpi.detail,
          },
      ],
      'recentIssues': [
        for (final issue in data.recentIssues) issueRecordItem(issue),
      ],
      'issueTrend': [
        for (final point in data.issueTrend) trendPoint(point),
      ],
      'categoryDistribution': [
        for (final segment in data.categoryDistribution) this.segment(segment),
      ],
    });
  }

  Map<String, dynamic> catalogEnvelope(List<LibraryBook> books) {
    return listEnvelope([for (final book in books) bookItem(book)]);
  }

  Map<String, dynamic> issuesEnvelope(List<LibraryIssueRecord> issues) {
    return listEnvelope([
      for (final issue in issues) issueRecordItem(issue),
    ]);
  }

  Map<String, dynamic> returnsEnvelope(List<LibraryReturnRecord> returns) {
    return listEnvelope([
      for (final record in returns) returnRecordItem(record),
    ]);
  }

  Map<String, dynamic> membersEnvelope(List<LibraryMember> members) {
    return listEnvelope([for (final member in members) memberItem(member)]);
  }

  Map<String, dynamic> finesEnvelope(LibraryFinesData data) {
    return envelope({
      'financeIntegrationNote': data.financeIntegrationNote,
      'financeRoute': data.financeRoute,
      'totalPending': data.totalPending,
      'fines': [
        for (final fine in data.fines)
          {
            'id': fine.id,
            'memberName': fine.memberName,
            'bookTitle': fine.bookTitle,
            'amount': fine.amount,
            'daysOverdue': fine.daysOverdue,
            'status': LibraryEnumCodec.fineStatusToApi(fine.status),
            'financeLinked': fine.financeLinked,
            if (fine.sisStudentId != null) 'sisStudentId': fine.sisStudentId,
          },
      ],
    });
  }

  Map<String, dynamic> digitalResourcesEnvelope(LibraryDigitalResourcesData data) {
    return envelope({
      'studentAppRoute': data.studentAppRoute,
      'teacherAppRoute': data.teacherAppRoute,
      'integrationNote': data.integrationNote,
      'resources': [
        for (final resource in data.resources)
          {
            'id': resource.id,
            'title': resource.title,
            'type': LibraryEnumCodec.resourceTypeToApi(resource.type),
            'classAccess': resource.classAccess,
            'downloads': resource.downloads,
            'studentAppVisible': resource.studentAppVisible,
            'teacherAppVisible': resource.teacherAppVisible,
          },
      ],
    });
  }

  Map<String, dynamic> reportsEnvelope(LibraryReportsData data) {
    return envelope({
      'catalog': [
        for (final item in data.catalog)
          {
            'id': item.id,
            'title': item.title,
            'description': item.description,
            'lastGenerated': item.lastGenerated,
          },
      ],
      'issueTrend': [
        for (final point in data.issueTrend) trendPoint(point),
      ],
      'overdueByClass': [
        for (final segment in data.overdueByClass) this.segment(segment),
      ],
      'popularTitles': [
        for (final segment in data.popularTitles) this.segment(segment),
      ],
    });
  }
}
