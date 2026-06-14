import '../../../continuity/continuity_models.dart';
import '../../interfaces/continuity_repository.dart';
import '../../repository_query.dart';
import 'api_continuity_repository.dart';

class HybridContinuityRepository implements ContinuityRepository {
  HybridContinuityRepository({required ApiContinuityRepository api}) : _api = api;

  final ApiContinuityRepository _api;

  @override
  Future<ContinuityMigrationPlan> previewContinuityMigration({
    required RepositoryQuery query,
    required String studentId,
    required String fromClass,
    required String fromSection,
    required String toClass,
    required String toSection,
    required String academicYear,
  }) =>
      _api.previewContinuityMigration(
        query: query,
        studentId: studentId,
        fromClass: fromClass,
        fromSection: fromSection,
        toClass: toClass,
        toSection: toSection,
        academicYear: academicYear,
      );

  @override
  Future<ContinuityMigrationResult> executeContinuityMigration({
    required RepositoryQuery query,
    required String planId,
  }) =>
      _api.executeContinuityMigration(query: query, planId: planId);

  @override
  Future<MessageOwnershipContinuityImpact> transferMessageOwnership({
    required RepositoryQuery query,
    required String fromTeacherId,
    required String toTeacherId,
    required List<String> studentIds,
  }) =>
      _api.transferMessageOwnership(
        query: query,
        fromTeacherId: fromTeacherId,
        toTeacherId: toTeacherId,
        studentIds: studentIds,
      );

  @override
  Future<TimetableContinuityImpact> migrateTimetableSlots({
    required RepositoryQuery query,
    required String studentId,
    required String fromSection,
    required String toSection,
  }) =>
      _api.migrateTimetableSlots(
        query: query,
        studentId: studentId,
        fromSection: fromSection,
        toSection: toSection,
      );

  @override
  Future<ParentCommunicationContinuityImpact> migrateParentNotifications({
    required RepositoryQuery query,
    required String studentId,
    required List<String> parentIds,
  }) =>
      _api.migrateParentNotifications(
        query: query,
        studentId: studentId,
        parentIds: parentIds,
      );

  @override
  Future<AssignmentContinuityImpact> migrateHomeworkAssignments({
    required RepositoryQuery query,
    required String studentId,
  }) =>
      _api.migrateHomeworkAssignments(query: query, studentId: studentId);

  @override
  Future<List<ContinuityAuditEvent>> getContinuityAuditTrail({
    required RepositoryQuery query,
    required String migrationId,
  }) =>
      _api.getContinuityAuditTrail(query: query, migrationId: migrationId);
}
