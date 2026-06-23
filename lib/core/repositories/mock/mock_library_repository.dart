import 'package:flutter/material.dart';

import '../../../features/library/library_models.dart';
import '../../../features/library/library_requests.dart';
import '../../../router/route_names.dart';
import '../interfaces/library_repository.dart';
import '../paginated_result.dart';
import '../pagination_helpers.dart';
import '../repository_query.dart';

class MockLibraryRepository implements LibraryRepository {
  MockLibraryRepository()
      : _books = List<LibraryBook>.from(_seedBooks),
        _issues = List<LibraryIssueRecord>.from(_seedIssues),
        _returns = List<LibraryReturnRecord>.from(_seedReturns),
        _members = List<LibraryMember>.from(_seedMembers),
        _resources = List<LibraryDigitalResource>.from(_seedResources);

  final List<LibraryBook> _books;
  final List<LibraryIssueRecord> _issues;
  final List<LibraryReturnRecord> _returns;
  final List<LibraryMember> _members;
  final List<LibraryDigitalResource> _resources;
  int _issueCounter = 5;
  int _returnCounter = 5;
  int _bookCounter = 6;
  int _resourceCounter = 5;

  static const _seedIssues = [
    LibraryIssueRecord(
      id: 'iss_1',
      memberName: 'Arjun Patel',
      memberType: LibraryMemberType.student,
      bookTitle: 'To Kill a Mockingbird',
      isbn: '978-0-06-112008-4',
      issuedDate: '22 May 2026',
      dueDate: '5 Jun 2026',
      status: LibraryLoanStatus.overdue,
      sisStudentId: 'SIS-STU-10421',
    ),
    LibraryIssueRecord(
      id: 'iss_2',
      memberName: 'Emma Thomas',
      memberType: LibraryMemberType.student,
      bookTitle: 'The Great Gatsby',
      isbn: '978-0-553-29698-3',
      issuedDate: '28 May 2026',
      dueDate: '11 Jun 2026',
      status: LibraryLoanStatus.active,
      sisStudentId: 'SIS-STU-10418',
    ),
    LibraryIssueRecord(
      id: 'iss_3',
      memberName: 'Dr. Meera Iyer',
      memberType: LibraryMemberType.teacher,
      bookTitle: 'Effective Java',
      isbn: '978-0-13-468599-1',
      issuedDate: '1 Jun 2026',
      dueDate: '15 Jun 2026',
      status: LibraryLoanStatus.active,
    ),
    LibraryIssueRecord(
      id: 'iss_4',
      memberName: 'Priya Sharma',
      memberType: LibraryMemberType.student,
      bookTitle: 'Pride and Prejudice',
      isbn: '978-0-14-143951-8',
      issuedDate: '15 May 2026',
      dueDate: '29 May 2026',
      status: LibraryLoanStatus.overdue,
      sisStudentId: 'SIS-STU-10415',
    ),
  ];

  static const _seedBooks = [
    LibraryBook(
      id: 'bk_1',
      isbn: '978-0-14-143951-8',
      title: 'Pride and Prejudice',
      author: 'Jane Austen',
      category: 'Fiction',
      totalCopies: 12,
      availableCopies: 8,
      shelf: 'A-12',
      status: LibraryBookStatus.available,
    ),
    LibraryBook(
      id: 'bk_2',
      isbn: '978-0-553-29698-3',
      title: 'The Great Gatsby',
      author: 'F. Scott Fitzgerald',
      category: 'Fiction',
      totalCopies: 10,
      availableCopies: 3,
      shelf: 'A-14',
      status: LibraryBookStatus.available,
    ),
    LibraryBook(
      id: 'bk_3',
      isbn: '978-0-06-112008-4',
      title: 'To Kill a Mockingbird',
      author: 'Harper Lee',
      category: 'Fiction',
      totalCopies: 8,
      availableCopies: 0,
      shelf: 'A-16',
      status: LibraryBookStatus.issued,
    ),
    LibraryBook(
      id: 'bk_4',
      isbn: '978-0-13-468599-1',
      title: 'Effective Java',
      author: 'Joshua Bloch',
      category: 'Reference',
      totalCopies: 6,
      availableCopies: 4,
      shelf: 'R-03',
      status: LibraryBookStatus.available,
    ),
    LibraryBook(
      id: 'bk_5',
      isbn: '978-0-07-802563-1',
      title: 'Concepts of Physics Vol. 1',
      author: 'H.C. Verma',
      category: 'Science',
      totalCopies: 15,
      availableCopies: 6,
      shelf: 'S-08',
      status: LibraryBookStatus.available,
    ),
    LibraryBook(
      id: 'bk_6',
      isbn: '978-81-219-2612-0',
      title: 'NCERT Mathematics Class 10',
      author: 'NCERT',
      category: 'Textbook',
      totalCopies: 20,
      availableCopies: 11,
      shelf: 'T-02',
      status: LibraryBookStatus.available,
    ),
  ];

