import 'package:flutter/material.dart';

import '../../../features/admissions/admissions_models.dart';
import '../../../features/sis/sis_models.dart';
import '../../../features/sis/sis_requests.dart';
import '../../errors/api_failure.dart';
import '../api/sis/dto/sis_enum_codec.dart';
import '../interfaces/sis_repository.dart';
import '../paginated_result.dart';
import '../repository_query.dart';
import '../../tenant/tenant_mock_scope.dart';
import 'mock_admissions_sis_bridge.dart';
import 'mock_alumni_write_store.dart';
import 'mock_sis_write_store.dart';

class MockSisRepository implements SisRepository {
  MockSisWriteStore get _store => MockSisWriteStore.instance;
  static const List<SisDocumentSummary> _seedDocuments = [
    SisDocumentSummary(
      id: 'SIS-DOC-901',
      type: 'Birth Certificate',
      status: 'Verified',
      uploadedAt: 'Jan 2026',
    ),
    SisDocumentSummary(
      id: 'SIS-DOC-902',
      type: 'Aadhaar',
      status: 'Verified',
      uploadedAt: 'Jan 2026',
    ),
    // SIS-3: pending document awaiting a manageSis verify/reject decision.
    SisDocumentSummary(
      id: 'SIS-DOC-903',
      type: 'Transfer Certificate',
      status: 'pending',
      uploadedAt: 'Feb 2026',
    ),
  ];

  // SIS-5: seed exit-log rows (transferred / alumni) for the transfers screen.
  static const List<SisTransferRecord> _seedTransfers = [
    SisTransferRecord(
      studentId: 'SIS-STU-10390',
      studentName: 'Rahul Verma',
      admissionNumber: 'ADM-2024-0031',
      classLabel: '9',
      section: 'B',
      academicYear: '2025–26',
      status: SisStudentStatus.transferred,
      exitedAt: '2026-03-14',
    ),
    SisTransferRecord(
      studentId: 'SIS-STU-10322',
      studentName: 'Sneha Gupta',
      admissionNumber: 'ADM-2019-0007',
      classLabel: '12',
      section: 'A',
      academicYear: '2024–25',
      status: SisStudentStatus.alumni,
      exitedAt: '2025-04-30',
    ),
  ];

