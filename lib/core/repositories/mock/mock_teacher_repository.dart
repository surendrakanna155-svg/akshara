import '../../../features/teacher/attendance/attendance_models.dart';
import '../../../features/teacher/dashboard/teacher_dashboard_provider.dart';
import '../../../features/teacher/exams/exam_models.dart';
import '../../../features/teacher/homework/homework_models.dart';
import '../../../features/teacher/leave/leave_models.dart';
import '../../../features/teacher/messages/message_models.dart';
import '../../../features/teacher/timetable/timetable_models.dart';
import '../../../shared/semantic_status.dart';
import '../interfaces/teacher_repository.dart';
import '../repository_query.dart';

class MockTeacherRepository implements TeacherRepository {
  @override
  Future<TeacherDashboardData> getDashboard({required RepositoryQuery query}) async =>
      TeacherDashboardData.mock();

  @override
  Future<List<TeacherAttendanceClass>> getAttendanceClasses({
    required RepositoryQuery query,
  }) async =>
      _mockClasses();

  @override
  Future<Map<String, List<TeacherAttendanceStudent>>>
      getAttendanceStudentsByClass({required RepositoryQuery query}) async =>
      _mockStudentsByClass();

  @override
  Future<List<TeacherHomeworkAssignment>> getHomeworkAssignments({
    required RepositoryQuery query,
  }) async {
    final map = _mockSubmissions();
    return [
      TeacherHomeworkAssignment(
        id: 'hw_8a_1',
        title: 'Exercise 5.2 — Linear equations',
        classLabel: '8-A',
        dueLabel: 'Due 8 Jun 2026',
        submissions: map['hw_8a_1'] ?? const [],
      ),
      TeacherHomeworkAssignment(
        id: 'hw_9b_1',
        title: 'Chapter 4 problem set',
        classLabel: '9-B',
        dueLabel: 'Due 10 Jun 2026',
        submissions: map['hw_9b_1'] ?? const [],
      ),
    ];
  }

  @override
  Future<List<TeacherUpcomingExam>> getUpcomingExams({
    required RepositoryQuery query,
  }) async =>
      const [
        TeacherUpcomingExam(
          id: 'ex_1',
          title: 'Unit Test — Mathematics',
          classLabel: '8-A',
          dateLabel: '12 Jun 2026',
          maxMarks: 50,
        ),
        TeacherUpcomingExam(
          id: 'ex_2',
          title: 'Term 2 Assessment',
          classLabel: '9-B',
          dateLabel: '20 Jun 2026',
          maxMarks: 80,
        ),
      ];

  @override
  Future<List<ExamMarkEntry>> getExamMarks({required RepositoryQuery query}) async =>
      _mockMarks();

  @override
  Future<TeacherTimetableData> getTimetable({required RepositoryQuery query}) async {
    final days = _mockDays();
    return TeacherTimetableData(
      teacherName: 'Priya Sharma',
      weekRangeLabel: '1 Jun - 5 Jun 2026',
      days: days,
      unreadNotifications: 1,
    );
  }

  @override
  Future<List<TeacherLeaveRequest>> getLeaveHistory({
    required RepositoryQuery query,
  }) async =>
      _mockHistory();

  @override
  Future<LeaveBalance> getLeaveBalance({required RepositoryQuery query}) async =>
      const LeaveBalance(
        casualRemaining: 6,
        sickRemaining: 4,
        earnedRemaining: 12,
      );

  @override
  Future<List<MessageThread>> getMessageThreads({required RepositoryQuery query}) async =>
      _mockThreads();
}



List<TeacherAttendanceClass> _mockClasses() {
  return const [
    TeacherAttendanceClass(
      id: 'class-8a-p1',
      label: '8-A',
      subject: 'Mathematics',
      periodLabel: 'Period 1',
      studentCount: 38,
      isPending: true,
    ),
    TeacherAttendanceClass(
      id: 'class-9b-p3',
      label: '9-B',
      subject: 'Mathematics',
      periodLabel: 'Period 3',
      studentCount: 36,
      isPending: false,
    ),
    TeacherAttendanceClass(
      id: 'class-8a-p5',
      label: '8-A',
      subject: 'Mathematics',
      periodLabel: 'Period 5',
      studentCount: 38,
      isPending: true,
    ),
  ];
}




Map<String, List<TeacherAttendanceStudent>> _mockStudentsByClass() {
  const students8a = [
    TeacherAttendanceStudent(id: 's1', name: 'Ravi Kumar', rollNo: '01', mark: StudentAttendanceMark.present),
    TeacherAttendanceStudent(id: 's2', name: 'Ananya Rao', rollNo: '02', mark: StudentAttendanceMark.present),
    TeacherAttendanceStudent(id: 's3', name: 'Karthik Menon', rollNo: '03', mark: StudentAttendanceMark.late),
    TeacherAttendanceStudent(id: 's4', name: 'Priya Nair', rollNo: '04', mark: StudentAttendanceMark.absent),
    TeacherAttendanceStudent(id: 's5', name: 'Arjun Das', rollNo: '05', mark: StudentAttendanceMark.unmarked),
    TeacherAttendanceStudent(id: 's6', name: 'Meera Iyer', rollNo: '06', mark: StudentAttendanceMark.unmarked),
  ];
  return {
    'class-8a-p1': students8a,
    'class-9b-p3': students8a,
    'class-8a-p5': students8a,
  };
}