  static const _seedMembers = [
    LibraryMember(
      id: 'mem_1',
      name: 'Arjun Patel',
      memberType: LibraryMemberType.student,
      identifier: 'ADM-2026-0138',
      classOrDepartment: 'Class 10',
      activeLoans: 2,
      status: LibraryMemberStatus.active,
      sisStudentId: 'SIS-STU-10421',
    ),
    LibraryMember(
      id: 'mem_2',
      name: 'Emma Thomas',
      memberType: LibraryMemberType.student,
      identifier: 'ADM-2026-0135',
      classOrDepartment: 'Class 7',
      activeLoans: 1,
      status: LibraryMemberStatus.active,
      sisStudentId: 'SIS-STU-10418',
    ),
    LibraryMember(
      id: 'mem_3',
      name: 'Priya Sharma',
      memberType: LibraryMemberType.student,
      identifier: 'ADM-2025-0092',
      classOrDepartment: 'Class 8',
      activeLoans: 3,
      status: LibraryMemberStatus.blocked,
      sisStudentId: 'SIS-STU-10415',
    ),
    LibraryMember(
      id: 'mem_4',
      name: 'Dr. Meera Iyer',
      memberType: LibraryMemberType.teacher,
      identifier: 'EMP-TCH-042',
      classOrDepartment: 'English Dept',
      activeLoans: 1,
      status: LibraryMemberStatus.active,
    ),
    LibraryMember(
      id: 'mem_5',
      name: 'Ravi Shankar',
      memberType: LibraryMemberType.staff,
      identifier: 'EMP-ADM-018',
      classOrDepartment: 'Administration',
      activeLoans: 0,
      status: LibraryMemberStatus.active,
    ),
  ];

  static const _seedReturns = [
    LibraryReturnRecord(
      id: 'ret_1',
      memberName: 'Ananya Reddy',
      bookTitle: 'NCERT Mathematics Class 10',
      isbn: '978-81-219-2612-0',
      returnedDate: '5 Jun 2026',
      condition: LibraryReturnCondition.good,
      fineAmount: '₹0',
      daysOverdue: 0,
    ),
    LibraryReturnRecord(
      id: 'ret_2',
      memberName: 'Rohan Mehta',
      bookTitle: 'The Great Gatsby',
      isbn: '978-0-553-29698-3',
      returnedDate: '4 Jun 2026',
      condition: LibraryReturnCondition.fair,
      fineAmount: '₹50',
      daysOverdue: 2,
    ),
    LibraryReturnRecord(
      id: 'ret_3',
      memberName: 'Priya Sharma',
      bookTitle: 'Concepts of Physics Vol. 1',
      isbn: '978-0-07-802563-1',
      returnedDate: '3 Jun 2026',
      condition: LibraryReturnCondition.damaged,
      fineAmount: '₹200',
      daysOverdue: 5,
    ),
    LibraryReturnRecord(
      id: 'ret_4',
      memberName: 'Dr. Meera Iyer',
      bookTitle: 'Pride and Prejudice',
      isbn: '978-0-14-143951-8',
      returnedDate: '2 Jun 2026',
      condition: LibraryReturnCondition.good,
      fineAmount: '₹0',
      daysOverdue: 0,
    ),
  ];

  List<LibraryIssueRecord> get _openIssues => _issues
      .where(
        (issue) =>
            issue.status == LibraryLoanStatus.active ||
            issue.status == LibraryLoanStatus.overdue,
      )
      .toList(growable: false);

