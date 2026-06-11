abstract final class IntelligenceApiPaths {
  static const String studentRisks = '/intelligence/risk/students';
  static const String studentRisksCompute = '/intelligence/risk/students/compute';
  static const String classRisks = '/intelligence/risk/classes';
  static const String communicationGenerate = '/intelligence/communication/generate';
  static const String parentGuidanceGenerate = '/intelligence/parent-guidance/generate';
  static const String teacherSuccessCenter = '/intelligence/teacher/success-center';
  static const String principalCenter = '/intelligence/principal/center';
  static const String principalQuery = '/intelligence/principal/query';
  static const String studentSuccessDashboard = '/intelligence/student-success/dashboard';
  static const String studentSuccessPredictions = '/intelligence/student-success/predictions';
  static const String studentSuccessCompute = '/intelligence/student-success/compute';
  static const String studentSuccessImprovements = '/intelligence/student-success/improvements';
  static const String studentSuccessInterventions = '/intelligence/student-success/interventions';
  static String studentSuccessStudent(String studentId) =>
      '/intelligence/student-success/students/$studentId';
  static const String examAnalytics = '/intelligence/exam/analytics';
  static const String examSubjectPerformance = '/intelligence/exam/subject-performance';
  static const String examWeakChapters = '/intelligence/exam/weak-chapters';
  static const String examResultIntelligence = '/intelligence/exam/result-intelligence';
  static const String examForecast = '/intelligence/exam/forecast';
  static const String examRankMovement = '/intelligence/exam/rank-movement';
  static const String teacherEffectivenessLessonScores =
      '/intelligence/teacher-effectiveness/lesson-scores';
  static const String teacherEffectivenessTopicMastery =
      '/intelligence/teacher-effectiveness/topic-mastery';
  static const String teacherEffectivenessPerformance =
      '/intelligence/teacher-effectiveness/performance';
  static const String teacherEffectivenessPlanningCenter =
      '/intelligence/teacher-effectiveness/planning-center';
  static const String teacherEffectivenessParentMeetingSummary =
      '/intelligence/teacher-effectiveness/parent-meeting-summary';
}
