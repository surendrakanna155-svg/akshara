class StudentSuccessSnapshot {
  const StudentSuccessSnapshot({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    this.sectionName,
    required this.dropoutProbability,
    required this.attendancePrediction,
    required this.performanceDeclineScore,
    required this.improvementScore,
    required this.riskSignals,
    required this.predictions,
    this.computedAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final String? sectionName;
  final int dropoutProbability;
  final int attendancePrediction;
  final int performanceDeclineScore;
  final int improvementScore;
  final List<Map<String, dynamic>> riskSignals;
  final Map<String, dynamic> predictions;
  final String? computedAt;
}

class StudentSuccessDashboard {
  const StudentSuccessDashboard({
    required this.studentsAnalyzed,
    required this.highDropoutRiskCount,
    required this.attendanceRiskCount,
    required this.performanceDeclineCount,
    required this.improvingStudentsCount,
    required this.averageImprovementScore,
    required this.topRiskStudents,
    required this.insights,
  });

  final int studentsAnalyzed;
  final int highDropoutRiskCount;
  final int attendanceRiskCount;
  final int performanceDeclineCount;
  final int improvingStudentsCount;
  final int averageImprovementScore;
  final List<Map<String, dynamic>> topRiskStudents;
  final List<String> insights;
}

class StudentImprovementItem {
  const StudentImprovementItem({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.improvementScore,
    required this.trend,
    this.previousImprovementScore,
    required this.highlights,
  });

  final String studentId;
  final String studentName;
  final String className;
  final int improvementScore;
  final String trend;
  final int? previousImprovementScore;
  final List<String> highlights;
}

class InterventionEffectivenessItem {
  const InterventionEffectivenessItem({
    required this.id,
    required this.studentId,
    required this.interventionType,
    required this.interventionLabel,
    required this.status,
    this.effectivenessScore,
    this.outcome,
    required this.startedAt,
  });

  final String id;
  final String studentId;
  final String interventionType;
  final String interventionLabel;
  final String status;
  final int? effectivenessScore;
  final String? outcome;
  final String startedAt;
}
