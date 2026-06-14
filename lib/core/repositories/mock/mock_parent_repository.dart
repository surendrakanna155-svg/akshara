import '../../../features/parent/academics/parent_academic_models.dart';
import 'mock_attendance_sync_store.dart';
import '../../../features/parent/attendance/attendance_models.dart';
import '../../../features/parent/dashboard/parent_dashboard_provider.dart';
import '../../../features/parent/events/events_models.dart';
import '../../../features/parent/exams/exam_models.dart';
import '../../../features/parent/fees/fees_provider.dart';
import '../../../features/parent/homework/homework_models.dart';
import '../../../features/parent/leave/leave_models.dart';
import '../../../features/parent/notices/notices_models.dart';
import '../../../features/parent/parent_requests.dart';
import '../../../features/parent/payment/payment_models.dart';
import '../../../features/parent/profile/profile_models.dart';
import '../../../features/parent/receipts/receipt_models.dart';
import '../../../features/parent/timetable/timetable_models.dart';
import '../interfaces/parent_repository.dart';
import '../repository_query.dart';
import 'mock_parent_write_store.dart';

class MockParentRepository implements ParentRepository {
  MockParentWriteStore get _store => MockParentWriteStore.instance;
  @override
  Future<ParentDashboardData> getDashboard({required RepositoryQuery query}) async =>
      ParentDashboardData.mock();

  @override
  Future<AttendanceMonthData> getAttendance({
    required RepositoryQuery query,
    required DateTime month,
  }) async {
    final base = AttendanceMonthData.mock(month: month);
    final sync = MockAttendanceSyncStore.instance;
    if (!sync.hasTeacherSubmission) {
      return base;
    }
    final total = sync.presentCount + sync.absentCount + sync.lateCount;
    final percent = total == 0
        ? base.kpi.attendancePercent
        : ((sync.presentCount / total) * 100).round();
    return AttendanceMonthData(
      month: base.month,
      childName: base.childName,
      childClass: base.childClass,
      kpi: AttendanceKpiMetrics(
        attendancePercent: percent,
        absentDays: sync.absentCount,
        lateDays: sync.lateCount,
      ),
      calendarDays: base.calendarDays,
      recentLogs: base.recentLogs,
      warningBannerMessage: base.warningBannerMessage,
      unreadNotifications: base.unreadNotifications,
      classTeacherPhone: base.classTeacherPhone,
    );
  }

  @override
  Future<ParentHomeworkData> getHomework({required RepositoryQuery query}) async =>
      ParentHomeworkData.mock();

  @override
  Future<ParentExamsData> getExams({required RepositoryQuery query}) async =>
      ParentExamsData.mock();

  @override
  Future<ParentTimetableData> getTimetable({required RepositoryQuery query}) async =>
      _parentTimetableWeekData();

  @override
  Future<ParentFeesData> getFees({required RepositoryQuery query}) async =>
      ParentFeesData.mock();

  @override
  Future<List<FeeReceipt>> getReceipts({required RepositoryQuery query}) async =>
      _mockReceipts();

  @override
  Future<List<ParentNotice>> getNotices({required RepositoryQuery query}) async =>
      _mockNotices();

  @override
  Future<ParentEventsData> getEvents({required RepositoryQuery query}) async =>
      _mockEvents();

  @override
  Future<List<LeaveRequest>> getLeaveHistory({required RepositoryQuery query}) async {
    await _ensureLeaveHistory();
    return List.from(_store.leaveRequests!);
  }

  @override
  Future<ParentProfileData> getProfile({
    required RepositoryQuery query,
    required String activeChildId,
  }) async {
    return ParentProfileData(
      parentName: 'Suresh Kumar',
      phoneLabel: '+91 98765 43210',
      email: 'suresh.kumar@email.com',
      schoolName: 'Akshara Public School',
      unreadNotifications: 2,
      children: [
        ParentChildProfile(
          id: 'child_ravi',
          name: 'Ravi Kumar',
          classLabel: '8-A',
          isActive: activeChildId == 'child_ravi',
        ),
        ParentChildProfile(
          id: 'child_ananya',
          name: 'Ananya Kumar',
          classLabel: '5-B',
          isActive: activeChildId == 'child_ananya',
        ),
      ],
    );
  }

