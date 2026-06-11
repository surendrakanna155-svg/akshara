import '../../../../../features/intelligence/exam/exam_intelligence_models.dart';
import '../../../../../features/intelligence/intelligence_models.dart';
import '../../../../../features/intelligence/student_success/student_success_models.dart';

class IntelligenceMapper {
  static StudentRiskLevel riskLevelFromApi(String value) => switch (value) {
        'critical' => StudentRiskLevel.critical,
        'high' => StudentRiskLevel.high,
        'medium' => StudentRiskLevel.medium,
        _ => StudentRiskLevel.low,
      };

  static String scenarioToApi(CommunicationScenario s) => switch (s) {
        CommunicationScenario.homeworkMissing => 'homework_missing',
        CommunicationScenario.lowAttendance => 'low_attendance',
        CommunicationScenario.parentMeeting => 'parent_meeting',
        CommunicationScenario.behaviorIssue => 'behavior_issue',
        CommunicationScenario.feeReminder => 'fee_reminder',
        CommunicationScenario.examReminder => 'exam_reminder',
        CommunicationScenario.appreciation => 'appreciation',
        CommunicationScenario.absent => 'absent',
      };

  static String modeToApi(GuidanceMode m) => switch (m) {
        GuidanceMode.examReview => 'exam_review',
        GuidanceMode.monthly => 'monthly',
        GuidanceMode.weekly => 'weekly',
      };

  static String languageToApi(IntelLanguage l) => l.name;

