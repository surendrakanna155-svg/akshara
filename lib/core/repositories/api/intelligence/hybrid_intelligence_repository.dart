import '../../../../features/intelligence/exam/exam_intelligence_models.dart';
import '../../../../features/intelligence/intelligence_models.dart';
import '../../../../features/intelligence/student_success/student_success_models.dart';
import '../../../../features/intelligence/teacher_effectiveness/teacher_effectiveness_models.dart';
import '../../interfaces/intelligence_repository.dart';
import '../../repository_query.dart';
import 'api_intelligence_repository.dart';

class HybridIntelligenceRepository implements IntelligenceRepository {
  HybridIntelligenceRepository({required ApiIntelligenceRepository api}) : _api = api;

  final ApiIntelligenceRepository _api;

  @override
  Future<List<StudentRiskSnapshot>> listStudentRisks({
    required RepositoryQuery query,
    String? className,
    StudentRiskLevel? riskLevel,
  }) =>
      _api.listStudentRisks(query: query, className: className, riskLevel: riskLevel);

  @override
  Future<List<StudentRiskSnapshot>> computeStudentRisks({
    required RepositoryQuery query,
    String? academicYearLabel,
  }) =>
      _api.computeStudentRisks(query: query, academicYearLabel: academicYearLabel);

  @override
  Future<List<ClassRiskSummary>> listClassRisks({required RepositoryQuery query}) =>
      _api.listClassRisks(query: query);

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
  }) =>
      _api.generateCommunication(
        query: query,
        scenario: scenario,
        studentName: studentName,
        className: className,
        customNote: customNote,
        languages: languages,
        parentPreferredLanguage: parentPreferredLanguage,
        feeAmount: feeAmount,
        dueDate: dueDate,
        examName: examName,
        meetingDate: meetingDate,
      );

  @override
  Future<ParentGuidanceReport> generateParentGuidance({
    required RepositoryQuery query,
    required String studentId,
    required GuidanceMode mode,
    IntelLanguage language = IntelLanguage.english,
    Map<String, dynamic> inputs = const {},
    bool publish = true,
    bool autoFillFromRisk = true,
  }) =>
      _api.generateParentGuidance(
        query: query,
        studentId: studentId,
        mode: mode,
        language: language,
        inputs: inputs,
        publish: publish,
        autoFillFromRisk: autoFillFromRisk,
      );

  @override
  Future<PrincipalQueryResult> queryPrincipal({
    required RepositoryQuery query,
    required String queryText,
  }) =>
      _api.queryPrincipal(query: query, queryText: queryText);

  @override
  Future<TeacherSuccessCenter> getTeacherSuccessCenter({required RepositoryQuery query}) =>
      _api.getTeacherSuccessCenter(query: query);

  @override
  Future<PrincipalIntelligenceCenter> getPrincipalCenter({
    required RepositoryQuery query,
    String period = 'monthly',
  }) =>
      _api.getPrincipalCenter(query: query, period: period);

  @override
  Future<StudentSuccessDashboard> getStudentSuccessDashboard({required RepositoryQuery query}) =>
      _api.getStudentSuccessDashboard(query: query);

  @override
  Future<List<StudentSuccessSnapshot>> listStudentSuccessPredictions({
    required RepositoryQuery query,
    String? className,
    int? minDropoutRisk,
  }) =>
      _api.listStudentSuccessPredictions(
        query: query,
        className: className,
        minDropoutRisk: minDropoutRisk,
      );

  @override
  Future<List<StudentSuccessSnapshot>> computeStudentSuccess({required RepositoryQuery query}) =>
      _api.computeStudentSuccess(query: query);

  @override
  Future<StudentSuccessSnapshot?> getStudentSuccess({
    required RepositoryQuery query,
    required String studentId,
  }) =>
      _api.getStudentSuccess(query: query, studentId: studentId);

  @override
  Future<List<StudentImprovementItem>> listStudentImprovements({
    required RepositoryQuery query,
    String? className,
  }) =>
      _api.listStudentImprovements(query: query, className: className);

  @override
  Future<List<InterventionEffectivenessItem>> listInterventionEffectiveness({
    required RepositoryQuery query,
    String? studentId,
  }) =>
      _api.listInterventionEffectiveness(query: query, studentId: studentId);

  @override
  Future<ExamAnalytics> getExamAnalytics({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
    String? examType,
  }) =>
      _api.getExamAnalytics(
        query: query,
        className: className,
        subjectName: subjectName,
        examType: examType,
      );

  @override
  Future<List<SubjectPerformanceItem>> getSubjectPerformance({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  }) =>
      _api.getSubjectPerformance(query: query, className: className, subjectName: subjectName);

  @override
  Future<List<WeakChapterItem>> getWeakChapters({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  }) =>
      _api.getWeakChapters(query: query, className: className, subjectName: subjectName);

  @override
  Future<ResultIntelligence> getResultIntelligence({
    required RepositoryQuery query,
    String? className,
  }) =>
      _api.getResultIntelligence(query: query, className: className);

  @override
  Future<AcademicForecast> getAcademicForecast({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  }) =>
      _api.getAcademicForecast(query: query, className: className, subjectName: subjectName);

  @override
  Future<List<RankMovementItem>> getRankMovement({
    required RepositoryQuery query,
    String? className,
  }) =>
      _api.getRankMovement(query: query, className: className);

  @override
  Future<List<LessonEffectivenessScore>> getLessonEffectivenessScores({
    required RepositoryQuery query,
    String? teacherUserId,
    String? className,
  }) =>
      _api.getLessonEffectivenessScores(
        query: query,
        teacherUserId: teacherUserId,
        className: className,
      );

  @override
  Future<List<TopicMasteryEntry>> getTopicMasteryAnalytics({
    required RepositoryQuery query,
    String? teacherUserId,
  }) =>
      _api.getTopicMasteryAnalytics(query: query, teacherUserId: teacherUserId);

  @override
  Future<TeacherPerformanceInsights> getTeacherPerformanceInsights({
    required RepositoryQuery query,
    String? teacherUserId,
  }) =>
      _api.getTeacherPerformanceInsights(query: query, teacherUserId: teacherUserId);

  @override
  Future<TeacherPlanningCenter> getTeacherPlanningCenter({
    required RepositoryQuery query,
    String? teacherUserId,
  }) =>
      _api.getTeacherPlanningCenter(query: query, teacherUserId: teacherUserId);

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
  }) =>
      _api.generateParentMeetingSummary(
        query: query,
        studentId: studentId,
        studentName: studentName,
        className: className,
        meetingDate: meetingDate,
        attendancePercent: attendancePercent,
        recentMarks: recentMarks,
        homeworkCompletionRate: homeworkCompletionRate,
        behaviorNotes: behaviorNotes,
        strengths: strengths,
        concerns: concerns,
        actionItems: actionItems,
      );
}