  static const List<SisStudent> _seedStudents = [
    SisStudent(
      id: 'SIS-STU-10421',
      studentName: 'Arjun Patel',
      admissionNumber: 'ADM-2026-0138',
      publicStudentId: 'DPSKKP-0001',
      classLabel: '10',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Male',
      dateOfBirth: '14 Jun 2011',
      guardianName: 'Kiran Patel',
      phone: '+91 98765 11111',
      email: 'kiran.patel@email.com',
      enrolledAt: 'Jan 2026',
      feeAccountId: 'acct_1',
    ),
    SisStudent(
      id: 'SIS-STU-10418',
      studentName: 'Emma Thomas',
      admissionNumber: 'ADM-2026-0135',
      publicStudentId: 'DPSKKP-0002',
      classLabel: '7',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Female',
      dateOfBirth: '22 Jan 2014',
      guardianName: 'David Thomas',
      phone: '+91 99887 76655',
      email: 'david.thomas@email.com',
      enrolledAt: 'Jan 2026',
      feeAccountId: 'acct_3',
    ),
    SisStudent(
      id: 'SIS-STU-10415',
      studentName: 'Priya Sharma',
      admissionNumber: 'ADM-2025-0092',
      classLabel: '8',
      section: 'B',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Female',
      dateOfBirth: '03 Sep 2013',
      guardianName: 'Anil Sharma',
      phone: '+91 91234 00092',
      email: 'anil.sharma@email.com',
      enrolledAt: 'Jun 2025',
      feeAccountId: 'acct_4',
    ),
    SisStudent(
      id: 'SIS-STU-10430',
      studentName: 'Ravi Kumar',
      admissionNumber: 'ADM-2026-0842',
      classLabel: '8',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Male',
      dateOfBirth: '14 Mar 2012',
      guardianName: 'Suresh Kumar',
      phone: '+91 98765 43210',
      email: 'suresh.kumar@email.com',
      enrolledAt: 'Jan 2026',
      feeAccountId: 'acct_ravi',
    ),
    SisStudent(
      id: 'SIS-STU-10431',
      studentName: 'Ananya Rao',
      admissionNumber: 'ADM-2026-0843',
      classLabel: '8',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Female',
      dateOfBirth: '02 Aug 2012',
      guardianName: 'Rajesh Rao',
      phone: '+91 91234 08431',
      email: 'rajesh.rao@email.com',
      enrolledAt: 'Jan 2026',
    ),
    SisStudent(
      id: 'SIS-STU-10432',
      studentName: 'Karthik Menon',
      admissionNumber: 'ADM-2026-0844',
      classLabel: '8',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Male',
      dateOfBirth: '19 Nov 2012',
      guardianName: 'Suresh Menon',
      phone: '+91 91234 08432',
      email: 'suresh.menon@email.com',
      enrolledAt: 'Jan 2026',
    ),
    SisStudent(
      id: 'SIS-STU-10433',
      studentName: 'Priya Nair',
      admissionNumber: 'ADM-2026-0845',
      classLabel: '8',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Female',
      dateOfBirth: '25 Jul 2012',
      guardianName: 'Lakshmi Nair',
      phone: '+91 91234 08433',
      email: 'lakshmi.nair@email.com',
      enrolledAt: 'Jan 2026',
    ),
    SisStudent(
      id: 'SIS-STU-10434',
      studentName: 'Meera Iyer',
      admissionNumber: 'ADM-2026-0846',
      classLabel: '8',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Female',
      dateOfBirth: '11 May 2012',
      guardianName: 'Anil Iyer',
      phone: '+91 91234 08434',
      email: 'anil.iyer@email.com',
      enrolledAt: 'Jan 2026',
    ),
    SisStudent(
      id: 'SIS-STU-10410',
      studentName: 'Rohan Mehta',
      admissionNumber: 'ADM-2025-0114',
      classLabel: '9',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: 'Male',
      dateOfBirth: '18 Nov 2012',
      guardianName: 'Sunita Mehta',
      phone: '+91 90001 11400',
      email: 'sunita.mehta@email.com',
      enrolledAt: 'Jun 2025',
    ),
    SisStudent(
      id: 'SIS-STU-10405',
      studentName: 'Kavya Iyer',
      admissionNumber: 'ADM-2025-0101',
      classLabel: '6',
      section: 'C',
      academicYear: '2026–27',
      status: SisStudentStatus.prospect,
      gender: 'Female',
      dateOfBirth: '07 Apr 2015',
      guardianName: 'Lakshmi Iyer',
      phone: '+91 94440 10101',
      email: 'lakshmi.iyer@email.com',
      enrolledAt: 'Pending',
    ),
    SisStudent(
      id: 'SIS-STU-PLH-0001',
      studentName: 'Placeholder · Grade 6A Roll 1',
      admissionNumber: 'PLH-6A-001',
      classLabel: '6',
      section: 'A',
      academicYear: '2026–27',
      status: SisStudentStatus.active,
      gender: '',
      dateOfBirth: '',
      guardianName: '',
      phone: '',
      email: '',
      enrolledAt: 'Generated',
      isPlaceholder: true,
    ),
  ];

