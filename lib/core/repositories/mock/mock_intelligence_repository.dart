import '../../../features/intelligence/exam/exam_intelligence_models.dart';
import '../../../features/intelligence/intelligence_models.dart';
import '../../../features/intelligence/student_success/student_success_models.dart';
import '../../../features/intelligence/teacher_effectiveness/teacher_effectiveness_models.dart';
import '../interfaces/intelligence_repository.dart';
import '../repository_query.dart';

class MockIntelligenceRepository implements IntelligenceRepository {
  final List<StudentRiskSnapshot> _risks = [
    const StudentRiskSnapshot(
      id: 'risk_1',
      studentId: 'student_1',
      studentName: 'Arjun Reddy',
      className: 'Grade 8',
      sectionName: 'A',
      riskScore: 78,
      riskLevel: StudentRiskLevel.high,
      reasons: [
        {'code': 'low_attendance', 'label': 'Low attendance', 'detail': 'Attendance is 62%'},
      ],
      interventions: [
        {'action': 'Schedule parent call', 'owner': 'teacher', 'priority': 'high'},
      ],
      teacherActions: ['Schedule parent call within 48 hours'],
      parentNotifications: ['Recommend attendance improvement notice'],
    ),
    const StudentRiskSnapshot(
      id: 'risk_2',
      studentId: 'student_2',
      studentName: 'Priya Sharma',
      className: 'Grade 8',
      sectionName: 'A',
      riskScore: 35,
      riskLevel: StudentRiskLevel.low,
      reasons: [
        {'code': 'stable', 'label': 'Stable profile', 'detail': 'No significant risk signals'},
      ],
      interventions: [],
      teacherActions: [],
      parentNotifications: [],
    ),
  ];

