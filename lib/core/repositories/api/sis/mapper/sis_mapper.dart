import '../../../../../features/admissions/admissions_models.dart';
import '../../../../../features/sis/sis_models.dart';
import '../dto/admissions_conversion_request_dto.dart';
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

  List<SisStudent> toStudents(SisStudentsResponseDto dto) {
    return [for (final item in dto.items) toStudent(item)];
  }

  SisStudent toStudent(SisStudentDto dto) {
    final raw = dto.raw;
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

  SisStudentProfile toStudentProfile(SisStudentProfileDto dto) {
    final raw = dto.raw;
    final studentRaw = raw['student'] as Map<String, dynamic>? ?? raw;
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
      studentId: raw['studentId'] as String? ??
          raw['student_id'] as String? ??
          '',
      admissionNumber: raw['admissionNumber'] as String? ??
          raw['admission_number'] as String? ??
          '',
      studentName: raw['studentName'] as String? ??
          raw['student_name'] as String? ??
          '',
      classLabel: raw['classLabel'] as String? ??
          raw['class_label'] as String? ??
          '',
      section: raw['section'] as String? ?? '',
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
      seekingClass: raw['seekingClass'] as String? ??
          raw['classLabel'] as String? ??
          '',
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