  static const List<SisEnrollmentQueueItem> _seedConversionQueue = [
    SisEnrollmentQueueItem(
      enrollment: PendingEnrollmentRecord(
        id: 'enr_1',
        studentName: 'Ananya Reddy',
        applicationId: 'APP-2208',
        seekingClass: '5',
        section: 'A',
        academicYear: '2026–27',
        guardianName: 'Rajesh Reddy',
        phone: '+91 98765 43210',
        submittedAt: 'Today',
        conversionStatus: EnrollmentConversionStatus.pending,
        gender: 'Female',
        dateOfBirth: '12 Mar 2016',
      ),
      effectiveStatus: EnrollmentConversionStatus.pending,
    ),
    SisEnrollmentQueueItem(
      enrollment: PendingEnrollmentRecord(
        id: 'enr_2',
        studentName: 'Vihaan Sharma',
        applicationId: 'APP-2215',
        seekingClass: '8',
        section: 'B',
        academicYear: '2026–27',
        guardianName: 'Priya Sharma',
        phone: '+91 91234 56780',
        submittedAt: 'Yesterday',
        conversionStatus: EnrollmentConversionStatus.pending,
        gender: 'Male',
        dateOfBirth: '05 Aug 2013',
      ),
      effectiveStatus: EnrollmentConversionStatus.pending,
    ),
    SisEnrollmentQueueItem(
      enrollment: PendingEnrollmentRecord(
        id: 'enr_3',
        studentName: 'Emma Thomas',
        applicationId: 'APP-2175',
        seekingClass: '7',
        section: 'A',
        academicYear: '2026–27',
        guardianName: 'David Thomas',
        phone: '+91 99887 76655',
        submittedAt: '3 days ago',
        conversionStatus: EnrollmentConversionStatus.converted,
        generatedAdmissionNumber: 'ADM-2026-0135',
        previewStudentId: 'SIS-STU-10418',
        gender: 'Female',
        dateOfBirth: '22 Jan 2014',
      ),
      effectiveStatus: EnrollmentConversionStatus.converted,
    ),
  ];

  Future<void> _ensureStudents(RepositoryQuery query) async {
    _store.students ??= List.from(_seedStudents);
  }

  Future<void> _ensureConversionQueue(RepositoryQuery query) async {
    _store.conversionQueue ??= List.from(_seedConversionQueue);
  }

  Future<void> _ensureStudentDocuments(RepositoryQuery query) async {
    await _ensureStudents(query);
    _store.studentDocuments ??= {
      for (final student in _store.students!)
        student.id: List<SisDocumentSummary>.from(_seedDocuments),
    };
  }

  String _generateAdmissionNumber(String enrollmentId) {
    final suffix = enrollmentId.replaceAll('enr_', '').padLeft(4, '0');
    return 'ADM-2026-$suffix';
  }

