import 'package:flutter/material.dart';

/// Hostel sub-module destinations (HO-01 → HO-08).
enum HostelScreen {
  dashboard,
  students,
  rooms,
  attendance,
  leave,
  mess,
  visitors,
  reports;

  String get label => switch (this) {
        HostelScreen.dashboard => 'Dashboard',
        HostelScreen.students => 'Students',
        HostelScreen.rooms => 'Rooms',
        HostelScreen.attendance => 'Attendance',
        HostelScreen.leave => 'Leave',
        HostelScreen.mess => 'Mess',
        HostelScreen.visitors => 'Visitors',
        HostelScreen.reports => 'Reports',
      };
}

enum HostelRoomStatus { occupied, vacant, maintenance, alert }

enum HostelRoomType { standard, ac, dormitory, staff }

enum HostelStudentStatus { awaitingAllocation, resident, onLeave, checkedOut }

enum HostelAttendanceSession { morning, evening, night }

enum HostelAttendanceStatus { present, absent, onLeave }

enum HostelLeaveStatus { pending, approved, rejected, active }

enum HostelVisitorStatus { active, checkedOut, expired }

enum HostelMealType { breakfast, lunch, snacks, dinner }

@immutable
class HostelKpi {
  const HostelKpi({
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
class HostelTrendPoint {
  const HostelTrendPoint({
    required this.label,
    required this.amountLakhs,
    required this.targetLakhs,
  });

  final String label;
  final double amountLakhs;
  final double targetLakhs;
}

@immutable
class HostelSegment {
  const HostelSegment({
    required this.label,
    required this.value,
    required this.percent,
  });

  final String label;
  final double value;
  final double percent;
}

@immutable
class HostelStudent {
  const HostelStudent({
    required this.id,
    required this.studentName,
    required this.admissionNumber,
    required this.classLabel,
    required this.block,
    required this.room,
    required this.bed,
    required this.sisStudentId,
    required this.status,
    required this.feePending,
    required this.parentAppLinked,
  });

  final String id;
  final String studentName;
  final String admissionNumber;
  final String classLabel;
  final String block;
  final String room;
  final String bed;
  final String sisStudentId;
  final HostelStudentStatus status;
  final String feePending;
  final bool parentAppLinked;
}

@immutable
class HostelRoom {
  const HostelRoom({
    required this.id,
    required this.block,
    required this.roomNumber,
    required this.floor,
    required this.type,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.status,
    required this.facilities,
  });

  final String id;
  final String block;
  final String roomNumber;
  final int floor;
  final HostelRoomType type;
  final int totalBeds;
  final int occupiedBeds;
  final HostelRoomStatus status;
  final String facilities;
}

@immutable
class HostelAttendanceRecord {
  const HostelAttendanceRecord({
    required this.id,
    required this.studentName,
    required this.room,
    required this.rollNumber,
    required this.morning,
    required this.evening,
    required this.night,
    required this.overallStatus,
    required this.remark,
    required this.parentNotified,
    required this.sisStudentId,
  });

  final String id;
  final String studentName;
  final String room;
  final String rollNumber;
  final HostelAttendanceStatus morning;
  final HostelAttendanceStatus evening;
  final HostelAttendanceStatus night;
  final HostelAttendanceStatus overallStatus;
  final String remark;
  final bool parentNotified;
  final String sisStudentId;
}

@immutable
class HostelLeaveRequest {
  const HostelLeaveRequest({
    required this.id,
    required this.studentName,
    required this.room,
    required this.fromDate,
    required this.toDate,
    required this.days,
    required this.reason,
    required this.parentContact,
    required this.status,
    required this.gatePassId,
    required this.sisStudentId,
    required this.parentAppRoute,
  });

  final String id;
  final String studentName;
  final String room;
  final String fromDate;
  final String toDate;
  final int days;
  final String reason;
  final String parentContact;
  final HostelLeaveStatus status;
  final String? gatePassId;
  final String sisStudentId;
  final String parentAppRoute;
}

@immutable
class HostelMealMenu {
  const HostelMealMenu({
    required this.day,
    required this.mealType,
    required this.items,
    required this.dietaryTags,
  });

  final String day;
  final HostelMealType mealType;
  final String items;
  final List<String> dietaryTags;
}

@immutable
class HostelMessData {
  const HostelMessData({
    required this.weeklyMenus,
    required this.consumptionTrend,
    required this.costMtd,
    required this.financeIntegrationNote,
  });

  final List<HostelMealMenu> weeklyMenus;
  final List<HostelTrendPoint> consumptionTrend;
  final String costMtd;
  final String financeIntegrationNote;
}

@immutable
class HostelVisitor {
  const HostelVisitor({
    required this.id,
    required this.visitorName,
    required this.relation,
    required this.studentName,
    required this.sisStudentId,
    required this.checkIn,
    required this.checkOut,
    required this.passId,
    required this.status,
  });

  final String id;
  final String visitorName;
  final String relation;
  final String studentName;
  final String sisStudentId;
  final String checkIn;
  final String? checkOut;
  final String passId;
  final HostelVisitorStatus status;
}

@immutable
class HostelVisitorsData {
  const HostelVisitorsData({
    required this.activeVisitors,
    required this.visitorLog,
    required this.qrPlaceholderLabel,
    required this.parentAppRoute,
  });

  final List<HostelVisitor> activeVisitors;
  final List<HostelVisitor> visitorLog;
  final String qrPlaceholderLabel;
  final String parentAppRoute;
}

@immutable
class HostelBlockOccupancy {
  const HostelBlockOccupancy({
    required this.block,
    required this.occupied,
    required this.total,
    required this.percent,
  });

  final String block;
  final int occupied;
  final int total;
  final int percent;
}

@immutable
class HostelSessionAttendance {
  const HostelSessionAttendance({
    required this.session,
    required this.present,
    required this.absent,
    required this.onLeave,
  });

  final HostelAttendanceSession session;
  final int present;
  final int absent;
  final int onLeave;
}

@immutable
class HostelOccupancyMetrics {
  const HostelOccupancyMetrics({
    required this.totalBeds,
    required this.occupiedBeds,
    required this.vacantBeds,
    required this.utilizationPercent,
  });

  final int totalBeds;
  final int occupiedBeds;
  final int vacantBeds;
  final int utilizationPercent;
}

@immutable
class HostelDashboardData {
  const HostelDashboardData({
    required this.kpis,
    required this.blockOccupancy,
    required this.sessionAttendance,
    required this.activeVisitorCount,
    required this.healthAlerts,
    required this.missingStudents,
    required this.occupancy,
    required this.aiInsight,
  });

  final List<HostelKpi> kpis;
  final List<HostelBlockOccupancy> blockOccupancy;
  final List<HostelSessionAttendance> sessionAttendance;
  final int activeVisitorCount;
  final List<String> healthAlerts;
  final List<String> missingStudents;
  final HostelOccupancyMetrics occupancy;
  final String aiInsight;
}

@immutable
class HostelReportCatalogItem {
  const HostelReportCatalogItem({
    required this.id,
    required this.title,
    required this.description,
    required this.lastGenerated,
  });

  final String id;
  final String title;
  final String description;
  final String lastGenerated;
}

@immutable
class HostelReportsData {
  const HostelReportsData({
    required this.catalog,
    required this.occupancyTrend,
    required this.attendanceByBlock,
    required this.messCostTrend,
  });

  final List<HostelReportCatalogItem> catalog;
  final List<HostelTrendPoint> occupancyTrend;
  final List<HostelSegment> attendanceByBlock;
  final List<HostelTrendPoint> messCostTrend;
}
