import 'package:flutter/material.dart';

import '../../../features/hostel/hostel_models.dart';
import '../../../features/hostel/hostel_requests.dart';
import '../../../router/route_names.dart';
import '../interfaces/hostel_repository.dart';
import '../paginated_result.dart';
import '../pagination_helpers.dart';
import '../repository_query.dart';

class MockHostelRepository implements HostelRepository {
  MockHostelRepository()
      : _students = List<HostelStudent>.from(_seedStudents),
        _rooms = List<HostelRoom>.from(_seedRooms);

  final List<HostelStudent> _students;
  final List<HostelRoom> _rooms;
  int _studentCounter = 5;

  HostelOccupancyMetrics get _occupancyMetrics {
    final totalBeds = _rooms.fold<int>(0, (sum, room) => sum + room.totalBeds);
    final occupiedBeds =
        _rooms.fold<int>(0, (sum, room) => sum + room.occupiedBeds);
    final vacantBeds = totalBeds - occupiedBeds;
    final utilizationPercent =
        totalBeds == 0 ? 0 : ((occupiedBeds / totalBeds) * 100).round();
    return HostelOccupancyMetrics(
      totalBeds: totalBeds,
      occupiedBeds: occupiedBeds,
      vacantBeds: vacantBeds,
      utilizationPercent: utilizationPercent,
    );
  }

  static const _seedStudents = [
    HostelStudent(
      id: 'ho_stu_1',
      studentName: 'Arjun Patel',
      admissionNumber: 'ADM-2026-0138',
      classLabel: '10',
      block: 'Block A',
      room: 'A-204',
      bed: 'B2',
      sisStudentId: 'SIS-STU-10421',
      status: HostelStudentStatus.resident,
      feePending: '₹12,400',
      parentAppLinked: true,
    ),
    HostelStudent(
      id: 'ho_stu_2',
      studentName: 'Emma Thomas',
      admissionNumber: 'ADM-2026-0135',
      classLabel: '7',
      block: 'Block A',
      room: 'A-108',
      bed: 'B1',
      sisStudentId: 'SIS-STU-10418',
      status: HostelStudentStatus.resident,
      feePending: '₹0',
      parentAppLinked: true,
    ),
    HostelStudent(
      id: 'ho_stu_3',
      studentName: 'Ananya Reddy',
      admissionNumber: 'ADM-2026-0142',
      classLabel: '5',
      block: 'Block B',
      room: 'B-312',
      bed: 'B3',
      sisStudentId: 'SIS-STU-10422',
      status: HostelStudentStatus.onLeave,
      feePending: '₹8,200',
      parentAppLinked: true,
    ),
    HostelStudent(
      id: 'ho_stu_4',
      studentName: 'Priya Sharma',
      admissionNumber: 'ADM-2025-0092',
      classLabel: '8',
      block: 'Block B',
      room: 'B-205',
      bed: 'B1',
      sisStudentId: 'SIS-STU-10415',
      status: HostelStudentStatus.resident,
      feePending: '₹4,800',
      parentAppLinked: true,
    ),
    HostelStudent(
      id: 'ho_stu_5',
      studentName: 'Karthik Sharma',
      admissionNumber: 'ADM-2026-0145',
      classLabel: '8',
      block: '—',
      room: '—',
      bed: '—',
      sisStudentId: 'SIS-STU-10425',
      status: HostelStudentStatus.awaitingAllocation,
      feePending: '₹0',
      parentAppLinked: true,
    ),
  ];

