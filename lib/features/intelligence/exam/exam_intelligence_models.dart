class ExamAnalytics {
  const ExamAnalytics({
    required this.totalExams,
    required this.studentsAssessed,
    required this.averageScorePercent,
    required this.passRatePercent,
    required this.topPerformers,
    required this.classBreakdown,
    required this.insights,
  });

  final int totalExams;
  final int studentsAssessed;
  final int averageScorePercent;
  final int passRatePercent;
  final List<Map<String, dynamic>> topPerformers;
  final List<Map<String, dynamic>> classBreakdown;
  final List<String> insights;
}

class SubjectPerformanceItem {
  const SubjectPerformanceItem({
    required this.subjectName,
    required this.avgPercent,
    required this.studentCount,
    required this.passRate,
    required this.trend,
  });

  final String subjectName;
  final int avgPercent;
  final int studentCount;
  final int passRate;
  final String trend;
}

class WeakChapterItem {
  const WeakChapterItem({
    required this.chapter,
    required this.subjectName,
    required this.avgPercent,
    required this.studentCount,
    required this.recommendation,
  });

  final String chapter;
  final String subjectName;
  final int avgPercent;
  final int studentCount;
  final String recommendation;
}

class ResultIntelligence {
  const ResultIntelligence({
    required this.passCount,
    required this.failCount,
    required this.distinctionCount,
    required this.gradeDistribution,
    required this.classRankings,
    required this.insights,
  });

  final int passCount;
  final int failCount;
  final int distinctionCount;
  final List<Map<String, dynamic>> gradeDistribution;
  final List<Map<String, dynamic>> classRankings;
  final List<String> insights;
}

class AcademicForecast {
  const AcademicForecast({
    required this.forecastPeriod,
    required this.predictedAvgPercent,
    required this.atRiskStudentCount,
    required this.improvingStudentCount,
    required this.subjectForecasts,
    required this.recommendations,
  });

  final String forecastPeriod;
  final int predictedAvgPercent;
  final int atRiskStudentCount;
  final int improvingStudentCount;
  final List<Map<String, dynamic>> subjectForecasts;
  final List<String> recommendations;
}

class RankMovementItem {
  const RankMovementItem({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.previousRank,
    required this.currentRank,
    required this.movement,
    required this.direction,
  });

  final String studentId;
  final String studentName;
  final String className;
  final int previousRank;
  final int currentRank;
  final int movement;
  final String direction;
}
