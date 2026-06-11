import '../../interfaces/school_completion_repository.dart';
import '../../repository_query.dart';
import '../../../../features/school_completion/school_completion_models.dart';
import 'mapper/school_completion_mapper.dart';
import 'mapper/school_completion_phase10_mapper.dart';
import 'mapper/school_completion_phase15_mapper.dart';
import 'remote/school_completion_remote_datasource.dart';

class ApiSchoolCompletionRepository implements SchoolCompletionRepository {
  ApiSchoolCompletionRepository({
    required SchoolCompletionRemoteDataSource remote,
    SchoolCompletionMapper mapper = const SchoolCompletionMapper(),
    SchoolCompletionPhase10Mapper phase10Mapper = const SchoolCompletionPhase10Mapper(),
    SchoolCompletionPhase15Mapper phase15Mapper = const SchoolCompletionPhase15Mapper(),
  })  : _remote = remote,
        _mapper = mapper,
        _phase10Mapper = phase10Mapper,
        _phase15Mapper = phase15Mapper;

  final SchoolCompletionRemoteDataSource _remote;
  final SchoolCompletionMapper _mapper;
  final SchoolCompletionPhase10Mapper _phase10Mapper;
  final SchoolCompletionPhase15Mapper _phase15Mapper;

  @override
  Future<List<AcademicSubject>> listSubjects({required RepositoryQuery query}) async {
    final items = await _remote.listSubjects(query: query);
    return items.map(_mapper.toSubject).toList();
  }

  @override
  Future<AcademicSubject> createSubject({
    required RepositoryQuery query,
    required String subjectCode,
    required String subjectName,
    String category = 'core',
    List<String> gradeLabels = const [],
  }) async {
    final dto = await _remote.createSubject(
      query: query,
      body: {
        'subjectCode': subjectCode,
        'subjectName': subjectName,
        'category': category,
        'gradeLabels': gradeLabels,
      },
    );
    return _mapper.toSubject(dto);
  }

  @override
  Future<AcademicSubject> updateSubject({
    required RepositoryQuery query,
    required String subjectId,
    String? subjectName,
    String? category,
    String? status,
  }) async {
    final dto = await _remote.updateSubject(
      query: query,
      subjectId: subjectId,
      body: {
        if (subjectName != null) 'subjectName': subjectName,
        if (category != null) 'category': category,
        if (status != null) 'status': status,
      },
    );
    return _mapper.toSubject(dto);
  }

  @override
  Future<List<LessonLogEntry>> listLessonLogs({
    required RepositoryQuery query,
    String? className,
  }) async {
    final items = await _remote.listLessonLogs(query: query, className: className);
    return items.map(_mapper.toLessonLog).toList();
  }

  @override
  Future<LessonLogEntry> createLessonLog({
    required RepositoryQuery query,
    required String className,
    required String topic,
    String? sectionName,
    String? subjectId,
    String outcome = 'completed',
    String? notes,
  }) async {
    final dto = await _remote.createLessonLog(
      query: query,
      body: {
        'className': className,
        'topic': topic,
        if (sectionName != null) 'sectionName': sectionName,
        if (subjectId != null) 'subjectId': subjectId,
        'outcome': outcome,
        if (notes != null) 'notes': notes,
      },
    );
    return _mapper.toLessonLog(dto);
  }

  @override
  Future<TimetableAutomationResult> automateTimetables({
    required RepositoryQuery query,
    required String academicYearId,
    int periodsPerDay = 6,
    int daysPerWeek = 5,
  }) async {
    final dto = await _remote.automateTimetables(
      query: query,
      body: {
        'academicYearId': academicYearId,
        'periodsPerDay': periodsPerDay,
        'daysPerWeek': daysPerWeek,
      },
    );
    return _mapper.toAutomationResult(dto);
  }

  @override
  Future<SchoolBranding> getBranding({required RepositoryQuery query}) async {
    final dto = await _remote.getBranding(query: query);
    return _mapper.toBranding(dto);
  }

  @override
  Future<SchoolBranding> saveBranding({
    required RepositoryQuery query,
    required SchoolBranding branding,
  }) async {
    final dto = await _remote.saveBranding(
      query: query,
      body: _mapper.brandingToJson(branding),
    );
    return _mapper.toBranding(dto);
  }

