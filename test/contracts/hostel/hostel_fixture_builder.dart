import 'package:akshara_erp/core/repositories/api/hostel/dto/hostel_enum_codec.dart';
import 'package:akshara_erp/features/hostel/hostel_models.dart';

/// Builds API-shaped JSON envelopes from Hostel domain models for contract tests.
class HostelFixtureBuilder {
  const HostelFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> trendPoint(HostelTrendPoint point) => {
        'label': point.label,
        'amountLakhs': point.amountLakhs,
        'targetLakhs': point.targetLakhs,
      };

  Map<String, dynamic> segment(HostelSegment segment) => {
        'label': segment.label,
        'value': segment.value,
        'percent': segment.percent,
      };

  Map<String, dynamic> occupancyItem(HostelOccupancyMetrics metrics) => {
        'totalBeds': metrics.totalBeds,
        'occupiedBeds': metrics.occupiedBeds,
        'vacantBeds': metrics.vacantBeds,
        'utilizationPercent': metrics.utilizationPercent,
      };

  Map<String, dynamic> studentItem(HostelStudent student) => {
        'id': student.id,
        'studentName': student.studentName,
        'admissionNumber': student.admissionNumber,
        'classLabel': student.classLabel,
        'block': student.block,
        'room': student.room,
        'bed': student.bed,
        'sisStudentId': student.sisStudentId,
        'status': HostelEnumCodec.studentStatusToApi(student.status),
        'feePending': student.feePending,
        'parentAppLinked': student.parentAppLinked,
      };

  Map<String, dynamic> roomItem(HostelRoom room) => {
        'id': room.id,
        'block': room.block,
        'roomNumber': room.roomNumber,
        'floor': room.floor,
        'type': HostelEnumCodec.roomTypeToApi(room.type),
        'totalBeds': room.totalBeds,
        'occupiedBeds': room.occupiedBeds,
        'status': HostelEnumCodec.roomStatusToApi(room.status),
        'facilities': room.facilities,
      };

  Map<String, dynamic> attendanceRecordItem(HostelAttendanceRecord record) => {
        'id': record.id,
        'studentName': record.studentName,
        'room': record.room,
        'rollNumber': record.rollNumber,
        'morning': HostelEnumCodec.attendanceStatusToApi(record.morning),
        'evening': HostelEnumCodec.attendanceStatusToApi(record.evening),
        'night': HostelEnumCodec.attendanceStatusToApi(record.night),
        'overallStatus':
            HostelEnumCodec.attendanceStatusToApi(record.overallStatus),
        'remark': record.remark,
        'parentNotified': record.parentNotified,
        'sisStudentId': record.sisStudentId,
      };

  Map<String, dynamic> leaveRequestItem(HostelLeaveRequest request) => {
        'id': request.id,
        'studentName': request.studentName,
        'room': request.room,
        'fromDate': request.fromDate,
        'toDate': request.toDate,
        'days': request.days,
        'reason': request.reason,
        'parentContact': request.parentContact,
        'status': HostelEnumCodec.leaveStatusToApi(request.status),
        if (request.gatePassId != null) 'gatePassId': request.gatePassId,
        'sisStudentId': request.sisStudentId,
        'parentAppRoute': request.parentAppRoute,
      };

  Map<String, dynamic> visitorItem(HostelVisitor visitor) => {
        'id': visitor.id,
        'visitorName': visitor.visitorName,
        'relation': visitor.relation,
        'studentName': visitor.studentName,
        'sisStudentId': visitor.sisStudentId,
        'checkIn': visitor.checkIn,
        if (visitor.checkOut != null) 'checkOut': visitor.checkOut,
        'passId': visitor.passId,
        'status': HostelEnumCodec.visitorStatusToApi(visitor.status),
      };

  Map<String, dynamic> dashboardEnvelope(HostelDashboardData data) {
    return envelope({
      'aiInsight': data.aiInsight,
      'activeVisitorCount': data.activeVisitorCount,
      'healthAlerts': data.healthAlerts,
      'missingStudents': data.missingStudents,
      'occupancy': occupancyItem(data.occupancy),
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
      'blockOccupancy': [
        for (final block in data.blockOccupancy)
          {
            'block': block.block,
            'occupied': block.occupied,
            'total': block.total,
            'percent': block.percent,
          },
      ],
      'sessionAttendance': [
        for (final session in data.sessionAttendance)
          {
            'session': HostelEnumCodec.attendanceSessionToApi(session.session),
            'present': session.present,
            'absent': session.absent,
            'onLeave': session.onLeave,
          },
      ],
    });
  }

  Map<String, dynamic> studentsEnvelope(List<HostelStudent> students) {
    return listEnvelope([
      for (final student in students) studentItem(student),
    ]);
  }

  Map<String, dynamic> roomsEnvelope(List<HostelRoom> rooms) {
    return listEnvelope([for (final room in rooms) roomItem(room)]);
  }

  Map<String, dynamic> attendanceEnvelope(List<HostelAttendanceRecord> records) {
    return listEnvelope([
      for (final record in records) attendanceRecordItem(record),
    ]);
  }

  Map<String, dynamic> leaveEnvelope(List<HostelLeaveRequest> requests) {
    return listEnvelope([
      for (final request in requests) leaveRequestItem(request),
    ]);
  }

  Map<String, dynamic> messEnvelope(HostelMessData data) {
    return envelope({
      'costMtd': data.costMtd,
      'financeIntegrationNote': data.financeIntegrationNote,
      'weeklyMenus': [
        for (final menu in data.weeklyMenus)
          {
            'day': menu.day,
            'mealType': HostelEnumCodec.mealTypeToApi(menu.mealType),
            'items': menu.items,
            'dietaryTags': menu.dietaryTags,
          },
      ],
      'consumptionTrend': [
        for (final point in data.consumptionTrend) trendPoint(point),
      ],
    });
  }

  Map<String, dynamic> visitorsEnvelope(HostelVisitorsData data) {
    return envelope({
      'qrPlaceholderLabel': data.qrPlaceholderLabel,
      'parentAppRoute': data.parentAppRoute,
      'activeVisitors': [
        for (final visitor in data.activeVisitors) visitorItem(visitor),
      ],
      'visitorLog': [
        for (final visitor in data.visitorLog) visitorItem(visitor),
      ],
    });
  }

  Map<String, dynamic> reportsEnvelope(HostelReportsData data) {
    return envelope({
      'catalog': [
        for (final item in data.catalog)
          {
            'id': item.id,
            'title': item.title,
            'description': item.description,
            'lastGenerated': item.lastGenerated,
          },
      ],
      'occupancyTrend': [
        for (final point in data.occupancyTrend) trendPoint(point),
      ],
      'attendanceByBlock': [
        for (final segment in data.attendanceByBlock) this.segment(segment),
      ],
      'messCostTrend': [
        for (final point in data.messCostTrend) trendPoint(point),
      ],
    });
  }

  Map<String, dynamic> occupancyMetricsEnvelope(HostelOccupancyMetrics metrics) {
    return envelope(occupancyItem(metrics));
  }
}
