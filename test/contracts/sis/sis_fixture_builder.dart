import 'package:akshara_erp/core/repositories/api/sis/dto/sis_enum_codec.dart';
import 'package:akshara_erp/features/sis/sis_models.dart';

/// Builds API-shaped JSON envelopes from SIS domain models for contract tests.
class SisFixtureBuilder {
  const SisFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> dashboardEnvelope(SisDashboardData data) {
    return envelope({
      'aiInsight': data.aiInsight,
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
      'classDistribution': [
        for (final segment in data.classDistribution)
          {
            'label': segment.label,
            'count': segment.count,
            'percent': segment.percent,
          },
      ],
      'genderDistribution': [
        for (final segment in data.genderDistribution)
          {
            'label': segment.label,
            'count': segment.count,
            'percent': segment.percent,
          },
      ],
      'recentEnrollments': [
        for (final enrollment in data.recentEnrollments)
          {
            'id': enrollment.id,
            'studentName': enrollment.studentName,
            'admissionNumber': enrollment.admissionNumber,
            'classLabel': enrollment.classLabel,
            'section': enrollment.section,
            'enrolledAt': enrollment.enrolledAt,
            'status': SisEnumCodec.studentStatusToApi(enrollment.status),
          },
      ],
    });
  }

  Map<String, dynamic> studentItem(SisStudent student) => {
        'id': student.id,
        'studentName': student.studentName,
        'admissionNumber': student.admissionNumber,
        'classLabel': student.classLabel,
        'section': student.section,
        'academicYear': student.academicYear,
        'status': SisEnumCodec.studentStatusToApi(student.status),
        'gender': student.gender,
        'dateOfBirth': student.dateOfBirth,
        'guardianName': student.guardianName,
        'phone': student.phone,
        'email': student.email,
        'enrolledAt': student.enrolledAt,
        if (student.feeAccountId != null) 'feeAccountId': student.feeAccountId,
      };

  Map<String, dynamic> profileEnvelope(SisStudentProfile profile) {
    return envelope({
      'student': studentItem(profile.student),
      'parent': {
        'guardianName': profile.parent.guardianName,
        'relationship': profile.parent.relationship,
        'phone': profile.parent.phone,
        'email': profile.parent.email,
        'address': profile.parent.address,
      },
      'academicHistory': [
        for (final entry in profile.academicHistory)
          {
            'academicYear': entry.academicYear,
            'classLabel': entry.classLabel,
            'section': entry.section,
            'result': entry.result,
          },
      ],
      if (profile.feeAccount != null)
        'feeAccount': {
          'feeStructureName': profile.feeAccount!.feeStructureName,
          'totalDue': profile.feeAccount!.totalDue,
          'totalPaid': profile.feeAccount!.totalPaid,
          'balance': profile.feeAccount!.balance,
          'status': profile.feeAccount!.status,
        },
      'attendance': {
        'presentPercent': profile.attendance.presentPercent,
        'absentDays': profile.attendance.absentDays,
        'lateDays': profile.attendance.lateDays,
        'periodLabel': profile.attendance.periodLabel,
      },
      'documents': [
        for (final document in profile.documents)
          {
            'type': document.type,
            'status': document.status,
            'uploadedAt': document.uploadedAt,
          },
      ],
      'timeline': [
        for (final event in profile.timeline)
          {
            'dateLabel': event.dateLabel,
            'title': event.title,
            'detail': event.detail,
          },
      ],
    });
  }

  Map<String, dynamic> academicAssignmentEnvelope(
    SisAcademicAssignmentData data,
  ) {
    return envelope({
      'classOptions': data.classOptions,
      'sectionOptions': data.sectionOptions,
      'academicYearOptions': data.academicYearOptions,
    });
  }

  Map<String, dynamic> conversionItem(SisEnrollmentQueueItem item) {
    final enrollment = item.enrollment;
    return {
      'id': enrollment.id,
      'studentName': enrollment.studentName,
      'applicationId': enrollment.applicationId,
      'seekingClass': enrollment.seekingClass,
      'section': enrollment.section,
      'academicYear': enrollment.academicYear,
      'guardianName': enrollment.guardianName,
      'phone': enrollment.phone,
      'submittedAt': enrollment.submittedAt,
      'conversionStatus':
          SisEnumCodec.conversionStatusToApi(enrollment.conversionStatus),
      'effectiveStatus': SisEnumCodec.conversionStatusToApi(item.effectiveStatus),
      if (enrollment.generatedAdmissionNumber != null)
        'generatedAdmissionNumber': enrollment.generatedAdmissionNumber,
      if (enrollment.previewStudentId != null)
        'previewStudentId': enrollment.previewStudentId,
      'gender': enrollment.gender,
      'dateOfBirth': enrollment.dateOfBirth,
    };
  }

  Map<String, dynamic> conversionEnvelope(SisAdmissionsConversionData data) {
    return envelope({
      'items': [for (final item in data.queue) conversionItem(item)],
    });
  }

  Map<String, dynamic> conversionPreviewEnvelope(SisConversionPreview preview) {
    return envelope({
      'studentId': preview.studentId,
      'admissionNumber': preview.admissionNumber,
      'studentName': preview.studentName,
      'classLabel': preview.classLabel,
      'section': preview.section,
      'academicYear': preview.academicYear,
    });
  }

  Map<String, dynamic> studentEnvelope(SisStudent student) => envelope(
        studentItem(student),
      );
}
