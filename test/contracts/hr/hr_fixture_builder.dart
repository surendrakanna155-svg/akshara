import 'package:akshara_erp/core/repositories/api/hr/dto/hr_enum_codec.dart';
import 'package:akshara_erp/features/hr/hr_models.dart';

/// Builds API-shaped JSON envelopes from HR domain models for contract tests.
class HrFixtureBuilder {
  const HrFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> trendPoint(HrTrendPoint point) => {
        'label': point.label,
        'amountLakhs': point.amountLakhs,
        'targetLakhs': point.targetLakhs,
      };

  Map<String, dynamic> segment(HrSegment segment) => {
        'label': segment.label,
        'value': segment.value,
        'percent': segment.percent,
      };

  Map<String, dynamic> employeeItem(HrEmployee employee) => {
        'id': employee.id,
        'name': employee.name,
        'employeeCode': employee.employeeCode,
        'department': HrEnumCodec.departmentToApi(employee.department),
        'role': HrEnumCodec.employeeRoleToApi(employee.role),
        'designation': employee.designation,
        'email': employee.email,
        'phone': employee.phone,
        'joinDate': employee.joinDate,
        'status': HrEnumCodec.employeeStatusToApi(employee.status),
        if (employee.teacherAppLinked != null)
          'teacherAppLinked': employee.teacherAppLinked,
        if (employee.classLabel != null) 'classLabel': employee.classLabel,
      };

  Map<String, dynamic> attendanceRecord(HrAttendanceRecord record) => {
        'id': record.id,
        'employeeId': record.employeeId,
        'employeeName': record.employeeName,
        'department': HrEnumCodec.departmentToApi(record.department),
        'date': record.date,
        'checkIn': record.checkIn,
        'checkOut': record.checkOut,
        'status': HrEnumCodec.attendanceStatusToApi(record.status),
        'geoVerified': record.geoVerified,
        'faceVerified': record.faceVerified,
      };

  Map<String, dynamic> candidateItem(HrCandidate candidate) => {
        'id': candidate.id,
        'name': candidate.name,
        'role': candidate.role,
        'department': HrEnumCodec.departmentToApi(candidate.department),
        'appliedOn': candidate.appliedOn,
        'stage': HrEnumCodec.recruitmentStageToApi(candidate.stage),
        'experience': candidate.experience,
        'source': candidate.source,
      };

  Map<String, dynamic> dashboardEnvelope(HrDashboardData data) {
    return envelope({
      'aiInsight': data.aiInsight,
      'managementKpiNote': data.managementKpiNote,
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
      'headcountTrend': [
        for (final point in data.headcountTrend) trendPoint(point),
      ],
      'attendanceTrend': [
        for (final point in data.attendanceTrend) trendPoint(point),
      ],
      'pendingLeave': [
        for (final item in data.pendingLeave)
          {
            'id': item.id,
            'employeeName': item.employeeName,
            'leaveType': HrEnumCodec.leaveTypeToApi(item.leaveType),
            'days': item.days,
            'submittedOn': item.submittedOn,
          },
      ],
      'recruitmentSnapshot': [
        for (final candidate in data.recruitmentSnapshot) candidateItem(candidate),
      ],
    });
  }

  Map<String, dynamic> employeeDetailEnvelope(HrEmployeeDetail detail) {
    return envelope({
      'employee': employeeItem(detail.employee),
      'reportingManager': detail.reportingManager,
      'address': detail.address,
      'emergencyContact': detail.emergencyContact,
      'leaveBalances': [
        for (final balance in detail.leaveBalances)
          {
            'leaveType': HrEnumCodec.leaveTypeToApi(balance.leaveType),
            'available': balance.available,
            'used': balance.used,
          },
      ],
      'documents': [
        for (final document in detail.documents)
          {
            'id': document.id,
            'title': document.title,
            'uploadedOn': document.uploadedOn,
            'status': document.status,
          },
      ],
      'recentAttendance': [
        for (final record in detail.recentAttendance) attendanceRecord(record),
      ],
      'integrationNotes': detail.integrationNotes,
    });
  }

