import '../../../../../features/teacher/attendance/attendance_models.dart';
import '../../../../../features/teacher/dashboard/teacher_dashboard_provider.dart';
import '../../../../../features/teacher/exams/exam_models.dart';
import '../../../../../features/teacher/homework/homework_models.dart';
import '../../../../../features/teacher/leave/leave_models.dart';
import '../../../../../features/teacher/messages/message_models.dart';
import '../../../../../features/teacher/timetable/timetable_models.dart';
import '../dto/teacher_enum_codec.dart';
import '../dto/teacher_responses_dto.dart';

/// Maps Teacher mobile API DTOs to domain models.
class TeacherMapper {
  const TeacherMapper();

  TeacherDashboardData toDashboard(TeacherDashboardDto dto) {
    final raw = dto.raw;
    final classTeacherRaw = raw['classTeacher'] as Map<String, dynamic>?;
    return TeacherDashboardData(
      teacherName: raw['teacherName'] as String? ?? '',
      greetingEyebrow: raw['greetingEyebrow'] as String? ?? '',
      greetingHeadline: raw['greetingHeadline'] as String? ?? '',
      periodLabel: raw['periodLabel'] as String? ?? '',
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
      checkIn: _mapCheckIn(raw['checkIn'] as Map<String, dynamic>? ?? const {}),
      attendanceSummary: _mapAttendanceSummary(
        raw['attendanceSummary'] as Map<String, dynamic>? ?? const {},
      ),
      todaySchedule: _mapScheduleClasses(raw['todaySchedule'] as List<dynamic>? ?? const []),
      pendingTasks: _mapPendingTasks(raw['pendingTasks'] as List<dynamic>? ?? const []),
      classTeacher: classTeacherRaw == null
          ? null
          : ClassTeacherInfo(
              classLabel: classTeacherRaw['classLabel'] as String? ?? '',
              title: classTeacherRaw['title'] as String? ?? '',
            ),
      quickActions: _mapQuickActions(raw['quickActions'] as List<dynamic>? ?? const []),
      aiInsight: _mapAiInsight(raw['aiInsight'] as Map<String, dynamic>? ?? const {}),
    );
  }

  List<TeacherAttendanceClass> toAttendanceClasses(
    TeacherAttendanceClassesResponseDto dto,
  ) {
    return [for (final item in dto.items) toAttendanceClass(item)];
  }

  TeacherAttendanceClass toAttendanceClass(TeacherAttendanceClassDto dto) {
    final raw = dto.raw;
    return TeacherAttendanceClass(
      id: raw['id'] as String? ?? '',
      label: raw['label'] as String? ?? '',
      subject: raw['subject'] as String? ?? '',
      periodLabel: raw['periodLabel'] as String? ?? '',
      studentCount: raw['studentCount'] as int? ?? 0,
      isPending: raw['isPending'] as bool? ?? false,
    );
  }

  Map<String, List<TeacherAttendanceStudent>> toAttendanceStudentsByClass(
    TeacherAttendanceStudentsResponseDto dto,
  ) {
    final raw = dto.raw['studentsByClass'] as Map<String, dynamic>? ?? const {};
    return {
      for (final entry in raw.entries)
        entry.key: _mapAttendanceStudents(entry.value as List<dynamic>? ?? const []),
    };
  }

  List<TeacherHomeworkAssignment> toHomeworkAssignments(
    TeacherHomeworkResponseDto dto,
  ) {
    return [for (final item in dto.items) toHomeworkAssignment(item)];
  }

