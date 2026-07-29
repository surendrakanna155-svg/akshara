import '../../../features/school_completion/school_completion_models.dart';
import '../interfaces/school_completion_repository.dart';
import '../repository_query.dart';

class MockSchoolCompletionRepository implements SchoolCompletionRepository {
  final List<AcademicSubject> _subjects = [
    const AcademicSubject(
      id: 'sub_1',
      subjectCode: 'ENG',
      subjectName: 'English',
      category: 'core',
      gradeLabels: ['Grade 1', 'Grade 2'],
      status: 'active',
    ),
    const AcademicSubject(
      id: 'sub_2',
      subjectCode: 'MATH',
      subjectName: 'Mathematics',
      category: 'core',
      gradeLabels: ['Grade 1', 'Grade 2'],
      status: 'active',
    ),
    const AcademicSubject(
      id: 'sub_3',
      subjectCode: 'SCI',
      subjectName: 'Science',
      category: 'core',
      gradeLabels: ['Grade 2'],
      status: 'active',
    ),
  ];

  final List<LessonLogEntry> _lessonLogs = [
    const LessonLogEntry(
      id: 'log_demo_1',
      teacherUserId: 'teacher_1',
      className: '5',
      sectionName: 'A',
      subjectId: 'sub_1',
      topic: 'Fractions introduction',
      outcome: 'completed',
      recordedOn: '2026-06-01',
    ),
    const LessonLogEntry(
      id: 'log_demo_2',
      teacherUserId: 'teacher_1',
      className: '5',
      sectionName: 'A',
      subjectId: 'sub_2',
      topic: 'Algebra basics',
      outcome: 'completed',
      recordedOn: '2026-06-02',
    ),
  ];
  SchoolBranding _branding = const SchoolBranding(
    // User-visible: this seed drives schoolDisplayNameProvider, i.e. the login
    // screen, the splash screen, the app title and the parent shell header in
    // demo/mock mode — and therefore every store screenshot. It must carry the
    // NIKSHA brand, not the pre-rename one.
    displayName: 'NIKSHA Demo School',
    tagline: 'Learning with purpose',
    primaryColor: '#1B4D89',
    secondaryColor: '#F5A623',
    logoUrl: 'assets/branding/demo_logo.png',
  );

  WhatsAppProviderConfig _whatsApp = const WhatsAppProviderConfig(
    provider: 'stub',
    isActive: true,
    senderId: 'NIKSHA',
  );

  // Class names use the same convention as MockAcademicRepository's catalog
  // ('1'..'12', not 'Grade 1'..'Grade 12') so the daily-capture dialog's class
  // picker (sourced from the real academic catalog) actually matches these
  // topics in demo/mock mode too.
  final List<SyllabusTopic> _syllabusTopics = [
    const SyllabusTopic(
      id: 'top_1',
      subjectId: 'sub_1',
      className: '7',
      chapterId: 'ch_1',
      topicName: 'Linear equations',
      sequenceOrder: 0,
      status: 'pending',
    ),
    const SyllabusTopic(
      id: 'top_2',
      subjectId: 'sub_1',
      className: '7',
      chapterId: 'ch_1',
      topicName: 'Quadratic expressions',
      sequenceOrder: 1,
      status: 'pending',
    ),
    const SyllabusTopic(
      id: 'top_3',
      subjectId: 'sub_2',
      className: '5',
      chapterId: null,
      topicName: 'Fractions introduction',
      sequenceOrder: 0,
      status: 'pending',
    ),
  ];
  final Set<String> _completedTopicIds = {};

