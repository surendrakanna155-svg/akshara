import 'package:flutter/material.dart';

/// Library sub-module destinations (LB-01 → LB-08).
enum LibraryScreen {
  dashboard,
  catalog,
  issues,
  returns,
  members,
  fines,
  resources,
  reports;

  String get label => switch (this) {
        LibraryScreen.dashboard => 'Dashboard',
        LibraryScreen.catalog => 'Catalog',
        LibraryScreen.issues => 'Issue',
        LibraryScreen.returns => 'Returns',
        LibraryScreen.members => 'Members',
        LibraryScreen.fines => 'Fines',
        LibraryScreen.resources => 'Digital',
        LibraryScreen.reports => 'Reports',
      };
}

enum LibraryBookStatus { available, issued, reserved, damaged }

enum LibraryMemberType { student, staff, teacher }

enum LibraryMemberStatus { active, blocked, expired }

enum LibraryLoanStatus { active, overdue, returned }

enum LibraryFineStatus { pending, paid, waived }

enum LibraryResourceType { ebook, pdf, link, video }

enum LibraryReturnCondition { good, fair, damaged }

@immutable
class LibraryKpi {
  const LibraryKpi({
    required this.id,
    required this.value,
    required this.label,
    required this.icon,
    required this.accentName,
    this.detail,
  });

  final String id;
  final String value;
  final String label;
  final IconData icon;
  final String accentName;
  final String? detail;
}

@immutable
class LibraryTrendPoint {
  const LibraryTrendPoint({
    required this.label,
    required this.amountLakhs,
    required this.targetLakhs,
  });

  final String label;
  final double amountLakhs;
  final double targetLakhs;
}

@immutable
class LibrarySegment {
  const LibrarySegment({
    required this.label,
    required this.value,
    required this.percent,
  });

  final String label;
  final double value;
  final double percent;
}

@immutable
class LibraryBook {
  const LibraryBook({
    required this.id,
    required this.isbn,
    required this.title,
    required this.author,
    required this.category,
    required this.totalCopies,
    required this.availableCopies,
    required this.shelf,
    required this.status,
  });

  final String id;
  final String isbn;
  final String title;
  final String author;
  final String category;
  final int totalCopies;
  final int availableCopies;
  final String shelf;
  final LibraryBookStatus status;
}

@immutable
class LibraryMember {
  const LibraryMember({
    required this.id,
    required this.name,
    required this.memberType,
    required this.identifier,
    required this.classOrDepartment,
    required this.activeLoans,
    required this.status,
    this.sisStudentId,
  });

  final String id;
  final String name;
  final LibraryMemberType memberType;
  final String identifier;
  final String classOrDepartment;
  final int activeLoans;
  final LibraryMemberStatus status;
  final String? sisStudentId;
}

@immutable
class LibraryIssueRecord {
  const LibraryIssueRecord({
    required this.id,
    required this.memberName,
    required this.memberType,
    required this.bookTitle,
    required this.isbn,
    required this.issuedDate,
    required this.dueDate,
    required this.status,
    this.sisStudentId,
  });

  final String id;
  final String memberName;
  final LibraryMemberType memberType;
  final String bookTitle;
  final String isbn;
  final String issuedDate;
  final String dueDate;
  final LibraryLoanStatus status;
  final String? sisStudentId;
}

@immutable
class LibraryReturnRecord {
  const LibraryReturnRecord({
    required this.id,
    required this.memberName,
    required this.bookTitle,
    required this.isbn,
    required this.returnedDate,
    required this.condition,
    required this.fineAmount,
    required this.daysOverdue,
  });

  final String id;
  final String memberName;
  final String bookTitle;
  final String isbn;
  final String returnedDate;
  final LibraryReturnCondition condition;
  final String fineAmount;
  final int daysOverdue;
}

@immutable
class LibraryFine {
  const LibraryFine({
    required this.id,
    required this.memberName,
    required this.bookTitle,
    required this.amount,
    required this.daysOverdue,
    required this.status,
    required this.financeLinked,
    this.sisStudentId,
  });

  final String id;
  final String memberName;
  final String bookTitle;
  final String amount;
  final int daysOverdue;
  final LibraryFineStatus status;
  final bool financeLinked;
  final String? sisStudentId;
}

@immutable
class LibraryDigitalResource {
  const LibraryDigitalResource({
    required this.id,
    required this.title,
    required this.type,
    required this.classAccess,
    required this.downloads,
    required this.studentAppVisible,
    required this.teacherAppVisible,
    this.resourceUrl,
  });

  final String id;
  final String title;
  final LibraryResourceType type;
  final String classAccess;
  final int downloads;
  final bool studentAppVisible;
  final bool teacherAppVisible;

  /// Retrievable http(s) content pointer (LIBRA-4); null on legacy seed rows.
  final String? resourceUrl;
}

@immutable
class LibraryReportCatalogItem {
  const LibraryReportCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.lastGenerated,
  });

  final String id;
  final String title;
  final String description;
  final String lastGenerated;
}

@immutable
class LibraryDashboardData {
  const LibraryDashboardData({
    required this.kpis,
    required this.recentIssues,
    required this.overdueTitles,
    required this.issueTrend,
    required this.categoryDistribution,
    required this.popularTitle,
    required this.aiInsight,
  });

  final List<LibraryKpi> kpis;
  final List<LibraryIssueRecord> recentIssues;
  final List<String> overdueTitles;
  final List<LibraryTrendPoint> issueTrend;
  final List<LibrarySegment> categoryDistribution;
  final String popularTitle;
  final String aiInsight;
}

@immutable
class LibraryFinesData {
  const LibraryFinesData({
    required this.fines,
    required this.financeIntegrationNote,
    required this.financeRoute,
    required this.totalPending,
  });

  final List<LibraryFine> fines;
  final String financeIntegrationNote;
  final String financeRoute;
  final String totalPending;
}

@immutable
class LibraryDigitalResourcesData {
  const LibraryDigitalResourcesData({
    required this.resources,
    required this.studentAppRoute,
    required this.teacherAppRoute,
    required this.integrationNote,
  });

  final List<LibraryDigitalResource> resources;
  final String studentAppRoute;
  final String teacherAppRoute;
  final String integrationNote;
}

@immutable
class LibraryReportsData {
  const LibraryReportsData({
    required this.catalog,
    required this.issueTrend,
    required this.overdueByClass,
    required this.popularTitles,
  });

  final List<LibraryReportCatalogItem> catalog;
  final List<LibraryTrendPoint> issueTrend;
  final List<LibrarySegment> overdueByClass;
  final List<LibrarySegment> popularTitles;
}