  @override
  Future<SisDashboardData> getDashboard(
      {required RepositoryQuery query}) async {
    return const SisDashboardData(
      kpis: [
        SisKpi(
          id: 'total_students',
          value: '1,248',
          label: 'Total Students',
          icon: Icons.groups_outlined,
          accentName: 'primary',
        ),
        SisKpi(
          id: 'new_admissions',
          value: '36',
          label: 'New Admissions (MTD)',
          icon: Icons.person_add_outlined,
          accentName: 'success',
          detail: '+8 this week',
        ),
        SisKpi(
          id: 'active_students',
          value: '1,198',
          label: 'Active Students',
          icon: Icons.verified_outlined,
          accentName: 'success',
        ),
        SisKpi(
          id: 'pending_conversion',
          value: '2',
          label: 'Pending Conversion',
          icon: Icons.swap_horiz_outlined,
          accentName: 'warning',
        ),
        SisKpi(
          id: 'classes',
          value: '14',
          label: 'Classes',
          icon: Icons.class_outlined,
          accentName: 'neutral',
        ),
        SisKpi(
          id: 'sections',
          value: '42',
          label: 'Sections',
          icon: Icons.grid_view_outlined,
          accentName: 'neutral',
        ),
      ],
      classDistribution: [
        DistributionSegment(label: 'Primary (1–5)', count: 412, percent: 33),
        DistributionSegment(label: 'Middle (6–8)', count: 378, percent: 30),
        DistributionSegment(label: 'Secondary (9–10)', count: 298, percent: 24),
        DistributionSegment(label: 'Senior (11–12)', count: 160, percent: 13),
      ],
      genderDistribution: [
        DistributionSegment(label: 'Male', count: 648, percent: 52),
        DistributionSegment(label: 'Female', count: 592, percent: 47),
        DistributionSegment(label: 'Other', count: 8, percent: 1),
      ],
      recentEnrollments: [
        RecentEnrollment(
          id: 'enr_r1',
          studentName: 'Arjun Patel',
          admissionNumber: 'ADM-2026-0138',
          classLabel: '10',
          section: 'A',
          enrolledAt: 'Today',
          status: SisStudentStatus.active,
        ),
        RecentEnrollment(
          id: 'enr_r2',
          studentName: 'Emma Thomas',
          admissionNumber: 'ADM-2026-0135',
          classLabel: '7',
          section: 'A',
          enrolledAt: 'Yesterday',
          status: SisStudentStatus.active,
        ),
        RecentEnrollment(
          id: 'enr_r3',
          studentName: 'Ananya Reddy',
          admissionNumber: 'ADM-2026-0142',
          classLabel: '5',
          section: 'A',
          enrolledAt: 'Pending',
          status: SisStudentStatus.prospect,
        ),
      ],
      aiInsight:
          'Class 5-A has 3 pending admissions conversions. Complete SIS registration before fee assignment to avoid billing delays.',
    );
  }