  Map<String, dynamic> attendanceEnvelope(HrAttendanceData data) {
    return envelope({
      'records': [for (final record in data.records) attendanceRecord(record)],
      'attendanceTrend': [
        for (final point in data.attendanceTrend) trendPoint(point),
      ],
      'departmentBreakdown': [
        for (final segment in data.departmentBreakdown) this.segment(segment),
      ],
      'summaryNote': data.summaryNote,
    });
  }

  Map<String, dynamic> leaveEnvelope(HrLeaveData data) {
    return envelope({
      'pendingCount': data.pendingCount,
      'integrationNote': data.integrationNote,
      'requests': [
        for (final request in data.requests)
          {
            'id': request.id,
            'employeeId': request.employeeId,
            'employeeName': request.employeeName,
            'department': HrEnumCodec.departmentToApi(request.department),
            'leaveType': HrEnumCodec.leaveTypeToApi(request.leaveType),
            'fromDate': request.fromDate,
            'toDate': request.toDate,
            'days': request.days,
            'status': HrEnumCodec.leaveStatusToApi(request.status),
            'approver': request.approver,
            'reason': request.reason,
          },
      ],
      'leaveByType': [
        for (final segment in data.leaveByType) this.segment(segment),
      ],
    });
  }

  Map<String, dynamic> payrollEnvelope(HrPayrollData data) {
    return envelope({
      'financeIntegrationNote': data.financeIntegrationNote,
      'financeRoute': data.financeRoute,
      'runs': [
        for (final run in data.runs)
          {
            'id': run.id,
            'period': run.period,
            'employeeCount': run.employeeCount,
            'grossAmount': run.grossAmount,
            'netAmount': run.netAmount,
            'status': HrEnumCodec.payrollStatusToApi(run.status),
            'processedOn': run.processedOn,
          },
      ],
      'entries': [
        for (final entry in data.entries)
          {
            'id': entry.id,
            'employeeId': entry.employeeId,
            'employeeName': entry.employeeName,
            'department': HrEnumCodec.departmentToApi(entry.department),
            'basicPay': entry.basicPay,
            'allowances': entry.allowances,
            'deductions': entry.deductions,
            'netPay': entry.netPay,
            'status': HrEnumCodec.payrollStatusToApi(entry.status),
          },
      ],
      'salaryTrend': [
        for (final point in data.salaryTrend) trendPoint(point),
      ],
    });
  }

  Map<String, dynamic> recruitmentEnvelope(HrRecruitmentData data) {
    return envelope({
      'openPositions': data.openPositions,
      'candidates': [
        for (final candidate in data.candidates) candidateItem(candidate),
      ],
      'pipelineCounts': [
        for (final segment in data.pipelineCounts) this.segment(segment),
      ],
      'hiringTrend': [
        for (final point in data.hiringTrend) trendPoint(point),
      ],
    });
  }

  Map<String, dynamic> performanceEnvelope(HrPerformanceData data) {
    return envelope({
      'managementInsight': data.managementInsight,
      'reviews': [
        for (final review in data.reviews)
          {
            'id': review.id,
            'employeeId': review.employeeId,
            'employeeName': review.employeeName,
            'department': HrEnumCodec.departmentToApi(review.department),
            'cycle': HrEnumCodec.reviewCycleToApi(review.cycle),
            'rating': review.rating,
            'status': HrEnumCodec.reviewStatusToApi(review.status),
            'reviewer': review.reviewer,
            'dueDate': review.dueDate,
          },
      ],
      'ratingDistribution': [
        for (final segment in data.ratingDistribution) this.segment(segment),
      ],
      'completionTrend': [
        for (final point in data.completionTrend) trendPoint(point),
      ],
    });
  }

  Map<String, dynamic> settingsEnvelope(HrSettingsData data) {
    return envelope({
      'defaultDepartment': HrEnumCodec.departmentToApi(data.defaultDepartment),
      'sections': [
        for (final section in data.sections)
          {
            'id': section.id,
            'title': section.title,
            'items': [
              for (final item in section.items)
                {
                  'id': item.id,
                  'label': item.label,
                  'value': item.value,
                  'description': item.description,
                  'editable': item.editable,
                },
            ],
          },
      ],
    });
  }
}