  TeacherHomeworkAssignment toHomeworkAssignment(TeacherHomeworkAssignmentDto dto) {
    final raw = dto.raw;
    return TeacherHomeworkAssignment(
      id: raw['id'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      dueLabel: raw['dueLabel'] as String? ?? '',
      submissions: _mapSubmissions(raw['submissions'] as List<dynamic>? ?? const []),
    );
  }

  List<TeacherUpcomingExam> toUpcomingExams(TeacherUpcomingExamsResponseDto dto) {
    return [for (final item in dto.items) toUpcomingExam(item)];
  }

  TeacherUpcomingExam toUpcomingExam(TeacherUpcomingExamDto dto) {
    final raw = dto.raw;
    return TeacherUpcomingExam(
      id: raw['id'] as String? ?? '',
      title: raw['title'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      dateLabel: raw['dateLabel'] as String? ?? '',
      maxMarks: raw['maxMarks'] as int? ?? 0,
    );
  }

  List<ExamMarkEntry> toExamMarks(TeacherExamMarksResponseDto dto) {
    return [for (final item in dto.items) toExamMark(item)];
  }

  ExamMarkEntry toExamMark(ExamMarkEntryDto dto) {
    final raw = dto.raw;
    return ExamMarkEntry(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      rollNo: raw['rollNo'] as String? ?? '',
      marksObtained: raw['marksObtained'] as int?,
      maxMarks: raw['maxMarks'] as int? ?? 0,
    );
  }

  TeacherTimetableData toTimetable(TeacherTimetableResponseDto dto) {
    final raw = dto.raw;
    return TeacherTimetableData(
      teacherName: raw['teacherName'] as String? ?? '',
      weekRangeLabel: raw['weekRangeLabel'] as String? ?? '',
      days: _mapTimetableDays(raw['days'] as List<dynamic>? ?? const []),
      unreadNotifications: raw['unreadNotifications'] as int? ?? 0,
    );
  }

  List<TeacherLeaveRequest> toLeaveHistory(TeacherLeaveResponseDto dto) {
    return [for (final item in dto.items) toLeaveRequest(item)];
  }

  TeacherLeaveRequest toLeaveRequest(TeacherLeaveRequestDto dto) {
    final raw = dto.raw;
    return TeacherLeaveRequest(
      id: raw['id'] as String? ?? '',
      typeLabel: raw['typeLabel'] as String? ?? '',
      fromDateLabel: raw['fromDateLabel'] as String? ?? '',
      toDateLabel: raw['toDateLabel'] as String? ?? '',
      reason: raw['reason'] as String? ?? '',
      status: TeacherEnumCodec.parseTeacherLeaveStatus(raw['status'] as String?),
      timeline: _mapLeaveTimeline(raw['timeline'] as List<dynamic>? ?? const []),
    );
  }

  LeaveBalance toLeaveBalance(TeacherLeaveBalanceResponseDto dto) {
    final raw = dto.raw;
    return LeaveBalance(
      casualRemaining: raw['casualRemaining'] as int? ?? 0,
      sickRemaining: raw['sickRemaining'] as int? ?? 0,
      earnedRemaining: raw['earnedRemaining'] as int? ?? 0,
    );
  }

  List<MessageThread> toMessageThreads(TeacherMessagesResponseDto dto) {
    return [for (final item in dto.items) toMessageThread(item)];
  }

  MessageThread toMessageThread(MessageThreadDto dto) {
    final raw = dto.raw;
    return MessageThread(
      id: raw['id'] as String? ?? '',
      parentName: raw['parentName'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      preview: raw['preview'] as String? ?? '',
      timeLabel: raw['timeLabel'] as String? ?? '',
      unreadCount: raw['unreadCount'] as int? ?? 0,
      messages: _mapMessages(raw['messages'] as List<dynamic>? ?? const []),
    );
  }

  StaffCheckInInfo _mapCheckIn(Map<String, dynamic> raw) {
    return StaffCheckInInfo(
      status: TeacherEnumCodec.parseStaffCheckInStatus(raw['status'] as String?),
      checkedInAt: raw['checkedInAt'] as String?,
      verificationLabel: raw['verificationLabel'] as String?,
    );
  }

  AttendanceSummary _mapAttendanceSummary(Map<String, dynamic> raw) {
    return AttendanceSummary(
      pendingBannerMessage: raw['pendingBannerMessage'] as String?,
      pendingBannerActionLabel: raw['pendingBannerActionLabel'] as String? ?? '',
      pendingClassId: raw['pendingClassId'] as String?,
      classesMarked: raw['classesMarked'] as int? ?? 0,
      classesTotal: raw['classesTotal'] as int? ?? 0,
      studentsPresent: raw['studentsPresent'] as int? ?? 0,
      studentsTotal: raw['studentsTotal'] as int? ?? 0,
    );
  }

  List<ScheduleClass> _mapScheduleClasses(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ScheduleClass(
            id: item['id'] as String? ?? '',
            timeLabel: item['timeLabel'] as String? ?? '',
            subject: item['subject'] as String? ?? '',
            classLabel: item['classLabel'] as String? ?? '',
            room: item['room'] as String? ?? '',
            status: TeacherEnumCodec.parseClassScheduleStatus(item['status'] as String?),
          ),
    ];
  }

  List<PendingTask> _mapPendingTasks(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          PendingTask(
            id: item['id'] as String? ?? '',
            icon: TeacherEnumCodec.iconForPendingTask(
              item['icon'] as String?,
              item['id'] as String?,
            ),
            count: item['count'] as int? ?? 0,
            label: item['label'] as String? ?? '',
          ),
    ];
  }

  List<TeacherQuickAction> _mapQuickActions(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TeacherQuickAction(
            id: item['id'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: TeacherEnumCodec.iconForQuickAction(
              item['icon'] as String?,
              item['id'] as String?,
            ),
          ),
    ];
  }

  TeacherAiInsight _mapAiInsight(Map<String, dynamic> raw) {
    return TeacherAiInsight(
      message: raw['message'] as String? ?? '',
      actionLabel: raw['actionLabel'] as String? ?? '',
    );
  }

  List<TeacherAttendanceStudent> _mapAttendanceStudents(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TeacherAttendanceStudent(
            id: item['id'] as String? ?? '',
            name: item['name'] as String? ?? '',
            rollNo: item['rollNo'] as String? ?? '',
            mark: TeacherEnumCodec.parseStudentAttendanceMark(item['mark'] as String?),
          ),
    ];
  }

