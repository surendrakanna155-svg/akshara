import 'package:flutter/material.dart';

import '../../../features/admissions/admissions_models.dart';
import '../../../features/sis/sis_models.dart';
import '../../../features/sis/sis_requests.dart';
import '../interfaces/sis_repository.dart';
import '../paginated_result.dart';
import '../repository_query.dart';
import '../../tenant/tenant_mock_scope.dart';
import 'mock_sis_write_store.dart';

class MockSisRepository implements SisRepository {
  MockSisWriteStore get _store => MockSisWriteStore.instance;

  static const List<SisStudent> _seedStudents = [
    SisStudent(
      id: 'SIS-STU-10421',
      studentName: 'Arjun Patel',
      admissionNumber: 'ADM-2026-0138',
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

  String _generateAdmissionNumber(String enrollmentId) {
    final suffix = enrollmentId.replaceAll('enr_', '').padLeft(4, '0');
    return 'ADM-2026-$suffix';
  }

  @override
  Future<SisDashboardData> getDashboard({required RepositoryQuery query}) async {
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
      documents: const [
        SisDocumentSummary(
          type: 'Birth Certificate',
          status: 'Verified',
          uploadedAt: 'Jan 2026',
        ),
        SisDocumentSummary(
          type: 'Aadhaar',
          status: 'Verified',
          uploadedAt: 'Jan 2026',
        ),
      ],
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
    final index = _store.students!.indexWhere((student) => student.id == studentId);
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
  Future<SisStudent> updateStudentStatus({
    required RepositoryQuery query,
    required String studentId,
    required UpdateStudentStatusRequest request,
  }) async {
    await _ensureStudents(query);
    final index = _store.students!.indexWhere((student) => student.id == studentId);
    if (index < 0) throw StateError('Student not found: $studentId');
    final updated = _store.copyStudent(
      _store.students![index],
      status: request.status,
    );
    _store.students![index] = updated;
    return updated;
  }

  @override
  Future<SisStudent> assignAcademicAssignment({
    required RepositoryQuery query,
    required AcademicAssignmentRequest request,
  }) async {
    await _ensureStudents(query);
    final index =
        _store.students!.indexWhere((student) => student.id == request.studentId);
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
    final index = _store.conversionQueue!.indexWhere(
      (item) => item.enrollment.id == request.enrollmentId,
    );
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
