import '../../../features/school_completion/school_completion_models.dart';
import '../repository_query.dart';

abstract class SchoolCompletionRepository {
  Future<List<AcademicSubject>> listSubjects({required RepositoryQuery query});

  Future<AcademicSubject> createSubject({
    required RepositoryQuery query,
    required String subjectCode,
    required String subjectName,
    String category = 'core',
    List<String> gradeLabels = const [],
  });

  Future<AcademicSubject> updateSubject({
    required RepositoryQuery query,
    required String subjectId,
    String? subjectName,
    String? category,
    String? status,
  });

  Future<List<LessonLogEntry>> listLessonLogs({
    required RepositoryQuery query,
    String? className,
  });

  Future<LessonLogEntry> createLessonLog({
    required RepositoryQuery query,
    required String className,
    required String topic,
    String? sectionName,
    String? subjectId,
    String outcome = 'completed',
    String? notes,
  });

  Future<TimetableAutomationResult> automateTimetables({
    required RepositoryQuery query,
    required String academicYearId,
    int periodsPerDay = 6,
    int daysPerWeek = 5,
  });

  Future<SchoolBranding> getBranding({required RepositoryQuery query});

  Future<SchoolBranding> saveBranding({
    required RepositoryQuery query,
    required SchoolBranding branding,
  });

  Future<WhatsAppProviderConfig> getWhatsAppProvider(
      {required RepositoryQuery query});

  Future<WhatsAppProviderConfig> saveWhatsAppProvider({
    required RepositoryQuery query,
    required WhatsAppProviderConfig config,
  });

  Future<WhatsAppTestResult> testWhatsAppProvider({
    required RepositoryQuery query,
    required String toPhone,
    String? templateId,
  });

  Future<List<ClassSubjectAssignment>> listClassSubjectAssignments({
    required RepositoryQuery query,
    String? academicYearId,
  });

  Future<ClassSubjectAssignment> createClassSubjectAssignment({
    required RepositoryQuery query,
    required String academicYearId,
    required String classId,
    required String subjectId,
    String? sectionId,
    bool isElective = false,
    int periodsPerWeek = 5,
  });

  Future<void> deleteClassSubjectAssignment({
    required RepositoryQuery query,
    required String assignmentId,
  });

  Future<List<TeacherSubjectAssignment>> listTeacherSubjectAssignments({
    required RepositoryQuery query,
    String? academicYearId,
  });

  Future<TeacherSubjectAssignment> createTeacherSubjectAssignment({
    required RepositoryQuery query,
    required String academicYearId,
    required String teacherUserId,
    required String subjectId,
    String? classId,
    String? sectionId,
    int periodsPerWeek = 0,
    bool isPrimary = false,
  });

  Future<List<SubjectWorkloadEntry>> getSubjectWorkload({
    required RepositoryQuery query,
  });

  Future<TeacherLessonAnalytics> getTeacherLessonAnalytics({
    required RepositoryQuery query,
    String? className,
    String? teacherUserId,
  });

  Future<List<PrincipalCoverageEntry>> getPrincipalLessonAnalytics({
    required RepositoryQuery query,
  });

  Future<TimetableOptimizationResult> getTimetableOptimization({
    required RepositoryQuery query,
    required String academicYearId,
  });

  Future<ApplyTimetableOptimizationResult> applyTimetableOptimization({
    required RepositoryQuery query,
    required String academicYearId,
    List<String> recommendationIds = const [],
    bool applyAll = false,
  });

  Future<SubstituteCoverageData> getSubstituteCoverage({
    required RepositoryQuery query,
    required String academicYearId,
    String? dayOfWeek,
  });

  Future<SubstituteAssignmentResult> assignSubstitute({
    required RepositoryQuery query,
    required AssignSubstituteRequest request,
  });

  Future<TeacherReassignmentData> getTeacherReassignmentOptions({
    required RepositoryQuery query,
    required String academicYearId,
    String? sourceTeacherId,
  });

  Future<TeacherReassignmentResult> reassignTeacher({
    required RepositoryQuery query,
    required ReassignTeacherRequest request,
  });

  Future<DeliveryAnalytics> getDeliveryAnalytics({
    required RepositoryQuery query,
  });

  Future<PilotDashboardSnapshot> getPilotDashboard({
    required RepositoryQuery query,
  });

  Future<List<SubjectTemplate>> listSubjectTemplates({
    required RepositoryQuery query,
    String? board,
    String? gradeLabel,
  });

  Future<SyllabusGenerationResult> generateSyllabus({
    required RepositoryQuery query,
    required String academicYearId,
    required String className,
    required String subjectId,
    required String subjectName,
    required String gradeLabel,
  });

  Future<SyllabusGenerationResult> cloneSyllabus({
    required RepositoryQuery query,
    required String fromYearId,
    required String toYearId,
  });

  Future<List<SyllabusChapter>> listSyllabusChapters({
    required RepositoryQuery query,
    String? academicYearId,
  });

  /// Real syllabus topics (with real `syllabus_topics.id` values) for a
  /// class/subject — backs the teacher's daily-capture topic picker so
  /// [completeTopic] is never called with a fabricated id.
  Future<List<SyllabusTopic>> listSyllabusTopics({
    required RepositoryQuery query,
    String? className,
    String? subjectId,
    String? chapterId,
  });

  Future<void> completeTopic({
    required RepositoryQuery query,
    required String topicId,
    String? lessonLogId,
  });

  Future<TeacherProgressDashboard> getTeacherProgress({
    required RepositoryQuery query,
  });

  Future<PrincipalAcademicDashboard> getPrincipalAcademicProgress({
    required RepositoryQuery query,
  });

  Future<List<AcademicRoom>> listRooms({required RepositoryQuery query});

  Future<AcademicRoom> createRoom({
    required RepositoryQuery query,
    required String roomLabel,
    String roomType = 'classroom',
    int capacity = 40,
  });

  Future<TimetableIntelligenceResult> getTimetableIntelligence({
    required RepositoryQuery query,
    required String academicYearId,
  });

  Future<CommunicationAnalyticsSummary> getCommunicationAnalytics({
    required RepositoryQuery query,
  });

  Future<PilotActivationStats> getParentActivationDashboard({
    required RepositoryQuery query,
  });

  Future<RoomAllocationResult> allocateRooms({
    required RepositoryQuery query,
    required String academicYearId,
  });
}