  static const _seedRooms = [
    HostelRoom(
      id: 'room_1',
      block: 'Block A',
      roomNumber: 'A-204',
      floor: 2,
      type: HostelRoomType.ac,
      totalBeds: 4,
      occupiedBeds: 4,
      status: HostelRoomStatus.occupied,
      facilities: 'AC · Attached bath',
    ),
    HostelRoom(
      id: 'room_2',
      block: 'Block A',
      roomNumber: 'A-108',
      floor: 1,
      type: HostelRoomType.standard,
      totalBeds: 4,
      occupiedBeds: 3,
      status: HostelRoomStatus.occupied,
      facilities: 'Shared bath',
    ),
    HostelRoom(
      id: 'room_3',
      block: 'Block B',
      roomNumber: 'B-312',
      floor: 3,
      type: HostelRoomType.standard,
      totalBeds: 4,
      occupiedBeds: 2,
      status: HostelRoomStatus.occupied,
      facilities: 'Shared bath',
    ),
    HostelRoom(
      id: 'room_4',
      block: 'Block B',
      roomNumber: 'B-401',
      floor: 4,
      type: HostelRoomType.dormitory,
      totalBeds: 8,
      occupiedBeds: 0,
      status: HostelRoomStatus.vacant,
      facilities: 'Dormitory · Common bath',
    ),
    HostelRoom(
      id: 'room_5',
      block: 'Block C',
      roomNumber: 'C-102',
      floor: 1,
      type: HostelRoomType.standard,
      totalBeds: 4,
      occupiedBeds: 0,
      status: HostelRoomStatus.maintenance,
      facilities: 'Plumbing repair',
    ),
  ];

  @override
  Future<HostelDashboardData> getDashboard({required RepositoryQuery query}) async {
    return HostelDashboardData(
      kpis: const [
        HostelKpi(
          id: 'occupancy',
          value: '87%',
          label: 'Occupancy',
          icon: Icons.bed_outlined,
          accentName: 'primary',
        ),
        HostelKpi(
          id: 'present',
          value: '412',
          label: 'Present Now',
          icon: Icons.groups_outlined,
          accentName: 'success',
        ),
        HostelKpi(
          id: 'missing',
          value: '3',
          label: 'Missing',
          icon: Icons.person_search_outlined,
          accentName: 'error',
        ),
        HostelKpi(
          id: 'visitors',
          value: '12',
          label: 'Visitors Today',
          icon: Icons.badge_outlined,
          accentName: 'primary',
        ),
        HostelKpi(
          id: 'mess_cost',
          value: '₹1.2L',
          label: 'Mess Cost (MTD)',
          icon: Icons.restaurant_outlined,
          accentName: 'neutral',
          detail: 'Finance integration placeholder',
        ),
        HostelKpi(
          id: 'fee_pending',
          value: '₹4.8L',
          label: 'Fee Pending',
          icon: Icons.payments_outlined,
          accentName: 'warning',
          detail: 'Links to Finance FN-02',
        ),
      ],
      blockOccupancy: const [
        HostelBlockOccupancy(
          block: 'Block A',
          occupied: 148,
          total: 160,
          percent: 93,
        ),
        HostelBlockOccupancy(
          block: 'Block B',
          occupied: 132,
          total: 160,
          percent: 83,
        ),
        HostelBlockOccupancy(
          block: 'Block C',
          occupied: 96,
          total: 120,
          percent: 80,
        ),
      ],
      sessionAttendance: const [
        HostelSessionAttendance(
          session: HostelAttendanceSession.morning,
          present: 408,
          absent: 4,
          onLeave: 3,
        ),
        HostelSessionAttendance(
          session: HostelAttendanceSession.evening,
          present: 405,
          absent: 5,
          onLeave: 5,
        ),
        HostelSessionAttendance(
          session: HostelAttendanceSession.night,
          present: 412,
          absent: 3,
          onLeave: 0,
        ),
      ],
      activeVisitorCount: 4,
      healthAlerts: [
        'Block A — Room A-108: student reported fever (parent notified)',
      ],
      missingStudents: [
        'Rohan Mehta — Block B B-205 (evening session)',
        'Kavya Iyer — Block A A-312 (night roll call)',
      ],
      occupancy: _occupancyMetrics,
      aiInsight:
          '3 students missing from evening session in Block B. Review attendance and notify parents via Parent App.',
    );
  }

  @override
  Future<PaginatedResult<HostelStudent>> getStudents({
    required RepositoryQuery query,
  }) async =>
      paginateList(_students, query);

  @override
  Future<PaginatedResult<HostelRoom>> getRooms({
    required RepositoryQuery query,
  }) async =>
      paginateList(_rooms, query);