  List<HomeworkSubmission> _mapSubmissions(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          HomeworkSubmission(
            id: item['id'] as String? ?? '',
            studentName: item['studentName'] as String? ?? '',
            classLabel: item['classLabel'] as String? ?? '',
            title: item['title'] as String? ?? '',
            submittedLabel: item['submittedLabel'] as String? ?? '',
            status: TeacherEnumCodec.parseHomeworkReviewStatus(item['status'] as String?),
            grade: item['grade'] as String?,
            comment: item['comment'] as String?,
          ),
    ];
  }

  List<TeacherTimetableDay> _mapTimetableDays(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TeacherTimetableDay(
            id: item['id'] as String? ?? '',
            shortLabel: item['shortLabel'] as String? ?? '',
            fullLabel: item['fullLabel'] as String? ?? '',
            periods: _mapTimetablePeriods(item['periods'] as List<dynamic>? ?? const []),
            isSelected: item['isSelected'] as bool? ?? false,
            isToday: item['isToday'] as bool? ?? false,
          ),
    ];
  }

  List<TeacherTimetablePeriod> _mapTimetablePeriods(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          TeacherTimetablePeriod(
            id: item['id'] as String? ?? '',
            periodLabel: item['periodLabel'] as String? ?? '',
            timeRange: item['timeRange'] as String? ?? '',
            subject: item['subject'] as String? ?? '',
            classLabel: item['classLabel'] as String? ?? '',
            roomLabel: item['roomLabel'] as String? ?? '',
            status: TeacherEnumCodec.parseClassScheduleStatus(item['status'] as String?),
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
          ),
    ];
  }

  List<MessageItem> _mapMessages(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          MessageItem(
            id: item['id'] as String? ?? '',
            body: item['body'] as String? ?? '',
            senderLabel: item['senderLabel'] as String? ?? '',
            timeLabel: item['timeLabel'] as String? ?? '',
            isTeacher: item['isTeacher'] as bool? ?? false,
          ),
    ];
  }
}