  final List<ClassSubjectAssignment> _classSubjects = [];
  final List<TeacherSubjectAssignment> _teacherSubjects = [];
  final List<SubstituteOpenSlot> _substituteOpenSlots = const [
    SubstituteOpenSlot(
      slotId: 'slot_1',
      academicYearId: 'year_1',
      className: 'Grade 7',
      sectionName: 'A',
      subjectName: 'Mathematics',
      originalTeacherId: 'teacher_14',
      originalTeacherName: 'Ms. Kavya',
      dayOfWeek: 'Monday',
      periodLabel: 'P2',
      slotDate: '2026-06-16',
    ),
    SubstituteOpenSlot(
      slotId: 'slot_2',
      academicYearId: 'year_1',
      className: 'Grade 8',
      sectionName: 'B',
      subjectName: 'Science',
      originalTeacherId: 'teacher_11',
      originalTeacherName: 'Mr. Sandeep',
      dayOfWeek: 'Monday',
      periodLabel: 'P4',
      slotDate: '2026-06-16',
    ),
    SubstituteOpenSlot(
      slotId: 'slot_3',
      academicYearId: 'year_1',
      className: 'Grade 9',
      sectionName: 'A',
      subjectName: 'English',
      originalTeacherId: 'teacher_19',
      originalTeacherName: 'Ms. Nitya',
      dayOfWeek: 'Tuesday',
      periodLabel: 'P1',
      slotDate: '2026-06-17',
    ),
  ];
  final List<SubstituteTeacherCandidate> _substituteCandidates = const [
    SubstituteTeacherCandidate(
      teacherId: 'teacher_2',
      teacherName: 'Mr. Vivek',
      subjects: ['Mathematics', 'Science'],
      freePeriods: 3,
      dailyLoad: 4,
      canNotify: true,
    ),
    SubstituteTeacherCandidate(
      teacherId: 'teacher_7',
      teacherName: 'Ms. Divya',
      subjects: ['English', 'Social Science'],
      freePeriods: 2,
      dailyLoad: 5,
      canNotify: true,
    ),
    SubstituteTeacherCandidate(
      teacherId: 'teacher_9',
      teacherName: 'Mr. Raghav',
      subjects: ['Science'],
      freePeriods: 1,
      dailyLoad: 6,
      canNotify: false,
    ),
  ];
  final List<TeacherReassignmentSlot> _teacherReassignmentSlots = const [
    TeacherReassignmentSlot(
      slotId: 'trs_1',
      academicYearId: 'year_1',
      sourceTeacherId: 'teacher_14',
      sourceTeacherName: 'Ms. Kavya',
      className: 'Grade 7',
      sectionName: 'A',
      subjectName: 'Mathematics',
      dayOfWeek: 'Monday',
      periodLabel: 'P2',
      slotDate: '2026-06-16',
    ),
    TeacherReassignmentSlot(
      slotId: 'trs_2',
      academicYearId: 'year_1',
      sourceTeacherId: 'teacher_14',
      sourceTeacherName: 'Ms. Kavya',
      className: 'Grade 7',
      sectionName: 'B',
      subjectName: 'Mathematics',
      dayOfWeek: 'Tuesday',
      periodLabel: 'P3',
      slotDate: '2026-06-17',
    ),
    TeacherReassignmentSlot(
      slotId: 'trs_3',
      academicYearId: 'year_1',
      sourceTeacherId: 'teacher_11',
      sourceTeacherName: 'Mr. Sandeep',
      className: 'Grade 8',
      sectionName: 'B',
      subjectName: 'Science',
      dayOfWeek: 'Wednesday',
      periodLabel: 'P4',
      slotDate: '2026-06-18',
    ),
  ];
  final List<TeacherReassignmentCandidate> _teacherReassignmentCandidates =
      const [
    TeacherReassignmentCandidate(
      teacherId: 'teacher_2',
      teacherName: 'Mr. Vivek',
      subjects: ['Mathematics', 'Science'],
      freePeriods: 3,
      dailyLoad: 4,
      canNotify: true,
    ),
    TeacherReassignmentCandidate(
      teacherId: 'teacher_7',
      teacherName: 'Ms. Divya',
      subjects: ['English', 'Mathematics'],
      freePeriods: 2,
      dailyLoad: 5,
      canNotify: true,
    ),
    TeacherReassignmentCandidate(
      teacherId: 'teacher_9',
      teacherName: 'Mr. Raghav',
      subjects: ['Science'],
      freePeriods: 1,
      dailyLoad: 6,
      canNotify: false,
    ),
  ];
  final Map<String, TimetableOptimizationResult> _timetableOptimizationByYear =
      {
    'year_1': const TimetableOptimizationResult(
      qualityScore: 82,
      conflictCount: 2,
      overloadAlerts: [
        TimetableOverloadAlert(
            teacherId: 't1', teacherName: 'Ms. Rao', periodCount: 28),
      ],
      freePeriodAnalysis: [
        TimetableFreePeriodEntry(
            teacherId: 't2', teacherName: 'Mr. Kumar', freePeriods: 8),
      ],
      substituteSuggestions: [
        TimetableSubstituteSuggestion(
          conflictMessage: 'Teacher double-booked Monday P3',
          suggestion: 'Assign substitute or move to free slot',
        ),
      ],
      recommendations: [
        TimetableRecommendation(
          recommendationId: 'rec_balance_load',
          kind: 'overloaded_teacher',
          title: 'Rebalance workload',
          detail: 'Shift two periods from Ms. Rao to Mr. Kumar.',
          readOnly: false,
        ),
        TimetableRecommendation(
          recommendationId: 'rec_free_slot',
          kind: 'slot_reassignment',
          title: 'Move Grade 7 Algebra slot',
          detail: 'Move Monday P3 Algebra from Room 202 to Tuesday P2.',
          readOnly: false,
        ),
        TimetableRecommendation(
          recommendationId: 'rec_policy',
          kind: 'policy_note',
          title: 'Monitor overload trend',
          detail: 'Track overload pattern for the next 2 weeks.',
          readOnly: true,
        ),
      ],
    ),
  };

