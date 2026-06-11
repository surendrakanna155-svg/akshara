import '../../../features/intelligence/exam/exam_intelligence_models.dart';
import '../../../features/intelligence/intelligence_models.dart';
import '../../../features/intelligence/student_success/student_success_models.dart';
import '../../../features/intelligence/teacher_effectiveness/teacher_effectiveness_models.dart';
import '../repository_query.dart';

abstract class IntelligenceRepository {
  Future<List<StudentRiskSnapshot>> listStudentRisks({
    required RepositoryQuery query,
    String? className,
    StudentRiskLevel? riskLevel,
  });

  Future<List<StudentRiskSnapshot>> computeStudentRisks({
    required RepositoryQuery query,
    String? academicYearLabel,
  });

  Future<List<ClassRiskSummary>> listClassRisks({
    required RepositoryQuery query,
  });

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
  });

  Future<ParentGuidanceReport> generateParentGuidance({
    required RepositoryQuery query,
    required String studentId,
    required GuidanceMode mode,
    IntelLanguage language = IntelLanguage.english,
    Map<String, dynamic> inputs = const {},
    bool publish = true,
    bool autoFillFromRisk = true,
  });

  Future<PrincipalQueryResult> queryPrincipal({
    required RepositoryQuery query,
    required String queryText,
  });

  Future<TeacherSuccessCenter> getTeacherSuccessCenter({
    required RepositoryQuery query,
  });

  Future<PrincipalIntelligenceCenter> getPrincipalCenter({
    required RepositoryQuery query,
    String period = 'monthly',
  });

  Future<StudentSuccessDashboard> getStudentSuccessDashboard({
    required RepositoryQuery query,
  });

  Future<List<StudentSuccessSnapshot>> listStudentSuccessPredictions({
    required RepositoryQuery query,
    String? className,
    int? minDropoutRisk,
  });

  Future<List<StudentSuccessSnapshot>> computeStudentSuccess({
    required RepositoryQuery query,
  });

  Future<StudentSuccessSnapshot?> getStudentSuccess({
    required RepositoryQuery query,
    required String studentId,
  });

  Future<List<StudentImprovementItem>> listStudentImprovements({
    required RepositoryQuery query,
    String? className,
  });

  Future<List<InterventionEffectivenessItem>> listInterventionEffectiveness({
    required RepositoryQuery query,
    String? studentId,
  });

  Future<ExamAnalytics> getExamAnalytics({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
    String? examType,
  });

  Future<List<SubjectPerformanceItem>> getSubjectPerformance({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  });

  Future<List<WeakChapterItem>> getWeakChapters({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  });

  Future<ResultIntelligence> getResultIntelligence({
    required RepositoryQuery query,
    String? className,
  });

  Future<AcademicForecast> getAcademicForecast({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  });

  Future<List<RankMovementItem>> getRankMovement({
    required RepositoryQuery query,
    String? className,
  });

  Future<List<LessonEffectivenessScore>> getLessonEffectivenessScores({
    required RepositoryQuery query,
    String? teacherUserId,
    String? className,
  });

  Future<List<TopicMasteryEntry>> getTopicMasteryAnalytics({
    required RepositoryQuery query,
    String? teacherUserId,
  });

  Future<TeacherPerformanceInsights> getTeacherPerformanceInsights({
    required RepositoryQuery query,
    String? teacherUserId,
  });

  Future<TeacherPlanningCenter> getTeacherPlanningCenter({
    required RepositoryQuery query,
    String? teacherUserId,
  });

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
  });
}