  @override
  Future<WhatsAppProviderConfig> getWhatsAppProvider({required RepositoryQuery query}) async {
    final dto = await _remote.getWhatsAppProvider(query: query);
    return _mapper.toWhatsAppConfig(dto);
  }

  @override
  Future<WhatsAppProviderConfig> saveWhatsAppProvider({
    required RepositoryQuery query,
    required WhatsAppProviderConfig config,
  }) async {
    final dto = await _remote.saveWhatsAppProvider(
      query: query,
      body: _mapper.whatsAppConfigToJson(config),
    );
    return _mapper.toWhatsAppConfig(dto);
  }

  @override
  Future<WhatsAppTestResult> testWhatsAppProvider({
    required RepositoryQuery query,
    required String toPhone,
    String? templateId,
  }) async {
    final dto = await _remote.testWhatsAppProvider(
      query: query,
      body: {
        'toPhone': toPhone,
        if (templateId != null) 'templateId': templateId,
      },
    );
    return _mapper.toWhatsAppTestResult(dto);
  }

  @override
  Future<List<ClassSubjectAssignment>> listClassSubjectAssignments({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    final items = await _remote.listClassSubjectAssignments(
      query: query,
      academicYearId: academicYearId,
    );
    return items.map(_mapper.toClassSubjectAssignment).toList();
  }

  @override
  Future<ClassSubjectAssignment> createClassSubjectAssignment({
    required RepositoryQuery query,
    required String academicYearId,
    required String classId,
    required String subjectId,
    String? sectionId,
    bool isElective = false,
    int periodsPerWeek = 5,
  }) async {
    final dto = await _remote.createClassSubjectAssignment(
      query: query,
      body: {
        'academicYearId': academicYearId,
        'classId': classId,
        'subjectId': subjectId,
        if (sectionId != null) 'sectionId': sectionId,
        'isElective': isElective,
        'periodsPerWeek': periodsPerWeek,
      },
    );
    return _mapper.toClassSubjectAssignment(dto);
  }

  @override
  Future<void> deleteClassSubjectAssignment({
    required RepositoryQuery query,
    required String assignmentId,
  }) =>
      _remote.deleteClassSubjectAssignment(query: query, assignmentId: assignmentId);

  @override
  Future<List<TeacherSubjectAssignment>> listTeacherSubjectAssignments({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    final items = await _remote.listTeacherSubjectAssignments(
      query: query,
      academicYearId: academicYearId,
    );
    return items.map(_mapper.toTeacherSubjectAssignment).toList();
  }

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
  }) async {
    final dto = await _remote.createTeacherSubjectAssignment(
      query: query,
      body: {
        'academicYearId': academicYearId,
        'teacherUserId': teacherUserId,
        'subjectId': subjectId,
        if (classId != null) 'classId': classId,
        if (sectionId != null) 'sectionId': sectionId,
        'periodsPerWeek': periodsPerWeek,
        'isPrimary': isPrimary,
      },
    );
    return _mapper.toTeacherSubjectAssignment(dto);
  }