  @override
  Future<PaginatedResult<SisStudent>> getStudents({
    required RepositoryQuery query,
  }) async {
    await _ensureStudents(query);
    return PaginatedResult.fromItems(
      TenantMockScope.filter(
        query: query,
        items: List.unmodifiable(_store.students!),
      ),
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<SisStudentProfile> getStudentProfile({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    await _ensureStudentDocuments(query);
    final students = (await getStudents(query: query)).items;
    final student = students.firstWhere(
      (item) => item.id == studentId,
      orElse: () => students.first,
    );
    return SisStudentProfile(
      student: student,
      parent: SisParentDetails(
        guardianName: student.guardianName,
        relationship: 'Guardian',
        phone: student.phone,
        email: student.email,
        address: 'Hyderabad, Telangana',
      ),
      academicHistory: [
        SisAcademicHistoryEntry(
          academicYear: student.academicYear,
          classLabel: student.classLabel,
          section: student.section,
          result: 'Enrolled',
        ),
        const SisAcademicHistoryEntry(
          academicYear: '2025–26',
          classLabel: 'Previous',
          section: '—',
          result: 'Promoted',
        ),
      ],
      feeAccount: student.feeAccountId == null
          ? null
          : const SisFeeAccountSummary(
              feeStructureName: 'Standard Annual',
              totalDue: '₹1,20,000',
              totalPaid: '₹45,000',
              balance: '₹75,000',
              status: 'Partial',
            ),
      attendance: const SisAttendanceSummary(
        presentPercent: '94%',
        absentDays: 4,
        lateDays: 2,
        periodLabel: 'This term',
      ),
      documents: List<SisDocumentSummary>.unmodifiable(
        _store.documentsForStudent(student.id),
      ),
      timeline: [
        SisTimelineEvent(
          dateLabel: student.enrolledAt,
          title: 'Enrolled in SIS',
          detail:
              '${student.classLabel}-${student.section} · ${student.academicYear}',
        ),
        const SisTimelineEvent(
          dateLabel: 'Dec 2025',
          title: 'Admission approved',
          detail: 'AD-07 approval completed',
        ),
      ],
    );
  }

  @override
  Future<List<SisSibling>> listStudentSiblings({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    // Read-only sibling view: other in-scope students who share a guardian with
    // the subject, self-excluded. The mock stands in for the backend's shared
    // guardian_user_id join by keying on the guardian name + phone.
    final students = (await getStudents(query: query)).items;
    SisStudent? subject;
    for (final student in students) {
      if (student.id == studentId) {
        subject = student;
        break;
      }
    }
    if (subject == null) return const [];

    final key = _guardianKey(subject);
    if (key == null) return const [];

    final siblings = <SisSibling>[
      for (final student in students)
        if (student.id != subject.id && _guardianKey(student) == key)
          SisSibling(
            studentId: student.id,
            studentName: student.studentName,
            admissionNumber: student.admissionNumber,
            classLabel: student.classLabel,
            section: student.section,
            status: student.status,
          ),
    ];
    siblings.sort((a, b) => a.studentName.compareTo(b.studentName));
    return siblings;
  }

  /// Mock shared-guardian identity: the guardian's name + phone. Null when the
  /// student has no guardian name on record (e.g. placeholder students), so
  /// contact-less students are never grouped as siblings.
  static String? _guardianKey(SisStudent student) {
    final name = student.guardianName.trim().toLowerCase();
    if (name.isEmpty) return null;
    return '$name|${student.phone.trim()}';
  }

  @override
  Future<SisAcademicAssignmentData> getAcademicAssignment({
    required RepositoryQuery query,
  }) async {
    return const SisAcademicAssignmentData(
      classOptions: [
        'Nursery',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '10',
        '11',
        '12',
      ],
      sectionOptions: ['A', 'B', 'C', 'D'],
      academicYearOptions: ['2026–27', '2025–26', '2024–25'],
    );
  }

  @override
  Future<SisAdmissionsConversionData> getAdmissionsConversion({
    required RepositoryQuery query,
  }) async {
    await _ensureConversionQueue(query);
    return SisAdmissionsConversionData(
      queue: List.unmodifiable(_store.conversionQueue!),
    );
  }

  @override
  Future<SisStudent> createStudent({
    required RepositoryQuery query,
    required CreateStudentRequest request,
  }) async {
    await _ensureStudents(query);
    final student = SisStudent(
      id: _store.nextStudentId(),
      studentName: request.studentName,
      admissionNumber: request.admissionNumber,
      classLabel: request.classLabel,
      section: request.section,
      academicYear: request.academicYear,
      status: request.status,
      gender: request.gender,
      dateOfBirth: request.dateOfBirth,
      guardianName: request.guardianName,
      phone: request.phone,
      email: request.email,
      enrolledAt: 'Today',
    );
    _store.students!.insert(0, student);
    return student;
  }

  @override
  Future<SisStudent> updateStudent({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentRequest request,
  }) async {
    await _ensureStudents(query);
    final index =
        _store.students!.indexWhere((student) => student.id == studentId);
    if (index < 0) throw StateError('Student not found: $studentId');
    final updated = _store.copyStudent(
      _store.students![index],
      studentName: request.studentName,
      admissionNumber: request.admissionNumber,
      classLabel: request.classLabel,
      section: request.section,
      academicYear: request.academicYear,
      gender: request.gender,
      dateOfBirth: request.dateOfBirth,
      guardianName: request.guardianName,
      phone: request.phone,
      email: request.email,
    );
    _store.students![index] = updated;
    return updated;
  }

  @override
  Future<SisDocumentSummary> uploadStudentDocument({
    required RepositoryQuery query,
    required String studentId,
    required UploadStudentDocumentRequest request,
  }) async {
    await _ensureStudentDocuments(query);
    final student = _store.findStudent(studentId);
    if (student == null) throw StateError('Student not found: $studentId');
    final document = SisDocumentSummary(
      id: _store.nextDocumentId(),
      type: request.type,
      status: request.status,
      uploadedAt: 'Today',
    );
    _store.documentsForStudent(studentId).insert(0, document);
    return document;
  }

  @override
  Future<SisDocumentSummary> uploadStudentDocumentFile({
    required RepositoryQuery query,
    required String studentId,
    required UploadStudentDocumentRequest request,
    required List<int> bytes,
    required String contentType,
  }) async {
    // PRA-P1-19: the mock has no real Storage; the file bytes are exercised only
    // in the API path. Persist the metadata record so the profile reflects it.
    return uploadStudentDocument(
      query: query,
      studentId: studentId,
      request: request,
    );
  }

  @override
  Future<String> getStudentDocumentDownloadUrl({
    required RepositoryQuery query,
    required String studentId,
    required String documentId,
  }) async {
    return 'https://mock.storage.local/student-documents/$studentId/$documentId';
  }

  @override
  Future<SisDocumentSummary> verifyStudentDocument({
    required RepositoryQuery query,
    required String studentId,
    required String documentId,
    required VerifyStudentDocumentRequest request,
  }) async {
    await _ensureStudentDocuments(query);
    final documents = _store.documentsForStudent(studentId);
    final index = documents.indexWhere((document) => document.id == documentId);
    if (index < 0) throw StateError('Document not found: $documentId');
    final existing = documents[index];
    final updated = SisDocumentSummary(
      id: existing.id,
      type: existing.type,
      status: request.decision.name,
      uploadedAt: existing.uploadedAt,
      verifiedBy: 'school.admin@akshara.demo',
      verifiedAt: _todayIso(),
    );
    documents[index] = updated;
    return updated;
  }

  @override
  Future<PaginatedResult<SisTransferRecord>> listStudentTransfers({
    required RepositoryQuery query,
    String? fromDate,
    String? toDate,
    SisStudentStatus? status,
  }) async {
    await _ensureStudents(query);
    // Seed rows + any student flipped to transferred/alumni at runtime.
    final seedIds = {for (final record in _seedTransfers) record.studentId};
    final records = <SisTransferRecord>[
      ..._seedTransfers,
      for (final student in _store.students!)
        if (!seedIds.contains(student.id) &&
            (student.status == SisStudentStatus.transferred ||
                student.status == SisStudentStatus.alumni))
          SisTransferRecord(
            studentId: student.id,
            studentName: student.studentName,
            admissionNumber: student.admissionNumber,
            classLabel: student.classLabel,
            section: student.section,
            academicYear: student.academicYear,
            status: student.status,
            exitedAt: _todayIso(),
          ),
    ];

    var filtered = TenantMockScope.filter(query: query, items: records);
    if (status != null) {
      filtered =
          filtered.where((record) => record.status == status).toList();
    }
    if (fromDate != null && fromDate.isNotEmpty) {
      filtered = filtered
          .where((record) => _exitDate(record).compareTo(fromDate) >= 0)
          .toList();
    }
    if (toDate != null && toDate.isNotEmpty) {
      filtered = filtered
          .where((record) => _exitDate(record).compareTo(toDate) <= 0)
          .toList();
    }

    return PaginatedResult.fromItems(
      filtered,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  static String _todayIso() =>
      DateTime.now().toIso8601String().substring(0, 10);

  /// ISO date part of the exit timestamp, for lexicographic range filters.
  static String _exitDate(SisTransferRecord record) =>
      record.exitedAt.length >= 10
          ? record.exitedAt.substring(0, 10)
          : record.exitedAt;

  @override
  Future<SisStudent> updateStudentStatus({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentStatusRequest request,
  }) async {
    await _ensureStudents(query);
    final index =
        _store.students!.indexWhere((student) => student.id == studentId);
    if (index < 0) throw StateError('Student not found: $studentId');
    final updated = _store.copyStudent(
      _store.students![index],
      status: request.status,
    );
    _store.students![index] = updated;
    if (request.status == SisStudentStatus.alumni) {
      MockAlumniWriteStore.instance.onboardFromSisStudent(updated);
    }
    return updated;
  }

  // ── SIS-1: certificate issuance + transfer certificate (TC) ─────────────────

  static const String _mockSchoolName = 'NIKSHA Public School';
  static const String _mockSchoolCode = 'DPSKKP';

  SisCertificateData _buildCertificateData(
    SisStudent student, {
    required SisCertificateType type,
    required String issueId,
    required String? serialNo,
    required String? reason,
    required String status,
  }) {
    return SisCertificateData(
      issueId: issueId,
      type: type,
      serialNo: serialNo,
      reason: reason,
      issuedAt: _todayIso(),
      studentName: student.studentName,
      publicStudentId: student.publicStudentId,
      admissionNumber: student.admissionNumber,
      className: student.classLabel,
      section: student.section,
      academicYear: student.academicYear,
      dateOfBirth: student.dateOfBirth,
      rollNumber: '',
      guardianName: student.guardianName,
      status: status,
      schoolName: _mockSchoolName,
      schoolCode: _mockSchoolCode,
    );
  }

  @override
  Future<SisCertificateData> issueCertificate({
    required RepositoryQuery query,
    required String studentId,
    required IssueCertificateRequest request,
  }) async {
    await _ensureStudents(query);
    final student = _store.findStudent(studentId);
    if (student == null) throw StateError('Student not found: $studentId');

    final reason = request.reason?.trim().isEmpty ?? true
        ? null
        : request.reason!.trim();
    final issueId = _store.nextCertificateId();
    _store.certificatesForStudent(studentId).insert(
          0,
          SisCertificateIssue(
            id: issueId,
            type: request.type,
            serialNo: null,
            reason: reason,
            issuedBy: 'school.admin@akshara.demo',
            issuedAt: _todayIso(),
          ),
        );
    return _buildCertificateData(
      student,
      type: request.type,
      issueId: issueId,
      serialNo: null,
      reason: reason,
      status: SisEnumCodec.studentStatusToApi(student.status),
    );
  }

  @override
  Future<SisCertificateData> issueTransferCertificate({
    required RepositoryQuery query,
    required String studentId,
    required IssueTransferCertificateRequest request,
  }) async {
    await _ensureStudents(query);
    final index =
        _store.students!.indexWhere((student) => student.id == studentId);
    if (index < 0) throw StateError('Student not found: $studentId');
    final student = _store.students![index];

    // Mirror the backend TC engine: reject an already-terminal student, enforce
    // the no-dues gate, then allocate a serial + flip status → transferred.
    if (student.status == SisStudentStatus.transferred ||
        student.status == SisStudentStatus.alumni) {
      throw ApiFailureException(
        ApiFailure(
          type: ApiFailureType.unknown,
          message:
              'Cannot issue a Transfer Certificate: student is already ${SisEnumCodec.studentStatusToApi(student.status)}.',
          code: 'VALIDATION_ERROR',
        ),
      );
    }

    // No-dues gate: a student with an open fee account still owes fees in the
    // mock world (the profile fee summary carries a ₹75,000 balance).
    if (student.feeAccountId != null) {
      const outstanding = 75000;
      throw ApiFailureException(
        const ApiFailure(
          type: ApiFailureType.unknown,
          message:
              'Cannot issue a Transfer Certificate: student has $outstanding outstanding in fees. Clear all dues first.',
          code: 'DUES_PENDING',
        ),
      );
    }

    final serialNo =
        _store.nextTcSerial(_mockSchoolCode, student.academicYear);
    final reason = request.reason?.trim().isEmpty ?? true
        ? null
        : request.reason!.trim();
    final issueId = _store.nextCertificateId();

    final transferred =
        _store.copyStudent(student, status: SisStudentStatus.transferred);
    _store.students![index] = transferred;

    _store.certificatesForStudent(studentId).insert(
          0,
          SisCertificateIssue(
            id: issueId,
            type: SisCertificateType.transfer,
            serialNo: serialNo,
            reason: reason,
            issuedBy: 'school.admin@akshara.demo',
            issuedAt: _todayIso(),
          ),
        );

    return _buildCertificateData(
      transferred,
      type: SisCertificateType.transfer,
      issueId: issueId,
      serialNo: serialNo,
      reason: reason,
      status: SisEnumCodec.studentStatusToApi(SisStudentStatus.transferred),
    );
  }

  @override
  Future<List<SisCertificateIssue>> listCertificates({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    await _ensureStudents(query);
    return List<SisCertificateIssue>.unmodifiable(
      _store.certificatesForStudent(studentId),
    );
  }

  @override
  Future<SisStudent> assignAcademicAssignment({
    required RepositoryQuery query,
    required AcademicAssignmentRequest request,
  }) async {
    await _ensureStudents(query);
    final index = _store.students!
        .indexWhere((student) => student.id == request.studentId);
    if (index < 0) throw StateError('Student not found: ${request.studentId}');
    final updated = _store.copyStudent(
      _store.students![index],
      classLabel: request.classLabel,
      section: request.section,
      academicYear: request.academicYear,
    );
    _store.students![index] = updated;
    return updated;
  }

  @override
  Future<SisConversionPreview> convertAdmissionsEnrollment({
    required RepositoryQuery query,
    required AdmissionsConversionRequest request,
  }) async {
    await _ensureStudents(query);
    await _ensureConversionQueue(query);
    var index = _store.conversionQueue!.indexWhere(
      (item) => item.enrollment.id == request.enrollmentId,
    );
    if (index < 0) {
      final linked =
          MockAdmissionsSisBridge.findEnrollment(request.enrollmentId);
      if (linked != null) {
        MockAdmissionsSisBridge.syncEnrollmentToConversionQueue(linked);
        index = _store.conversionQueue!.indexWhere(
          (item) => item.enrollment.id == request.enrollmentId,
        );
      }
    }
    if (index < 0) {
      throw StateError('Enrollment not found: ${request.enrollmentId}');
    }

    final item = _store.conversionQueue![index];
    if (item.effectiveStatus == EnrollmentConversionStatus.converted) {
      final enrollment = item.enrollment;
      return SisConversionPreview(
        studentId: enrollment.previewStudentId ?? '',
        admissionNumber: enrollment.generatedAdmissionNumber ?? '',
        studentName: enrollment.studentName,
        classLabel: request.classLabel,
        section: request.section,
        academicYear: request.academicYear,
      );
    }

    final admissionNumber = _generateAdmissionNumber(request.enrollmentId);
    final studentId = _store.nextStudentId();
    final enrollment = item.enrollment;

    final student = SisStudent(
      id: studentId,
      studentName: enrollment.studentName,
      admissionNumber: admissionNumber,
      classLabel: request.classLabel,
      section: request.section,
      academicYear: request.academicYear,
      status: SisStudentStatus.active,
      gender: enrollment.gender,
      dateOfBirth: enrollment.dateOfBirth,
      guardianName: enrollment.guardianName,
      phone: enrollment.phone,
      email: '',
      enrolledAt: 'Today',
    );
    _store.students!.insert(0, student);

    final updatedEnrollment = _store.copyEnrollment(
      enrollment,
      conversionStatus: EnrollmentConversionStatus.converted,
      generatedAdmissionNumber: admissionNumber,
      previewStudentId: studentId,
      seekingClass: request.classLabel,
      section: request.section,
    );
    _store.conversionQueue![index] = SisEnrollmentQueueItem(
      enrollment: updatedEnrollment,
      effectiveStatus: EnrollmentConversionStatus.converted,
    );

    return SisConversionPreview(
      studentId: studentId,
      admissionNumber: admissionNumber,
      studentName: enrollment.studentName,
      classLabel: request.classLabel,
      section: request.section,
      academicYear: request.academicYear,
    );
  }
}
