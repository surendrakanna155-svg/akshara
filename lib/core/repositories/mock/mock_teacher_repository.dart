import '../../../features/teacher/attendance/attendance_models.dart';
import '../../../features/teacher/dashboard/teacher_dashboard_provider.dart';
import '../../../features/teacher/exams/exam_models.dart';
import '../../../features/teacher/homework/homework_models.dart';
import '../../../features/teacher/leave/leave_models.dart';
import '../../../features/teacher/messages/message_models.dart';
import '../../../features/teacher/teacher_requests.dart';
import '../../../features/teacher/timetable/timetable_models.dart';
import '../../../shared/semantic_status.dart';
import '../interfaces/teacher_repository.dart';
import '../repository_query.dart';
import 'mock_attendance_sync_store.dart';
import 'mock_canonical_student_registry.dart';
import '../../communication/parent_communication_governance.dart';
import '../../teaching/teacher_assignment_registry.dart';
import '../../communication/parent_communication_models.dart';
import '../../communication/parent_communication_store.dart';
import '../../communication/subject_teacher_concern_store.dart';
import '../../exams/exam_administration_store.dart';
import '../../homework/school_homework_store.dart';
import 'mock_teacher_write_store.dart';

class MockTeacherRepository implements TeacherRepository {
  MockTeacherWriteStore get _store => MockTeacherWriteStore.instance;
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
      getAttendanceStudentsByClass({required RepositoryQuery query}) async {
    final base = _mockStudentsByClass();
    return {
      for (final entry in base.entries)
        entry.key: _applyAttendanceDraft(entry.key, entry.value),
    };
  }

  @override
  Future<List<TeacherHomeworkAssignment>> getHomeworkAssignments({
    required RepositoryQuery query,
  }) async {
    final map = _mockSubmissions();
    final base = [
      TeacherHomeworkAssignment(
        id: 'hw_8a_1',
        title: 'Exercise 5.2 — Linear equations',
        classLabel: '8-A',
        dueLabel: 'Due 8 Jun 2026',
        submissions: _applyHomeworkReviews(map['hw_8a_1'] ?? const []),
      ),
      TeacherHomeworkAssignment(
        id: 'hw_9b_1',
        title: 'Chapter 4 problem set',
        classLabel: '9-B',
        dueLabel: 'Due 10 Jun 2026',
        submissions: _applyHomeworkReviews(map['hw_9b_1'] ?? const []),
      ),
    ];
    final created = [
      for (final record in SchoolHomeworkStore.instance.allRecords())
        SchoolHomeworkStore.instance.toTeacherAssignment(record),
    ];
    return [...created, ...base];
  }

  @override
  Future<List<TeacherUpcomingExam>> getUpcomingExams({
    required RepositoryQuery query,
    TeacherTeachingContext? teachingContext,
  }) async {
    final store = ExamAdministrationStore.instance..ensureSeeded();
    return [
      for (final exam in store.upcomingExams())
        if (_teaches(teachingContext, exam))
          TeacherUpcomingExam(
            id: exam.id,
            title: exam.title,
            classLabel: exam.classLabel,
            dateLabel: exam.dateLabel,
            maxMarks: exam.maxMarks,
            subject: exam.subject,
            canEnterMarks: exam.phase == ExamLifecyclePhase.marksEntry ||
                exam.phase == ExamLifecyclePhase.processed,
          ),
    ];
  }

  /// Scopes an exam to the teacher's subject assignments. When no teaching
  /// context is supplied (e.g. contract/integration probes) nothing is hidden.
  bool _teaches(TeacherTeachingContext? context, ExamSession exam) {
    if (context == null) return true;
    return TeacherAssignmentRegistry.teachesSubjectClass(
      teacherId: context.teacherId,
      teacherName: context.teacherName,
      subject: exam.subject,
      grade: exam.grade,
      section: exam.section,
    );
  }

  @override
  Future<List<TeacherExamSessionOption>> getMarksEntryExams({
    required RepositoryQuery query,
    TeacherTeachingContext? teachingContext,
  }) async {
    final store = ExamAdministrationStore.instance..ensureSeeded();
    return [
      for (final exam in store.allExams())
        if ((exam.phase == ExamLifecyclePhase.marksEntry ||
                exam.phase == ExamLifecyclePhase.processed) &&
            _teaches(teachingContext, exam))
          TeacherExamSessionOption(
            id: exam.id,
            title: exam.title,
            classLabel: exam.classLabel,
            maxMarks: exam.maxMarks,
            subject: exam.subject,
            termLabel: exam.termLabel,
            dateLabel: exam.dateLabel,
            phaseLabel: exam.phase.name,
            coordinatorVerified: store.isCoordinatorVerified(exam.id),
            rejectionComment: store.rejectionCommentFor(exam.id),
          ),
    ];
  }