  static StudentRiskSnapshot riskFromApi(Map<String, dynamic> json) {
    return StudentRiskSnapshot(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      studentName: json['studentName'] as String?,
      className: json['className'] as String? ?? '',
      sectionName: json['sectionName'] as String?,
      riskScore: (json['riskScore'] as num).toInt(),
      riskLevel: riskLevelFromApi(json['riskLevel'] as String? ?? 'low'),
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      interventions: (json['interventions'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      teacherActions: (json['teacherActions'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      parentNotifications: (json['parentNotifications'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  static ClassRiskSummary classRiskFromApi(Map<String, dynamic> json) {
    return ClassRiskSummary(
      className: json['className'] as String,
      studentCount: (json['studentCount'] as num).toInt(),
      averageRiskScore: (json['averageRiskScore'] as num).toInt(),
      criticalCount: (json['criticalCount'] as num).toInt(),
      highCount: (json['highCount'] as num).toInt(),
      mediumCount: (json['mediumCount'] as num).toInt(),
      lowCount: (json['lowCount'] as num).toInt(),
    );
  }

  static CommunicationDraft draftFromApi(Map<String, dynamic> json) {
    final channels = json['channels'] as Map? ?? {};
    return CommunicationDraft(
      language: IntelLanguage.values.firstWhere(
        (l) => l.name == json['language'],
        orElse: () => IntelLanguage.english,
      ),
      professional: json['professional'] as String? ?? '',
      parentFriendly: json['parentFriendly'] as String? ?? '',
      channels: CommunicationChannelDraft(
        whatsapp: channels['whatsapp'] as String? ?? '',
        sms: channels['sms'] as String? ?? '',
        email: channels['email'] as String? ?? '',
      ),
    );
  }

  static ParentGuidanceReport guidanceFromApi(Map<String, dynamic> json) {
    final report = json['report'] as Map? ?? json;
    return ParentGuidanceReport(
      progressSummary: report['progressSummary'] as String? ?? '',
      strengths: (report['strengths'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      concerns: (report['concerns'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      studyRecommendations: (report['studyRecommendations'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      nextStepGuidance: (report['nextStepGuidance'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      id: json['id'] as String?,
      status: json['status'] as String? ?? 'draft',
      printable: json['printable'] as bool? ?? true,
    );
  }

  static PrincipalQueryResult principalQueryFromApi(Map<String, dynamic> json) {
    return PrincipalQueryResult(
      query: json['query'] as String? ?? '',
      intent: json['intent'] as String? ?? 'unknown',
      summary: json['summary'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  static TeacherDailyAction dailyActionFromApi(Map<String, dynamic> json) {
    return TeacherDailyAction(
      priority: json['priority'] as String? ?? 'medium',
      action: json['action'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
    );
  }

  static TeacherSuccessCenter teacherCenterFromApi(Map<String, dynamic> json) {
    return TeacherSuccessCenter(
      studentsNeedingAttention:
          (json['studentsNeedingAttention'] as List<dynamic>? ?? const [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList(),
      riskStudents: (json['riskStudents'] as num?)?.toInt() ?? 0,
      homeworkGaps: (json['homeworkGaps'] as num?)?.toInt() ?? 0,
      attendanceConcerns: (json['attendanceConcerns'] as num?)?.toInt() ?? 0,
      pendingParentCommunication:
          (json['pendingParentCommunication'] as num?)?.toInt() ?? 0,
      weakStudents: (json['insights']?['weakStudents'] as List<dynamic>? ??
              json['weakStudents'] as List<dynamic>? ??
              const [])
          .map((e) => e.toString())
          .toList(),
      improvingStudents:
          (json['insights']?['improvingStudents'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
      highPerformers: (json['insights']?['highPerformers'] as List<dynamic>? ??
              json['highPerformers'] as List<dynamic>? ??
              const [])
          .map((e) => e.toString())
          .toList(),
      suggestedActions: (json['suggestedActions'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      dailyActionPlan: (json['dailyActionPlan'] as List<dynamic>? ?? const [])
          .map((e) => dailyActionFromApi(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  static PrincipalExecutiveDashboard executiveFromApi(Map<String, dynamic> dash) {
    return PrincipalExecutiveDashboard(
      schoolHealthScore: (dash['schoolHealthScore'] as num?)?.toInt() ?? 0,
      studentsAtRisk: (dash['studentsAtRisk'] as num?)?.toInt() ?? 0,
      criticalRiskCount: (dash['criticalRiskCount'] as num?)?.toInt() ?? 0,
      overloadedTeachers: (dash['overloadedTeachers'] as num?)?.toInt() ?? 0,
      attendanceTrend: dash['attendanceTrend'] as String? ?? 'stable',
      feeCollectionTrend: dash['feeCollectionTrend'] as String? ?? 'on track',
      communicationEffectiveness:
          dash['communicationEffectiveness'] as String? ?? 'effective',
      classPerformanceTrend: dash['classPerformanceTrend'] as String? ?? 'positive',
    );
  }

  static PrincipalIntelligenceCenter principalFromApi(Map<String, dynamic> json) {
    final dash = json['executiveDashboard'] as Map? ?? json;
    final executive = executiveFromApi(Map<String, dynamic>.from(dash));
    final insights = (json['schoolHealthInsights'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    return PrincipalIntelligenceCenter(
      schoolHealthScore: executive.schoolHealthScore,
      studentsAtRisk: executive.studentsAtRisk,
      criticalRiskCount: executive.criticalRiskCount,
      insights: insights,
      interventions: (json['interventionRecommendations'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      classSummaries: (json['classRiskSummaries'] as List<dynamic>? ?? const [])
          .map((e) => classRiskFromApi(Map<String, dynamic>.from(e as Map)))
          .toList(),
      monthlySummary: json['exportReady']?['monthlySummary'] as String? ?? '',
      quarterlySummary: json['exportReady']?['quarterlySummary'] as String? ?? '',
      executiveDashboard: executive,
      feeCollectionSummary: insights
          .where((i) => i.toLowerCase().contains('fee'))
          .firstOrNull,
      attendanceSummary: insights
          .where((i) => i.toLowerCase().contains('attendance') || i.toLowerCase().contains('health'))
          .firstOrNull,
      academicPerformanceSummary: executive.classPerformanceTrend == 'positive'
          ? 'Class performance trend is positive'
          : 'Class performance needs attention',
    );
  }

  static StudentSuccessSnapshot studentSuccessFromApi(Map<String, dynamic> json) {
    return StudentSuccessSnapshot(
      id: json['id'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      className: json['className'] as String? ?? '',
      sectionName: json['sectionName'] as String?,
      dropoutProbability: (json['dropoutProbability'] as num?)?.toInt() ?? 0,
      attendancePrediction: (json['attendancePrediction'] as num?)?.toInt() ?? 0,
      performanceDeclineScore: (json['performanceDeclineScore'] as num?)?.toInt() ?? 0,
      improvementScore: (json['improvementScore'] as num?)?.toInt() ?? 0,
      riskSignals: (json['riskSignals'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      predictions: Map<String, dynamic>.from(json['predictions'] as Map? ?? const {}),
      computedAt: json['computedAt'] as String?,
    );
  }

  static StudentSuccessDashboard studentSuccessDashboardFromApi(Map<String, dynamic> json) {
    final dash = json['dashboard'] as Map? ?? json;
    return StudentSuccessDashboard(
      studentsAnalyzed: (dash['studentsAnalyzed'] as num?)?.toInt() ?? 0,
      highDropoutRiskCount: (dash['highDropoutRiskCount'] as num?)?.toInt() ?? 0,
      attendanceRiskCount: (dash['attendanceRiskCount'] as num?)?.toInt() ?? 0,
      performanceDeclineCount: (dash['performanceDeclineCount'] as num?)?.toInt() ?? 0,
      improvingStudentsCount: (dash['improvingStudentsCount'] as num?)?.toInt() ?? 0,
      averageImprovementScore: (dash['averageImprovementScore'] as num?)?.toInt() ?? 0,
      topRiskStudents: (dash['topRiskStudents'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      insights: (dash['insights'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  static StudentImprovementItem improvementFromApi(Map<String, dynamic> json) {
    return StudentImprovementItem(
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      className: json['className'] as String? ?? '',
      improvementScore: (json['improvementScore'] as num?)?.toInt() ?? 0,
      trend: json['trend'] as String? ?? 'stable',
      previousImprovementScore: (json['previousImprovementScore'] as num?)?.toInt(),
      highlights: (json['highlights'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  static InterventionEffectivenessItem interventionFromApi(Map<String, dynamic> json) {
    return InterventionEffectivenessItem(
      id: json['id'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      interventionType: json['interventionType'] as String? ?? '',
      interventionLabel: json['interventionLabel'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      effectivenessScore: (json['effectivenessScore'] as num?)?.toInt(),
      outcome: json['outcome'] as String?,
      startedAt: json['startedAt'] as String? ?? '',
    );
  }

  static ExamAnalytics examAnalyticsFromApi(Map<String, dynamic> json) {
    final analytics = json['analytics'] as Map? ?? json;
    return ExamAnalytics(
      totalExams: (analytics['totalExams'] as num?)?.toInt() ?? 0,
      studentsAssessed: (analytics['studentsAssessed'] as num?)?.toInt() ?? 0,
      averageScorePercent: (analytics['averageScorePercent'] as num?)?.toInt() ?? 0,
      passRatePercent: (analytics['passRatePercent'] as num?)?.toInt() ?? 0,
      topPerformers: (analytics['topPerformers'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      classBreakdown: (analytics['classBreakdown'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      insights: (analytics['insights'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  static SubjectPerformanceItem subjectPerformanceFromApi(Map<String, dynamic> json) {
    return SubjectPerformanceItem(
      subjectName: json['subjectName'] as String? ?? '',
      avgPercent: (json['avgPercent'] as num?)?.toInt() ?? 0,
      studentCount: (json['studentCount'] as num?)?.toInt() ?? 0,
      passRate: (json['passRate'] as num?)?.toInt() ?? 0,
      trend: json['trend'] as String? ?? 'stable',
    );
  }

  static WeakChapterItem weakChapterFromApi(Map<String, dynamic> json) {
    return WeakChapterItem(
      chapter: json['chapter'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      avgPercent: (json['avgPercent'] as num?)?.toInt() ?? 0,
      studentCount: (json['studentCount'] as num?)?.toInt() ?? 0,
      recommendation: json['recommendation'] as String? ?? '',
    );
  }

  static ResultIntelligence resultIntelligenceFromApi(Map<String, dynamic> json) {
    final result = json['result'] as Map? ?? json;
    return ResultIntelligence(
      passCount: (result['passCount'] as num?)?.toInt() ?? 0,
      failCount: (result['failCount'] as num?)?.toInt() ?? 0,
      distinctionCount: (result['distinctionCount'] as num?)?.toInt() ?? 0,
      gradeDistribution: (result['gradeDistribution'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      classRankings: (result['classRankings'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      insights: (result['insights'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  static AcademicForecast academicForecastFromApi(Map<String, dynamic> json) {
    final forecast = json['forecast'] as Map? ?? json;
    return AcademicForecast(
      forecastPeriod: forecast['forecastPeriod'] as String? ?? 'next_term',
      predictedAvgPercent: (forecast['predictedAvgPercent'] as num?)?.toInt() ?? 0,
      atRiskStudentCount: (forecast['atRiskStudentCount'] as num?)?.toInt() ?? 0,
      improvingStudentCount: (forecast['improvingStudentCount'] as num?)?.toInt() ?? 0,
      subjectForecasts: (forecast['subjectForecasts'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      recommendations: (forecast['recommendations'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  static RankMovementItem rankMovementFromApi(Map<String, dynamic> json) {
    return RankMovementItem(
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      className: json['className'] as String? ?? '',
      previousRank: (json['previousRank'] as num?)?.toInt() ?? 0,
      currentRank: (json['currentRank'] as num?)?.toInt() ?? 0,
      movement: (json['movement'] as num?)?.toInt() ?? 0,
      direction: json['direction'] as String? ?? 'stable',
    );
  }
}