Map<String, List<HomeworkSubmission>> _mockSubmissions() {
  return {
    'hw_8a_1': const [
      HomeworkSubmission(
        id: 'sub_1',
        studentName: 'Ravi Kumar',
        classLabel: '8-A',
        title: 'Exercise 5.2',
        submittedLabel: 'Submitted 5 Jun · 6:40 PM',
        status: HomeworkReviewStatus.pending,
      ),
      HomeworkSubmission(
        id: 'sub_2',
        studentName: 'Ananya Rao',
        classLabel: '8-A',
        title: 'Exercise 5.2',
        submittedLabel: 'Submitted 5 Jun · 7:10 PM',
        status: HomeworkReviewStatus.pending,
      ),
      HomeworkSubmission(
        id: 'sub_3',
        studentName: 'Karthik Menon',
        classLabel: '8-A',
        title: 'Exercise 5.2',
        submittedLabel: 'Submitted 4 Jun',
        status: HomeworkReviewStatus.reviewed,
        grade: 'A',
        comment: 'Excellent steps shown.',
      ),
    ],
    'hw_9b_1': const [
      HomeworkSubmission(
        id: 'sub_4',
        studentName: 'Dev Patel',
        classLabel: '9-B',
        title: 'Chapter 4 problem set',
        submittedLabel: 'Submitted 5 Jun',
        status: HomeworkReviewStatus.pending,
      ),
    ],
  };
}




List<ExamMarkEntry> _mockMarks() {
  return const [
    ExamMarkEntry(id: 'm1', studentName: 'Ravi Kumar', rollNo: '01', marksObtained: 42, maxMarks: 50),
    ExamMarkEntry(id: 'm2', studentName: 'Ananya Rao', rollNo: '02', marksObtained: 45, maxMarks: 50),
    ExamMarkEntry(id: 'm3', studentName: 'Karthik Menon', rollNo: '03', marksObtained: null, maxMarks: 50),
    ExamMarkEntry(id: 'm4', studentName: 'Priya Nair', rollNo: '04', marksObtained: 38, maxMarks: 50),
  ];
}




List<TeacherTimetableDay> _mockDays() {
  return const [
    TeacherTimetableDay(
      id: 'mon',
      shortLabel: 'Mon',
      fullLabel: 'Monday',
      periods: [
        TeacherTimetablePeriod(
          id: 'mon-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'Mathematics',
          classLabel: '8-A',
          roomLabel: 'Room 204',
          status: ClassScheduleStatus.done,
        ),
      ],
    ),
    TeacherTimetableDay(
      id: 'fri',
      shortLabel: 'Fri',
      fullLabel: 'Friday',
      isToday: true,
      periods: [
        TeacherTimetablePeriod(
          id: 'fri-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'Mathematics',
          classLabel: '8-A',
          roomLabel: 'Room 204',
          status: ClassScheduleStatus.done,
        ),
        TeacherTimetablePeriod(
          id: 'fri-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'Mathematics',
          classLabel: '9-B',
          roomLabel: 'Room 206',
          status: ClassScheduleStatus.now,
        ),
        TeacherTimetablePeriod(
          id: 'fri-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 13:15',
          subject: 'Mathematics',
          classLabel: '8-A',
          roomLabel: 'Room 204',
          status: ClassScheduleStatus.upcoming,
        ),
      ],
    ),
  ];
}



List<TeacherLeaveRequest> _mockHistory() {
  return const [
    TeacherLeaveRequest(
      id: 'tlv_1',
      typeLabel: 'Casual leave',
      fromDateLabel: '18 Jun 2026',
      toDateLabel: '18 Jun 2026',
      reason: 'Personal appointment in the afternoon.',
      status: TeacherLeaveStatus.pending,
      timeline: [
        LeaveTimelineStep(
          label: 'Submitted',
          dateLabel: '5 Jun 2026',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'HOD approval',
          dateLabel: 'Pending',
          isComplete: false,
        ),
        LeaveTimelineStep(
          label: 'HR confirmation',
          dateLabel: 'Pending',
          isComplete: false,
        ),
      ],
    ),
    TeacherLeaveRequest(
      id: 'tlv_2',
      typeLabel: 'Sick leave',
      fromDateLabel: '2 May 2026',
      toDateLabel: '3 May 2026',
      reason: 'Fever and medical rest.',
      status: TeacherLeaveStatus.approved,
      timeline: [
        LeaveTimelineStep(
          label: 'Submitted',
          dateLabel: '1 May 2026',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'HOD approval',
          dateLabel: '1 May 2026',
          isComplete: true,
        ),
        LeaveTimelineStep(
          label: 'HR confirmation',
          dateLabel: '2 May 2026',
          isComplete: true,
        ),
      ],
    ),
  ];
}




List<MessageThread> _mockThreads() {
  return const [
    MessageThread(
      id: 'thread_1',
      parentName: 'Suresh Kumar',
      studentName: 'Ravi Kumar · 8-A',
      preview: 'Could you share the homework solution steps?',
      timeLabel: '10:24 AM',
      unreadCount: 1,
      messages: [
        MessageItem(
          id: 'm1',
          body: 'Could you share the homework solution steps for Q5?',
          senderLabel: 'Suresh Kumar',
          timeLabel: '10:24 AM',
          isTeacher: false,
        ),
        MessageItem(
          id: 'm2',
          body: 'I will upload worked examples by evening.',
          senderLabel: 'Priya Sharma',
          timeLabel: '10:40 AM',
          isTeacher: true,
        ),
      ],
    ),
    MessageThread(
      id: 'thread_2',
      parentName: 'Lakshmi Nair',
      studentName: 'Ananya Rao · 8-A',
      preview: 'Thank you for the PTM slot confirmation.',
      timeLabel: 'Yesterday',
      unreadCount: 0,
      messages: [
        MessageItem(
          id: 'm3',
          body: 'Thank you for the PTM slot confirmation.',
          senderLabel: 'Lakshmi Nair',
          timeLabel: 'Yesterday',
          isTeacher: false,
        ),
      ],
    ),
  ];
}


