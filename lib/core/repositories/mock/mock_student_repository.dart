import '../../../features/parent/attendance/attendance_models.dart';
import '../../../features/parent/timetable/timetable_models.dart';
import 'mock_attendance_sync_store.dart';
import '../../../features/student/dashboard/student_dashboard_provider.dart';
import '../../../features/student/exams/exam_models.dart';
import '../../../features/student/homework/homework_models.dart';
import '../../../features/student/notices/notices_models.dart';
import '../../../features/student/profile/profile_models.dart';
import '../../../features/student/student_requests.dart';
import '../interfaces/student_repository.dart';
import '../repository_query.dart';
import 'mock_canonical_student_registry.dart';
import '../../homework/school_homework_store.dart';
import '../../communication/parent_communication_store.dart';
import '../../communication/school_broadcast_store.dart';
import '../../exams/exam_administration_store.dart';
import '../../i18n/content_localization.dart';
import '../../i18n/supported_languages.dart';
import 'mock_student_write_store.dart';

class MockStudentRepository implements StudentRepository {
  MockStudentWriteStore get _store => MockStudentWriteStore.instance;
  @override
  Future<StudentDashboardData> getDashboard({required RepositoryQuery query}) async =>
      StudentDashboardData.mock();

  @override
  Future<AttendanceMonthData> getAttendance({
    required RepositoryQuery query,
    required DateTime month,
  }) async {
    // Same teacher-submission sync the parent view uses, so the student sees
    // their real attendance once the teacher marks it.
    final base = AttendanceMonthData.mock(month: month);
    return MockAttendanceSyncStore.instance.mergedMonth(base);
  }

  @override
  Future<List<StudentHomeworkItem>> getHomeworkItems({
    required RepositoryQuery query,
  }) async {
    final student = MockCanonicalStudentRegistry.primaryMobileStudent;
    final language = ParentCommunicationStore.instance
        .preferredLanguageForStudent(student.sisStudentId);
    final base = _mockItems();
    final storeRecords = SchoolHomeworkStore.instance.forStudent(student.sisStudentId);
    final created = [
      for (final record in storeRecords)
        SchoolHomeworkStore.instance.toStudentItem(
          record,
          ContentLocalization.localize(record.title, language),
          sisStudentId: student.sisStudentId,
        ),
    ];
    return [
      ...created,
      for (final item in base)
        _localizeHomeworkItem(_store.submittedHomework[item.id] ?? item, language),
    ];
  }

  @override
  Future<StudentExamsData> getExams({required RepositoryQuery query}) async {
    final student = MockCanonicalStudentRegistry.primaryMobileStudent;
    final store = ExamAdministrationStore.instance..ensureSeeded();
    final published = store.resultsForStudent(student.sisStudentId);
    final upcoming = store.upcomingExams(classLabel: student.classLabel);

    final examResults = [
      for (final result in published)
        StudentExamResult(
          id: result.markEntryId,
          title: result.examTitle,
          termLabel: result.termLabel,
          dateLabel: result.dateLabel,
          scoreObtained: result.scoreObtained,
          maxScore: result.maxScore,
          grade: result.grade,
        ),
    ];

    final subjectScores = _subjectScoresFromPublished(published);
    final average = examResults.isEmpty
        ? 0
        : ((examResults.fold<int>(0, (sum, item) => sum + item.scoreObtained) /
                    examResults.fold<int>(0, (sum, item) => sum + item.maxScore)) *
                100)
            .round();

    return StudentExamsData(
      studentName: student.studentName,
      classLabel: student.classLabel,
      unreadNotifications: 2,
      averagePercent: average,
      upcomingExams: [
        for (final exam in upcoming)
          StudentUpcomingExam(
            id: exam.id,
            title: exam.title,
            subject: exam.subject,
            dateLabel: exam.dateLabel,
            timeLabel: exam.timeLabel,
            venueLabel: exam.venueLabel,
          ),
      ],
      examResults: examResults,
      subjectScores: subjectScores,
    );
  }

  @override
  Future<ParentTimetableData> getTimetable({required RepositoryQuery query}) async =>
      _mockWeekData();

  @override
  Future<List<StudentNotice>> getNotices({required RepositoryQuery query}) async {
    final student = MockCanonicalStudentRegistry.primaryMobileStudent;
    final language = ParentCommunicationStore.instance
        .preferredLanguageForStudent(student.sisStudentId);
    return [
      ...SchoolBroadcastStore.instance.studentNotices(),
      for (final notice in _mockNotices())
        StudentNotice(
          id: notice.id,
          title: ContentLocalization.localize(notice.title, language),
          summary: ContentLocalization.localize(notice.summary, language),
          dateLabel: notice.dateLabel,
          scope: notice.scope,
          priority: notice.priority,
          isRead: notice.isRead,
        ),
    ];
  }

  @override
  Future<StudentProfileData> getProfile({required RepositoryQuery query}) async {
    final student = MockCanonicalStudentRegistry.primaryMobileStudent;
    return StudentProfileData(
      studentName: student.studentName,
      classLabel: student.classLabel,
      rollNo: student.rollNo,
      admissionNo: student.admissionNumber,
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

  @override
  Future<StudentHomeworkItem> submitHomework({
    required RepositoryQuery query,
    required StudentHomeworkSubmitRequest request,
  }) async {
    final existing = _mockItems().firstWhere(
      (item) => item.id == request.homeworkId,
      orElse: () => throw StateError('Homework not found: ${request.homeworkId}'),
    );
    final submitted = StudentHomeworkItem(
      id: existing.id,
      subject: existing.subject,
      title: existing.title,
      dueLabel: existing.dueLabel,
      status: StudentHomeworkStatus.submitted,
      attachmentLabel: request.attachmentLabel ?? existing.attachmentLabel,
      submittedLabel: 'Submitted just now',
    );
    _store.submittedHomework[request.homeworkId] = submitted;
    return submitted;
  }
}



List<SubjectScore> _subjectScoresFromPublished(List<PublishedExamResult> published) {
  if (published.isEmpty) return const [];
  return [
    for (final result in published)
      SubjectScore(
        subject: result.subject,
        scorePercent: result.maxScore == 0
            ? 0
            : ((result.scoreObtained / result.maxScore) * 100).round(),
        grade: result.grade,
      ),
  ];
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




StudentHomeworkItem _localizeHomeworkItem(
  StudentHomeworkItem item,
  AksharaLanguage language,
) {
  return StudentHomeworkItem(
    id: item.id,
    subject: item.subject,
    title: ContentLocalization.localize(item.title, language),
    dueLabel: item.dueLabel,
    status: item.status,
    attachmentLabel: item.attachmentLabel,
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

