import 'package:akshara_erp/core/repositories/api/student/dto/student_enum_codec.dart';
import 'package:akshara_erp/features/parent/attendance/attendance_models.dart';
import 'package:akshara_erp/features/parent/timetable/timetable_models.dart';
import 'package:akshara_erp/features/student_app/dashboard/student_dashboard_provider.dart';
import 'package:akshara_erp/features/student_app/exams/exam_models.dart';
import 'package:akshara_erp/features/student_app/homework/homework_models.dart';
import 'package:akshara_erp/features/student_app/notices/notices_models.dart';
import 'package:akshara_erp/features/student_app/profile/profile_models.dart';

/// Builds API-shaped JSON envelopes from Student domain models for contract tests.
class StudentFixtureBuilder {
  const StudentFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> dashboardEnvelope(StudentDashboardData data) {
    return envelope({
      'studentName': data.studentName,
      'classLabel': data.classLabel,
      'greetingHeadline': data.greetingHeadline,
      'greetingSubtitle': data.greetingSubtitle,
      'unreadNotifications': data.unreadNotifications,
      'todaySchedule': [
        for (final period in data.todaySchedule)
          {
            'id': period.id,
            'timeLabel': period.timeLabel,
            'subject': period.subject,
            'teacherName': period.teacherName,
            'state': StudentEnumCodec.periodStateToApi(period.state),
          },
      ],
      'attendanceKpi': {
        'label': data.attendanceKpi.label,
        'value': data.attendanceKpi.value,
        'detail': data.attendanceKpi.detail,
        'tone': StudentEnumCodec.studentKpiToneToApi(data.attendanceKpi.tone),
      },
      'homeworkDue': [
        for (final item in data.homeworkDue)
          {
            'id': item.id,
            'title': item.title,
            'subject': item.subject,
            'dueLabel': item.dueLabel,
            'status': StudentEnumCodec.homeworkDueStatusToApi(item.status),
            'icon': item.subject.toLowerCase(),
          },
      ],
      'examReminder': {
        'id': data.examReminder.id,
        'title': data.examReminder.title,
        'subject': data.examReminder.subject,
        'dateLabel': data.examReminder.dateLabel,
        'daysUntil': data.examReminder.daysUntil,
      },
      'quickActions': [
        for (final action in data.quickActions)
          {
            'id': action.id,
            'label': action.label,
            'icon': action.id,
            'emphasis': StudentEnumCodec.studentKpiToneToApi(action.emphasis),
            'isVisible': action.isVisible,
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
      'studentName': data.childName,
      'classLabel': data.childClass,
      'kpi': {
        'attendancePercent': data.kpi.attendancePercent,
        'absentDays': data.kpi.absentDays,
        'lateDays': data.kpi.lateDays,
      },
      'calendarDays': [
        for (final day in data.calendarDays)
          {
            if (day.date != null) 'date': day.date!.toIso8601String().split('T').first,
            'status': StudentEnumCodec.attendanceDayStatusToApi(day.status),
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
            'status': StudentEnumCodec.attendanceDayStatusToApi(log.status),
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

  Map<String, dynamic> homeworkItem(StudentHomeworkItem item) => {
        'id': item.id,
        'subject': item.subject,
        'title': item.title,
        'dueLabel': item.dueLabel,
        'status': StudentEnumCodec.homeworkStatusToApi(item.status),
        if (item.attachmentLabel != null) 'attachmentLabel': item.attachmentLabel,
        if (item.submittedLabel != null) 'submittedLabel': item.submittedLabel,
      };

  Map<String, dynamic> examsEnvelope(StudentExamsData data) {
    return envelope({
      'studentName': data.studentName,
      'classLabel': data.classLabel,
      'unreadNotifications': data.unreadNotifications,
      'averagePercent': data.averagePercent,
      'upcomingExams': [
        for (final exam in data.upcomingExams)
          {
            'id': exam.id,
            'title': exam.title,
            'subject': exam.subject,
            'dateLabel': exam.dateLabel,
            'timeLabel': exam.timeLabel,
            'venueLabel': exam.venueLabel,
          },
      ],
      'examResults': [
        for (final result in data.examResults)
          {
            'id': result.id,
            'title': result.title,
            'termLabel': result.termLabel,
            'dateLabel': result.dateLabel,
            'scoreObtained': result.scoreObtained,
            'maxScore': result.maxScore,
            'grade': result.grade,
          },
      ],
      'subjectScores': [
        for (final score in data.subjectScores)
          {
            'subject': score.subject,
            'scorePercent': score.scorePercent,
            'grade': score.grade,
          },
      ],
    });
  }

  Map<String, dynamic> timetableEnvelope(ParentTimetableData data) {
    return envelope({
      'studentName': data.childName,
      'classLabel': data.childClass,
      'weekRangeLabel': data.weekRangeLabel,
      'totalPeriodsThisWeek': data.totalPeriodsThisWeek,
      'completedPeriodsToday': data.completedPeriodsToday,
      'upcomingPeriodsToday': data.upcomingPeriodsToday,
      'unreadNotifications': data.unreadNotifications,
      if (data.scheduleChangeMessage != null)
        'scheduleChangeMessage': data.scheduleChangeMessage,
      'days': [
        for (final day in data.days)
          {
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
                  'status': StudentEnumCodec.timetablePeriodStatusToApi(period.status),
                  'isRoomChanged': period.isRoomChanged,
                },
            ],
          },
      ],
    });
  }

  Map<String, dynamic> noticeItem(StudentNotice notice) => {
        'id': notice.id,
        'title': notice.title,
        'dateLabel': notice.dateLabel,
        'summary': notice.summary,
        'scope': StudentEnumCodec.noticeScopeToApi(notice.scope),
        'priority': StudentEnumCodec.noticePriorityToApi(notice.priority),
        'isRead': notice.isRead,
      };

  Map<String, dynamic> profileEnvelope(StudentProfileData data) {
    return envelope({
      'studentName': data.studentName,
      'classLabel': data.classLabel,
      'rollNo': data.rollNo,
      'admissionNo': data.admissionNo,
      'dateOfBirth': data.dateOfBirth,
      'bloodGroup': data.bloodGroup,
      'schoolName': data.schoolName,
      'unreadNotifications': data.unreadNotifications,
      'parentContacts': [
        for (final contact in data.parentContacts)
          {
            'name': contact.name,
            'relation': contact.relation,
            'phoneLabel': contact.phoneLabel,
            'email': contact.email,
          },
      ],
      'academicSummary': [
        for (final item in data.academicSummary)
          {'label': item.label, 'value': item.value},
      ],
    });
  }
}
