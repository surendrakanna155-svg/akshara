import '../../../features/parent/attendance/attendance_models.dart';
import '../../../features/parent/timetable/timetable_models.dart';
import '../../../features/student/dashboard/student_dashboard_provider.dart';
import '../../../features/student/exams/exam_models.dart';
import '../../../features/student/homework/homework_models.dart';
import '../../../features/student/notices/notices_models.dart';
import '../../../features/student/profile/profile_models.dart';
import '../interfaces/student_repository.dart';
import '../repository_query.dart';

class MockStudentRepository implements StudentRepository {
  @override
  Future<StudentDashboardData> getDashboard({required RepositoryQuery query}) async =>
      StudentDashboardData.mock();

  @override
  Future<AttendanceMonthData> getAttendance({
    required RepositoryQuery query,
    required DateTime month,
  }) async =>
      AttendanceMonthData.mock(month: month);

  @override
  Future<List<StudentHomeworkItem>> getHomeworkItems({
    required RepositoryQuery query,
  }) async =>
      _mockItems();

  @override
  Future<StudentExamsData> getExams({required RepositoryQuery query}) async =>
      const StudentExamsData(
        studentName: 'Ravi Kumar',
        classLabel: '8-A',
        unreadNotifications: 2,
        averagePercent: 84,
        upcomingExams: [
          StudentUpcomingExam(
            id: 'ex-1',
            title: 'Mid-term Mathematics',
            subject: 'Mathematics',
            dateLabel: '12 Jun 2026',
            timeLabel: '9:00 AM',
            venueLabel: 'Room 203',
          ),
          StudentUpcomingExam(
            id: 'ex-2',
            title: 'Science practical assessment',
            subject: 'Science',
            dateLabel: '18 Jun 2026',
            timeLabel: '10:30 AM',
            venueLabel: 'Lab 2',
          ),
        ],
        examResults: [
          StudentExamResult(
            id: 'res-1',
            title: 'Unit Test — Algebra',
            termLabel: 'Term 2',
            dateLabel: '20 May 2026',
            scoreObtained: 42,
            maxScore: 50,
            grade: 'A',
          ),
          StudentExamResult(
            id: 'res-2',
            title: 'English comprehension',
            termLabel: 'Term 2',
            dateLabel: '8 May 2026',
            scoreObtained: 38,
            maxScore: 50,
            grade: 'B+',
          ),
        ],
        subjectScores: [
          SubjectScore(subject: 'Mathematics', scorePercent: 88, grade: 'A'),
          SubjectScore(subject: 'Science', scorePercent: 82, grade: 'A'),
          SubjectScore(subject: 'English', scorePercent: 76, grade: 'B+'),
          SubjectScore(subject: 'Hindi', scorePercent: 90, grade: 'A+'),
        ],
      );

  @override
  Future<ParentTimetableData> getTimetable({required RepositoryQuery query}) async =>
      _mockWeekData();

  @override
  Future<List<StudentNotice>> getNotices({required RepositoryQuery query}) async =>
      _mockNotices();

  @override
  Future<StudentProfileData> getProfile({required RepositoryQuery query}) async =>
      const StudentProfileData(
        studentName: 'Ravi Kumar',
        classLabel: '8-A',
        rollNo: '08',
        admissionNo: 'AKS-2024-0842',
        dateOfBirth: '14 Mar 2012',
        bloodGroup: 'B+',
        schoolName: 'Akshara International School',
        unreadNotifications: 2,
        parentContacts: [
          ParentContact(
            name: 'Suresh Kumar',
            relation: 'Father',
            phoneLabel: '+91 98765 43210',
            email: 'suresh.kumar@email.com',
          ),
          ParentContact(
            name: 'Lakshmi Kumar',
            relation: 'Mother',
            phoneLabel: '+91 98765 43211',
            email: 'lakshmi.kumar@email.com',
          ),
        ],
        academicSummary: [
          AcademicSummaryItem(label: 'Current term', value: 'Term 2 · 2025-26'),
          AcademicSummaryItem(label: 'Class teacher', value: 'Mrs. Sharma'),
          AcademicSummaryItem(label: 'Attendance', value: '92% this month'),
          AcademicSummaryItem(label: 'Overall grade', value: 'A'),
        ],
      );
}