  @override
  Future<LibraryDashboardData> getDashboard({required RepositoryQuery query}) async {
    return LibraryDashboardData(
      kpis: const [
        LibraryKpi(
          id: 'total_books',
          value: '4,280',
          label: 'Total Books',
          icon: Icons.menu_book_outlined,
          accentName: 'primary',
        ),
        LibraryKpi(
          id: 'issued_today',
          value: '47',
          label: 'Issued Today',
          icon: Icons.swap_horiz_outlined,
          accentName: 'success',
        ),
        LibraryKpi(
          id: 'overdue',
          value: '18',
          label: 'Overdue',
          icon: Icons.schedule_outlined,
          accentName: 'warning',
        ),
        LibraryKpi(
          id: 'fines_mtd',
          value: '₹2,840',
          label: 'Fines MTD',
          icon: Icons.payments_outlined,
          accentName: 'error',
          detail: 'Finance FN-02 placeholder',
        ),
        LibraryKpi(
          id: 'popular',
          value: 'H.C. Verma',
          label: 'Popular Title',
          icon: Icons.trending_up_outlined,
          accentName: 'neutral',
          detail: 'Concepts of Physics Vol. 1',
        ),
        LibraryKpi(
          id: 'digital',
          value: '126',
          label: 'Digital Resources',
          icon: Icons.cloud_download_outlined,
          accentName: 'primary',
          detail: 'Student & Teacher app',
        ),
      ],
      recentIssues: _openIssues.take(3).toList(growable: false),
      overdueTitles: const [
        'To Kill a Mockingbird — 3 copies overdue',
        'NCERT Mathematics Class 10 — 2 copies overdue',
        'The Great Gatsby — 1 copy overdue',
      ],
      issueTrend: const [
        LibraryTrendPoint(label: 'Jan', amountLakhs: 820, targetLakhs: 900),
        LibraryTrendPoint(label: 'Feb', amountLakhs: 880, targetLakhs: 900),
        LibraryTrendPoint(label: 'Mar', amountLakhs: 910, targetLakhs: 950),
        LibraryTrendPoint(label: 'Apr', amountLakhs: 940, targetLakhs: 950),
        LibraryTrendPoint(label: 'May', amountLakhs: 920, targetLakhs: 950),
        LibraryTrendPoint(label: 'Jun', amountLakhs: 960, targetLakhs: 1000),
      ],
      categoryDistribution: const [
        LibrarySegment(label: 'Fiction', value: 38, percent: 38),
        LibrarySegment(label: 'Textbook', value: 28, percent: 28),
        LibrarySegment(label: 'Science', value: 18, percent: 18),
        LibrarySegment(label: 'Reference', value: 16, percent: 16),
      ],
      popularTitle: 'Concepts of Physics Vol. 1 — 42 issues this month',
      aiInsight:
          '18 overdue loans — 6 from Class 8. Send reminders via Student App. Priya Sharma blocked (₹450 fines) — link to Finance FN-02 library_fine fee head.',
    );
  }

  @override
  Future<PaginatedResult<LibraryBook>> getCatalog({
    required RepositoryQuery query,
  }) async =>
      paginateList(_books, query);

  @override
  Future<PaginatedResult<LibraryIssueRecord>> getIssues({
    required RepositoryQuery query,
  }) async =>
      paginateList(_openIssues, query);

  @override
  Future<PaginatedResult<LibraryReturnRecord>> getReturns({
    required RepositoryQuery query,
  }) async =>
      paginateList(_returns, query);

  @override
  Future<PaginatedResult<LibraryMember>> getMembers({
    required RepositoryQuery query,
  }) async =>
      paginateList(_members, query);

