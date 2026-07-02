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
        _fines = List<LibraryFine>.from(_seedFines),
        _resources = List<LibraryDigitalResource>.from(_seedResources);

  final List<LibraryBook> _books;
  final List<LibraryIssueRecord> _issues;
  final List<LibraryReturnRecord> _returns;
  final List<LibraryMember> _members;
  final List<LibraryFine> _fines;
  final List<LibraryDigitalResource> _resources;
  int _issueCounter = 5;
  int _returnCounter = 5;
  int _bookCounter = 6;
  int _resourceCounter = 5;
  int _memberCounter = 5;

  /// LIB-D1 — in-memory circulation settings (starts at the owner defaults).
  LibrarySettings _settings = LibrarySettings.defaults;

  /// LIB-4 — per-issue renewal counter so the mock can enforce the cap without
  /// widening the [LibraryIssueRecord] read model.
  final Map<String, int> _renewalCounts = <String, int>{};

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

  static const _seedFines = [
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
  ];

  String get _totalPendingLabel {
    var total = 0;
    for (final fine in _fines) {
      if (fine.status != LibraryFineStatus.pending) continue;
      total += int.tryParse(fine.amount.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    return '₹$total';
  }

  @override
  Future<LibraryFinesData> getFines({required RepositoryQuery query}) async {
    return LibraryFinesData(
      fines: List<LibraryFine>.unmodifiable(_fines),
      financeIntegrationNote:
          'Library fines sync to Finance FN-02 fee head library_fine. Paid fines post to FN-05 collections.',
      financeRoute: RouteNames.financeFeeStructures,
      totalPending: _totalPendingLabel,
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
      resourceUrl: 'https://ncert.nic.in/textbook/pdf/jesc1dd.pdf',
      studentAppVisible: true,
      teacherAppVisible: true,
    ),
    LibraryDigitalResource(
      id: 'dig_2',
      title: 'Oxford Learner\'s Dictionary',
      type: LibraryResourceType.ebook,
      classAccess: 'All classes',
      downloads: 1204,
      resourceUrl: 'https://www.oxfordlearnersdictionaries.com/',
      studentAppVisible: true,
      teacherAppVisible: true,
    ),
    LibraryDigitalResource(
      id: 'dig_3',
      title: 'Khan Academy — Algebra',
      type: LibraryResourceType.link,
      classAccess: 'Class 8–10',
      downloads: 567,
      resourceUrl: 'https://www.khanacademy.org/math/algebra',
      studentAppVisible: true,
      teacherAppVisible: true,
    ),
    LibraryDigitalResource(
      id: 'dig_4',
      title: 'Staff Policy Handbook',
      type: LibraryResourceType.pdf,
      classAccess: 'Staff only',
      downloads: 48,
      resourceUrl: 'https://example.org/staff-policy-handbook.pdf',
      studentAppVisible: false,
      teacherAppVisible: true,
    ),
    LibraryDigitalResource(
      id: 'dig_5',
      title: 'Science Lab Safety Video',
      type: LibraryResourceType.video,
      classAccess: 'Class 9–12',
      downloads: 312,
      resourceUrl: 'https://www.youtube.com/watch?v=VRWRmIEHr3A',
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

    final url = request.resourceUrl.trim();
    if (url.isEmpty) {
      throw StateError('A digital resource needs a retrievable URL');
    }

    _resourceCounter += 1;
    final resource = LibraryDigitalResource(
      id: 'dig_$_resourceCounter',
      title: title,
      type: request.type,
      classAccess:
          request.classAccess.trim().isEmpty ? 'All classes' : request.classAccess.trim(),
      downloads: 0,
      resourceUrl: url,
      studentAppVisible: request.studentAppVisible,
      teacherAppVisible: request.teacherAppVisible,
    );
    _resources.insert(0, resource);
    return resource;
  }

  @override
  Future<LibraryMember> enrollMember({
    required RepositoryQuery query,
    required EnrollLibraryMemberRequest request,
  }) async {
    final name = request.name.trim();
    if (name.isEmpty) {
      throw StateError('Member name is required');
    }

    _memberCounter += 1;
    final member = LibraryMember(
      id: 'mem_$_memberCounter',
      name: name,
      memberType: request.memberType,
      identifier: request.identifier.trim(),
      classOrDepartment: request.classOrDepartment.trim(),
      activeLoans: 0,
      status: LibraryMemberStatus.active,
      sisStudentId: request.sisStudentId,
    );
    _members.insert(0, member);
    return member;
  }

  @override
  Future<LibraryFine> waiveFine({
    required RepositoryQuery query,
    required WaiveLibraryFineRequest request,
  }) async {
    final index = _fines.indexWhere((fine) => fine.id == request.fineId);
    if (index < 0) {
      throw StateError('Fine not found: ${request.fineId}');
    }
    final fine = _fines[index];
    if (fine.status == LibraryFineStatus.waived) {
      throw StateError('Fine already waived');
    }
    final waived = LibraryFine(
      id: fine.id,
      memberName: fine.memberName,
      bookTitle: fine.bookTitle,
      amount: fine.amount,
      daysOverdue: fine.daysOverdue,
      status: LibraryFineStatus.waived,
      financeLinked: fine.financeLinked,
      sisStudentId: fine.sisStudentId,
    );
    _fines[index] = waived;
    return waived;
  }

  @override
  Future<LibraryBook> updateLibraryBook({
    required RepositoryQuery query,
    required String id,
    required UpdateLibraryBookRequest request,
  }) async {
    final index = _books.indexWhere((book) => book.id == id);
    if (index < 0) {
      throw StateError('Book not found: $id');
    }
    final isbn = request.isbn.trim();
    final title = request.title.trim();
    if (isbn.isEmpty || title.isEmpty) {
      throw StateError('ISBN and title are required');
    }
    // ISBN stays unique per school; a book may keep its OWN isbn (skip self).
    if (_books.any((book) => book.id != id && book.isbn == isbn)) {
      throw StateError('A book with ISBN $isbn already exists');
    }

    final existing = _books[index];
    final onLoan =
        (existing.totalCopies - existing.availableCopies).clamp(0, existing.totalCopies);
    final nextTotal = request.totalCopies < onLoan
        ? onLoan
        : (request.totalCopies < 1 ? 1 : request.totalCopies);
    final nextAvailable = (nextTotal - onLoan).clamp(0, nextTotal);

    final updated = LibraryBook(
      id: id,
      isbn: isbn,
      title: title,
      author: request.author.trim(),
      category: request.category.trim(),
      totalCopies: nextTotal,
      availableCopies: nextAvailable,
      shelf: request.shelf.trim(),
      status: nextAvailable <= 0
          ? LibraryBookStatus.issued
          : LibraryBookStatus.available,
    );
    _books[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteLibraryBook({
    required RepositoryQuery query,
    required String id,
  }) async {
    final index = _books.indexWhere((book) => book.id == id);
    if (index < 0) {
      throw StateError('Book not found: $id');
    }
    final isbn = _books[index].isbn;
    // Block deletion while any copy is on an active loan (mirrors backend).
    final onLoan = _issues.any(
      (issue) =>
          issue.isbn == isbn && issue.status != LibraryLoanStatus.returned,
    );
    if (onLoan) {
      throw StateError(
        'Cannot delete a book while a copy is on an active loan — return it first',
      );
    }
    _books.removeAt(index);
  }

  @override
  Future<ImportResult> bulkImportBooks({
    required RepositoryQuery query,
    required BulkImportBooksRequest request,
  }) async {
    if (request.rows.isEmpty) {
      throw StateError('books must be a non-empty array of book rows');
    }
    final seenIsbns = {
      for (final book in _books)
        if (book.isbn.isNotEmpty) book.isbn,
    };
    var imported = 0;
    final failed = <ImportFailure>[];

    for (var i = 0; i < request.rows.length; i++) {
      final rowNum = i + 1;
      final row = request.rows[i];
      final isbn = row.isbn.trim();
      final title = row.title.trim();
      if (isbn.isEmpty || title.isEmpty) {
        failed.add(ImportFailure(row: rowNum, reason: 'ISBN and title are required'));
        continue;
      }
      if (seenIsbns.contains(isbn)) {
        failed.add(ImportFailure(
          row: rowNum,
          reason: 'A book with this ISBN already exists',
        ));
        continue;
      }
      final total = (row.totalCopies ?? 1) < 1 ? 1 : row.totalCopies!;
      _bookCounter += 1;
      _books.insert(
        0,
        LibraryBook(
          id: 'bk_$_bookCounter',
          isbn: isbn,
          title: title,
          author: row.author.trim(),
          category: (row.category ?? '').trim().isEmpty
              ? 'General'
              : row.category!.trim(),
          totalCopies: total,
          availableCopies: total,
          shelf: (row.shelf ?? '').trim().isEmpty ? 'Unshelved' : row.shelf!.trim(),
          status: LibraryBookStatus.available,
        ),
      );
      seenIsbns.add(isbn);
      imported += 1;
    }
    return ImportResult(imported: imported, failed: failed);
  }

  @override
  Future<LibraryIssueRecord> renewLibraryLoan({
    required RepositoryQuery query,
    required String issueId,
  }) async {
    final index = _issues.indexWhere((issue) => issue.id == issueId);
    if (index < 0) {
      throw StateError('Issue not found: $issueId');
    }
    final issue = _issues[index];
    if (issue.status == LibraryLoanStatus.returned) {
      throw StateError('Cannot renew a returned loan');
    }
    final currentRenewals = _renewalCounts[issueId] ?? 0;
    if (currentRenewals >= _settings.maxRenewals) {
      throw StateError('Renewal limit reached');
    }
    _renewalCounts[issueId] = currentRenewals + 1;

    // Renewal clears an overdue loan back to active and pushes the due date.
    final renewed = LibraryIssueRecord(
      id: issue.id,
      memberName: issue.memberName,
      memberType: issue.memberType,
      bookTitle: issue.bookTitle,
      isbn: issue.isbn,
      issuedDate: issue.issuedDate,
      dueDate: '27 Jun 2026',
      status: LibraryLoanStatus.active,
      sisStudentId: issue.sisStudentId,
    );
    _issues[index] = renewed;
    return renewed;
  }

  @override
  Future<List<OverdueLoan>> getOverdueLoans({
    required RepositoryQuery query,
  }) async {
    // Mirror the backend `overdueList` shape: open loans marked overdue, each
    // with an accrued fine (mock uses a fixed 2-day accrual like returns).
    return [
      for (final issue in _issues)
        if (issue.status == LibraryLoanStatus.overdue)
          OverdueLoan(
            issueId: issue.id,
            memberName: issue.memberName,
            memberType: issue.memberType,
            bookTitle: issue.bookTitle,
            isbn: issue.isbn,
            dueDate: issue.dueDate,
            daysOverdue: 2,
            accruedFine: '₹10',
            sisStudentId: issue.sisStudentId,
          ),
    ];
  }

  @override
  Future<int> sendOverdueReminder({required RepositoryQuery query}) async {
    return _issues
        .where((issue) => issue.status == LibraryLoanStatus.overdue)
        .length;
  }

  @override
  Future<LibrarySettings> getLibrarySettings({
    required RepositoryQuery query,
  }) async {
    return _settings;
  }

  @override
  Future<LibrarySettings> updateLibrarySettings({
    required RepositoryQuery query,
    required LibrarySettings settings,
  }) async {
    _settings = LibrarySettings(
      maxBooksPerMember:
          settings.maxBooksPerMember < 1 ? 1 : settings.maxBooksPerMember,
      maxRenewals: settings.maxRenewals < 0 ? 0 : settings.maxRenewals,
      blockOnFineThreshold:
          settings.blockOnFineThreshold < 0 ? 0 : settings.blockOnFineThreshold,
    );
    return _settings;
  }
}
