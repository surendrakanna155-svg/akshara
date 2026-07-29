import '../../../../../core/communication/parent_communication_models.dart';
import '../../../../../core/i18n/supported_languages.dart';
import '../../../../../features/parent/attendance/attendance_models.dart';
import '../../../../../features/parent/dashboard/parent_dashboard_provider.dart';
import '../../../../../features/parent/events/events_models.dart';
import '../../../../../features/parent/exams/exam_models.dart';
import '../../../../../features/parent/fees/fee_certificate_models.dart';
import '../../../../../features/parent/fees/fees_provider.dart';
import '../../../../../features/parent/homework/homework_models.dart';
import '../../../../../features/parent/leave/leave_models.dart';
import '../../../../../features/parent/notices/notices_models.dart';
import '../../../../../features/parent/parent_requests.dart';
import '../../../../../features/parent/payment/payment_models.dart';
import '../../../../../features/parent/profile/profile_models.dart';
import '../../../../../features/parent/receipts/receipt_models.dart';
import '../../../../../features/parent/timetable/timetable_models.dart';
import '../dto/parent_communication_dto.dart';
import '../dto/parent_enum_codec.dart';
import '../dto/parent_payment_request_dto.dart';
import '../dto/parent_responses_dto.dart';

/// Maps Parent mobile API DTOs to domain models.
class ParentMapper {
  const ParentMapper();

  ParentDashboardData toDashboard(ParentDashboardDto dto) {
    final raw = dto.raw;
    return ParentDashboardData(
      childName: raw['childName'] as String? ?? '',
      childClass: raw['childClass'] as String? ?? '',
      greetingEyebrow: raw['greetingEyebrow'] as String? ?? '',
      greetingHeadline: raw['greetingHeadline'] as String? ?? '',
      schoolName: raw['schoolName'] as String? ?? '',
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
      statusChips: _mapStatusChips(raw['statusChips'] as List<dynamic>? ?? const []),
      quickActions: _mapQuickActions(raw['quickActions'] as List<dynamic>? ?? const []),
      todaySummary: _mapTodaySummary(raw['todaySummary'] as List<dynamic>? ?? const []),
      notices: _mapDashboardNotices(raw['notices'] as List<dynamic>? ?? const []),
      events: _mapDashboardEvents(raw['events'] as List<dynamic>? ?? const []),
      aiInsight: _mapAiInsight(raw['aiInsight'] as Map<String, dynamic>? ?? const {}),
    );
  }

  AttendanceMonthData toAttendance(ParentAttendanceResponseDto dto) {
    final raw = dto.raw;
    final monthRaw = raw['month'] as String? ?? '';
    final monthParts = monthRaw.split('-');
    final month = monthParts.length >= 2
        ? DateTime(int.parse(monthParts[0]), int.parse(monthParts[1]), 1)
        : DateTime.now();

    return AttendanceMonthData(
      month: month,
      childName: raw['childName'] as String? ?? '',
      childClass: raw['childClass'] as String? ?? '',
      kpi: _mapAttendanceKpi(raw['kpi'] as Map<String, dynamic>? ?? const {}),
      calendarDays: _mapCalendarDays(raw['calendarDays'] as List<dynamic>? ?? const []),
      recentLogs: _mapRecentLogs(raw['recentLogs'] as List<dynamic>? ?? const []),
      warningBannerMessage: raw['warningBannerMessage'] as String?,
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
      classTeacherPhone: raw['classTeacherPhone'] as String?,
    );
  }

  ParentHomeworkData toHomework(ParentHomeworkResponseDto dto) {
    final raw = dto.raw;
    return ParentHomeworkData(
      childName: raw['childName'] as String? ?? '',
      childClass: raw['childClass'] as String? ?? '',
      items: _mapHomeworkItems(raw['items'] as List<dynamic>? ?? const []),
      insightMessage: raw['insightMessage'] as String? ?? '',
      insightActionLabel: raw['insightActionLabel'] as String? ?? '',
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
    );
  }

  ParentExamsData toExams(ParentExamsResponseDto dto) {
    final raw = dto.raw;
    return ParentExamsData(
      childName: raw['childName'] as String? ?? '',
      childClass: raw['childClass'] as String? ?? '',
      schoolName: raw['schoolName'] as String? ?? '',
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
      upcomingExams: _mapUpcomingExams(raw['upcomingExams'] as List<dynamic>? ?? const []),
      examResults: _mapExamResults(raw['examResults'] as List<dynamic>? ?? const []),
    );
  }

