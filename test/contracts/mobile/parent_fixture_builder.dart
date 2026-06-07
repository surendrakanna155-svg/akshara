import 'package:akshara_erp/core/repositories/api/parent/dto/parent_enum_codec.dart';
import 'package:akshara_erp/features/parent/attendance/attendance_models.dart';
import 'package:akshara_erp/features/parent/dashboard/parent_dashboard_provider.dart';
import 'package:akshara_erp/features/parent/events/events_models.dart';
import 'package:akshara_erp/features/parent/exams/exam_models.dart';
import 'package:akshara_erp/features/parent/fees/fees_provider.dart';
import 'package:akshara_erp/features/parent/homework/homework_models.dart';
import 'package:akshara_erp/features/parent/leave/leave_models.dart';
import 'package:akshara_erp/features/parent/notices/notices_models.dart';
import 'package:akshara_erp/features/parent/payment/payment_models.dart';
import 'package:akshara_erp/features/parent/profile/profile_models.dart';
import 'package:akshara_erp/features/parent/receipts/receipt_models.dart';
import 'package:akshara_erp/features/parent/timetable/timetable_models.dart';

/// Builds API-shaped JSON envelopes from Parent domain models for contract tests.
class ParentFixtureBuilder {
  const ParentFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> dashboardEnvelope(ParentDashboardData data) {
    return envelope({
      'childName': data.childName,
      'childClass': data.childClass,
      'greetingEyebrow': data.greetingEyebrow,
      'greetingHeadline': data.greetingHeadline,
      'schoolName': data.schoolName,
      'unreadNotifications': data.unreadNotifications,
      'statusChips': [
        for (final chip in data.statusChips)
          {
            'label': chip.label,
            'tone': ParentEnumCodec.dashboardChipToneToApi(chip.tone),
          },
      ],
      'quickActions': [
        for (final action in data.quickActions)
          {
            'id': action.id,
            'label': action.label,
            'icon': action.id,
          },
      ],
      'todaySummary': [
        for (final item in data.todaySummary)
          {
            'id': item.id,
            'icon': item.id,
            'iconTone': ParentEnumCodec.dashboardChipToneToApi(item.iconTone),
            'title': item.title,
          },
      ],
      'notices': [
        for (final notice in data.notices)
          {
            'id': notice.id,
            'title': notice.title,
            'dateLabel': notice.dateLabel,
            'isUrgent': notice.isUrgent,
          },
      ],
      'events': [
        for (final event in data.events)
          {
            'id': event.id,
            'day': event.day,
            'month': event.month,
            'title': event.title,
            'subtitle': event.subtitle,
          },
      ],
      'aiInsight': {
        'message': data.aiInsight.message,
        'actionLabel': data.aiInsight.actionLabel,
      },
    });
  }

  Map<String, dynamic> attendanceEnvelope(AttendanceMonthData data) {
    return envelope({
      'month': '${data.month.year}-${data.month.month.toString().padLeft(2, '0')}',
      'childName': data.childName,
      'childClass': data.childClass,
      'kpi': {
        'attendancePercent': data.kpi.attendancePercent,
        'absentDays': data.kpi.absentDays,
        'lateDays': data.kpi.lateDays,
      },
      'calendarDays': [
        for (final day in data.calendarDays)
          {
            if (day.date != null) 'date': day.date!.toIso8601String().split('T').first,
            'status': ParentEnumCodec.attendanceDayStatusToApi(day.status),
            'dayNumber': day.dayNumber,
            'isSelected': day.isSelected,
            if (day.markedAt != null) 'markedAt': day.markedAt,
            if (day.detailTitle != null) 'detailTitle': day.detailTitle,
            if (day.detailBody != null) 'detailBody': day.detailBody,
            if (day.detailNote != null) 'detailNote': day.detailNote,
          },
      ],
      'recentLogs': [
        for (final log in data.recentLogs)
          {
            'date': log.date.toIso8601String().split('T').first,
            'status': ParentEnumCodec.attendanceDayStatusToApi(log.status),
            'detail': log.detail,
            'detailTitle': log.detailTitle,
            'detailBody': log.detailBody,
            if (log.detailNote != null) 'detailNote': log.detailNote,
          },
      ],
      if (data.warningBannerMessage != null)
        'warningBannerMessage': data.warningBannerMessage,
      'unreadNotifications': data.unreadNotifications,
    });
  }

