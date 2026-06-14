import '../../continuity/continuity_models.dart';
import '../repository_query.dart';

abstract class ContinuityRepository {
  Future<ContinuityMigrationPlan> previewContinuityMigration({
    required RepositoryQuery query,
    required String studentId,
    required String fromClass,
    required String fromSection,
    required String toClass,
    required String toSection,
    required String academicYear,
  });

  Future<ContinuityMigrationResult> executeContinuityMigration({
    required RepositoryQuery query,
    required String planId,
  });

  Future<MessageOwnershipContinuityImpact> transferMessageOwnership({
    required RepositoryQuery query,
    required String fromTeacherId,
    required String toTeacherId,
    required List<String> studentIds,
  });

  Future<TimetableContinuityImpact> migrateTimetableSlots({
    required RepositoryQuery query,
    required String studentId,
    required String fromSection,
    required String toSection,
  });

  Future<ParentCommunicationContinuityImpact> migrateParentNotifications({
    required RepositoryQuery query,
    required String studentId,
    required List<String> parentIds,
  });

  Future<AssignmentContinuityImpact> migrateHomeworkAssignments({
    required RepositoryQuery query,
    required String studentId,
  });

  Future<List<ContinuityAuditEvent>> getContinuityAuditTrail({
    required RepositoryQuery query,
    required String migrationId,
  });
}
