import '../../../../../features/parent/attendance/attendance_models.dart';
import '../../../../../features/parent/timetable/timetable_models.dart';
import '../../../../../features/student_app/dashboard/student_dashboard_provider.dart';
import '../../../../../features/student_app/exams/exam_models.dart';
import '../../../../../features/student_app/homework/homework_models.dart';
import '../../../../../features/student_app/notices/notices_models.dart';
import '../../../../../features/student_app/profile/profile_models.dart';
import '../dto/student_enum_codec.dart';
import '../dto/student_homework_submit_request_dto.dart';
import '../dto/student_responses_dto.dart';

/// Maps Student mobile API DTOs to domain models.
class StudentMapper {
  const StudentMapper();

  StudentDashboardData toDashboard(StudentDashboardDto dto) {
    final raw = dto.raw;
    return StudentDashboardData(
      studentName: raw['studentName'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      greetingHeadline: raw['greetingHeadline'] as String? ?? '',
      greetingSubtitle: raw['greetingSubtitle'] as String? ?? '',
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
      todaySchedule: _mapSchedulePeriods(raw['todaySchedule'] as List<dynamic>? ?? const []),
      attendanceKpi: _mapAttendanceKpi(raw['attendanceKpi'] as Map<String, dynamic>? ?? const {}),
      homeworkDue: _mapHomeworkDue(raw['homeworkDue'] as List<dynamic>? ?? const []),
      examReminder: _mapExamReminder(raw['examReminder'] as Map<String, dynamic>? ?? const {}),
      quickActions: _mapQuickActions(raw['quickActions'] as List<dynamic>? ?? const []),
      aiInsight: _mapAiInsight(raw['aiInsight'] as Map<String, dynamic>? ?? const {}),
    );
  }

  AttendanceMonthData toAttendance(StudentAttendanceResponseDto dto) {
    final raw = dto.raw;
    final monthRaw = raw['month'] as String? ?? '';
    final monthParts = monthRaw.split('-');
    final month = monthParts.length >= 2
        ? DateTime(int.parse(monthParts[0]), int.parse(monthParts[1]), 1)
        : DateTime.now();

    return AttendanceMonthData(
      month: month,
      childName: raw['childName'] as String? ?? raw['studentName'] as String? ?? '',
      childClass: raw['childClass'] as String? ?? raw['classLabel'] as String? ?? '',
      kpi: _mapAttendanceKpiMetrics(raw['kpi'] as Map<String, dynamic>? ?? const {}),
      calendarDays: _mapCalendarDays(raw['calendarDays'] as List<dynamic>? ?? const []),
      recentLogs: _mapRecentLogs(raw['recentLogs'] as List<dynamic>? ?? const []),
      warningBannerMessage: raw['warningBannerMessage'] as String?,
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
    );
  }

  List<StudentHomeworkItem> toHomeworkItems(StudentHomeworkResponseDto dto) {
    return [for (final item in dto.items) toHomeworkItem(item)];
  }

  StudentHomeworkItem toHomeworkItem(StudentHomeworkItemDto dto) {
    final raw = dto.raw;
    return StudentHomeworkItem(
      id: raw['id'] as String? ?? '',
      subject: raw['subject'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      dueLabel: raw['dueLabel'] as String? ?? '',
      status: StudentEnumCodec.parseHomeworkStatus(raw['status'] as String?),
      attachmentLabel: raw['attachmentLabel'] as String?,
      submittedLabel: raw['submittedLabel'] as String?,
      reviewGrade: raw['reviewGrade'] as String?,
      reviewComment: raw['reviewComment'] as String?,
    );
  }

  StudentHomeworkItem toHomeworkSubmitResult(StudentHomeworkSubmitResponseDto dto) {
    return toHomeworkItem(StudentHomeworkItemDto(raw: dto.raw));
  }

  StudentExamsData toExams(StudentExamsResponseDto dto) {
    final raw = dto.raw;
    return StudentExamsData(
      studentName: raw['studentName'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
      averagePercent: raw['averagePercent'] as int? ?? 0,
      upcomingExams: _mapUpcomingExams(raw['upcomingExams'] as List<dynamic>? ?? const []),
      examResults: _mapExamResults(raw['examResults'] as List<dynamic>? ?? const []),
      subjectScores: _mapSubjectScores(raw['subjectScores'] as List<dynamic>? ?? const []),
    );
  }

  ParentTimetableData toTimetable(StudentTimetableResponseDto dto) {
    final raw = dto.raw;
    return ParentTimetableData(
      childName: raw['childName'] as String? ?? raw['studentName'] as String? ?? '',
      childClass: raw['childClass'] as String? ?? raw['classLabel'] as String? ?? '',
      weekRangeLabel: raw['weekRangeLabel'] as String? ?? '',
      days: _mapTimetableDays(raw['days'] as List<dynamic>? ?? const []),
      totalPeriodsThisWeek: raw['totalPeriodsThisWeek'] as int? ?? 0,
      completedPeriodsToday: raw['completedPeriodsToday'] as int? ?? 0,
      upcomingPeriodsToday: raw['upcomingPeriodsToday'] as int? ?? 0,
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
      scheduleChangeMessage: raw['scheduleChangeMessage'] as String?,
    );
  }

  List<StudentNotice> toNotices(StudentNoticesResponseDto dto) {
    return [for (final item in dto.items) toNotice(item)];
  }

  StudentNotice toNotice(StudentNoticeDto dto) {
    final raw = dto.raw;
    return StudentNotice(
      id: raw['id'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      dateLabel: raw['dateLabel'] as String? ?? '',
      summary: raw['summary'] as String? ?? '',
      scope: StudentEnumCodec.parseNoticeScope(raw['scope'] as String?),
      priority: StudentEnumCodec.parseNoticePriority(raw['priority'] as String?),
      isRead: raw['isRead'] as bool? ?? false,
    );
  }

  StudentProfileData toProfile(StudentProfileResponseDto dto) {
    final raw = dto.raw;
    return StudentProfileData(
      studentName: raw['studentName'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      rollNo: raw['rollNo'] as String? ?? '',
      admissionNo: raw['admissionNo'] as String? ?? '',
      dateOfBirth: raw['dateOfBirth'] as String? ?? '',
      bloodGroup: raw['bloodGroup'] as String? ?? '',
      schoolName: raw['schoolName'] as String? ?? '',
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
      parentContacts: _mapParentContacts(raw['parentContacts'] as List<dynamic>? ?? const []),
      academicSummary: _mapAcademicSummary(raw['academicSummary'] as List<dynamic>? ?? const []),
    );
  }

  List<SchedulePeriod> _mapSchedulePeriods(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          SchedulePeriod(
            id: item['id'] as String? ?? '',
            timeLabel: item['timeLabel'] as String? ?? '',
            subject: item['subject'] as String? ?? '',
            teacherName: item['teacherName'] as String? ?? '',
            state: StudentEnumCodec.parsePeriodState(item['state'] as String?),
          ),
    ];
  }

  AttendanceKpi _mapAttendanceKpi(Map<String, dynamic> raw) {
    return AttendanceKpi(
      label: raw['label'] as String? ?? '',
      value: raw['value'] as String? ?? '',
      detail: raw['detail'] as String? ?? '',
      tone: StudentEnumCodec.parseStudentKpiTone(raw['tone'] as String?),
    );
  }

  List<HomeworkDueItem> _mapHomeworkDue(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HomeworkDueItem(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            subject: item['subject'] as String? ?? '',
            dueLabel: item['dueLabel'] as String? ?? '',
            status: StudentEnumCodec.parseHomeworkDueStatus(item['status'] as String?),
            icon: StudentEnumCodec.iconForHomeworkDue(
              item['icon'] as String?,
              item['subject'] as String?,
            ),
          ),
    ];
  }

  ExamReminder _mapExamReminder(Map<String, dynamic> raw) {
    return ExamReminder(
      id: raw['id'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      subject: raw['subject'] as String? ?? '',
      dateLabel: raw['dateLabel'] as String? ?? '',
      daysUntil: raw['daysUntil'] as int? ?? 0,
    );
  }

  List<StudentQuickAction> _mapQuickActions(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          StudentQuickAction(
            id: item['id'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: StudentEnumCodec.iconForQuickAction(
              item['icon'] as String?,
              item['id'] as String?,
            ),
            emphasis: StudentEnumCodec.parseStudentKpiTone(item['emphasis'] as String?),
            isVisible: item['isVisible'] as bool? ?? true,
          ),
    ];
  }

  StudentAiInsight _mapAiInsight(Map<String, dynamic> raw) {
    return StudentAiInsight(
      message: raw['message'] as String? ?? '',
      actionLabel: raw['actionLabel'] as String? ?? '',
    );
  }

  AttendanceKpiMetrics _mapAttendanceKpiMetrics(Map<String, dynamic> raw) {
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
            status: StudentEnumCodec.parseAttendanceDayStatus(item['status'] as String?),
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
            status: StudentEnumCodec.parseAttendanceDayStatus(item['status'] as String?),
            detail: item['detail'] as String? ?? '',
            detailTitle: item['detailTitle'] as String? ?? '',
            detailBody: item['detailBody'] as String? ?? '',
            detailNote: item['detailNote'] as String?,
          ),
    ];
  }

  List<StudentUpcomingExam> _mapUpcomingExams(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          StudentUpcomingExam(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            subject: item['subject'] as String? ?? '',
            dateLabel: item['dateLabel'] as String? ?? '',
            timeLabel: item['timeLabel'] as String? ?? '',
            venueLabel: item['venueLabel'] as String? ?? '',
          ),
    ];
  }

  List<StudentExamResult> _mapExamResults(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          StudentExamResult(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            termLabel: item['termLabel'] as String? ?? '',
            dateLabel: item['dateLabel'] as String? ?? '',
            scoreObtained: item['scoreObtained'] as int? ?? 0,
            maxScore: item['maxScore'] as int? ?? 0,
            grade: item['grade'] as String? ?? '',
          ),
    ];
  }

  List<SubjectScore> _mapSubjectScores(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          SubjectScore(
            subject: item['subject'] as String? ?? '',
            scorePercent: item['scorePercent'] as int? ?? 0,
            grade: item['grade'] as String? ?? '',
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
            status: StudentEnumCodec.parseTimetablePeriodStatus(item['status'] as String?),
            isRoomChanged: item['isRoomChanged'] as bool? ?? false,
          ),
    ];
  }

  List<ParentContact> _mapParentContacts(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ParentContact(
            name: item['name'] as String? ?? '',
            relation: item['relation'] as String? ?? '',
            phoneLabel: item['phoneLabel'] as String? ?? '',
            email: item['email'] as String? ?? '',
          ),
    ];
  }

  List<AcademicSummaryItem> _mapAcademicSummary(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AcademicSummaryItem(
            label: item['label'] as String? ?? '',
            value: item['value'] as String? ?? '',
          ),
    ];
  }
}