  Map<String, dynamic> homeworkEnvelope(ParentHomeworkData data) {
    return envelope({
      'childName': data.childName,
      'childClass': data.childClass,
      'insightMessage': data.insightMessage,
      'insightActionLabel': data.insightActionLabel,
      'unreadNotifications': data.unreadNotifications,
      'items': [
        for (final item in data.items)
          {
            'id': item.id,
            'subject': item.subject,
            'title': item.title,
            'dueLabel': item.dueLabel,
            'status': ParentEnumCodec.homeworkStatusToApi(item.status),
          },
      ],
    });
  }

  Map<String, dynamic> examsEnvelope(ParentExamsData data) {
    return envelope({
      'childName': data.childName,
      'childClass': data.childClass,
      'unreadNotifications': data.unreadNotifications,
      'upcomingExams': [
        for (final exam in data.upcomingExams) upcomingExamItem(exam),
      ],
      'examResults': [
        for (final result in data.examResults) examResultItem(result),
      ],
    });
  }

  Map<String, dynamic> upcomingExamItem(ExamScheduleItem exam) => {
        'id': exam.id,
        'title': exam.title,
        'subject': exam.subject,
        'dateLabel': exam.dateLabel,
        'timeLabel': exam.timeLabel,
        'venueLabel': exam.venueLabel,
        'syllabusLabel': exam.syllabusLabel,
        'isToday': exam.isToday,
      };

  Map<String, dynamic> examResultItem(ExamResultItem result) => {
        'id': result.id,
        'title': result.title,
        'termLabel': result.termLabel,
        'dateLabel': result.dateLabel,
        'scoreObtained': result.scoreObtained,
        'maxScore': result.maxScore,
        'grade': result.grade,
        if (result.remarks != null) 'remarks': result.remarks,
      };

  Map<String, dynamic> timetableEnvelope(ParentTimetableData data) {
    return envelope({
      'childName': data.childName,
      'childClass': data.childClass,
      'weekRangeLabel': data.weekRangeLabel,
      'totalPeriodsThisWeek': data.totalPeriodsThisWeek,
      'completedPeriodsToday': data.completedPeriodsToday,
      'upcomingPeriodsToday': data.upcomingPeriodsToday,
      'unreadNotifications': data.unreadNotifications,
      if (data.scheduleChangeMessage != null)
        'scheduleChangeMessage': data.scheduleChangeMessage,
      'days': [for (final day in data.days) timetableDayItem(day)],
    });
  }

  Map<String, dynamic> timetableDayItem(TimetableDay day) => {
        'id': day.id,
        'shortLabel': day.shortLabel,
        'fullLabel': day.fullLabel,
        'date': day.date.toIso8601String().split('T').first,
        'isSelected': day.isSelected,
        'isToday': day.isToday,
        'periods': [
          for (final period in day.periods)
            {
              'id': period.id,
              'periodLabel': period.periodLabel,
              'timeRange': period.timeRange,
              'subject': period.subject,
              'teacherName': period.teacherName,
              'roomLabel': period.roomLabel,
              'status': ParentEnumCodec.timetablePeriodStatusToApi(period.status),
              'isRoomChanged': period.isRoomChanged,
            },
        ],
      };

  Map<String, dynamic> feesEnvelope(ParentFeesData data) {
    return envelope({
      'pendingAmount': data.pendingAmount,
      'isOverdue': data.isOverdue,
      'dueLabel': data.dueLabel,
      'paidAmount': data.paidAmount,
      'annualAmount': data.annualAmount,
      'progressPercent': data.progressPercent,
      'unreadNotifications': data.unreadNotifications,
      'installments': [
        for (final item in data.installments)
          {
            'id': item.id,
            'title': item.title,
            'amount': item.amount,
            'status': ParentEnumCodec.feeInstallmentStatusToApi(item.status),
            if (item.meta != null) 'meta': item.meta,
            if (item.dueDateLabel != null) 'dueDateLabel': item.dueDateLabel,
            'hasReceipt': item.hasReceipt,
            'isLast': item.isLast,
          },
      ],
      'breakdown': [
        for (final category in data.breakdown)
          {
            'id': category.id,
            'title': category.title,
            'initiallyExpanded': category.initiallyExpanded,
            'lines': [
              for (final line in category.lines)
                {'label': line.label, 'amount': line.amount},
            ],
          },
      ],
      'paymentHistory': [
        for (final item in data.paymentHistory)
          {
            'id': item.id,
            'title': item.title,
            'dateLabel': item.dateLabel,
            'amount': item.amount,
            'statusLabel': item.statusLabel,
            'isSuccess': item.isSuccess,
          },
      ],
    });
  }

