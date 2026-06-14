import '../../continuity/continuity_models.dart';
import '../interfaces/communication_repository.dart';
import '../interfaces/continuity_repository.dart';
import '../interfaces/parent_repository.dart';
import '../interfaces/teacher_repository.dart';
import '../interfaces/timetable_repository.dart';
import '../repository_query.dart';

class MockContinuityRepository implements ContinuityRepository {
  MockContinuityRepository({
    required TeacherRepository teacherRepository,
    required CommunicationRepository communicationRepository,
    required TimetableRepository timetableRepository,
    required ParentRepository parentRepository,
  })  : _teacherRepository = teacherRepository,
        _communicationRepository = communicationRepository,
        _timetableRepository = timetableRepository,
        _parentRepository = parentRepository;

  final TeacherRepository _teacherRepository;
  final CommunicationRepository _communicationRepository;
  final TimetableRepository _timetableRepository;
  final ParentRepository _parentRepository;

  final Map<String, ContinuityMigrationPlan> _plans = {};
  final Map<String, List<ContinuityAuditEvent>> _audit = {};
  int _planSeq = 0;
  int _migrationSeq = 0;
  int _auditSeq = 0;

  @override
  Future<ContinuityMigrationPlan> previewContinuityMigration({
    required RepositoryQuery query,
    required String studentId,
    required String fromClass,
    required String fromSection,
    required String toClass,
    required String toSection,
    required String academicYear,
  }) async {
    final teacherThreads = await _teacherRepository.getMessageThreads(query: query);
    final parentThreads = await _parentRepository.getMessageThreads(query: query);
    final timetable = await _timetableRepository.getTimetables(query: query);
    final notifications = await _communicationRepository.getNotifications(query: query);
    final impactedTeacherThreads = teacherThreads
        .where((thread) => thread.studentName.contains(studentId) || thread.studentName.contains(fromClass))
        .toList(growable: false);
    final impactedParentThreadIds = parentThreads.take(2).map((e) => e.id).toList(growable: false);
    final impactedSlots = timetable
        .where((row) => row.sectionId.toLowerCase().contains(fromSection.toLowerCase()))
        .map((row) => row.id)
        .toList(growable: false);

    final plan = ContinuityMigrationPlan(
      id: 'CONT_PLAN_${++_planSeq}',
      studentId: studentId,
      fromClass: fromClass,
      fromSection: fromSection,
      toClass: toClass,
      toSection: toSection,
      academicYear: academicYear,
      status: ContinuityPlanStatus.previewed,
      teacherImpact: TeacherContinuityImpact(
        fromTeacherId: 'teacher_${fromClass}_$fromSection',
        toTeacherId: 'teacher_${toClass}_$toSection',
        studentIds: [studentId],
        threadCount: impactedTeacherThreads.length,
      ),
      timetableImpact: TimetableContinuityImpact(
        studentId: studentId,
        fromSection: fromSection,
        toSection: toSection,
        slotIds: impactedSlots,
      ),
      parentCommunicationImpact: ParentCommunicationContinuityImpact(
        studentId: studentId,
        parentIds: const ['parent_primary'],
        threadIds: impactedParentThreadIds,
      ),
      notificationImpact: NotificationContinuityImpact(
        studentId: studentId,
        notificationIds: notifications.take(3).map((n) => n.id).toList(growable: false),
        recipientIds: const ['parent_primary', 'teacher_current'],
      ),
      assignmentImpact: AssignmentContinuityImpact(
        studentId: studentId,
        assignmentIds: ['hw_cont_1', 'hw_cont_2'],
        migratedCount: 2,
      ),
      messageOwnershipImpact: MessageOwnershipContinuityImpact(
        fromTeacherId: 'teacher_${fromClass}_$fromSection',
        toTeacherId: 'teacher_${toClass}_$toSection',
        transferredThreadIds: impactedTeacherThreads.map((e) => e.id).toList(growable: false),
      ),
      createdAt: DateTime.now(),
    );
    _plans[plan.id] = plan;
    _audit[plan.id] = [
      _event(
        migrationId: plan.id,
        area: ContinuityMigrationArea.teacher,
        action: 'previewed',
        metadata: {'threads': '${plan.teacherImpact.threadCount}'},
      ),
    ];
    return plan;
  }

