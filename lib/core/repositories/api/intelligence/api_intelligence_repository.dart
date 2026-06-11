import '../../../../features/intelligence/exam/exam_intelligence_models.dart';
import '../../../../features/intelligence/intelligence_models.dart';
import '../../../../features/intelligence/student_success/student_success_models.dart';
import '../../../../features/intelligence/teacher_effectiveness/teacher_effectiveness_models.dart';
import '../../interfaces/intelligence_repository.dart';
import '../../repository_query.dart';
import 'mapper/intelligence_mapper.dart';
import 'mapper/teacher_effectiveness_mapper.dart';
import 'remote/intelligence_remote_datasource.dart';

class ApiIntelligenceRepository implements IntelligenceRepository {
  ApiIntelligenceRepository({
    required IntelligenceRemoteDataSource remote,
    TeacherEffectivenessMapper teacherEffectivenessMapper = const TeacherEffectivenessMapper(),
  })  : _remote = remote,
        _teacherEffectivenessMapper = teacherEffectivenessMapper;

  final IntelligenceRemoteDataSource _remote;
  final TeacherEffectivenessMapper _teacherEffectivenessMapper;

  @override
  Future<List<StudentRiskSnapshot>> listStudentRisks({
    required RepositoryQuery query,
    String? className,
    StudentRiskLevel? riskLevel,
  }) async {
    final rows = await _remote.fetchStudentRisks(
      query: query,
      className: className,
      riskLevel: riskLevel,
    );
    return rows.map(IntelligenceMapper.riskFromApi).toList();
  }

  @override
  Future<List<StudentRiskSnapshot>> computeStudentRisks({
    required RepositoryQuery query,
    String? academicYearLabel,
  }) async {
    final rows = await _remote.computeStudentRisks(
      query: query,
      academicYearLabel: academicYearLabel,
    );
    return rows.map(IntelligenceMapper.riskFromApi).toList();
  }

