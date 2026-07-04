import 'package:flutter/material.dart';

/// HR sub-module destinations (HR-01 → HR-09, excluding HR-03 child route).
enum HrScreen {
  dashboard,
  employees,
  attendance,
  leave,
  payroll,
  recruitment,
  performance,
  reports,
  settings;

  String get label => switch (this) {
        HrScreen.dashboard => 'Dashboard',
        HrScreen.employees => 'Employees',
        HrScreen.attendance => 'Attendance',
        HrScreen.leave => 'Leave',
        HrScreen.payroll => 'Payroll',
        HrScreen.recruitment => 'Recruitment',
        HrScreen.performance => 'Performance',
        HrScreen.reports => 'Reports',
        HrScreen.settings => 'Settings',
      };
}

enum HrEmployeeStatus { active, onLeave, probation, inactive }

enum HrDepartment {
  academics,
  administration,
  transport,
  finance,
  hr,
  support,
}

enum HrEmployeeRole { teacher, driver, admin, principal, staff }

enum HrAttendanceStatus { present, absent, late, onLeave, halfDay }

enum HrLeaveStatus { pending, approved, rejected, cancelled }

enum HrLeaveType { casual, sick, earned, maternity, unpaid }

enum HrRecruitmentStage { applied, screening, interview, selected, joined }

enum HrPayrollStatus { draft, processed, paid, onHold }

enum HrReviewCycle { q1, q2, q3, annual }

enum HrReviewStatus { notStarted, inProgress, completed, overdue }