  @override
  Future<PaymentSummary> getPaymentSummary({
    required RepositoryQuery query,
    required String installmentId,
  }) async =>
      _summaryForInstallment(installmentId);

  @override
  Future<LeaveRequest> submitLeaveRequest({
    required RepositoryQuery query,
    required ParentLeaveSubmitRequest request,
  }) async {
    await _ensureLeaveHistory();
    final child = _childProfileFor(request.childId);
    final leave = LeaveRequest(
      id: _store.nextLeaveId(),
      childName: child.name,
      childClass: child.classLabel,
      fromDateLabel: request.fromDateLabel,
      toDateLabel: request.toDateLabel,
      reason: request.reason.trim(),
      type: request.type,
      status: LeaveStatus.pending,
      submittedLabel: 'Submitted just now',
      hasAttachment: request.hasAttachment,
      attachmentName: request.attachmentName,
      timeline: const [
        LeaveTimelineStep(
          label: 'Submitted',
          dateLabel: 'Just now',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'Class teacher review',
          dateLabel: 'Pending',
          isComplete: false,
        ),
        LeaveTimelineStep(
          label: 'School approval',
          dateLabel: 'Pending',
          isComplete: false,
        ),
      ],
    );
    _store.leaveRequests!.insert(0, leave);
    return leave;
  }

  @override
  Future<PaymentInitiationResult> initiatePayment({
    required RepositoryQuery query,
    required ParentPaymentInitiateRequest request,
  }) async {
    final intentId = _store.nextPaymentIntentId();
    _store.paymentIntents[intentId] = request;
    return PaymentInitiationResult(
      paymentIntentId: intentId,
      installmentId: request.installmentId,
      amount: request.amount,
      status: 'pending',
      expiresAtLabel: 'Expires in 15 minutes',
    );
  }

  @override
  Future<PaymentConfirmationResult> confirmPayment({
    required RepositoryQuery query,
    required ParentPaymentConfirmRequest request,
  }) async {
    final intent = _store.paymentIntents[request.paymentIntentId];
    if (intent == null) {
      throw StateError('Payment intent not found: ${request.paymentIntentId}');
    }
    return PaymentConfirmationResult(
      receiptId: 'rcpt_${intent.installmentId}',
      receiptNumber: 'APS-2026-${intent.installmentId.toUpperCase()}',
      paidAmount: intent.amount,
      paymentMethod: intent.paymentMethod,
      paidAtLabel: 'Just now',
    );
  }

  @override
  Future<ParentAcademicSummary> getAcademicSummary({
    required RepositoryQuery query,
    required String studentId,
  }) async =>
      ParentAcademicSummary(
        studentId: studentId,
        attendanceSummary: const {'ratePercent': 92, 'presentDays': 23, 'totalDays': 25},
        performanceSummary: const {'overallGrade': 'A', 'trend': 'improving'},
        strengths: const ['Regular attendance', 'Strong in Mathematics'],
        weaknesses: const ['Science lab reports pending'],
        homeworkStatus: const {'submitted': 8, 'pending': 2, 'completionRate': 80},
        examReadiness: const {'readinessScore': 85, 'recommendation': 'On track for unit tests'},
        teacherRecommendations: const [
          'Review homework daily',
          'Practice science diagrams',
        ],
        generatedAt: DateTime.now().toIso8601String(),
      );