  @override
  Future<PaginatedResult<HostelAttendanceRecord>> getAttendanceRecords({
    required RepositoryQuery query,
  }) async {
    return paginateList(const [
      HostelAttendanceRecord(
        id: 'att_1',
        studentName: 'Arjun Patel',
        room: 'A-204',
        rollNumber: '10-A-12',
        morning: HostelAttendanceStatus.present,
        evening: HostelAttendanceStatus.present,
        night: HostelAttendanceStatus.present,
        overallStatus: HostelAttendanceStatus.present,
        remark: '',
        parentNotified: false,
        sisStudentId: 'SIS-STU-10421',
      ),
      HostelAttendanceRecord(
        id: 'att_2',
        studentName: 'Emma Thomas',
        room: 'A-108',
        rollNumber: '7-B-08',
        morning: HostelAttendanceStatus.present,
        evening: HostelAttendanceStatus.present,
        night: HostelAttendanceStatus.present,
        overallStatus: HostelAttendanceStatus.present,
        remark: '',
        parentNotified: false,
        sisStudentId: 'SIS-STU-10418',
      ),
      HostelAttendanceRecord(
        id: 'att_3',
        studentName: 'Ananya Reddy',
        room: 'B-312',
        rollNumber: '5-C-04',
        morning: HostelAttendanceStatus.onLeave,
        evening: HostelAttendanceStatus.onLeave,
        night: HostelAttendanceStatus.onLeave,
        overallStatus: HostelAttendanceStatus.onLeave,
        remark: 'Approved leave — gate pass HO-PASS-042',
        parentNotified: true,
        sisStudentId: 'SIS-STU-10422',
      ),
      HostelAttendanceRecord(
        id: 'att_4',
        studentName: 'Priya Sharma',
        room: 'B-205',
        rollNumber: '8-A-15',
        morning: HostelAttendanceStatus.present,
        evening: HostelAttendanceStatus.absent,
        night: HostelAttendanceStatus.present,
        overallStatus: HostelAttendanceStatus.absent,
        remark: 'Missing evening session',
        parentNotified: true,
        sisStudentId: 'SIS-STU-10415',
      ),
    ], query);
  }

  @override
  Future<PaginatedResult<HostelLeaveRequest>> getLeaveRequests({
    required RepositoryQuery query,
  }) async {
    return paginateList(const [
      HostelLeaveRequest(
        id: 'leave_1',
        studentName: 'Ananya Reddy',
        room: 'B-312',
        fromDate: '6 Jun 2026',
        toDate: '8 Jun 2026',
        days: 3,
        reason: 'Family function',
        parentContact: 'Rajesh Reddy · +91 98765 43210',
        status: HostelLeaveStatus.approved,
        gatePassId: 'HO-PASS-042',
        sisStudentId: 'SIS-STU-10422',
        parentAppRoute: RouteNames.parentLeave,
      ),
      HostelLeaveRequest(
        id: 'leave_2',
        studentName: 'Arjun Patel',
        room: 'A-204',
        fromDate: '10 Jun 2026',
        toDate: '12 Jun 2026',
        days: 3,
        reason: 'Medical appointment',
        parentContact: 'Vikram Patel · +91 91234 56789',
        status: HostelLeaveStatus.pending,
        gatePassId: null,
        sisStudentId: 'SIS-STU-10421',
        parentAppRoute: RouteNames.parentLeave,
      ),
      HostelLeaveRequest(
        id: 'leave_3',
        studentName: 'Emma Thomas',
        room: 'A-108',
        fromDate: '1 Jun 2026',
        toDate: '2 Jun 2026',
        days: 2,
        reason: 'Weekend home visit',
        parentContact: 'Sarah Thomas · +91 99887 76655',
        status: HostelLeaveStatus.rejected,
        gatePassId: null,
        sisStudentId: 'SIS-STU-10418',
        parentAppRoute: RouteNames.parentLeave,
      ),
      HostelLeaveRequest(
        id: 'leave_4',
        studentName: 'Priya Sharma',
        room: 'B-205',
        fromDate: '14 Jun 2026',
        toDate: '16 Jun 2026',
        days: 3,
        reason: 'Sports tournament',
        parentContact: 'Amit Sharma · +91 97654 32109',
        status: HostelLeaveStatus.active,
        gatePassId: 'HO-PASS-051',
        sisStudentId: 'SIS-STU-10415',
        parentAppRoute: RouteNames.parentLeave,
      ),
    ], query);
  }