ParentTimetableData _mockWeekData() {
  final days = <TimetableDay>[
    TimetableDay(
      id: 'fri',
      shortLabel: 'Fri',
      fullLabel: 'Friday',
      date: DateTime(2026, 6, 5),
      isToday: true,
      periods: const [
        TimetablePeriod(
          id: 'fri-p1',
          periodLabel: 'Period 1',
          timeRange: '08:30 - 09:15',
          subject: 'Mathematics',
          teacherName: 'Mrs. Sharma',
          roomLabel: 'Room 203',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'fri-p2',
          periodLabel: 'Period 2',
          timeRange: '09:20 - 10:05',
          subject: 'Science',
          teacherName: 'Mrs. Rao',
          roomLabel: 'Lab 2',
          status: TimetablePeriodStatus.done,
        ),
        TimetablePeriod(
          id: 'fri-p3',
          periodLabel: 'Period 3',
          timeRange: '10:15 - 11:00',
          subject: 'English',
          teacherName: 'Mr. Patel',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.now,
        ),
        TimetablePeriod(
          id: 'fri-p4',
          periodLabel: 'Period 4',
          timeRange: '11:05 - 11:50',
          subject: 'Physical Education',
          teacherName: 'Coach Singh',
          roomLabel: 'Ground',
          status: TimetablePeriodStatus.upcoming,
        ),
        TimetablePeriod(
          id: 'fri-p5',
          periodLabel: 'Period 5',
          timeRange: '12:30 - 13:15',
          subject: 'Hindi',
          teacherName: 'Meena Ma\'am',
          roomLabel: 'Room 201',
          status: TimetablePeriodStatus.upcoming,
        ),
      ],
    ),
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
          teacherName: 'Mr. Patel',
          roomLabel: 'Room 204',
          status: TimetablePeriodStatus.done,
        ),
      ],
    ),
  ];

  return ParentTimetableData(
    childName: 'Ravi Kumar',
    childClass: '8-A',
    weekRangeLabel: '1 Jun - 5 Jun 2026',
    days: days,
    totalPeriodsThisWeek: 6,
    completedPeriodsToday: 2,
    upcomingPeriodsToday: 2,
    unreadNotifications: 2,
    scheduleChangeMessage: 'Period 4 PE moved to the main ground today.',
  );
}




List<StudentHomeworkItem> _mockItems() {
  return const [
    StudentHomeworkItem(
      id: 'hw-1',
      subject: 'Mathematics',
      title: 'Algebra worksheet — Exercise 5.2',
      dueLabel: 'Due tomorrow · 8 Jun',
      status: StudentHomeworkStatus.pending,
      attachmentLabel: 'worksheet_5_2.pdf',
    ),
    StudentHomeworkItem(
      id: 'hw-2',
      subject: 'Science',
      title: 'Photosynthesis lab report',
      dueLabel: 'Due today · Overdue',
      status: StudentHomeworkStatus.overdue,
      attachmentLabel: 'lab_template.docx',
    ),
    StudentHomeworkItem(
      id: 'hw-3',
      subject: 'English',
      title: 'Essay — My favourite book',
      dueLabel: 'Submitted 4 Jun',
      status: StudentHomeworkStatus.submitted,
      submittedLabel: 'Submitted 4 Jun · 7:20 PM',
      attachmentLabel: 'essay_draft.pdf',
    ),
    StudentHomeworkItem(
      id: 'hw-4',
      subject: 'Hindi',
      title: 'Poem memorisation recording',
      dueLabel: 'Submitted 2 Jun',
      status: StudentHomeworkStatus.submitted,
      submittedLabel: 'Submitted 2 Jun · 6:10 PM',
    ),
  ];
}



List<StudentNotice> _mockNotices() {
  return const [
    StudentNotice(
      id: 'sn-1',
      title: 'School closed on 15 June for staff training',
      dateLabel: '5 Jun 2026',
      summary: 'Regular classes resume on 16 June. Online resources will be shared.',
      scope: StudentNoticeScope.school,
      priority: StudentNoticePriority.urgent,
    ),
    StudentNotice(
      id: 'sn-2',
      title: 'Class 8-A science fair project deadline',
      dateLabel: '4 Jun 2026',
      summary: 'Submit your project outline to Mrs. Rao by 10 June.',
      scope: StudentNoticeScope.classNotice,
      priority: StudentNoticePriority.important,
    ),
    StudentNotice(
      id: 'sn-3',
      title: 'Library week — extra reading hours',
      dateLabel: '3 Jun 2026',
      summary: 'Library open till 5 PM all week. Borrow up to 3 books.',
      scope: StudentNoticeScope.school,
      priority: StudentNoticePriority.normal,
      isRead: true,
    ),
    StudentNotice(
      id: 'sn-4',
      title: '8-A maths revision session Saturday',
      dateLabel: '2 Jun 2026',
      summary: 'Optional revision class 9–11 AM in Room 203.',
      scope: StudentNoticeScope.classNotice,
      priority: StudentNoticePriority.important,
    ),
  ];
}

