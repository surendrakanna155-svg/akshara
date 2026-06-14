import '../../../continuity/continuity_models.dart';
import '../../interfaces/continuity_repository.dart';
import '../../repository_query.dart';
import 'dto/continuity_request_dto.dart';
import 'mapper/continuity_mapper.dart';
import 'remote/continuity_remote_datasource.dart';

class ApiContinuityRepository implements ContinuityRepository {
  ApiContinuityRepository({
    required ContinuityRemoteDataSource remote,
    ContinuityMapper mapper = const ContinuityMapper(),
  })  : _remote = remote,
        _mapper = mapper;

  final ContinuityRemoteDataSource _remote;
  final ContinuityMapper _mapper;

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
    final dto = await _remote.previewMigration(
      query: query,
      request: ContinuityPreviewRequestDto(
        studentId: studentId,
        fromClass: fromClass,
        fromSection: fromSection,
        toClass: toClass,
        toSection: toSection,
        academicYear: academicYear,
      ),
    );
    return _mapper.toPlan(dto);
  }

  @override
  Future<ContinuityMigrationResult> executeContinuityMigration({
    required RepositoryQuery query,
    required String planId,
  }) async {
    final dto = await _remote.executeMigration(query: query, planId: planId);
    final base = _mapper.toResult(dto);
    final audit = await getContinuityAuditTrail(query: query, migrationId: base.planId);
    return ContinuityMigrationResult(
      migrationId: base.migrationId,
      planId: base.planId,
      status: base.status,
      migratedAreas: base.migratedAreas,
      executedAt: base.executedAt,
      auditTrail: audit,
    );
  }

  @override
  Future<MessageOwnershipContinuityImpact> transferMessageOwnership({
    required RepositoryQuery query,
    required String fromTeacherId,
    required String toTeacherId,
    required List<String> studentIds,
  }) async {
    final raw = await _remote.transferMessageOwnership(
      query: query,
      fromTeacherId: fromTeacherId,
      toTeacherId: toTeacherId,
      studentIds: studentIds,
    );
    return MessageOwnershipContinuityImpact(
      fromTeacherId: raw['fromTeacherId'] as String? ?? fromTeacherId,
      toTeacherId: raw['toTeacherId'] as String? ?? toTeacherId,
      transferredThreadIds: (raw['transferredThreadIds'] as List<dynamic>? ?? const [])
          .map((e) => '$e')
          .toList(growable: false),
    );
  }

  @override
  Future<TimetableContinuityImpact> migrateTimetableSlots({
    required RepositoryQuery query,
    required String studentId,
    required String fromSection,
    required String toSection,
  }) async {
    final raw = await _remote.migrateTimetableSlots(
      query: query,
      studentId: studentId,
      fromSection: fromSection,
      toSection: toSection,
    );
    return TimetableContinuityImpact(
      studentId: raw['studentId'] as String? ?? studentId,
      fromSection: raw['fromSection'] as String? ?? fromSection,
      toSection: raw['toSection'] as String? ?? toSection,
      slotIds: (raw['slotIds'] as List<dynamic>? ?? const []).map((e) => '$e').toList(growable: false),
    );
  }

  @override
  Future<ParentCommunicationContinuityImpact> migrateParentNotifications({
    required RepositoryQuery query,
    required String studentId,
    required List<String> parentIds,
  }) async {
    final raw = await _remote.migrateParentNotifications(
      query: query,
      studentId: studentId,
      parentIds: parentIds,
    );
    return ParentCommunicationContinuityImpact(
      studentId: raw['studentId'] as String? ?? studentId,
      parentIds: (raw['parentIds'] as List<dynamic>? ?? parentIds).map((e) => '$e').toList(growable: false),
      threadIds: (raw['threadIds'] as List<dynamic>? ?? const []).map((e) => '$e').toList(growable: false),
    );
  }

  @override
  Future<AssignmentContinuityImpact> migrateHomeworkAssignments({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    final raw = await _remote.migrateHomeworkAssignments(query: query, studentId: studentId);
    return AssignmentContinuityImpact(
      studentId: raw['studentId'] as String? ?? studentId,
      assignmentIds: (raw['assignmentIds'] as List<dynamic>? ?? const []).map((e) => '$e').toList(growable: false),
      migratedCount: (raw['migratedCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<List<ContinuityAuditEvent>> getContinuityAuditTrail({
    required RepositoryQuery query,
    required String migrationId,
  }) async {
    final dto = await _remote.fetchAuditTrail(query: query, migrationId: migrationId);
    return _mapper.toAuditEvents(dto);
  }
}