  @override
  Future<List<ClassRiskSummary>> listClassRisks({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.fetchClassRisks(query: query);
    return rows.map(IntelligenceMapper.classRiskFromApi).toList();
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
    final data = await _remote.generateCommunication(
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
    final drafts = data['drafts'] as List<dynamic>? ?? const [];
    return drafts
        .map((e) => IntelligenceMapper.draftFromApi(Map<String, dynamic>.from(e as Map)))
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
    final data = await _remote.generateParentGuidance(
      query: query,
      studentId: studentId,
      mode: mode,
      language: language,
      inputs: inputs,
      publish: publish,
      autoFillFromRisk: autoFillFromRisk,
    );
    return IntelligenceMapper.guidanceFromApi(data);
  }

  @override
  Future<PrincipalQueryResult> queryPrincipal({
    required RepositoryQuery query,
    required String queryText,
  }) async {
    final data = await _remote.fetchPrincipalQuery(query: query, queryText: queryText);
    return IntelligenceMapper.principalQueryFromApi(data);
  }

  @override
  Future<TeacherSuccessCenter> getTeacherSuccessCenter({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchTeacherSuccessCenter(query: query);
    return IntelligenceMapper.teacherCenterFromApi(data);
  }

  @override
  Future<PrincipalIntelligenceCenter> getPrincipalCenter({
    required RepositoryQuery query,
    String period = 'monthly',
  }) async {
    final data = await _remote.fetchPrincipalCenter(query: query, period: period);
    return IntelligenceMapper.principalFromApi(data);
  }

  @override
  Future<StudentSuccessDashboard> getStudentSuccessDashboard({
    required RepositoryQuery query,
  }) async {
    final data = await _remote.fetchStudentSuccessDashboard(query: query);
    return IntelligenceMapper.studentSuccessDashboardFromApi(data);
  }

  @override
  Future<List<StudentSuccessSnapshot>> listStudentSuccessPredictions({
    required RepositoryQuery query,
    String? className,
    int? minDropoutRisk,
  }) async {
    final rows = await _remote.fetchStudentSuccessPredictions(
      query: query,
      className: className,
      minDropoutRisk: minDropoutRisk,
    );
    return rows.map(IntelligenceMapper.studentSuccessFromApi).toList();
  }

  @override
  Future<List<StudentSuccessSnapshot>> computeStudentSuccess({
    required RepositoryQuery query,
  }) async {
    final rows = await _remote.computeStudentSuccess(query: query);
    return rows.map(IntelligenceMapper.studentSuccessFromApi).toList();
  }

  @override
  Future<StudentSuccessSnapshot?> getStudentSuccess({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final data = await _remote.fetchStudentSuccess(query: query, studentId: studentId);
    return IntelligenceMapper.studentSuccessFromApi(data);
  }

  @override
  Future<List<StudentImprovementItem>> listStudentImprovements({
    required RepositoryQuery query,
    String? className,
  }) async {
    final rows = await _remote.fetchStudentImprovements(query: query, className: className);
    return rows.map(IntelligenceMapper.improvementFromApi).toList();
  }

  @override
  Future<List<InterventionEffectivenessItem>> listInterventionEffectiveness({
    required RepositoryQuery query,
    String? studentId,
  }) async {
    final rows = await _remote.fetchInterventionEffectiveness(query: query, studentId: studentId);
    return rows.map(IntelligenceMapper.interventionFromApi).toList();
  }

  @override
  Future<ExamAnalytics> getExamAnalytics({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
    String? examType,
  }) async {
    final data = await _remote.fetchExamAnalytics(
      query: query,
      className: className,
      subjectName: subjectName,
      examType: examType,
    );
    return IntelligenceMapper.examAnalyticsFromApi(data);
  }

  @override
  Future<List<SubjectPerformanceItem>> getSubjectPerformance({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  }) async {
    final rows = await _remote.fetchSubjectPerformance(
      query: query,
      className: className,
      subjectName: subjectName,
    );
    return rows.map(IntelligenceMapper.subjectPerformanceFromApi).toList();
  }

  @override
  Future<List<WeakChapterItem>> getWeakChapters({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  }) async {
    final rows = await _remote.fetchWeakChapters(
      query: query,
      className: className,
      subjectName: subjectName,
    );
    return rows.map(IntelligenceMapper.weakChapterFromApi).toList();
  }

  @override
  Future<ResultIntelligence> getResultIntelligence({
    required RepositoryQuery query,
    String? className,
  }) async {
    final data = await _remote.fetchResultIntelligence(query: query, className: className);
    return IntelligenceMapper.resultIntelligenceFromApi(data);
  }

  @override
  Future<AcademicForecast> getAcademicForecast({
    required RepositoryQuery query,
    String? className,
    String? subjectName,
  }) async {
    final data = await _remote.fetchAcademicForecast(
      query: query,
      className: className,
      subjectName: subjectName,
    );
    return IntelligenceMapper.academicForecastFromApi(data);
  }

  @override
  Future<List<RankMovementItem>> getRankMovement({
    required RepositoryQuery query,
    String? className,
  }) async {
    final rows = await _remote.fetchRankMovement(query: query, className: className);
    return rows.map(IntelligenceMapper.rankMovementFromApi).toList();
  }

  @override
  Future<List<LessonEffectivenessScore>> getLessonEffectivenessScores({
    required RepositoryQuery query,
    String? teacherUserId,
    String? className,
  }) async {
    final rows = await _remote.fetchLessonEffectivenessScores(
      query: query,
      teacherUserId: teacherUserId,
      className: className,
    );
    return rows.map(_teacherEffectivenessMapper.lessonScoreFromApi).toList();
  }

  @override
  Future<List<TopicMasteryEntry>> getTopicMasteryAnalytics({
    required RepositoryQuery query,
    String? teacherUserId,
  }) async {
    final rows = await _remote.fetchTopicMasteryAnalytics(
      query: query,
      teacherUserId: teacherUserId,
    );
    return rows.map(_teacherEffectivenessMapper.topicMasteryFromApi).toList();
  }

  @override
  Future<TeacherPerformanceInsights> getTeacherPerformanceInsights({
    required RepositoryQuery query,
    String? teacherUserId,
  }) async {
    final data = await _remote.fetchTeacherPerformanceInsights(
      query: query,
      teacherUserId: teacherUserId,
    );
    return _teacherEffectivenessMapper.performanceFromApi(data);
  }

  @override
  Future<TeacherPlanningCenter> getTeacherPlanningCenter({
    required RepositoryQuery query,
    String? teacherUserId,
  }) async {
    final data = await _remote.fetchTeacherPlanningCenter(
      query: query,
      teacherUserId: teacherUserId,
    );
    return _teacherEffectivenessMapper.planningFromApi(data);
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
    final data = await _remote.generateParentMeetingSummary(
      query: query,
      body: {
        'studentId': studentId,
        'studentName': studentName,
        'className': className,
        'meetingDate': meetingDate,
        if (attendancePercent != null) 'attendancePercent': attendancePercent,
        if (recentMarks != null) 'recentMarks': recentMarks,
        if (homeworkCompletionRate != null) 'homeworkCompletionRate': homeworkCompletionRate,
        if (behaviorNotes != null) 'behaviorNotes': behaviorNotes,
        if (strengths.isNotEmpty) 'strengths': strengths,
        if (concerns.isNotEmpty) 'concerns': concerns,
        if (actionItems.isNotEmpty) 'actionItems': actionItems,
      },
    );
    return _teacherEffectivenessMapper.parentMeetingSummaryFromApi(data);
  }
}