  @override
  Future<List<AcademicSubject>> listSubjects(
          {required RepositoryQuery query}) async =>
      List.from(_subjects);

  @override
  Future<AcademicSubject> createSubject({
    required RepositoryQuery query,
    required String subjectCode,
    required String subjectName,
    String category = 'core',
    List<String> gradeLabels = const [],
  }) async {
    final subject = AcademicSubject(
      id: 'sub_${_subjects.length + 1}',
      subjectCode: subjectCode,
      subjectName: subjectName,
      category: category,
      gradeLabels: gradeLabels,
      status: 'active',
    );
    _subjects.add(subject);
    return subject;
  }

  @override
  Future<AcademicSubject> updateSubject({
    required RepositoryQuery query,
    required String subjectId,
    String? subjectName,
    String? category,
    String? status,
  }) async {
    final index = _subjects.indexWhere((s) => s.id == subjectId);
    if (index < 0) throw StateError('Subject not found');
    final existing = _subjects[index];
    final updated = AcademicSubject(
      id: existing.id,
      subjectCode: existing.subjectCode,
      subjectName: subjectName ?? existing.subjectName,
      category: category ?? existing.category,
      gradeLabels: existing.gradeLabels,
      status: status ?? existing.status,
    );
    _subjects[index] = updated;
    return updated;
  }

  @override
  Future<List<LessonLogEntry>> listLessonLogs({
    required RepositoryQuery query,
    String? className,
  }) async {
    if (className == null) return List.from(_lessonLogs);
    return _lessonLogs.where((l) => l.className == className).toList();
  }

  @override
  Future<LessonLogEntry> createLessonLog({
    required RepositoryQuery query,
    required String className,
    required String topic,
    String? sectionName,
    String? subjectId,
    String outcome = 'completed',
    String? notes,
  }) async {
    final entry = LessonLogEntry(
      id: 'log_${_lessonLogs.length + 1}',
      teacherUserId: 'teacher_1',
      className: className,
      sectionName: sectionName,
      subjectId: subjectId,
      topic: topic,
      outcome: outcome,
      notes: notes,
      recordedOn: DateTime.now().toIso8601String().substring(0, 10),
    );
    _lessonLogs.insert(0, entry);
    return entry;
  }

  @override
  Future<TimetableAutomationResult> automateTimetables({
    required RepositoryQuery query,
    required String academicYearId,
    int periodsPerDay = 6,
    int daysPerWeek = 5,
  }) async {
    return TimetableAutomationResult(
      timetablesCreated: 8,
      subjectsUsed: _subjects.map((s) => s.subjectName).toList(),
      warnings: _subjects.length < 5
          ? const ['Consider adding elective subjects']
          : const [],
      conflictCount: 1,
    );
  }

  @override
  Future<SchoolBranding> getBranding({required RepositoryQuery query}) async =>
      _branding;

  @override
  Future<SchoolBranding> saveBranding({
    required RepositoryQuery query,
    required SchoolBranding branding,
  }) async {
    _branding = branding;
    return _branding;
  }

  @override
  Future<WhatsAppProviderConfig> getWhatsAppProvider(
          {required RepositoryQuery query}) async =>
      _whatsApp;

  @override
  Future<WhatsAppProviderConfig> saveWhatsAppProvider({
    required RepositoryQuery query,
    required WhatsAppProviderConfig config,
  }) async {
    _whatsApp = config;
    return _whatsApp;
  }

  @override
  Future<WhatsAppTestResult> testWhatsAppProvider({
    required RepositoryQuery query,
    required String toPhone,
    String? templateId,
  }) async {
    return WhatsAppTestResult(
      success: true,
      providerRef: 'wa_stub_${toPhone.hashCode}',
    );
  }

