import '../../interfaces/school_completion_repository.dart';
import '../../repository_query.dart';
import '../../../../features/school_completion/school_completion_models.dart';
import 'api_school_completion_repository.dart';

class HybridSchoolCompletionRepository implements SchoolCompletionRepository {
  HybridSchoolCompletionRepository({required ApiSchoolCompletionRepository api})
      : _api = api;

  final ApiSchoolCompletionRepository _api;

  @override
  Future<List<AcademicSubject>> listSubjects(
          {required RepositoryQuery query}) =>
      _api.listSubjects(query: query);

  @override
  Future<AcademicSubject> createSubject({
    required RepositoryQuery query,
    required String subjectCode,
    required String subjectName,
    String category = 'core',
    List<String> gradeLabels = const [],
  }) =>
      _api.createSubject(
        query: query,
        subjectCode: subjectCode,
        subjectName: subjectName,
        category: category,
        gradeLabels: gradeLabels,
      );

  @override
  Future<AcademicSubject> updateSubject({
    required RepositoryQuery query,
    required String subjectId,
    String? subjectName,
    String? category,
    String? status,
  }) =>
      _api.updateSubject(
        query: query,
        subjectId: subjectId,
        subjectName: subjectName,
        category: category,
        status: status,
      );

  @override
  Future<List<LessonLogEntry>> listLessonLogs({
    required RepositoryQuery query,
    String? className,
  }) =>
      _api.listLessonLogs(query: query, className: className);

  @override
  Future<LessonLogEntry> createLessonLog({
    required RepositoryQuery query,
    required String className,
    required String topic,
    String? sectionName,
    String? subjectId,
    String outcome = 'completed',
    String? notes,
  }) =>
      _api.createLessonLog(
        query: query,
        className: className,
        topic: topic,
        sectionName: sectionName,
        subjectId: subjectId,
        outcome: outcome,
        notes: notes,
      );

  @override
  Future<TimetableAutomationResult> automateTimetables({
    required RepositoryQuery query,
    required String academicYearId,
    int periodsPerDay = 6,
    int daysPerWeek = 5,
  }) =>
      _api.automateTimetables(
        query: query,
        academicYearId: academicYearId,
        periodsPerDay: periodsPerDay,
        daysPerWeek: daysPerWeek,
      );

  @override
  Future<SchoolBranding> getBranding({required RepositoryQuery query}) =>
      _api.getBranding(query: query);

  @override
  Future<SchoolBranding> saveBranding({
    required RepositoryQuery query,
    required SchoolBranding branding,
  }) =>
      _api.saveBranding(query: query, branding: branding);

  @override
  Future<WhatsAppProviderConfig> getWhatsAppProvider(
          {required RepositoryQuery query}) =>
      _api.getWhatsAppProvider(query: query);

  @override
  Future<WhatsAppProviderConfig> saveWhatsAppProvider({
    required RepositoryQuery query,
    required WhatsAppProviderConfig config,
  }) =>
      _api.saveWhatsAppProvider(query: query, config: config);

  @override
  Future<WhatsAppTestResult> testWhatsAppProvider({
    required RepositoryQuery query,
    required String toPhone,
    String? templateId,
  }) =>
      _api.testWhatsAppProvider(
          query: query, toPhone: toPhone, templateId: templateId);

  @override
  Future<List<ClassSubjectAssignment>> listClassSubjectAssignments({
    required RepositoryQuery query,
    String? academicYearId,
  }) =>
      _api.listClassSubjectAssignments(
          query: query, academicYearId: academicYearId);

  @override
  Future<ClassSubjectAssignment> createClassSubjectAssignment({
    required RepositoryQuery query,
    required String academicYearId,
    required String classId,
    required String subjectId,
    String? sectionId,
    bool isElective = false,
    int periodsPerWeek = 5,
  }) =>
      _api.createClassSubjectAssignment(
        query: query,
        academicYearId: academicYearId,
        classId: classId,
        subjectId: subjectId,
        sectionId: sectionId,
        isElective: isElective,
        periodsPerWeek: periodsPerWeek,
      );

  @override
  Future<void> deleteClassSubjectAssignment({
    required RepositoryQuery query,
    required String assignmentId,
  }) =>
      _api.deleteClassSubjectAssignment(
          query: query, assignmentId: assignmentId);

  @override
  Future<List<TeacherSubjectAssignment>> listTeacherSubjectAssignments({
    required RepositoryQuery query,
    String? academicYearId,
  }) =>
      _api.listTeacherSubjectAssignments(
          query: query, academicYearId: academicYearId);

  @override
  Future<TeacherSubjectAssignment> createTeacherSubjectAssignment({
    required RepositoryQuery query,
    required String academicYearId,
    required String teacherUserId,
    required String subjectId,
    String? classId,
    String? sectionId,
    int periodsPerWeek = 0,
    bool isPrimary = false,
  }) =>
      _api.createTeacherSubjectAssignment(
        query: query,
        academicYearId: academicYearId,
        teacherUserId: teacherUserId,
        subjectId: subjectId,
        classId: classId,
        sectionId: sectionId,
        periodsPerWeek: periodsPerWeek,
        isPrimary: isPrimary,
      );

  @override
  Future<List<SubjectWorkloadEntry>> getSubjectWorkload({
    required RepositoryQuery query,
  }) =>
      _api.getSubjectWorkload(query: query);

  @override
  Future<TeacherLessonAnalytics> getTeacherLessonAnalytics({
    required RepositoryQuery query,
    String? className,
    String? teacherUserId,
  }) =>
      _api.getTeacherLessonAnalytics(
        query: query,
        className: className,
        teacherUserId: teacherUserId,
      );