  @override
  Future<List<StudentRiskSnapshot>> listStudentRisks({
    required RepositoryQuery query,
    String? className,
    StudentRiskLevel? riskLevel,
  }) async {
    return _risks.where((r) {
      if (className != null && !r.className.contains(className)) return false;
      if (riskLevel != null && r.riskLevel != riskLevel) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<StudentRiskSnapshot>> computeStudentRisks({
    required RepositoryQuery query,
    String? academicYearLabel,
  }) async {
    return List<StudentRiskSnapshot>.from(_risks);
  }

  @override
  Future<List<ClassRiskSummary>> listClassRisks({
    required RepositoryQuery query,
  }) async {
    return const [
      ClassRiskSummary(
        className: 'Grade 8',
        studentCount: 2,
        averageRiskScore: 56,
        criticalCount: 0,
        highCount: 1,
        mediumCount: 0,
        lowCount: 1,
      ),
    ];
  }

  @override
  Future<List<CommunicationDraft>> generateCommunication({
    required RepositoryQuery query,
    required CommunicationScenario scenario,
    String? studentName,
    String? className,
    String? customNote,
    List<IntelLanguage> languages = const [IntelLanguage.english],
    IntelLanguage? parentPreferredLanguage,
    String? feeAmount,
    String? dueDate,
    String? examName,
    String? meetingDate,
  }) async {
    final langs = parentPreferredLanguage != null && parentPreferredLanguage != IntelLanguage.english
        ? [parentPreferredLanguage, ...languages.where((l) => l != parentPreferredLanguage)]
        : languages;
    final feeNote = feeAmount != null ? ' Amount: ₹$feeAmount${dueDate != null ? " due $dueDate" : ""}.' : '';
    final examNote = examName != null ? ' Exam: $examName.' : '';
    return langs
        .map(
          (lang) => CommunicationDraft(
            language: lang,
            professional:
                'Professional ${scenario.name} message for ${studentName ?? "student"}.$feeNote$examNote',
            parentFriendly: 'Dear Parent, update regarding ${studentName ?? "your child"}.',
            channels: CommunicationChannelDraft(
              whatsapp: 'Dear Parent, ${scenario.name} update.',
              sms: '${scenario.name} update - ${className ?? "school"}',
              email: 'Subject: School update\n\nProfessional message.',
            ),
          ),
        )
        .toList();
  }

  @override
  Future<ParentGuidanceReport> generateParentGuidance({
    required RepositoryQuery query,
    required String studentId,
    required GuidanceMode mode,
    IntelLanguage language = IntelLanguage.english,
    Map<String, dynamic> inputs = const {},
    bool publish = true,
    bool autoFillFromRisk = true,
  }) async {
    final risk = _risks.where((r) => r.studentId == studentId).firstOrNull;
    final attendance = inputs['attendancePercent'] as int? ??
        (risk != null ? 62 : 85);
    return ParentGuidanceReport(
      id: 'guidance_${studentId}_${mode.name}',
      status: publish ? 'published' : 'draft',
      progressSummary:
          '${mode.name} summary for ${inputs['studentName'] ?? studentId} ($language): attendance $attendance%.',
      strengths: const ['Participation: consistent effort visible in class activities'],
      concerns: const ['Time management: targeted practice recommended'],
      studyRecommendations: const ['30 min daily revision', 'Print this report for PTM reference'],
      nextStepGuidance: const ['Maintain attendance above 85%'],
    );
  }

  @override
  Future<PrincipalQueryResult> queryPrincipal({
    required RepositoryQuery query,
    required String queryText,
  }) async {
    final q = queryText.toLowerCase();
    if (q.contains('attendance')) {
      return PrincipalQueryResult(
        query: queryText,
        intent: 'low_attendance',
        summary: '1 student below 75% attendance',
        count: 1,
        items: const [
          {
            'studentId': 'student_1',
            'studentName': 'Arjun Reddy',
            'className': 'Grade 8',
            'attendancePercent': 62,
          },
        ],
      );
    }
    if (q.contains('risk')) {
      return PrincipalQueryResult(
        query: queryText,
        intent: 'high_risk',
        summary: '1 high-risk student',
        count: 1,
        items: const [
          {
            'studentId': 'student_1',
            'studentName': 'Arjun Reddy',
            'riskLevel': 'high',
            'riskScore': 78,
          },
        ],
      );
    }
    return PrincipalQueryResult(
      query: queryText,
      intent: 'fee_defaulters',
      summary: '0 students with outstanding fee balance',
      count: 0,
      items: const [],
    );
  }

  @override
  Future<TeacherSuccessCenter> getTeacherSuccessCenter({
    required RepositoryQuery query,
  }) async {
    return const TeacherSuccessCenter(
      studentsNeedingAttention: [
        {
          'studentId': 'student_1',
          'studentName': 'Arjun Reddy',
          'className': 'Grade 8',
          'riskLevel': 'high',
          'riskScore': 78,
          'topReason': 'Low attendance',
        },
      ],
      riskStudents: 1,
      homeworkGaps: 1,
      attendanceConcerns: 1,
      pendingParentCommunication: 1,
      weakStudents: ['Arjun Reddy'],
      improvingStudents: [],
      highPerformers: ['Priya Sharma'],
      suggestedActions: [
        {
          'action': 'Send parent communication for Arjun Reddy',
          'target': 'student_1',
          'type': 'communicate_parent',
        },
      ],
      dailyActionPlan: [
        TeacherDailyAction(
          priority: 'high',
          action: 'Review attendance for 1 student below 75%',
          category: 'attendance',
        ),
        TeacherDailyAction(
          priority: 'medium',
          action: 'Send parent communication drafts today',
          category: 'communication',
        ),
      ],
    );
  }

  @override
  Future<PrincipalIntelligenceCenter> getPrincipalCenter({
    required RepositoryQuery query,
    String period = 'monthly',
  }) async {
    return PrincipalIntelligenceCenter(
      schoolHealthScore: 82,
      studentsAtRisk: 1,
      criticalRiskCount: 0,
      insights: const [
        'School health score is 82/100.',
        '1 student currently flagged above low risk.',
        'Fee collection risk score: 22.',
      ],
      interventions: const ['Review class risk dashboards weekly'],
      classSummaries: await listClassRisks(query: query),
      monthlySummary: 'Monthly Principal Intelligence Summary',
      quarterlySummary: 'Quarterly Principal Intelligence Summary',
      executiveDashboard: const PrincipalExecutiveDashboard(
        schoolHealthScore: 82,
        studentsAtRisk: 1,
        criticalRiskCount: 0,
        overloadedTeachers: 2,
        attendanceTrend: 'stable',
        feeCollectionTrend: 'on track',
        communicationEffectiveness: 'effective',
        classPerformanceTrend: 'positive',
      ),
      feeCollectionSummary: 'Fee collection risk score: 22.',
      attendanceSummary: 'School health score is 82/100.',
      academicPerformanceSummary: 'Class performance trend is positive',
    );
  }

  final List<StudentSuccessSnapshot> _studentSuccess = [
    const StudentSuccessSnapshot(
      id: 'ss_1',
      studentId: 'student_1',
      studentName: 'Arjun Reddy',
      className: 'Grade 8',
      sectionName: 'A',
      dropoutProbability: 72,
      attendancePrediction: 58,
      performanceDeclineScore: 65,
      improvementScore: 38,
      riskSignals: [
        {'code': 'dropout_risk', 'label': 'Elevated dropout risk', 'severity': 'high'},
        {'code': 'attendance_decline', 'label': 'Attendance below threshold', 'severity': 'high'},
      ],
      predictions: {
        'dropoutRisk': 'High — immediate intervention recommended',
        'attendanceOutlook': 'At risk of further decline',
        'performanceTrend': 'Declining — remedial support needed',
        'recommendedInterventions': [
          'Schedule counselor session within 7 days',
          'Parent attendance improvement plan',
        ],
      },
    ),
    const StudentSuccessSnapshot(
      id: 'ss_2',
      studentId: 'student_2',
      studentName: 'Priya Sharma',
      className: 'Grade 8',
      sectionName: 'A',
      dropoutProbability: 18,
      attendancePrediction: 91,
      performanceDeclineScore: 12,
      improvementScore: 82,
      riskSignals: [],
      predictions: {
        'dropoutRisk': 'Low — stable retention outlook',
        'attendanceOutlook': 'Expected to maintain healthy attendance',
        'performanceTrend': 'Stable or improving',
        'recommendedInterventions': ['Continue monitoring — student on track'],
      },
    ),
  ];

  @override
  Future<StudentSuccessDashboard> getStudentSuccessDashboard({
    required RepositoryQuery query,
  }) async {
    return StudentSuccessDashboard(
      studentsAnalyzed: _studentSuccess.length,
      highDropoutRiskCount: 1,
      attendanceRiskCount: 1,
      performanceDeclineCount: 1,
      improvingStudentsCount: 1,
      averageImprovementScore: 60,
      topRiskStudents: const [
        {
          'studentId': 'student_1',
          'studentName': 'Arjun Reddy',
          'className': 'Grade 8',
          'dropoutProbability': 72,
          'topSignal': 'Elevated dropout risk',
        },
      ],
      insights: const [
        '2 students analyzed for success intelligence.',
        '1 student flagged with elevated dropout risk.',
        '1 student showing improvement trajectory.',
      ],
    );
  }

  @override
  Future<List<StudentSuccessSnapshot>> listStudentSuccessPredictions({
    required RepositoryQuery query,
    String? className,
    int? minDropoutRisk,
  }) async {
    return _studentSuccess.where((s) {
      if (className != null && !s.className.contains(className)) return false;
      if (minDropoutRisk != null && s.dropoutProbability < minDropoutRisk) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<StudentSuccessSnapshot>> computeStudentSuccess({
    required RepositoryQuery query,
  }) async {
    return List<StudentSuccessSnapshot>.from(_studentSuccess);
  }

  @override
  Future<StudentSuccessSnapshot?> getStudentSuccess({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    return _studentSuccess.where((s) => s.studentId == studentId).firstOrNull;
  }

  @override
  Future<List<StudentImprovementItem>> listStudentImprovements({
    required RepositoryQuery query,
    String? className,
  }) async {
    return [
      const StudentImprovementItem(
        studentId: 'student_2',
        studentName: 'Priya Sharma',
        className: 'Grade 8',
        improvementScore: 82,
        trend: 'improving',
        highlights: ['Positive improvement trajectory', 'Attendance outlook is healthy'],
      ),
      const StudentImprovementItem(
        studentId: 'student_1',
        studentName: 'Arjun Reddy',
        className: 'Grade 8',
        improvementScore: 38,
        trend: 'declining',
        highlights: ['Requires targeted support plan'],
      ),
    ];
  }

  @override
  Future<List<InterventionEffectivenessItem>> listInterventionEffectiveness({
    required RepositoryQuery query,
    String? studentId,
  }) async {
    return [
      const InterventionEffectivenessItem(
        id: 'int_1',
        studentId: 'student_1',
        interventionType: 'academic_support',
        interventionLabel: 'Schedule counselor session within 7 days',
        status: 'active',
        effectivenessScore: 45,
        outcome: 'Under review',
        startedAt: '2026-06-01T00:00:00Z',
      ),
    ].where((i) => studentId == null || i.studentId == studentId).toList();
  }

  @override
  Future<ExamAnalytics> getExamAnalytics({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
    String? examType,
  }) async {
    return const ExamAnalytics(
      totalExams: 4,
      studentsAssessed: 28,
      averageScorePercent: 68,
      passRatePercent: 82,
      topPerformers: [
        {'studentId': 'student_2', 'studentName': 'Priya Sharma', 'avgPercent': 88},
        {'studentId': 'student_1', 'studentName': 'Arjun Reddy', 'avgPercent': 54},
      ],
      classBreakdown: [
        {'className': 'Grade 8', 'avgPercent': 68, 'studentCount': 28},
      ],
      insights: [
        '4 exams assessed across 28 students.',
        'School average: 68% with 82% pass rate.',
      ],
    );
  }

  @override
  Future<List<SubjectPerformanceItem>> getSubjectPerformance({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  }) async {
    return const [
      SubjectPerformanceItem(
        subjectName: 'Mathematics',
        avgPercent: 58,
        studentCount: 28,
        passRate: 75,
        trend: 'declining',
      ),
      SubjectPerformanceItem(
        subjectName: 'Science',
        avgPercent: 74,
        studentCount: 28,
        passRate: 89,
        trend: 'improving',
      ),
    ];
  }

  @override
  Future<List<WeakChapterItem>> getWeakChapters({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  }) async {
    return const [
      WeakChapterItem(
        chapter: 'Algebra',
        subjectName: 'Mathematics',
        avgPercent: 48,
        studentCount: 28,
        recommendation: 'Priority remedial — schedule revision classes',
      ),
      WeakChapterItem(
        chapter: 'Fractions',
        subjectName: 'Mathematics',
        avgPercent: 55,
        studentCount: 28,
        recommendation: 'Revision worksheets and targeted homework recommended',
      ),
    ];
  }

  @override
  Future<ResultIntelligence> getResultIntelligence({
    required RepositoryQuery query,
    String? className,
  }) async {
    return const ResultIntelligence(
      passCount: 46,
      failCount: 10,
      distinctionCount: 8,
      gradeDistribution: [
        {'grade': 'A', 'count': 8},
        {'grade': 'B', 'count': 18},
        {'grade': 'C', 'count': 20},
        {'grade': 'D', 'count': 10},
        {'grade': 'F', 'count': 10},
      ],
      classRankings: [
        {'className': 'Grade 8', 'avgPercent': 68, 'rank': 1},
      ],
      insights: ['46 passing results, 10 below pass threshold.', '8 distinction-level performances.'],
    );
  }

  @override
  Future<AcademicForecast> getAcademicForecast({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  }) async {
    return const AcademicForecast(
      forecastPeriod: 'next_term',
      predictedAvgPercent: 70,
      atRiskStudentCount: 5,
      improvingStudentCount: 12,
      subjectForecasts: [
        {'subjectName': 'Mathematics', 'predictedAvg': 54, 'confidence': 'high'},
        {'subjectName': 'Science', 'predictedAvg': 78, 'confidence': 'high'},
      ],
      recommendations: [
        'Focus remedial support on 1 underperforming subjects',
        'Replicate teaching strategies from improving subjects',
      ],
    );
  }

  @override
  Future<List<RankMovementItem>> getRankMovement({
    required RepositoryQuery query,
    String? className,
  }) async {
    return const [
      RankMovementItem(
        studentId: 'student_2',
        studentName: 'Priya Sharma',
        className: 'Grade 8',
        previousRank: 3,
        currentRank: 1,
        movement: 2,
        direction: 'up',
      ),
      RankMovementItem(
        studentId: 'student_1',
        studentName: 'Arjun Reddy',
        className: 'Grade 8',
        previousRank: 18,
        currentRank: 22,
        movement: 4,
        direction: 'down',
      ),
    ];
  }

  @override
  Future<List<LessonEffectivenessScore>> getLessonEffectivenessScores({
    required RepositoryQuery query,
    String? teacherUserId,
    String? className,
  }) async {
    return const [
      LessonEffectivenessScore(
        id: 'les_1',
        lessonLogId: 'log_1',
        className: 'Grade 8',
        subjectId: 'sub_1',
        topic: 'Fractions',
        effectivenessScore: 82,
        completionRate: 100,
        studentEngagementScore: 78,
        syllabusAlignmentScore: 90,
        recordedOn: '2026-06-10',
      ),
    ];
  }

  @override
  Future<List<TopicMasteryEntry>> getTopicMasteryAnalytics({
    required RepositoryQuery query,
    String? teacherUserId,
  }) async {
    return const [
      TopicMasteryEntry(
        className: 'Grade 8',
        subjectId: 'sub_1',
        topicName: 'Fractions',
        masteryPercent: 75,
        lessonsCompleted: 3,
        avgEffectivenessScore: 80,
      ),
      TopicMasteryEntry(
        className: 'Grade 8',
        subjectId: 'sub_1',
        topicName: 'Decimals',
        masteryPercent: 45,
        lessonsCompleted: 1,
        avgEffectivenessScore: 62,
      ),
    ];
  }

  @override
  Future<TeacherPerformanceInsights> getTeacherPerformanceInsights({
    required RepositoryQuery query,
    String? teacherUserId,
  }) async {
    return const TeacherPerformanceInsights(
      overallEffectivenessScore: 78,
      lessonsCompleted: 12,
      syllabusCoveragePercent: 68,
      avgStudentEngagement: 74,
      strengths: ['Strong syllabus coverage pace', 'High student engagement in recorded lessons'],
      improvementAreas: ['Align more lessons to syllabus topics'],
      recentHighlights: ['Fractions (Grade 8) — 82% effective'],
    );
  }

  @override
  Future<TeacherPlanningCenter> getTeacherPlanningCenter({
    required RepositoryQuery query,
    String? teacherUserId,
  }) async {
    return const TeacherPlanningCenter(
      weeklyFocus: 'Decimals',
      pendingTopics: ['Decimals', 'Percentages'],
      upcomingAssessments: ['Unit test — end of month'],
      planningItems: [
        TeacherPlanningItem(
          priority: 'high',
          category: 'syllabus',
          action: 'Complete pending topic: Decimals',
          dueHint: 'This week',
        ),
      ],
    );
  }

  @override
  Future<ParentMeetingSummary> generateParentMeetingSummary({
    required RepositoryQuery query,
    required String studentId,
    required String studentName,
    required String className,
    required String meetingDate,
    int? attendancePercent,
    int? recentMarks,
    int? homeworkCompletionRate,
    String? behaviorNotes,
    List<String> strengths = const [],
    List<String> concerns = const [],
    List<String> actionItems = const [],
  }) async {
    return ParentMeetingSummary(
      id: 'pms_1',
      studentId: studentId,
      studentName: studentName,
      className: className,
      meetingDate: meetingDate,
      printable: true,
      summary: ParentMeetingSummarySections(
        opening: 'Parent meeting for $studentName ($className) on $meetingDate.',
        academicProgress: recentMarks != null
            ? 'Recent assessment average: $recentMarks%.'
            : 'Academic progress reviewed.',
        attendance: attendancePercent != null ? 'Attendance: $attendancePercent%.' : 'Attendance discussed.',
        homework: homeworkCompletionRate != null
            ? 'Homework completion: $homeworkCompletionRate%.'
            : 'Homework habits reviewed.',
        behavior: behaviorNotes ?? 'Behavior discussed positively.',
        strengths: strengths.isNotEmpty ? strengths : const ['Shows willingness to improve'],
        concerns: concerns.isNotEmpty ? concerns : const ['Attendance below school benchmark'],
        actionItems: actionItems.isNotEmpty
            ? actionItems
            : const ['Maintain daily homework routine'],
        closing: 'Thank you for your partnership.',
      ),
    );
  }
}