  ParentTimetableData toTimetable(ParentTimetableResponseDto dto) {
    final raw = dto.raw;
    return ParentTimetableData(
      childName: raw['childName'] as String? ?? '',
      childClass: raw['childClass'] as String? ?? '',
      weekRangeLabel: raw['weekRangeLabel'] as String? ?? '',
      days: _mapTimetableDays(raw['days'] as List<dynamic>? ?? const []),
      totalPeriodsThisWeek: raw['totalPeriodsThisWeek'] as int? ?? 0,
      completedPeriodsToday: raw['completedPeriodsToday'] as int? ?? 0,
      upcomingPeriodsToday: raw['upcomingPeriodsToday'] as int? ?? 0,
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
      scheduleChangeMessage: raw['scheduleChangeMessage'] as String?,
    );
  }

  /// Honest-state contract for money fields.
  ///
  /// [ParentFeesData] carries non-nullable `int`s, so an ABSENT amount (no fee
  /// structure published for this student yet) is indistinguishable from a
  /// measured zero at this layer — both arrive as `0`. The presentation layer
  /// therefore treats `annualAmount <= 0` as "no published fee structure" and
  /// suppresses the derived collection percentage (a percentage against a zero
  /// denominator is undefined, not 0%) — see `FeeSummaryHero` /
  /// `FeeCollectionProgress`. Do NOT synthesize a `progressPercent` here from
  /// paid/annual: the backend owns that arithmetic.
  ParentFeesData toFees(ParentFeesResponseDto dto) {
    final raw = dto.raw;
    return ParentFeesData(
      pendingAmount: raw['pendingAmount'] as int? ?? 0,
      isOverdue: raw['isOverdue'] as bool? ?? false,
      dueLabel: raw['dueLabel'] as String? ?? '',
      paidAmount: raw['paidAmount'] as int? ?? 0,
      annualAmount: raw['annualAmount'] as int? ?? 0,
      progressPercent: raw['progressPercent'] as int? ?? 0,
      installments: _mapInstallments(raw['installments'] as List<dynamic>? ?? const []),
      breakdown: _mapBreakdown(raw['breakdown'] as List<dynamic>? ?? const []),
      paymentHistory: _mapPaymentHistory(raw['paymentHistory'] as List<dynamic>? ?? const []),
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
    );
  }

  List<FeeReceipt> toReceipts(ParentReceiptsResponseDto dto) {
    return [for (final item in dto.items) toReceipt(item)];
  }