  @override
  Future<List<SubjectWorkloadEntry>> getSubjectWorkload({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.getSubjectWorkload(query: query);
    return items.map(_mapper.toSubjectWorkload).toList();
  }

  @override
  Future<TeacherLessonAnalytics> getTeacherLessonAnalytics({
    required RepositoryQuery query,
    String? className,
    String? teacherUserId,
  }) async {
    final dto = await _remote.getTeacherLessonAnalytics(
      query: query,
      className: className,
      teacherUserId: teacherUserId,
    );
    return _mapper.toTeacherLessonAnalytics(dto);
  }

  @override
  Future<List<PrincipalCoverageEntry>> getPrincipalLessonAnalytics({
    required RepositoryQuery query,
  }) async {
    final items = await _remote.getPrincipalLessonAnalytics(query: query);
    return items.map(_mapper.toPrincipalCoverage).toList();
  }

  @override
  Future<TimetableOptimizationResult> getTimetableOptimization({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final dto = await _remote.getTimetableOptimization(
      query: query,
      academicYearId: academicYearId,
    );
    return _mapper.toTimetableOptimization(dto);
  }

  @override
  Future<DeliveryAnalytics> getDeliveryAnalytics({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.getDeliveryAnalytics(query: query);
    return _mapper.toDeliveryAnalytics(dto);
  }

  @override
  Future<PilotDashboardSnapshot> getPilotDashboard({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.getPilotDashboard(query: query);
    return _mapper.toPilotDashboard(dto);
  }

  @override
  Future<List<SubjectTemplate>> listSubjectTemplates({
    required RepositoryQuery query,
    String? board,
    String? gradeLabel,
  }) async {
    final items = await _remote.listSubjectTemplates(query: query, board: board, gradeLabel: gradeLabel);
    return items.map(_phase10Mapper.toSubjectTemplate).toList();
  }

  @override
  Future<SyllabusGenerationResult> generateSyllabus({
    required RepositoryQuery query,
    required String academicYearId,
    required String className,
    required String subjectId,
    required String subjectName,
    required String gradeLabel,
  }) async {
    final dto = await _remote.generateSyllabus(
      query: query,
      body: {
        'academicYearId': academicYearId,
        'className': className,
        'subjectId': subjectId,
        'subjectName': subjectName,
        'gradeLabel': gradeLabel,
      },
    );
    return _phase10Mapper.toGenerationResult(dto);
  }

  @override
  Future<SyllabusGenerationResult> cloneSyllabus({
    required RepositoryQuery query,
    required String fromYearId,
    required String toYearId,
  }) async {
    final dto = await _remote.cloneSyllabus(
      query: query,
      body: {'fromYearId': fromYearId, 'toYearId': toYearId},
    );
    return _phase10Mapper.toGenerationResult(dto);
  }

  @override
  Future<List<SyllabusChapter>> listSyllabusChapters({
    required RepositoryQuery query,
    String? academicYearId,
  }) async {
    final items = await _remote.listSyllabusChapters(query: query, academicYearId: academicYearId);
    return items.map(_phase10Mapper.toChapter).toList();
  }

  @override
  Future<void> completeTopic({
    required RepositoryQuery query,
    required String topicId,
    String? lessonLogId,
  }) =>
      _remote.completeTopic(
        query: query,
        body: {
          'topicId': topicId,
          if (lessonLogId != null) 'lessonLogId': lessonLogId,
        },
      );

  @override
  Future<TeacherProgressDashboard> getTeacherProgress({required RepositoryQuery query}) async {
    final dto = await _remote.getTeacherProgress(query: query);
    return _phase10Mapper.toTeacherProgress(dto);
  }

  @override
  Future<PrincipalAcademicDashboard> getPrincipalAcademicProgress({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.getPrincipalAcademicProgress(query: query);
    return _phase10Mapper.toPrincipalProgress(dto);
  }

  @override
  Future<List<AcademicRoom>> listRooms({required RepositoryQuery query}) async {
    final items = await _remote.listRooms(query: query);
    return items.map(_phase10Mapper.toRoom).toList();
  }

  @override
  Future<AcademicRoom> createRoom({
    required RepositoryQuery query,
    required String roomLabel,
    String roomType = 'classroom',
    int capacity = 40,
  }) async {
    final dto = await _remote.createRoom(
      query: query,
      body: {'roomLabel': roomLabel, 'roomType': roomType, 'capacity': capacity},
    );
    return _phase10Mapper.toRoom(dto);
  }

  @override
  Future<TimetableIntelligenceResult> getTimetableIntelligence({
    required RepositoryQuery query,
    required String academicYearId,
  }) async {
    final dto = await _remote.getTimetableIntelligence(query: query, academicYearId: academicYearId);
    return _phase10Mapper.toIntelligence(dto);
  }

  @override
  Future<CommunicationAnalyticsSummary> getCommunicationAnalytics({
    required RepositoryQuery query,
  }) async {
    final dto = await _remote.getCommunicationAnalytics(query: query);
    return _phase15Mapper.toCommunicationAnalyticsSummary(dto);
  }
}
