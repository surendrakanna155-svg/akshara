import 'package:akshara_erp/core/repositories/api/teacher/dto/teacher_enum_codec.dart';
import 'package:akshara_erp/features/teacher/attendance/attendance_models.dart';
import 'package:akshara_erp/features/teacher/attendance/my_attendance_models.dart';
import 'package:akshara_erp/features/teacher/dashboard/teacher_dashboard_provider.dart';
import 'package:akshara_erp/features/teacher/exams/exam_models.dart';
import 'package:akshara_erp/features/teacher/homework/homework_models.dart';
import 'package:akshara_erp/features/teacher/leave/leave_models.dart';
import 'package:akshara_erp/features/teacher/messages/message_models.dart';
import 'package:akshara_erp/features/teacher/timetable/timetable_models.dart';

/// Builds API-shaped JSON envelopes from Teacher domain models for contract tests.
class TeacherFixtureBuilder {
  const TeacherFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> dashboardEnvelope(TeacherDashboardData data) {
    return envelope({
      'teacherName': data.teacherName,
      'greetingEyebrow': data.greetingEyebrow,
      'greetingHeadline': data.greetingHeadline,
      'periodLabel': data.periodLabel,
      'unreadNotifications': data.unreadNotifications,
      'checkIn': {
        'status': TeacherEnumCodec.staffCheckInStatusToApi(data.checkIn.status),
        if (data.checkIn.checkedInAt != null) 'checkedInAt': data.checkIn.checkedInAt,
        if (data.checkIn.verificationLabel != null)
          'verificationLabel': data.checkIn.verificationLabel,
      },
      'attendanceSummary': {
        if (data.attendanceSummary.pendingBannerMessage != null)
          'pendingBannerMessage': data.attendanceSummary.pendingBannerMessage,
        'pendingBannerActionLabel': data.attendanceSummary.pendingBannerActionLabel,
        if (data.attendanceSummary.pendingClassId != null)
          'pendingClassId': data.attendanceSummary.pendingClassId,
        'classesMarked': data.attendanceSummary.classesMarked,
        'classesTotal': data.attendanceSummary.classesTotal,
        'studentsPresent': data.attendanceSummary.studentsPresent,
        'studentsTotal': data.attendanceSummary.studentsTotal,
      },
      'todaySchedule': [
        for (final item in data.todaySchedule)
          {
            'id': item.id,
            'timeLabel': item.timeLabel,
            'subject': item.subject,
            'classLabel': item.classLabel,
            'room': item.room,
            'status': TeacherEnumCodec.classScheduleStatusToApi(item.status),
          },
      ],
      'pendingTasks': [
        for (final task in data.pendingTasks)
          {
            'id': task.id,
            'icon': task.id,
            'count': task.count,
            'label': task.label,
          },
      ],
      if (data.classTeacher != null)
        'classTeacher': {
          'classLabel': data.classTeacher!.classLabel,
          'title': data.classTeacher!.title,
        },
      'quickActions': [
        for (final action in data.quickActions)
          {
            'id': action.id,
            'label': action.label,
            'icon': action.id,
          },
      ],
      'aiInsight': {
        'message': data.aiInsight.message,
        'actionLabel': data.aiInsight.actionLabel,
      },
    });
  }

  Map<String, dynamic> attendanceClassItem(TeacherAttendanceClass item) => {
        'id': item.id,
        'label': item.label,
        'subject': item.subject,
        'periodLabel': item.periodLabel,
        'studentCount': item.studentCount,
        'isPending': item.isPending,
      };

  Map<String, dynamic> attendanceStudentsEnvelope(
    Map<String, List<TeacherAttendanceStudent>> data,
  ) {
    return envelope({
      'studentsByClass': {
        for (final entry in data.entries)
          entry.key: [
            for (final student in entry.value)
              {
                'id': student.id,
                'name': student.name,
                'rollNo': student.rollNo,
                'mark': TeacherEnumCodec.studentAttendanceMarkToApi(student.mark),
              },
          ],
      },
    });
  }