  @override
  Future<String> getPrintableReport({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final summary = await getAcademicSummary(query: query, studentId: studentId);
    return [
      'AKSHARA SCHOOL — PARENT ACADEMIC REPORT',
      'Attendance: ${summary.attendanceSummary['ratePercent']}%',
      'Grade: ${summary.performanceSummary['overallGrade']}',
      'Strengths: ${summary.strengths.join(', ')}',
    ].join('\n');
  }

  Future<void> _ensureLeaveHistory() async {
    _store.leaveRequests ??= List<LeaveRequest>.from(_mockLeaveHistory());
  }

  ParentChildProfile _childProfileFor(String childId) {
    return switch (childId) {
      'child_ananya' => const ParentChildProfile(
          id: 'child_ananya',
          name: 'Ananya Kumar',
          classLabel: '5-B',
          isActive: false,
        ),
      _ => const ParentChildProfile(
          id: 'child_ravi',
          name: 'Ravi Kumar',
          classLabel: '8-A',
          isActive: true,
        ),
    };
  }
}



ParentTimetableData _parentTimetableWeekData() {
  final days = <TimetableDay>[
    TimetableDay(
      id: 'mon',
      shortLabel: 'Mon',
      fullLabel: 'Monday',
      date: DateTime(2026, 6, 1),
      periods: const [
        TimetablePeriod(
          id: 'mon-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'English',
          teacherName: 'Priya Ma\'am',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'mon-p2',
          periodLabel: 'Period 2',
          timeRange: '09:20 - 10:05',
          subject: 'Mathematics',
          teacherName: 'Arun Sir',
          roomLabel: 'Room 203',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'mon-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'Science',
          teacherName: 'Nisha Ma\'am',
          roomLabel: 'Lab 2',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'mon-p4',
          periodLabel: 'Period 4',
          timeRange: '11:05 - 11:50',
          subject: 'Hindi',
          teacherName: 'Meena Ma\'am',
          roomLabel: 'Room 201',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'mon-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 01:15',
          subject: 'Social Science',
          teacherName: 'Rakesh Sir',
          roomLabel: 'Room 208',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'mon-p6',
          periodLabel: 'Period 6',
          timeRange: '01:20 - 02:05',
          subject: 'Computer',
          teacherName: 'Swapna Ma\'am',
          roomLabel: 'ICT Lab',
          status: TimetablePeriodStatus.done,
        ),
      ],
    ),
    TimetableDay(
      id: 'tue',
      shortLabel: 'Tue',
      fullLabel: 'Tuesday',
      date: DateTime(2026, 6, 2),
      periods: const [
        TimetablePeriod(
          id: 'tue-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'Mathematics',
          teacherName: 'Arun Sir',
          roomLabel: 'Room 203',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'tue-p2',
          periodLabel: 'Period 2',
          timeRange: '09:20 - 10:05',
          subject: 'English',
          teacherName: 'Priya Ma\'am',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'tue-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'Kannada',
          teacherName: 'Suma Ma\'am',
          roomLabel: 'Room 205',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'tue-p4',
          periodLabel: 'Period 4',
          timeRange: '11:05 - 11:50',
          subject: 'Science',
          teacherName: 'Nisha Ma\'am',
          roomLabel: 'Lab 2',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'tue-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 01:15',
          subject: 'Art',
          teacherName: 'Anita Ma\'am',
          roomLabel: 'Art Studio',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'tue-p6',
          periodLabel: 'Period 6',
          timeRange: '01:20 - 02:05',
          subject: 'Physical Education',
          teacherName: 'Rahul Sir',
          roomLabel: 'Ground',
          status: TimetablePeriodStatus.done,
        ),
      ],
    ),
    TimetableDay(
      id: 'wed',
      shortLabel: 'Wed',
      fullLabel: 'Wednesday',
      date: DateTime(2026, 6, 3),
      isToday: true,
      periods: const [
        TimetablePeriod(
          id: 'wed-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'Science',
          teacherName: 'Nisha Ma\'am',
          roomLabel: 'Lab 2',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'wed-p2',
          periodLabel: 'Period 2',
          timeRange: '09:20 - 10:05',
          subject: 'Mathematics',
          teacherName: 'Arun Sir',
          roomLabel: 'Room 203',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'wed-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'English',
          teacherName: 'Priya Ma\'am',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'wed-p4',
          periodLabel: 'Period 4',
          timeRange: '11:05 - 11:50',
          subject: 'Social Science',
          teacherName: 'Rakesh Sir',
          roomLabel: 'Room 205',
          status: TimetablePeriodStatus.now,
          isRoomChanged: true,
        ),
        TimetablePeriod(
          id: 'wed-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 01:15',
          subject: 'Computer',
          teacherName: 'Swapna Ma\'am',
          roomLabel: 'ICT Lab',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'wed-p6',
          periodLabel: 'Period 6',
          timeRange: '01:20 - 02:05',
          subject: 'Hindi',
          teacherName: 'Meena Ma\'am',
          roomLabel: 'Room 201',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'wed-p7',
          periodLabel: 'Period 7',
          timeRange: '02:10 - 02:50',
          subject: 'Library',
          teacherName: 'Shilpa Ma\'am',
          roomLabel: 'Library',
          status: TimetablePeriodStatus.upcoming,
        ),
      ],
    ),
    TimetableDay(
      id: 'thu',
      shortLabel: 'Thu',
      fullLabel: 'Thursday',
      date: DateTime(2026, 6, 4),
      periods: const [
        TimetablePeriod(
          id: 'thu-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'English',
          teacherName: 'Priya Ma\'am',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'thu-p2',
          periodLabel: 'Period 2',
          timeRange: '09:20 - 10:05',
          subject: 'Science',
          teacherName: 'Nisha Ma\'am',
          roomLabel: 'Lab 2',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'thu-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'Mathematics',
          teacherName: 'Arun Sir',
          roomLabel: 'Room 203',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'thu-p4',
          periodLabel: 'Period 4',
          timeRange: '11:05 - 11:50',
          subject: 'Kannada',
          teacherName: 'Suma Ma\'am',
          roomLabel: 'Room 205',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'thu-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 01:15',
          subject: 'Social Science',
          teacherName: 'Rakesh Sir',
          roomLabel: 'Room 208',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'thu-p6',
          periodLabel: 'Period 6',
          timeRange: '01:20 - 02:05',
          subject: 'Physical Education',
          teacherName: 'Rahul Sir',
          roomLabel: 'Ground',
          status: TimetablePeriodStatus.upcoming,
        ),
      ],
    ),
    TimetableDay(
      id: 'fri',
      shortLabel: 'Fri',
      fullLabel: 'Friday',
      date: DateTime(2026, 6, 5),
      periods: const [
        TimetablePeriod(
          id: 'fri-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'Mathematics',
          teacherName: 'Arun Sir',
          roomLabel: 'Room 203',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'fri-p2',
          periodLabel: 'Period 2',
          timeRange: '09:20 - 10:05',
          subject: 'Hindi',
          teacherName: 'Meena Ma\'am',
          roomLabel: 'Room 201',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'fri-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'Computer',
          teacherName: 'Swapna Ma\'am',
          roomLabel: 'ICT Lab',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'fri-p4',
          periodLabel: 'Period 4',
          timeRange: '11:05 - 11:50',
          subject: 'English',
          teacherName: 'Priya Ma\'am',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'fri-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 01:15',
          subject: 'Science',
          teacherName: 'Nisha Ma\'am',
          roomLabel: 'Lab 2',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'fri-p6',
          periodLabel: 'Period 6',
          timeRange: '01:20 - 02:05',
          subject: 'Social Science',
          teacherName: 'Rakesh Sir',
          roomLabel: 'Room 208',
          status: TimetablePeriodStatus.upcoming,
        ),
      ],
    ),
  ];

  return ParentTimetableData(
    childName: 'Ravi Kumar',
    childClass: '8-A',
    weekRangeLabel: '1 Jun - 5 Jun 2026',
    days: days,
    totalPeriodsThisWeek: days.fold<int>(
      0,
      (total, day) => total + day.periods.length,
    ),
    completedPeriodsToday: 3,
    upcomingPeriodsToday: 3,
    unreadNotifications: 2,
    scheduleChangeMessage:
        'Period 4 Social Science moved to Room 205 for today.',
  );
}




List<ParentNotice> _mockNotices() {
  return const [
    ParentNotice(
      id: 'n1',
      title: 'PTM scheduled for 15 June — please confirm your slot',
      dateLabel: '5 Jun 2026',
      summary:
          'Parent-teacher meetings will run in 15-minute slots between 2:00 PM and 6:00 PM.',
      category: NoticeCategory.academic,
      isUrgent: true,
    ),
    ParentNotice(
      id: 'n2',
      title: 'Summer vacation dates announced',
      dateLabel: '3 Jun 2026',
      summary: 'School closes from 1 Jul to 15 Jul. First day back is 16 Jul.',
      category: NoticeCategory.general,
    ),
    ParentNotice(
      id: 'n3',
      title: 'New transport route effective Monday',
      dateLabel: '1 Jun 2026',
      summary: 'Route 12 pickup time moves to 7:35 AM at Green Park stop.',
      category: NoticeCategory.transport,
    ),
    ParentNotice(
      id: 'n4',
      title: 'Annual health check-up camp on campus',
      dateLabel: '28 May 2026',
      summary: 'Consent forms must be submitted by 10 June.',
      category: NoticeCategory.general,
      isRead: true,
    ),
    ParentNotice(
      id: 'n5',
      title: 'Unit test schedule published for Term 2',
      dateLabel: '25 May 2026',
      summary: 'Mathematics and Science tests begin 12 June.',
      category: NoticeCategory.academic,
      isRead: true,
    ),
    ParentNotice(
      id: 'n6',
      title: 'Bus delay alert — Route 12 running 20 min late',
      dateLabel: '22 May 2026',
      summary: 'Traffic on Ring Road. Track live ETA in transport section.',
      category: NoticeCategory.transport,
      isUrgent: true,
      isRead: true,
    ),
  ];
}



List<FeeReceipt> _mockReceipts() {
  return const [
    FeeReceipt(
      id: 'rcpt_term_1',
      receiptNumber: 'APS-2026-TERM_1',
      title: 'Term 1 — Full payment',
      dateLabel: '15 Apr 2026',
      amount: 8000,
      paymentMethod: 'UPI',
      statusLabel: 'Paid',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      category: 'term',
      lineItems: [
        ReceiptLineItem(label: 'Tuition', amount: 6500),
        ReceiptLineItem(label: 'Transport', amount: 1000),
        ReceiptLineItem(label: 'Activity', amount: 500),
      ],
    ),
    FeeReceipt(
      id: 'rcpt_ph_2',
      receiptNumber: 'APS-2026-ADM-001',
      title: 'Admission fee',
      dateLabel: '2 Mar 2026',
      amount: 5000,
      paymentMethod: 'Net Banking',
      statusLabel: 'Paid',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      category: 'admission',
      lineItems: [
        ReceiptLineItem(label: 'Admission fee', amount: 4500),
        ReceiptLineItem(label: 'Registration', amount: 500),
      ],
    ),
    FeeReceipt(
      id: 'rcpt_ph_3',
      receiptNumber: 'APS-2026-TRN-Q1',
      title: 'Transport — Q1',
      dateLabel: '10 Jan 2026',
      amount: 1500,
      paymentMethod: 'Card',
      statusLabel: 'Paid',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      category: 'transport',
      lineItems: [
        ReceiptLineItem(label: 'Bus route A', amount: 1200),
        ReceiptLineItem(label: 'Fuel surcharge', amount: 300),
      ],
    ),
    FeeReceipt(
      id: 'rcpt_ph_4',
      receiptNumber: 'APS-2025-ACT-014',
      title: 'Activity kit',
      dateLabel: '5 Dec 2025',
      amount: 800,
      paymentMethod: 'UPI',
      statusLabel: 'Paid',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      category: 'term',
      lineItems: [
        ReceiptLineItem(label: 'Sports kit', amount: 500),
        ReceiptLineItem(label: 'Lab apron', amount: 300),
      ],
    ),
  ];
}


List<LeaveRequest> _mockLeaveHistory() {
  return const [
    LeaveRequest(
      id: 'lv_1',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      fromDateLabel: '10 Jun 2026',
      toDateLabel: '10 Jun 2026',
      reason: 'Fever and doctor advised rest for one day.',
      type: LeaveType.sick,
      status: LeaveStatus.pending,
      submittedLabel: 'Submitted 5 Jun 2026',
      hasAttachment: true,
      attachmentName: 'medical_note.pdf',
      timeline: [
        LeaveTimelineStep(
          label: 'Submitted',
          dateLabel: '5 Jun 2026 · 9:10 AM',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'Class teacher review',
          dateLabel: 'Expected by 6 Jun',
          isComplete: false,
        ),
        LeaveTimelineStep(
          label: 'School approval',
          dateLabel: 'Pending',
          isComplete: false,
        ),
      ],
    ),
    LeaveRequest(
      id: 'lv_2',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      fromDateLabel: '18 May 2026',
      toDateLabel: '19 May 2026',
      reason: 'Family wedding out of town.',
      type: LeaveType.family,
      status: LeaveStatus.approved,
      submittedLabel: 'Submitted 15 May 2026',
      timeline: [
        LeaveTimelineStep(
          label: 'Submitted',
          dateLabel: '15 May 2026 · 6:40 PM',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'Class teacher review',
          dateLabel: '16 May 2026 · Approved',
          isComplete: true,
          note: 'Reviewed by Arun Sir',
        ),
        LeaveTimelineStep(
          label: 'School approval',
          dateLabel: '16 May 2026 · Approved',
          isComplete: true,
        ),
      ],
    ),
    LeaveRequest(
      id: 'lv_3',
      childName: 'Ravi Kumar',
      childClass: '8-A',
      fromDateLabel: '2 Apr 2026',
      toDateLabel: '2 Apr 2026',
      reason: 'Travel plan overlapped with school day.',
      type: LeaveType.personal,
      status: LeaveStatus.rejected,
      submittedLabel: 'Submitted 1 Apr 2026',
      timeline: [
        LeaveTimelineStep(
          label: 'Submitted',
          dateLabel: '1 Apr 2026 · 8:05 AM',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'Class teacher review',
          dateLabel: '1 Apr 2026 · Rejected',
          isComplete: true,
          note: 'Exam day — leave not permitted',
        ),
        LeaveTimelineStep(
          label: 'School approval',
          dateLabel: 'Not required',
          isComplete: false,
        ),
      ],
    ),
  ];
}


ParentEventsData _mockEvents() {
  return const ParentEventsData(
    childName: 'Ravi Kumar',
    childClass: '8-A',
    unreadNotifications: 2,
    upcomingEvents: [
      ParentEvent(
        id: 'e1',
        day: 12,
        month: 'Jun',
        title: 'Science Exhibition',
        timeLabel: '9:00 AM',
        venueLabel: 'Main Hall',
        subtitle: '9:00 AM · Main Hall',
        isRsvpOpen: true,
      ),
      ParentEvent(
        id: 'e2',
        day: 18,
        month: 'Jun',
        title: 'Parent-Teacher Meeting',
        timeLabel: '2:00 PM',
        venueLabel: 'Block B',
        subtitle: '2:00 PM · Block B',
        isRsvpOpen: true,
      ),
      ParentEvent(
        id: 'e3',
        day: 25,
        month: 'Jun',
        title: 'Annual Sports Day',
        timeLabel: '8:00 AM',
        venueLabel: 'Sports Ground',
        subtitle: '8:00 AM · Sports Ground',
      ),
      ParentEvent(
        id: 'e4',
        day: 8,
        month: 'Jul',
        title: 'Inter-house Debate Finals',
        timeLabel: '11:00 AM',
        venueLabel: 'Auditorium',
        subtitle: '11:00 AM · Auditorium',
      ),
    ],
    pastEvents: [
      ParentEvent(
        id: 'e5',
        day: 20,
        month: 'May',
        title: 'Founders Day Assembly',
        timeLabel: '10:00 AM',
        venueLabel: 'Main Hall',
        subtitle: '10:00 AM · Main Hall',
        isPast: true,
      ),
      ParentEvent(
        id: 'e6',
        day: 5,
        month: 'May',
        title: 'Earth Day Plantation Drive',
        timeLabel: '7:30 AM',
        venueLabel: 'School Garden',
        subtitle: '7:30 AM · School Garden',
        isPast: true,
      ),
    ],
  );
}

PaymentSummary _summaryForInstallment(String installmentId) {
  return switch (installmentId) {
    'term_1' => const PaymentSummary(
        installmentId: 'term_1',
        installmentTitle: 'Term 1',
        childName: 'Ravi Kumar',
        childClass: '8-A',
        dueLabel: 'Paid 15 Apr 2026',
        baseAmount: 8000,
        lateFee: 0,
        convenienceFee: 0,
        breakdown: [
          PaymentBreakdownLine(label: 'Tuition', amount: 6500),
          PaymentBreakdownLine(label: 'Transport', amount: 1000),
          PaymentBreakdownLine(label: 'Activity', amount: 500),
        ],
      ),
    _ => const PaymentSummary(
        installmentId: 'term_2',
        installmentTitle: 'Term 2',
        childName: 'Ravi Kumar',
        childClass: '8-A',
        dueLabel: 'Due 12 Jun 2026',
        baseAmount: 4000,
        lateFee: 200,
        convenienceFee: 0,
        unreadNotifications: 2,
        breakdown: [
          PaymentBreakdownLine(label: 'Tuition', amount: 3200),
          PaymentBreakdownLine(label: 'Transport', amount: 600),
          PaymentBreakdownLine(label: 'Activity', amount: 200),
          PaymentBreakdownLine(label: 'Late fee', amount: 200),
        ],
      ),
  };
}