  FeeReceipt toReceipt(ParentReceiptDto dto) {
    final raw = dto.raw;
    return FeeReceipt(
      id: raw['id'] as String? ?? '',
      receiptNumber: raw['receiptNumber'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      dateLabel: raw['dateLabel'] as String? ?? '',
      amount: raw['amount'] as int? ?? 0,
      paymentMethod: raw['paymentMethod'] as String? ?? '',
      statusLabel: raw['statusLabel'] as String? ?? '',
      childName: raw['childName'] as String? ?? '',
      childClass: raw['childClass'] as String? ?? '',
      category: raw['category'] as String? ?? '',
      lineItems: _mapReceiptLineItems(raw['lineItems'] as List<dynamic>? ?? const []),
      schoolName: raw['schoolName'] as String? ?? 'Akshara Public School',
    );
  }

  FeeCertificateData toFeeCertificate(ParentFeeCertificateResponseDto dto) {
    final raw = dto.raw;
    final psid = raw['publicStudentId'] as String?;
    final admission = raw['admissionNumber'] as String?;
    return FeeCertificateData(
      schoolName: raw['schoolName'] as String? ?? 'Akshara Public School',
      guardianName: raw['guardianName'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? 'Student',
      publicStudentId: (psid == null || psid.isEmpty) ? null : psid,
      admissionNumber:
          (admission == null || admission.isEmpty) ? null : admission,
      academicYear: raw['academicYear'] as String? ?? '',
      totalPaidAmount: _toDouble(raw['totalPaidAmount']),
      payments: [
        for (final item in raw['payments'] as List<dynamic>? ?? const [])
          _toFeeCertificatePayment(item as Map<String, dynamic>),
      ],
      signatoryTitle: raw['signatoryTitle'] as String? ?? 'Principal',
    );
  }

  FeeCertificatePayment _toFeeCertificatePayment(Map<String, dynamic> raw) {
    return FeeCertificatePayment(
      date: raw['date'] as String? ?? '',
      receiptNo: raw['receiptNo'] as String? ?? '',
      amount: _toDouble(raw['amount']),
      paymentMethod: raw['paymentMethod'] as String? ?? '',
      description: raw['description'] as String? ?? '',
    );
  }

  double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  List<ParentNotice> toNotices(ParentNoticesResponseDto dto) {
    return [for (final item in dto.items) toNotice(item)];
  }

  ParentNotice toNotice(ParentNoticeDto dto) {
    final raw = dto.raw;
    return ParentNotice(
      id: raw['id'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      dateLabel: raw['dateLabel'] as String? ?? '',
      summary: raw['summary'] as String? ?? '',
      category: ParentEnumCodec.parseNoticeCategory(raw['category'] as String?),
      isUrgent: raw['isUrgent'] as bool? ?? false,
      isRead: raw['isRead'] as bool? ?? false,
    );
  }

  ParentEventsData toEvents(ParentEventsResponseDto dto) {
    final raw = dto.raw;
    return ParentEventsData(
      childName: raw['childName'] as String? ?? '',
      childClass: raw['childClass'] as String? ?? '',
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
      upcomingEvents: _mapEvents(raw['upcomingEvents'] as List<dynamic>? ?? const []),
      pastEvents: _mapEvents(raw['pastEvents'] as List<dynamic>? ?? const []),
    );
  }

  List<LeaveRequest> toLeaveHistory(ParentLeaveResponseDto dto) {
    return [for (final item in dto.items) toLeaveRequest(item)];
  }

  LeaveRequest toLeaveRequest(ParentLeaveRequestDto dto) {
    final raw = dto.raw;
    return LeaveRequest(
      id: raw['id'] as String? ?? '',
      childName: raw['childName'] as String? ?? '',
      childClass: raw['childClass'] as String? ?? '',
      fromDateLabel: raw['fromDateLabel'] as String? ?? '',
      toDateLabel: raw['toDateLabel'] as String? ?? '',
      reason: raw['reason'] as String? ?? '',
      type: ParentEnumCodec.parseLeaveType(raw['type'] as String?),
      status: ParentEnumCodec.parseLeaveStatus(raw['status'] as String?),
      submittedLabel: raw['submittedLabel'] as String? ?? '',
      timeline: _mapLeaveTimeline(raw['timeline'] as List<dynamic>? ?? const []),
      hasAttachment: raw['hasAttachment'] as bool? ?? false,
      attachmentName: raw['attachmentName'] as String?,
    );
  }

  ParentLeaveCancelResult toLeaveCancelResult(Map<String, dynamic> raw) {
    return ParentLeaveCancelResult(
      id: raw['id'] as String? ?? '',
      status: ParentEnumCodec.parseLeaveStatus(raw['status'] as String?),
    );
  }

  ParentLeaveAttachmentResult toLeaveAttachmentResult(Map<String, dynamic> raw) {
    return ParentLeaveAttachmentResult(
      id: raw['id'] as String? ?? '',
      hasAttachment: raw['hasAttachment'] as bool? ?? true,
      attachmentName: raw['attachmentName'] as String? ?? '',
    );
  }

  ParentProfileData toProfile(ParentProfileResponseDto dto) {
    final raw = dto.raw;
    return ParentProfileData(
      parentName: raw['parentName'] as String? ?? '',
      phoneLabel: raw['phoneLabel'] as String? ?? '',
      email: raw['email'] as String? ?? '',
      schoolName: raw['schoolName'] as String? ?? '',
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
      children: _mapChildren(raw['children'] as List<dynamic>? ?? const []),
    );
  }

  PaymentSummary toPaymentSummary(ParentPaymentSummaryResponseDto dto) {
    final raw = dto.raw;
    return PaymentSummary(
      installmentId: raw['installmentId'] as String? ?? '',
      installmentTitle: raw['installmentTitle'] as String? ?? '',
      childName: raw['childName'] as String? ?? '',
      childClass: raw['childClass'] as String? ?? '',
      dueLabel: raw['dueLabel'] as String? ?? '',
      baseAmount: raw['baseAmount'] as int? ?? 0,
      lateFee: raw['lateFee'] as int? ?? 0,
      convenienceFee: raw['convenienceFee'] as int? ?? 0,
      breakdown: _mapPaymentBreakdown(raw['breakdown'] as List<dynamic>? ?? const []),
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
    );
  }

  PaymentInitiationResult toPaymentInitiation(
    ParentPaymentInitiationResponseDto dto,
  ) {
    final raw = dto.raw;
    return PaymentInitiationResult(
      paymentIntentId: raw['paymentIntentId'] as String? ?? '',
      installmentId: raw['installmentId'] as String? ?? '',
      amount: raw['amount'] as int? ?? 0,
      status: raw['status'] as String? ?? 'pending',
      expiresAtLabel: raw['expiresAtLabel'] as String?,
    );
  }

  PaymentConfirmationResult toPaymentConfirmation(
    ParentPaymentConfirmationResponseDto dto,
  ) {
    final raw = dto.raw;
    return PaymentConfirmationResult(
      receiptId: raw['receiptId'] as String? ?? '',
      receiptNumber: raw['receiptNumber'] as String? ?? '',
      paidAmount: raw['paidAmount'] as int? ?? 0,
      paymentMethod: _parsePaymentMethod(raw['paymentMethod'] as String?),
      paidAtLabel: raw['paidAtLabel'] as String? ?? '',
    );
  }

  PaymentMethod _parsePaymentMethod(String? value) {
    return switch (value) {
      'card' => PaymentMethod.card,
      'net_banking' => PaymentMethod.netBanking,
      _ => PaymentMethod.upi,
    };
  }

  List<DashboardStatusChip> _mapStatusChips(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          DashboardStatusChip(
            label: item['label'] as String? ?? '',
            tone: ParentEnumCodec.parseDashboardChipTone(item['tone'] as String?),
            // Typed when the server sends it; otherwise classified once, here,
            // rather than sniffed at every render site.
            kind: _chipKind(item),
          ),
    ];
  }

  DashboardChipKind _chipKind(Map<String, dynamic> item) {
    final raw = (item['kind'] ?? item['id']) as String?;
    if (raw != null) {
      for (final kind in DashboardChipKind.values) {
        if (kind.name == raw) return kind;
      }
    }
    return classifyDashboardChip(item['label'] as String? ?? '');
  }

  List<DashboardQuickAction> _mapQuickActions(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          DashboardQuickAction(
            id: item['id'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: ParentEnumCodec.iconForQuickAction(
              item['icon'] as String?,
              item['id'] as String?,
            ),
          ),
    ];
  }

  List<TodaySummaryItem> _mapTodaySummary(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TodaySummaryItem(
            id: item['id'] as String? ?? '',
            icon: ParentEnumCodec.iconForSummary(
              item['icon'] as String?,
              item['id'] as String?,
            ),
            iconTone: ParentEnumCodec.parseDashboardChipTone(item['iconTone'] as String?),
            title: item['title'] as String? ?? '',
          ),
    ];
  }

  List<DashboardNotice> _mapDashboardNotices(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          DashboardNotice(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            dateLabel: item['dateLabel'] as String? ?? '',
            isUrgent: item['isUrgent'] as bool? ?? false,
          ),
    ];
  }