  @override
  Future<LibraryFinesData> getFines({required RepositoryQuery query}) async {
    return const LibraryFinesData(
      fines: [
        LibraryFine(
          id: 'fine_1',
          memberName: 'Arjun Patel',
          bookTitle: 'To Kill a Mockingbird',
          amount: '₹60',
          daysOverdue: 1,
          status: LibraryFineStatus.pending,
          financeLinked: false,
          sisStudentId: 'SIS-STU-10421',
        ),
        LibraryFine(
          id: 'fine_2',
          memberName: 'Priya Sharma',
          bookTitle: 'Pride and Prejudice',
          amount: '₹450',
          daysOverdue: 7,
          status: LibraryFineStatus.pending,
          financeLinked: true,
          sisStudentId: 'SIS-STU-10415',
        ),
        LibraryFine(
          id: 'fine_3',
          memberName: 'Rohan Mehta',
          bookTitle: 'The Great Gatsby',
          amount: '₹50',
          daysOverdue: 2,
          status: LibraryFineStatus.paid,
          financeLinked: true,
        ),
        LibraryFine(
          id: 'fine_4',
          memberName: 'Emma Thomas',
          bookTitle: 'NCERT Mathematics Class 10',
          amount: '₹30',
          daysOverdue: 1,
          status: LibraryFineStatus.waived,
          financeLinked: false,
          sisStudentId: 'SIS-STU-10418',
        ),
      ],
      financeIntegrationNote:
          'Library fines sync to Finance FN-02 fee head library_fine. Paid fines post to FN-05 collections.',
      financeRoute: RouteNames.financeFeeStructures,
      totalPending: '₹510',
    );
  }

  @override
  Future<LibraryDigitalResourcesData> getDigitalResources({required RepositoryQuery query}) async {
    return LibraryDigitalResourcesData(
      studentAppRoute: RouteNames.studentDashboard,
      teacherAppRoute: RouteNames.teacherDashboard,
      integrationNote:
          'Digital resources visible in Student App (My Books) and Teacher App (Resource shelf). Class-level access rules enforced.',
      resources: List<LibraryDigitalResource>.unmodifiable(_resources),
    );
  }

  static const List<LibraryDigitalResource> _seedResources = [
    LibraryDigitalResource(
      id: 'dig_1',
      title: 'NCERT Science Class 10 (PDF)',
      type: LibraryResourceType.pdf,
      classAccess: 'Class 10',
      downloads: 842,
      studentAppVisible: true,
      teacherAppVisible: true,
    ),
    LibraryDigitalResource(
      id: 'dig_2',
      title: 'Oxford Learner\'s Dictionary',
      type: LibraryResourceType.ebook,
      classAccess: 'All classes',
      downloads: 1204,
      studentAppVisible: true,
      teacherAppVisible: true,
    ),
    LibraryDigitalResource(
      id: 'dig_3',
      title: 'Khan Academy — Algebra',
      type: LibraryResourceType.link,
      classAccess: 'Class 8–10',
      downloads: 567,
      studentAppVisible: true,
      teacherAppVisible: true,
    ),
    LibraryDigitalResource(
      id: 'dig_4',
      title: 'Staff Policy Handbook',
      type: LibraryResourceType.pdf,
      classAccess: 'Staff only',
      downloads: 48,
      studentAppVisible: false,
      teacherAppVisible: true,
    ),
    LibraryDigitalResource(
      id: 'dig_5',
      title: 'Science Lab Safety Video',
      type: LibraryResourceType.video,
      classAccess: 'Class 9–12',
      downloads: 312,
      studentAppVisible: true,
      teacherAppVisible: true,
    ),
  ];

