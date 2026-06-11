class HomeworkIntelligencePlan {
  const HomeworkIntelligencePlan({
    required this.className,
    required this.subjectName,
    required this.examType,
    required this.weakTopics,
    required this.riskStudents,
    required this.revisionSuggestions,
    required this.worksheetSuggestions,
    required this.recommendedHomework,
    required this.recommendedQuestionPapers,
    required this.classRecommendations,
    required this.studentRecommendations,
    required this.revisionPlans,
    required this.interventionPlans,
  });

  final String className;
  final String subjectName;
  final String examType;
  final List<Map<String, dynamic>> weakTopics;
  final List<Map<String, dynamic>> riskStudents;
  final List<String> revisionSuggestions;
  final List<Map<String, dynamic>> worksheetSuggestions;
  final List<Map<String, dynamic>> recommendedHomework;
  final List<Map<String, dynamic>> recommendedQuestionPapers;
  final List<String> classRecommendations;
  final List<Map<String, dynamic>> studentRecommendations;
  final List<Map<String, dynamic>> revisionPlans;
  final List<Map<String, dynamic>> interventionPlans;
}