  @override
  Future<HostelMessData> getMessData({required RepositoryQuery query}) async {
    return const HostelMessData(
      weeklyMenus: [
        HostelMealMenu(
          day: 'Mon',
          mealType: HostelMealType.breakfast,
          items: 'Idli · Sambar · Chutney',
          dietaryTags: ['Veg', 'Jain option'],
        ),
        HostelMealMenu(
          day: 'Mon',
          mealType: HostelMealType.lunch,
          items: 'Rice · Dal · Paneer curry · Salad',
          dietaryTags: ['Veg'],
        ),
        HostelMealMenu(
          day: 'Mon',
          mealType: HostelMealType.snacks,
          items: 'Fruit bowl · Biscuits',
          dietaryTags: ['Veg', 'Allergy: nuts'],
        ),
        HostelMealMenu(
          day: 'Mon',
          mealType: HostelMealType.dinner,
          items: 'Roti · Mixed veg · Curd',
          dietaryTags: ['Veg', 'Jain option'],
        ),
      ],
      consumptionTrend: [
        HostelTrendPoint(label: 'Jan', amountLakhs: 1.0, targetLakhs: 1.1),
        HostelTrendPoint(label: 'Feb', amountLakhs: 1.05, targetLakhs: 1.1),
        HostelTrendPoint(label: 'Mar', amountLakhs: 1.12, targetLakhs: 1.15),
        HostelTrendPoint(label: 'Apr', amountLakhs: 1.08, targetLakhs: 1.15),
        HostelTrendPoint(label: 'May', amountLakhs: 1.18, targetLakhs: 1.2),
        HostelTrendPoint(label: 'Jun', amountLakhs: 1.2, targetLakhs: 1.2),
      ],
      costMtd: '₹1.2L',
      financeIntegrationNote:
          'Mess expenses post to Finance FN-05 expense ledger (placeholder)',
    );
  }

  @override
  Future<HostelVisitorsData> getVisitors({required RepositoryQuery query}) async {
    return const HostelVisitorsData(
      activeVisitors: [
        HostelVisitor(
          id: 'vis_1',
          visitorName: 'Vikram Patel',
          relation: 'Father',
          studentName: 'Arjun Patel',
          sisStudentId: 'SIS-STU-10421',
          checkIn: '10:30 AM',
          checkOut: null,
          passId: 'HO-VIS-108',
          status: HostelVisitorStatus.active,
        ),
        HostelVisitor(
          id: 'vis_2',
          visitorName: 'Sarah Thomas',
          relation: 'Mother',
          studentName: 'Emma Thomas',
          sisStudentId: 'SIS-STU-10418',
          checkIn: '11:15 AM',
          checkOut: null,
          passId: 'HO-VIS-109',
          status: HostelVisitorStatus.active,
        ),
      ],
      visitorLog: [
        HostelVisitor(
          id: 'vis_3',
          visitorName: 'Rajesh Reddy',
          relation: 'Father',
          studentName: 'Ananya Reddy',
          sisStudentId: 'SIS-STU-10422',
          checkIn: '9:00 AM',
          checkOut: '11:45 AM',
          passId: 'HO-VIS-105',
          status: HostelVisitorStatus.checkedOut,
        ),
        HostelVisitor(
          id: 'vis_4',
          visitorName: 'Amit Sharma',
          relation: 'Father',
          studentName: 'Priya Sharma',
          sisStudentId: 'SIS-STU-10415',
          checkIn: '4 Jun 2026',
          checkOut: '4 Jun 2026',
          passId: 'HO-VIS-098',
          status: HostelVisitorStatus.expired,
        ),
      ],
      qrPlaceholderLabel: 'QR visitor pass preview (120×120)',
      parentAppRoute: RouteNames.parentDashboard,
    );
  }