  @override
  Future<LibraryReportsData> getReports({required RepositoryQuery query}) async {
    return const LibraryReportsData(
      catalog: [
        LibraryReportCatalogItem(
          id: 'rpt_available',
          title: 'Available Books (RPT-LB-001)',
          description: 'Shelf inventory and availability by category',
          lastGenerated: '5 Jun 2026',
        ),
        LibraryReportCatalogItem(
          id: 'rpt_overdue',
          title: 'Overdue Loans (RPT-LB-002)',
          description: 'Overdue titles with member and fine details',
          lastGenerated: '5 Jun 2026',
        ),
        LibraryReportCatalogItem(
          id: 'rpt_popular',
          title: 'Popular Titles (RPT-LB-003)',
          description: 'Most issued books by class and month',
          lastGenerated: '4 Jun 2026',
        ),
        LibraryReportCatalogItem(
          id: 'rpt_fines',
          title: 'Fine Collection Summary',
          description: 'Fines MTD — Finance FN-02 integration placeholder',
          lastGenerated: '1 Jun 2026',
        ),
        LibraryReportCatalogItem(
          id: 'rpt_digital',
          title: 'Digital Resource Usage',
          description: 'Downloads by Student/Teacher app',
          lastGenerated: '3 Jun 2026',
        ),
        LibraryReportCatalogItem(
          id: 'rpt_members',
          title: 'Member Activity',
          description: 'Active members and loan frequency',
          lastGenerated: '2 Jun 2026',
        ),
      ],
      issueTrend: [
        LibraryTrendPoint(label: 'Jan', amountLakhs: 820, targetLakhs: 900),
        LibraryTrendPoint(label: 'Feb', amountLakhs: 880, targetLakhs: 900),
        LibraryTrendPoint(label: 'Mar', amountLakhs: 910, targetLakhs: 950),
        LibraryTrendPoint(label: 'Apr', amountLakhs: 940, targetLakhs: 950),
        LibraryTrendPoint(label: 'May', amountLakhs: 920, targetLakhs: 950),
        LibraryTrendPoint(label: 'Jun', amountLakhs: 960, targetLakhs: 1000),
      ],
      overdueByClass: [
        LibrarySegment(label: 'Class 8', value: 6, percent: 33),
        LibrarySegment(label: 'Class 10', value: 4, percent: 22),
        LibrarySegment(label: 'Class 7', value: 3, percent: 17),
        LibrarySegment(label: 'Staff', value: 2, percent: 11),
      ],
      popularTitles: [
        LibrarySegment(label: 'H.C. Verma', value: 42, percent: 28),
        LibrarySegment(label: 'NCERT Math 10', value: 38, percent: 25),
        LibrarySegment(label: 'Great Gatsby', value: 24, percent: 16),
        LibrarySegment(label: 'Effective Java', value: 18, percent: 12),
      ],
    );
  }

  @override
  Future<LibraryIssueRecord> issueLibraryBook({
    required RepositoryQuery query,
    required IssueLibraryBookRequest request,
  }) async {
    final bookIndex = _books.indexWhere((book) => book.isbn == request.isbn);
    if (bookIndex < 0) {
      throw StateError('Book not found for ISBN ${request.isbn}');
    }

    final memberIndex = _members.indexWhere((m) => m.id == request.memberId);
    if (memberIndex < 0) {
      throw StateError('Member not found: ${request.memberId}');
    }

    final book = _books[bookIndex];
    final member = _members[memberIndex];

    if (book.availableCopies <= 0) {
      throw StateError('No copies available for ${book.title}');
    }
    if (member.status != LibraryMemberStatus.active) {
      throw StateError('Member ${member.name} is not active');
    }

    _issueCounter += 1;
    final issueId = 'iss_$_issueCounter';
    const issuedDate = '13 Jun 2026';
    const dueDate = '27 Jun 2026';

    final issue = LibraryIssueRecord(
      id: issueId,
      memberName: member.name,
      memberType: member.memberType,
      bookTitle: book.title,
      isbn: book.isbn,
      issuedDate: issuedDate,
      dueDate: dueDate,
      status: LibraryLoanStatus.active,
      sisStudentId: member.sisStudentId,
    );
    _issues.insert(0, issue);

    final updatedAvailable = book.availableCopies - 1;
    _books[bookIndex] = LibraryBook(
      id: book.id,
      isbn: book.isbn,
      title: book.title,
      author: book.author,
      category: book.category,
      totalCopies: book.totalCopies,
      availableCopies: updatedAvailable,
      shelf: book.shelf,
      status: updatedAvailable == 0
          ? LibraryBookStatus.issued
          : LibraryBookStatus.available,
    );

    _members[memberIndex] = LibraryMember(
      id: member.id,
      name: member.name,
      memberType: member.memberType,
      identifier: member.identifier,
      classOrDepartment: member.classOrDepartment,
      activeLoans: member.activeLoans + 1,
      status: member.status,
      sisStudentId: member.sisStudentId,
    );

    return issue;
  }

