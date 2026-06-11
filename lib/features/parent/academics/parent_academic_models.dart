class ParentAcademicSummary {
  const ParentAcademicSummary({
    required this.studentId,
    required this.attendanceSummary,
    required this.performanceSummary,
    required this.strengths,
    required this.weaknesses,
    required this.homeworkStatus,
    required this.examReadiness,
    required this.teacherRecommendations,
    required this.generatedAt,
  });

  final String studentId;
  final Map<String, dynamic> attendanceSummary;
  final Map<String, dynamic> performanceSummary;
  final List<String> strengths;
  final List<String> weaknesses;
  final Map<String, dynamic> homeworkStatus;
  final Map<String, dynamic> examReadiness;
  final List<String> teacherRecommendations;
  final String generatedAt;
}