  @override
  Future<HostelReportsData> getReports({required RepositoryQuery query}) async {
    return const HostelReportsData(
      catalog: [
        HostelReportCatalogItem(
          id: 'rpt_1',
          title: 'Occupancy report',
          description: 'Block-wise bed utilization',
          lastGenerated: '5 Jun 2026',
        ),
        HostelReportCatalogItem(
          id: 'rpt_2',
          title: 'Attendance summary',
          description: 'Session-wise present/absent/leave',
          lastGenerated: '6 Jun 2026',
        ),
        HostelReportCatalogItem(
          id: 'rpt_3',
          title: 'Visitor log',
          description: 'Check-in/out with pass IDs',
          lastGenerated: '6 Jun 2026',
        ),
        HostelReportCatalogItem(
          id: 'rpt_4',
          title: 'Mess cost analysis',
          description: 'Monthly consumption vs budget',
          lastGenerated: '1 Jun 2026',
        ),
        HostelReportCatalogItem(
          id: 'rpt_5',
          title: 'Fee collection',
          description: 'Hostel fee pending — Finance FN-02 link',
          lastGenerated: '3 Jun 2026',
        ),
        HostelReportCatalogItem(
          id: 'rpt_6',
          title: 'Incident log',
          description: 'Health and safety incidents',
          lastGenerated: '28 May 2026',
        ),
      ],
      occupancyTrend: [
        HostelTrendPoint(label: 'Jan', amountLakhs: 82, targetLakhs: 85),
        HostelTrendPoint(label: 'Feb', amountLakhs: 84, targetLakhs: 85),
        HostelTrendPoint(label: 'Mar', amountLakhs: 86, targetLakhs: 88),
        HostelTrendPoint(label: 'Apr', amountLakhs: 85, targetLakhs: 88),
        HostelTrendPoint(label: 'May', amountLakhs: 87, targetLakhs: 90),
        HostelTrendPoint(label: 'Jun', amountLakhs: 87, targetLakhs: 90),
      ],
      attendanceByBlock: [
        HostelSegment(label: 'Block A', value: 96, percent: 96),
        HostelSegment(label: 'Block B', value: 94, percent: 94),
        HostelSegment(label: 'Block C', value: 91, percent: 91),
      ],
      messCostTrend: [
        HostelTrendPoint(label: 'Jan', amountLakhs: 1.0, targetLakhs: 1.1),
        HostelTrendPoint(label: 'Feb', amountLakhs: 1.05, targetLakhs: 1.1),
        HostelTrendPoint(label: 'Mar', amountLakhs: 1.12, targetLakhs: 1.15),
        HostelTrendPoint(label: 'Apr', amountLakhs: 1.08, targetLakhs: 1.15),
        HostelTrendPoint(label: 'May', amountLakhs: 1.18, targetLakhs: 1.2),
        HostelTrendPoint(label: 'Jun', amountLakhs: 1.2, targetLakhs: 1.2),
      ],
    );
  }

  @override
  Future<HostelOccupancyMetrics> getOccupancyMetrics({required RepositoryQuery query}) async {
    return _occupancyMetrics;
  }

  int _roomIndexByNumber(String roomNumber) =>
      _rooms.indexWhere((room) => room.roomNumber == roomNumber);

  HostelRoomStatus _statusForOccupancy(
    HostelRoom room,
    int occupiedBeds,
  ) {
    if (room.status == HostelRoomStatus.maintenance) {
      return HostelRoomStatus.maintenance;
    }
    if (occupiedBeds <= 0) {
      return HostelRoomStatus.vacant;
    }
    if (occupiedBeds >= room.totalBeds) {
      return HostelRoomStatus.occupied;
    }
    return HostelRoomStatus.occupied;
  }

  void _releaseStudentBed(HostelStudent student) {
    if (student.room == '—') return;
    final roomIndex = _roomIndexByNumber(student.room);
    if (roomIndex < 0) return;

    final room = _rooms[roomIndex];
    final occupiedBeds = room.occupiedBeds > 0 ? room.occupiedBeds - 1 : 0;
    _rooms[roomIndex] = HostelRoom(
      id: room.id,
      block: room.block,
      roomNumber: room.roomNumber,
      floor: room.floor,
      type: room.type,
      totalBeds: room.totalBeds,
      occupiedBeds: occupiedBeds,
      status: _statusForOccupancy(room, occupiedBeds),
      facilities: room.facilities,
    );
  }