  @override
  Future<LibraryReturnRecord> returnLibraryBook({
    required RepositoryQuery query,
    required ReturnLibraryBookRequest request,
  }) async {
    final issueIndex = _issues.indexWhere((issue) => issue.id == request.issueId);
    if (issueIndex < 0) {
      throw StateError('Issue not found: ${request.issueId}');
    }

    final issue = _issues[issueIndex];
    if (issue.status == LibraryLoanStatus.returned) {
      throw StateError('Issue already returned');
    }

    final bookIndex = _books.indexWhere((book) => book.isbn == issue.isbn);
    if (bookIndex < 0) {
      throw StateError('Book not found for ISBN ${issue.isbn}');
    }

    final memberIndex =
        _members.indexWhere((member) => member.name == issue.memberName);
    if (memberIndex < 0) {
      throw StateError('Member not found: ${issue.memberName}');
    }

    final daysOverdue =
        issue.status == LibraryLoanStatus.overdue ? 2 : 0;
    final damageFine = request.condition == LibraryReturnCondition.damaged
        ? 200
        : 0;
    final totalFine = daysOverdue * 30 + damageFine;
    final fineLabel = totalFine == 0 ? '₹0' : '₹$totalFine';

    _returnCounter += 1;
    final returnRecord = LibraryReturnRecord(
      id: 'ret_$_returnCounter',
      memberName: issue.memberName,
      bookTitle: issue.bookTitle,
      isbn: issue.isbn,
      returnedDate: '13 Jun 2026',
      condition: request.condition,
      fineAmount: fineLabel,
      daysOverdue: daysOverdue,
    );
    _returns.insert(0, returnRecord);

    _issues[issueIndex] = LibraryIssueRecord(
      id: issue.id,
      memberName: issue.memberName,
      memberType: issue.memberType,
      bookTitle: issue.bookTitle,
      isbn: issue.isbn,
      issuedDate: issue.issuedDate,
      dueDate: issue.dueDate,
      status: LibraryLoanStatus.returned,
      sisStudentId: issue.sisStudentId,
    );

    final book = _books[bookIndex];
    final updatedAvailable = book.availableCopies + 1;
    _books[bookIndex] = LibraryBook(
      id: book.id,
      isbn: book.isbn,
      title: book.title,
      author: book.author,
      category: book.category,
      totalCopies: book.totalCopies,
      availableCopies: updatedAvailable,
      shelf: book.shelf,
      status: LibraryBookStatus.available,
    );

    final member = _members[memberIndex];
    _members[memberIndex] = LibraryMember(
      id: member.id,
      name: member.name,
      memberType: member.memberType,
      identifier: member.identifier,
      classOrDepartment: member.classOrDepartment,
      activeLoans: member.activeLoans > 0 ? member.activeLoans - 1 : 0,
      status: member.status,
      sisStudentId: member.sisStudentId,
    );

    return returnRecord;
  }

  @override
  Future<LibraryBook> addLibraryBook({
    required RepositoryQuery query,
    required AddLibraryBookRequest request,
  }) async {
    final isbn = request.isbn.trim();
    final title = request.title.trim();
    if (isbn.isEmpty || title.isEmpty) {
      throw StateError('ISBN and title are required');
    }
    if (request.totalCopies <= 0) {
      throw StateError('A book must have at least one copy');
    }
    if (_books.any((book) => book.isbn == isbn)) {
      throw StateError('A book with ISBN $isbn already exists');
    }

    _bookCounter += 1;
    final book = LibraryBook(
      id: 'bk_$_bookCounter',
      isbn: isbn,
      title: title,
      author: request.author.trim(),
      category: request.category.trim(),
      totalCopies: request.totalCopies,
      availableCopies: request.totalCopies,
      shelf: request.shelf.trim(),
      status: LibraryBookStatus.available,
    );
    _books.insert(0, book);
    return book;
  }

  @override
  Future<LibraryDigitalResource> addDigitalResource({
    required RepositoryQuery query,
    required AddLibraryResourceRequest request,
  }) async {
    final title = request.title.trim();
    if (title.isEmpty) {
      throw StateError('Resource title is required');
    }

    _resourceCounter += 1;
    final resource = LibraryDigitalResource(
      id: 'dig_$_resourceCounter',
      title: title,
      type: request.type,
      classAccess:
          request.classAccess.trim().isEmpty ? 'All classes' : request.classAccess.trim(),
      downloads: 0,
      studentAppVisible: request.studentAppVisible,
      teacherAppVisible: request.teacherAppVisible,
    );
    _resources.insert(0, resource);
    return resource;
  }
}
