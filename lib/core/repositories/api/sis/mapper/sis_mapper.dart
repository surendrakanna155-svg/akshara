import '../../../../../features/admissions/admissions_models.dart';
import '../../../../../features/sis/sis_models.dart';
import '../dto/sis_academic_assignment_dto.dart';
import '../dto/sis_conversion_dto.dart';
import '../dto/sis_dashboard_dto.dart';
import '../dto/sis_enum_codec.dart';
import '../dto/sis_student_profile_dto.dart';
import '../dto/sis_students_dto.dart';

/// Maps SIS API DTOs to domain models.
class SisMapper {
  const SisMapper();

  SisDashboardData toDashboard(SisDashboardDto dto) {
    final raw = dto.raw;
    if (raw.containsKey('totalStudents')) {
      return _toDashboardFromApi(raw);
    }
    return SisDashboardData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      classDistribution: _mapDistribution(
        raw['classDistribution'] as List<dynamic>? ?? const [],
      ),
      genderDistribution: _mapDistribution(
        raw['genderDistribution'] as List<dynamic>? ?? const [],
      ),
      recentEnrollments: _mapRecentEnrollments(
        raw['recentEnrollments'] as List<dynamic>? ?? const [],
      ),
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  SisDashboardData _toDashboardFromApi(Map<String, dynamic> raw) {
    final kpis = raw['kpis'] as List<dynamic>?;
    if (kpis != null && kpis.isNotEmpty) {
      return SisDashboardData(
        kpis: _mapKpis(kpis),
        classDistribution: _mapDistribution(
          raw['classDistribution'] as List<dynamic>? ?? const [],
        ),
        genderDistribution: _mapDistribution(
          raw['genderDistribution'] as List<dynamic>? ?? const [],
        ),
        recentEnrollments: _mapRecentEnrollments(
          raw['recentEnrollments'] as List<dynamic>? ?? const [],
        ),
        aiInsight: raw['aiInsight'] as String? ?? '',
      );
    }

    String formatCount(dynamic value) => '${value ?? 0}';

    return SisDashboardData(
      kpis: [
        SisKpi(
          id: 'total_students',
          value: formatCount(raw['totalStudents']),
          label: 'Total Students',
          icon: SisEnumCodec.iconForKpi(null, 'primary'),
          accentName: 'primary',
        ),
        SisKpi(
          id: 'recent_admissions',
          value: formatCount(raw['recentAdmissions']),
          label: 'Recent Admissions (30d)',
          icon: SisEnumCodec.iconForKpi(null, 'success'),
          accentName: 'success',
        ),
        SisKpi(
          id: 'active_students',
          value: formatCount(raw['activeStudents']),
          label: 'Active Students',
          icon: SisEnumCodec.iconForKpi(null, 'success'),
          accentName: 'success',
        ),
        SisKpi(
          id: 'pending_conversion',
          value: formatCount(raw['pendingConversions']),
          label: 'Pending Conversion',
          icon: SisEnumCodec.iconForKpi(null, 'warning'),
          accentName: 'warning',
        ),
        SisKpi(
          id: 'current_enrollments',
          value: formatCount(raw['currentEnrollments']),
          label: 'Current Enrollments',
          icon: SisEnumCodec.iconForKpi(null, 'neutral'),
          accentName: 'neutral',
        ),
        SisKpi(
          id: 'classes',
          value: formatCount(raw['distinctClasses']),
          label: 'Classes',
          icon: SisEnumCodec.iconForKpi(null, 'neutral'),
          accentName: 'neutral',
        ),
        SisKpi(
          id: 'sections',
          value: formatCount(raw['distinctSections']),
          label: 'Sections',
          icon: SisEnumCodec.iconForKpi(null, 'neutral'),
          accentName: 'neutral',
        ),
      ],
      classDistribution: _mapDistribution(
        raw['classDistribution'] as List<dynamic>? ?? const [],
      ),
      genderDistribution: _mapDistribution(
        raw['genderDistribution'] as List<dynamic>? ?? const [],
      ),
      recentEnrollments: _mapRecentEnrollments(
        raw['recentEnrollments'] as List<dynamic>? ?? const [],
      ),
      aiInsight: raw['aiInsight'] as String? ?? '',
    );
  }

  List<SisStudent> toStudents(SisStudentsResponseDto dto) {
    return [for (final item in dto.items) toStudent(item)];
  }

  SisStudent toStudent(SisStudentDto dto) {
    final raw = dto.raw;
    if (raw.containsKey('studentId') || raw.containsKey('student_id')) {
      return toStudentFromDirectory(raw);
    }
    if (raw.containsKey('student') && raw['student'] is Map<String, dynamic>) {
      return toStudentFromDetail(raw);
    }
    return toStudentFromLegacy(raw);
  }

  SisStudent toStudentFromDirectory(Map<String, dynamic> raw) {
    return SisStudent(
      id: raw['studentId'] as String? ?? raw['student_id'] as String? ?? '',
      studentName: raw['displayName'] as String? ??
          raw['display_name'] as String? ??
          raw['studentName'] as String? ??
          '',
      admissionNumber: raw['admissionNumber'] as String? ??
          raw['admission_number'] as String? ??
          '',
      classLabel: raw['className'] as String? ??
          raw['class_name'] as String? ??
          raw['classLabel'] as String? ??
          '',
      section: raw['sectionName'] as String? ??
          raw['section_name'] as String? ??
          raw['section'] as String? ??
          '',
      academicYear: raw['academicYear'] as String? ??
          raw['academic_year'] as String? ??
          '',
      status: SisEnumCodec.parseStudentStatus(raw['status'] as String?),
      gender: raw['gender'] as String? ?? '',
      dateOfBirth: raw['dateOfBirth'] as String? ??
          raw['date_of_birth'] as String? ??
          '',
      guardianName: raw['guardianName'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
      email: raw['email'] as String? ?? '',
      enrolledAt: raw['createdAt'] as String? ??
          raw['created_at'] as String? ??
          raw['enrolledAt'] as String? ??
          '',
      feeAccountId: raw['feeAccountId'] as String?,
    );
  }

  SisStudent toStudentFromDetail(Map<String, dynamic> raw) {
    final studentRaw = raw['student'] as Map<String, dynamic>? ?? raw;
    final profileRaw = raw['profile'] as Map<String, dynamic>?;
    final enrollmentRaw = raw['currentEnrollment'] as Map<String, dynamic>?;
    final guardians = raw['guardians'] as List<dynamic>? ?? const [];
    final primaryGuardian = guardians.isNotEmpty && guardians.first is Map
        ? guardians.first as Map<String, dynamic>
        : null;

    return SisStudent(
      id: studentRaw['id'] as String? ?? '',
      studentName: studentRaw['displayName'] as String? ??
          studentRaw['display_name'] as String? ??
          '',
      admissionNumber: profileRaw?['admissionNumber'] as String? ??
          profileRaw?['admission_number'] as String? ??
          '',
      classLabel: enrollmentRaw?['className'] as String? ??
          enrollmentRaw?['class_name'] as String? ??
          '',
      section: enrollmentRaw?['sectionName'] as String? ??
          enrollmentRaw?['section_name'] as String? ??
          '',
      academicYear: enrollmentRaw?['academicYear'] as String? ??
          enrollmentRaw?['academic_year'] as String? ??
          '',
      status: SisEnumCodec.parseStudentStatus(studentRaw['status'] as String?),
      gender: profileRaw?['gender'] as String? ?? '',
      dateOfBirth: profileRaw?['dateOfBirth'] as String? ??
          profileRaw?['date_of_birth'] as String? ??
          '',
      guardianName: primaryGuardian?['displayName'] as String? ?? '',
      phone: primaryGuardian?['phone'] as String? ?? '',
      email: primaryGuardian?['email'] as String? ?? '',
      enrolledAt: studentRaw['createdAt'] as String? ??
          studentRaw['created_at'] as String? ??
          '',
      feeAccountId: null,
    );
  }

  SisStudent toStudentFromEnrollment(Map<String, dynamic> raw) {
    return SisStudent(
      id: raw['studentId'] as String? ?? raw['student_id'] as String? ?? '',
      studentName:
          raw['studentName'] as String? ?? raw['student_name'] as String? ?? '',
      admissionNumber: '',
      classLabel:
          raw['className'] as String? ?? raw['class_name'] as String? ?? '',
      section:
          raw['sectionName'] as String? ?? raw['section_name'] as String? ?? '',
      academicYear: raw['academicYear'] as String? ??
          raw['academic_year'] as String? ??
          '',
      status: SisStudentStatus.active,
      gender: '',
      dateOfBirth: '',
      guardianName: '',
      phone: '',
      email: '',
      enrolledAt:
          raw['createdAt'] as String? ?? raw['created_at'] as String? ?? '',
    );
  }

  SisStudent toStudentFromLegacy(Map<String, dynamic> raw) {
    return SisStudent(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      admissionNumber: raw['admissionNumber'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      section: raw['section'] as String? ?? '',
      academicYear: raw['academicYear'] as String? ?? '',
      status: SisEnumCodec.parseStudentStatus(raw['status'] as String?),
      gender: raw['gender'] as String? ?? '',
      dateOfBirth: raw['dateOfBirth'] as String? ?? '',
      guardianName: raw['guardianName'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
      email: raw['email'] as String? ?? '',
      enrolledAt: raw['enrolledAt'] as String? ?? '',
      feeAccountId: raw['feeAccountId'] as String?,
    );
  }

  SisStudent toStudentFromWriteResponse(Map<String, dynamic> raw) {
    if (raw.containsKey('parent') || raw.containsKey('academicHistory')) {
      return toStudentProfile(SisStudentProfileDto(raw: raw)).student;
    }
    return toStudentFromDetail(raw);
  }

  SisDocumentSummary toDocumentSummary(Map<String, dynamic> raw) {
    return SisDocumentSummary(
      id: raw['id'] as String?,
      type: raw['type'] as String? ?? '',
      status: raw['status'] as String? ?? '',
      uploadedAt: raw['uploadedAt'] as String? ?? '',
    );
  }

  SisStudentProfile toStudentProfile(SisStudentProfileDto dto) {
    final raw = dto.raw;
    if (raw.containsKey('student') && raw['student'] is Map<String, dynamic>) {
      if (raw.containsKey('parent') || raw.containsKey('academicHistory')) {
        return _toStudentProfileFromLegacyEnvelope(raw);
      }

      final student = toStudentFromDetail(raw);
      final profileRaw = raw['profile'] as Map<String, dynamic>?;
      final enrollmentRaw = raw['currentEnrollment'] as Map<String, dynamic>?;
      final guardians = raw['guardians'] as List<dynamic>? ?? const [];
      final primaryGuardian = guardians.isNotEmpty && guardians.first is Map
          ? guardians.first as Map<String, dynamic>
          : null;

      return SisStudentProfile(
        student: student,
        parent: SisParentDetails(
          guardianName: primaryGuardian?['displayName'] as String? ?? '',
          relationship:
              primaryGuardian?['relationship'] as String? ?? 'Guardian',
          phone: primaryGuardian?['phone'] as String? ?? '',
          email: primaryGuardian?['email'] as String? ?? '',
          address: profileRaw?['address'] as String? ?? '',
        ),
        academicHistory: enrollmentRaw == null
            ? const []
            : [
                SisAcademicHistoryEntry(
                  academicYear: enrollmentRaw['academicYear'] as String? ?? '',
                  classLabel: enrollmentRaw['className'] as String? ?? '',
                  section: enrollmentRaw['sectionName'] as String? ?? '',
                  result: enrollmentRaw['isCurrent'] == true
                      ? 'Current'
                      : 'Historical',
                ),
              ],
        feeAccount: null,
        attendance: const SisAttendanceSummary(
          presentPercent: '—',
          absentDays: 0,
          lateDays: 0,
          periodLabel: '',
        ),
        documents: _mapDocuments(raw['documents'] as List<dynamic>? ?? const []),
        timeline: [
          if (student.enrolledAt.isNotEmpty)
            SisTimelineEvent(
              dateLabel: student.enrolledAt,
              title: 'Student record',
              detail: '${student.classLabel}-${student.section}',
            ),
        ],
      );
    }

    final studentRaw = raw['student'] as Map<String, dynamic>? ?? raw;
    return _toStudentProfileFromLegacyEnvelope({
      ...raw,
      'student': studentRaw,
    });
  }

  SisStudentProfile _toStudentProfileFromLegacyEnvelope(
    Map<String, dynamic> raw,
  ) {
    final studentRaw = raw['student'] as Map<String, dynamic>;
    final parentRaw = raw['parent'] as Map<String, dynamic>? ?? const {};
    final feeRaw = raw['feeAccount'] as Map<String, dynamic>?;
    final attendanceRaw =
        raw['attendance'] as Map<String, dynamic>? ?? const {};

    return SisStudentProfile(
      student: toStudent(SisStudentDto(raw: studentRaw)),
      parent: SisParentDetails(
        guardianName: parentRaw['guardianName'] as String? ?? '',
        relationship: parentRaw['relationship'] as String? ?? 'Guardian',
        phone: parentRaw['phone'] as String? ?? '',
        email: parentRaw['email'] as String? ?? '',
        address: parentRaw['address'] as String? ?? '',
      ),
      academicHistory: _mapAcademicHistory(
        raw['academicHistory'] as List<dynamic>? ?? const [],
      ),
      feeAccount: feeRaw == null ? null : _mapFeeAccount(feeRaw),
      attendance: SisAttendanceSummary(
        presentPercent: attendanceRaw['presentPercent'] as String? ?? '—',
        absentDays: attendanceRaw['absentDays'] as int? ?? 0,
        lateDays: attendanceRaw['lateDays'] as int? ?? 0,
        periodLabel: attendanceRaw['periodLabel'] as String? ?? '',
      ),
      documents: _mapDocuments(raw['documents'] as List<dynamic>? ?? const []),
      timeline: _mapTimeline(raw['timeline'] as List<dynamic>? ?? const []),
    );
  }

  SisAcademicAssignmentData toAcademicAssignment(SisAcademicAssignmentDto dto) {
    final raw = dto.raw;
    return SisAcademicAssignmentData(
      classOptions: _stringList(raw['classOptions']),
      sectionOptions: _stringList(raw['sectionOptions']),
      academicYearOptions: _stringList(raw['academicYearOptions']),
    );
  }

  SisAdmissionsConversionData toAdmissionsConversion(
    SisConversionResponseDto dto,
  ) {
    return SisAdmissionsConversionData(
      queue: [for (final item in dto.items) toConversionQueueItem(item)],
    );
  }

  SisConversionPreview toConversionPreview(SisConversionPreviewDto dto) {
    final raw = dto.raw;
    return SisConversionPreview(
      studentId:
          raw['studentId'] as String? ?? raw['student_id'] as String? ?? '',
      admissionNumber: raw['admissionNumber'] as String? ??
          raw['admission_number'] as String? ??
          '',
      studentName:
          raw['studentName'] as String? ?? raw['student_name'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ??
          raw['class_label'] as String? ??
          raw['className'] as String? ??
          '',
      section: raw['section'] as String? ?? raw['sectionName'] as String? ?? '',
      academicYear: raw['academicYear'] as String? ??
          raw['academic_year'] as String? ??
          '',
    );
  }

  SisEnrollmentQueueItem toConversionQueueItem(SisConversionItemDto dto) {
    final raw = dto.raw;
    final enrollment = PendingEnrollmentRecord(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      applicationId: raw['applicationId'] as String? ?? '',
      seekingClass:
          raw['seekingClass'] as String? ?? raw['classLabel'] as String? ?? '',
      section: raw['section'] as String? ?? '',
      academicYear: raw['academicYear'] as String? ?? '',
      guardianName: raw['guardianName'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
      submittedAt: raw['submittedAt'] as String? ?? '',
      conversionStatus: SisEnumCodec.parseConversionStatus(
        raw['conversionStatus'] as String?,
      ),
      generatedAdmissionNumber: raw['generatedAdmissionNumber'] as String?,
      previewStudentId: raw['previewStudentId'] as String?,
      gender: raw['gender'] as String? ?? '',
      dateOfBirth: raw['dateOfBirth'] as String? ?? '',
    );
    final effectiveStatus = SisEnumCodec.parseConversionStatus(
      raw['effectiveStatus'] as String? ?? raw['conversionStatus'] as String?,
    );
    return SisEnrollmentQueueItem(
      enrollment: enrollment,
      effectiveStatus: effectiveStatus,
    );
  }

  List<SisKpi> _mapKpis(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          SisKpi(
            id: item['id'] as String? ?? '',
            value: item['value'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: SisEnumCodec.iconForKpi(
              item['icon'] as String?,
              item['accentName'] as String?,
            ),
            accentName: item['accentName'] as String? ?? 'neutral',
            detail: item['detail'] as String?,
          ),
    ];
  }

  List<DistributionSegment> _mapDistribution(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          DistributionSegment(
            label: item['label'] as String? ?? '',
            count: item['count'] as int? ?? 0,
            percent: (item['percent'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<RecentEnrollment> _mapRecentEnrollments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          RecentEnrollment(
            id: item['id'] as String? ?? '',
            studentName: item['studentName'] as String? ?? '',
            admissionNumber: item['admissionNumber'] as String? ?? '',
            classLabel: item['classLabel'] as String? ?? '',
            section: item['section'] as String? ?? '',
            enrolledAt: item['enrolledAt'] as String? ?? '',
            status: SisEnumCodec.parseStudentStatus(item['status'] as String?),
          ),
    ];
  }

  List<SisAcademicHistoryEntry> _mapAcademicHistory(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          SisAcademicHistoryEntry(
            academicYear: item['academicYear'] as String? ?? '',
            classLabel: item['classLabel'] as String? ?? '',
            section: item['section'] as String? ?? '',
            result: item['result'] as String? ?? '',
          ),
    ];
  }

  SisFeeAccountSummary _mapFeeAccount(Map<String, dynamic> raw) {
    return SisFeeAccountSummary(
      feeStructureName: raw['feeStructureName'] as String? ?? '',
      totalDue: raw['totalDue'] as String? ?? '',
      totalPaid: raw['totalPaid'] as String? ?? '',
      balance: raw['balance'] as String? ?? '',
      status: raw['status'] as String? ?? '',
    );
  }

  List<SisDocumentSummary> _mapDocuments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          SisDocumentSummary(
            id: item['id'] as String?,
            type: item['type'] as String? ?? '',
            status: item['status'] as String? ?? '',
            uploadedAt: item['uploadedAt'] as String? ?? '',
          ),
    ];
  }

  List<SisTimelineEvent> _mapTimeline(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          SisTimelineEvent(
            dateLabel: item['dateLabel'] as String? ?? '',
            title: item['title'] as String? ?? '',
            detail: item['detail'] as String? ?? '',
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