  void _occupyRoomBed(HostelRoom room, int roomIndex) {
    final occupiedBeds = room.occupiedBeds + 1;
    _rooms[roomIndex] = HostelRoom(
      id: room.id,
      block: room.block,
      roomNumber: room.roomNumber,
      floor: room.floor,
      type: room.type,
      totalBeds: room.totalBeds,
      occupiedBeds: occupiedBeds,
      status: _statusForOccupancy(room, occupiedBeds),
      facilities: room.facilities,
    );
  }

  @override
  Future<HostelStudent> admitHostelStudent({
    required RepositoryQuery query,
    required AdmitHostelStudentRequest request,
  }) async {
    if (_students.any((s) => s.sisStudentId == request.sisStudentId)) {
      throw StateError('Student already admitted to hostel');
    }

    _studentCounter += 1;
    final student = HostelStudent(
      id: 'ho_stu_$_studentCounter',
      studentName: request.studentName,
      admissionNumber: request.admissionNumber,
      classLabel: request.classLabel,
      block: '—',
      room: '—',
      bed: '—',
      sisStudentId: request.sisStudentId,
      status: HostelStudentStatus.awaitingAllocation,
      feePending: '₹0',
      parentAppLinked: true,
    );
    _students.insert(0, student);
    return student;
  }

  @override
  Future<HostelStudent> assignHostelRoom({
    required RepositoryQuery query,
    required AssignHostelRoomRequest request,
  }) async {
    final studentIndex =
        _students.indexWhere((s) => s.id == request.hostelStudentId);
    if (studentIndex < 0) {
      throw StateError('Hostel student not found');
    }

    final student = _students[studentIndex];
    if (student.status == HostelStudentStatus.checkedOut) {
      throw StateError('Checked-out students cannot be assigned a room');
    }

    final roomIndex = _rooms.indexWhere((room) => room.id == request.roomId);
    if (roomIndex < 0) {
      throw StateError('Room not found');
    }

    final room = _rooms[roomIndex];
    if (room.status == HostelRoomStatus.maintenance) {
      throw StateError('Room is under maintenance');
    }
    if (room.occupiedBeds >= room.totalBeds) {
      throw StateError('Room is at full capacity');
    }

    _releaseStudentBed(student);

    _occupyRoomBed(room, roomIndex);

    final assigned = HostelStudent(
      id: student.id,
      studentName: student.studentName,
      admissionNumber: student.admissionNumber,
      classLabel: student.classLabel,
      block: room.block,
      room: room.roomNumber,
      bed: request.bed,
      sisStudentId: student.sisStudentId,
      status: HostelStudentStatus.resident,
      feePending: student.feePending,
      parentAppLinked: student.parentAppLinked,
    );
    _students[studentIndex] = assigned;
    return assigned;
  }

  @override
  Future<HostelStudent> checkoutHostelStudent({
    required RepositoryQuery query,
    required CheckoutHostelStudentRequest request,
  }) async {
    final studentIndex =
        _students.indexWhere((s) => s.id == request.hostelStudentId);
    if (studentIndex < 0) {
      throw StateError('Hostel student not found');
    }

    final student = _students[studentIndex];
    if (student.status == HostelStudentStatus.checkedOut) {
      throw StateError('Student already checked out');
    }
    if (student.status == HostelStudentStatus.awaitingAllocation) {
      throw StateError('Assign a room before checkout');
    }

    _releaseStudentBed(student);

    final checkedOut = HostelStudent(
      id: student.id,
      studentName: student.studentName,
      admissionNumber: student.admissionNumber,
      classLabel: student.classLabel,
      block: '—',
      room: '—',
      bed: '—',
      sisStudentId: student.sisStudentId,
      status: HostelStudentStatus.checkedOut,
      feePending: student.feePending,
      parentAppLinked: student.parentAppLinked,
    );
    _students[studentIndex] = checkedOut;
    return checkedOut;
  }
}