  Map<String, dynamic> homeworkAssignmentItem(TeacherHomeworkAssignment item) => {
        'id': item.id,
        'title': item.title,
        'classLabel': item.classLabel,
        'dueLabel': item.dueLabel,
        'submissions': [
          for (final sub in item.submissions)
            {
              'id': sub.id,
              'studentName': sub.studentName,
              'classLabel': sub.classLabel,
              'title': sub.title,
              'submittedLabel': sub.submittedLabel,
              'status': TeacherEnumCodec.homeworkReviewStatusToApi(sub.status),
              if (sub.grade != null) 'grade': sub.grade,
              if (sub.comment != null) 'comment': sub.comment,
            },
        ],
      };

  Map<String, dynamic> upcomingExamItem(TeacherUpcomingExam exam) => {
        'id': exam.id,
        'title': exam.title,
        'classLabel': exam.classLabel,
        'dateLabel': exam.dateLabel,
        'maxMarks': exam.maxMarks,
      };

  Map<String, dynamic> examMarkItem(ExamMarkEntry entry) => {
        'id': entry.id,
        'studentName': entry.studentName,
        'rollNo': entry.rollNo,
        'marksObtained': entry.marksObtained,
        'maxMarks': entry.maxMarks,
      };

  Map<String, dynamic> timetableEnvelope(TeacherTimetableData data) {
    return envelope({
      'teacherName': data.teacherName,
      'weekRangeLabel': data.weekRangeLabel,
      'unreadNotifications': data.unreadNotifications,
      'days': [
        for (final day in data.days)
          {
            'id': day.id,
            'shortLabel': day.shortLabel,
            'fullLabel': day.fullLabel,
            'isSelected': day.isSelected,
            'isToday': day.isToday,
            'periods': [
              for (final period in day.periods)
                {
                  'id': period.id,
                  'periodLabel': period.periodLabel,
                  'timeRange': period.timeRange,
                  'subject': period.subject,
                  'classLabel': period.classLabel,
                  'roomLabel': period.roomLabel,
                  'status': TeacherEnumCodec.classScheduleStatusToApi(period.status),
                },
            ],
          },
      ],
    });
  }

  Map<String, dynamic> leaveItem(TeacherLeaveRequest request) => {
        'id': request.id,
        'typeLabel': request.typeLabel,
        'fromDateLabel': request.fromDateLabel,
        'toDateLabel': request.toDateLabel,
        'reason': request.reason,
        'status': TeacherEnumCodec.teacherLeaveStatusToApi(request.status),
        'timeline': [
          for (final step in request.timeline)
            {
              'label': step.label,
              'dateLabel': step.dateLabel,
              'isComplete': step.isComplete,
            },
        ],
      };

  Map<String, dynamic> leaveBalanceEnvelope(LeaveBalance data) {
    return envelope({
      'casualRemaining': data.casualRemaining,
      'sickRemaining': data.sickRemaining,
      'earnedRemaining': data.earnedRemaining,
    });
  }

  // TCH-9 — the self-attendance history payload.
  Map<String, dynamic> myAttendanceDay(MyAttendanceDay day) => {
        'date': day.date,
        'checkIn': day.checkIn,
        'checkOut': day.checkOut,
        'workingMinutes': day.workingMinutes,
        'status': day.status.name,
        'manualOverride': day.manualOverride,
      };

  Map<String, dynamic> myAttendanceEnvelope(MyAttendanceHistory data) {
    return envelope({
      'month': data.month,
      'days': [for (final d in data.days) myAttendanceDay(d)],
      'summary': {
        'presentDays': data.summary.presentDays,
        'lateDays': data.summary.lateDays,
        'absentDays': data.summary.absentDays,
        'workingDaysInMonth': data.summary.workingDaysInMonth,
        'avgWorkingMinutes': data.summary.avgWorkingMinutes,
      },
      'today': data.today == null ? null : myAttendanceDay(data.today!),
      'yesterday':
          data.yesterday == null ? null : myAttendanceDay(data.yesterday!),
    });
  }

  Map<String, dynamic> messageThreadItem(MessageThread thread) => {
        'id': thread.id,
        'parentName': thread.parentName,
        'studentName': thread.studentName,
        'preview': thread.preview,
        'timeLabel': thread.timeLabel,
        'unreadCount': thread.unreadCount,
        'messages': [
          for (final msg in thread.messages)
            {
              'id': msg.id,
              'body': msg.body,
              'senderLabel': msg.senderLabel,
              'timeLabel': msg.timeLabel,
              'isTeacher': msg.isTeacher,
            },
        ],
      };
}