  Map<String, dynamic> receiptItem(FeeReceipt receipt) => {
        'id': receipt.id,
        'receiptNumber': receipt.receiptNumber,
        'title': receipt.title,
        'dateLabel': receipt.dateLabel,
        'amount': receipt.amount,
        'paymentMethod': receipt.paymentMethod,
        'statusLabel': receipt.statusLabel,
        'childName': receipt.childName,
        'childClass': receipt.childClass,
        'category': receipt.category,
        'schoolName': receipt.schoolName,
        'lineItems': [
          for (final line in receipt.lineItems)
            {'label': line.label, 'amount': line.amount},
        ],
      };

  Map<String, dynamic> noticeItem(ParentNotice notice) => {
        'id': notice.id,
        'title': notice.title,
        'dateLabel': notice.dateLabel,
        'summary': notice.summary,
        'category': ParentEnumCodec.noticeCategoryToApi(notice.category),
        'isUrgent': notice.isUrgent,
        'isRead': notice.isRead,
      };

  Map<String, dynamic> eventsEnvelope(ParentEventsData data) {
    return envelope({
      'childName': data.childName,
      'childClass': data.childClass,
      'unreadNotifications': data.unreadNotifications,
      'upcomingEvents': [for (final e in data.upcomingEvents) eventItem(e)],
      'pastEvents': [for (final e in data.pastEvents) eventItem(e)],
    });
  }

  Map<String, dynamic> eventItem(ParentEvent event) => {
        'id': event.id,
        'day': event.day,
        'month': event.month,
        'title': event.title,
        'timeLabel': event.timeLabel,
        'venueLabel': event.venueLabel,
        if (event.subtitle != null) 'subtitle': event.subtitle,
        'isRsvpOpen': event.isRsvpOpen,
        'isPast': event.isPast,
      };

  Map<String, dynamic> leaveItem(LeaveRequest request) => {
        'id': request.id,
        'childName': request.childName,
        'childClass': request.childClass,
        'fromDateLabel': request.fromDateLabel,
        'toDateLabel': request.toDateLabel,
        'reason': request.reason,
        'type': ParentEnumCodec.leaveTypeToApi(request.type),
        'status': ParentEnumCodec.leaveStatusToApi(request.status),
        'submittedLabel': request.submittedLabel,
        'hasAttachment': request.hasAttachment,
        if (request.attachmentName != null) 'attachmentName': request.attachmentName,
        'timeline': [
          for (final step in request.timeline)
            {
              'label': step.label,
              'dateLabel': step.dateLabel,
              'isComplete': step.isComplete,
              if (step.note != null) 'note': step.note,
            },
        ],
      };

  Map<String, dynamic> profileEnvelope(ParentProfileData data) {
    return envelope({
      'parentName': data.parentName,
      'phoneLabel': data.phoneLabel,
      'email': data.email,
      'schoolName': data.schoolName,
      'unreadNotifications': data.unreadNotifications,
      'children': [
        for (final child in data.children)
          {
            'id': child.id,
            'name': child.name,
            'classLabel': child.classLabel,
            'isActive': child.isActive,
          },
      ],
    });
  }

  Map<String, dynamic> paymentSummaryEnvelope(PaymentSummary data) {
    return envelope({
      'installmentId': data.installmentId,
      'installmentTitle': data.installmentTitle,
      'childName': data.childName,
      'childClass': data.childClass,
      'dueLabel': data.dueLabel,
      'baseAmount': data.baseAmount,
      'lateFee': data.lateFee,
      'convenienceFee': data.convenienceFee,
      'unreadNotifications': data.unreadNotifications,
      'breakdown': [
        for (final line in data.breakdown)
          {'label': line.label, 'amount': line.amount},
      ],
    });
  }
}