@immutable
class HrKpi {
  const HrKpi({
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
class HrTrendPoint {
  const HrTrendPoint({
    required this.label,
    required this.amountLakhs,
    required this.targetLakhs,
  });

  final String label;
  final double amountLakhs;
  final double targetLakhs;
}

@immutable
class HrSegment {
  const HrSegment({
    required this.label,
    required this.value,
    required this.percent,
  });

  final String label;
  final double value;
  final double percent;
}

@immutable
class HrEmployee {
  const HrEmployee({
    required this.id,
    required this.name,
    required this.employeeCode,
    required this.department,
    required this.role,
    required this.designation,
    required this.email,
    required this.phone,
    required this.joinDate,
    required this.status,
    this.teacherAppLinked,
    this.classLabel,
  });

  final String id;
  final String name;
  final String employeeCode;
  final HrDepartment department;
  final HrEmployeeRole role;
  final String designation;
  final String email;
  final String phone;
  final String joinDate;
  final HrEmployeeStatus status;
  final bool? teacherAppLinked;
  final String? classLabel;
}

@immutable
class HrEmployeeDocument {
  const HrEmployeeDocument({
    required this.id,
    required this.title,
    required this.uploadedOn,
    required this.status,
    this.docType,
    this.expiryDate,
    this.daysToExpiry,
  });

  final String id;
  final String title;
  final String uploadedOn;
  final String status;

  /// HR-D1 — document type (e.g. police_verification, medical, contract, licence).
  final String? docType;

  /// HR-D1 — optional expiry date (yyyy-mm-dd). Null when the document never expires.
  final String? expiryDate;

  /// HR-D1 — whole days until [expiryDate] (negative once expired), or null.
  final int? daysToExpiry;
}

@immutable
class HrEmployeeLeaveBalance {
  const HrEmployeeLeaveBalance({
    required this.leaveType,
    required this.available,
    required this.used,
  });

  final HrLeaveType leaveType;
  final int available;
  final int used;
}

@immutable
class HrEmployeeDetail {
  const HrEmployeeDetail({
    required this.employee,
    required this.reportingManager,
    required this.address,
    required this.emergencyContact,
    required this.leaveBalances,
    required this.documents,
    required this.recentAttendance,
    required this.integrationNotes,
  });

  final HrEmployee employee;
  final String reportingManager;
  final String address;
  final String emergencyContact;
  final List<HrEmployeeLeaveBalance> leaveBalances;
  final List<HrEmployeeDocument> documents;
  final List<HrAttendanceRecord> recentAttendance;
  final List<String> integrationNotes;
}

@immutable
class HrAttendanceRecord {
  const HrAttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.status,
    required this.geoVerified,
    required this.faceVerified,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final HrDepartment department;
  final String date;
  final String checkIn;
  final String checkOut;
  final HrAttendanceStatus status;
  final bool geoVerified;
  final bool faceVerified;
}

@immutable
class HrAttendanceData {
  const HrAttendanceData({
    required this.records,
    required this.attendanceTrend,
    required this.departmentBreakdown,
    required this.summaryNote,
  });

  final List<HrAttendanceRecord> records;
  final List<HrTrendPoint> attendanceTrend;
  final List<HrSegment> departmentBreakdown;
  final String summaryNote;
}

@immutable
class HrLeaveRequest {
  const HrLeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.status,
    required this.approver,
    required this.reason,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final HrDepartment department;
  final HrLeaveType leaveType;
  final String fromDate;
  final String toDate;
  final int days;
  final HrLeaveStatus status;
  final String approver;
  final String reason;
}

/// HR-3 — the outcome of a batch approve/reject: which requests were decided and
/// which were skipped (already-decided / absent), with a reason per skip.
@immutable
class HrBatchLeaveDecision {
  const HrBatchLeaveDecision({required this.decided, required this.skipped});

  final List<String> decided;
  final List<HrBatchLeaveSkip> skipped;

  int get decidedCount => decided.length;
  int get skippedCount => skipped.length;
}

@immutable
class HrBatchLeaveSkip {
  const HrBatchLeaveSkip({required this.id, required this.reason});

  final String id;
  final String reason;
}

@immutable
class HrLeaveData {
  const HrLeaveData({
    required this.requests,
    required this.pendingCount,
    required this.leaveByType,
    required this.integrationNote,
  });

  final List<HrLeaveRequest> requests;
  final int pendingCount;
  final List<HrSegment> leaveByType;
  final String integrationNote;
}

@immutable
class HrPayrollRun {
  const HrPayrollRun({
    required this.id,
    required this.period,
    required this.employeeCount,
    required this.grossAmount,
    required this.netAmount,
    required this.status,
    required this.processedOn,
  });

  final String id;
  final String period;
  final int employeeCount;
  final String grossAmount;
  final String netAmount;
  final HrPayrollStatus status;
  final String processedOn;
}

@immutable
class HrPayrollEntry {
  const HrPayrollEntry({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.basicPay,
    required this.allowances,
    required this.deductions,
    required this.netPay,
    required this.status,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final HrDepartment department;
  final String basicPay;
  final String allowances;
  final String deductions;
  final String netPay;
  final HrPayrollStatus status;
}

@immutable
class HrPayrollData {
  const HrPayrollData({
    required this.runs,
    required this.entries,
    required this.salaryTrend,
    required this.financeIntegrationNote,
    required this.financeRoute,
  });

  final List<HrPayrollRun> runs;
  final List<HrPayrollEntry> entries;
  final List<HrTrendPoint> salaryTrend;
  final String financeIntegrationNote;
  final String financeRoute;
}

/// MOD-2 — a per-employee monthly salary structure (the payroll engine's
/// input; runs are generated from these).
@immutable
class HrSalaryStructure {
  const HrSalaryStructure({
    required this.employeeId,
    required this.employeeCode,
    required this.employeeName,
    required this.department,
    required this.basicPay,
    required this.allowances,
    required this.deductions,
  });

  final String employeeId;
  final String employeeCode;
  final String employeeName;
  final String department;
  final double basicPay;
  final double allowances;
  final double deductions;

  double get netPay => basicPay + allowances - deductions;
}

@immutable
class HrCandidate {
  const HrCandidate({
    required this.id,
    required this.name,
    required this.role,
    required this.department,
    required this.appliedOn,
    required this.stage,
    required this.experience,
    required this.source,
  });

  final String id;
  final String name;
  final String role;
  final HrDepartment department;
  final String appliedOn;
  final HrRecruitmentStage stage;
  final String experience;
  final String source;
}

@immutable
class HrRecruitmentData {
  const HrRecruitmentData({
    required this.candidates,
    required this.openPositions,
    required this.pipelineCounts,
    required this.hiringTrend,
  });

  final List<HrCandidate> candidates;
  final int openPositions;
  final List<HrSegment> pipelineCounts;
  final List<HrTrendPoint> hiringTrend;
}

@immutable
class HrPerformanceReview {
  const HrPerformanceReview({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.department,
    required this.cycle,
    required this.rating,
    required this.status,
    required this.reviewer,
    required this.dueDate,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final HrDepartment department;
  final HrReviewCycle cycle;
  final String rating;
  final HrReviewStatus status;
  final String reviewer;
  final String dueDate;
}

@immutable
class HrPerformanceData {
  const HrPerformanceData({
    required this.reviews,
    required this.ratingDistribution,
    required this.completionTrend,
    required this.managementInsight,
  });

  final List<HrPerformanceReview> reviews;
  final List<HrSegment> ratingDistribution;
  final List<HrTrendPoint> completionTrend;
  final String managementInsight;
}

@immutable
class HrPendingLeaveItem {
  const HrPendingLeaveItem({
    required this.id,
    required this.employeeName,
    required this.leaveType,
    required this.days,
    required this.submittedOn,
  });

  final String id;
  final String employeeName;
  final HrLeaveType leaveType;
  final int days;
  final String submittedOn;
}

@immutable
class HrDashboardData {
  const HrDashboardData({
    required this.kpis,
    required this.headcountTrend,
    required this.attendanceTrend,
    required this.pendingLeave,
    required this.recruitmentSnapshot,
    required this.aiInsight,
    required this.managementKpiNote,
  });

  final List<HrKpi> kpis;
  final List<HrTrendPoint> headcountTrend;
  final List<HrTrendPoint> attendanceTrend;
  final List<HrPendingLeaveItem> pendingLeave;
  final List<HrCandidate> recruitmentSnapshot;
  final String aiInsight;
  final String managementKpiNote;
}

@immutable
class HrSettingItem {
  const HrSettingItem({
    required this.id,
    required this.label,
    required this.value,
    required this.description,
    required this.editable,
  });

  final String id;
  final String label;
  final String value;
  final String description;
  final bool editable;
}

@immutable
class HrSettingsSection {
  const HrSettingsSection({
    required this.id,
    required this.title,
    required this.items,
  });

  final String id;
  final String title;
  final List<HrSettingItem> items;
}

@immutable
class HrSettingsData {
  const HrSettingsData({
    required this.sections,
    required this.defaultDepartment,
  });

  final List<HrSettingsSection> sections;
  final HrDepartment defaultDepartment;
}

@immutable
class HrReportCatalogItem {
  const HrReportCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
}

@immutable
class HrReportsData {
  const HrReportsData({
    required this.catalog,
    required this.headlineMetric,
  });

  final List<HrReportCatalogItem> catalog;
  final String headlineMetric;

  factory HrReportsData.mock() {
    return const HrReportsData(
      headlineMetric: '142 active staff · 96.2% attendance MTD',
      catalog: [
        HrReportCatalogItem(
          id: 'hr_headcount',
          title: 'Headcount by department',
          description: 'Active, on-leave, and probation counts',
          icon: Icons.groups_outlined,
        ),
        HrReportCatalogItem(
          id: 'hr_attendance',
          title: 'Attendance compliance',
          description: 'Daily presence and late arrivals',
          icon: Icons.fact_check_outlined,
        ),
        HrReportCatalogItem(
          id: 'hr_leave',
          title: 'Leave utilization',
          description: 'Approved vs pending leave by type',
          icon: Icons.event_busy_outlined,
        ),
        HrReportCatalogItem(
          id: 'hr_payroll',
          title: 'Payroll readiness',
          description: 'Processed vs draft payroll cycles',
          icon: Icons.payments_outlined,
        ),
      ],
    );
  }
}
