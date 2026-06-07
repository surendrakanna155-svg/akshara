import '../../../../../features/hr/hr_models.dart';
import '../dto/hr_enum_codec.dart';
import '../dto/hr_responses_dto.dart';

/// Maps HR API DTOs to domain models.
class HrMapper {
  const HrMapper();

  HrDashboardData toDashboard(HrDashboardDto dto) {
    final raw = dto.raw;
    return HrDashboardData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      headcountTrend: _mapTrendPoints(
        raw['headcountTrend'] as List<dynamic>? ?? const [],
      ),
      attendanceTrend: _mapTrendPoints(
        raw['attendanceTrend'] as List<dynamic>? ?? const [],
      ),
      pendingLeave: _mapPendingLeave(
        raw['pendingLeave'] as List<dynamic>? ?? const [],
      ),
      recruitmentSnapshot: _mapCandidates(
        raw['recruitmentSnapshot'] as List<dynamic>? ?? const [],
      ),
      aiInsight: raw['aiInsight'] as String? ?? '',
      managementKpiNote: raw['managementKpiNote'] as String? ?? '',
    );
  }

  List<HrEmployee> toEmployees(HrEmployeesResponseDto dto) {
    return [for (final item in dto.items) toEmployee(item)];
  }

  HrEmployee toEmployee(HrEmployeeDto dto) {
    final raw = dto.raw;
    return HrEmployee(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      employeeCode: raw['employeeCode'] as String? ?? '',
      department: HrEnumCodec.parseDepartment(raw['department'] as String?),
      role: HrEnumCodec.parseEmployeeRole(raw['role'] as String?),
      designation: raw['designation'] as String? ?? '',
      email: raw['email'] as String? ?? '',
      phone: raw['phone'] as String? ?? '',
      joinDate: raw['joinDate'] as String? ?? '',
      status: HrEnumCodec.parseEmployeeStatus(raw['status'] as String?),
      teacherAppLinked: raw['teacherAppLinked'] as bool?,
      classLabel: raw['classLabel'] as String?,
    );
  }

  HrEmployeeDetail? toEmployeeDetail(HrEmployeeDetailDto dto) {
    final raw = dto.raw;
    if (raw.isEmpty) return null;

    final employeeRaw = raw['employee'] as Map<String, dynamic>?;
    if (employeeRaw == null || (employeeRaw['id'] as String?)?.isEmpty == true) {
      return null;
    }

    return HrEmployeeDetail(
      employee: toEmployee(HrEmployeeDto.fromJson(employeeRaw)),
      reportingManager: raw['reportingManager'] as String? ?? '',
      address: raw['address'] as String? ?? '',
      emergencyContact: raw['emergencyContact'] as String? ?? '',
      leaveBalances: _mapLeaveBalances(
        raw['leaveBalances'] as List<dynamic>? ?? const [],
      ),
      documents: _mapDocuments(raw['documents'] as List<dynamic>? ?? const []),
      recentAttendance: _mapAttendanceRecords(
        raw['recentAttendance'] as List<dynamic>? ?? const [],
      ),
      integrationNotes: _stringList(raw['integrationNotes']),
    );
  }

  HrAttendanceData toAttendance(HrAttendanceResponseDto dto) {
    final raw = dto.raw;
    return HrAttendanceData(
      records: _mapAttendanceRecords(
        raw['records'] as List<dynamic>? ?? const [],
      ),
      attendanceTrend: _mapTrendPoints(
        raw['attendanceTrend'] as List<dynamic>? ?? const [],
      ),
      departmentBreakdown: _mapSegments(
        raw['departmentBreakdown'] as List<dynamic>? ?? const [],
      ),
      summaryNote: raw['summaryNote'] as String? ?? '',
    );
  }

  HrLeaveData toLeave(HrLeaveResponseDto dto) {
    final raw = dto.raw;
    return HrLeaveData(
      requests: _mapLeaveRequests(
        raw['requests'] as List<dynamic>? ?? const [],
      ),
      pendingCount: raw['pendingCount'] as int? ?? 0,
      leaveByType: _mapSegments(
        raw['leaveByType'] as List<dynamic>? ?? const [],
      ),
      integrationNote: raw['integrationNote'] as String? ?? '',
    );
  }

  HrPayrollData toPayroll(HrPayrollResponseDto dto) {
    final raw = dto.raw;
    return HrPayrollData(
      runs: _mapPayrollRuns(raw['runs'] as List<dynamic>? ?? const []),
      entries: _mapPayrollEntries(
        raw['entries'] as List<dynamic>? ?? const [],
      ),
      salaryTrend: _mapTrendPoints(
        raw['salaryTrend'] as List<dynamic>? ?? const [],
      ),
      financeIntegrationNote: raw['financeIntegrationNote'] as String? ?? '',
      financeRoute: raw['financeRoute'] as String? ?? '',
    );
  }

  HrRecruitmentData toRecruitment(HrRecruitmentResponseDto dto) {
    final raw = dto.raw;
    return HrRecruitmentData(
      candidates: _mapCandidates(raw['candidates'] as List<dynamic>? ?? const []),
      openPositions: raw['openPositions'] as int? ?? 0,
      pipelineCounts: _mapSegments(
        raw['pipelineCounts'] as List<dynamic>? ?? const [],
      ),
      hiringTrend: _mapTrendPoints(
        raw['hiringTrend'] as List<dynamic>? ?? const [],
      ),
    );
  }

  HrPerformanceData toPerformance(HrPerformanceResponseDto dto) {
    final raw = dto.raw;
    return HrPerformanceData(
      reviews: _mapPerformanceReviews(
        raw['reviews'] as List<dynamic>? ?? const [],
      ),
      ratingDistribution: _mapSegments(
        raw['ratingDistribution'] as List<dynamic>? ?? const [],
      ),
      completionTrend: _mapTrendPoints(
        raw['completionTrend'] as List<dynamic>? ?? const [],
      ),
      managementInsight: raw['managementInsight'] as String? ?? '',
    );
  }

  HrSettingsData toSettings(HrSettingsResponseDto dto) {
    final raw = dto.raw;
    return HrSettingsData(
      sections: _mapSettingsSections(
        raw['sections'] as List<dynamic>? ?? const [],
      ),
      defaultDepartment: HrEnumCodec.parseDepartment(
        raw['defaultDepartment'] as String?,
      ),
    );
  }

  List<HrKpi> _mapKpis(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrKpi(
            id: item['id'] as String? ?? '',
            value: item['value'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: HrEnumCodec.iconForKpi(
              item['icon'] as String?,
              item['accentName'] as String?,
            ),
            accentName: item['accentName'] as String? ?? 'neutral',
            detail: item['detail'] as String?,
          ),
    ];
  }

  List<HrTrendPoint> _mapTrendPoints(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrTrendPoint(
            label: item['label'] as String? ?? '',
            amountLakhs: (item['amountLakhs'] as num?)?.toDouble() ?? 0,
            targetLakhs: (item['targetLakhs'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<HrSegment> _mapSegments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrSegment(
            label: item['label'] as String? ?? '',
            value: (item['value'] as num?)?.toDouble() ?? 0,
            percent: (item['percent'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<HrPendingLeaveItem> _mapPendingLeave(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrPendingLeaveItem(
            id: item['id'] as String? ?? '',
            employeeName: item['employeeName'] as String? ?? '',
            leaveType: HrEnumCodec.parseLeaveType(item['leaveType'] as String?),
            days: item['days'] as int? ?? 0,
            submittedOn: item['submittedOn'] as String? ?? '',
          ),
    ];
  }

  List<HrCandidate> _mapCandidates(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrCandidate(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            role: item['role'] as String? ?? '',
            department: HrEnumCodec.parseDepartment(
              item['department'] as String?,
            ),
            appliedOn: item['appliedOn'] as String? ?? '',
            stage: HrEnumCodec.parseRecruitmentStage(item['stage'] as String?),
            experience: item['experience'] as String? ?? '',
            source: item['source'] as String? ?? '',
          ),
    ];
  }

  List<HrEmployeeLeaveBalance> _mapLeaveBalances(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrEmployeeLeaveBalance(
            leaveType: HrEnumCodec.parseLeaveType(item['leaveType'] as String?),
            available: item['available'] as int? ?? 0,
            used: item['used'] as int? ?? 0,
          ),
    ];
  }

  List<HrEmployeeDocument> _mapDocuments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrEmployeeDocument(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            uploadedOn: item['uploadedOn'] as String? ?? '',
            status: item['status'] as String? ?? '',
          ),
    ];
  }

  List<HrAttendanceRecord> _mapAttendanceRecords(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrAttendanceRecord(
            id: item['id'] as String? ?? '',
            employeeId: item['employeeId'] as String? ?? '',
            employeeName: item['employeeName'] as String? ?? '',
            department: HrEnumCodec.parseDepartment(
              item['department'] as String?,
            ),
            date: item['date'] as String? ?? '',
            checkIn: item['checkIn'] as String? ?? '',
            checkOut: item['checkOut'] as String? ?? '',
            status: HrEnumCodec.parseAttendanceStatus(
              item['status'] as String?,
            ),
            geoVerified: item['geoVerified'] as bool? ?? false,
            faceVerified: item['faceVerified'] as bool? ?? false,
          ),
    ];
  }

  List<HrLeaveRequest> _mapLeaveRequests(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrLeaveRequest(
            id: item['id'] as String? ?? '',
            employeeId: item['employeeId'] as String? ?? '',
            employeeName: item['employeeName'] as String? ?? '',
            department: HrEnumCodec.parseDepartment(
              item['department'] as String?,
            ),
            leaveType: HrEnumCodec.parseLeaveType(item['leaveType'] as String?),
            fromDate: item['fromDate'] as String? ?? '',
            toDate: item['toDate'] as String? ?? '',
            days: item['days'] as int? ?? 0,
            status: HrEnumCodec.parseLeaveStatus(item['status'] as String?),
            approver: item['approver'] as String? ?? '',
            reason: item['reason'] as String? ?? '',
          ),
    ];
  }

  List<HrPayrollRun> _mapPayrollRuns(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrPayrollRun(
            id: item['id'] as String? ?? '',
            period: item['period'] as String? ?? '',
            employeeCount: item['employeeCount'] as int? ?? 0,
            grossAmount: item['grossAmount'] as String? ?? '',
            netAmount: item['netAmount'] as String? ?? '',
            status: HrEnumCodec.parsePayrollStatus(item['status'] as String?),
            processedOn: item['processedOn'] as String? ?? '',
          ),
    ];
  }

  List<HrPayrollEntry> _mapPayrollEntries(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrPayrollEntry(
            id: item['id'] as String? ?? '',
            employeeId: item['employeeId'] as String? ?? '',
            employeeName: item['employeeName'] as String? ?? '',
            department: HrEnumCodec.parseDepartment(
              item['department'] as String?,
            ),
            basicPay: item['basicPay'] as String? ?? '',
            allowances: item['allowances'] as String? ?? '',
            deductions: item['deductions'] as String? ?? '',
            netPay: item['netPay'] as String? ?? '',
            status: HrEnumCodec.parsePayrollStatus(item['status'] as String?),
          ),
    ];
  }

  List<HrPerformanceReview> _mapPerformanceReviews(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrPerformanceReview(
            id: item['id'] as String? ?? '',
            employeeId: item['employeeId'] as String? ?? '',
            employeeName: item['employeeName'] as String? ?? '',
            department: HrEnumCodec.parseDepartment(
              item['department'] as String?,
            ),
            cycle: HrEnumCodec.parseReviewCycle(item['cycle'] as String?),
            rating: item['rating'] as String? ?? '',
            status: HrEnumCodec.parseReviewStatus(item['status'] as String?),
            reviewer: item['reviewer'] as String? ?? '',
            dueDate: item['dueDate'] as String? ?? '',
          ),
    ];
  }

  List<HrSettingsSection> _mapSettingsSections(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrSettingsSection(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            items: _mapSettingItems(item['items'] as List<dynamic>? ?? const []),
          ),
    ];
  }

  List<HrSettingItem> _mapSettingItems(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HrSettingItem(
            id: item['id'] as String? ?? '',
            label: item['label'] as String? ?? '',
            value: item['value'] as String? ?? '',
            description: item['description'] as String? ?? '',
            editable: item['editable'] as bool? ?? false,
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
