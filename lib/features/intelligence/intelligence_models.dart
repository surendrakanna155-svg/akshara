enum StudentRiskLevel { low, medium, high, critical }

enum CommunicationScenario {
  absent,
  homeworkMissing,
  lowAttendance,
  parentMeeting,
  behaviorIssue,
  appreciation,
  feeReminder,
  examReminder,
}

enum GuidanceMode { weekly, monthly, examReview }

enum IntelLanguage {
  english,
  telugu,
  hindi,
  tamil,
  kannada,
  malayalam,
  bengali,
  marathi,
}

class StudentRiskSnapshot {
  const StudentRiskSnapshot({
    required this.id,
    required this.studentId,
    this.studentName,
    required this.className,
    this.sectionName,
    required this.riskScore,
    required this.riskLevel,
    required this.reasons,
    required this.interventions,
    required this.teacherActions,
    required this.parentNotifications,
  });

  final String id;
  final String studentId;
  final String? studentName;
  final String className;
  final String? sectionName;
  final int riskScore;
  final StudentRiskLevel riskLevel;
  final List<Map<String, dynamic>> reasons;
  final List<Map<String, dynamic>> interventions;
  final List<String> teacherActions;
  final List<String> parentNotifications;
}

class ClassRiskSummary {
  const ClassRiskSummary({
    required this.className,
    required this.studentCount,
    required this.averageRiskScore,
    required this.criticalCount,
    required this.highCount,
    required this.mediumCount,
    required this.lowCount,
  });

  final String className;
  final int studentCount;
  final int averageRiskScore;
  final int criticalCount;
  final int highCount;
  final int mediumCount;
  final int lowCount;
}

class CommunicationChannelDraft {
  const CommunicationChannelDraft({
    required this.whatsapp,
    required this.sms,
    required this.email,
  });

  final String whatsapp;
  final String sms;
  final String email;
}

class CommunicationDraft {
  const CommunicationDraft({
    required this.language,
    required this.professional,
    required this.parentFriendly,
    required this.channels,
  });

  final IntelLanguage language;
  final String professional;
  final String parentFriendly;
  final CommunicationChannelDraft channels;
}

class ParentGuidanceReport {
  const ParentGuidanceReport({
    required this.progressSummary,
    required this.strengths,
    required this.concerns,
    required this.studyRecommendations,
    required this.nextStepGuidance,
    this.id,
    this.status = 'draft',
    this.printable = true,
  });

  final String progressSummary;
  final List<String> strengths;
  final List<String> concerns;
  final List<String> studyRecommendations;
  final List<String> nextStepGuidance;
  final String? id;
  final String status;
  final bool printable;
}

class TeacherDailyAction {
  const TeacherDailyAction({
    required this.priority,
    required this.action,
    required this.category,
  });

  final String priority;
  final String action;
  final String category;
}

class TeacherSuccessCenter {
  const TeacherSuccessCenter({
    required this.studentsNeedingAttention,
    required this.riskStudents,
    required this.homeworkGaps,
    required this.attendanceConcerns,
    required this.pendingParentCommunication,
    required this.weakStudents,
    required this.improvingStudents,
    required this.highPerformers,
    required this.suggestedActions,
    this.dailyActionPlan = const [],
  });

  final List<Map<String, dynamic>> studentsNeedingAttention;
  final int riskStudents;
  final int homeworkGaps;
  final int attendanceConcerns;
  final int pendingParentCommunication;
  final List<String> weakStudents;
  final List<String> improvingStudents;
  final List<String> highPerformers;
  final List<Map<String, dynamic>> suggestedActions;
  final List<TeacherDailyAction> dailyActionPlan;
}

class PrincipalExecutiveDashboard {
  const PrincipalExecutiveDashboard({
    required this.schoolHealthScore,
    required this.studentsAtRisk,
    required this.criticalRiskCount,
    required this.overloadedTeachers,
    required this.attendanceTrend,
    required this.feeCollectionTrend,
    required this.communicationEffectiveness,
    required this.classPerformanceTrend,
  });

  final int schoolHealthScore;
  final int studentsAtRisk;
  final int criticalRiskCount;
  final int overloadedTeachers;
  final String attendanceTrend;
  final String feeCollectionTrend;
  final String communicationEffectiveness;
  final String classPerformanceTrend;
}

class PrincipalQueryResult {
  const PrincipalQueryResult({
    required this.query,
    required this.intent,
    required this.summary,
    required this.count,
    required this.items,
  });

  final String query;
  final String intent;
  final String summary;
  final int count;
  final List<Map<String, dynamic>> items;
}

class PrincipalIntelligenceCenter {
  const PrincipalIntelligenceCenter({
    required this.schoolHealthScore,
    required this.studentsAtRisk,
    required this.criticalRiskCount,
    required this.insights,
    required this.interventions,
    required this.classSummaries,
    required this.monthlySummary,
    required this.quarterlySummary,
    this.executiveDashboard,
    this.feeCollectionSummary,
    this.attendanceSummary,
    this.academicPerformanceSummary,
  });

  final int schoolHealthScore;
  final int studentsAtRisk;
  final int criticalRiskCount;
  final List<String> insights;
  final List<String> interventions;
  final List<ClassRiskSummary> classSummaries;
  final String monthlySummary;
  final String quarterlySummary;
  final PrincipalExecutiveDashboard? executiveDashboard;
  final String? feeCollectionSummary;
  final String? attendanceSummary;
  final String? academicPerformanceSummary;
}