  List<DashboardEvent> _mapDashboardEvents(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          DashboardEvent(
            id: item['id'] as String? ?? '',
            day: item['day'] as int? ?? 0,
            month: item['month'] as String? ?? '',
            title: item['title'] as String? ?? '',
            subtitle: item['subtitle'] as String?,
          ),
    ];
  }

  DashboardAiInsight _mapAiInsight(Map<String, dynamic> raw) {
    return DashboardAiInsight(
      message: raw['message'] as String? ?? '',
      actionLabel: raw['actionLabel'] as String? ?? '',
    );
  }

  AttendanceKpiMetrics _mapAttendanceKpi(Map<String, dynamic> raw) {
    return AttendanceKpiMetrics(
      attendancePercent: raw['attendancePercent'] as int? ?? 0,
      absentDays: raw['absentDays'] as int? ?? 0,
      lateDays: raw['lateDays'] as int? ?? 0,
    );
  }

  List<AttendanceCalendarDay> _mapCalendarDays(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AttendanceCalendarDay(
            date: item['date'] != null ? DateTime.tryParse(item['date'] as String) : null,
            status: ParentEnumCodec.parseAttendanceDayStatus(item['status'] as String?),
            dayNumber: item['dayNumber'] as int?,
            isSelected: item['isSelected'] as bool? ?? false,
            markedAt: item['markedAt'] as String?,
            detailTitle: item['detailTitle'] as String?,
            detailBody: item['detailBody'] as String?,
            detailNote: item['detailNote'] as String?,
          ),
    ];
  }

  List<AttendanceDayLog> _mapRecentLogs(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AttendanceDayLog(
            date: DateTime.tryParse(item['date'] as String? ?? '') ?? DateTime.now(),
            status: ParentEnumCodec.parseAttendanceDayStatus(item['status'] as String?),
            detail: item['detail'] as String? ?? '',
            detailTitle: item['detailTitle'] as String? ?? '',
            detailBody: item['detailBody'] as String? ?? '',
            detailNote: item['detailNote'] as String?,
          ),
    ];
  }

  List<ParentHomeworkItem> _mapHomeworkItems(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ParentHomeworkItem(
            id: item['id'] as String? ?? '',
            subject: item['subject'] as String? ?? '',
            title: item['title'] as String? ?? '',
            dueLabel: item['dueLabel'] as String? ?? '',
            dueDate: item['dueDate'] as String?,
            status: ParentEnumCodec.parseHomeworkStatus(item['status'] as String?),
            // HWK-4 teacher attachment + HWK-7 child submission note/attachment,
            // surfaced from the real-state overlay.
            attachmentLabel: item['attachmentName'] as String? ??
                item['attachmentLabel'] as String?,
            attachmentRef: item['attachmentRef'] as String?,
            reviewGrade: item['reviewGrade'] as String?,
            reviewComment: item['reviewComment'] as String?,
            submissionNote: item['submissionNote'] as String?,
            submissionAttachmentLabel:
                item['submissionAttachmentLabel'] as String?,
          ),
    ];
  }

  List<ExamScheduleItem> _mapUpcomingExams(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ExamScheduleItem(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            subject: item['subject'] as String? ?? '',
            dateLabel: item['dateLabel'] as String? ?? '',
            timeLabel: item['timeLabel'] as String? ?? '',
            venueLabel: item['venueLabel'] as String? ?? '',
            syllabusLabel: item['syllabusLabel'] as String? ?? '',
            isToday: item['isToday'] as bool? ?? false,
          ),
    ];
  }

  List<ExamResultItem> _mapExamResults(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ExamResultItem(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            termLabel: item['termLabel'] as String? ?? '',
            dateLabel: item['dateLabel'] as String? ?? '',
            scoreObtained: item['scoreObtained'] as int? ?? 0,
            maxScore: item['maxScore'] as int? ?? 0,
            grade: item['grade'] as String? ?? '',
            remarks: item['remarks'] as String?,
          ),
    ];
  }

  List<TimetableDay> _mapTimetableDays(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TimetableDay(
            id: item['id'] as String? ?? '',
            shortLabel: item['shortLabel'] as String? ?? '',
            fullLabel: item['fullLabel'] as String? ?? '',
            date: DateTime.tryParse(item['date'] as String? ?? '') ?? DateTime.now(),
            periods: _mapTimetablePeriods(item['periods'] as List<dynamic>? ?? const []),
            isSelected: item['isSelected'] as bool? ?? false,
            isToday: item['isToday'] as bool? ?? false,
          ),
    ];
  }

  List<TimetablePeriod> _mapTimetablePeriods(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TimetablePeriod(
            id: item['id'] as String? ?? '',
            periodLabel: item['periodLabel'] as String? ?? '',
            timeRange: item['timeRange'] as String? ?? '',
            subject: item['subject'] as String? ?? '',
            teacherName: item['teacherName'] as String? ?? '',
            roomLabel: item['roomLabel'] as String? ?? '',
            status: ParentEnumCodec.parseTimetablePeriodStatus(item['status'] as String?),
            isRoomChanged: item['isRoomChanged'] as bool? ?? false,
          ),
    ];
  }

  List<FeeInstallment> _mapInstallments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          FeeInstallment(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            amount: item['amount'] as int? ?? 0,
            status: ParentEnumCodec.parseFeeInstallmentStatus(item['status'] as String?),
            meta: item['meta'] as String?,
            dueDateLabel: item['dueDateLabel'] as String?,
            hasReceipt: item['hasReceipt'] as bool? ?? false,
            isLast: item['isLast'] as bool? ?? false,
          ),
    ];
  }

  List<FeeBreakdownCategory> _mapBreakdown(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          FeeBreakdownCategory(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            initiallyExpanded: item['initiallyExpanded'] as bool? ?? false,
            lines: _mapFeeBreakdownLines(item['lines'] as List<dynamic>? ?? const []),
          ),
    ];
  }

  List<FeeBreakdownLine> _mapFeeBreakdownLines(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          FeeBreakdownLine(
            label: item['label'] as String? ?? '',
            amount: item['amount'] as int? ?? 0,
          ),
    ];
  }

  List<PaymentHistoryItem> _mapPaymentHistory(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          PaymentHistoryItem(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            dateLabel: item['dateLabel'] as String? ?? '',
            amount: item['amount'] as int? ?? 0,
            statusLabel: item['statusLabel'] as String? ?? '',
            isSuccess: item['isSuccess'] as bool? ?? false,
          ),
    ];
  }

  List<ReceiptLineItem> _mapReceiptLineItems(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ReceiptLineItem(
            label: item['label'] as String? ?? '',
            amount: item['amount'] as int? ?? 0,
          ),
    ];
  }

  List<ParentEvent> _mapEvents(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ParentEvent(
            id: item['id'] as String? ?? '',
            day: item['day'] as int? ?? 0,
            month: item['month'] as String? ?? '',
            title: item['title'] as String? ?? '',
            timeLabel: item['timeLabel'] as String? ?? '',
            venueLabel: item['venueLabel'] as String? ?? '',
            subtitle: item['subtitle'] as String?,
            isRsvpOpen: item['isRsvpOpen'] as bool? ?? false,
            isPast: item['isPast'] as bool? ?? false,
          ),
    ];
  }

  List<LeaveTimelineStep> _mapLeaveTimeline(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          LeaveTimelineStep(
            label: item['label'] as String? ?? '',
            dateLabel: item['dateLabel'] as String? ?? '',
            isComplete: item['isComplete'] as bool? ?? false,
            note: item['note'] as String?,
          ),
    ];
  }

  List<ParentChildProfile> _mapChildren(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ParentChildProfile(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            classLabel: item['classLabel'] as String? ?? '',
            isActive: item['isActive'] as bool? ?? false,
          ),
    ];
  }

  List<PaymentBreakdownLine> _mapPaymentBreakdown(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          PaymentBreakdownLine(
            label: item['label'] as String? ?? '',
            amount: item['amount'] as int? ?? 0,
          ),
    ];
  }

  List<ParentCommunicationInboxItem> toCommunicationInbox(
    ParentCommunicationInboxResponseDto dto,
  ) {
    return [
      for (final item in dto.items)
        if (toCommunicationInboxItem(item) case final mapped?) mapped,
    ];
  }

  ParentCommunicationInboxItem? toCommunicationInboxItem(
    Map<String, dynamic> raw,
  ) {
    final id = raw['id'] as String? ?? '';
    if (id.isEmpty) return null;
    final channelsRaw = raw['channels'] as List<dynamic>? ?? const [];
    final statusRaw =
        raw['deliveryStatus'] as String? ?? raw['delivery_status'] as String?;
    return ParentCommunicationInboxItem(
      id: id,
      sisStudentId: raw['sisStudentId'] as String? ??
          raw['sis_student_id'] as String? ??
          '',
      studentName: raw['studentName'] as String? ??
          raw['student_name'] as String? ??
          '',
      senderName: raw['senderName'] as String? ??
          raw['sender_name'] as String? ??
          '',
      reasonLabel: raw['reasonLabel'] as String? ??
          raw['reason_label'] as String? ??
          '',
      originalMessage: raw['originalMessage'] as String? ??
          raw['original_message'] as String? ??
          '',
      translatedMessage: raw['translatedMessage'] as String? ??
          raw['translated_message'] as String? ??
          '',
      targetLanguage: AksharaLanguage.fromCode(
        raw['targetLanguage'] as String? ?? raw['target_language'] as String?,
      ),
      channels: [
        for (final channel in channelsRaw)
          ParentCommunicationChannel.values.firstWhere(
            (c) => c.name == channel,
            orElse: () => ParentCommunicationChannel.inApp,
          ),
      ],
      sentAt: DateTime.tryParse(
            raw['sentAt'] as String? ?? raw['sent_at'] as String? ?? '',
          ) ??
          DateTime.now(),
      sentAtLabel: raw['sentAtLabel'] as String? ??
          raw['sent_at_label'] as String? ??
          '',
      deliveryStatus: ParentCommunicationDeliveryStatus.values.firstWhere(
        (s) => s.name == statusRaw,
        orElse: () => ParentCommunicationDeliveryStatus.delivered,
      ),
      isUnread: raw['isUnread'] as bool? ?? raw['is_unread'] as bool? ?? true,
      readAt: DateTime.tryParse(
        raw['readAt'] as String? ?? raw['read_at'] as String? ?? '',
      ),
      acknowledgedAt: DateTime.tryParse(
        raw['acknowledgedAt'] as String? ??
            raw['acknowledged_at'] as String? ??
            '',
      ),
    );
  }
}