  @override
  Future<List<ExamMarkEntry>> getExamMarks({
    required RepositoryQuery query,
    String? examId,
  }) async {
    final store = ExamAdministrationStore.instance..ensureSeeded();
    final resolvedId = examId ?? store.activeMarksExamId;
    if (resolvedId == null) return const [];
    final exam = store.examById(resolvedId);
    if (exam == null) return const [];
    return [
      for (final mark in store.marksForExam(resolvedId))
        ExamMarkEntry(
          id: mark.id,
          studentName: mark.studentName,
          rollNo: mark.rollNo,
          marksObtained: mark.marksObtained,
          maxMarks: exam.maxMarks,
        ),
    ];
  }

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
  }) async {
    await _ensureLeaveHistory();
    return List.from(_store.leaveRequests!);
  }

  @override
  Future<LeaveBalance> getLeaveBalance({required RepositoryQuery query}) async =>
      const LeaveBalance(
        casualRemaining: 6,
        sickRemaining: 4,
        earnedRemaining: 12,
      );

  @override
  Future<List<MessageThread>> getMessageThreads({required RepositoryQuery query}) async {
    await _ensureMessageThreads();
    return List.from(_store.messageThreads!);
  }

  @override
  Future<TeacherAttendanceDraftResult> saveAttendanceDraft({
    required RepositoryQuery query,
    required TeacherAttendanceDraftRequest request,
  }) async {
    _store.attendanceDrafts[request.classId] = {
      for (final entry in request.entries) entry.studentId: entry.mark,
    };
    return TeacherAttendanceDraftResult(
      classId: request.classId,
      savedAtLabel: 'Saved just now',
      markedCount: request.entries.length,
    );
  }

  @override
  Future<TeacherAttendanceSubmitResult> submitClassAttendance({
    required RepositoryQuery query,
    required TeacherAttendanceSubmitRequest request,
  }) async {
    _store.attendanceDrafts[request.classId] = {
      for (final entry in request.entries) entry.studentId: entry.mark,
    };
    _store.submittedClasses.add(request.classId);
    var present = 0;
    var absent = 0;
    var late = 0;
    for (final entry in request.entries) {
      switch (entry.mark) {
        case StudentAttendanceMark.present:
          present++;
        case StudentAttendanceMark.absent:
          absent++;
        case StudentAttendanceMark.late:
          late++;
        case StudentAttendanceMark.unmarked:
          break;
      }
    }
    MockAttendanceSyncStore.instance.recordTeacherSubmit(
      present: present,
      absent: absent,
      late: late,
    );
    return TeacherAttendanceSubmitResult(
      classId: request.classId,
      submittedAtLabel: 'Submitted just now',
      presentCount: present,
      absentCount: absent,
      lateCount: late,
    );
  }

  @override
  Future<TeacherHomeworkReviewResult> reviewHomeworkSubmission({
    required RepositoryQuery query,
    required TeacherHomeworkReviewRequest request,
  }) async {
    final existing = _findSubmission(request.submissionId);
    final reviewed = existing.copyWith(
      status: HomeworkReviewStatus.reviewed,
      grade: request.grade,
      comment: request.comment.trim().isEmpty ? null : request.comment.trim(),
    );
    _store.reviewedSubmissions[request.submissionId] = reviewed;
    return TeacherHomeworkReviewResult(submission: reviewed);
  }

  @override
  Future<ExamMarkEntry> updateExamMark({
    required RepositoryQuery query,
    required TeacherExamMarkUpdateRequest request,
  }) async {
    final store = ExamAdministrationStore.instance..ensureSeeded();
    final updated = store.recordMark(
      markEntryId: request.markEntryId,
      marksObtained: request.marksObtained,
    );
    final exam = store.examById(updated.examId)!;
    return ExamMarkEntry(
      id: updated.id,
      studentName: updated.studentName,
      rollNo: updated.rollNo,
      marksObtained: updated.marksObtained,
      maxMarks: exam.maxMarks,
    );
  }

  @override
  Future<TeacherExamProcessResultsResult> processExamResults({
    required RepositoryQuery query,
    required TeacherExamProcessResultsRequest request,
  }) async {
    final store = ExamAdministrationStore.instance..ensureSeeded();
    final exam = store.processResults(request.examId);
    return TeacherExamProcessResultsResult(
      examId: exam.id,
      examTitle: exam.title,
      phaseLabel: exam.phase.name,
    );
  }

  @override
  Future<TeacherExamPublishResult> publishExamResults({
    required RepositoryQuery query,
    required TeacherExamPublishRequest request,
  }) async {
    final store = ExamAdministrationStore.instance..ensureSeeded();
    final count = store.publishExamResults(request.examId);
    final exam = store.examById(request.examId)!;
    return TeacherExamPublishResult(
      examId: exam.id,
      examTitle: exam.title,
      publishedCount: count,
      publishedAtLabel: 'Just now',
    );
  }

  @override
  Future<ParentCommunicationSendResult> sendParentCommunication({
    required RepositoryQuery query,
    required TeacherParentCommunicationSendRequest request,
    required TeacherTeachingContext teachingContext,
  }) async {
    final student = MockCanonicalStudentRegistry.byId(request.sisStudentId);
    if (student == null) {
      throw StateError('Student not found: ${request.sisStudentId}');
    }
    ParentCommunicationGovernance.assertCanSend(teachingContext, student);

    final result = ParentCommunicationStore.instance.send(
      request: ParentCommunicationSendRequest(
        sisStudentId: request.sisStudentId,
        reason: request.reason,
        tone: request.tone,
        channels: request.channels,
        customMessage: request.customMessage,
        useAi: request.useAi,
        sourceConcernId: request.sourceConcernId,
      ),
      senderName: teachingContext.teacherName,
      parentPhone: student.sisStudentId ==
              MockCanonicalStudentRegistry.primaryMobileStudentId
          ? '919876543210'
          : null,
      sourceConcernId: request.sourceConcernId,
    );

    if (request.sourceConcernId != null) {
      SubjectTeacherConcernStore.instance.markSent(
        concernId: request.sourceConcernId!,
        communicationId: result.record.id,
        classTeacherName: teachingContext.teacherName,
      );
    }

    return result;
  }

  @override
  Future<SubjectTeacherConcernFlagResult> flagSubjectConcern({
    required RepositoryQuery query,
    required TeacherSubjectConcernFlagRequest request,
    required TeacherTeachingContext teachingContext,
  }) async {
    final student = MockCanonicalStudentRegistry.byId(request.sisStudentId);
    if (student == null) {
      throw StateError('Student not found: ${request.sisStudentId}');
    }
    ParentCommunicationGovernance.assertCanFlag(teachingContext, student);
    if (teachingContext.isClassTeacherForStudent(student)) {
      throw ParentCommunicationGovernanceException(
        'Class teachers send parent communication directly; escalation is for subject teachers.',
      );
    }

    return SubjectTeacherConcernStore.instance.flag(
      SubjectTeacherConcernFlagRequest(
        sisStudentId: request.sisStudentId,
        category: request.category,
        observation: request.observation,
        flaggedByTeacherId: teachingContext.teacherId,
        flaggedByTeacherName: teachingContext.teacherName,
        subject: teachingContext.primarySubject,
      ),
    );
  }

  @override
  Future<List<SubjectTeacherConcern>> listPendingConcerns({
    required RepositoryQuery query,
    required TeacherTeachingContext teachingContext,
  }) async {
    final classLabel = teachingContext.classTeacherClassLabel;
    if (classLabel == null) return const [];
    return SubjectTeacherConcernStore.instance.pendingForClass(classLabel);
  }

  @override
  Future<SubjectTeacherConcern> dismissSubjectConcern({
    required RepositoryQuery query,
    required String concernId,
    required TeacherTeachingContext teachingContext,
    String? note,
  }) async {
    if (!teachingContext.isClassTeacher) {
      throw ParentCommunicationGovernanceException(
        'Only the class teacher may dismiss escalated concerns.',
      );
    }
    return SubjectTeacherConcernStore.instance.dismiss(
      concernId: concernId,
      classTeacherName: teachingContext.teacherName,
      note: note,
    );
  }

  @override
  Future<TeacherLeaveRequest> submitLeaveRequest({
    required RepositoryQuery query,
    required TeacherLeaveSubmitRequest request,
  }) async {
    await _ensureLeaveHistory();
    final leave = TeacherLeaveRequest(
      id: _store.nextLeaveId(),
      typeLabel: request.typeLabel,
      fromDateLabel: request.fromDateLabel,
      toDateLabel: request.toDateLabel,
      reason: request.reason.trim(),
      status: TeacherLeaveStatus.pending,
      timeline: const [
        LeaveTimelineStep(
          label: 'Submitted',
          dateLabel: 'Just now',
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
    );
    _store.leaveRequests!.insert(0, leave);
    return leave;
  }

  @override
  Future<MessageThread> sendMessage({
    required RepositoryQuery query,
    required TeacherMessageSendRequest request,
  }) async {
    await _ensureMessageThreads();
    final message = MessageItem(
      id: _store.nextMessageId(),
      body: request.body.trim(),
      senderLabel: 'Priya Sharma',
      timeLabel: 'Just now',
      isTeacher: true,
    );

    if (request.threadId != null) {
      final index = _store.messageThreads!.indexWhere(
        (thread) => thread.id == request.threadId,
      );
      if (index >= 0) {
        final existing = _store.messageThreads![index];
        final updated = MessageThread(
          id: existing.id,
          parentName: existing.parentName,
          studentName: existing.studentName,
          preview: request.body.trim(),
          timeLabel: 'Just now',
          unreadCount: existing.unreadCount,
          messages: [...existing.messages, message],
        );
        _store.messageThreads![index] = updated;
        return updated;
      }
    }

    final thread = MessageThread(
      id: _store.nextThreadId(),
      parentName: request.recipient,
      studentName: request.subject,
      preview: request.body.trim(),
      timeLabel: 'Just now',
      unreadCount: 0,
      messages: [message],
    );
    _store.messageThreads!.insert(0, thread);
    return thread;
  }

  Future<void> _ensureLeaveHistory() async {
    _store.leaveRequests ??= List<TeacherLeaveRequest>.from(_mockHistory());
  }

  Future<void> _ensureMessageThreads() async {
    _store.messageThreads ??= List<MessageThread>.from(_mockThreads());
  }

  List<TeacherAttendanceStudent> _applyAttendanceDraft(
    String classId,
    List<TeacherAttendanceStudent> students,
  ) {
    final draft = _store.attendanceDrafts[classId];
    if (draft == null) return students;
    return [
      for (final student in students)
        draft.containsKey(student.id)
            ? student.copyWith(mark: draft[student.id]!)
            : student,
    ];
  }

  List<HomeworkSubmission> _applyHomeworkReviews(List<HomeworkSubmission> items) {
    return [
      for (final item in items) _store.reviewedSubmissions[item.id] ?? item,
    ];
  }

  HomeworkSubmission _findSubmission(String submissionId) {
    for (final submissions in _mockSubmissions().values) {
      for (final submission in submissions) {
        if (submission.id == submissionId) return submission;
      }
    }
    throw StateError('Submission not found: $submissionId');
  }
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
  // Contract tests expect stable mock studentIds (s1..s6). We keep those ids
  // but align the canonical student name ("Ravi Kumar") to s5.
  final students8a = [
    TeacherAttendanceStudent(
      id: 's1',
      name: 'Arjun Das',
      rollNo: '05',
      mark: StudentAttendanceMark.unmarked,
    ),
    TeacherAttendanceStudent(
      id: 's2',
      name: 'Ananya Rao',
      rollNo: '02',
      mark: StudentAttendanceMark.present,
    ),
    TeacherAttendanceStudent(
      id: 's3',
      name: 'Karthik Menon',
      rollNo: '03',
      mark: StudentAttendanceMark.late,
    ),
    TeacherAttendanceStudent(
      id: 's4',
      name: 'Priya Nair',
      rollNo: '04',
      mark: StudentAttendanceMark.absent,
    ),
    TeacherAttendanceStudent(
      id: 's5',
      name: 'Ravi Kumar',
      rollNo: '01',
      mark: StudentAttendanceMark.unmarked,
    ),
    TeacherAttendanceStudent(
      id: 's6',
      name: 'Meera Iyer',
      rollNo: '06',
      mark: StudentAttendanceMark.unmarked,
    ),
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