  @override
  Future<List<PrincipalCoverageEntry>> getPrincipalLessonAnalytics({
    required RepositoryQuery query,
  }) =>
      _api.getPrincipalLessonAnalytics(query: query);

  @override
  Future<TimetableOptimizationResult> getTimetableOptimization({
    required RepositoryQuery query,
    required String academicYearId,
  }) =>
      _api.getTimetableOptimization(
          query: query, academicYearId: academicYearId);

  @override
  Future<ApplyTimetableOptimizationResult> applyTimetableOptimization({
    required RepositoryQuery query,
    required String academicYearId,
    List<String> recommendationIds = const [],
    bool applyAll = false,
  }) =>
      _api.applyTimetableOptimization(
        query: query,
        academicYearId: academicYearId,
        recommendationIds: recommendationIds,
        applyAll: applyAll,
      );

  @override
  Future<SubstituteCoverageData> getSubstituteCoverage({
    required RepositoryQuery query,
    required String academicYearId,
    String? dayOfWeek,
  }) =>
      _api.getSubstituteCoverage(
        query: query,
        academicYearId: academicYearId,
        dayOfWeek: dayOfWeek,
      );

  @override
  Future<SubstituteAssignmentResult> assignSubstitute({
    required RepositoryQuery query,
    required AssignSubstituteRequest request,
  }) =>
      _api.assignSubstitute(query: query, request: request);

  @override
  Future<TeacherReassignmentData> getTeacherReassignmentOptions({
    required RepositoryQuery query,
    required String academicYearId,
    String? sourceTeacherId,
  }) =>
      _api.getTeacherReassignmentOptions(
        query: query,
        academicYearId: academicYearId,
        sourceTeacherId: sourceTeacherId,
      );

  @override
  Future<TeacherReassignmentResult> reassignTeacher({
    required RepositoryQuery query,
    required ReassignTeacherRequest request,
  }) =>
      _api.reassignTeacher(query: query, request: request);

  @override
  Future<DeliveryAnalytics> getDeliveryAnalytics({
    required RepositoryQuery query,
  }) =>
      _api.getDeliveryAnalytics(query: query);

  @override
  Future<PilotDashboardSnapshot> getPilotDashboard({
    required RepositoryQuery query,
  }) =>
      _api.getPilotDashboard(query: query);

  @override
  Future<List<SubjectTemplate>> listSubjectTemplates({
    required RepositoryQuery query,
    String? board,
    String? gradeLabel,
  }) =>
      _api.listSubjectTemplates(
          query: query, board: board, gradeLabel: gradeLabel);

  @override
  Future<SyllabusGenerationResult> generateSyllabus({
    required RepositoryQuery query,
    required String academicYearId,
    required String className,
    required String subjectId,
    required String subjectName,
    required String gradeLabel,
  }) =>
      _api.generateSyllabus(
        query: query,
        academicYearId: academicYearId,
        className: className,
        subjectId: subjectId,
        subjectName: subjectName,
        gradeLabel: gradeLabel,
      );

  @override
  Future<SyllabusGenerationResult> cloneSyllabus({
    required RepositoryQuery query,
    required String fromYearId,
    required String toYearId,
  }) =>
      _api.cloneSyllabus(
          query: query, fromYearId: fromYearId, toYearId: toYearId);

  @override
  Future<List<SyllabusChapter>> listSyllabusChapters({
    required RepositoryQuery query,
    String? academicYearId,
  }) =>
      _api.listSyllabusChapters(query: query, academicYearId: academicYearId);

  @override
  Future<List<SyllabusTopic>> listSyllabusTopics({
    required RepositoryQuery query,
    String? className,
    String? subjectId,
    String? chapterId,
  }) =>
      _api.listSyllabusTopics(
        query: query,
        className: className,
        subjectId: subjectId,
        chapterId: chapterId,
      );

  @override
  Future<void> completeTopic({
    required RepositoryQuery query,
    required String topicId,
    String? lessonLogId,
  }) =>
      _api.completeTopic(
          query: query, topicId: topicId, lessonLogId: lessonLogId);

  @override
  Future<TeacherProgressDashboard> getTeacherProgress(
          {required RepositoryQuery query}) =>
      _api.getTeacherProgress(query: query);

  @override
  Future<PrincipalAcademicDashboard> getPrincipalAcademicProgress({
    required RepositoryQuery query,
  }) =>
      _api.getPrincipalAcademicProgress(query: query);

  @override
  Future<List<AcademicRoom>> listRooms({required RepositoryQuery query}) =>
      _api.listRooms(query: query);

  @override
  Future<AcademicRoom> createRoom({
    required RepositoryQuery query,
    required String roomLabel,
    String roomType = 'classroom',
    int capacity = 40,
  }) =>
      _api.createRoom(
        query: query,
        roomLabel: roomLabel,
        roomType: roomType,
        capacity: capacity,
      );

  @override
  Future<TimetableIntelligenceResult> getTimetableIntelligence({
    required RepositoryQuery query,
    required String academicYearId,
  }) =>
      _api.getTimetableIntelligence(
          query: query, academicYearId: academicYearId);

  @override
  Future<CommunicationAnalyticsSummary> getCommunicationAnalytics({
    required RepositoryQuery query,
  }) =>
      _api.getCommunicationAnalytics(query: query);

  @override
  Future<PilotActivationStats> getParentActivationDashboard({
    required RepositoryQuery query,
  }) =>
      _api.getParentActivationDashboard(query: query);

  @override
  Future<RoomAllocationResult> allocateRooms({
    required RepositoryQuery query,
    required String academicYearId,
  }) =>
      _api.allocateRooms(query: query, academicYearId: academicYearId);
}