  @override
  Future<ContinuityMigrationResult> executeContinuityMigration({
    required RepositoryQuery query,
    required String planId,
  }) async {
    final plan = _plans[planId];
    if (plan == null) {
      throw StateError('Unknown continuity plan: $planId');
    }
    final ownership = await transferMessageOwnership(
      query: query,
      fromTeacherId: plan.teacherImpact.fromTeacherId,
      toTeacherId: plan.teacherImpact.toTeacherId,
      studentIds: plan.teacherImpact.studentIds,
    );
    final timetable = await migrateTimetableSlots(
      query: query,
      studentId: plan.studentId,
      fromSection: plan.fromSection,
      toSection: plan.toSection,
    );
    final parent = await migrateParentNotifications(
      query: query,
      studentId: plan.studentId,
      parentIds: plan.parentCommunicationImpact.parentIds,
    );
    final assignments = await migrateHomeworkAssignments(
      query: query,
      studentId: plan.studentId,
    );
    _audit[planId] = [
      ...?_audit[planId],
      _event(
        migrationId: planId,
        area: ContinuityMigrationArea.messageOwnership,
        action: 'transferred',
        metadata: {'threads': '${ownership.transferredThreadIds.length}'},
      ),
      _event(
        migrationId: planId,
        area: ContinuityMigrationArea.timetable,
        action: 'migrated',
        metadata: {'slots': '${timetable.slotIds.length}'},
      ),
      _event(
        migrationId: planId,
        area: ContinuityMigrationArea.parentCommunication,
        action: 'migrated',
        metadata: {'threads': '${parent.threadIds.length}'},
      ),
      _event(
        migrationId: planId,
        area: ContinuityMigrationArea.assignment,
        action: 'migrated',
        metadata: {'assignments': '${assignments.migratedCount}'},
      ),
      _event(
        migrationId: planId,
        area: ContinuityMigrationArea.notification,
        action: 'migrated',
        metadata: {'notifications': '${plan.notificationImpact.notificationIds.length}'},
      ),
    ];
    return ContinuityMigrationResult(
      migrationId: 'CONT_MIG_${++_migrationSeq}',
      planId: planId,
      status: ContinuityPlanStatus.executed,
      migratedAreas: const [
        ContinuityMigrationArea.teacher,
        ContinuityMigrationArea.timetable,
        ContinuityMigrationArea.parentCommunication,
        ContinuityMigrationArea.notification,
        ContinuityMigrationArea.assignment,
        ContinuityMigrationArea.messageOwnership,
      ],
      executedAt: DateTime.now(),
      auditTrail: _audit[planId] ?? const [],
    );
  }

  @override
  Future<MessageOwnershipContinuityImpact> transferMessageOwnership({
    required RepositoryQuery query,
    required String fromTeacherId,
    required String toTeacherId,
    required List<String> studentIds,
  }) async {
    final threads = await _teacherRepository.getMessageThreads(query: query);
    final transferred = threads
        .where((thread) => studentIds.any((studentId) => thread.studentName.contains(studentId)))
        .map((thread) => thread.id)
        .toList(growable: false);
    return MessageOwnershipContinuityImpact(
      fromTeacherId: fromTeacherId,
      toTeacherId: toTeacherId,
      transferredThreadIds: transferred,
    );
  }

  @override
  Future<TimetableContinuityImpact> migrateTimetableSlots({
    required RepositoryQuery query,
    required String studentId,
    required String fromSection,
    required String toSection,
  }) async {
    final rows = await _timetableRepository.getTimetables(query: query);
    final slotIds = rows
        .where((row) => row.sectionId.toLowerCase().contains(fromSection.toLowerCase()))
        .map((row) => row.id)
        .toList(growable: false);
    return TimetableContinuityImpact(
      studentId: studentId,
      fromSection: fromSection,
      toSection: toSection,
      slotIds: slotIds,
    );
  }

  @override
  Future<ParentCommunicationContinuityImpact> migrateParentNotifications({
    required RepositoryQuery query,
    required String studentId,
    required List<String> parentIds,
  }) async {
    final threads = await _parentRepository.getMessageThreads(query: query);
    return ParentCommunicationContinuityImpact(
      studentId: studentId,
      parentIds: parentIds,
      threadIds: threads.take(3).map((e) => e.id).toList(growable: false),
    );
  }

  @override
  Future<AssignmentContinuityImpact> migrateHomeworkAssignments({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    return AssignmentContinuityImpact(
      studentId: studentId,
      assignmentIds: ['hw_cont_1', 'hw_cont_2'],
      migratedCount: 2,
    );
  }

  @override
  Future<List<ContinuityAuditEvent>> getContinuityAuditTrail({
    required RepositoryQuery query,
    required String migrationId,
  }) async {
    return _audit[migrationId] ?? const [];
  }

  ContinuityAuditEvent _event({
    required String migrationId,
    required ContinuityMigrationArea area,
    required String action,
    required Map<String, String> metadata,
  }) {
    return ContinuityAuditEvent(
      id: 'CONT_AUDIT_${++_auditSeq}',
      migrationId: migrationId,
      area: area,
      action: action,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }
}