  @override
  Future<List<ClassSubjectAssignment>> listClassSubjectAssignments({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    if (academicYearId == null) return List.from(_classSubjects);
    return _classSubjects
        .where((a) => a.academicYearId == academicYearId)
        .toList();
  }

  @override
  Future<ClassSubjectAssignment> createClassSubjectAssignment({
    required RepositoryQuery query,
    required String academicYearId,
    required String classId,
    required String subjectId,
    String? sectionId,
    bool isElective = false,
    int periodsPerWeek = 5,
  }) async {
    final duplicate = _classSubjects.any((a) =>
        a.classId == classId &&
        a.sectionId == sectionId &&
        a.subjectId == subjectId);
    if (duplicate) {
      throw StateError('Subject already assigned to this class/section');
    }
    final assignment = ClassSubjectAssignment(
      id: 'csa_${_classSubjects.length + 1}',
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      subjectId: subjectId,
      isElective: isElective,
      periodsPerWeek: periodsPerWeek,
      status: 'active',
    );
    _classSubjects.add(assignment);
    return assignment;
  }

  @override
  Future<void> deleteClassSubjectAssignment({
    required RepositoryQuery query,
    required String assignmentId,
  }) async {
    _classSubjects.removeWhere((a) => a.id == assignmentId);
  }

  @override
  Future<List<TeacherSubjectAssignment>> listTeacherSubjectAssignments({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    if (academicYearId == null) return List.from(_teacherSubjects);
    return _teacherSubjects
        .where((a) => a.academicYearId == academicYearId)
        .toList();
  }

  @override
  Future<TeacherSubjectAssignment> createTeacherSubjectAssignment({
    required RepositoryQuery query,
    required String academicYearId,
    required String teacherUserId,
    required String subjectId,
    String? classId,
    String? sectionId,
    int periodsPerWeek = 0,
    bool isPrimary = false,
  }) async {
    final duplicate = _teacherSubjects.any((a) =>
        a.teacherUserId == teacherUserId &&
        a.subjectId == subjectId &&
        a.classId == classId &&
        a.sectionId == sectionId);
    if (duplicate) {
      throw StateError(
          'Teacher already assigned to this subject for the class/section');
    }
    final assignment = TeacherSubjectAssignment(
      id: 'tsa_${_teacherSubjects.length + 1}',
      academicYearId: academicYearId,
      teacherUserId: teacherUserId,
      subjectId: subjectId,
      classId: classId,
      sectionId: sectionId,
      periodsPerWeek: periodsPerWeek,
      isPrimary: isPrimary,
      status: 'active',
    );
    _teacherSubjects.add(assignment);
    return assignment;
  }

  @override
  Future<List<SubjectWorkloadEntry>> getSubjectWorkload({
    required RepositoryQuery query,
  }) async {
    final map = <String, SubjectWorkloadEntry>{};
    for (final row in _teacherSubjects) {
      final key = '${row.teacherUserId}:${row.subjectId}';
      final existing = map[key];
      if (existing != null) {
        final total = existing.totalPeriods + row.periodsPerWeek;
        map[key] = SubjectWorkloadEntry(
          teacherUserId: row.teacherUserId,
          subjectId: row.subjectId,
          totalPeriods: total,
          assignmentCount: existing.assignmentCount + 1,
          isOverloaded: total > 25,
        );
      } else {
        map[key] = SubjectWorkloadEntry(
          teacherUserId: row.teacherUserId,
          subjectId: row.subjectId,
          totalPeriods: row.periodsPerWeek,
          assignmentCount: 1,
          isOverloaded: row.periodsPerWeek > 25,
        );
      }
    }
    return map.values.toList();
  }

  @override
  Future<TeacherLessonAnalytics> getTeacherLessonAnalytics({
    required RepositoryQuery query,
    String? className,
    String? teacherUserId,
  }) async {
    final logs = await listLessonLogs(query: query, className: className);
    final completed = logs.where((l) => l.outcome == 'completed').length;
    final pending = logs.length - completed;
    return TeacherLessonAnalytics(
      completedLessons: completed,
      pendingLessons: pending,
      coveragePercent: logs.isEmpty ? 0 : (completed * 100 ~/ logs.length),
      pendingTopics: const ['Fractions', 'Decimals'],
      upcomingRisk: pending > 2 ? 'Syllabus behind schedule' : null,
    );
  }

  @override
  Future<List<PrincipalCoverageEntry>> getPrincipalLessonAnalytics({
    required RepositoryQuery query,
  }) async {
    return const [
      PrincipalCoverageEntry(
        className: 'Grade 7',
        subjectId: 'sub_1',
        coveragePercent: 72,
        completedTopics: 18,
        totalTopics: 25,
        pendingTopics: ['Poetry', 'Grammar'],
      ),
    ];
  }

  @override
  Future<TimetableOptimizationResult> getTimetableOptimization({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final seeded = _timetableOptimizationByYear[academicYearId];
    if (seeded != null) {
      return seeded;
    }
    final fallback = _timetableOptimizationByYear['year_1']!;
    _timetableOptimizationByYear[academicYearId] = fallback;
    return fallback;
  }

  @override
  Future<ApplyTimetableOptimizationResult> applyTimetableOptimization({
    required RepositoryQuery query,
    required String academicYearId,
    List<String> recommendationIds = const [],
    bool applyAll = false,
  }) async {
    final current = await getTimetableOptimization(
        query: query, academicYearId: academicYearId);
    final actionable = current.recommendations
        .where((recommendation) =>
            !recommendation.readOnly && recommendation.recommendationId != null)
        .toList(growable: false);
    final allowedIds = actionable
        .map((recommendation) => recommendation.recommendationId!)
        .toSet();
    final requestedIds = applyAll
        ? allowedIds
        : recommendationIds.where((id) => allowedIds.contains(id)).toSet();

    if (requestedIds.isEmpty) {
      return ApplyTimetableOptimizationResult(
        appliedRecommendationIds: const [],
        appliedCount: 0,
        updatedConflictCount: current.conflictCount,
        updatedQualityScore: current.qualityScore,
        message: 'No actionable recommendations selected.',
      );
    }

    final updatedRecommendations =
        current.recommendations.map((recommendation) {
      final id = recommendation.recommendationId;
      if (id == null || !requestedIds.contains(id)) {
        return recommendation;
      }
      return TimetableRecommendation(
        recommendationId: recommendation.recommendationId,
        kind: recommendation.kind,
        title: recommendation.title,
        detail: '${recommendation.detail} (Applied)',
        readOnly: true,
      );
    }).toList(growable: false);
    final appliedCount = requestedIds.length;
    final updatedConflicts = (current.conflictCount - appliedCount)
        .clamp(0, current.conflictCount)
        .toInt();
    final updatedQuality =
        (current.qualityScore + (appliedCount * 4)).clamp(0, 100).toInt();
    final updated = TimetableOptimizationResult(
      qualityScore: updatedQuality,
      conflictCount: updatedConflicts,
      overloadAlerts: current.overloadAlerts,
      freePeriodAnalysis: current.freePeriodAnalysis,
      substituteSuggestions: current.substituteSuggestions,
      recommendations: updatedRecommendations,
    );
    _timetableOptimizationByYear[academicYearId] = updated;
    return ApplyTimetableOptimizationResult(
      appliedRecommendationIds: requestedIds.toList(growable: false),
      appliedCount: appliedCount,
      updatedConflictCount: updatedConflicts,
      updatedQualityScore: updatedQuality,
      message: appliedCount == 1
          ? '1 recommendation applied successfully.'
          : '$appliedCount recommendations applied successfully.',
    );
  }

  @override
  Future<SubstituteCoverageData> getSubstituteCoverage({
    required RepositoryQuery query,
    required String academicYearId,
    String? dayOfWeek,
  }) async {
    final normalizedDay = dayOfWeek?.trim().toLowerCase();
    final slots = _substituteOpenSlots
        .where((slot) => slot.academicYearId == academicYearId)
        .where(
          (slot) => normalizedDay == null || normalizedDay.isEmpty
              ? true
              : slot.dayOfWeek.toLowerCase() == normalizedDay,
        )
        .toList(growable: false);
    return SubstituteCoverageData(
      openSlots: slots,
      candidates: List<SubstituteTeacherCandidate>.from(_substituteCandidates),
      generatedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<SubstituteAssignmentResult> assignSubstitute({
    required RepositoryQuery query,
    required AssignSubstituteRequest request,
  }) async {
    final slot =
        _substituteOpenSlots.where((entry) => entry.slotId == request.slotId);
    if (slot.isEmpty) {
      throw StateError('Open slot not found');
    }
    final teacher = _substituteCandidates
        .where((entry) => entry.teacherId == request.substituteTeacherId);
    if (teacher.isEmpty) {
      throw StateError('Substitute teacher not available');
    }
    final notifiedAudience = <String>[
      if (request.notifySubstituteTeacher) 'substitute_teacher',
      if (request.notifyClassIncharge) 'class_incharge',
      if (request.notifyStudents) 'students',
    ];
    return SubstituteAssignmentResult(
      assignmentId: 'sub_assign_${DateTime.now().millisecondsSinceEpoch}',
      slotId: request.slotId,
      timetableUpdated: true,
      notifiedAudience: notifiedAudience,
      message: 'Substitute assigned and timetable updated.',
    );
  }

  @override
  Future<TeacherReassignmentData> getTeacherReassignmentOptions({
    required RepositoryQuery query,
    required String academicYearId,
    String? sourceTeacherId,
  }) async {
    final filtered = _teacherReassignmentSlots
        .where((slot) => slot.academicYearId == academicYearId)
        .toList(growable: false);
    if (filtered.isEmpty) {
      return TeacherReassignmentData(
        sourceTeacherId: sourceTeacherId ?? '',
        sourceTeacherName: '',
        slots: const [],
        candidates: List<TeacherReassignmentCandidate>.from(
            _teacherReassignmentCandidates),
        generatedAt: DateTime.now().toIso8601String(),
      );
    }
    final resolvedSourceTeacherId = sourceTeacherId?.trim().isNotEmpty == true
        ? sourceTeacherId!.trim()
        : filtered.first.sourceTeacherId;
    final slotsForTeacher = filtered
        .where((slot) => slot.sourceTeacherId == resolvedSourceTeacherId)
        .toList(growable: false);
    final sourceTeacherName = slotsForTeacher.isNotEmpty
        ? slotsForTeacher.first.sourceTeacherName
        : filtered.first.sourceTeacherName;
    return TeacherReassignmentData(
      sourceTeacherId: resolvedSourceTeacherId,
      sourceTeacherName: sourceTeacherName,
      slots: slotsForTeacher,
      candidates: List<TeacherReassignmentCandidate>.from(
          _teacherReassignmentCandidates),
      generatedAt: DateTime.now().toIso8601String(),
    );
  }

  @override
  Future<TeacherReassignmentResult> reassignTeacher({
    required RepositoryQuery query,
    required ReassignTeacherRequest request,
  }) async {
    final availableSlotIds =
        _teacherReassignmentSlots.map((slot) => slot.slotId).toSet();
    final hasInvalidSlot =
        request.slotIds.any((slotId) => !availableSlotIds.contains(slotId));
    if (hasInvalidSlot) {
      throw StateError('One or more selected timetable periods are invalid.');
    }
    final targetExists = _teacherReassignmentCandidates
        .any((candidate) => candidate.teacherId == request.targetTeacherId);
    if (!targetExists) {
      throw StateError('Target teacher is not available for reassignment.');
    }
    final notifiedAudience = <String>[
      if (request.notifySourceTeacher) 'source_teacher',
      if (request.notifyTargetTeacher) 'target_teacher',
      if (request.notifyStudents) 'students',
    ];
    return TeacherReassignmentResult(
      reassignmentId:
          'teacher_reassign_${DateTime.now().millisecondsSinceEpoch}',
      sourceTeacherId: request.sourceTeacherId,
      targetTeacherId: request.targetTeacherId,
      updatedSlotIds: request.slotIds,
      notifiedAudience: notifiedAudience,
      message: 'Teacher reassignment completed and timetable updated.',
    );
  }

  @override
  Future<DeliveryAnalytics> getDeliveryAnalytics({
    required RepositoryQuery query,
  }) async {
    return const DeliveryAnalytics(
      totalSent: 120,
      totalFailed: 3,
      totalPending: 5,
      deliveryRate: 94,
      byChannel: {
        'whatsapp': DeliveryChannelStats(sent: 80, failed: 2, pending: 2),
        'in_app': DeliveryChannelStats(sent: 40, failed: 1, pending: 3),
      },
      recentEvents: [],
    );
  }

  @override
  Future<PilotDashboardSnapshot> getPilotDashboard({
    required RepositoryQuery query,
  }) async {
    return const PilotDashboardSnapshot(
      onboardingStatus: 'in_progress',
      setupWizardCompleted: false,
      pilotScore: 68,
      importHealth:
          PilotImportHealth(totalJobs: 2, committedJobs: 1, failedRows: 4),
      teacherActivation: PilotActivationStats(
          total: 20, active: 14, pending: 6, activationRate: 70),
      parentActivation: PilotActivationStats(
          total: 150, active: 90, pending: 60, activationRate: 60),
      otpDelivery: PilotOtpDelivery(
          sentLast7Days: 45, failedLast7Days: 2, deliveryRate: 96),
    );
  }

  @override
  Future<List<SubjectTemplate>> listSubjectTemplates({
    required RepositoryQuery query,
    String? board,
    String? gradeLabel,
  }) async =>
      const [
        SubjectTemplate(
          id: 'tpl_1',
          board: 'CBSE',
          subjectCode: 'MATH',
          subjectName: 'Mathematics',
          gradeLabel: 'Grade 7',
          chapters: [
            SyllabusTemplateChapter(
                name: 'Algebra', topics: ['Expressions', 'Equations']),
          ],
        ),
      ];

  @override
  Future<SyllabusGenerationResult> generateSyllabus({
    required RepositoryQuery query,
    required String academicYearId,
    required String className,
    required String subjectId,
    required String subjectName,
    required String gradeLabel,
  }) async =>
      const SyllabusGenerationResult(
          chaptersCreated: 4, topicsCreated: 12, generationId: 'gen_1');

  @override
  Future<SyllabusGenerationResult> cloneSyllabus({
    required RepositoryQuery query,
    required String fromYearId,
    required String toYearId,
  }) async =>
      const SyllabusGenerationResult(
          chaptersCreated: 4, topicsCreated: 12, generationId: 'gen_clone');

  @override
  Future<List<SyllabusChapter>> listSyllabusChapters({
    required RepositoryQuery query,
    String? academicYearId,
  }) async =>
      const [
        SyllabusChapter(
          id: 'ch_1',
          academicYearId: 'year_1',
          subjectId: 'sub_1',
          className: 'Grade 7',
          chapterName: 'Algebra',
          sequenceOrder: 0,
          status: 'in_progress',
        ),
      ];

  @override
  Future<List<SyllabusTopic>> listSyllabusTopics({
    required RepositoryQuery query,
    String? className,
    String? subjectId,
    String? chapterId,
  }) async {
    return _syllabusTopics
        .where((t) => className == null || t.className == className)
        .where((t) => subjectId == null || t.subjectId == subjectId)
        .where((t) => chapterId == null || t.chapterId == chapterId)
        .map((t) => _completedTopicIds.contains(t.id)
            ? SyllabusTopic(
                id: t.id,
                subjectId: t.subjectId,
                className: t.className,
                chapterId: t.chapterId,
                topicName: t.topicName,
                sequenceOrder: t.sequenceOrder,
                status: 'completed',
              )
            : t)
        .toList();
  }

  @override
  Future<void> completeTopic({
    required RepositoryQuery query,
    required String topicId,
    String? lessonLogId,
  }) async {
    final exists = _syllabusTopics.any((t) => t.id == topicId);
    if (!exists) {
      throw StateError('Syllabus topic not found: $topicId');
    }
    _completedTopicIds.add(topicId);
  }

  @override
  Future<TeacherProgressDashboard> getTeacherProgress({
    required RepositoryQuery query,
  }) async =>
      const TeacherProgressDashboard(
        topicsCompleted: 18,
        topicsPending: 6,
        chaptersCompleted: 3,
        chaptersTotal: 5,
        coveragePercent: 75,
        pendingAlerts: ['Fractions', 'Decimals'],
      );

  @override
  Future<PrincipalAcademicDashboard> getPrincipalAcademicProgress({
    required RepositoryQuery query,
  }) async =>
      const PrincipalAcademicDashboard(
        overallCoveragePercent: 72,
        classCoverage: [
          PrincipalClassCoverage(
            className: 'Grade 7',
            subjectId: 'sub_1',
            coveragePercent: 72,
            pendingTopics: 4,
          ),
        ],
      );

  @override
  Future<List<AcademicRoom>> listRooms(
          {required RepositoryQuery query}) async =>
      const [
        AcademicRoom(
            id: 'room_1',
            roomLabel: 'Room 101',
            roomType: 'classroom',
            capacity: 40,
            status: 'active'),
        AcademicRoom(
            id: 'room_2',
            roomLabel: 'Science Lab',
            roomType: 'lab',
            capacity: 30,
            status: 'active'),
      ];

  @override
  Future<AcademicRoom> createRoom({
    required RepositoryQuery query,
    required String roomLabel,
    String roomType = 'classroom',
    int capacity = 40,
  }) async =>
      AcademicRoom(
          id: 'room_new',
          roomLabel: roomLabel,
          roomType: roomType,
          capacity: capacity,
          status: 'active');

  @override
  Future<TimetableIntelligenceResult> getTimetableIntelligence({
    required RepositoryQuery query,
    required String academicYearId,
  }) async =>
      const TimetableIntelligenceResult(
        intelligenceScore: 85,
        examCount: 6,
        conflictCount: 1,
        roomUtilization: [
          RoomUtilizationEntry(
              roomLabel: 'Room 101', periodCount: 24, capacity: 40),
        ],
      );

  @override
  Future<CommunicationAnalyticsSummary> getCommunicationAnalytics({
    required RepositoryQuery query,
  }) async =>
      const CommunicationAnalyticsSummary(
        campaigns: CampaignAnalytics(
          totalCampaigns: 3,
          activeCampaigns: 1,
          aggregateDeliveryRate: 94,
          aggregateOpenRate: 62,
          aggregateResponseRate: 28,
          campaigns: [
            CampaignSummary(
              id: 'camp_1',
              campaignCode: 'FEE_REM',
              campaignName: 'Fee Reminder June',
              channel: 'whatsapp',
              templateCode: 'fee_reminder',
              status: 'completed',
              sentCount: 120,
              deliveredCount: 115,
              failedCount: 5,
              openRate: 68,
              responseRate: 32,
            ),
          ],
        ),
        delivery: AnalyticsDeliverySnapshot(
          totalSent: 120,
          totalFailed: 3,
          totalPending: 5,
          deliveryRate: 94,
          byChannel: {
            'whatsapp': DeliveryChannelStats(sent: 80, failed: 2, pending: 2),
            'in_app': DeliveryChannelStats(sent: 40, failed: 1, pending: 3),
          },
          last7DaysSent: 45,
          last7DaysFailed: 2,
          trend: [
            AnalyticsDeliveryTrendPoint(date: '2026-06-04', sent: 8, failed: 0),
            AnalyticsDeliveryTrendPoint(
                date: '2026-06-05', sent: 12, failed: 1),
          ],
        ),
        effectiveness: CommunicationEffectiveness(
          effectivenessScore: 72,
          openRate: 62,
          responseRate: 28,
          topTemplates: [
            TemplateEffectiveness(
                templateCode: 'attendance_alert', sent: 80, openRate: 70),
          ],
          channelEffectiveness: {
            'whatsapp':
                ChannelEffectiveness(sent: 80, openRate: 68, responseRate: 30),
            'in_app':
                ChannelEffectiveness(sent: 40, openRate: 50, responseRate: 22),
          },
        ),
        parentEngagement: ParentEngagementAnalytics(
          averageEngagementScore: 64,
          activeParents30d: 90,
          lowEngagementParents: 18,
          topEngagedParents: [
            ParentEngagementEntry(
              parentUserId: 'parent_1',
              engagementScore: 88,
              messagesRead30d: 14,
              appSessions30d: 9,
              lastActiveAt: '2026-06-10',
            ),
          ],
          engagementTrend: [
            EngagementTrendPoint(period: 'week_1', score: 56),
            EngagementTrendPoint(period: 'week_4', score: 67),
          ],
        ),
        parentAdoption: ParentAdoptionAnalytics(
          totalParents: 150,
          activeParents: 90,
          pendingParents: 60,
          adoptionRate: 60,
          newActivations30d: 12,
          adoptionByGrade: [
            ParentAdoptionByGrade(
                gradeLabel: 'Grade 7', total: 50, active: 35, rate: 70),
            ParentAdoptionByGrade(
                gradeLabel: 'Grade 8', total: 50, active: 28, rate: 56),
          ],
        ),
      );

  @override
  Future<PilotActivationStats> getParentActivationDashboard({
    required RepositoryQuery query,
  }) async =>
      const PilotActivationStats(
        total: 500,
        active: 412,
        pending: 88,
        activationRate: 82,
        adoptionRate: 68,
        dailyActiveParents: 156,
        monthlyActiveParents: 389,
      );

  @override
  Future<RoomAllocationResult> allocateRooms({
    required RepositoryQuery query,
    required String academicYearId,
  }) async =>
      const RoomAllocationResult(
        allocatedPeriods: 120,
        labAssignments: 24,
        conflictsResolved: 3,
      );
}
